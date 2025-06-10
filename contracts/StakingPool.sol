// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title StakingPool
 * @dev Simple staking mechanism for escrowed assets
 */
contract StakingPool is Ownable, ReentrancyGuard {
    IERC20 public stakingToken;
    
    struct StakeInfo {
        uint256 amount;
        uint256 startTime;
        uint256 lastRewardTime;
        uint256 accumulatedRewards;
    }
    
    mapping(uint256 => StakeInfo) public stakes; // bondId => StakeInfo
    mapping(address => uint256) public totalStakedByUser;
    
    uint256 public totalStaked;
    uint256 public rewardRate = 100; // 1% per year (100 basis points)
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BASIS_POINTS = 10000;
    
    event Staked(uint256 indexed bondId, uint256 amount);
    event RewardCalculated(uint256 indexed bondId, uint256 reward);
    event Unstaked(uint256 indexed bondId, uint256 amount, uint256 reward);
    
    constructor(address _stakingToken, address initialOwner) Ownable(initialOwner) {
        stakingToken = IERC20(_stakingToken);
    }
    
    function stake(uint256 bondId, uint256 amount) external onlyOwner {
        require(amount > 0, "Cannot stake 0");
        
        StakeInfo storage stakeInfo = stakes[bondId];
        
        if (stakeInfo.amount > 0) {
            // Calculate and add pending rewards
            uint256 pendingReward = calculateReward(bondId);
            stakeInfo.accumulatedRewards += pendingReward;
        }
        
        stakeInfo.amount += amount;
        stakeInfo.startTime = block.timestamp;
        stakeInfo.lastRewardTime = block.timestamp;
        
        totalStaked += amount;
        
        emit Staked(bondId, amount);
    }
    
    function calculateReward(uint256 bondId) public view returns (uint256) {
        StakeInfo memory stakeInfo = stakes[bondId];
        
        if (stakeInfo.amount == 0) {
            return 0;
        }
        
        uint256 timeStaked = block.timestamp - stakeInfo.lastRewardTime;
        uint256 reward = (stakeInfo.amount * rewardRate * timeStaked) / (BASIS_POINTS * SECONDS_PER_YEAR);
        
        return reward;
    }
    
    function getTotalRewards(uint256 bondId) external view returns (uint256) {
        StakeInfo memory stakeInfo = stakes[bondId];
        return stakeInfo.accumulatedRewards + calculateReward(bondId);
    }
    
    function unstake(uint256 bondId) external onlyOwner returns (uint256, uint256) {
        StakeInfo storage stakeInfo = stakes[bondId];
        require(stakeInfo.amount > 0, "No stake found");
        
        uint256 pendingReward = calculateReward(bondId);
        uint256 totalReward = stakeInfo.accumulatedRewards + pendingReward;
        uint256 stakedAmount = stakeInfo.amount;
        
        totalStaked -= stakedAmount;
        
        // Reset stake info
        delete stakes[bondId];
        
        emit RewardCalculated(bondId, totalReward);
        emit Unstaked(bondId, stakedAmount, totalReward);
        
        return (stakedAmount, totalReward);
    }
    
    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        require(_rewardRate <= 5000, "Reward rate too high"); // Max 50%
        rewardRate = _rewardRate;
    }
    
    function getStakeInfo(uint256 bondId) external view returns (StakeInfo memory) {
        return stakes[bondId];
    }
}