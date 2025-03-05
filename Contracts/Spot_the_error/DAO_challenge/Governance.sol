// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./GovernanceToken.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// The Governance contract manages the DAO's decision-making processes
contract Governance is AccessControl {
    // Reference to the associated GovernanceToken contract
    GovernanceToken public governanceToken;

    // Struct to store member information
    struct Member {
        bool isApproved; // Whether the member is approved to participate
        bool hasPassedKYC; // Whether the member has passed KYC checks
        uint256 votingPower; // Additional voting power assigned to the member
    }

    // Struct to store proposal information
    struct Proposal {
        uint256 id; // Unique identifier for the proposal
        address proposer; // Address of the member who created the proposal
        string description; // Description of the proposal
        uint256 forVotes; // Number of votes in favor
        uint256 againstVotes; // Number of votes against
        uint256 startTime; // Timestamp when the proposal was created
        bool executed; // Whether the proposal has been executed
    }

    // Mapping to store member information
    mapping(address => Member) public members;
    // Mapping to store proposal information
    mapping(uint256 => Proposal) public proposals;
    // Mapping to track if a member has voted on a specific proposal
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    // Mapping to store delegation information
    mapping(address => address) public delegates;

    // Counter for the number of proposals
    uint256 public proposalCount;
    // Duration of the voting period (default: 3 days)
    uint256 public votingPeriod = 3 days;
    // Percentage of total voting power required for quorum (default: 10%)
    uint256 public quorumPercentage = 10;

    // Role identifier for admin functions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Memner list
    address[] public memberList;

    // Events
    event MemberAdded(address member);
    event MemberRemoved(address member);
    event KYCStatusUpdated(address member, bool status);
    event ProposalCreated(
        uint256 indexed proposalId,
        address proposer,
        string description
    );
    event Voted(
        uint256 indexed proposalId,
        address voter,
        bool support,
        uint256 weight
    );
    event ProposalExecuted(uint256 indexed proposalId);
    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );

    // Constructor to initialize the contract with the GovernanceToken address
    constructor(address _governanceToken, uint256 _votingPeriod) {
        governanceToken = GovernanceToken(_governanceToken);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        votingPeriod = _votingPeriod;
    }

    // Function to add a new member (only callable by admin)
    function addMember(
        address _member,
        uint256 _votingPower
    ) external onlyRole(ADMIN_ROLE) {
        require(!members[_member].isApproved, "Member already exists");
        members[_member] = Member(true, false, _votingPower);
        memberList.push(_member);
        emit MemberAdded(_member);
    }

    // Function to remove a member (only callable by admin)
    function removeMember(address _member) external onlyRole(ADMIN_ROLE) {
        require(members[_member].isApproved, "Member does not exist");
        delete members[_member];
        emit MemberRemoved(_member);
    }

    // Function to update a member's KYC status (only callable by admin)
    function updateKYCStatus(
        address _member,
        bool _status
    ) external onlyRole(ADMIN_ROLE) {
        require(members[_member].isApproved, "Member does not exist");
        members[_member].hasPassedKYC = _status;
        governanceToken.setKYCStatus(_member, _status);
        emit KYCStatusUpdated(_member, _status);
    }

    // Function to create a new proposal
    function createProposal(string memory _description) external {
        require(members[msg.sender].isApproved, "Not a member");
        require(members[msg.sender].hasPassedKYC, "KYC not passed");
        require(votingPower(msg.sender) > 0, "No voting power");

        uint256 proposalId = proposalCount++;
        proposals[proposalId] = Proposal({
            id: proposalId,
            proposer: msg.sender,
            description: _description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            executed: false
        });

        emit ProposalCreated(proposalId, msg.sender, _description);
    }

    // Function to vote on a proposal
    function vote(uint256 _proposalId, bool _support) external {
        require(members[msg.sender].isApproved, "Not a member");
        require(members[msg.sender].hasPassedKYC, "KYC not passed");
        require(!hasVoted[msg.sender][_proposalId], "Already voted");
        require(
            block.timestamp <= proposals[_proposalId].startTime + votingPeriod,
            "Voting period has ended"
        );

        uint256 weight = votingPower(msg.sender);
        require(weight > 0, "No voting power");

        if (_support) {
            proposals[_proposalId].forVotes += weight;
        } else {
            proposals[_proposalId].againstVotes += weight;
        }

        hasVoted[msg.sender][_proposalId] = true;
        emit Voted(_proposalId, msg.sender, _support, weight);
    }

    // Function to execute a proposal after the voting period has ended
    function executeProposal(uint256 _proposalId) external {
        Proposal storage proposal = proposals[_proposalId];
        require(
            block.timestamp > proposal.startTime + votingPeriod,
            "Voting period has not ended"
        );
        require(!proposal.executed, "Proposal already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalVotingPower = getTotalVotingPower();
        uint256 quorumVotes = (totalVotingPower * quorumPercentage) / 100;

        // console.log("Total votes: %s, Quorum votes: %s", totalVotes, quorumVotes);

        require(totalVotes >= quorumVotes, "Quorum not reached");
        require(
            proposal.forVotes > proposal.againstVotes,
            "Proposal not passed"
        );

        proposal.executed = true;
        emit ProposalExecuted(_proposalId);

        // Proposal execution...
    }

    // Calculate total voting power
    function getTotalVotingPower() public view returns (uint256) {
        uint256 totalPower = 0;
        for (uint256 i = 0; i < memberList.length; i++) {
            totalPower += votingPower(memberList[i]);
        }
        return totalPower;
    }

    // Function to delegate voting power to another address
    function delegate(address delegatee) external {
        require(members[msg.sender].isApproved, "Not a member");
        require(members[msg.sender].hasPassedKYC, "KYC not passed");
        require(delegatee != address(0), "Cannot delegate to zero address");
        address currentDelegate = delegates[msg.sender];
        delegates[msg.sender] = delegatee;
        emit DelegateChanged(msg.sender, currentDelegate, delegatee);
    }

    // Function to calculate the voting power of an account
    function votingPower(address account) public view returns (uint256) {
        address delegatee = delegates[account];
        if (delegatee == address(0)) {
            return
                governanceToken.balanceOf(account) +
                members[account].votingPower;
        } else {
            return
                governanceToken.balanceOf(delegatee) +
                members[delegatee].votingPower;
        }
    }

    // Function to set the quorum percentage (only callable by admin)
    function setQuorumPercentage(uint256 _quorumPercentage) external {
    if (!hasRole(ADMIN_ROLE, msg.sender)) {
        revert(string(abi.encodePacked("AccessControl: account ", Strings.toHexString(uint160(msg.sender), 20), " is missing role ", Strings.toHexString(uint256(ADMIN_ROLE), 32))));
    }
    require(
        _quorumPercentage > 0 && _quorumPercentage <= 100,
        "Invalid quorum percentage"
    );
    quorumPercentage = _quorumPercentage;
}

    // Function to set the voting period (only callable by admin)
    function setVotingPeriod(uint256 _votingPeriod) external {
    if (!hasRole(ADMIN_ROLE, msg.sender)) {
        revert(string(abi.encodePacked("AccessControl: account ", Strings.toHexString(uint160(msg.sender), 20), " is missing role ", Strings.toHexString(uint256(ADMIN_ROLE), 32))));
    }
    votingPeriod = _votingPeriod;
}

    // Function to set additional voting power for a member (only callable by admin)
    function setMemberVotingPower(
        address _member,
        uint256 _votingPower
    ) external onlyRole(ADMIN_ROLE) {
        require(members[_member].isApproved, "Member does not exist");
        members[_member].votingPower = _votingPower;
    }
}
