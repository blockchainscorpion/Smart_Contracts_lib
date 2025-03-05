// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


// The GovernanceToken contract represents the token used for voting in the DAO
contract GovernanceToken is ERC20, AccessControl {
    // Role identifier for minting tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    // Role identifier for managing KYC status
    bytes32 public constant KYC_ROLE = keccak256("KYC_ROLE");

    // Total amount of tokens (1 billion)
    uint public tokenAmount = 1000000000;

    // Mapping to store KYC approval status for each address
    mapping(address => bool) public kycApproved;

    // Constructor to initialize the token with a name and symbol
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(KYC_ROLE, msg.sender);
    }

    // Function to mint new tokens (only callable by addresses with MINTER_ROLE)
    function mint(address to, uint256 amount) public {
        if (!hasRole(MINTER_ROLE, msg.sender)) {
            revert(string(abi.encodePacked("AccessControl: account ", Strings.toHexString(uint160(msg.sender), 20), " is missing role ", Strings.toHexString(uint256(MINTER_ROLE), 32))));
        }
        _mint(to, amount);
    }

    // Function to set KYC status for an account (only callable by addresses with KYC_ROLE)
    function setKYCStatus(address account, bool status) public onlyRole(KYC_ROLE) {
        kycApproved[account] = status;
    }

    // Override the transfer function to include KYC checks
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(kycApproved[_msgSender()] && kycApproved[recipient], "KYC not approved");
        return super.transfer(recipient, amount);
    }

    // Override the transferFrom function to include KYC checks
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(kycApproved[sender] && kycApproved[recipient], "KYC not approved");
        return super.transferFrom(sender, recipient, amount);
    }
}