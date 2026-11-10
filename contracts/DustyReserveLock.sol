// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// DustyReserveLock — immutable, ownerless token timelock for the Dusty Rewards Reserve.
// Modeled on OpenZeppelin's TokenTimelock (removed in OZ v5). UNAUDITED.
// Build: solc 0.8.24, optimizer 200 runs, evmVersion cancun, OpenZeppelin Contracts v5.6.1.
//
// - token, beneficiary and releaseTime are fixed at deploy and can never change.
// - No owner, no admin, no upgrade, no early withdraw, no rescue.
// - release() can be called by anyone, but only after releaseTime, and it always sends
//   the FULL balance of `token` to `beneficiary` (never anywhere else).

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DustyReserveLock {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable releaseTime;

    event Released(address indexed beneficiary, uint256 amount);

    constructor(IERC20 token_, address beneficiary_, uint256 releaseTime_) {
        require(address(token_) != address(0), "LOCK: zero token");
        require(beneficiary_ != address(0), "LOCK: zero beneficiary");
        require(releaseTime_ > block.timestamp, "LOCK: release time in past");
        token = token_;
        beneficiary = beneficiary_;
        releaseTime = releaseTime_;
    }

    /// @notice Tokens currently held by the lock.
    function lockedAmount() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /// @notice Send all locked tokens to the beneficiary. Reverts before releaseTime.
    function release() external {
        require(block.timestamp >= releaseTime, "LOCK: still locked");
        uint256 amount = token.balanceOf(address(this));
        require(amount > 0, "LOCK: nothing to release");
        token.safeTransfer(beneficiary, amount);
        emit Released(beneficiary, amount);
    }
}
