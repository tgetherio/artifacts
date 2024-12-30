// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Counters.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
interface V2ContractInterface{
    function addPostData(uint256 _tokenId, address authorAddress, string memory authorName, string memory title, string memory content, string memory description ) external returns (bool);
}

interface ArtifactContractInterface{
    function sendArtifact(address nftContract, uint256 tokenId) external returns (uint256 artifactId);
    }
contract tgetherPosts is ERC721Enumerable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    struct Post {
        string content;
        string title;
        address authorAddress;
        string authorName;
        string description;
    }
    mapping(uint256 => Post) public posts;
    address owner;
    address v2ContractAddress;
    address artifactContractAddress;

    mapping (uint256 => uint256) public postToArtifactId;
    modifier ownerOnly() {
        require(msg.sender == owner, "Not the contract owner `");
        _;
    }   

    constructor(address _artifactContractAddress) ERC721("LearnTgetherPosts", "TGP") {
        _tokenIdCounter.increment();
        owner = msg.sender;
        artifactContractAddress = _artifactContractAddress;
    }

event PostMintedTo(uint256 indexed postId, address indexed authorAddress, string authorName);

function mintPost(
    string memory _content,
    string memory _title,
    string memory _authorName,
    string memory _description
) public returns (uint256) {
    uint256 newTokenId = _tokenIdCounter.current();

    Post memory newPost = Post({
        content: _content,
        title: _title,
        authorAddress: msg.sender,
        authorName: _authorName,
        description: _description
    });

    _safeMint(msg.sender, newTokenId);
    _tokenIdCounter.increment();

    // Save post data in the mapping
    posts[newTokenId] = newPost;

    // Send the post data to the artifact contract
    uint256 artifactId = ArtifactContractInterface(artifactContractAddress).sendArtifact(address(this), newTokenId);
    postToArtifactId[newTokenId] = artifactId;


    // Emit the event with the correct arguments
    emit PostMintedTo(newTokenId, msg.sender, _authorName);
    return (newTokenId);
}


    // Generate a base64-encoded tokenURI dynamically    // Generate a base64-encoded tokenURI dynamically
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        Post memory post = posts[tokenId];
        
        // Create metadata JSON object
        string memory json = string(
            abi.encodePacked(
                "{",
                "\"name\":\"", post.title, "\",",
                "\"description\":\"", post.description, "\",",
                "\"content\":\"", post.content, "\"",
                "}"
            )
        );

  

        // Base64 encode the JSON object and return it as a data URI
        string memory jsonBase64 = Base64.encode(bytes(json));
        return string(abi.encodePacked("data:application/json;base64,", jsonBase64));
    }
   // Getters


    function getPost(uint256 _postId) external view returns(Post memory){
        return posts[_postId];
    }

    function getPostExists(uint256 _postId) external view returns(bool){
        if(ownerOf(_postId) == address(0)){
            return false;
        }else{
            return true;
        }
    }



    // Only Owner Funcitons

    function incrementToken() external ownerOnly {
        _tokenIdCounter.increment();

    }

    function setV2ContractAddress(address _v2ContractAddress) external ownerOnly {
        v2ContractAddress = _v2ContractAddress;
    }




    // Transfer functions

    function transferNFTsToV2(uint256 _tokenId) external {
        require(v2ContractAddress != address(0), "V2 contract address not set");
        
        // Transfer each token and associated post data to the v2 contract
        require(ownerOf(_tokenId) == msg.sender, "Not the owner of the token");
        
        // Get the post data associated with the token ID
        Post memory post = posts[_tokenId];
        
        // Transfer the NFT to the v2 contract
        safeTransferFrom(msg.sender, v2ContractAddress, _tokenId);
        
        // Add the post data to the v2 contract's storage
        V2ContractInterface(v2ContractAddress).addPostData(_tokenId, post.authorAddress, post.authorName, post.title, post.content, post.description );

    }

    function transferToken(address to, uint256 tokenId) external {
    require(ownerOf(tokenId) == msg.sender, "Only the owner can transfer the token");
    _transfer(msg.sender, to, tokenId);
    } 

}
