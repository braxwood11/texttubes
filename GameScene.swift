//
//  GameScene.swift
//  TextTubes
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

// MARK: - Pipe Direction Enum
enum PipeDirection {
    case up, down, left, right
    
    var opposite: PipeDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

// MARK: - Pipe Type Enum
enum PipeType {
    case straight(PipeDirection)  // Vertical or horizontal straight pipe
    case elbow(PipeDirection, PipeDirection)  // Corner pipe with two openings
    case start(PipeDirection)  // Starting pipe (one opening)
    case end(PipeDirection)  // Ending pipe (one opening)
    
    // Helper to check if a direction is an opening in this pipe
    func hasOpening(in direction: PipeDirection) -> Bool {
        switch self {
        case .straight(let dir):
            return dir == direction || dir.opposite == direction
        case .elbow(let dir1, let dir2):
            return dir1 == direction || dir2 == direction
        case .start(let dir):
            return dir == direction
        case .end(let dir):
            return dir == direction
        }
    }
}

// MARK: - Updated PipeTile class with improved visuals and logic

class PipeTile: SKSpriteNode {
    // Core properties
    var letter: Character?
    var originalPosition: CGPoint?
    var pipeType: PipeType?
    var isObstacle: Bool = false
    
    // UI elements
    private var letterLabel: SKLabelNode?
    private var pipeNode: SKShapeNode?
    private var liquidNode: SKShapeNode?
    private var cropNode: SKCropNode?
    
    // Constants for rendering
    private let pipeLineWidth: CGFloat = 8.0 // Increased thickness
    private let pipeColor = UIColor(hex: "#333333") ?? .darkGray
    private let filledColor = UIColor(hex: "#FDE6BD") ?? .white
    private let liquidColor = UIColor(hex: "#4F97C7") ?? .blue // Deeper blue for better visibility
    
    override var hash: Int {
        return self.name?.hashValue ?? super.hash
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let otherTile = object as? PipeTile else { return false }
        return self === otherTile
    }
    
    init(letter: Character?, color: UIColor, size: CGSize, cornerRadius: CGFloat, pipeType: PipeType? = nil, isObstacle: Bool = false) {
        self.letter = letter
        self.pipeType = pipeType
        self.isObstacle = isObstacle
        super.init(texture: nil, color: .clear, size: size)
        
        // Create background with rounded corners
        let background = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        background.fillColor = color
        background.strokeColor = .gray
        background.lineWidth = 1.0
        background.position = .zero
        self.addChild(background)
        
        // Add letter label
        if let letter = letter {
            letterLabel = SKLabelNode(text: String(letter))
            letterLabel!.fontColor = .black
            letterLabel!.fontSize = size.height / 2.5
            letterLabel!.fontName = "ArialRoundedMTBold" // Better font
            letterLabel!.verticalAlignmentMode = .center
            letterLabel!.horizontalAlignmentMode = .center
            letterLabel!.zPosition = 10 // Above the pipe
            self.addChild(letterLabel!)
        }
        
        // Only draw pipes if this isn't an obstacle tile
        if !isObstacle && pipeType != nil {
            // Draw the pipe shape
            drawPipe(type: pipeType!, size: size)
            
            // Setup for liquid flow
            setupLiquidNode(for: pipeType!, size: size, cornerRadius: cornerRadius)
        }
        
        // Set additional properties
        self.zPosition = 0
        self.originalPosition = .zero
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Drawing Methods
    
    private func drawPipe(type: PipeType, size: CGSize) {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        // Pipe takes up 40% of tile width for better proportions
        let pipeWidth = size.width * 0.4
        
        pipeNode = SKShapeNode()
        pipeNode?.strokeColor = pipeColor
        pipeNode?.lineWidth = pipeLineWidth
        pipeNode?.lineCap = .round  // Rounded ends
        pipeNode?.lineJoin = .round // Rounded corners
        pipeNode?.fillColor = .clear // No fill, just the stroke
        pipeNode?.zPosition = 5
        
        // The path for the pipe shape
        let path = UIBezierPath()
        let insetFactor: CGFloat = 0.3 // How far to inset the pipe from the edge
        
        switch type {
        case .straight(let direction):
            if direction == .up || direction == .down {
                // Vertical pipe
                let topPoint = CGPoint(x: 0, y: halfHeight * (1 - insetFactor))
                let bottomPoint = CGPoint(x: 0, y: -halfHeight * (1 - insetFactor))
                path.move(to: bottomPoint)
                path.addLine(to: topPoint)
            } else {
                // Horizontal pipe
                let leftPoint = CGPoint(x: -halfWidth * (1 - insetFactor), y: 0)
                let rightPoint = CGPoint(x: halfWidth * (1 - insetFactor), y: 0)
                path.move(to: leftPoint)
                path.addLine(to: rightPoint)
            }
            
        case .elbow(let dir1, let dir2):
            // Corner pipe
            let startPoint = getEndpointForDirection(dir1.opposite, size: size, insetFactor: insetFactor)
            let endPoint = getEndpointForDirection(dir2.opposite, size: size, insetFactor: insetFactor)
            
            path.move(to: startPoint)
            // For smoother corners, we use quadratic curves instead of straight lines
            let controlPoint = CGPoint.zero // Center of tile
            
            // Draw the path with a quadratic curve for smoother corners
            path.move(to: startPoint)
            path.addLine(to: controlPoint)
            path.addLine(to: endPoint)
            
        case .start(let direction):
            // Start cap - one opening (from center to edge)
            let centerPoint = CGPoint.zero
            let edgePoint = getEndpointForDirection(direction.opposite, size: size, insetFactor: insetFactor)
            
            // Draw a line from center to the edge
            path.move(to: centerPoint)
            path.addLine(to: edgePoint)
            
            // Add a filled circle at the center for the start bubble
            let startNode = SKShapeNode(circleOfRadius: pipeWidth / 2)
            startNode.fillColor = pipeColor
            startNode.strokeColor = pipeColor
            startNode.position = centerPoint
            startNode.zPosition = 4
            self.addChild(startNode)
            
        case .end(let direction):
            // End cap - one opening (from edge to center)
            let centerPoint = CGPoint.zero
            let edgePoint = getEndpointForDirection(direction.opposite, size: size, insetFactor: insetFactor)
            
            // Draw a line from the edge to center
            path.move(to: edgePoint)
            path.addLine(to: centerPoint)
            
            // Add a filled circle at the center for the end bubble
            let endNode = SKShapeNode(circleOfRadius: pipeWidth / 2)
            endNode.fillColor = pipeColor
            endNode.strokeColor = pipeColor
            endNode.position = centerPoint
            endNode.zPosition = 4
            self.addChild(endNode)
        }
        
        pipeNode?.path = path.cgPath
        self.addChild(pipeNode!)
    }
    
    private func getEndpointForDirection(_ direction: PipeDirection, size: CGSize, insetFactor: CGFloat) -> CGPoint {
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        
        switch direction {
        case .up:
            return CGPoint(x: 0, y: halfHeight * (1 - insetFactor))
        case .down:
            return CGPoint(x: 0, y: -halfHeight * (1 - insetFactor))
        case .left:
            return CGPoint(x: -halfWidth * (1 - insetFactor), y: 0)
        case .right:
            return CGPoint(x: halfWidth * (1 - insetFactor), y: 0)
        }
    }
    
    // MARK: - Liquid Animation Setup
    
    private func setupLiquidNode(for pipeType: PipeType, size: CGSize, cornerRadius: CGFloat) {
        // Create the liquid node (initially hidden)
        liquidNode = SKShapeNode()
        liquidNode?.fillColor = .clear
        liquidNode?.strokeColor = liquidColor
        liquidNode?.lineWidth = pipeLineWidth * 0.8 // Slightly thinner than the pipe
        liquidNode?.lineCap = .round
        liquidNode?.lineJoin = .round
        liquidNode?.alpha = 0.9
        liquidNode?.zPosition = 6 // Above the pipe but below the letter
        liquidNode?.isHidden = true
        
        // Create the path that matches the pipe path
        liquidNode?.path = pipeNode?.path
        
        self.addChild(liquidNode!)
    }
    
    // MARK: - Liquid Animation
    
    func fillWithLiquid(duration: TimeInterval = 0.6, completion: @escaping () -> Void) {
        guard !isObstacle, let pipeType = self.pipeType else {
            completion()
            return
        }
        
        liquidNode?.isHidden = false
        liquidNode?.removeAllActions()
        
        // Set initial state - transparent
        liquidNode?.alpha = 0.0
        
        // Simple fade-in animation for the liquid
        let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: duration)
        
        // For start/end pipe types, we add a center bubble animation
        if case .start = pipeType {
            // Create a bubble at the center for start pipe
            addBubbleAnimation(duration: duration)
        } else if case .end = pipeType {
            // Create a bubble at the center for end pipe
            addBubbleAnimation(duration: duration)
        }
        
        // Run the animation
        liquidNode?.run(fadeIn) {
            completion()
        }
    }

    // Helper method to create the bubble animation
    private func addBubbleAnimation(duration: TimeInterval) {
        // Create a bubble at the center
        let bubbleNode = SKShapeNode(circleOfRadius: pipeLineWidth * 0.4)
        bubbleNode.fillColor = liquidColor
        bubbleNode.strokeColor = liquidColor
        bubbleNode.position = .zero
        bubbleNode.zPosition = 7
        bubbleNode.alpha = 0
        self.addChild(bubbleNode)
        
        // Animate the bubble
        let bubbleFadeIn = SKAction.fadeIn(withDuration: duration * 0.5)
        bubbleNode.run(bubbleFadeIn)
    }
    
    // Helper to calculate the total length of a path
    private func calculatePathLength(_ path: CGPath) -> CGFloat {
        var pathLength: CGFloat = 0
        var start = CGPoint.zero
        var hasStartPoint = false
        
        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                start = point
                hasStartPoint = true
            case .addLineToPoint:
                if hasStartPoint {
                    let point = element.points[0]
                    let dx = point.x - start.x
                    let dy = point.y - start.y
                    pathLength += sqrt(dx*dx + dy*dy)
                    start = point
                }
            case .closeSubpath:
                break
            default:
                break
            }
        }
        
        return max(pathLength, 10.0) // Ensure we have at least some length
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
    var activeTile: PipeTile?
    let snapThreshold: CGFloat = 100.0 // Adjust based on your needs
    var puzzleWord: String = ""
    var puzzleWordLabel: SKLabelNode?
    var grid: [[PipeTile?]] = [] // Represents the grid where nil indicates an empty square
    var path: [GridPosition] = [] // Path taken by the word through the grid
    var unplacedTiles: Set<PipeTile> = Set()

    
    override func sceneDidLoad() {
        self.backgroundColor = .white
        if let words = loadWordsFromFile(), !words.isEmpty {
            puzzleWord = words.randomElement() ?? "DEFAULT" // Use a default word if none is found
        } else {
            puzzleWord = "FALLBACK" // Fallback word in case the word list couldn't be loaded
        }

        setupGrid()
        addResetButton()
        addNewGameButton()
        addShowWordButton()
        createPuzzleWordLabel()
        initializeGrid()
        addCheckSolutionButton()
        
        // Start a new game to generate the initial puzzle
        startNewGame()
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
            if let tile = node as? PipeTile, let originalPosition = tile.originalPosition {
                tile.position = originalPosition // Reset to the original position
            }
        }

        // Update the logical grid with the original positions of the tiles
        updateLogicalGridFromVisualPositions()
    }
    
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
            if node is PipeTile {
                node.removeFromParent()
            }
        }

        // Generate new tiles
        resetGrid()
        generatePath(for: puzzleWord)
        placeTilesWithPipes(for: puzzleWord)
        placeObstacleTiles(count: 5)
        
        // Hide the puzzle word when starting a new game
        puzzleWordLabel?.isHidden = true
    }
    
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

    // MARK: - Pipe system implementation
    
    // Determine which pipe type should be used based on the word path
    func determinePipeType(for position: GridPosition, in path: [GridPosition]) -> PipeType {
        // Find the index of this position in the path
        guard let index = path.firstIndex(where: { $0.row == position.row && $0.column == position.column }) else {
            return .straight(.up) // Default if not found (shouldn't happen)
        }
        
        // First position (start cap)
        if index == 0 {
            if path.count > 1 {
                let nextPos = path[1]
                // Direction FROM this position TO the next (not the other way around)
                let direction = determineOutgoingDirection(from: position, to: nextPos)
                return .start(direction)
            } else {
                return .start(.right) // Default direction if there's only one position
            }
        }
        
        // Last position (end cap)
        if index == path.count - 1 {
            let prevPos = path[index - 1]
            // Direction FROM previous position TO this one
            let direction = determineOutgoingDirection(from: prevPos, to: position)
            return .end(direction)
        }
        
        // Middle positions
        let prevPos = path[index - 1]
        let nextPos = path[index + 1]
        
        // Direction coming INTO this position (from previous)
        let inDirection = determineOutgoingDirection(from: prevPos, to: position)
        // Direction going OUT of this position (to next)
        let outDirection = determineOutgoingDirection(from: position, to: nextPos)
        
        // If the in and out directions are opposites, it's a straight pipe
        if inDirection.opposite == outDirection {
            if inDirection == .up || inDirection == .down {
                return .straight(.up) // Vertical pipe
            } else {
                return .straight(.right) // Horizontal pipe
            }
        }
        
        // Otherwise it's an elbow - note we pass the direction the flow comes IN from
        // and the direction the flow goes OUT to
        return .elbow(inDirection.opposite, outDirection)
    }
    
    func determineOutgoingDirection(from: GridPosition, to: GridPosition) -> PipeDirection {
        if to.column > from.column { return .right }
        else if to.column < from.column { return .left }
        else if to.row > from.row { return .down } // Remember grid is 0,0 at top-left
        else { return .up }
    }
    
    // Convert text direction to PipeDirection
    func toPipeDirection(_ textDirection: String) -> PipeDirection {
        switch textDirection {
        case "→": return .right
        case "←": return .left
        case "↑": return .up
        case "↓": return .down
        default: return .right // Default
        }
    }
    
    // Convert grid direction to PipeDirection
    func determineDirectionAsPipe(from: GridPosition, to: GridPosition) -> PipeDirection {
        if to.column > from.column { return .right }
        else if to.column < from.column { return .left }
        else if to.row > from.row { return .down }
        else { return .up }
    }
    
    // Replace original direction method to be compatible with the pipe system
    func determineDirection(from: GridPosition, to: GridPosition) -> String {
        if to.column > from.column { return "→" }
        else if to.row > from.row { return "↓" }
        else if to.row < from.row { return "↑" }
        return "←" // Default to left if no other condition is met
    }
    
    // Place tiles with pipes for the word
    func placeTilesWithPipes(for word: String) {
        // Predefine hex colors for start, end, and other tiles
        let startTileColor = UIColor(hex: "#54A37D") ?? .green  // Green
        let endTileColor = UIColor(hex: "#E27378") ?? .red     // Red
        let normalTileColor = UIColor(hex: "#FDE6BD") ?? .white // White
        
        var tilesWithPipes: [PipeTile] = []
        let letters = Array(word)
        
        // Reset unplaced tiles set
        unplacedTiles.removeAll()
        
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

            // Determine the pipe type for this position
            let pipeType = determinePipeType(for: gridPosition, in: path)
            
            // Create the tile with the determined pipe type
            let letter = letters[index]
            let tile = PipeTile(letter: letter, color: tileColor, size: tileSize(), cornerRadius: 4.0, pipeType: pipeType)
            tile.letter = letters[index]

            // Place the first tile directly on the board and mark it as immovable
            if index == 0 {
                let tilePosition = positionForGridCell(row: gridPosition.row, column: gridPosition.column)
                tile.position = tilePosition
                self.addChild(tile)
                tile.originalPosition = tilePosition
                grid[gridPosition.row][gridPosition.column] = tile
                tile.userData = NSMutableDictionary()
                tile.userData?.setValue(true, forKey: "immovable")
            } else {
                tilesWithPipes.append(tile)
                unplacedTiles.insert(tile) // Track unplaced tiles
            }
        }

        // Shuffle and place the remaining tiles in the tray
        tilesWithPipes.shuffle()
        for (index, tile) in tilesWithPipes.enumerated() {
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
    
    // Obstacle placement
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
            // Create obstacle tile without any pipe type and mark as obstacle
            let obstacleTile = PipeTile(letter: nil, color: .brown, size: tileSize(), cornerRadius: 4.0, isObstacle: true)
            obstacleTile.position = positionForGridCell(row: position.row, column: position.column)
            self.addChild(obstacleTile)
            
            // Mark the tile as immovable
            obstacleTile.userData = NSMutableDictionary()
            obstacleTile.userData?.setValue(true, forKey: "immovable")
            
            // Add the obstacle tile to the grid
            grid[position.row][position.column] = obstacleTile
        }
    }
    
    // Solution validation and animation
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
            animateSolutionWithPipes()
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
    
    func moveTile(tile: PipeTile, to position: GridPosition) -> Bool {
        // Check if the target position is already occupied or contains an obstacle
        if let existingTile = grid[position.row][position.column] {
            if existingTile.userData?.value(forKey: "immovable") as? Bool == true {
                // Tile cannot be moved to this cell
                print("Cannot move to an obstacle or immovable tile at \(position).")
                return false
            }
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
    func findTilePosition(tile: PipeTile) -> GridPosition? {
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
        // Reset the grid array
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
            if let tile = node as? PipeTile, let visualPosition = tile.position as CGPoint? {
                if let gridPosition = self.gridPosition(from: visualPosition) {
                    grid[gridPosition.row][gridPosition.column] = tile
                }
            }
        }
    }
    
    // Modified animation solution to use the pipe-based animation
    func animateSolutionWithPipes() {
        var index = 0
        let totalDuration: TimeInterval = 0.6 // Duration for each tile
        
        func animateNextTile() {
            guard index < path.count else { return } // End of path reached
            
            let position = path[index]
            guard let tile = grid[position.row][position.column] as? PipeTile else {
                index += 1
                animateNextTile()
                return
            }
            
            // Animate the liquid flow with the simplified method
            tile.fillWithLiquid(duration: totalDuration) {
                index += 1
                animateNextTile()
            }
        }
        
        // Start a small delay before animation begins
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            animateNextTile() // Start the animation chain
        }
    }
    
    // Debug function to print the current grid layout
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
    
    // Touch event methods
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
                // Handle new game button action
                startNewGame()
                // Optionally hide the puzzle word when starting a new game
                puzzleWordLabel?.isHidden = true
            } else if node.name == "resetButton" {
                // Handle reset button action
                resetTilesToOriginalPositions()
            } else if node.name == "showWordButton" {
                if let label = puzzleWordLabel {
                    label.text = puzzleWord // Update text to the current puzzle word
                    label.isHidden.toggle() // Toggle visibility
                }
            } else if let tile = node as? PipeTile {
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
