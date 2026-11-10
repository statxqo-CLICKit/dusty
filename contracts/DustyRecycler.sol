// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// DustyRecycler v2 — TESTNET PROTOTYPE (Base Sepolia). UNAUDITED. Not for mainnet use without a professional audit.
// Build: solc 0.8.24, optimizer 200 runs, evmVersion cancun, OpenZeppelin Contracts v5.6.1.
//
// Flow: the user approves an allowlisted dust token, the Dusty backend signs an EIP-712 quote (how much
// DUSTY the dust is worth), the user calls recycle(). The dust goes to the treasury and the user receives
// the quoted DUSTY minus the recycle fee (default 5%). The fee portion is simply not minted.
//
// H-1 guard rails (a leaked quote-signer key can no longer mint up to the cap):
//   * allowedToken[token]           on-chain allowlist of accepted dust tokens
//   * maxDustyPerQuote              per-quote ceiling (admin-settable, hard ceiling MAX_PER_QUOTE_CEILING)
//   * dailyMintCap                  rolling 24h limit (token bucket), hard ceiling MAX_DAILY_CAP_CEILING
//   * MAX_QUOTE_TTL                 quotes may not be valid for more than 15 minutes
//   * per-user sequential nonce     replay protection; users can burn an outstanding quote with cancelNonce()
//   * token-side minterAllowance    even a buggy recycler cannot exceed the budget the token admin gave it
//
// H-2 role separation:
//   DEFAULT_ADMIN_ROLE  one holder, two-step transfer with delay (Safe-ready). Sets treasury, signer, fee,
//                       limits, allowlist; unpauses. owner() returns this address.
//   PAUSER_ROLE         guardian: can pause recycle() without being admin.
//   quoteSigner         hot key; may hold NO role and may not be the treasury (enforced).
//   treasury            receives all dust; separate setter.

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IDustyToken {
    function mintReward(address to, uint256 amount, bytes32 ref) external;
}

contract DustyRecycler is AccessControlDefaultAdminRules, Pausable, ReentrancyGuard, EIP712 {
    using SafeERC20 for IERC20;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint16 public constant MAX_FEE_BPS = 1000;                       // fee can never exceed 10%
    uint256 public constant MAX_QUOTE_TTL = 15 minutes;              // signer cannot issue long-lived quotes
    uint256 public constant MAX_PER_QUOTE_CEILING = 100_000 * 1e18;  // hard ceiling for maxDustyPerQuote
    uint256 public constant MAX_DAILY_CAP_CEILING = 10_000_000 * 1e18; // hard ceiling for dailyMintCap (1% of supply)
    uint256 public constant WINDOW = 1 days;

    IDustyToken public immutable dusty;
    address public treasury;
    address public quoteSigner;
    uint16 public feeBps;

    mapping(address => bool) public allowedToken;
    uint256 public maxDustyPerQuote;   // default 10,000 DUSTY (= $10 at the 1,000 DUSTY/$ demo rate)
    uint256 public dailyMintCap;       // default 1,000,000 DUSTY per rolling 24h

    // token-bucket state for the rolling cap
    uint256 public windowUsed;
    uint256 public windowUpdatedAt;

    mapping(address => uint256) public nonces;

    // feeBps is part of the signed quote: if the admin changes the fee after quoting, the quote fails (L-1).
    bytes32 public constant QUOTE_TYPEHASH = keccak256(
        "Quote(address user,address token,uint256 amount,uint256 dustyOut,uint16 feeBps,uint256 nonce,uint256 deadline)"
    );

    event Recycled(address indexed user, address indexed token, uint256 amount, uint256 dustyToUser, uint256 feeDusty, uint256 nonce);
    event TreasurySet(address indexed treasury);
    event QuoteSignerSet(address indexed signer);
    event FeeSet(uint16 feeBps);
    event TokenAllowed(address indexed token, bool allowed);
    event LimitsSet(uint256 maxDustyPerQuote, uint256 dailyMintCap);
    event NonceCancelled(address indexed user, uint256 nonce);
    event Rescued(address indexed token, uint256 amount);

    /// @param admin        owner / DEFAULT_ADMIN_ROLE (later: a Safe)
    /// @param adminDelay   seconds a new admin must wait before accepting (testnet 0; mainnet e.g. 172800)
    /// @param guardian     PAUSER_ROLE holder (can pause, cannot unpause or change settings)
    /// @param dustyToken   DustyToken v2 address
    /// @param treasury_    receives all recycled dust
    /// @param quoteSigner_ backend hot key (must differ from admin, guardian and treasury)
    /// @param feeBps_      500 = 5% (max 1000)
    constructor(
        address admin,
        uint48 adminDelay,
        address guardian,
        address dustyToken,
        address treasury_,
        address quoteSigner_,
        uint16 feeBps_
    ) AccessControlDefaultAdminRules(adminDelay, admin) EIP712("DustyRecycler", "2") {
        require(dustyToken.code.length > 0, "token not contract");
        require(guardian != address(0) && treasury_ != address(0), "zero addr");
        require(feeBps_ <= MAX_FEE_BPS, "fee too high");
        dusty = IDustyToken(dustyToken);
        _grantRole(PAUSER_ROLE, guardian);
        treasury = treasury_;
        emit TreasurySet(treasury_);
        _setSigner(quoteSigner_);
        feeBps = feeBps_;
        emit FeeSet(feeBps_);
        maxDustyPerQuote = 10_000 * 1e18;
        dailyMintCap = 1_000_000 * 1e18;
        windowUpdatedAt = block.timestamp;
        emit LimitsSet(maxDustyPerQuote, dailyMintCap);
    }

    // ---------------- user ----------------

    /// @notice Recycle one dust token for DUSTY using a backend-signed quote.
    function recycle(address token, uint256 amount, uint256 dustyOut, uint256 deadline, bytes calldata signature)
        external
        nonReentrant
        whenNotPaused
    {
        (uint256 nonce, uint16 fBps) = _verifyQuote(token, amount, dustyOut, deadline, signature);
        _consumeDaily(dustyOut);
        _pullExact(token, amount);
        _payout(token, amount, dustyOut, fBps, nonce);
    }

    /// @notice Invalidate your current outstanding quote (burns your next nonce).
    function cancelNonce() external {
        uint256 n = nonces[msg.sender]++;
        emit NonceCancelled(msg.sender, n);
    }

    // ---------------- views ----------------

    /// @notice EIP-712 digest the backend signs (helper for off-chain code and tests).
    function quoteDigest(
        address user, address token, uint256 amount, uint256 dustyOut, uint16 fBps, uint256 nonce, uint256 deadline
    ) external view returns (bytes32) {
        return _hashTypedDataV4(keccak256(abi.encode(QUOTE_TYPEHASH, user, token, amount, dustyOut, fBps, nonce, deadline)));
    }

    /// @notice DUSTY that can still be minted right now under the rolling 24h cap.
    function dailyMintRemaining() external view returns (uint256) {
        uint256 used = _currentUsed();
        return used >= dailyMintCap ? 0 : dailyMintCap - used;
    }

    // ---------------- admin ----------------

    function setTreasury(address t) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(t != address(0), "zero");
        require(t != quoteSigner, "treasury == signer");
        treasury = t;
        emit TreasurySet(t);
    }

    function setQuoteSigner(address s) external onlyRole(DEFAULT_ADMIN_ROLE) { _setSigner(s); }

    function setFee(uint16 f) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(f <= MAX_FEE_BPS, "fee too high");
        feeBps = f;
        emit FeeSet(f);
    }

    function setAllowedToken(address token, bool ok) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(token != address(0), "zero");
        allowedToken[token] = ok;
        emit TokenAllowed(token, ok);
    }

    function setLimits(uint256 perQuote, uint256 perDay) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(perQuote > 0 && perQuote <= MAX_PER_QUOTE_CEILING, "perQuote out of range");
        require(perDay >= perQuote && perDay <= MAX_DAILY_CAP_CEILING, "perDay out of range");
        // settle the bucket at the old rate before changing it
        windowUsed = _currentUsed();
        windowUpdatedAt = block.timestamp;
        maxDustyPerQuote = perQuote;
        dailyMintCap = perDay;
        emit LimitsSet(perQuote, perDay);
    }

    /// @notice Tokens sent here by mistake go to the treasury (never anywhere else).
    function rescue(address token, uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IERC20(token).safeTransfer(treasury, amount);
        emit Rescued(token, amount);
    }

    function pause() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }

    // ---------------- internal ----------------

    function _verifyQuote(address token, uint256 amount, uint256 dustyOut, uint256 deadline, bytes calldata signature)
        internal
        returns (uint256 nonce, uint16 fBps)
    {
        require(amount > 0 && dustyOut > 0, "zero amount");
        require(block.timestamp <= deadline, "quote expired");
        require(deadline <= block.timestamp + MAX_QUOTE_TTL, "deadline too far");
        require(allowedToken[token], "token not allowed");
        require(dustyOut <= maxDustyPerQuote, "quote too large");
        fBps = feeBps;
        nonce = nonces[msg.sender]++;
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(QUOTE_TYPEHASH, msg.sender, token, amount, dustyOut, fBps, nonce, deadline))
        );
        require(ECDSA.recover(digest, signature) == quoteSigner, "bad quote");
    }

    /// M-1: treasury must receive exactly `amount` (rejects fee-on-transfer / rebasing behaviour).
    function _pullExact(address token, uint256 amount) internal {
        address t = treasury;
        uint256 before = IERC20(token).balanceOf(t);
        IERC20(token).safeTransferFrom(msg.sender, t, amount);
        require(IERC20(token).balanceOf(t) - before == amount, "fee-on-transfer token");
    }

    function _payout(address token, uint256 amount, uint256 dustyOut, uint16 fBps, uint256 nonce) internal {
        uint256 fee = (dustyOut * fBps) / 10_000;
        uint256 toUser = dustyOut - fee;
        dusty.mintReward(msg.sender, toUser, keccak256(abi.encode(msg.sender, token, amount, nonce)));
        emit Recycled(msg.sender, token, amount, toUser, fee, nonce);
    }

    function _setSigner(address s) internal {
        require(s != address(0), "zero signer");
        require(s != treasury, "signer == treasury");
        require(s != defaultAdmin(), "signer == admin");
        (address pendingAdmin, ) = pendingDefaultAdmin();
        require(s != pendingAdmin, "signer == pending admin");
        require(!hasRole(PAUSER_ROLE, s), "signer is pauser");
        quoteSigner = s;
        emit QuoteSignerSet(s);
    }

    /// The hot signer key may never hold any role (admin, pauser, or anything added later).
    function _grantRole(bytes32 role, address account) internal override returns (bool) {
        require(account != quoteSigner, "signer cannot hold roles");
        return super._grantRole(role, account);
    }

    function _beginDefaultAdminTransfer(address newAdmin) internal override {
        require(newAdmin != quoteSigner, "signer cannot be admin");
        super._beginDefaultAdminTransfer(newAdmin);
    }

    function _currentUsed() internal view returns (uint256) {
        uint256 elapsed = block.timestamp - windowUpdatedAt;
        uint256 decay = (elapsed * dailyMintCap) / WINDOW;
        return windowUsed > decay ? windowUsed - decay : 0;
    }

    function _consumeDaily(uint256 amt) internal {
        uint256 used = _currentUsed() + amt;
        require(used <= dailyMintCap, "daily cap");
        windowUsed = used;
        windowUpdatedAt = block.timestamp;
    }
}
