// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;

    // Owner of this contract can also mint NFT Token, sellIt (or) keep with themselves!
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    
    // Whenever third-party lists Nft, owner get paid as listing fee..
    // Ether = Matic in polygon Network
    address payable owner;
    uint256 listingPrice = 0.025 ether;

    constructor() {
    owner = payable(msg.sender);
    }

    struct MarketItem {
    uint itemId;
    address nftContract;
    uint256 tokenId;
    address payable seller;
    address payable owner;
    uint256 price;
    bool sold;
    }

    // We use Id to return each (NFT token)MarketItem!
    mapping(uint256 => MarketItem) private idToMarketItem;

    // Event, basically used to store the arguments passed in the transaction logs when emitted!
    event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
    );

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }
    
    // To create NFT token as a user!
    /* Places an item for sale on the marketplace */
    function createMarketItem(
    address nftContract,
    uint256 tokenId,
    uint256 price
    ) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Price must be equal to listing price");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();
  
        idToMarketItem[itemId] =  MarketItem(
            itemId,
            nftContract,
            tokenId,
            payable(msg.sender), // seller
            payable(address(0)), // No owner as Noone yet to own it
            price,
            false
        );
        
        /** Now, we need to transfer the ownership to the contract itself from the person, who is writing the transaction(contract)
    
       Contract will take the ownership of this item and transfer it to the next preferrable buyer.

       this - this contract itself.
        */ 
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }
    
    /* Creates the sale of a marketplace item */
    /* Transfers ownership of the item, as well as funds between parties */
    function createMarketSale(
    address nftContract,
    uint256 itemId
    ) public payable nonReentrant {
        uint price = idToMarketItem[itemId].price;
        uint tokenId = idToMarketItem[itemId].tokenId;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        
        // As a buyer, I need to transfer the selling amount to the seller(owner's address) to buy that NFTtoken!..
        idToMarketItem[itemId].seller.transfer(msg.value);

        // Transfering of ownership from the contract to the buyer!
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();

        // After selling a NFTToken, seller must pay listingPrice to the owner(of this marketPlace)
        payable(owner).transfer(listingPrice);
    }
    
    // Returns all unsold market items
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint itemCount = _itemIds.current(); 
        uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint currentIndex = 0;
        
        // Unsold NFTtoken Array in the length of unsoldItemCount!
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for (uint i = 0; i < itemCount; i++) {
            // To find the unSoldItems.
            if (idToMarketItem[i + 1].owner == address(0)){
              uint currentId = idToMarketItem[i + 1].itemId;
              MarketItem storage currentItem = idToMarketItem[currentId];
              items[currentIndex] = currentItem;
              currentIndex += 1;
            }
        }
        return items;
    }

    /*Returns the NFTtoken, which is created by the user themselves! as a owner
    
    Returning the nfts that the user has purchased themselves! */ 
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint totalItemCount = _itemIds.current();
        uint itemCount = 0;// Counting all the Nft, which is actually created by the user.
        uint currentIndex = 0;
    
       // Counting all the NFTtoken, which is created by user itself!
       for (uint i = 0; i < totalItemCount; i++) {
           if (idToMarketItem[i + 1].owner == msg.sender) {
            itemCount += 1;
           }
        }
    
        // NFTtoken Array created by the user in the length of itemCount!
        MarketItem[] memory items = new MarketItem[](itemCount);


        for (uint i = 0; i < totalItemCount; i++) {
            // To find the NFT owned by the owner
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    // Returning NFT's, that the user has created themselves to sell to buyer!
    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
    uint totalItemCount = _itemIds.current();
    uint itemCount = 0;
    uint currentIndex = 0;
    
    // Counting all the NFTtoken, which is created by user to sell to the buyer!
    for (uint i = 0; i < totalItemCount; i++) {
      if (idToMarketItem[i + 1].seller == msg.sender) {
        itemCount += 1;
      }
    }
    
    // NFTtoken Array created by the user in the length of itemCount to sell!
    MarketItem[] memory items = new MarketItem[](itemCount);

    for (uint i = 0; i < totalItemCount; i++) {
      // To find the NFT owned by the owner to sell
      if (idToMarketItem[i + 1].seller == msg.sender) {
        uint currentId = i + 1;
        MarketItem storage currentItem = idToMarketItem[currentId];
        items[currentIndex] = currentItem;
        currentIndex += 1;
      }
    }
    return items;
  }

} 