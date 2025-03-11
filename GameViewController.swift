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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as? SKView {
            // Create and configure the scene.
            let scene = GameScene(size: view.bounds.size) // Initialize GameScene with the size of the view.
            scene.scaleMode = .aspectFill // Set the scale mode to scale to fit the window
            
            // Present the scene.
            view.presentScene(scene)
            
            view.ignoresSiblingOrder = true
            
            // (Optional) Show statistics such as fps and node count
            view.showsFPS = true
            view.showsNodeCount = true
        }
    }

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
