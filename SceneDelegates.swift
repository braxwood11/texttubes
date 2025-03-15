//
//  SceneDelegates.swift
//  TextTubes
//
//  Created by Braxton Smallwood on 3/14/25.
//

import Foundation

// Protocol for Map Scene to communicate with GameViewController
protocol MapSceneDelegate: AnyObject {
    // Called when a puzzle is selected from the map
    func mapScene(_ scene: MapScene, didSelectPuzzleWithWord word: String, connectionIndex: Int)
}

// Protocol for Game Scene to communicate with GameViewController
protocol GameSceneDelegate: AnyObject {
    // Called when a puzzle is completed
    func gameScene(_ scene: GameScene, didCompletePuzzleWithWord word: String, connectionIndex: Int)
    
    // Called if a player cancels out of a puzzle
    func gameScene(_ scene: GameScene, didCancelPuzzle: Bool)
}
