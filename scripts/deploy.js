const { ethers } = require("hardhat");

async function main() {
  console.log("Starting deployment...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with account:", deployer.address);
  
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");
  
  // Deploy Mock ERC20 Token (for testing)
  console.log("\n1. Deploying MockERC20...");
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const mockToken = await MockERC20.deploy(
    "Bond Token",
    "BOND",
    1000000, // 1M tokens
    deployer.address
  );
  await mockToken.waitForDeployment();
  const mockTokenAddress = await mockToken.getAddress();
  console.log("MockERC20 deployed to:", mockTokenAddress);
  
  // Deploy BondedNFT
  console.log("\n2. Deploying BondedNFT...");
  const BondedNFT = await ethers.getContractFactory("BondedNFT");
  const bondedNFT = await BondedNFT.deploy(deployer.address);
  await bondedNFT.waitForDeployment();
  const bondedNFTAddress = await bondedNFT.getAddress();
  console.log("BondedNFT deployed to:", bondedNFTAddress);
  
  // Deploy StakingPool
  console.log("\n3. Deploying StakingPool...");
  const StakingPool = await ethers.getContractFactory("StakingPool");
  const stakingPool = await StakingPool.deploy(mockTokenAddress, deployer.address);
  await stakingPool.waitForDeployment();
  const stakingPoolAddress = await stakingPool.getAddress();
  console.log("StakingPool deployed to:", stakingPoolAddress);
  
  // Deploy GovernanceWallet
  console.log("\n4. Deploying GovernanceWallet...");
  const GovernanceWallet = await ethers.getContractFactory("GovernanceWallet");
  const governanceWallet = await GovernanceWallet.deploy(deployer.address);
  await governanceWallet.waitForDeployment();
  const governanceWalletAddress = await governanceWallet.getAddress();
  console.log("GovernanceWallet deployed to:", governanceWalletAddress);
  
  // Deploy BondEscrow
  console.log("\n5. Deploying BondEscrow...");
  const BondEscrow = await ethers.getContractFactory("BondEscrow");
  const bondEscrow = await BondEscrow.deploy(
    mockTokenAddress,
    bondedNFTAddress,
    stakingPoolAddress,
    governanceWalletAddress,
    deployer.address
  );
  await bondEscrow.waitForDeployment();
  const bondEscrowAddress = await bondEscrow.getAddress();
  console.log("BondEscrow deployed to:", bondEscrowAddress);
  
  // Setup permissions
  console.log("\n6. Setting up permissions...");
  
  // Set BondEscrow as owner of BondedNFT
  await bondedNFT.transferOwnership(bondEscrowAddress);
  console.log("BondedNFT ownership transferred to BondEscrow");
  
  // Set BondEscrow as owner of StakingPool
  await stakingPool.transferOwnership(bondEscrowAddress);
  console.log("StakingPool ownership transferred to BondEscrow");
  
  // Set BondEscrow as the escrow contract in GovernanceWallet
  await governanceWallet.setEscrowContract(bondEscrowAddress);
  console.log("GovernanceWallet escrow contract set");
  
  // Transfer some tokens to BondEscrow for staking rewards
  const rewardAmount = ethers.parseEther("10000"); // 10k tokens for rewards
  await mockToken.transfer(stakingPoolAddress, rewardAmount);
  console.log("Transferred reward tokens to StakingPool");
  
  console.log("\n=== DEPLOYMENT SUMMARY ===");
  console.log("MockERC20:", mockTokenAddress);
  console.log("BondedNFT:", bondedNFTAddress);
  console.log("StakingPool:", stakingPoolAddress);
  console.log("GovernanceWallet:", governanceWalletAddress);
  console.log("BondEscrow:", bondEscrowAddress);
  console.log("\n=== SETUP COMPLETE ===");
  
  // Save deployment addresses
  const deploymentInfo = {
    network: await ethers.provider.getNetwork(),
    deployer: deployer.address,
    contracts: {
      MockERC20: mockTokenAddress,
      BondedNFT: bondedNFTAddress,
      StakingPool: stakingPoolAddress,
      GovernanceWallet: governanceWalletAddress,
      BondEscrow: bondEscrowAddress
    },
    timestamp: new Date().toISOString()
  };
  
  console.log("\nDeployment info:", JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });