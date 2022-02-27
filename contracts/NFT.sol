// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.3;

//Counters is used to incrementing utils
import "@openzeppelin/contracts/utils/Counters.sol";
//ERC721  gives us an additional function setTokenUri
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
//standard smart contract import from openzeppelin
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

//here we inherit from ERC721URIStrage which inturn inherits from ERC721
contract NFT is ERC721URIStorage {
    
    using Counters for Counters.Counter;
    //use counters to declare a private variable called tokenIds,which allows us to keeping track of 
    // incrementing values for each token
    Counters.Counter private _tokenIds;
    //variable contractAddress is the address of the marketplace that we want out NFT to be able to interact
    //with and vice versa
    address contractAddress;


//give the marketplace the ability to transact these tokens and change the ownership of these tokens from a seperate contract
//to do that call the function setApprovalForAll and pass in the contractAddress whose value we will set in below constructor
//use the constructor to set the value of the contractAddress
//constructor will take in the marketplaceaddress as the argument

    constructor(address marketplaceAddress) ERC721("Metaverse", "METT") {
        //then set the contractAddress as argument for marketplaceaddress
        //beacuse we need the address of marketplace before deploying the contract
        //now we can access the marketplace by referencing the contractAddress
        contractAddress = marketplaceAddress;
    }


//function for minting new tokens
//only need to pass tokenURI because we already stored the marketplaceaddrerss and the tokenids and
//we also know that msg.sender is going to mint the tokens
    function createToken(string memory tokenURI) public returns (uint) {
        //beacuse this function mints token so increment tokenids
        _tokenIds.increment();
        //newitemid will get the current value of the tokenids 
        uint256 newItemId = _tokenIds.current();
 //mint the token-pass in the msg.sender as the creator and id of current token being minted as the newitemid
        _mint(msg.sender, newItemId);
//set the tokenuri - get the id of the current token being minted as newitemid and pass in the tokenURI to set the current token uri 
        _setTokenURI(newItemId, tokenURI);
//give the marketplace the approval to transact these tokens/NFTS- if we did not do this then we wont be able to transact from other contracts
//pass in the contract address which is same as marketplace address
        setApprovalForAll(contractAddress, true);
        // if we decide to interact with the contract from the client side then we need to mint the token first
        // then set it for sale and then do the transaction.
        //to set it for sale we need to get the current tokenid. thats why we return the current tokenid=newitemid
        return newItemId;
    }
}
