// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// DustyRecycler — TESTNET PROTOTYPE (Base Sepolia). Unaudited. Not for mainnet use.
//
// Flow: the user approves a dust token, the Dusty backend signs a quote (how much DUSTY
// that dust is worth), the user calls recycle(). The dust goes to the treasury, and the user
// receives the quoted DUSTY minus the recycle fee (default 5%). The fee portion is simply not
// minted, so the treasury keeps 100% of the dust and no extra DUSTY is created for fees.
//
// Setup after deploy: on DustyToken, owner calls setMinter(<this contract>, true).

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface IDustyToken {
    function mintReward(address to, uint256 amount, bytes32 ref) external;
}

contract DustyRecycler is Ownable, Pausable, ReentrancyGuard, EIP712 {
    using SafeERC20 for IERC20;

    uint16 public constant MAX_FEE_BPS = 1000; // fee can never exceed 10%

    IDustyToken public immutable dusty;
    address public treasury;      // receives all recycled dust
    address public quoteSigner;   // backend key that signs quotes (Dusty Minter wallet)
    uint16 public feeBps;         // 500 = 5%

    mapping(address => uint256) public nonces;

    bytes32 private constant QUOTE_TYPEHASH = keccak256(
        "Quote(address user,address token,uint256 amount,uint256 dustyOut,uint256 nonce,uint256 deadline)"
    );

    event Recycled(address indexed user, address indexed token, uint256 amount, uint256 dustyToUser, uint256 feeDusty, uint256 nonce);
    event TreasurySet(address treasury);
    event QuoteSignerSet(address signer);
    event FeeSet(uint16 feeBps);

    constructor(address initialOwner, address dustyToken, address treasury_, address quoteSigner_, uint16 feeBps_)
        Ownable(initialOwner)
        EIP712("DustyRecycler", "1")
    {
        require(dustyToken != address(0) && treasury_ != address(0) && quoteSigner_ != address(0), "zero addr");
        require(feeBps_ <= MAX_FEE_BPS, "fee too high");
        dusty = IDustyToken(dustyToken);
        treasury = treasury_;
        quoteSigner = quoteSigner_;
        feeBps = feeBps_;
    }

    /// @notice Recycle one dust token for DUSTY using a backend-signed quote.
    function recycle(address token, uint256 amount, uint256 dustyOut, uint256 deadline, bytes calldata signature)
        external
        nonReentrant
        whenNotPaused
    {
        require(block.timestamp <= deadline, "quote expired");
        require(amount > 0 && dustyOut > 0, "zero amount");
        uint256 nonce = nonces[msg.sender]++;
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(QUOTE_TYPEHASH, msg.sender, token, amount, dustyOut, nonce, deadline))
        );
        require(ECDSA.recover(digest, signature) == quoteSigner, "bad quote");

        IERC20(token).safeTransferFrom(msg.sender, treasury, amount);

        uint256 fee = (dustyOut * feeBps) / 10_000;
        uint256 toUser = dustyOut - fee;
        dusty.mintReward(msg.sender, toUser, keccak256(abi.encode(token, amount, nonce)));
        emit Recycled(msg.sender, token, amount, toUser, fee, nonce);
    }

    /// @notice EIP-712 digest the backend signs (helper for off-chain code and testing).
    function quoteDigest(address user, address token, uint256 amount, uint256 dustyOut, uint256 nonce, uint256 deadline)
        external view returns (bytes32)
    {
        return _hashTypedDataV4(keccak256(abi.encode(QUOTE_TYPEHASH, user, token, amount, dustyOut, nonce, deadline)));
    }

    // ---- owner controls ----
    function setTreasury(address t) external onlyOwner { require(t != address(0), "zero"); treasury = t; emit TreasurySet(t); }
    function setQuoteSigner(address s) external onlyOwner { require(s != address(0), "zero"); quoteSigner = s; emit QuoteSignerSet(s); }
    function setFee(uint16 f) external onlyOwner { require(f <= MAX_FEE_BPS, "fee too high"); feeBps = f; emit FeeSet(f); }
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }
}
