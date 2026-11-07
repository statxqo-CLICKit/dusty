// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Dusty (DUSTY) reward token.
// UNAUDITED. Deploy to Base Sepolia and test before any mainnet use.
// Compile in Remix (https://remix.ethereum.org), compiler 0.8.24+, OpenZeppelin v5 imports.

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DustyToken is ERC20, ERC20Capped, ERC20Burnable, Ownable {
    // Max supply: 1,000,000,000 DUSTY (18 decimals).
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18;

    // Addresses allowed to mint rewards (e.g. the Dusty recycler contract or backend wallet).
    mapping(address => bool) public isMinter;

    event MinterSet(address indexed minter, bool allowed);
    event Recycled(address indexed user, uint256 amount, bytes32 indexed ref);

    // initialOwner: your wallet. initialSupply: whole tokens minted to the owner at deploy (can be 0).
    constructor(address initialOwner, uint256 initialSupply)
        ERC20("Dusty", "DUSTY")
        ERC20Capped(MAX_SUPPLY)
        Ownable(initialOwner)
    {
        if (initialSupply > 0) {
            _mint(initialOwner, initialSupply * 1e18);
        }
    }

    function setMinter(address minter, bool allowed) external onlyOwner {
        isMinter[minter] = allowed;
        emit MinterSet(minter, allowed);
    }

    // Mint DUSTY to a user after their dust is recycled. ref = an id you log off-chain.
    function mintReward(address to, uint256 amount, bytes32 ref) external {
        require(isMinter[msg.sender] || msg.sender == owner(), "DUSTY: not minter");
        _mint(to, amount);
        emit Recycled(to, amount, ref);
    }

    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Capped)
    {
        super._update(from, to, value);
    }
}
