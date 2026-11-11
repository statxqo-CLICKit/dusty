// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../contracts/DustyLiquidityLock.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// Minimal stand-in for the Uniswap v3 NonfungiblePositionManager (ERC721 + collect).
contract MockNPM is ERC721 {
    uint256 public fee0;
    uint256 public fee1;
    address public lastRecipient;
    constructor() ERC721("P", "P") {}
    function mint(address to, uint256 id) external { _mint(to, id); }
    function setFees(uint256 a, uint256 b) external { fee0 = a; fee1 = b; }
    function collect(INonfungiblePositionManager.CollectParams calldata p) external payable returns (uint256, uint256) {
        require(_isAuthorized(ownerOf(p.tokenId), msg.sender, p.tokenId), "Not approved");
        lastRecipient = p.recipient;
        (uint256 a, uint256 b) = (fee0, fee1);
        fee0 = 0; fee1 = 0;
        return (a, b);
    }
}

contract DustyLiquidityLockTest is Test {
    uint256 constant UNLOCK = 1825825200; // 2027-11-09 21:40 PST
    address constant ADMIN = 0x9b8EBB1490E823bB152aCd64B198Df4d1035c7Fd;
    uint256 constant ID = 6525151;
    MockNPM npm;
    DustyLiquidityLock lock;

    function setUp() public {
        vm.warp(1794292800);
        npm = new MockNPM();
        npm.mint(ADMIN, ID);
        npm.mint(ADMIN, ID + 1);
        lock = new DustyLiquidityLock(INonfungiblePositionManager(address(npm)), ID, ADMIN, UNLOCK);
        vm.prank(ADMIN);
        npm.safeTransferFrom(ADMIN, address(lock), ID);
    }

    function test_immutables() public view {
        assertEq(address(lock.positionManager()), address(npm));
        assertEq(lock.tokenId(), ID);
        assertEq(lock.beneficiary(), ADMIN);
        assertEq(lock.unlockTime(), UNLOCK);
        assertTrue(lock.isLocked());
        assertEq(npm.ownerOf(ID), address(lock));
    }

    function test_constructorGuards() public {
        vm.expectRevert("LPLOCK: zero manager");
        new DustyLiquidityLock(INonfungiblePositionManager(address(0)), ID, ADMIN, UNLOCK);
        vm.expectRevert("LPLOCK: zero beneficiary");
        new DustyLiquidityLock(INonfungiblePositionManager(address(npm)), ID, address(0), UNLOCK);
        vm.expectRevert("LPLOCK: unlock time in past");
        new DustyLiquidityLock(INonfungiblePositionManager(address(npm)), ID, ADMIN, block.timestamp);
    }

    function test_rejectsOtherNFTs() public {
        vm.prank(ADMIN);
        vm.expectRevert("LPLOCK: wrong NFT");
        npm.safeTransferFrom(ADMIN, address(lock), ID + 1);
        MockNPM other = new MockNPM();
        other.mint(ADMIN, ID);
        vm.prank(ADMIN);
        vm.expectRevert("LPLOCK: wrong NFT");
        other.safeTransferFrom(ADMIN, address(lock), ID);
        vm.expectRevert("LPLOCK: wrong NFT");
        lock.onERC721Received(address(this), address(this), ID, "");
    }

    function test_collectFees_anyCaller_toBeneficiary() public {
        npm.setFees(5, 7);
        vm.prank(address(0xBAD));
        (uint256 a, uint256 b) = lock.collectFees();
        assertEq(a, 5); assertEq(b, 7);
        assertEq(npm.lastRecipient(), ADMIN);
        assertEq(npm.ownerOf(ID), address(lock));
    }

    function test_withdrawBeforeUnlockReverts() public {
        vm.warp(UNLOCK - 1);
        vm.prank(ADMIN);
        vm.expectRevert("LPLOCK: still locked");
        lock.withdraw();
    }

    function testFuzz_earlyWithdrawAlwaysReverts(uint256 ts) public {
        ts = bound(ts, block.timestamp, UNLOCK - 1);
        vm.warp(ts);
        vm.prank(ADMIN);
        vm.expectRevert("LPLOCK: still locked");
        lock.withdraw();
    }

    function testFuzz_nonBeneficiaryNeverWithdraws(address who, uint256 ts) public {
        vm.assume(who != ADMIN);
        vm.warp(bound(ts, block.timestamp, type(uint64).max));
        vm.prank(who);
        vm.expectRevert("LPLOCK: not beneficiary");
        lock.withdraw();
    }

    function test_withdrawAfterUnlock() public {
        vm.warp(UNLOCK);
        vm.prank(ADMIN);
        lock.withdraw();
        assertEq(npm.ownerOf(ID), ADMIN);
        assertFalse(lock.isLocked());
    }
}

interface IPos {
    function positions(uint256) external view returns (uint96, address, address, address, uint24, int24, int24, uint128, uint256, uint256, uint128, uint128);
    function decreaseLiquidity(DecParams calldata) external payable returns (uint256, uint256);
    struct DecParams { uint256 tokenId; uint128 liquidity; uint256 amount0Min; uint256 amount1Min; uint256 deadline; }
}
interface ISwapRouter02 {
    struct ExactInputSingleParams { address tokenIn; address tokenOut; uint24 fee; address recipient; uint256 amountIn; uint256 amountOutMinimum; uint160 sqrtPriceLimitX96; }
    function exactInputSingle(ExactInputSingleParams calldata) external payable returns (uint256);
}

/// Base mainnet fork: real Uniswap v3 position #6525151 owned by the admin wallet.
/// Run: forge test --match-contract DustyLiquidityLockForkTest --fork-url https://mainnet.base.org
/// Checks the LIVE lock on Base: LP NFT 6525151 has been held by 0xacCED9C1…5ee6 since 2026-11-09 22:37 PT.
contract DustyLiquidityLockForkTest is Test {
    uint256 constant UNLOCK = 1825825200; // 2027-11-09
    address constant NPM = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant ROUTER = 0x2626664c2603336E57B271c5C0b26F421741e481; // Uniswap SwapRouter02 on Base
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant DUSTY = 0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1;
    address constant ADMIN = 0x9b8EBB1490E823bB152aCd64B198Df4d1035c7Fd;
    address constant LOCK = 0xacCED9C10915F0587D2f37215438f1E0c71b5ee6;
    uint256 constant ID = 6525151;

    function test_fork_liveLock() public {
        if (block.chainid != 8453) return; // only meaningful on a Base fork
        INonfungiblePositionManager npm = INonfungiblePositionManager(NPM);
        DustyLiquidityLock lock = DustyLiquidityLock(LOCK);

        // deployed lock is wired to the right NFT, beneficiary and date, and holds the position
        assertGt(LOCK.code.length, 0, "lock deployed");
        assertEq(address(lock.positionManager()), NPM);
        assertEq(lock.tokenId(), ID);
        assertEq(lock.beneficiary(), ADMIN);
        assertEq(lock.unlockTime(), UNLOCK);
        assertTrue(lock.isLocked());
        assertEq(npm.ownerOf(ID), LOCK, "lock should own the LP NFT");
        (, , address t0, address t1, uint24 fee, , , uint128 liq0, , , , ) = IPos(NPM).positions(ID);
        assertEq(t0, USDC);
        assertEq(t1, DUSTY);
        assertEq(fee, 10000);
        assertGt(liq0, 0);

        // Admin (former owner) can no longer touch the liquidity.
        vm.prank(ADMIN);
        vm.expectRevert();
        IPos(NPM).decreaseLiquidity(IPos.DecParams(ID, liq0, 0, 0, block.timestamp));

        // generate trading fees with a real swap, then anyone collects them to the admin wallet
        address trader = address(0x7777);
        deal(USDC, trader, 5e6);
        vm.startPrank(trader);
        IERC20(USDC).approve(ROUTER, type(uint256).max);
        ISwapRouter02(ROUTER).exactInputSingle(ISwapRouter02.ExactInputSingleParams(USDC, DUSTY, 10000, trader, 5e6, 0, 0));
        vm.stopPrank();
        uint256 before = IERC20(USDC).balanceOf(ADMIN);
        uint256 badBefore = IERC20(USDC).balanceOf(address(0xBAD));
        vm.prank(address(0xBAD));
        (uint256 a0, uint256 a1) = lock.collectFees();
        assertGt(a0 + a1, 0, "fees collected");
        assertEq(IERC20(USDC).balanceOf(ADMIN) - before, a0, "USDC fees went to the admin wallet"); // token0 = USDC
        assertEq(IERC20(USDC).balanceOf(address(0xBAD)), badBefore, "caller got nothing");
        (, , , , , , , uint128 liq1, , , , ) = IPos(NPM).positions(ID);
        assertEq(liq1, liq0, "principal untouched");

        // no early withdraw, nobody else ever
        vm.prank(ADMIN);
        vm.expectRevert("LPLOCK: still locked");
        lock.withdraw();
        vm.warp(UNLOCK - 1);
        vm.prank(ADMIN);
        vm.expectRevert("LPLOCK: still locked");
        lock.withdraw();
        vm.warp(UNLOCK);
        vm.prank(address(0xBAD));
        vm.expectRevert("LPLOCK: not beneficiary");
        lock.withdraw();
        vm.prank(ADMIN);
        lock.withdraw();
        assertEq(npm.ownerOf(ID), ADMIN);
    }
}
