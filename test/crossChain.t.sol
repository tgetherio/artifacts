// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {CCIPLocalSimulator} from "@chainlink/local/src/ccip/CCIPLocalSimulator.sol";
import {tgetherPosts} from "../src/tgetherPosts.sol";
import "../src/SendArtifact.sol";
import {Artifacts} from "../src/Artifacts.sol";
import {SendLocalArtifact} from "../src/SendLocalArtifact.sol";
import "forge-std/console.sol";
contract crossChain is Test {
    CCIPLocalSimulator public ccipLocalSimulator;

    Artifacts public artifacts;
    SendArtifact public sendArtifact;
    tgetherPosts public posts;
    SendLocalArtifact public sla;

    uint64 chainSelector;
    address public addr1 = address(0x1);


    function setUp() public {
        ccipLocalSimulator = new CCIPLocalSimulator();
        (
            uint64 chainSelector_,
            IRouterClient sourceRouter,
            IRouterClient destinationRouter,
            ,
            ,
            ,

        ) = ccipLocalSimulator.configuration();

        sla = new SendLocalArtifact();
        artifacts = new Artifacts(address(sourceRouter),  2 , address(sla) );
        sendArtifact = new SendArtifact(address(destinationRouter),chainSelector_, chainSelector_, address(artifacts));
        sla.setArtifactContract(address(artifacts));
        posts = new tgetherPosts(address(sla));


        chainSelector = chainSelector_;
    }

    function test_CreateArtifacts() external {
        vm.prank(addr1,addr1);
        posts.mintPost("content", "title", "authorName", "description");  
        vm.prank(addr1,addr1);
        uint256 fee = sendArtifact.testFeePrice(address(posts), 1);
        sendArtifact.sendArtifact{value: fee }(address(posts), 1);

        (address nftContract1_,
        uint256 chainId1_,
        uint256 tokenId1_,
        address owner1_,
        string memory name1_,
        string memory symbol1_,
        string memory tokenURI1_,
        ) = artifacts.artifacts(1);
        
        (address nftContract2_,
        uint256 chainId2_,
        uint256 tokenId2_,
        address owner2_,
        string memory name2_,
        string memory symbol2_,
        string memory tokenURI2_,
        ) = artifacts.artifacts(2);

        assertEq(nftContract1_, address(posts));
        assertEq(chainId1_, 2);
        assertEq(tokenId1_, 1);
        assertEq(owner1_, address(addr1));
        assertEq(name1_, "LearnTgetherPosts");
        assertEq(symbol1_, "TGP");

        assert(nftContract2_ == address(posts));
        assertEq(chainId2_, chainSelector);
        assertEq(tokenId2_, 1);
        assertEq(owner2_, address(addr1));
        assertEq(name2_, "LearnTgetherPosts");
        assertEq(symbol2_, "TGP");

        assertEq(tokenURI1_, tokenURI2_);


        


    }
}