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
            // A straight pipe has openings in the direction and its opposite
            return dir == direction || dir.opposite == direction
        case .elbow(let dir1, let dir2):
            // An elbow pipe has openings in exactly the two specified directions
            return dir1 == direction || dir2 == direction
        case .start(let dir):
            // A start pipe has an opening in the specified direction
            return dir == direction
        case .end(let dir):
            // An end pipe has an opening in the specified direction
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
    private var extendedPipeNode: SKShapeNode? // New pipe node for extended state
    private var liquidNode: SKShapeNode?
    private var cropNode: SKCropNode?
    private var letterBackground: SKShapeNode?
    
    // Constants for rendering
    private let pipeLineWidth: CGFloat = 40.0
    private let pipeColor = UIColor(hex: "#595d58") ?? UIColor(red: 0.54, green: 0.56, blue: 0.57, alpha: 1.0)
    private let filledColor = UIColor(hex: "#FDE6BD") ?? .white
    private let liquidColor = UIColor(hex: "#4F97C7") ?? .blue
    
    // For contained vs extended state
    private var isExtended: Bool = false
    private let containedInsetFactor: CGFloat = 0.0 // Higher value = more contained
    private let extendedInsetFactor: CGFloat = -0.15 // Lower value = more extended
    
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
        
        // Create enhanced background with rounded corners - simple but refined
        createEnhancedBackground(color: color, size: size, cornerRadius: cornerRadius)
        
        // Only draw pipes if this isn't an obstacle tile
        if !isObstacle && pipeType != nil {
            // Draw the contained pipe shape initially
            drawPipe(type: pipeType!, size: size, isExtended: false)
            
            // Also create the extended pipe node (initially hidden)
            createExtendedPipe(type: pipeType!, size: size)
            
            // Setup for liquid flow (initially based on contained pipe)
            setupLiquidNode(for: pipeType!, size: size, cornerRadius: cornerRadius)
        }
        
        // Add letter with clean, simple background
        if let letter = letter {
            addCleanLetterDisplay(letter: letter, size: size)
        }
        
        // Set additional properties
        self.zPosition = 0
        self.originalPosition = .zero
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Color Helper Methods

    // Helper to lighten a color
    private func lighten(_ color: UIColor, by percentage: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return UIColor(
            red: min(red + percentage, 1.0),
            green: min(green + percentage, 1.0),
            blue: min(blue + percentage, 1.0),
            alpha: alpha
        )
    }

    // Helper to darken a color
    private func darken(_ color: UIColor, by percentage: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return UIColor(
            red: max(red - percentage, 0.0),
            green: max(green - percentage, 0.0),
            blue: max(blue - percentage, 0.0),
            alpha: alpha
        )
    }

    // Helper to determine if a color is dark
    private func isDarkColor(_ color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        return brightness < 0.6
    }
    
    private func createEnhancedBackground(color: UIColor, size: CGSize, cornerRadius: CGFloat) {
        // Create main background with rounded corners
        let background = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        background.fillColor = color
        background.strokeColor = darken(color, by: 0.15) // Darker outline for definition
        background.lineWidth = 1.5
        background.position = .zero
        background.zPosition = 0
        self.addChild(background)
        
        // Add a subtle top highlight for a very slight 3D effect
        let highlight = SKShapeNode()
        let path = UIBezierPath()
        
        // Create an arc just at the top of the tile
        let topY = size.height / 2 - cornerRadius - 1
        let leftX = -size.width / 2 + cornerRadius + 1
        let rightX = size.width / 2 - cornerRadius - 1
        
        path.move(to: CGPoint(x: leftX, y: topY))
        path.addLine(to: CGPoint(x: rightX, y: topY))
        
        highlight.path = path.cgPath
        highlight.strokeColor = lighten(color, by: 0.2) // Lighter color for highlight
        highlight.lineWidth = 1.5
        highlight.alpha = 0.5 // Very subtle
        highlight.zPosition = 2
        self.addChild(highlight)
    }
    
    private func addCleanLetterDisplay(letter: Character, size: CGSize) {
        // Create a circular background for the letter
        let circleRadius = size.width * 0.3
        
        // Main letter background - clean and simple
        letterBackground = SKShapeNode(circleOfRadius: circleRadius)
        letterBackground!.fillColor = .white
        letterBackground!.strokeColor = UIColor(white: 0.85, alpha: 1.0) // Light gray border
        letterBackground!.lineWidth = 1.0
        letterBackground!.position = .zero
        letterBackground!.zPosition = 7
        self.addChild(letterBackground!)
        
        // Add letter with clean appearance
        letterLabel = SKLabelNode(text: String(letter))
        letterLabel!.fontColor = .black
        letterLabel!.fontSize = size.height / 2.8
        letterLabel!.fontName = "ArialRoundedMTBold"
        letterLabel!.verticalAlignmentMode = .center
        letterLabel!.horizontalAlignmentMode = .center
        letterLabel!.zPosition = 8
        self.addChild(letterLabel!)
    }


    // Add a more visually interesting letter display
    private func addEnhancedLetterDisplay(letter: Character, size: CGSize) {
        // Create a circular background for the letter with enhanced appearance
        let circleRadius = size.width * 0.3
        
        // Inner glow effect (slightly larger circle behind the main one)
        let innerGlow = SKShapeNode(circleOfRadius: circleRadius + 2)
        innerGlow.fillColor = .white
        innerGlow.strokeColor = .white
        innerGlow.alpha = 0.3
        innerGlow.position = .zero
        innerGlow.zPosition = 6
        self.addChild(innerGlow)
        
        // Main letter background
        letterBackground = SKShapeNode(circleOfRadius: circleRadius)
        letterBackground!.fillColor = .white
        
        // Add a gradient effect to the background
        let gradient = SKShapeNode(circleOfRadius: circleRadius * 0.85)
        gradient.fillColor = UIColor(white: 0.95, alpha: 1.0)
        gradient.strokeColor = .clear
        gradient.position = CGPoint(x: -circleRadius * 0.15, y: circleRadius * 0.15) // Offset to create gradient effect
        letterBackground!.addChild(gradient)
        
        letterBackground!.strokeColor = UIColor(white: 0.8, alpha: 1.0)
        letterBackground!.lineWidth = 1.0
        letterBackground!.position = .zero
        letterBackground!.zPosition = 7
        letterBackground!.alpha = 0.95
        self.addChild(letterBackground!)
        
        // Add letter with enhanced appearance
        letterLabel = SKLabelNode(text: String(letter))
        letterLabel!.fontColor = .black
        letterLabel!.fontSize = size.height / 2.8
        letterLabel!.fontName = "ArialRoundedMTBold"
        letterLabel!.verticalAlignmentMode = .center
        letterLabel!.horizontalAlignmentMode = .center
        letterLabel!.zPosition = 8
        
        // Add a subtle shadow to the text
        letterLabel!.position = CGPoint(x: 1, y: -1)
        let shadowLabel = letterLabel!.copy() as! SKLabelNode
        shadowLabel.fontColor = UIColor.black.withAlphaComponent(0.3)
        shadowLabel.position = CGPoint(x: -1, y: 1)
        shadowLabel.zPosition = 7.5
        self.addChild(shadowLabel)
        
        self.addChild(letterLabel!)
    }

    // Helper method to add subtle texture pattern
    private func addSubtlePattern(to node: SKNode, size: CGSize, cornerRadius: CGFloat, baseColor: UIColor, zPosition: CGFloat) {
        // Create a node to hold the pattern
        let patternNode = SKNode()
        patternNode.zPosition = zPosition
        
        // Determine pattern type based on color (for variety)
        let isStartTile = baseColor.isGreen()
        let isEndTile = baseColor.isRed()
        
        if isStartTile {
            // For start tiles, add a subtle radial pattern
            addRadialPattern(to: patternNode, size: size, baseColor: baseColor)
        } else if isEndTile {
            // For end tiles, add concentric circles
            addConcentricPattern(to: patternNode, size: size, baseColor: baseColor)
        } else {
            // For regular tiles, add a dot grid pattern
            addDotPattern(to: patternNode, size: size, baseColor: baseColor)
        }
        
        node.addChild(patternNode)
    }

    // Add a dot pattern for regular tiles
    private func addDotPattern(to node: SKNode, size: CGSize, baseColor: UIColor) {
        let dotSize: CGFloat = 1.5
        let spacing: CGFloat = 12.0
        let rows = Int(size.height / spacing) - 1
        let cols = Int(size.width / spacing) - 1
        
        for row in 0..<rows {
            for col in 0..<cols {
                if (row + col) % 2 == 0 { // Checkerboard pattern
                    let dot = SKShapeNode(circleOfRadius: dotSize / 2)
                    let dotColor = isDarkColor(baseColor) ?
                        lighten(baseColor, by: 0.3) :
                        darken(baseColor, by: 0.3)
                    dot.fillColor = dotColor.withAlphaComponent(0.2)
                    dot.strokeColor = .clear
                    
                    // Position the dot
                    let x = -size.width/2 + CGFloat(col+1) * spacing
                    let y = -size.height/2 + CGFloat(row+1) * spacing
                    dot.position = CGPoint(x: x, y: y)
                    
                    node.addChild(dot)
                }
            }
        }
    }

    // Add a radial pattern for start tiles
    private func addRadialPattern(to node: SKNode, size: CGSize, baseColor: UIColor) {
        let center = CGPoint.zero
        let maxRadius = min(size.width, size.height) / 2
        
        for radius in stride(from: maxRadius * 0.2, to: maxRadius * 0.8, by: maxRadius * 0.15) {
            let circle = SKShapeNode(circleOfRadius: radius)
            circle.position = center
            circle.fillColor = .clear
            circle.strokeColor = lighten(baseColor, by: 0.1).withAlphaComponent(0.15)
            circle.lineWidth = 1.0
            node.addChild(circle)
        }
    }

    // Add concentric pattern for end tiles
    private func addConcentricPattern(to node: SKNode, size: CGSize, baseColor: UIColor) {
        let maxSize = min(size.width, size.height) * 0.8
        
        for i in 0..<3 {
            let squareSize = maxSize * (1.0 - CGFloat(i) * 0.25)
            let square = SKShapeNode(rectOf: CGSize(width: squareSize, height: squareSize), cornerRadius: squareSize * 0.1)
            square.fillColor = .clear
            square.strokeColor = lighten(baseColor, by: 0.1).withAlphaComponent(0.15)
            square.lineWidth = 1.0
            node.addChild(square)
        }
    }
    
    // MARK: - Drawing Methods
    
    private func drawPipe(type: PipeType, size: CGSize, isExtended: Bool) {
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2
            let pipeWidth = size.width * 0.75
            
            // Use different inset factors depending on if we're drawing contained or extended pipes
            let insetFactor = isExtended ? extendedInsetFactor : containedInsetFactor
            
            if isExtended {
                // For extended state, we'll use the extendedPipeNode
                extendedPipeNode?.removeFromParent() // Remove if exists
                extendedPipeNode = SKShapeNode()
                extendedPipeNode?.strokeColor = pipeColor
                extendedPipeNode?.lineWidth = pipeLineWidth
                extendedPipeNode?.lineCap = .butt
                extendedPipeNode?.lineJoin = .round
                extendedPipeNode?.fillColor = .clear
                extendedPipeNode?.zPosition = 5
                extendedPipeNode?.isHidden = true // Hide initially
                
                // Draw extended pipe
                createPipePath(type: type, size: size, insetFactor: insetFactor, node: extendedPipeNode!)
                self.addChild(extendedPipeNode!)
            } else {
                // For contained state, we'll use the regular pipeNode
                pipeNode?.removeFromParent() // Remove if exists
                pipeNode = SKShapeNode()
                pipeNode?.strokeColor = pipeColor
                pipeNode?.lineWidth = pipeLineWidth
                pipeNode?.lineCap = .butt
                pipeNode?.lineJoin = .round
                pipeNode?.fillColor = .clear
                pipeNode?.zPosition = 5
                
                // Draw contained pipe
                createPipePath(type: type, size: size, insetFactor: insetFactor, node: pipeNode!)
                self.addChild(pipeNode!)
            }
        }
        
        // Create the extended pipe (initially hidden)
        private func createExtendedPipe(type: PipeType, size: CGSize) {
            drawPipe(type: type, size: size, isExtended: true)
        }
        
        // Helper method to create the pipe path
        private func createPipePath(type: PipeType, size: CGSize, insetFactor: CGFloat, node: SKShapeNode) {
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2
            let pipeWidth = size.width * 0.75
            
            
            
            let path = UIBezierPath()
            
            switch type {
            case .straight(let direction):
                if direction == .up || direction == .down {
                    // Vertical pipe - draw from bottom to top
                    let bottomY = -halfHeight * (1 - insetFactor)
                    let topY = halfHeight * (1 - insetFactor)
                    path.move(to: CGPoint(x: 0, y: bottomY))
                    path.addLine(to: CGPoint(x: 0, y: topY))
                } else {
                    // Horizontal pipe - draw from left to right
                    let leftX = -halfWidth * (1 - insetFactor)
                    let rightX = halfWidth * (1 - insetFactor)
                    path.move(to: CGPoint(x: leftX, y: 0))
                    path.addLine(to: CGPoint(x: rightX, y: 0))
                }
                
            case .elbow(let dir1, let dir2):
                // Get endpoints for both directions
                let point1 = getElbowEndpoint(for: dir1, size: size, insetFactor: insetFactor)
                let point2 = getElbowEndpoint(for: dir2, size: size, insetFactor: insetFactor)
                
                // Draw from first endpoint through center to second endpoint
                path.move(to: point1)
                path.addLine(to: CGPoint.zero)  // Center point
                path.addLine(to: point2)
                
            case .start(let direction):
                // Start cap - draw from center to edge in the given direction
                let edgePoint = getElbowEndpoint(for: direction, size: size, insetFactor: insetFactor)
                path.move(to: CGPoint.zero)
                path.addLine(to: edgePoint)
                
                // Add a filled circle at the center for the start bubble
                let startNode = SKShapeNode(circleOfRadius: pipeWidth / 2)
                startNode.fillColor = pipeColor
                startNode.strokeColor = pipeColor
                startNode.position = CGPoint.zero
                startNode.zPosition = 4
                if node == pipeNode {
                    self.addChild(startNode)
                } else {
                    // For extended pipe, add a separate bubble
                    let extendedStartNode = startNode.copy() as! SKShapeNode
                    extendedStartNode.isHidden = true // Initially hidden
                    node.userData = NSMutableDictionary()
                    node.userData?.setValue(extendedStartNode, forKey: "startBubble")
                    self.addChild(extendedStartNode)
                }
                
            case .end(let direction):
                // End cap - draw from edge to center in the given direction
                let edgePoint = getElbowEndpoint(for: direction, size: size, insetFactor: insetFactor)
                path.move(to: edgePoint)
                path.addLine(to: CGPoint.zero)
                
                // Add a filled circle at the center for the end bubble
                let endNode = SKShapeNode(circleOfRadius: pipeWidth / 2)
                endNode.fillColor = pipeColor
                endNode.strokeColor = pipeColor
                endNode.position = CGPoint.zero
                endNode.zPosition = 4
                if node == pipeNode {
                    self.addChild(endNode)
                } else {
                    // For extended pipe, add a separate bubble
                    let extendedEndNode = endNode.copy() as! SKShapeNode
                    extendedEndNode.isHidden = true // Initially hidden
                    node.userData = NSMutableDictionary()
                    node.userData?.setValue(extendedEndNode, forKey: "endBubble")
                    self.addChild(extendedEndNode)
                }
            }
            
            // Set the path for the node
            node.path = path.cgPath
        }
        
        private func getElbowEndpoint(for direction: PipeDirection, size: CGSize, insetFactor: CGFloat) -> CGPoint {
            let halfWidth = size.width / 2
            let halfHeight = size.height / 2
            
            // For each direction, return the point on the edge of the tile in that direction
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
    
    // MARK: - Pipe Extension Animation
        
        func animateExtendPipes(duration: TimeInterval = 0.5, completion: @escaping () -> Void) {
            guard !isObstacle, !isExtended, let pipeType = self.pipeType else {
                completion()
                return
            }
            
            // Show the extended pipe node
            extendedPipeNode?.isHidden = false
            extendedPipeNode?.alpha = 0
            
            // Start the fade animation
            let fadeIn = SKAction.fadeIn(withDuration: duration)
            let fadeOut = SKAction.fadeOut(withDuration: duration)
            
            // Also handle bubble nodes for start/end pipes
            if case .start = pipeType, let startBubble = extendedPipeNode?.userData?.value(forKey: "startBubble") as? SKShapeNode {
                startBubble.isHidden = false
                startBubble.alpha = 0
                startBubble.run(fadeIn)
            } else if case .end = pipeType, let endBubble = extendedPipeNode?.userData?.value(forKey: "endBubble") as? SKShapeNode {
                endBubble.isHidden = false
                endBubble.alpha = 0
                endBubble.run(fadeIn)
            }
            
            // Run animations simultaneously
            let group = SKAction.group([
                SKAction.run { self.extendedPipeNode?.run(fadeIn) },
                SKAction.run { self.pipeNode?.run(fadeOut) }
            ])
            
            self.run(group) {
                // Update state
                self.isExtended = true
                
                // Update liquid path to match extended pipe
                self.updateLiquidForExtendedPipe()
                
                completion()
            }
        }
    
    // MARK: - Liquid Animation Setup
    
    private func setupLiquidNode(for pipeType: PipeType, size: CGSize, cornerRadius: CGFloat) {
            // Remove any existing liquid node
            liquidNode?.removeFromParent()
            
            // Create a new liquid node (initially hidden)
            liquidNode = SKShapeNode()
            liquidNode?.fillColor = .clear
            liquidNode?.strokeColor = liquidColor
            liquidNode?.lineWidth = pipeLineWidth * 0.8
            liquidNode?.lineCap = .butt
        liquidNode?.lineJoin = .round
            liquidNode?.alpha = 0.0
            liquidNode?.zPosition = 6 // Above the pipe but below the letter
            liquidNode?.isHidden = true
            
            // Initially match the contained pipe path
            liquidNode?.path = pipeNode?.path
            
            self.addChild(liquidNode!)
        }
        
        // Update liquid to match extended pipe path
        private func updateLiquidForExtendedPipe() {
            liquidNode?.path = extendedPipeNode?.path
        }
        
        // MARK: - Liquid Animation
        
    func fillWithLiquid(duration: TimeInterval = 0.3, completion: @escaping () -> Void) {
        guard !isObstacle, let pipeType = self.pipeType else {
            completion()
            return
        }
        
        // Make sure the letter and its background remain visible during animation
        letterBackground?.zPosition = 15 // Above the liquid
        letterLabel?.zPosition = 16      // Above everything
        
        liquidNode?.isHidden = false
        liquidNode?.removeAllActions()
        
        // Set initial state - transparent
        liquidNode?.alpha = 0.0
        
        // Simple fade-in animation for the liquid
        let fadeIn = SKAction.fadeAlpha(to: 0.9, duration: duration)
        
        // For start/end pipe types, we add a center bubble animation
        if case .start = pipeType {
            // Create a bubble at the center for start pipe
            addBubbleAnimation(duration: duration, pipeType: pipeType)
        } else if case .end = pipeType {
            // Create a bubble at the center for end pipe
            addBubbleAnimation(duration: duration, pipeType: pipeType)
        }
        
        // Run the animation
        liquidNode?.run(fadeIn) {
            completion()
        }
    }
        
        // Helper method to create the bubble animation
    private func addBubbleAnimation(duration: TimeInterval, pipeType: PipeType) {
        // We'll create a liquid bubble that preserves the pipe bubble appearance
        
        // First, create a liquid-filled bubble that's slightly smaller than the pipe bubble
        let innerRadius = pipeLineWidth * 0.6 // Smaller than the pipe bubble
        let liquidBubble = SKShapeNode(circleOfRadius: innerRadius)
        liquidBubble.fillColor = liquidColor
        liquidBubble.strokeColor = .clear // No stroke on the inner bubble
        liquidBubble.position = .zero
        liquidBubble.zPosition = 7
        liquidBubble.alpha = 0
        self.addChild(liquidBubble)
        
        // Create an outer ring to maintain the pipe appearance
        let outerRadius = pipeLineWidth * 0.7 // Same size as the original pipe bubble
        let bubbleOutline = SKShapeNode(circleOfRadius: outerRadius)
        bubbleOutline.fillColor = .clear
        bubbleOutline.strokeColor = pipeColor
        bubbleOutline.lineWidth = 3.0
        bubbleOutline.position = .zero
        bubbleOutline.zPosition = 8
        self.addChild(bubbleOutline)
        
        // Animate the liquid bubble
        let bubbleFadeIn = SKAction.fadeIn(withDuration: duration * 0.2)
        liquidBubble.run(bubbleFadeIn)
    }
        
        // Helper to reset to contained state if needed (e.g., when moving a tile from the grid back to tray)
        func resetToContainedState() {
            if isExtended {
                // Hide extended pipe
                extendedPipeNode?.isHidden = true
                
                // Show contained pipe
                pipeNode?.alpha = 1.0
                pipeNode?.isHidden = false
                
                // Reset liquid path
                liquidNode?.path = pipeNode?.path
                liquidNode?.isHidden = true
                liquidNode?.alpha = 0
                
                // Handle bubbles
                if let pipeType = self.pipeType {
                    if case .start = pipeType, let startBubble = extendedPipeNode?.userData?.value(forKey: "startBubble") as? SKShapeNode {
                        startBubble.isHidden = true
                    } else if case .end = pipeType, let endBubble = extendedPipeNode?.userData?.value(forKey: "endBubble") as? SKShapeNode {
                        endBubble.isHidden = true
                    }
                }
                
                isExtended = false
            }
        }
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
    var puzzleWord: String = "" {
        didSet {
            print("⚠️ puzzleWord CHANGED from '\(oldValue)' to '\(puzzleWord)' (length: \(puzzleWord.count))")
        }
    }
    var puzzleWordLabel: SKLabelNode?
    var grid: [[PipeTile?]] = [] // Represents the grid where nil indicates an empty square
    var path: [GridPosition] = [] // Path taken by the word through the grid
    var unplacedTiles: Set<PipeTile> = Set()
    var connectionIndex: Int = 0
    weak var gameDelegate: GameSceneDelegate?
    
    private var backButton: SKLabelNode?

    
    override func sceneDidLoad() {
        self.backgroundColor = .white
       /* if let words = loadWordsFromFile(), !words.isEmpty {
            puzzleWord = words.randomElement() ?? "DEFAULT" // Use a default word if none is found
        } else {
            puzzleWord = "FALLBACK" // Fallback word in case the word list couldn't be loaded
        } */

        setupGrid()
        addNewGameButton()
        // addShowWordButton()
        createPuzzleWordLabel()
        initializeGrid()
        
    }
    
    override func didMove(to view: SKView) {
        // Call your existing setup methods
        print("GameScene didMove with puzzleWord: \(puzzleWord) (length: \(puzzleWord.count))")
        
        // Add back button
        setupBackButton()
        
        // Only start a new game if we have a valid puzzle word
        if !puzzleWord.isEmpty {
            print("Starting new game with word: \(puzzleWord)")
            startNewGame()
        } else {
            print("ERROR: Empty puzzle word in didMove")
        }
    }
    
    func setupBackButton() {
        backButton = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        backButton?.text = "← Back to Map"
        backButton?.fontSize = 24
        backButton?.fontColor = SKColor.red
        
        // Position the button on the left, aligned with reset button and at the same level as "New Game"
        backButton?.position = CGPoint(x: 100, y: self.frame.maxY - 80)
        backButton?.name = "backButton"
        self.addChild(backButton!)
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
                // Create an enhanced tile with texture and subtle effects
                let tile = createEnhancedGridTile(size: size, cornerRadius: 4.0)
                
                // Calculate position with padding included
                let x = size.width * CGFloat(column) + size.width / 2 + 10 * CGFloat(column) + gridPadding
                let y = self.size.height - (size.height * CGFloat(row) + size.height / 2 + 10 * CGFloat(row) + gridPadding + topPadding)
                tile.position = CGPoint(x: x, y: y)
                
                // Add tile to scene
                self.addChild(tile)
            }
        }
    }
    
    func createEnhancedGridTile(size: CGSize, cornerRadius: CGFloat) -> SKNode {
        // Create the container node
        let container = SKNode()
        
        // Create the main background with rounded corners
        let background = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        background.fillColor = UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0) // Light gray with slight blue tint
        background.strokeColor = UIColor(red: 0.7, green: 0.7, blue: 0.72, alpha: 1.0) // Slightly darker for edge definition
        background.lineWidth = 1.5
        
        // Add a subtle pattern texture
        let pattern = createSubtleGridPattern(size: size, cornerRadius: cornerRadius)
        pattern.alpha = 0.15 // Very subtle
        
        // Add a slight inner shadow effect
        let innerShadow = createInnerShadow(size: size, cornerRadius: cornerRadius)
        innerShadow.alpha = 0.2 // Subtle
        
        // Add a highlight at the top
        let highlight = createTopHighlight(size: size, cornerRadius: cornerRadius)
        highlight.alpha = 0.35 // Subtle glow
        
        // Add all elements to the container
        container.addChild(background)
        container.addChild(pattern)
        container.addChild(innerShadow)
        container.addChild(highlight)
        
        return container
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
    
    func calculateGridBottomY() -> CGFloat {
        let tileSize = self.tileSize()
        let lastRowY = self.size.height - (tileSize.height * CGFloat(numGridRows - 1) + tileSize.height / 2 + 10 * CGFloat(numGridRows - 1) + gridPadding + topPadding)
        // Return a position slightly below the last row (subtract tile height + some padding)
        return lastRowY - (tileSize.height / 2) - 20
    }
    /*
    func addShowWordButton() {
        let showWordButton = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        showWordButton.text = "Show Word"
        showWordButton.fontSize = 24
        showWordButton.fontColor = SKColor.purple  // Changed color for better visibility
        showWordButton.position = CGPoint(x: self.frame.midX, y: self.frame.minY + 325)
        showWordButton.name = "showWordButton"
        self.addChild(showWordButton)
    }
    */
    func createPuzzleWordLabel() {
        let label = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        label.text = puzzleWord
        label.fontSize = 36
        label.fontColor = SKColor.orange
        
        // Position below the grid - calculate the bottom of the grid area
        let gridBottom = calculateGridBottomY() - 20 // Add some padding
        label.position = CGPoint(x: self.frame.midX, y: gridBottom)
        label.isHidden = true
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
    
    func processDroppedTile(_ tile: PipeTile, at location: CGPoint) {
            if let newPosition = gridPosition(from: location), moveTile(tile: tile, to: newPosition) {
                // If moving to grid, ensure pipe is in contained state
                tile.resetToContainedState()
                
                // Update logical grid
                updateLogicalGridFromVisualPositions()
                
                // Check if all tiles have been placed (moved from earlier)
                if unplacedTiles.isEmpty {
                    // Let's automatically check the solution now
                    if checkSolution() {
                        print("Correct solution!")
                        // Animation happens in checkSolution
                    } else {
                        print("Incorrect solution, please try again.")
                    }
                }
            } else if let originalPosition = tile.originalPosition {
                // If moving failed, reset to original position
                tile.position = originalPosition
            }

            tile.zPosition = 0
        }


    func startNewGame() {
        /*
        if let words = loadWordsFromFile(), !words.isEmpty {
            puzzleWord = words.randomElement() ?? "DEFAULT"
        } else {
            puzzleWord = "FALLBACK"
        } */
        
        print("startNewGame called with puzzleWord: \(puzzleWord) (length: \(puzzleWord.count))")
            
            // Ensure we have a valid word
            if puzzleWord.isEmpty {
                print("ERROR: Empty puzzle word in startNewGame")
                return
            }

        // Clear existing tiles
        self.children.forEach { node in
            if node is PipeTile {
                node.removeFromParent()
            }
        }

        // Generate new tiles
            resetGrid()
            resetAllPipesToContainedState()
            
            print("Generating path for word: \(puzzleWord) (length: \(puzzleWord.count))")
            generatePath(for: puzzleWord)
            
            placeTilesWithPipes(for: puzzleWord)
            placeObstacleTiles(count: 5)
            
            // Hide the puzzle word when starting a new game
            puzzleWordLabel?.isHidden = true
    }
    
    // Word Path generation
    func generatePath(for word: String) {
        var attempts = 0
        let maxAttempts = 30 // Increased maximum attempts
        
        print("Generating path for word: \(word) with \(word.count) letters")

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
                print("Successfully generated path with \(path.count) positions")
                break // Exit the while loop if a successful path is generated
            }

            attempts += 1
        }
        
        // Ensure we have a valid path even if random generation failed
        if path.count != word.count {
            print("Failed to generate valid path after \(attempts) attempts. Creating fallback path.")
            path.removeAll()
            
            // Create a simple path - just go straight across from left to right
            let startRow = numGridRows / 2 // Middle row
            
            // Make sure we don't exceed grid dimensions
            let pathLength = min(word.count, numGridColumns)
            
            for col in 0..<pathLength {
                path.append(GridPosition(row: startRow, column: col))
            }
        }
        
        // Final check
        print("Final path has \(path.count) positions for word with \(word.count) letters")
    }

    // MARK: - Pipe system implementation
    
    func determinePipeType(for position: GridPosition, in path: [GridPosition]) -> PipeType {
        // Find this position's index in the path
        guard let index = path.firstIndex(where: { $0.row == position.row && $0.column == position.column }) else {
            return .straight(.up) // Default
        }
        
        // First position (start cap)
        if index == 0 {
            // Get the next position
            let nextPos = path[1]
            
            // Flow moves FROM start TO next position
            // So we want the pipe opening facing the direction of the next position
            if nextPos.column > position.column {
                return .start(.right)
            } else if nextPos.column < position.column {
                return .start(.left)
            } else if nextPos.row > position.row {
                return .start(.down)
            } else {
                return .start(.up)
            }
        }
        
        // Last position (end cap)
        if index == path.count - 1 {
            // Get the previous position
            let prevPos = path[index - 1]
            
            // Flow moves FROM previous TO end
            // So we want the pipe opening facing the direction FROM which the flow comes
            if prevPos.column > position.column {
                return .end(.right)  // Flow comes from right
            } else if prevPos.column < position.column {
                return .end(.left)   // Flow comes from left
            } else if prevPos.row > position.row {
                return .end(.down)   // Flow comes from below
            } else {
                return .end(.up)     // Flow comes from above
            }
        }
        
        // Middle positions
        let prevPos = path[index - 1]
        let nextPos = path[index + 1]
        
        // Determine incoming direction (where flow comes FROM)
        let inDir: PipeDirection
        if prevPos.column > position.column {
            inDir = .right      // Coming from right
        } else if prevPos.column < position.column {
            inDir = .left       // Coming from left
        } else if prevPos.row > position.row {
            inDir = .down       // Coming from below
        } else {
            inDir = .up         // Coming from above
        }
        
        // Determine outgoing direction (where flow goes TO)
        let outDir: PipeDirection
        if nextPos.column > position.column {
            outDir = .right     // Going to right
        } else if nextPos.column < position.column {
            outDir = .left      // Going to left
        } else if nextPos.row > position.row {
            outDir = .down      // Going down
        } else {
            outDir = .up        // Going up
        }
        
        // If incoming and outgoing are opposite, it's a straight pipe
        if (inDir == .up && outDir == .down) || (inDir == .down && outDir == .up) {
            return .straight(.up)    // Vertical straight pipe
        } else if (inDir == .left && outDir == .right) || (inDir == .right && outDir == .left) {
            return .straight(.right) // Horizontal straight pipe
        }
        
        // Otherwise it's an elbow - specify both openings
        return .elbow(inDir, outDir)
    }

    // Simplify and clarify the direction determination
    func determineDirection(from: GridPosition, to: GridPosition) -> PipeDirection {
        if to.column > from.column { return .right }
        else if to.column < from.column { return .left }
        else if to.row > from.row { return .down } // Grid is 0,0 at top-left
        else { return .up }
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
    
    // Place tiles with pipes for the word
    func placeTilesWithPipes(for word: String) {
        // Predefine hex colors for start, end, and other tiles
        let startTileColor = UIColor(hex: "#54A37D") ?? .green  // Green
        let endTileColor = UIColor(hex: "#E27378") ?? .red     // Red
        let normalTileColor = UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
        
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

        // Place enhanced obstacle tiles
        for position in obstaclePositions {
            // Create enhanced obstacle tile
            let obstacleTile = createEnhancedObstacleTile(size: tileSize(), cornerRadius: 4.0)
            obstacleTile.position = positionForGridCell(row: position.row, column: position.column)
            self.addChild(obstacleTile)
            
            // Mark the tile as immovable
            obstacleTile.userData = NSMutableDictionary()
            obstacleTile.userData?.setValue(true, forKey: "immovable")
            
            // Add the obstacle tile to the grid
            grid[position.row][position.column] = obstacleTile
        }
    }
    
    func createEnhancedObstacleTile(size: CGSize, cornerRadius: CGFloat) -> PipeTile {
        // Create the base obstacle tile
        let tile = PipeTile(letter: nil, color: .clear, size: size, cornerRadius: cornerRadius, isObstacle: true)
        
        // Add a metal/concrete-like background
        let background = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        background.fillColor = UIColor(red: 0.4, green: 0.35, blue: 0.3, alpha: 1.0) // Brown-gray concrete color
        background.strokeColor = UIColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        background.lineWidth = 1.5
        background.zPosition = 0
        tile.addChild(background)
        
        // Add a concrete/metal texture with rivets
        let texture = createObstacleTexture(size: size, cornerRadius: cornerRadius)
        texture.zPosition = 1
        tile.addChild(texture)
        
        return tile
    }
    
    func createSubtleGridPattern(size: CGSize, cornerRadius: CGFloat) -> SKShapeNode {
        let pattern = SKShapeNode(rectOf: size, cornerRadius: cornerRadius)
        pattern.fillColor = .clear
        pattern.strokeColor = .clear
        
        // Create a grid of small dots
        let dotSize: CGFloat = 2.0
        let spacing: CGFloat = 10.0
        let rows = Int(size.height / spacing)
        let cols = Int(size.width / spacing)
        
        for row in 0..<rows {
            for col in 0..<cols {
                if (row + col) % 2 == 0 { // Checkerboard pattern
                    let dot = SKShapeNode(circleOfRadius: dotSize / 2)
                    dot.fillColor = UIColor.black.withAlphaComponent(0.1)
                    dot.strokeColor = .clear
                    
                    // Position the dot
                    let x = -size.width/2 + CGFloat(col) * spacing + spacing/2
                    let y = -size.height/2 + CGFloat(row) * spacing + spacing/2
                    dot.position = CGPoint(x: x, y: y)
                    
                    pattern.addChild(dot)
                }
            }
        }
        
        return pattern
    }

    // Create an inner shadow effect for depth
    func createInnerShadow(size: CGSize, cornerRadius: CGFloat) -> SKShapeNode {
        let shadow = SKShapeNode(rectOf: CGSize(width: size.width - 4, height: size.height - 4), cornerRadius: cornerRadius - 1)
        shadow.fillColor = .clear
        shadow.strokeColor = UIColor.black.withAlphaComponent(0.3)
        shadow.lineWidth = 4.0
        shadow.position = CGPoint(x: 1, y: -1) // Offset slightly to create shadow effect
        return shadow
    }

    // Create a highlight at the top of the tile for a 3D effect
    func createTopHighlight(size: CGSize, cornerRadius: CGFloat) -> SKShapeNode {
        let highlight = SKShapeNode()
        let path = UIBezierPath()
        
        // Create an arc just at the top of the tile
        let topY = size.height / 2 - cornerRadius
        let leftX = -size.width / 2 + cornerRadius
        let rightX = size.width / 2 - cornerRadius
        
        path.move(to: CGPoint(x: leftX, y: topY))
        path.addLine(to: CGPoint(x: rightX, y: topY))
        
        highlight.path = path.cgPath
        highlight.strokeColor = UIColor.white
        highlight.lineWidth = 2.0
        
        return highlight
    }

    // Create a concrete/metal texture for obstacle tiles
    func createObstacleTexture(size: CGSize, cornerRadius: CGFloat) -> SKNode {
        let textureNode = SKNode()
        
        // Create an overlay with scratch marks
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width - 8, height: size.height - 8), cornerRadius: cornerRadius - 1)
        overlay.fillColor = .clear
        overlay.strokeColor = .clear
        
        // Add some random scratch lines
        for _ in 0..<5 {
            let scratch = SKShapeNode()
            let path = UIBezierPath()
            
            // Random starting and ending points
            let startX = CGFloat.random(in: -size.width/2+10...size.width/2-10)
            let startY = CGFloat.random(in: -size.height/2+10...size.height/2-10)
            let endX = CGFloat.random(in: -size.width/2+10...size.width/2-10)
            let endY = CGFloat.random(in: -size.height/2+10...size.height/2-10)
            
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))
            
            scratch.path = path.cgPath
            scratch.strokeColor = UIColor.black.withAlphaComponent(0.2)
            scratch.lineWidth = CGFloat.random(in: 1.0...2.0)
            
            overlay.addChild(scratch)
        }
        
        // Add rivets in the corners for industrial look
        addRivets(to: textureNode, size: size, cornerRadius: cornerRadius)
        
        textureNode.addChild(overlay)
        return textureNode
    }

    // Add rivets to the obstacle texture
    func addRivets(to node: SKNode, size: CGSize, cornerRadius: CGFloat) {
        let rivetPositions = [
            CGPoint(x: -size.width/2 + cornerRadius, y: size.height/2 - cornerRadius),
            CGPoint(x: size.width/2 - cornerRadius, y: size.height/2 - cornerRadius),
            CGPoint(x: -size.width/2 + cornerRadius, y: -size.height/2 + cornerRadius),
            CGPoint(x: size.width/2 - cornerRadius, y: -size.height/2 + cornerRadius)
        ]
        
        for position in rivetPositions {
            let rivet = SKShapeNode(circleOfRadius: 3.0)
            rivet.fillColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
            rivet.strokeColor = UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
            rivet.lineWidth = 1.0
            rivet.position = position
            
            // Add a highlight to the rivet for 3D effect
            let highlight = SKShapeNode(circleOfRadius: 1.0)
            highlight.fillColor = UIColor.white.withAlphaComponent(0.5)
            highlight.strokeColor = .clear
            highlight.position = CGPoint(x: -0.5, y: 0.5)
            rivet.addChild(highlight)
            
            node.addChild(rivet)
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
            // Use the new two-step animation:
            // 1. First extend pipes
            // 2. Then animate liquid flow
            animateSolutionWithPipes()
            print("Solution is correct!")
            notifyPuzzleCompleted()
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
    
    func addReturnToMapButton(withSuccess success: Bool) {
        // Create a back button with attractive styling
        let buttonWidth: CGFloat = 200
        let buttonHeight: CGFloat = 50
        
        let backButtonNode = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
        backButtonNode.fillColor = success ? UIColor(hex: "#54A37D") ?? .green : UIColor(hex: "#4F97C7") ?? .blue
        backButtonNode.strokeColor = .white
        backButtonNode.lineWidth = 2
        
        // Move button higher to avoid overlap with word label
        backButtonNode.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2 - 180)
        backButtonNode.name = "returnToMapButton"
        backButtonNode.zPosition = 100 // Above everything else
        
        // Add text to the button
        let buttonText = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        buttonText.text = success ? "Continue Adventure" : "Return to Map"
        buttonText.fontSize = 18
        buttonText.fontColor = .white
        buttonText.verticalAlignmentMode = .center
        buttonText.horizontalAlignmentMode = .center
        buttonText.position = CGPoint.zero
        backButtonNode.addChild(buttonText)
        
        // Add a glow effect for emphasis
        let glowAction = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.7, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        backButtonNode.run(SKAction.repeatForever(glowAction))
        
        // Add the button to the scene
        self.addChild(backButtonNode)
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
            // 1. First extend all pipes to connect
            animateExtendPipes() {
                // 2. Then animate the liquid flow
                self.animateLiquidFlow()
            }
        }
        
    func animateExtendPipes(completion: @escaping () -> Void) {
        var pipeExtensionCount = 0
        let totalPipeCount = path.count
        
        // Extend each pipe in the path
        for position in path {
            guard let tile = grid[position.row][position.column] as? PipeTile else { continue }
            
            // Use the longer duration
            tile.animateExtendPipes(duration: 0.5) {
                pipeExtensionCount += 1
                
                // When all pipes are extended, proceed to liquid flow after a longer delay
                if pipeExtensionCount >= totalPipeCount {
                    // Add a longer pause before starting the liquid flow
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { // Increased from 0.5 to 1.2
                        completion()
                    }
                }
            }
        }
    }
        
        func animateLiquidFlow() {
            var index = 0
            let totalDuration: TimeInterval = 0.3
            
            func animateNextTile() {
                guard index < path.count else { return } // End of path reached
                
                let position = path[index]
                guard let tile = grid[position.row][position.column] as? PipeTile else {
                    index += 1
                    animateNextTile()
                    return
                }
                
                // Animate the liquid flow with the shortened duration
                tile.fillWithLiquid(duration: totalDuration) {
                    index += 1
                    animateNextTile()
                }
            }
            
            // Start liquid animation
            animateNextTile()
        }
        
        // Add a reset method to reset pipes to contained state when appropriate
        func resetAllPipesToContainedState() {
            self.children.forEach { node in
                if let tile = node as? PipeTile {
                    tile.resetToContainedState()
                }
            }
        }
    
    func notifyPuzzleCompleted() {
        // First, make the word visible
        puzzleWordLabel?.text = puzzleWord
        puzzleWordLabel?.fontColor = UIColor(hex: "#54A37D") ?? .green // Green to indicate success
        puzzleWordLabel?.isHidden = false
        
        // Add a longer delay to allow for completion animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            // Add the return to map button - position BELOW the word
            self.addReturnToMapButton(withSuccess: true)
            
            // Add completion message at the TOP of the screen
            let successMessage = SKLabelNode(fontNamed: "ArialRoundedMTBold")
            successMessage.text = "Puzzle Complete!"
            successMessage.fontSize = 30
            successMessage.fontColor = UIColor(hex: "#54A37D") ?? .green
            
            // Position the message at the top, below any navigation buttons
            successMessage.position = CGPoint(x: self.size.width / 2, y: self.size.height - 550)
            successMessage.zPosition = 100
            successMessage.alpha = 0
            
            self.addChild(successMessage)
            
            // Fade in with a scale effect
            let fadeIn = SKAction.fadeIn(withDuration: 0.5)
            let scaleUp = SKAction.scale(to: 1.2, duration: 0.5)
            let scaleDown = SKAction.scale(to: 1.0, duration: 0.3)
            let group = SKAction.group([fadeIn, SKAction.sequence([scaleUp, scaleDown])])
            
            successMessage.run(group)
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
            // Check for the return to map button
                    if node.name == "returnToMapButton" {
                        self.gameDelegate?.gameScene(self, didCompletePuzzleWithWord: self.puzzleWord, connectionIndex: self.connectionIndex)
                        return
                    }
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
          /*  } else if node.name == "showWordButton" {
                if let label = puzzleWordLabel {
                    label.text = puzzleWord // Update text to the current puzzle word
                    label.isHidden.toggle() // Toggle visibility
                } */
            } else if let tile = node as? PipeTile {
                // Check if the tile is immovable before setting it as active
                if tile.userData?["immovable"] as? Bool ?? false {
                    print("This tile is immovable.")
                } else {
                    // Set the tile as active and ready to be moved
                    activeTile = tile
                    tile.zPosition = 1 // Bring the tile to the front
                }
            } else if node.name == "backButton" {
                // Return to map
                gameDelegate?.gameScene(self, didCancelPuzzle: true)
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

        // Use our new helper method to process the dropped tile
        processDroppedTile(tile, at: location)
        
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

// MARK: - UIColor Extensions

extension UIColor {
    func isGreen() -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return green > 0.5 && green > red * 1.5 && green > blue * 1.5
    }
    
    func isRed() -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        self.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return red > 0.5 && red > green * 1.5 && red > blue * 1.5
    }
}
