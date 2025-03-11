//
//  GameScene.swift
//  TextTubes
//
//  Created by Braxton Smallwood on 3/27/24.
//

import SpriteKit
import GameplayKit
import UIKit

extension UIColor {
    /// Create a UIColor from a hex string (e.g., "#FF0000" or "FF0000")
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = ((int >> 24) & 0xff, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            return nil
        }

        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}


class RoundedTile: SKSpriteNode {
    var letter: Character?
    var originalPosition: CGPoint?
    private var directionIndicator: SKLabelNode?
    private var letterLabel: SKLabelNode? // Letter label property
    private var liquidNode: SKSpriteNode? // Liquid node property
    
    override var hash: Int {
            return self.name?.hashValue ?? super.hash
        }
    
    override func isEqual(_ object: Any?) -> Bool {
            guard let otherTile = object as? RoundedTile else { return false }
            return self === otherTile
        }

    init(letter: Character?, color: UIColor, size: CGSize, cornerRadius: CGFloat) {
        self.letter = letter
        super.init(texture: nil, color: color, size: size)

        // Create a shape node for masking
        let shapeNode = SKShapeNode(rect: CGRect(origin: .zero, size: size), cornerRadius: cornerRadius)
        shapeNode.fillColor = color
        shapeNode.strokeColor = .clear

        // Create the mask texture and apply to the sprite node
        let texture = SKView().texture(from: shapeNode)!
        self.texture = texture
        self.color = .clear

        // Set additional properties
        self.zPosition = 0
        self.originalPosition = .zero

        // Initialize and add the liquid node first
        setupLiquidNode(hexColor: "#8FCEF4", cornerRadius: 4.0)

        // Create a letter label if the letter is not nil
        if let letter = letter {
            letterLabel = SKLabelNode(text: String(letter))
            letterLabel!.fontColor = .black
            letterLabel!.fontSize = size.height / 2
            letterLabel!.verticalAlignmentMode = .center
            letterLabel!.horizontalAlignmentMode = .center
            letterLabel!.zPosition = 2 // Higher than liquid
            self.addChild(letterLabel!)
        }

        // Initialize the direction indicator
        directionIndicator = SKLabelNode()
        directionIndicator?.fontName = "Arial"
        directionIndicator?.fontSize = size.width / 3
        directionIndicator?.fontColor = .black
        directionIndicator?.position = CGPoint(x: 0, y: -size.height / 3)
        directionIndicator?.zPosition = 3 // Higher than liquid and letter
        self.addChild(directionIndicator!)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Setup the liquid node with rounded corners
    func setupLiquidNode(hexColor: String, cornerRadius: CGFloat) {
        // Set the fill color using the provided hex code, falling back to a default purple if the conversion fails
        let fillColor = UIColor(hex: hexColor) ?? .purple

        // Create the liquid node
        let liquidNode = SKSpriteNode(color: fillColor, size: self.size)
        liquidNode.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        liquidNode.position = .zero
        liquidNode.zPosition = 1 // Above the base but below the letter
        liquidNode.xScale = 0.0 // Initially hidden

        // Create a shape node for the mask with the correct anchor point
        let maskShape = SKShapeNode(rectOf: self.size, cornerRadius: cornerRadius)
        maskShape.position = .zero
        maskShape.fillColor = .white // Mask should have a solid color
        maskShape.strokeColor = .clear
        maskShape.zPosition = 1

        // Create the crop node and assign the mask to it
        let maskCropNode = SKCropNode()
        maskCropNode.maskNode = maskShape
        maskCropNode.addChild(liquidNode)
        maskCropNode.zPosition = 1

        // Add the masked liquid node to the tile
        self.addChild(maskCropNode)

        // Store the liquid node itself in user data for future access
        self.userData = NSMutableDictionary()
        self.userData?.setValue(liquidNode, forKey: "liquidNode")
    }



    // Fill with liquid in a specified direction
    func fillWithLiquid(direction: String, completion: @escaping () -> Void) {
        guard let liquid = self.userData?.value(forKey: "liquidNode") as? SKSpriteNode else { return }

        liquid.isHidden = false

        switch direction {
        case "→", "←":
            liquid.yScale = 1.0
            liquid.xScale = 0.0
        case "↓", "↑":
            liquid.xScale = 1.0
            liquid.yScale = 0.0
        default:
            liquid.xScale = 0.0
        }

        switch direction {
        case "→":
            liquid.anchorPoint = CGPoint(x: 0, y: 0.5)
            liquid.position = CGPoint(x: -self.size.width / 2, y: 0)
        case "←":
            liquid.anchorPoint = CGPoint(x: 1, y: 0.5)
            liquid.position = CGPoint(x: self.size.width / 2, y: 0)
        case "↓":
            liquid.anchorPoint = CGPoint(x: 0.5, y: 1)
            liquid.position = CGPoint(x: 0, y: self.size.height / 2)
        case "↑":
            liquid.anchorPoint = CGPoint(x: 0.5, y: 0)
            liquid.position = CGPoint(x: 0, y: -self.size.height / 2)
        default:
            return
        }

        let fillAction: SKAction = (direction == "→" || direction == "←") ? SKAction.scaleX(to: 1.0, duration: 0.5) : SKAction.scaleY(to: 1.0, duration: 0.5)
        liquid.run(fillAction, completion: completion)
    }

    // Update direction indicator
    func addDirectionIndicator(direction: String) {
        directionIndicator?.text = direction
    }
}



struct GridPosition {
    var row: Int
    var column: Int
}

class GameScene: SKScene {
    
    let numGridRows = 4
    let numGridColumns = 4
    let numTrayRows = 2
    let numTrayColumns = 5
    let gridPadding: CGFloat = 20.0 // Padding around the entire grid
    let topPadding: CGFloat = 80.0 // Padding at top of grid
    var activeTile: RoundedTile?
    let snapThreshold: CGFloat = 100.0 // Adjust based on your needs
    var puzzleWord: String = ""
    var puzzleWordLabel: SKLabelNode?
    var grid: [[RoundedTile?]] = [] // Represents the grid where nil indicates an empty square
    var path: [GridPosition] = [] // Path taken by the word through the grid
    var unplacedTiles: Set<RoundedTile> = Set()

    
    override func sceneDidLoad() {
        self.backgroundColor = .white
        if let words = loadWordsFromFile(), !words.isEmpty {
            puzzleWord = words.randomElement() ?? "DEFAULT" // Use a default word if none is found
        } else {
            puzzleWord = "FALLBACK" // Fallback word in case the word list couldn't be loaded
        }

        setupGrid()
   //     initializeTileTray()
        addResetButton()
        addNewGameButton()
        addShowWordButton()
        createPuzzleWordLabel()
        initializeGrid()
        addCheckSolutionButton()
    }


    // Grid setup code
    func tileSize() -> CGSize {
        let spacing: CGFloat = 10.0 // Space between tiles
        let totalSpacing = spacing * CGFloat(numGridColumns - 1) + 2 * gridPadding // Updated to include padding
        let tileSize = (self.size.width - totalSpacing) / CGFloat(numGridColumns)
        return CGSize(width: tileSize, height: tileSize)
    }
    
    func initializeGrid() {
        grid = Array(repeating: Array(repeating: nil, count: numGridColumns), count: numGridRows)
    }

    
    func setupGrid() {
        let size = tileSize()
        for row in 0..<numGridRows {
            for column in 0..<numGridColumns {
                let tile = SKShapeNode(rectOf: size, cornerRadius: 4.0)
                tile.fillColor = SKColor.lightGray
                tile.strokeColor = SKColor.gray
                
                // Calculate position with padding included
                let x = size.width * CGFloat(column) + size.width / 2 + 10 * CGFloat(column) + gridPadding
                let y = self.size.height - (size.height * CGFloat(row) + size.height / 2 + 10 * CGFloat(row) + gridPadding + topPadding)
                tile.position = CGPoint(x: x, y: y)
                
                // Add tile to scene
                self.addChild(tile)
            }
        }
    }

    // End grid setup code

    //Tile tray setup
    
    func initializeTileTray() {
        let tileSize = self.tileSize()
        let trayPadding: CGFloat = 30.0 // Padding on the edges of the tray
        let spacing: CGFloat = 5.0 // Space between tiles
        let tilesPerRow = min(4, puzzleWord.count) // Up to 5 tiles per row

        // Calculate starting positions
        let totalRowWidth = CGFloat(tilesPerRow) * tileSize.width + CGFloat(tilesPerRow - 1) * spacing
        let startingX = (self.size.width - totalRowWidth) / 2 + trayPadding // Center tray horizontally with padding
        let startingY: CGFloat = 275.0 // Position of the first tray row from the bottom of the screen
        
        // Shuffle the letters in the puzzle word
        let shuffledLetters = puzzleWord.shuffled()

        for (index, letter) in shuffledLetters.enumerated() {
            let tile = RoundedTile(letter: letter, color: .white, size: tileSize, cornerRadius: 4.0)
            tile.letter = letter
            let label = SKLabelNode(text: String(letter))
            label.fontColor = SKColor.black
            label.fontSize = tileSize.height / 2 // Adjust font size based on tile size
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            tile.addChild(label) // Add the letter label to the tile
            
            tile.setupLiquidNode(hexColor: "#8FCEF4", cornerRadius: 4.0)

            let row = index / tilesPerRow
            let column = index % tilesPerRow
            let positionX = startingX + (tileSize.width + spacing) * CGFloat(column)
            let positionY = startingY - (tileSize.height + spacing) * CGFloat(row)
            tile.position = CGPoint(x: positionX, y: positionY)
            tile.originalPosition = tile.position // Storing original tile position
            
            unplacedTiles.insert(tile)
            self.addChild(tile)
        }
    }
    // End tile tray setup
    
    // WordList
    func loadWordsFromFile() -> [String]? {
        guard let filePath = Bundle.main.path(forResource: "WordList", ofType: "txt") else {
            print("Word list file not found")
            return nil
        }
        
        do {
            let contents = try String(contentsOfFile: filePath)
            // Split the contents into lines, filter out empty lines, and convert each word to uppercase
            let words = contents.components(separatedBy: "\n").filter { !$0.isEmpty }.map { $0.uppercased() }
            return words
        } catch {
            print("Could not load the word list: \(error)")
            return nil
        }
    }
    // End word list

    // Snap to grid code
    func positionForGridCell(row: Int, column: Int) -> CGPoint {
        let tileSize = self.tileSize()
        let spacing: CGFloat = 10.0 // Assuming you have a fixed spacing between tiles
        let x = tileSize.width * CGFloat(column) + tileSize.width / 2 + spacing * CGFloat(column) + gridPadding
        let y = self.size.height - (tileSize.height * CGFloat(row) + tileSize.height / 2 + spacing * CGFloat(row) + gridPadding + topPadding)
        return CGPoint(x: x, y: y)
    }

    func closestGridCell(to point: CGPoint) -> (row: Int, column: Int)? {
        var minDistance = CGFloat.greatestFiniteMagnitude
        var closestCell: (row: Int, column: Int)?
        
        for row in 0..<numGridRows {
            for column in 0..<numGridColumns {
                let cellPosition = positionForGridCell(row: row, column: column)
                let distance = hypot(cellPosition.x - point.x, cellPosition.y - point.y)
                
                if distance < minDistance {
                    minDistance = distance
                    closestCell = (row, column)
                }
            }
        }
        
        return closestCell
    }
    // End snap to grid functionality
    
    // Add reset button
    func addResetButton() {
        let resetButton = SKLabelNode(fontNamed: "Arial")
        resetButton.text = "Reset Tiles"
        resetButton.fontSize = 24
        resetButton.fontColor = SKColor.red
        // Positioning the button on the left side with a margin
        resetButton.position = CGPoint(x: resetButton.frame.size.width / 2 + 20, y: self.frame.maxY - 80)
        resetButton.name = "resetButton"
        self.addChild(resetButton)
    }

    
    func resetTilesToOriginalPositions() {
        // Loop through all child nodes and reset their positions if they are Tiles
        for node in self.children {
            if let tile = node as? RoundedTile, let originalPosition = tile.originalPosition {
                tile.position = originalPosition // Reset to the original position
            }
        }

        // Update the logical grid with the original positions of the tiles
        updateLogicalGridFromVisualPositions()
    }

    // End reset button
    
    // Add show word button
    func addShowWordButton() {
        let showWordButton = SKLabelNode(fontNamed: "Arial")
        showWordButton.text = "Show Word"
        showWordButton.fontSize = 24
        showWordButton.fontColor = SKColor.black
        showWordButton.position = CGPoint(x: self.frame.midX, y: self.frame.minY + 325) // Adjust as needed
        showWordButton.name = "showWordButton" // Important for identifying the node later
        self.addChild(showWordButton)
    }
    
    func createPuzzleWordLabel() {
        let label = SKLabelNode(fontNamed: "Arial")
        label.text = puzzleWord // Set the text to the puzzle word
        label.fontSize = 30
        label.fontColor = SKColor.orange
        label.position = CGPoint(x: self.frame.midX, y: self.frame.midY - 70) // Center on screen, adjust as needed
        label.isHidden = true // Initially hidden
        self.addChild(label)
        puzzleWordLabel = label
    }

    // End show word button
    
    // New Game code
    func addNewGameButton() {
        let newGameButton = SKLabelNode(fontNamed: "Arial")
        newGameButton.text = "New Game"
        newGameButton.fontSize = 24
        newGameButton.fontColor = SKColor.blue
        // Positioning the button on the right side
        // Calculate the position based on the screen width and button width
        newGameButton.position = CGPoint(x: self.frame.width - newGameButton.frame.size.width / 2 - 20, y: self.frame.maxY - 80)
        newGameButton.name = "newGameButton"
        self.addChild(newGameButton)
    }


    func startNewGame() {
        if let words = loadWordsFromFile(), !words.isEmpty {
            puzzleWord = words.randomElement() ?? "DEFAULT"
        } else {
            puzzleWord = "FALLBACK"
        }

        // Clear existing tiles
        self.children.forEach { node in
            if node is RoundedTile {
                node.removeFromParent()
            }
        }

        // Generate new tiles
    //    initializeTileTray()
        resetGrid()
        generatePath(for: puzzleWord)
        placeTiles(for: puzzleWord)
        updateTileDirections()
        placeObstacleTiles(count: 5)
    }
    // End New Game code
    
    // Word Path generation
    func generatePath(for word: String) {
        var attempts = 0
        let maxAttempts = 15 // Set a maximum to prevent infinite loops

        while attempts < maxAttempts {
            path.removeAll()

            // Randomly choose a starting position in the left column
            let startRow = Int.random(in: 0..<numGridRows)
            path.append(GridPosition(row: startRow, column: 0))

            var currentRow = startRow
            var success = true

            for _ in 1..<word.count {
                let lastPosition = path.last!
                
                // Generate potential next positions (right, up, down) ensuring they are within grid bounds
                var nextPositions = [GridPosition(row: lastPosition.row, column: min(lastPosition.column + 1, numGridColumns - 1))]
                if lastPosition.row > 0 { nextPositions.append(GridPosition(row: lastPosition.row - 1, column: lastPosition.column)) } // up
                if lastPosition.row < numGridRows - 1 { nextPositions.append(GridPosition(row: lastPosition.row + 1, column: lastPosition.column)) } // down
                
                // Filter out positions already in the path
                nextPositions = nextPositions.filter { position in
                    !path.contains { $0.row == position.row && $0.column == position.column }
                }

                if nextPositions.isEmpty { // Handle potential dead ends
                    success = false
                    break // Exit the loop and retry path generation
                }

                // Randomly select the next position from the remaining valid options
                if let nextPosition = nextPositions.randomElement() {
                    path.append(nextPosition)
                    currentRow = nextPosition.row
                }
            }

            if success && path.count == word.count {
                break // Exit the while loop if a successful path is generated
            }

            attempts += 1
        }
    }


    func placeTiles(for word: String) {
        // Predefine hex colors for start, end, and other tiles
        let startTileColor = UIColor(hex: "#54A37D") ?? .green  // Green
        let endTileColor = UIColor(hex: "#E27378") ?? .red     // Red
        let normalTileColor = UIColor(hex: "#FDE6BD") ?? .white // White
        
        var tilesWithDirections: [RoundedTile] = []
        let letters = Array(word)
        
        for (index, gridPosition) in path.enumerated() {
            // Determine the color based on tile type
            let tileColor: UIColor
            if index == 0 {
                tileColor = startTileColor
            } else if index == letters.count - 1 {
                tileColor = endTileColor
            } else {
                tileColor = normalTileColor
            }

            // Create the tile with the selected color
            let letter = letters[index]
            let tile = RoundedTile(letter: letter, color: tileColor, size: tileSize(), cornerRadius: 4.0)
            tile.letter = letters[index]

            // Add a letter label to the tile
            let label = SKLabelNode(text: String(letters[index]))
            label.fontColor = .black
            label.fontSize = tileSize().height / 2
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            tile.addChild(label)

            // Add direction indicators for tiles with a following path
            if index < path.count - 1 {
                let nextPos = path[index + 1]
                let direction = determineDirection(from: gridPosition, to: nextPos)
                tile.addDirectionIndicator(direction: direction)
            }

            // Place the first tile directly on the board and mark it as immovable
            if index == 0 {
                let tilePosition = positionForGridCell(row: gridPosition.row, column: gridPosition.column)
                tile.position = tilePosition
                self.addChild(tile)
                tile.originalPosition = tilePosition
                grid[gridPosition.row][gridPosition.column] = tile
                tile.userData = ["immovable": true]
            } else {
                tilesWithDirections.append(tile)
            }
        }

        // Shuffle and place the remaining tiles in the tray
        tilesWithDirections.shuffle()
        for (index, tile) in tilesWithDirections.enumerated() {
            let position = calculateTrayPosition(index: index, tileSize: tileSize(), trayPadding: 30.0, spacing: 5.0, tilesPerRow: min(4, puzzleWord.count))
            tile.position = CGPoint(x: position.x, y: position.y)
            tile.originalPosition = position
            self.addChild(tile)
        }
    }


    // Helper function to calculate tray positions
    func calculateTrayPosition(index: Int, tileSize: CGSize, trayPadding: CGFloat, spacing: CGFloat, tilesPerRow: Int) -> CGPoint {
        let totalRowWidth = CGFloat(tilesPerRow) * tileSize.width + CGFloat(tilesPerRow - 1) * spacing
        let startingX = (self.size.width - totalRowWidth) / 2 + trayPadding
        let startingY: CGFloat = 275.0 // Adjust as necessary
        let row = index / tilesPerRow
        let column = index % tilesPerRow
        let x = startingX + (tileSize.width + spacing) * CGFloat(column)
        let y = startingY - (tileSize.height + spacing) * CGFloat(row)
        return CGPoint(x: x, y: y)
    }


    // Helper function to determine direction
    func determineDirection(from: GridPosition, to: GridPosition) -> String {
        if to.column > from.column { return "→" }
        else if to.row > from.row { return "↓" }
        else if to.row < from.row { return "↑" }
        return "←" // Default to left if no other condition is met
    }

    
    func updateTileDirections() {
        for i in 0..<path.count - 1 {
            let currentPosition = path[i]
            let nextPosition = path[i + 1]

            let direction: String
            if nextPosition.column > currentPosition.column {
                direction = "→"
            } else if nextPosition.column < currentPosition.column {
                direction = "←"
            } else if nextPosition.row > currentPosition.row {
                direction = "↓"
            } else {
                direction = "↑"
            }

            if let tile = grid[currentPosition.row][currentPosition.column] {
                tile.addDirectionIndicator(direction: direction)
            }
        }
        // Optionally, remove the indicator from the last tile, as it's the end of the word
        if let lastPosition = path.last, let lastTile = grid[lastPosition.row][lastPosition.column] {
            lastTile.addDirectionIndicator(direction: "")
        }
    }
    
    func printGridPath() {
        for row in 0..<numGridRows {
            var rowString = ""
            for column in 0..<numGridColumns {
                if let tile = grid[row][column], let letter = tile.letter {
                    // If it's the first or last tile, you can use special characters or just use the letter
                    if tile.userData?["immovable"] as? Bool ?? false {
                        rowString += "[\(letter)]" // Brackets to indicate immovable tiles
                    } else {
                        rowString += " \(letter) "
                    }
                } else {
                    // Placeholder for empty spaces or obstacles
                    rowString += " . "
                }
            }
            print(rowString)
        }
        print("\n") // Extra line for better separation
    }

    
    // End Word Path Generation Code
    
    // Start Obstacle Code
    
    func placeObstacleTiles(count: Int) {
        var availablePositions: [GridPosition] = []

        // Identify available positions for obstacle tiles
        for row in 0..<numGridRows {
            for column in 0..<numGridColumns {
                let position = GridPosition(row: row, column: column)
                if !path.contains(where: { $0.row == row && $0.column == column }) {
                    availablePositions.append(position)
                }
            }
        }

        // Randomly select positions to place obstacle tiles
        availablePositions.shuffle()
        let obstaclePositions = availablePositions.prefix(count)

        // Place obstacle tiles
        for position in obstaclePositions {
            let obstacleTile = RoundedTile(letter: nil, color: .brown, size: tileSize(), cornerRadius: 4.0)
            obstacleTile.position = positionForGridCell(row: position.row, column: position.column)
            self.addChild(obstacleTile)
            // Mark the tile as immovable
            obstacleTile.userData = ["immovable": true]
            
            // Optionally, if using an array to track tiles, add the obstacle tile to the grid
            grid[position.row][position.column] = obstacleTile
        }
    }

    // End Obstacle Code
    
    // Solution Validation
    
    func checkSolution() -> Bool {
        // Ensure the path and the grid match the puzzle word
        var currentWord = ""
        
        // Follow the path generated for the word
        for position in path {
            // Ensure there's a tile at each position
            guard let tile = grid[position.row][position.column], let letter = tile.letter else {
                print("Solution incomplete: Missing tile at \(position).")
                return false
            }
            
            // Append the letter to the current word
            currentWord.append(letter)
        }
        
        // Check if the constructed word matches the puzzle word
        if currentWord == puzzleWord {
            animateSolution()
            print("Solution is correct!")
            return true
        } else {
            print("Solution does not match the puzzle word. Found: \(currentWord), Expected: \(puzzleWord)")
            return false
        }
    }

    
    func isSolutionValid() -> Bool {
        let letters = Array(puzzleWord)
        
        for (index, gridPosition) in path.enumerated() {
            guard let tile = grid[gridPosition.row][gridPosition.column],
                  let letter = tile.letter else {
                print("Missing tile at index \(index), grid position (\(gridPosition.row), \(gridPosition.column))")
                return false
            }
            
            if letters[index] != letter {
                print("Mismatch at index \(index), grid position (\(gridPosition.row), \(gridPosition.column)). Expected: '\(letters[index])', Found: '\(letter)'")
                return false
            }
        }

        return true // All tiles are correctly placed
    }


    func addCheckSolutionButton() {
        let checkButton = SKLabelNode(fontNamed: "Arial")
        checkButton.text = "Check Solution"
        checkButton.fontSize = 24
        checkButton.fontColor = SKColor.blue
        checkButton.position = CGPoint(x: self.frame.midX, y: self.frame.minY + 100)
        checkButton.name = "checkSolutionButton"
        self.addChild(checkButton)
    }
    
    func moveTile(tile: RoundedTile, to position: GridPosition) -> Bool {
        // Check if the target position is already occupied or contains an obstacle
        if let existingTile = grid[position.row][position.column], existingTile.userData?["immovable"] as? Bool == true {
            // Tile cannot be moved to this cell
            print("Cannot move to an obstacle or immovable tile at \(position).")
            return false
        }

        // Remove the tile from its previous position
        if let oldPosition = findTilePosition(tile: tile) {
            grid[oldPosition.row][oldPosition.column] = nil
        }

        // Add the tile to its new position only if it's not blocked
        grid[position.row][position.column] = tile
        tile.position = positionForGridCell(row: position.row, column: position.column)
        
        unplacedTiles.remove(tile)

           // Check if all tiles have been placed
           if unplacedTiles.isEmpty {
              _ = checkSolution()
           }
        
        return true
    }


    // Helper function to find a tile's current position in the grid
    func findTilePosition(tile: RoundedTile) -> GridPosition? {
        for row in 0..<numGridRows {
            for column in 0..<numGridColumns {
                if grid[row][column] === tile {
                    return GridPosition(row: row, column: column)
                }
            }
        }
        return nil
    }
    
    func resetGrid() {
        // Assuming `grid` is defined as [[Tile?]] or a similar structure
        grid = Array(repeating: Array(repeating: nil, count: numGridColumns), count: numGridRows)
    }

    
    func gridPosition(from visualPosition: CGPoint) -> GridPosition? {
        // Assuming tiles are placed from the top down with consistent spacing
        let tileWidthWithSpacing = tileSize().width + 10.0 // Adjust based on actual spacing
        let tileHeightWithSpacing = tileSize().height + 10.0 // Adjust based on actual spacing
        
        // Calculate starting X and Y considering the entire scene's height
        let startX = gridPadding
        let startY = self.size.height - topPadding - tileSize().height / 2
        
        // Translate visualPosition to grid coordinates
        let adjustedX = visualPosition.x - startX
        let adjustedY = startY - visualPosition.y
        
        let column = Int(adjustedX / tileWidthWithSpacing)
        let row = Int(adjustedY / tileHeightWithSpacing)
        
        // Ensure the calculated grid position falls within the actual grid
        if column >= 0, column < numGridColumns, row >= 0, row < numGridRows {
            return GridPosition(row: row, column: column)
        } else {
            return nil // Position falls outside the grid
        }
    }




    func updateLogicalGridFromVisualPositions() {
        // Reset the logical grid
        self.initializeGrid()
        
        self.children.forEach { node in
            if let tile = node as? RoundedTile, let visualPosition = tile.position as CGPoint? {
                if let gridPosition = self.gridPosition(from: visualPosition) {
                    grid[gridPosition.row][gridPosition.column] = tile
                }
            }
        }
    }

    // Visual pizzazz
    
    func prepareTilesForAnimation() {
        for position in path {
            if let tile = grid[position.row][position.column] {
                tile.setupLiquidNode(hexColor: "#8FCEF4", cornerRadius: 4.0) // Prepare each tile with a liquid node
            }
        }
    }

    func animateSolution() {
        // Ensure liquid nodes are set up
        prepareTilesForAnimation()

        var index = 0 // Keep track of the index in the path

        func animateNextTile() {
            guard index < path.count else { return } // Ensure there are more tiles to animate

            let position = path[index]
            if let tile = grid[position.row][position.column] {
                // Determine the fill direction based on the previous tile's direction, except for the first tile
                let fillDirection: String
                if index == 0 {
                    // For the first tile, use its own direction
                    fillDirection = determineDirection(from: position, to: path[min(index + 1, path.count - 1)])
                } else {
                    // For subsequent tiles, use the direction of the previous tile towards the current one
                    fillDirection = determineDirection(from: path[index - 1], to: position)
                }

                tile.fillWithLiquid(direction: fillDirection) {
                    // Proceed to next tile after animation completes
                    index += 1
                    animateNextTile()
                }
            }
        }

        animateNextTile() // Start the animation chain
    }


    
    // Update touch event methods for your game's drag-and-drop logic
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodesAtLocation = self.nodes(at: location)
        
        for node in nodesAtLocation {
            if node.name == "checkSolutionButton" {
                updateLogicalGridFromVisualPositions()
                // Call the function to check if the solution is correct
                if checkSolution() {
                    print("Correct solution!")
                    // Additional actions for correct solution
                } else {
                    print("Incorrect solution, please try again.")
                    // Additional actions for incorrect solution
                }
                // Print the current grid path for debugging
                printGridPath()
                break
            } else if node.name == "newGameButton" {
                // Handle new game button action...
                startNewGame()
                // Optionally hide the puzzle word when starting a new game
                puzzleWordLabel?.isHidden = true
            } else if node.name == "resetButton" {
                // Handle reset button action...
                resetTilesToOriginalPositions()
            } else if node.name == "showWordButton" {
                if let label = puzzleWordLabel {
                    label.text = puzzleWord // Update text to the current puzzle word
                    label.isHidden.toggle() // Toggle visibility
                }
            } else if let tile = node as? RoundedTile {
                // Check if the tile is immovable before setting it as active
                if tile.userData?["immovable"] as? Bool ?? false {
                    print("This tile is immovable.")
                } else {
                    // Set the tile as active and ready to be moved
                    activeTile = tile
                    tile.zPosition = 1 // Bring the tile to the front
                }
            }
        }
    }


    

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let tile = activeTile else { return }
        let location = touch.location(in: self)
        tile.position = location // Move only the active tile
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let tile = activeTile else { return }
        let location = touch.location(in: self)

        if let newPosition = gridPosition(from: location), moveTile(tile: tile, to: newPosition) {
            // Only update the logical grid if the move was successful
            updateLogicalGridFromVisualPositions()
        } else if let originalPosition = tile.originalPosition {
            // If moving to the new position failed, reset to the original position
            tile.position = originalPosition
        }

        tile.zPosition = 0 // Reset zPosition if changed
        activeTile = nil // Stop tracking the tile
    }





    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTile?.zPosition = 0 // Reset zPosition if changed
        activeTile = nil // Stop tracking the tile
    }

    
    override func update(_ currentTime: TimeInterval) {
        // Your game's frame-by-frame logic, if needed
    }
}
