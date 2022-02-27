// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
//security mechanism that will give us a utility called nonreentrant which allows to protect transactions talking to a seperate contract
//prevents someone to hit it with multiple transactions
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
//standard ERC721 contract
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";


//declare the contract which inherits from reentrancyguard
contract NFTMarket is ReentrancyGuard {
  //use counters for incrementing values
  using Counters for Counters.Counter;
  //counter for each individual item that will be created-itemid
  Counters.Counter private _itemIds;
  //counter for each item sold
  //we need to keep up with no of items sold because solidity doesnt support dynamic length arrays. so need to know the length of the array 
  Counters.Counter private _itemsSold;

//create a variable for the owner of the contract  and make it payable bcause the owner will get a commision on each item sold
  address payable owner;
//so listing fee is charged. anyone who wants to list an item should pay the lsiting fee. and owner of the contract gets a commision from that fee
  uint256 listingPrice = 0.025 ether;

//set the owner as the msg.sender as the owner will be deploying this contract
  constructor() {
    owner = payable(msg.sender);
  }
//define a struct called marketitem for each individual market item. struct is a map /object . it holds other values 
  struct MarketItem {
    uint itemId;            //
    address nftContract;    //
    uint256 tokenId;      // tokenid
    address payable seller;   //address of the seller
    address payable owner;   // address of the owner
    uint256 price; //keep up with the price
    bool sold;      // whether its sold or not
  }

// create a mapping for all the market items that are being created
// so we map a uint256(the itemid) to a marketitem= so that you can fetch the marketitem based on the itemid
  mapping(uint256 => MarketItem) private idToMarketItem;

//event called marketitemcreated for when a market item is created- it will match the marketitem struct
//so we need to emit an event every time a new marketitem is created
//this is useful if u want to listen to events from a frontend application
  event MarketItemCreated (
    uint indexed itemId,
    address indexed nftContract,
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool sold
  );

//function to get the listing price. when we deploy this contract we dont know what the listingprice is at the front end
// so with this function we can call the contract , get the listing price and send the correct amount of payment
  function getListingPrice() public view returns (uint256) {
    return listingPrice;
  }


  
 //function to create a market item. arguments- contract for the actual nft(contractaddress for deployment), 
 //id of the token from that contract,price of the token which is being put up for sale
 //whoever is putting that item on sale defines the price
 //non reentrant is going to prevent reentry- its called a modifier
 // condition 1 = price must be greater than one wei(dont list it for free)
 //condition2= user should pay the required listing price(of which the contract owner gets a commision)
  function createMarketItem(
    address nftContract,
    uint256 tokenId,
    uint256 price
  ) public payable nonReentrant {
    require(price > 0, "Price must be at least 1 wei");
    require(msg.value == listingPrice, "Price must be equal to listing price");

    // increment ur item ids as the new items are being created in this contract
    _itemIds.increment();
    
    //create a variable called itemid to get the id of the item that is going for sale right now
    uint256 itemId = _itemIds.current();
  
  //create the mapping for the itemid to marketitem(struct)
    idToMarketItem[itemId] =  MarketItem(
      itemId,
      nftContract,
      tokenId,
      payable(msg.sender),   //person who is selling this-available in the transaction
      payable(address(0)),   //address of the owner-empty address- beacuse the seller is putting it for sale and noone owns it right now
      price,     
      false    // the item is not yet being sold
    );
//transfer the ownership of the NFT/item being created to the contract, bcoz r right now thw person writing this transaction owns this
//so we transfer ownership to the contract and the contract can transfer it to the next buyer
    IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

    //emit the event that we created earlier

    emit MarketItemCreated(
      itemId,
      nftContract,
      tokenId,
      msg.sender,
      address(0),    // because still no one is the owner
      price,
      false
    );
  }




//function to create a market sale , arguments=contract address and itemid. dont need to pass in the price

    function createMarketSale(
    address nftContract,
    uint256 itemId
    ) public payable nonReentrant {
      //create variables based on our arguments
      //get the price of the current item by using the mapping from that itemid to its price
    uint price = idToMarketItem[itemId].price;
    //we have the itemid which wont always match the token id. so get the current token id by using mapping.map the tokenid to its itemid
    uint tokenId = idToMarketItem[itemId].tokenId;
    //condition= person should send the correct amount. Value=price, so person should send that much price
    require(msg.value == price, "Please submit the asking price in order to complete the purchase");

//transfer the value of the transaction(how much money was sent/price paid by the buyer) to the seller
    idToMarketItem[itemId].seller.transfer(msg.value);
    //transfer the ownership of the nft from this contract to the msg.sender-this transfers the ownership from contract to the buyer
    IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
    //set the local value of the owner to be msg.sender--updating the mapping--msg.sender is the owner of the nft
    idToMarketItem[itemId].owner = payable(msg.sender);
    //set the value of sold=true
    idToMarketItem[itemId].sold = true;
    //increase the number of sold items
    _itemsSold.increment();
    //finally pay the owner of the contract(commision)
    payable(owner).transfer(listingPrice);
  }





//function to get unsold items-its public(visible from the client side),view(doesnt do any transactional stuff) , 
//it returns an array of market items

  function fetchMarketItems() public view returns (MarketItem[] memory) {

    //variable itemcount =total no of items that we have currently created
    uint itemCount = _itemIds.current();
    //unsold itemcount= total created items- sold items
    uint unsoldItemCount = _itemIds.current() - _itemsSold.current();
    // we are gonna loop over an array and we ahve to keep up with a number within that array.
    //here we loop over number of items created. we want to increment that number if we have an empty address
    // if an item has an empty address that means it has not yet been sold and we want to populate an array with that unsold item.
    //then we want to return that item. because from this function we e returning the unsold items
    // this variable is to keep track of the unsold items being added to the array(items)
    uint currentIndex = 0;

//create an empty array called items which will be of the length unsold item count. values in this array are of the marketitems
    MarketItem[] memory items = new MarketItem[](unsoldItemCount);
    // loop over itmecount(no of items that have been created)
    for (uint i = 0; i < itemCount; i++) {
      // check to see if the created item is unsold . owner is a type of address. use the mapping to find an owner with the empty address
      //empty address means the item is unsold. this address is only populated when an item is sold.
      if (idToMarketItem[i + 1].owner == address(0)) {
        //now insert that unsold item in the items array and increment that current item by 1
        //currentid is the id of the item that we r interacting with right now 
        uint currentId = i + 1;
        //create a variable called currentitem and map it to currentid-this will give us the reference for the unsold item
        //that we want to insert into that array 
        MarketItem storage currentItem = idToMarketItem[currentId];
       // now insert that item into that array (items) by saying items at the currentindex to be equal to currentitem
        items[currentIndex] = currentItem;
        //increment the index by 1
        currentIndex += 1;
      }
    }
    //return the array
    return items;
  }




  // Returns only items that a user has purchased 
  //function called fetchmynfts - is public(anyone can view) and retruns an empty array of marketitems 
  function fetchMyNFTs() public view returns (MarketItem[] memory) {
    //again totalitemcount= total no of items that have been created 
    uint totalItemCount = _itemIds.current();
    // keep track of new variable called itemcount that tells us how many items we have purchased

    uint itemCount = 0;
    //also keep up with the current index that tells us the id of the items that we have purchased
    
    uint currentIndex = 0;
// we dont really have a function that fetches the no of items that user has created or purchased
// to get that number , loop over all the items created(totalitemcount) 
    for (uint i = 0; i < totalItemCount; i++) {
      //then declare the owner as msg.sender,i.e., the owner of the purchased item
      if (idToMarketItem[i + 1].owner == msg.sender) {
        //increase the value of purchased items by one
        itemCount += 1;
      }
    }

//create  a new array called items which is of length itemcount(no of items that are purchased by the user )
    MarketItem[] memory items = new MarketItem[](itemCount);
    // loop over totalitemcount(total no of items that have been created)
    for (uint i = 0; i < totalItemCount; i++) {
      // check to see if the owner address is =to msg.sender,i.e., if the user is the owner of the item/user has purchased it and owns it now

      if (idToMarketItem[i + 1].owner == msg.sender) {
        //then get the id of that current item
        uint currentId = i + 1;
        //create a variable called currentitem and map it to currentid to get the current item 
        MarketItem storage currentItem = idToMarketItem[currentId];
        // now insert that item into the array(items) and currentindex keeps track of items being added to the items array
        items[currentIndex] = currentItem;
        //increment the currentindex after adding that item into the array(items)
        currentIndex += 1;
      }
    }
    //return the array
    return items;
  }






  // Returns only items a user has created themselves
  //function calld fetchitemscreated is pulic(visible from clientside) and returns an empty array 
  function fetchItemsCreated() public view returns (MarketItem[] memory) {
    // create a variable called totalitemcount to get the total number of items created
    uint totalItemCount = _itemIds.current();
    //create a vraible called itemcount to keep track items that are created by the user
    uint itemCount = 0;
    //keep track of currentindex which adds the items created by the user to the array(items)
    uint currentIndex = 0;

//loop over totalitemcount(total no of items created) 
    for (uint i = 0; i < totalItemCount; i++) {
      //set the msg.sender eqaul to seller , i.e , now the user is going to be the seller of the nft/item he/she has created
      if (idToMarketItem[i + 1].seller == msg.sender) {
        //increase the count of the items created by the user
        itemCount += 1;
      }
    }
//create a array (items) of the lenth itemcount(bno of items created by the user)
    MarketItem[] memory items = new MarketItem[](itemCount);
    //loop over total itemcount(total no items created)
    for (uint i = 0; i < totalItemCount; i++) {
      //we check to see if the seller address is = to msg.sender , i.e , user/i have created this item
      if (idToMarketItem[i + 1].seller == msg.sender) {
        //get the current item id
        uint currentId = i + 1;
        //create a variable called currentitem and map it to currentid to get a reference to the current item that has been created 
        MarketItem storage currentItem = idToMarketItem[currentId];
        //insert that item into the array using the currentindex
        items[currentIndex] = currentItem;
        //now increment the current index
        currentIndex += 1;

      }
    }
    //return the array(items)
    return items;
  }
}
