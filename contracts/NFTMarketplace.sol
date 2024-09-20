// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";  // Import the ERC-721 interface for Membership NFT

contract NFTMarketplace is ERC721, Ownable (msg.sender){

    uint256 public _tokenIdCounter;  // To track token IDs
    uint256 public _numberOfMintedNFTs;  // To track total minted NFTs
    uint256 public _marketplaceFee;  // Marketplace fee as a percentage (2 means 2%)
    uint256 public _numberOfSellers;  // Tracks the number of unique sellers
    uint256 public _numberOfSales;    // Tracks total number of NFT sales
    uint256 public mintingFee;           // Fee required to mint an NFT
    uint256 public maxMintsPerAddress;   // Maximum number of NFTs each address can mint
    uint256 public maxSupply;            // Maximum number of NFTs that can be minted
    address public _admin;  // Admin address for contract control
    address public membershipNFTAddress = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;  // Membership NFT contract: BoredApeYachtClub 

    struct Seller {
        uint256 totalSales;    // Total number of NFTs sold by the seller
        uint256 totalEarnings; // Total Ether earned by the seller
        uint256 totalMintedNFTS; // Total number of minted NFTs
        address[] listOfCustomers; // List of customer addresses
    }

    struct NFT {
        uint256 price;          // Price of the NFT
        uint256 expiration;     // Expiration timestamp for the listing
        address owner;          // Original owner of the NFT
        bool listed;            // Whether the NFT is currently listed
    }

    mapping(uint256 => string) public _tokenURIs;  // Mapping of tokenId to IPFS URIs
    mapping(address => uint256) public _proceeds;  // Tracks proceeds for each seller
    mapping(address => bool) public _authorizedMinters;  // Mapping of authorized minters
    mapping(address => Seller) public _sellers;  // Mapping of seller addresses to their sales details
    mapping(address => bool) public _sellerHasListedBefore;  // Tracks if a seller has been counted as a unique seller
    mapping(uint256 => NFT) public nfts; // Mapping from tokenId to the NFT struct
    mapping(uint256 => bool) public _tokenExists;  // Mapping to track whether a tokenId exists

    constructor(address _membershipNFTAddress) ERC721("NFT Marketplace", "NFTM") {
        _admin = msg.sender;  // Assign the contract deployer as the admin
        _marketplaceFee = 2;  // Default marketplace fee of 2%
        membershipNFTAddress = _membershipNFTAddress;
    }

    // Events
    event NFTListed(address indexed seller, uint256 indexed tokenId, uint256 price, uint256 duration);
    event NFTMinted(address indexed minter, uint256 indexed tokenId, string tokenURI);
    event NFTSold(address indexed seller, address indexed buyer, uint256 indexed tokenId, uint256 price);
    event ProceedsWithdrawn(address indexed seller, uint256 amount);
    event NFTDelisted(address indexed owner, uint256 indexed tokenId);

    // Modifier to check if the user owns the Membership NFT
    modifier onlyMembershipHolder() {
        IERC721 membershipNFT = IERC721(membershipNFTAddress);
        require(membershipNFT.balanceOf(msg.sender) > 0, "You must hold a Membership NFT to perform this action");
        _;
    }

    // Mint function to create new NFTs (restricted to Membership NFT holders)
    function mintNFT(address to, string memory tokenURI) public payable onlyMembershipHolder {
        require(to != address(0), "Cannot mint to zero address");
        require(msg.value == mintingFee, "Incorrect minting fee sent");
        require(_sellers[msg.sender].totalMintedNFTS < maxMintsPerAddress, "Minting limit reached for this address");
        require(_numberOfMintedNFTs < maxSupply, "Maximum NFT supply reached");
        require(bytes(tokenURI).length > 0, "Metadata URI must be provided");

        // Increment the token ID counter
        _tokenIdCounter += 1;
        uint256 newTokenId = _tokenIdCounter;

        // Mint the NFT and set its URI
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

         // Mark the token as existing
        _tokenExists[newTokenId] = true;

        // Track the total number of NFTs minted
        _numberOfMintedNFTs += 1;
        _sellers[to].totalMintedNFTS += 1;

        emit NFTMinted(to, newTokenId, tokenURI);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal {
        require(_tokenExists[tokenId], "nonexistent tokenId");  // Check existence using the mapping
        _tokenURIs[tokenId] = tokenURI;
    }


    // List an NFT for sale (restricted to Membership NFT holders)
    function listNFT(uint256 tokenId, uint256 price, uint256 duration) public onlyMembershipHolder {
        require(ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(price > 0, "Price must be greater than zero");
        require(duration > 0, "Duration must be greater than zero");

        // Transfer the NFT to the marketplace contract for custody during the sale
        _safeTransfer(msg.sender, address(this), tokenId, "");

        // Set the sale price, listing status, and expiration
        nfts[tokenId] = NFT({
            price: price,
            expiration: block.timestamp + duration,
            owner: msg.sender,
            listed: true
        });

        // Track the unique sellers
        if (!_sellerHasListedBefore[msg.sender]) {
            _numberOfSellers += 1;
            _sellerHasListedBefore[msg.sender] = true;
        }

        emit NFTListed(msg.sender, tokenId, price, duration);
    }

    // Buy a listed NFT
    function buyNFT(uint256 tokenId) public payable {
        require(nfts[tokenId].listed, "This NFT is not listed for sale");
        require(block.timestamp <= nfts[tokenId].expiration, "Listing has expired");

        // Ensure the buyer has sent enough Ether to cover the price
        uint256 price = nfts[tokenId].price;
        require(msg.value == price, "Incorrect Ether value sent");

        address seller = nfts[tokenId].owner;

        // Transfer the NFT to the buyer
        _safeTransfer(address(this), msg.sender, tokenId, "");

        // Transfer proceeds to the seller (minus marketplace fees)
        uint256 marketplaceFeeAmount = (price * _marketplaceFee) / 100;
        uint256 sellerProceeds = price - marketplaceFeeAmount;
        _proceeds[seller] += sellerProceeds;

        // Mark the NFT as no longer listed
        nfts[tokenId].listed = false;

        // Increment the seller's total sales and add buyer to their customer list
        _sellers[seller].totalSales += 1;
        _sellers[seller].listOfCustomers.push(msg.sender);

        // Emit the NFTSold event
        emit NFTSold(seller, msg.sender, tokenId, price);
    }

    // Withdraw proceeds from sales
    function withdrawProceeds() public {
        uint256 proceeds = _proceeds[msg.sender];
        require(proceeds > 0, "No proceeds to withdraw");

        // Reset proceeds before transferring to prevent reentrancy attacks
        _proceeds[msg.sender] = 0;

        // Transfer the proceeds to the seller
        (bool success, ) = msg.sender.call{value: proceeds}("");
        require(success, "Transfer failed");

        emit ProceedsWithdrawn(msg.sender, proceeds);
    }

    // Delist an NFT (with 1.5% fee if delisted before expiration)
    function delistNFT(uint256 tokenId) public payable {
        require(ownerOf(tokenId) == address(this), "NFT is not held by the contract");
        require(nfts[tokenId].listed, "This NFT is not listed for sale");

        // Check if the listing duration has expired
        if (block.timestamp < nfts[tokenId].expiration) {
            // Calculate the delisting fee (1.5%)
            uint256 price = nfts[tokenId].price;
            uint256 delistingFee = (price * 15) / 1000;
            require(msg.value == delistingFee, "Incorrect delisting fee sent");
        }

        // Transfer the NFT back to the owner
        _safeTransfer(address(this), msg.sender, tokenId, "");

        // Mark the NFT as no longer listed
        nfts[tokenId].listed = false;

        emit NFTDelisted(msg.sender, tokenId);
    }

    // Getter function to fetch NFT details
    function getNFTDetails(uint256 tokenId) public view returns (uint256 price, uint256 timeLeft, address owner, uint256 delistingFee) {
        require(nfts[tokenId].listed, "This NFT is not listed for sale");

        // 1. Get price
        price = nfts[tokenId].price;

        // 2. Calculate time left
        if (block.timestamp >= nfts[tokenId].expiration) {
            timeLeft = 0;  // Listing has expired
        } else {
            timeLeft = nfts[tokenId].expiration - block.timestamp;
        }

        // 3. Get the owner
        owner = nfts[tokenId].owner;

        // 4. Calculate delisting fee
        if (block.timestamp < nfts[tokenId].expiration) {
            delistingFee = (price * 15) / 1000;  // 1.5% fee
        } else {
            delistingFee = 0;  // No fee if expired
        }

        return (price, timeLeft, owner, delistingFee);
    }
}
