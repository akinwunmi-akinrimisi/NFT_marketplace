// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

// Import the ERC-721 interface and other utilities from OpenZeppelin
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTMarketplace is ERC721, Ownable {
    
    uint256 public _tokenIdCounter;  // To track token IDs
    uint256 public _numberOfMintedNFTs;  // To track total minted NFTs
    uint256 public _marketplaceFee;  // Marketplace fee as a percentage (2 means 2%)
    uint256 public _numberOfSellers;  // Tracks the number of unique sellers
    uint256 public _numberOfSales;    // Tracks total number of NFT sales
    address public _admin;  // Admin address for contract control
    
    struct Seller {
        uint256 totalSales;    // Total number of NFTs sold by the seller
        uint256 totalEarnings; // Total Ether earned by the seller
        uint256 totalMintedNFTS; // Total number of minted NFTs
        address[] listOfCustomers; // List of customer addresses
    }

    mapping(uint256 => string) public _tokenURIs;  // Mapping of tokenId to IPFS URIs
    mapping(address => uint256) public _proceeds;  // Tracks proceeds for each seller
    mapping(uint256 => uint256) public _tokenPrices;  // tokenId to sale price
    mapping(uint256 => bool) public _listedTokens;  // tokenId to listing status (true if listed)
    mapping(address => bool) public _authorizedMinters;  // Mapping of authorized minters
    mapping(address => Seller) public _sellers;  // Mapping of seller addresses to their sales details

    constructor() ERC721("NFT Marketplace", "NFTM") {
        _admin = msg.sender;  // Assign the contract deployer as the admin
        _marketplaceFee = 2;  // Default marketplace fee of 2%
    }

    event NFTMinted(address indexed minter, unit256 indexed tokenId, string tokenURI);

    function mintNFT(address to, sring memory tokenURI) public {
        require(to != address(0), "Cannot mint to zero address");
        require(msg.value == mintingFee, "Incorrect minting fee sent");
        require(_sellers[msg.sender].totalMintedNFTS < maxMintsPerAddress, "Minting limit reached for this address");
        require(_numberOfMintedNFTs < maxSupply, "Maximum NFT supply reached");

        require(bytes(tokenURI).length > 0, "Metadata URI must be provided");

        for (uint256 i = 1; i <= _tokenIdCounter; i++) {
        require(keccak256(abi.encodePacked(_tokenURIs[i])) != keccak256(abi.encodePacked(tokenURI)), "Token URI already exists");
    }

        _tokenIdCounter += 1;
        uint256 newTokenId = _tokenIdCounter;

        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        _numberOfMintedNFTs += 1;
        _sellers[to].totalMintedNFTS +=1;

        emit NFTMinted(to, newTokenId, tokenURI);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal{
        require(_exist(tokenId), "nonexistent tokenId");
        _tokenURIs[tokenId] = tokenURI;
    }
   

}
