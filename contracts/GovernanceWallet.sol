// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title GovernanceWallet
 * @dev Multi-signature governance wallet for adjudication decisions
 */
contract GovernanceWallet is AccessControl, ReentrancyGuard {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ADJUDICATOR_ROLE = keccak256("ADJUDICATOR_ROLE");
    
    struct AdjudicationProposal {
        uint256 bondId;
        address proposer;
        string evidence;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 deadline;
        mapping(address => bool) hasVoted;
        mapping(address => bool) vote; // true = for, false = against
    }
    
    mapping(uint256 => AdjudicationProposal) public proposals;
    uint256 public proposalCounter;
    uint256 public votingPeriod = 7 days;
    uint256 public requiredVotes = 2; // Minimum votes needed
    
    address public escrowContract;
    
    event ProposalCreated(uint256 indexed proposalId, uint256 indexed bondId, address proposer);
    event VoteCast(uint256 indexed proposalId, address voter, bool support);
    event ProposalExecuted(uint256 indexed proposalId, bool approved);
    
    modifier onlyEscrow() {
        require(msg.sender == escrowContract, "Only escrow contract");
        _;
    }
    
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(GOVERNOR_ROLE, admin);
        _grantRole(ADJUDICATOR_ROLE, admin);
    }
    
    function setEscrowContract(address _escrowContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        escrowContract = _escrowContract;
    }
    
    function addGovernor(address governor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(GOVERNOR_ROLE, governor);
        _grantRole(ADJUDICATOR_ROLE, governor);
    }
    
    function removeGovernor(address governor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(GOVERNOR_ROLE, governor);
        _revokeRole(ADJUDICATOR_ROLE, governor);
    }
    
    function createAdjudicationProposal(
        uint256 bondId,
        string memory evidence
    ) external onlyRole(ADJUDICATOR_ROLE) returns (uint256) {
        uint256 proposalId = proposalCounter++;
        
        AdjudicationProposal storage proposal = proposals[proposalId];
        proposal.bondId = bondId;
        proposal.proposer = msg.sender;
        proposal.evidence = evidence;
        proposal.deadline = block.timestamp + votingPeriod;
        
        emit ProposalCreated(proposalId, bondId, msg.sender);
        return proposalId;
    }
    
    function vote(uint256 proposalId, bool support) external onlyRole(ADJUDICATOR_ROLE) {
        AdjudicationProposal storage proposal = proposals[proposalId];
        
        require(block.timestamp <= proposal.deadline, "Voting period ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");
        require(!proposal.executed, "Proposal already executed");
        
        proposal.hasVoted[msg.sender] = true;
        proposal.vote[msg.sender] = support;
        
        if (support) {
            proposal.votesFor++;
        } else {
            proposal.votesAgainst++;
        }
        
        emit VoteCast(proposalId, msg.sender, support);
    }
    
    function executeProposal(uint256 proposalId) external returns (bool) {
        AdjudicationProposal storage proposal = proposals[proposalId];
        
        require(block.timestamp > proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votesFor + proposal.votesAgainst >= requiredVotes, "Not enough votes");
        
        proposal.executed = true;
        bool approved = proposal.votesFor > proposal.votesAgainst;
        
        emit ProposalExecuted(proposalId, approved);
        return approved;
    }
    
    function getProposalInfo(uint256 proposalId) external view returns (
        uint256 bondId,
        address proposer,
        string memory evidence,
        bool executed,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 deadline
    ) {
        AdjudicationProposal storage proposal = proposals[proposalId];
        return (
            proposal.bondId,
            proposal.proposer,
            proposal.evidence,
            proposal.executed,
            proposal.votesFor,
            proposal.votesAgainst,
            proposal.deadline
        );
    }
    
    function hasVoted(uint256 proposalId, address voter) external view returns (bool) {
        return proposals[proposalId].hasVoted[voter];
    }
    
    function getVote(uint256 proposalId, address voter) external view returns (bool) {
        require(proposals[proposalId].hasVoted[voter], "Voter has not voted");
        return proposals[proposalId].vote[voter];
    }
    
    function setVotingPeriod(uint256 _votingPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        votingPeriod = _votingPeriod;
    }
    
    function setRequiredVotes(uint256 _requiredVotes) external onlyRole(DEFAULT_ADMIN_ROLE) {
        requiredVotes = _requiredVotes;
    }
}