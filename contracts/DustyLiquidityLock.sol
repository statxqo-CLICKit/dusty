// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// DustyLiquidityLock — immutable, ownerless timelock for one Uniswap v3 LP position NFT. UNAUDITED.
// Build: solc 0.8.24, optimizer 200 runs, evmVersion cancun, OpenZeppelin Contracts v5.6.1.
//
// - positionManager, tokenId, beneficiary and unlockTime are fixed at deploy and can never change.
// - Accepts exactly one NFT: `tokenId` from `positionManager`. Any other NFT is rejected.
// - Before unlockTime the position cannot leave this contract and its liquidity cannot be removed:
//   there is no decreaseLiquidity, no transfer, no approve, no owner, no admin, no upgrade.
// - collectFees(): anyone may call at any time; trading fees earned by the position are sent to
//   `beneficiary` (never anywhere else). The principal liquidity stays in the position.
// - withdraw(): only `beneficiary`, only at or after unlockTime, sends the NFT to `beneficiary`.

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface INonfungiblePositionManager {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract DustyLiquidityLock is IERC721Receiver {
    INonfungiblePositionManager public immutable positionManager;
    uint256 public immutable tokenId;
    address public immutable beneficiary;
    uint256 public immutable unlockTime;

    event Locked(address indexed from, uint256 indexed tokenId);
    event FeesCollected(address indexed to, uint256 amount0, uint256 amount1);
    event Withdrawn(address indexed to, uint256 indexed tokenId);

    constructor(INonfungiblePositionManager positionManager_, uint256 tokenId_, address beneficiary_, uint256 unlockTime_) {
        require(address(positionManager_) != address(0), "LPLOCK: zero manager");
        require(beneficiary_ != address(0), "LPLOCK: zero beneficiary");
        require(unlockTime_ > block.timestamp, "LPLOCK: unlock time in past");
        positionManager = positionManager_;
        tokenId = tokenId_;
        beneficiary = beneficiary_;
        unlockTime = unlockTime_;
    }

    /// @notice True while this contract owns the position NFT.
    function isLocked() external view returns (bool) {
        return positionManager.ownerOf(tokenId) == address(this);
    }

    /// @dev Only the configured position NFT can be received.
    function onERC721Received(address, address from, uint256 id, bytes calldata) external returns (bytes4) {
        require(msg.sender == address(positionManager) && id == tokenId, "LPLOCK: wrong NFT");
        emit Locked(from, id);
        return IERC721Receiver.onERC721Received.selector;
    }

    /// @notice Send all trading fees owed to the position to the beneficiary. Anyone may call.
    function collectFees() external returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = positionManager.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId,
                recipient: beneficiary,
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );
        emit FeesCollected(beneficiary, amount0, amount1);
    }

    /// @notice After unlockTime, the beneficiary takes the position NFT back.
    function withdraw() external {
        require(msg.sender == beneficiary, "LPLOCK: not beneficiary");
        require(block.timestamp >= unlockTime, "LPLOCK: still locked");
        positionManager.safeTransferFrom(address(this), beneficiary, tokenId);
        emit Withdrawn(beneficiary, tokenId);
    }
}
