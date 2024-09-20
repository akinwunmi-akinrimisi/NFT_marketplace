import {
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("NFTMarketplace", function () {
  // Fixture to deploy the contract and get initial values
  async function deployNFTMarketplaceFixture() {
    const [admin, otherAccount] = await hre.ethers.getSigners();
    
    // Deploying the contract
    const membershipNFTAddress = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D";
    const NFTMarketplace = await hre.ethers.getContractFactory("NFTMarketplace");
    const nftMarketplace = await NFTMarketplace.deploy(membershipNFTAddress);

    // Initial state variables
    const marketplaceFee = await nftMarketplace._marketplaceFee();
    const numberOfSellers = await nftMarketplace._numberOfSellers();
    const numberOfSales = await nftMarketplace._numberOfSales();
    const numberOfMintedNFTs = await nftMarketplace._numberOfMintedNFTs();
    const adminAddress = await nftMarketplace._admin();

    return { nftMarketplace, admin, otherAccount, marketplaceFee, numberOfSellers, numberOfSales, numberOfMintedNFTs, adminAddress };
  }

  describe("Deployment", function () {
    it("Should set the right admin", async function () {
      const { nftMarketplace, admin } = await loadFixture(deployNFTMarketplaceFixture);

      expect(await nftMarketplace._admin()).to.equal(admin.address);
    });

    it("Should initialize the marketplace fee correctly", async function () {
      const { marketplaceFee } = await loadFixture(deployNFTMarketplaceFixture);

      expect(marketplaceFee).to.equal(2); // default fee is 2%
    });

    it("Should initialize number of sellers to 0", async function () {
      const { numberOfSellers } = await loadFixture(deployNFTMarketplaceFixture);

      expect(numberOfSellers).to.equal(0);
    });

    it("Should initialize number of sales to 0", async function () {
      const { numberOfSales } = await loadFixture(deployNFTMarketplaceFixture);

      expect(numberOfSales).to.equal(0);
    });

    it("Should initialize number of minted NFTs to 0", async function () {
      const { numberOfMintedNFTs } = await loadFixture(deployNFTMarketplaceFixture);

      expect(numberOfMintedNFTs).to.equal(0);
    });

    it("Should set the right admin address", async function () {
      const { adminAddress, admin } = await loadFixture(deployNFTMarketplaceFixture);

      expect(adminAddress).to.equal(admin.address);
    });
  });
});
