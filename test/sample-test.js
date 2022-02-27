const { expect } = require("chai");
const { ethers } = require("hardhat");
const { isCallTrace } = require("hardhat/internal/hardhat-network/stack-traces/message-trace");


// stimulate deploying contracts, create an NFT, putting that nft for sale on the market and purchasing it by/for?? someone else
describe("NFTMarket", function () {
  it ("Should create and execute market sales",async function (){


    //get a reference to that market contract
    const Market=await ethers.getContractFactory("NFTMarket")
    //deploy the market contract
    const market=await Market.deploy()  
    //wait for it to be deployed
    await market.deployed()   

    //get a reference of the address from which it was deployed-- because in the NFT.sol 
    //contract we have a constructor that needs a marketplaceaddress as an argument
    const marketAddress=market.address  


    // similarly as above get a reference to the NFT contract
    const NFT=await ethers.getContractFactory("NFT")  
    //To deploy this NFT contract we need to pass in the marketplaceaddress as 
    //mentioned above. 
    const nft =await NFT.deploy(marketAddress)  
    //wait for the contract to be deployed
    await nft.deployed()

    //similarly as we got referece to the market address
    //get a reference to the NFT address as well 
    //and store it in variable called nftcontractaddress
    const nftContractAddress = nft.address 

//now we have reference to the market contract address and nft contract address

// contracts are now deployed , so we can start interacting with them


    //get reference to the value of listing price
    let listingPrice =await market.getListingPrice()
    // we now turn it into a string to be able to interact with it
    listingPrice = listingPrice.toString()


    //create a variable for the auction price
    // it tells how much are we selling our items for
    // for user interface we may display wallet balance in eth 
    //but for transactions we need wallet balance plus gas fees 
    //both in gewi or wei which is machine readable
    //parse units will parse a string displaying ether into wei
    //additional info: opposite of parseunits is formatunits which changes
    //big numbers like wei in ether to display it to the user 
    const auctionPrice=ethers.utils.parseUnits('100','ether')


//create a bunch of tokens and put them up for sale


    // Creating Tokens-using the function of the NFT.sol which is createToken to create new tokens
    //the argument to passed in is the string which is the tokenURI
    // this function returns the newitemis, which is the id of the current token we r 
    // dealing with
    await nft.createToken("https://www.mytokenlocation.com")  // pass in the URI of the tokens
    await nft.createToken("https://www.mytokenlocation2.com")
  



    //list these tokens on the market
    //use the function in NFTMarket.sol which is createMarketItem
    // this function accepts nftcontractaddress , tokenid , price of the token , 
    //lastly we pass in the listing price , i.e. is the money we give to the owner 
    await market.createMarketItem(nftContractAddress,1,auctionPrice,{value:listingPrice})
    await market.createMarketItem(nftContractAddress,2,auctionPrice,{value:listingPrice})



    //additional info: u can get test accounts from hardhat as well as ethers 
    //how to get different addresses from different users-- get test addresses to work with?
    //ethers.GetSigners returns an array
    // when we r deploying , we r gonna be working with very 1st item in that array
    // so we r not specifying the seller addresses we are just deploying right now , so ignoore that address
    // giving a _
    // we dont want the buyer to be the same person as the seller, so we use _ to ignore the  seller address 
    //and then specify the buyer address
    const[_,buyerAddress] = await ethers.getSigners()
    

    //SELLING THE NFTS
    //use the buyer address to connect to the market
    //then create a market sale and pass in the contract address, the id of token and value of auction price -- which in our case will be 100 matic
    await market.connect(buyerAddress).createMarketSale(nftContractAddress,1,{value:auctionPrice})

    //QUERING THESE MARKET ITEMS
    

    //1. variable called items
    //map over all these items and update the value of them

    //promise.all allows u to do asynchronous mapping
    items = await market.fetchMarketItems()
    //map over all the items and update the value of them
    items = await Promise.all(items.map(async i => {
      const tokenUri = await nft.tokenURI(i.tokenId)
      //get the token URI
      //new reference to the item
      let item = {
        price: i.price.toString(),     // convert the big number into a string
        tokenId: i.tokenId.toString(),   
        seller: i.seller,
        owner: i.owner,
        tokenUri
      }
      return item
    }))
    console.log('items: ', items)
  })
})
