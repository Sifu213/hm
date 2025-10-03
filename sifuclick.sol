// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SifuClick
 * @dev Contrat ultra simple pour enregistrer les clicks des joueurs
 */
contract SifuClick {
    // Événement émis à chaque click
    event Click(
        address indexed player,
        uint256 timestamp
    );

    // Mapping pour compter les clicks par joueur
    mapping(address => uint256) public clicks;
    
    // Compteur global
    uint256 public totalClicks;

    /**
     * @dev Fonction principale - enregistre un click
     * @param playerAddress L'adresse du joueur
     */
    function click(address playerAddress) external {
        require(playerAddress != address(0), "Invalid address");
        
        // Incrémenter les compteurs
        clicks[playerAddress]++;
        totalClicks++;
        
        // Émettre l'événement
        emit Click(playerAddress, block.timestamp);
    }
}