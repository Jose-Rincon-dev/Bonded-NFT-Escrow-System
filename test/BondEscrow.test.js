const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("BondEscrow System", function () {
  let mockToken, bondedNFT, stakingPool, governanceWallet, bondEscrow;
  let owner, issuer, poster, affiliate, governor;
  
  beforeEach(async function () {
    [owner, issuer, poster, affiliate, governor] = await ethers.getSigners();
    
    // Deploy MockERC20
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockToken = await MockERC20.deploy("Bond Token", "BOND", 1000000, owner.address);
    
    // Deploy BondedNFT
    const BondedNFT = await ethers.getContractFactory("BondedNFT");
    bondedNFT = await BondedNFT.deploy(owner.address);
    
    // Deploy StakingPool
    const StakingPool = await ethers.getContractFactory("StakingPool");
    stakingPool = await StakingPool.deploy(await mockToken.getAddress(), owner.address);
    
    // Deploy GovernanceWallet
    const GovernanceWallet = await ethers.getContractFactory("GovernanceWallet");
    governanceWallet = await GovernanceWallet.deploy(owner.address);
    
    // Deploy BondEscrow
    const BondEscrow = await ethers.getContractFactory("BondEscrow");
    bondEscrow = await BondEscrow.deploy(
      await mockToken.getAddress(),
      await bondedNFT.getAddress(),
      await stakingPool.getAddress(),
      await governanceWallet.getAddress(),
      owner.address
    );
    
    // Setup permissions
    await bondedNFT.transferOwnership(await bondEscrow.getAddress());
    await stakingPool.transferOwnership(await bondEscrow.getAddress());
    await governanceWallet.setEscrowContract(await bondEscrow.getAddress());
    
    // Distribute tokens
    await mockToken.transfer(poster.address, ethers.parseEther("1000"));
    await mockToken.transfer(await stakingPool.getAddress(), ethers.parseEther("10000"));
    
    // Add governor
    await governanceWallet.addGovernor(governor.address);
  });
  
  describe("Bond Issuance", function () {
    it("Should allow issuing a bond", async function () {
      const tx = await bondEscrow.connect(issuer).issueBond(
        "video",
        ethers.parseEther("100"),
        86400, // 1 day
        10
      );
      
      await expect(tx)
        .to.emit(bondEscrow, "BondIssued")
        .withArgs(0, issuer.address, "video", ethers.parseEther("100"), 10);
      
      const bond = await bondEscrow.getBond(0);
      expect(bond.issuer).to.equal(issuer.address);
      expect(bond.assetType).to.equal("video");
      expect(bond.bondAmount).to.equal(ethers.parseEther("100"));
      expect(bond.quantity).to.equal(10);
      expect(bond.remainingQuantity).to.equal(10);
      expect(bond.isActive).to.be.true;
    });
  });
  
  describe("Bond Posting", function () {
    beforeEach(async function () {
      await bondEscrow.connect(issuer).issueBond(
        "video",
        ethers.parseEther("100"),
        86400,
        10
      );
    });
    
    it("Should allow posting a bond", async function () {
      await mockToken.connect(poster).approve(await bondEscrow.getAddress(), ethers.parseEther("100"));
      
      const tx = await bondEscrow.connect(poster).postBond(0, affiliate.address);
      
      await expect(tx)
        .to.emit(bondEscrow, "BondPosted")
        .withArgs(0, 0, poster.address, ethers.parseEther("100"));
      
      const postedBond = await bondEscrow.getPostedBond(0);
      expect(postedBond.poster).to.equal(poster.address);
      expect(postedBond.amount).to.equal(ethers.parseEther("100"));
      expect(postedBond.affiliate).to.equal(affiliate.address);
      expect(postedBond.isActive).to.be.true;
      
      // Check NFT was minted
      expect(await bondedNFT.ownerOf(0)).to.equal(poster.address);
    });
    
    it("Should pay affiliate fee", async function () {
      const initialBalance = await mockToken.balanceOf(affiliate.address);
      
      await mockToken.connect(poster).approve(await bondEscrow.getAddress(), ethers.parseEther("100"));
      await bondEscrow.connect(poster).postBond(0, affiliate.address);
      
      const finalBalance = await mockToken.balanceOf(affiliate.address);
      const expectedFee = ethers.parseEther("100") * 200n / 10000n; // 2%
      
      expect(finalBalance - initialBalance).to.equal(expectedFee);
    });
  });
  
  describe("Governance and Adjudication", function () {
    beforeEach(async function () {
      await bondEscrow.connect(issuer).issueBond("video", ethers.parseEther("100"), 86400, 10);
      await mockToken.connect(poster).approve(await bondEscrow.getAddress(), ethers.parseEther("100"));
      await bondEscrow.connect(poster).postBond(0, ethers.ZeroAddress);
    });
    
    it("Should create and execute adjudication proposal", async function () {
      // Create proposal
      const tx1 = await governanceWallet.connect(governor).createAdjudicationProposal(
        0,
        "Leak evidence: watermark detected"
      );
      
      await expect(tx1)
        .to.emit(governanceWallet, "ProposalCreated")
        .withArgs(0, 0, governor.address);
      
      // Vote on proposal
      await governanceWallet.connect(governor).vote(0, true);
      
      // Fast forward time
      await ethers.provider.send("evm_increaseTime", [7 * 24 * 60 * 60 + 1]); // 7 days + 1 second
      await ethers.provider.send("evm_mine");
      
      // Execute proposal
      const initialIssuerBalance = await mockToken.balanceOf(issuer.address);
      await bondEscrow.adjudicateLeak(0);
      const finalIssuerBalance = await mockToken.balanceOf(issuer.address);
      
      expect(finalIssuerBalance).to.be.gt(initialIssuerBalance);
      
      const postedBond = await bondEscrow.getPostedBond(0);
      expect(postedBond.isActive).to.be.false;
    });
  });
  
  describe("Bond Expiry", function () {
    beforeEach(async function () {
      await bondEscrow.connect(issuer).issueBond("video", ethers.parseEther("100"), 86400, 10);
      await mockToken.connect(poster).approve(await bondEscrow.getAddress(), ethers.parseEther("100"));
      await bondEscrow.connect(poster).postBond(0, ethers.ZeroAddress);
    });
    
    it("Should allow claiming expired bond", async function () {
      // Fast forward past expiry
      await ethers.provider.send("evm_increaseTime", [86400 + 1]); // 1 day + 1 second
      await ethers.provider.send("evm_mine");
      
      const initialBalance = await mockToken.balanceOf(poster.address);
      await bondEscrow.connect(poster).claimExpiredBond(0);
      const finalBalance = await mockToken.balanceOf(poster.address);
      
      expect(finalBalance).to.be.gt(initialBalance);
      
      const postedBond = await bondEscrow.getPostedBond(0);
      expect(postedBond.isActive).to.be.false;
    });
  });
});