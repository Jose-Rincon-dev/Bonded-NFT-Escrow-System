// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./BondedNFT.sol";
import "./StakingPool.sol";
import "./GovernanceWallet.sol";

/**
 * @title BondEscrow
 * @dev Main escrow contract for bonded NFT system
 */
contract BondEscrow is Ownable, ReentrancyGuard {
    IERC20 public paymentToken;
    BondedNFT public bondedNFT;
    StakingPool public stakingPool;
    GovernanceWallet public governanceWallet;
    
    struct Bond {
        uint256 id;
        address issuer;
        string assetType;
        uint256 bondAmount;
        uint256 duration;
        uint256 quantity;
        uint256 remainingQuantity;
        uint256 createdAt;
        bool isActive;
    }
    
    struct PostedBond {
        uint256 bondId;
        address poster;
        uint256 amount;
        uint256 postedAt;
        uint256 expiryTime;
        bool isActive;
        address affiliate;
    }
    
    mapping(uint256 => Bond) public bonds;
    mapping(uint256 => PostedBond) public postedBonds;
    mapping(address => uint256[]) public userBonds;
    mapping(address => uint256[]) public userPostedBonds;
    
    uint256 public bondCounter;
    uint256 public postedBondCounter;
    
    // Fee structure
    uint256 public governanceFeeRate = 500; // 5% (500 basis points)
    uint256 public affiliateFeeRate = 200; // 2% (200 basis points)
    uint256 public constant BASIS_POINTS = 10000;
    
    event BondIssued(uint256 indexed bondId, address indexed issuer, string assetType, uint256 amount, uint256 quantity);
    event BondPosted(uint256 indexed postedBondId, uint256 indexed bondId, address indexed poster, uint256 amount);
    event BondExpired(uint256 indexed postedBondId, address indexed holder);
    event LeakAdjudicated(uint256 indexed postedBondId, address indexed issuer, uint256 amount);
    event AffiliateRewardPaid(address indexed affiliate, uint256 amount);
    
    constructor(
        address _paymentToken,
        address _bondedNFT,
        address _stakingPool,
        address _governanceWallet,
        address initialOwner
    ) Ownable(initialOwner) {
        paymentToken = IERC20(_paymentToken);
        bondedNFT = BondedNFT(_bondedNFT);
        stakingPool = StakingPool(_stakingPool);
        governanceWallet = GovernanceWallet(_governanceWallet);
    }
    
    function issueBond(
        string memory assetType,
        uint256 bondAmount,
        uint256 duration,
        uint256 quantity
    ) external returns (uint256) {
        require(bondAmount > 0, "Bond amount must be positive");
        require(duration > 0, "Duration must be positive");
        require(quantity > 0, "Quantity must be positive");
        
        uint256 bondId = bondCounter++;
        
        bonds[bondId] = Bond({
            id: bondId,
            issuer: msg.sender,
            assetType: assetType,
            bondAmount: bondAmount,
            duration: duration,
            quantity: quantity,
            remainingQuantity: quantity,
            createdAt: block.timestamp,
            isActive: true
        });
        
        userBonds[msg.sender].push(bondId);
        
        emit BondIssued(bondId, msg.sender, assetType, bondAmount, quantity);
        return bondId;
    }
    
    function postBond(uint256 bondId, address affiliate) external nonReentrant returns (uint256) {
        Bond storage bond = bonds[bondId];
        require(bond.isActive, "Bond not active");
        require(bond.remainingQuantity > 0, "No bonds available");
        
        uint256 amount = bond.bondAmount;
        require(paymentToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        
        uint256 postedBondId = postedBondCounter++;
        uint256 expiryTime = block.timestamp + bond.duration;
        
        postedBonds[postedBondId] = PostedBond({
            bondId: bondId,
            poster: msg.sender,
            amount: amount,
            postedAt: block.timestamp,
            expiryTime: expiryTime,
            isActive: true,
            affiliate: affiliate
        });
        
        bond.remainingQuantity--;
        userPostedBonds[msg.sender].push(postedBondId);
        
        // Mint NFT
        string memory tokenURI = string(abi.encodePacked("bond-", toString(postedBondId)));
        bondedNFT.mintBondNFT(
            msg.sender,
            postedBondId,
            bond.issuer,
            amount,
            expiryTime,
            bond.assetType,
            tokenURI
        );
        
        // Start staking
        stakingPool.stake(postedBondId, amount);
        
        // Pay affiliate fee if applicable
        if (affiliate != address(0) && affiliate != msg.sender) {
            uint256 affiliateReward = (amount * affiliateFeeRate) / BASIS_POINTS;
            require(paymentToken.transfer(affiliate, affiliateReward), "Affiliate payment failed");
            emit AffiliateRewardPaid(affiliate, affiliateReward);
        }
        
        emit BondPosted(postedBondId, bondId, msg.sender, amount);
        return postedBondId;
    }
    
    function claimExpiredBond(uint256 postedBondId) external nonReentrant {
        PostedBond storage postedBond = postedBonds[postedBondId];
        require(postedBond.isActive, "Bond not active");
        require(block.timestamp >= postedBond.expiryTime, "Bond not expired");
        
        // Get current NFT holder
        uint256 tokenId = bondedNFT.getTokenIdByBondId(postedBondId);
        address currentHolder = bondedNFT.ownerOf(tokenId);
        
        // Unstake and get rewards
        (uint256 stakedAmount, uint256 rewards) = stakingPool.unstake(postedBondId);
        
        // Calculate fee distribution
        uint256 governanceFee = (rewards * governanceFeeRate) / BASIS_POINTS;
        uint256 holderReward = stakedAmount + rewards - governanceFee;
        
        // Transfer funds
        require(paymentToken.transfer(currentHolder, holderReward), "Transfer to holder failed");
        require(paymentToken.transfer(address(governanceWallet), governanceFee), "Governance fee transfer failed");
        
        // Deactivate bond and NFT
        postedBond.isActive = false;
        bondedNFT.deactivateBond(tokenId);
        
        emit BondExpired(postedBondId, currentHolder);
    }
    
    function adjudicateLeak(uint256 proposalId) external nonReentrant {
        bool approved = governanceWallet.executeProposal(proposalId);
        require(approved, "Proposal not approved");
        
        (uint256 bondId, , , , , , ) = governanceWallet.getProposalInfo(proposalId);
        PostedBond storage postedBond = postedBonds[bondId];
        require(postedBond.isActive, "Bond not active");
        
        Bond storage bond = bonds[postedBond.bondId];
        
        // Unstake and get total amount
        (uint256 stakedAmount, uint256 rewards) = stakingPool.unstake(bondId);
        uint256 totalAmount = stakedAmount + rewards;
        
        // Transfer all funds to bond issuer
        require(paymentToken.transfer(bond.issuer, totalAmount), "Transfer to issuer failed");
        
        // Deactivate bond and NFT
        postedBond.isActive = false;
        uint256 tokenId = bondedNFT.getTokenIdByBondId(bondId);
        bondedNFT.deactivateBond(tokenId);
        
        emit LeakAdjudicated(bondId, bond.issuer, totalAmount);
    }
    
    function getBond(uint256 bondId) external view returns (Bond memory) {
        return bonds[bondId];
    }
    
    function getPostedBond(uint256 postedBondId) external view returns (PostedBond memory) {
        return postedBonds[postedBondId];
    }
    
    function getUserBonds(address user) external view returns (uint256[] memory) {
        return userBonds[user];
    }
    
    function getUserPostedBonds(address user) external view returns (uint256[] memory) {
        return userPostedBonds[user];
    }
    
    function setFeeRates(uint256 _governanceFeeRate, uint256 _affiliateFeeRate) external onlyOwner {
        require(_governanceFeeRate <= 1000, "Governance fee too high"); // Max 10%
        require(_affiliateFeeRate <= 500, "Affiliate fee too high"); // Max 5%
        governanceFeeRate = _governanceFeeRate;
        affiliateFeeRate = _affiliateFeeRate;
    }
    
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}