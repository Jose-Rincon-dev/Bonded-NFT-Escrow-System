// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BondedNFT
 * @dev NFT contract for bond certificates with metadata
 */
contract BondedNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;
    
    struct BondMetadata {
        uint256 bondId;
        address issuer;
        uint256 amount;
        uint256 expiryTime;
        string assetType;
        bool isActive;
    }
    
    mapping(uint256 => BondMetadata) public bondMetadata;
    mapping(uint256 => uint256) public bondIdToTokenId; // bondId => tokenId
    
    event BondNFTMinted(uint256 indexed tokenId, uint256 indexed bondId, address indexed holder);
    
    constructor(address initialOwner) ERC721("BondedNFT", "BNFT") Ownable(initialOwner) {}
    
    function mintBondNFT(
        address to,
        uint256 bondId,
        address issuer,
        uint256 amount,
        uint256 expiryTime,
        string memory assetType,
        string memory newTokenURI
    ) external onlyOwner returns (uint256) {
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, newTokenURI);
        
        bondMetadata[tokenId] = BondMetadata({
            bondId: bondId,
            issuer: issuer,
            amount: amount,
            expiryTime: expiryTime,
            assetType: assetType,
            isActive: true
        });
        
        bondIdToTokenId[bondId] = tokenId;
        
        emit BondNFTMinted(tokenId, bondId, to);
        return tokenId;
    }
    
    function deactivateBond(uint256 tokenId) external onlyOwner {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        bondMetadata[tokenId].isActive = false;
    }
    
    function getBondMetadata(uint256 tokenId) external view returns (BondMetadata memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return bondMetadata[tokenId];
    }
    
    function getTokenIdByBondId(uint256 bondId) external view returns (uint256) {
        return bondIdToTokenId[bondId];
    }
    
    // Override required functions
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
    function _update(address to, uint256 tokenId, address auth) internal override(ERC721) returns (address) {
        return super._update(to, tokenId, auth);
    }
    
    function _increaseBalance(address account, uint128 value) internal override(ERC721) {
        super._increaseBalance(account, value);
    }
}