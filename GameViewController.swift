//
//  GameViewController.swift
//  TextTubes
//
//  Created by Braxton Smallwood on 3/27/24.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    // Track current game state
    private var currentPuzzleWord: String?
    private var currentConnectionIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Start with the map scene instead of going directly to a game scene
        presentMapScene()
    }
    
    // MARK: - Scene Presentation Methods
    
    func presentMapScene() {
        if let view = self.view as? SKView {
            // Create and configure the map scene
            let scene = MapScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill
            
            // Set the map scene delegate to this view controller
            scene.gameDelegate = self  // Make sure this line is here!
            
            // Present the map scene
            view.presentScene(scene)
            
            view.ignoresSiblingOrder = true
            
            // Optional debug info
            view.showsFPS = true
            view.showsNodeCount = true
        }
    }
    
    func presentGameScene(withWord word: String, connectionIndex: Int) {
        if let view = self.view as? SKView {
            // Store current puzzle info
            currentPuzzleWord = word
            currentConnectionIndex = connectionIndex
            
            // Create and configure the game scene
            let scene = GameScene(size: view.bounds.size)
            scene.scaleMode = .aspectFill
            
            // Pass the word to solve
            scene.puzzleWord = word
            scene.connectionIndex = connectionIndex
            
            // Set the game scene delegate to this view controller
            scene.gameDelegate = self
            
            // Add a debug print
            print("About to present game scene with word: \(word)")
            
            // Present the game scene
            view.presentScene(scene, transition: SKTransition.fade(withDuration: 0.5))
            
            view.ignoresSiblingOrder = true
        }
    }
    
    // MARK: - System Overrides

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}

// MARK: - MapSceneDelegate

extension GameViewController: MapSceneDelegate {
    func mapScene(_ scene: MapScene, didSelectPuzzleWithWord word: String, connectionIndex: Int) {
        print("GameViewController received delegate call to start puzzle with word: \(word)")
        // Transition to game scene with the selected word
        presentGameScene(withWord: word, connectionIndex: connectionIndex)
    }
}

// MARK: - GameSceneDelegate

extension GameViewController: GameSceneDelegate {
    func gameScene(_ scene: GameScene, didCompletePuzzleWithWord word: String, connectionIndex: Int) {
        // First return to the map scene
        presentMapScene()
        
        // Then update the map with the completed connection
        // We need to do this after a short delay to ensure the map scene is loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let skView = self.view as? SKView,
               let mapScene = skView.scene as? MapScene {
                mapScene.completeConnection(index: connectionIndex)
            }
        }
    }
    
    func gameScene(_ scene: GameScene, didCancelPuzzle: Bool) {
        // Return to map without updating anything
        presentMapScene()
    }
}
