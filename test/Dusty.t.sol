// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import "../contracts/DustyToken.sol";
import "../contracts/DustyRecycler.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {}
    function decimals() public pure override returns (uint8) { return 6; }
    function mint(address a, uint256 v) external { _mint(a, v); }
}

contract FeeOnTransfer is ERC20 {
    constructor() ERC20("FOT", "FOT") {}
    function mint(address a, uint256 v) external { _mint(a, v); }
    function _update(address f, address t, uint256 v) internal override {
        if (f != address(0) && t != address(0)) {
            uint256 fee = v / 10;
            super._update(f, address(0xdead), fee);
            super._update(f, t, v - fee);
        } else super._update(f, t, v);
    }
}

contract DustyTest is Test {
    DustyToken tok;
    DustyRecycler rec;
    MockUSDC usdc;

    address admin = address(0xA11CE);
    address guardian = address(0x6A2D);
    address treasury = address(0x7EA5);
    uint256 signerPk = 0xB0B;
    address signer;
    address user = address(0xCAFE);
    address attacker = address(0xBAD);
    address safe = address(0x5AFE);

    uint256 constant RATE = 1000;                    // demo: 1,000 DUSTY per $1
    uint256 constant RECYCLER_ALLOWANCE = 100_000_000e18;
    uint256 constant N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    function setUp() public {
        vm.warp(1_760_000_000);
        signer = vm.addr(signerPk);
        tok = new DustyToken(admin, 0, guardian, 0);
        rec = new DustyRecycler(admin, 0, guardian, address(tok), treasury, signer, 500);
        usdc = new MockUSDC();
        vm.startPrank(admin);
        tok.setMinter(address(rec), true, RECYCLER_ALLOWANCE);
        rec.setAllowedToken(address(usdc), true);
        vm.stopPrank();
        usdc.mint(user, 100e6);
    }

    // ---------- helpers ----------
    function _sign(uint256 pk, address u, address t, uint256 a, uint256 out, uint16 fee, uint256 n, uint256 d)
        internal view returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, rec.quoteDigest(u, t, a, out, fee, n, d));
        return abi.encodePacked(r, s, v);
    }
    function _quote(address u, uint256 a, uint256 out) internal view returns (bytes memory, uint256) {
        uint256 d = block.timestamp + 600;
        return (_sign(signerPk, u, address(usdc), a, out, rec.feeBps(), rec.nonces(u), d), d);
    }
    function _approve(address u, address t, uint256 a) internal { vm.prank(u); IERC20(t).approve(address(rec), a); }
    function _recycle(address u, uint256 a, uint256 out) internal {
        (bytes memory sig, uint256 d) = _quote(u, a, out);
        _approve(u, address(usdc), a);
        vm.prank(u); rec.recycle(address(usdc), a, out, d, sig);
    }

    // ---------- fee math / happy path ----------
    function test_demo_1USDC_gives_950DUSTY() public {
        uint256 amount = 1e6;                          // 1 USDC (6 decimals)
        uint256 out = amount * RATE * 1e18 / 1e6;      // same formula as the Worker -> 1000 DUSTY
        assertEq(out, 1000e18);
        _recycle(user, amount, out);
        assertEq(tok.balanceOf(user), 950e18);
        assertEq(usdc.balanceOf(treasury), 1e6);
        assertEq(tok.totalSupply(), 950e18);           // fee is never minted
        assertEq(tok.minterAllowance(address(rec)), RECYCLER_ALLOWANCE - 950e18);
        assertEq(rec.nonces(user), 1);
    }

    function testFuzz_feeMath(uint256 out, uint16 fee) public {
        fee = uint16(bound(fee, 0, 1000));
        out = bound(out, 1, 10_000e18);
        vm.prank(admin); rec.setFee(fee);
        _recycle(user, 1e6, out);
        uint256 expected = out - (out * fee) / 10_000;
        assertEq(tok.balanceOf(user), expected);
        assertGe(tok.balanceOf(user) * 10_000, out * 9_000);
    }

    // ---------- replay / nonce / expiry ----------
    function test_replay_reverts() public {
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 2e6);
        vm.prank(user); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
        vm.prank(user); vm.expectRevert(bytes("bad quote")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function testFuzz_replayAlwaysFails(uint8 k) public {
        uint256 n = bound(k, 1, 5);
        for (uint256 i; i < n; i++) _recycle(user, 1e6, 1000e18);
        // a quote signed for any already-used nonce fails
        uint256 d = block.timestamp + 600;
        bytes memory sig = _sign(signerPk, user, address(usdc), 1e6, 1000e18, 500, n - 1, d);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("bad quote")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function test_cancelNonce_invalidatesQuote() public {
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); rec.cancelNonce();
        vm.prank(user); vm.expectRevert(bytes("bad quote")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function test_otherSenderCannotUseQuote() public {
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        usdc.mint(attacker, 1e6); _approve(attacker, address(usdc), 1e6);
        vm.prank(attacker); vm.expectRevert(bytes("bad quote")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function test_expired_reverts() public {
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6); vm.warp(d + 1);
        vm.prank(user); vm.expectRevert(bytes("quote expired")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function testFuzz_deadlineTooFar(uint256 extra) public {
        extra = bound(extra, 15 minutes + 1, 365 days);
        uint256 d = block.timestamp + extra;
        bytes memory sig = _sign(signerPk, user, address(usdc), 1e6, 1000e18, 500, 0, d);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("deadline too far")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function test_deadlineExactlyMaxTTL_ok() public {
        uint256 d = block.timestamp + 15 minutes;
        bytes memory sig = _sign(signerPk, user, address(usdc), 1e6, 1000e18, 500, 0, d);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
        assertEq(tok.balanceOf(user), 950e18);
    }

    function test_tamperedAmount_reverts() public {
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("bad quote")); rec.recycle(address(usdc), 1e6, 2000e18, d, sig);
    }

    function test_highS_malleable_rejected() public {
        uint256 d = block.timestamp + 600;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, rec.quoteDigest(user, address(usdc), 1e6, 1000e18, 500, 0, d));
        bytes memory bad = abi.encodePacked(r, bytes32(N - uint256(s)), v == 27 ? uint8(28) : uint8(27));
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(); rec.recycle(address(usdc), 1e6, 1000e18, d, bad);
    }

    function testFuzz_wrongSignerRejected(uint256 pk) public {
        pk = bound(pk, 1, N - 1);
        vm.assume(pk != signerPk);
        uint256 d = block.timestamp + 600;
        bytes memory sig = _sign(pk, user, address(usdc), 1e6, 1000e18, 500, 0, d);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("bad quote")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    // ---------- L-1: fee change between quote and execution ----------
    function test_feeChangeAfterQuote_quoteFails() public {
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        vm.prank(admin); rec.setFee(1000);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("bad quote")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    // ---------- H-1: caps ----------
    function test_H1_leakedSigner_cannotMintCap() public {
        // attacker holds the signer key and deploys junk token; it is not allowlisted
        MockUSDC junk = new MockUSDC(); junk.mint(attacker, 1);
        uint256 d = block.timestamp + 600;
        bytes memory sig = _sign(signerPk, attacker, address(junk), 1, 999_999_999e18, 500, 0, d);
        vm.prank(attacker); junk.approve(address(rec), 1);
        vm.prank(attacker); vm.expectRevert(bytes("token not allowed")); rec.recycle(address(junk), 1, 999_999_999e18, d, sig);
        // with an allowlisted token, a huge quote is still rejected
        usdc.mint(attacker, 1);
        sig = _sign(signerPk, attacker, address(usdc), 1, 999_999_999e18, 500, 0, d);
        _approve(attacker, address(usdc), 1);
        vm.prank(attacker); vm.expectRevert(bytes("quote too large")); rec.recycle(address(usdc), 1, 999_999_999e18, d, sig);
    }

    function test_H1_leakedSigner_boundedByDailyCap() public {
        // attacker loops max-size quotes; total minted in one block stops at dailyMintCap
        usdc.mint(attacker, 1_000);
        _approve(attacker, address(usdc), 1_000);
        uint256 per = rec.maxDustyPerQuote();
        uint256 cap = rec.dailyMintCap();
        uint256 i;
        for (; i < 200; i++) {
            uint256 d = block.timestamp + 600;
            bytes memory sig = _sign(signerPk, attacker, address(usdc), 1, per, 500, rec.nonces(attacker), d);
            vm.prank(attacker);
            try rec.recycle(address(usdc), 1, per, d, sig) {} catch { break; }
        }
        assertEq(i, cap / per);
        assertLe(tok.balanceOf(attacker), cap);
        assertEq(rec.dailyMintRemaining(), 0);
    }

    function test_rollingCap_refills() public {
        vm.prank(admin); rec.setLimits(10_000e18, 20_000e18);
        _recycle(user, 1e6, 10_000e18);
        _recycle(user, 1e6, 10_000e18);
        assertEq(rec.dailyMintRemaining(), 0);
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("daily cap")); rec.recycle(address(usdc), 1e6, 1e18, d, sig);
        vm.warp(block.timestamp + 12 hours);           // half the window -> half the cap back
        assertEq(rec.dailyMintRemaining(), 10_000e18);
        _recycle(user, 1e6, 10_000e18);
        vm.warp(block.timestamp + 1 days);
        assertEq(rec.dailyMintRemaining(), 20_000e18);
    }

    function testFuzz_rollingCap_neverExceeded(uint256 seed) public {
        vm.prank(admin); rec.setLimits(5_000e18, 50_000e18);
        uint256 minted;
        for (uint256 i; i < 40; i++) {
            seed = uint256(keccak256(abi.encode(seed, i)));
            vm.warp(block.timestamp + (seed % 3 hours));
            uint256 out = 1e18 + (seed >> 32) % 4_999e18; // <= maxDustyPerQuote
            uint256 remaining = rec.dailyMintRemaining();
            (bytes memory sig, uint256 d) = _quote(user, 1, out);
            _approve(user, address(usdc), 1);
            vm.prank(user);
            try rec.recycle(address(usdc), 1, out, d, sig) {
                assertLe(out, remaining);
                minted += out;
            } catch {
                assertGt(out, remaining);
            }
            assertLe(rec.windowUsed(), rec.dailyMintCap());
        }
    }

    function test_setLimits_hardCeilings() public {
        vm.startPrank(admin);
        vm.expectRevert(bytes("perQuote out of range")); rec.setLimits(100_001e18, 1_000_000e18);
        vm.expectRevert(bytes("perQuote out of range")); rec.setLimits(0, 1_000_000e18);
        vm.expectRevert(bytes("perDay out of range")); rec.setLimits(10_000e18, 10_000_001e18);
        vm.expectRevert(bytes("perDay out of range")); rec.setLimits(10_000e18, 9_999e18);
        rec.setLimits(100_000e18, 10_000_000e18);
        vm.stopPrank();
        assertEq(rec.maxDustyPerQuote(), 100_000e18);
    }

    function testFuzz_setLimits_withinCeilings(uint256 q, uint256 dcap) public {
        q = bound(q, 1, 100_000e18);
        dcap = bound(dcap, q, 10_000_000e18);
        vm.prank(admin); rec.setLimits(q, dcap);
        assertEq(rec.maxDustyPerQuote(), q);
        assertEq(rec.dailyMintCap(), dcap);
    }

    function test_tokenMinterAllowance_bounds_recycler() public {
        vm.prank(admin); tok.setMinter(address(rec), true, 1500e18);
        _recycle(user, 1e6, 1000e18);               // 950 minted, 550 left
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("DUSTY: minter allowance")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function test_capEnforced() public {
        address m = address(0x3141);
        vm.prank(admin); tok.setMinter(m, true, type(uint256).max);
        vm.prank(m); tok.mintReward(user, 1_000_000_000e18, bytes32(0));
        vm.prank(m); vm.expectRevert(); tok.mintReward(user, 1, bytes32(0));
    }

    function test_allowlist_removal() public {
        vm.prank(admin); rec.setAllowedToken(address(usdc), false);
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(bytes("token not allowed")); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    // ---------- M-1 ----------
    function test_feeOnTransfer_rejected() public {
        FeeOnTransfer f = new FeeOnTransfer(); f.mint(user, 100e18);
        vm.prank(admin); rec.setAllowedToken(address(f), true);
        uint256 d = block.timestamp + 600;
        bytes memory sig = _sign(signerPk, user, address(f), 10e18, 1000e18, 500, 0, d);
        _approve(user, address(f), 10e18);
        vm.prank(user); vm.expectRevert(bytes("fee-on-transfer token")); rec.recycle(address(f), 10e18, 1000e18, d, sig);
    }

    // ---------- pause ----------
    function test_guardianPauses_adminUnpauses() public {
        vm.prank(guardian); rec.pause();
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(Pausable.EnforcedPause.selector); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
        vm.prank(guardian); vm.expectRevert(); rec.unpause();     // guardian cannot unpause
        vm.prank(admin); rec.unpause();
        vm.prank(user); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
        assertEq(tok.balanceOf(user), 950e18);
    }

    function test_tokenMintPause_stopsAllMinters() public {
        vm.prank(guardian); tok.pauseMinting();
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(Pausable.EnforcedPause.selector); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
        // transfers still work while minting is paused
        vm.prank(guardian); vm.expectRevert(); tok.unpauseMinting();
        vm.prank(admin); tok.unpauseMinting();
        vm.prank(user); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
        vm.prank(guardian); tok.pauseMinting();
        vm.prank(user); tok.transfer(attacker, 1e18);
        assertEq(tok.balanceOf(attacker), 1e18);
    }

    function test_attackerCannotPause() public {
        vm.prank(attacker); vm.expectRevert(); rec.pause();
        vm.prank(attacker); vm.expectRevert(); tok.pauseMinting();
    }

    // ---------- H-2: role separation ----------
    function test_adminCannotMintDirectly() public {
        vm.prank(admin); vm.expectRevert(); tok.mintReward(admin, 1e18, bytes32(0));
    }

    function test_nonMinterCannotMint() public {
        vm.prank(attacker); vm.expectRevert(); tok.mintReward(attacker, 1, bytes32(0));
    }

    function testFuzz_onlyAdminSetters(address who) public {
        vm.assume(who != admin);
        vm.startPrank(who);
        vm.expectRevert(); rec.setTreasury(who);
        vm.expectRevert(); rec.setQuoteSigner(who);
        vm.expectRevert(); rec.setFee(0);
        vm.expectRevert(); rec.setLimits(1, 1);
        vm.expectRevert(); rec.setAllowedToken(who, true);
        vm.expectRevert(); rec.rescue(address(usdc), 1);
        vm.expectRevert(); rec.unpause();
        vm.expectRevert(); tok.setMinter(who, true, 1);
        vm.expectRevert(); tok.unpauseMinting();
        vm.stopPrank();
    }

    function test_signerCannotBeAdminTreasuryOrPauser() public {
        vm.startPrank(admin);
        vm.expectRevert(bytes("signer == admin")); rec.setQuoteSigner(admin);
        vm.expectRevert(bytes("signer == treasury")); rec.setQuoteSigner(treasury);
        vm.expectRevert(bytes("signer is pauser")); rec.setQuoteSigner(guardian);
        vm.expectRevert(bytes("treasury == signer")); rec.setTreasury(signer);
        bytes32 pr = rec.PAUSER_ROLE();
        vm.expectRevert(bytes("signer cannot hold roles")); rec.grantRole(pr, signer);
        vm.expectRevert(bytes("signer cannot be admin")); rec.beginDefaultAdminTransfer(signer);
        vm.stopPrank();
    }

    function test_constructorRejectsSignerEqualsAdmin() public {
        vm.expectRevert(bytes("signer == admin"));
        new DustyRecycler(admin, 0, guardian, address(tok), treasury, admin, 500);
        vm.expectRevert(bytes("signer == treasury"));
        new DustyRecycler(admin, 0, guardian, address(tok), treasury, treasury, 500);
        vm.expectRevert(bytes("signer is pauser"));
        new DustyRecycler(admin, 0, guardian, address(tok), treasury, guardian, 500);
        vm.expectRevert(bytes("fee too high"));
        new DustyRecycler(admin, 0, guardian, address(tok), treasury, signer, 1001);
        vm.expectRevert(bytes("token not contract"));
        new DustyRecycler(admin, 0, guardian, address(0x1234), treasury, signer, 500);
    }

    function test_separateSetters_work() public {
        address newT = address(0x7EA6); address newS = address(0x5160);
        vm.startPrank(admin);
        rec.setTreasury(newT); rec.setQuoteSigner(newS);
        vm.stopPrank();
        assertEq(rec.treasury(), newT); assertEq(rec.quoteSigner(), newS);
    }

    function test_twoStepAdminTransfer_toSafe() public {
        // delay 0 on testnet; still requires the new admin to accept
        vm.prank(admin); rec.beginDefaultAdminTransfer(safe);
        assertEq(rec.owner(), admin);
        vm.prank(attacker); vm.expectRevert(); rec.acceptDefaultAdminTransfer();
        vm.warp(block.timestamp + 1);
        vm.prank(safe); rec.acceptDefaultAdminTransfer();
        assertEq(rec.owner(), safe);
        assertEq(rec.defaultAdmin(), safe);
        vm.prank(admin); vm.expectRevert(); rec.setFee(0);
        vm.prank(safe); rec.setFee(0);
    }

    function test_twoStepAdminTransfer_withDelay() public {
        DustyToken t2 = new DustyToken(admin, 2 days, guardian, 0);
        vm.prank(admin); t2.beginDefaultAdminTransfer(safe);
        vm.prank(safe); vm.expectRevert(); t2.acceptDefaultAdminTransfer();
        vm.warp(block.timestamp + 2 days + 1);
        vm.prank(safe); t2.acceptDefaultAdminTransfer();
        assertEq(t2.owner(), safe);
    }

    function test_adminRoleCannotBeGrantedDirectly() public {
        bytes32 a = tok.DEFAULT_ADMIN_ROLE();
        vm.prank(admin); vm.expectRevert(); tok.grantRole(a, attacker);
    }

    function test_revokeMinter() public {
        vm.prank(admin); tok.setMinter(address(rec), false, 123);
        assertEq(tok.minterAllowance(address(rec)), 0);
        assertFalse(tok.isMinter(address(rec)));
        (bytes memory sig, uint256 d) = _quote(user, 1e6, 1000e18);
        _approve(user, address(usdc), 1e6);
        vm.prank(user); vm.expectRevert(); rec.recycle(address(usdc), 1e6, 1000e18, d, sig);
    }

    function test_rescue_goesToTreasury() public {
        usdc.mint(address(rec), 5e6);
        vm.prank(admin); rec.rescue(address(usdc), 5e6);
        assertEq(usdc.balanceOf(treasury), 5e6);
    }

    // Signature produced by ethers v6 signTypedData with the exact TYPES_V2 / domain used in workers/dusty-quote.js
    // (pk 0xB0B, chainId 31337, verifyingContract = this test's recycler). Proves Worker <-> contract encoding match.
    function test_workerEthersSignature_accepted() public {
        assertEq(address(rec), 0x2e234DAe75C793f67A35089C9d99245E1C58470b);
        assertEq(rec.quoteDigest(user, address(usdc), 1e6, 1000e18, 500, 0, 1_760_000_600),
            0x7f4b74b1f580a6227a1eb1f4f5b1c4582d93b9ed8cd4e76f075856c6eeea5263);
        bytes memory sig = hex"b8790a896926da542caad0f994587db3360e15953480d25294588c131526d408049d1e1a06d6a4b0d45714cbdb36fbdfcaca94bead6b77b1b8493fc6524635281c";
        _approve(user, address(usdc), 1e6);
        vm.prank(user); rec.recycle(address(usdc), 1e6, 1000e18, 1_760_000_600, sig);
        assertEq(tok.balanceOf(user), 950e18);
    }

    function test_initialSupply() public {
        DustyToken t2 = new DustyToken(admin, 0, guardian, 1000);
        assertEq(t2.balanceOf(admin), 1000e18);
    }
}
