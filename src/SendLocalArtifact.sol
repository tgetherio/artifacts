//SpDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";


interface tgetherArtifcats {
    function receiveLocalChain(  
            uint256 tokenId,
            address nftContract,
            address owner,
            string memory name,
            string memory symbol,
            string memory tokenURI)external  returns (uint256);
}
contract SendLocalArtifact { 

    address owner;
    address public artifactContract;

    modifier ownerOnly() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }
    function sendArtifact(address nftContract, uint256 tokenId) external returns (uint256 artifactId) { 
        address currentOwner = IERC721Metadata(nftContract).ownerOf(tokenId);

        string memory tokenURI;
        try IERC721Metadata(nftContract).tokenURI(tokenId) returns (string memory _tokenURI) {
            tokenURI = _tokenURI;
        } catch {
            tokenURI = "Metadata not available";
        }

        string memory name = IERC721Metadata(nftContract).name();
        string memory symbol = IERC721Metadata(nftContract).symbol();

        artifactId= tgetherArtifcats(artifactContract).receiveLocalChain(tokenId, nftContract, currentOwner, name, symbol, tokenURI);

    }


    function setArtifactContract(address _artifactContract) external ownerOnly {
        artifactContract = _artifactContract;
    }
}