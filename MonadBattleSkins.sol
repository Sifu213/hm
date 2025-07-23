// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title MonadBattleSkins
 * @dev Contrat NFT pour les skins de personnages du jeu Monad Battle
 */
contract MonadBattleSkins is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    // Types de skins disponibles
    enum SkinType { KEONE, PORT, BILL, MIKE, NINI }
    
    // Prix de mint pour chaque type de skin (en wei)
    uint256 public constant SKIN_PRICE = 1000000000000000; // 0.001 MON
    
    // URIs IPFS fixes pour chaque type de skin
    mapping(SkinType => string) public skinURIs;
    
    // Mapping tokenId vers type de skin
    mapping(uint256 => SkinType) public tokenSkinType;
    
    // Événement émis lors du mint
    event SkinMinted(
        address indexed to,
        uint256 indexed tokenId,
        SkinType indexed skinType,
        string tokenURI
    );
    
    constructor() ERC721("Monad Battle Skins", "MBS") Ownable(msg.sender) {
        
        
        skinURIs[SkinType.KEONE] = "ipfs://bafkreigo7t4zdx3fe5jgf3o7seuzz7676baayqjjk5z2irbjnknkw75y3a";
        skinURIs[SkinType.PORT] = "ipfs://bafkreieg5iala2zupwgcgcu3fhy2blwqz2n625tmzmeq5xszkwyphizx3a";
        skinURIs[SkinType.BILL] = "ipfs://bafkreic4de3tkgecfydnmzoypknxo73ha4efzvczsyesyt44godq7ife6i";
        skinURIs[SkinType.MIKE] = "ipfs://bafkreiadrex6ow6nkfp4ltbr6rt6wy7fy4dmpqgz7jeedfpv33vuxcdxfu";
        skinURIs[SkinType.NINI] = "ipfs://bafkreieknbk5jfzywdz47mbpq2pdxsj7h2b7hcudei7jxw2jhyeakamd5m";
        
        // Start token IDs at 1
        _tokenIdCounter.increment();
    }
    
     
    /**
     * @dev Mint un NFT skin
     * @param to Adresse qui recevra le NFT
     * @param skinType Type de skin à minter
     */
    function mintSkin(address to, SkinType skinType) public payable {
        require(msg.value >= SKIN_PRICE, "Insufficient payment");
        require(bytes(skinURIs[skinType]).length > 0, "No URI set for this skin type");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        // Récupérer l'URI pour ce type de skin
        string memory tokenURI_ = skinURIs[skinType];
        
        // Stocker le type de skin
        tokenSkinType[tokenId] = skinType;
        
        // Mint le NFT
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        
        emit SkinMinted(to, tokenId, skinType, tokenURI_);
        
        // Rembourser l'excédent s'il y en a un
        if (msg.value > SKIN_PRICE) {
            payable(msg.sender).transfer(msg.value - SKIN_PRICE);
        }
    }
    
    /**
     * @dev Mint pour soi-même
     * @param skinType Type de skin à minter
     */
    function mint(SkinType skinType) external payable {
        mintSkin(msg.sender, skinType);
    }
    
    /**
     * @dev Obtenir l'URI d'un type de skin
     * @param skinType Type de skin
     * @return URI IPFS du skin
     */
    function getSkinURI(SkinType skinType) external view returns (string memory) {
        return skinURIs[skinType];
    }
    
    /**
     * @dev Obtenir tous les NFTs d'une adresse avec leurs types
     * @param owner Adresse du propriétaire
     * @return tokenIds Array des IDs des tokens
     * @return skinTypes Array des types de skins correspondants
     */
    function getOwnedSkins(address owner) external view returns (uint256[] memory tokenIds, SkinType[] memory skinTypes) {
        uint256 balance = balanceOf(owner);
        tokenIds = new uint256[](balance);
        skinTypes = new SkinType[](balance);
        
        uint256 currentIndex = 0;
        uint256 currentSupply = _tokenIdCounter.current();
        
        for (uint256 i = 1; i < currentSupply; i++) {
            if (_ownerOf(i) == owner) {
                tokenIds[currentIndex] = i;
                skinTypes[currentIndex] = tokenSkinType[i];
                currentIndex++;
                if (currentIndex >= balance) break;
            }
        }
    }
    
    /**
     * @dev Vérifier si une adresse possède un type de skin spécifique
     * @param owner Adresse à vérifier
     * @param skinType Type de skin à chercher
     * @return true si la personne possède ce type de skin
     */
    function ownsSkinType(address owner, SkinType skinType) external view returns (bool) {
        uint256 balance = balanceOf(owner);
        if (balance == 0) return false;
        
        uint256 currentSupply = _tokenIdCounter.current();
        
        for (uint256 i = 1; i < currentSupply; i++) {
            if (_ownerOf(i) == owner && tokenSkinType[i] == skinType) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * @dev Obtenir le nombre total de NFTs mintés
     * @return Nombre total de NFTs
     */
    function totalSupply() external view returns (uint256) {
        return _tokenIdCounter.current() - 1;
    }
    
    /**
     * @dev Retirer les fonds du contrat (owner seulement)
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdrawal failed");
    }
    
    /**
     * @dev Obtenir le solde du contrat
     * @return Solde en wei
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Override nécessaire pour ERC721URIStorage
     */
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }
    
    /**
     * @dev Override pour supporter les interfaces
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}