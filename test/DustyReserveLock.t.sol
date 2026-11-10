// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../contracts/DustyReserveLock.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockTok is ERC20 {
    constructor() ERC20("T", "T") {}
    function mint(address a, uint256 v) external { _mint(a, v); }
}

contract DustyReserveLockTest is Test {
    uint256 constant UNLOCK = 1825825200; // 2027-11-09 21:40 PST (2027-11-10 05:40 UTC)
    address constant RESERVE = 0x4F9eb9a29c174Ec2a087545275Bf1e9070ef108C;
    MockTok t;
    DustyReserveLock lock;

    function setUp() public {
        vm.warp(1794292800); // ~2026-11-10
        t = new MockTok();
        lock = new DustyReserveLock(IERC20(address(t)), RESERVE, UNLOCK);
        t.mint(address(lock), 4_500_000e18);
    }

    function test_immutables() public view {
        assertEq(address(lock.token()), address(t));
        assertEq(lock.beneficiary(), RESERVE);
        assertEq(lock.releaseTime(), UNLOCK);
        assertEq(lock.lockedAmount(), 4_500_000e18);
    }

    function test_constructorGuards() public {
        vm.expectRevert("LOCK: zero token");
        new DustyReserveLock(IERC20(address(0)), RESERVE, UNLOCK);
        vm.expectRevert("LOCK: zero beneficiary");
        new DustyReserveLock(IERC20(address(t)), address(0), UNLOCK);
        vm.expectRevert("LOCK: release time in past");
        new DustyReserveLock(IERC20(address(t)), RESERVE, block.timestamp);
    }

    function test_earlyReleaseReverts() public {
        vm.warp(UNLOCK - 1);
        vm.expectRevert("LOCK: still locked");
        lock.release();
        vm.prank(RESERVE);
        vm.expectRevert("LOCK: still locked");
        lock.release();
    }

    function testFuzz_earlyAlwaysReverts(uint256 ts) public {
        ts = bound(ts, block.timestamp, UNLOCK - 1);
        vm.warp(ts);
        vm.expectRevert("LOCK: still locked");
        lock.release();
    }

    function test_releaseAfterUnlock_anyCaller_onlyToBeneficiary() public {
        vm.warp(UNLOCK);
        vm.prank(address(0xBAD));
        lock.release();
        assertEq(t.balanceOf(RESERVE), 4_500_000e18);
        assertEq(t.balanceOf(address(0xBAD)), 0);
        assertEq(lock.lockedAmount(), 0);
        vm.expectRevert("LOCK: nothing to release");
        lock.release();
    }
}

/// Base mainnet fork: real DUSTY v2, real reserve wallet balance.
/// Run: forge test --match-contract DustyReserveLockForkTest --fork-url https://mainnet.base.org
contract DustyReserveLockForkTest is Test {
    uint256 constant UNLOCK = 1825825200;
    IERC20 constant DUSTY = IERC20(0xAf47E82C6f7cB9E28bB0382a1FeAdBC6308FDDc1);
    address constant RESERVE = 0x4F9eb9a29c174Ec2a087545275Bf1e9070ef108C;

    function test_fork_lockReserve() public {
        if (block.chainid != 8453) return; // only meaningful on a Base fork
        uint256 before = DUSTY.balanceOf(RESERVE);
        assertEq(before, 5_000_000e18, "reserve should hold full supply");
        vm.startPrank(RESERVE);
        DustyReserveLock lock = new DustyReserveLock(DUSTY, RESERVE, UNLOCK);
        DUSTY.transfer(address(lock), 4_500_000e18);
        vm.stopPrank();
        assertEq(DUSTY.balanceOf(address(lock)), 4_500_000e18);
        assertEq(DUSTY.balanceOf(RESERVE), 500_000e18);

        vm.expectRevert("LOCK: still locked");
        lock.release();
        vm.warp(UNLOCK - 1);
        vm.expectRevert("LOCK: still locked");
        lock.release();

        vm.warp(UNLOCK);
        lock.release();
        assertEq(DUSTY.balanceOf(address(lock)), 0);
        assertEq(DUSTY.balanceOf(RESERVE), 5_000_000e18);
    }
}
