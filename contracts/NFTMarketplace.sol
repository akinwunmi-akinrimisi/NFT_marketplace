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
    uint256 public mintingFee;           // Fee required to mint an NFT
    uint256 public maxMintsPerAddress;   // Maximum number of NFTs each address can mint
    uint256 public maxSupply;            // Maximum number of NFTs that can be minted
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
    mapping(address => bool) public _sellerHasListedBefore;  // Tracks if a seller has been counted as a unique seller
    mapping(uint256 => uint256) public _listingExpiration;   // Mapping to store listing expiration timestamps for each tokenId

    constructor() ERC721("NFT Marketplace", "NFTM") {
        _admin = msg.sender;  // Assign the contract deployer as the admin
        _marketplaceFee = 2;  // Default marketplace fee of 2%
    }

    
    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price, uint256 duration);
    event NFTMinted(address indexed minter, unit256 indexed tokenId, string tokenURI);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);

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


    function listNFT(uint256 tokenId, uint256 price, uint256 duration) public {
        require(ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(!_listedTokens[tokenId], "This NFT is already listed for sale");
        require(price > 0, "Price must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");

        //Transfer the NFT to the marketplace contract for custody during the sale
        _safeTransfer(msg.sender, address(this), tokenId, "");     


        _tokenPrices[tokenId] = price;  // Set the sale price of the NFT
        _listedTokens[tokenId] = true;  //Mark the NFT as listed

        _listingExpiration[tokenId] = block.timestamp + duration;

        // Track the unique sellers
        if (!_sellerHasListedBefore[msg.sender]) {
            _numberOfSellers += 1;
            _sellerHasListedBefore[msg.sender] = true;
        }

        emit NFTListed(msg.sender, tokenId, price, duration);
    }


    function buyNFT(uint256 tokenId) public payable {

        require(_listedTokens[tokenId], "This NFT is not listed for sale");
        require(block.timestamp <= _listingExpiration[tokenId], "Listing has expired");

        //Ensure the buyer has sent enough Ether to cover the price
        uint256 price = _tokenPrices[tokenId];
        require(msg.value == price, "Incorrect Ether value sent");

        address seller = ownerOf(tokenId);

        //Transfer the NFT from the contract to the buyer
        _safeTransfer(address(this), msg.sender, tokenId, "");

        //Transfer proceeds to the seller (minus marketplace fees)
        uint256 marketplaceFeeAmount = (price * _marketplaceFee) / 100;
        uint256 sellerProceeds = price - marketplaceFeeAmount;
        _proceeds[seller] += sellerProceeds;

        //Mark the NFT as no longer listed
        _listedTokens[tokenId] = false;

        //Increment the seller's total sales and add buyer to their customer list
        _sellers[seller].totalSales += 1;
        _sellers[seller].listOfCustomers.push(msg.sender);

        //Emit the NFTSold event
        emit NFTSold(seller, msg.sender, tokenId, price);
        
}




}
