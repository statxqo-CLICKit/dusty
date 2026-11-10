// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// Dusty (DUSTY) reward token — v2 (security-fixes branch).
// UNAUDITED. Testnet (Base Sepolia) prototype. Not for mainnet use without a professional audit.
// Build: solc 0.8.24, optimizer 200 runs, evmVersion cancun, OpenZeppelin Contracts v5.6.1.
//
// Roles (H-2 fix — no single key controls everything):
//   DEFAULT_ADMIN_ROLE  "owner". Exactly one holder. Transfer is TWO-STEP with a delay
//                       (beginDefaultAdminTransfer -> wait adminDelay -> acceptDefaultAdminTransfer),
//                       so it can later be handed to a Safe multisig. Grants/revokes roles,
//                       sets minter allowances, unpauses minting. Can NOT mint by itself.
//   MINTER_ROLE         may call mintReward, but only up to its own minterAllowance (H-1 defence in depth).
//   PAUSER_ROLE         guardian: can pause minting (all minters at once) without being admin.
//                       Only the admin can unpause.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract DustyToken is ERC20, ERC20Capped, ERC20Burnable, AccessControlDefaultAdminRules, Pausable {
    /// Max supply: 1,000,000,000 DUSTY (18 decimals).
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// Remaining DUSTY each minter may still mint. Spent on every mint; admin tops it up.
    mapping(address => uint256) public minterAllowance;

    event MinterSet(address indexed minter, bool allowed, uint256 allowance);
    event RewardMinted(address indexed minter, address indexed to, uint256 amount, bytes32 indexed ref);

    /// @param admin        owner / DEFAULT_ADMIN_ROLE (later: a Safe).
    /// @param adminDelay   seconds the next admin must wait before accepting a transfer (testnet 0; mainnet e.g. 172800).
    /// @param guardian     PAUSER_ROLE holder (may equal admin on testnet; ideally a separate hardware wallet).
    /// @param initialSupply whole tokens minted to `admin` once, at deploy (recommended 0).
    constructor(address admin, uint48 adminDelay, address guardian, uint256 initialSupply)
        ERC20("Dusty", "DUSTY")
        ERC20Capped(MAX_SUPPLY)
        AccessControlDefaultAdminRules(adminDelay, admin)
    {
        require(guardian != address(0), "DUSTY: zero guardian");
        _grantRole(PAUSER_ROLE, guardian);
        if (initialSupply > 0) {
            _mint(admin, initialSupply * 1e18);
        }
    }

    // ---------------- minters ----------------

    /// @notice Grant or revoke a minter and set its remaining allowance in one call.
    ///         allowed=false revokes the role and zeroes the allowance.
    function setMinter(address minter, bool allowed, uint256 allowance) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(minter != address(0), "DUSTY: zero minter");
        if (allowed) {
            _grantRole(MINTER_ROLE, minter);
            minterAllowance[minter] = allowance;
        } else {
            _revokeRole(MINTER_ROLE, minter);
            minterAllowance[minter] = 0;
        }
        emit MinterSet(minter, allowed, minterAllowance[minter]);
    }

    /// @notice Compatibility view (v1 had a public isMinter mapping).
    function isMinter(address account) external view returns (bool) {
        return hasRole(MINTER_ROLE, account);
    }

    /// @notice Mint DUSTY after dust is recycled. Only minters, only within their allowance, only while not paused.
    function mintReward(address to, uint256 amount, bytes32 ref) external onlyRole(MINTER_ROLE) whenNotPaused {
        uint256 left = minterAllowance[msg.sender];
        require(amount <= left, "DUSTY: minter allowance");
        unchecked { minterAllowance[msg.sender] = left - amount; }
        _mint(to, amount);
        emit RewardMinted(msg.sender, to, amount, ref);
    }

    // ---------------- pause (minting only; transfers and burns keep working) ----------------

    function pauseMinting() external onlyRole(PAUSER_ROLE) { _pause(); }
    function unpauseMinting() external onlyRole(DEFAULT_ADMIN_ROLE) { _unpause(); }

    // ---------------- overrides ----------------

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControlDefaultAdminRules) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
