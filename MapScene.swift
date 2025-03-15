//
//  MapScene.swift
//  TextTubes
//
//  Created by Braxton Smallwood on 3/14/25.
//

import SpriteKit
import GameplayKit

class MapScene: SKScene {
    
    // MARK: - Properties
    
    // Map nodes
    private var mapBackground: SKSpriteNode!
    private var startLocation: SKShapeNode!
    private var endLocation: SKShapeNode!
    private var intermediateLocations: [SKShapeNode] = []
    
    // Connection paths
    private var connectionPaths: [Int: SKNode] = [:]
    private var locationLabels: [Int: SKLabelNode] = [:]
    
    // Selection UI
    private var selectionPanel: SKShapeNode!
    private var availableConnectionButtons: [SKNode] = []
    
    // Data
    private let locationCount = 5 // Start, 3 intermediate, End
    private var discoveredWords: [Int: String] = [:]
    private var completedConnections: Set<Int> = []
    
    // Delegate
    weak var gameDelegate: MapSceneDelegate?
    
    // Connection definitions - index, start location index, end location index, word to solve
    private let connections: [(index: Int, from: Int, to: Int, word: String)] = [
        (1, 0, 1, "RIVER"),   // Start to Location 1
        (2, 0, 2, "VALLEY"),  // Start to Location 2
        (3, 1, 3, "TOWER"),   // Location 1 to Location 3
        (4, 2, 3, "BRIDGE"),  // Location 2 to Location 3
        (5, 3, 4, "CASTLE")   // Location 3 to End
    ]
    
    // MARK: - Scene Lifecycle
    
    override func didMove(to view: SKView) {
        super.didMove(to: view)
        
        backgroundColor = .white
        setupMapBackground()
        setupLocations()
        setupConnectionPaths()
        setupSelectionPanel()
        updateAvailableConnections()
        loadCompletedConnections()
    }
    
    // MARK: - Setup Methods
    
    private func setupMapBackground() {
        // Create a subtle background for the map
        let background = SKShapeNode(rectOf: CGSize(width: self.size.width - 40, height: self.size.height - 120))
        background.fillColor = UIColor(red: 0.88, green: 0.90, blue: 0.98, alpha: 1.0)
        background.strokeColor = UIColor(red: 0.53, green: 0.60, blue: 0.80, alpha: 1.0)
        background.lineWidth = 2
        background.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2 + 30)
        background.zPosition = -1
        addChild(background)
        
        // Add title
        let titleLabel = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        titleLabel.text = "TextTubes Adventure Map"
        titleLabel.fontSize = 24
        titleLabel.fontColor = .darkGray
        titleLabel.position = CGPoint(x: self.size.width / 2, y: self.size.height - 40)
        addChild(titleLabel)
    }
    
    private func setupLocations() {
        // Create location nodes
        
        // Start location (green)
        startLocation = createLocationNode(
            position: CGPoint(x: self.size.width * 0.25, y: self.size.height * 0.5),
            color: UIColor(hex: "#54A37D") ?? .green,
            label: "Start",
            index: 0
        )
        
        // Intermediate locations
        let location1 = createLocationNode(
            position: CGPoint(x: self.size.width * 0.4, y: self.size.height * 0.65),
            color: UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0),
            label: "?",
            index: 1
        )
        
        let location2 = createLocationNode(
            position: CGPoint(x: self.size.width * 0.4, y: self.size.height * 0.35),
            color: UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0),
            label: "?",
            index: 2
        )
        
        let location3 = createLocationNode(
            position: CGPoint(x: self.size.width * 0.6, y: self.size.height * 0.5),
            color: UIColor(red: 0.88, green: 0.88, blue: 0.88, alpha: 1.0),
            label: "?",
            index: 3
        )
        
        intermediateLocations = [location1, location2, location3]
        
        // End location (red)
        endLocation = createLocationNode(
            position: CGPoint(x: self.size.width * 0.75, y: self.size.height * 0.65),
            color: UIColor(hex: "#E27378") ?? .red,
            label: "End",
            index: 4
        )
    }
    
    private func createLocationNode(position: CGPoint, color: UIColor, label: String, index: Int) -> SKShapeNode {
        // Create circle node
        let location = SKShapeNode(circleOfRadius: 25)
        location.fillColor = color
        location.strokeColor = .darkGray
        location.lineWidth = 2
        location.position = position
        location.name = "location_\(index)"
        addChild(location)
        
        // Add label
        let locationLabel = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        locationLabel.text = label
        locationLabel.fontSize = 16
        locationLabel.fontColor = isDarkColor(color) ? .white : .black
        locationLabel.verticalAlignmentMode = .center
        locationLabel.horizontalAlignmentMode = .center
        locationLabel.position = CGPoint.zero
        location.addChild(locationLabel)
        
        // Store reference to the label
        locationLabels[index] = locationLabel
        
        return location
    }
    
    private func setupConnectionPaths() {
        // Create all the connection paths (initially as dotted lines)
        for connection in connections {
            let fromLocation = getLocationNode(connection.from)
            let toLocation = getLocationNode(connection.to)
            
            // Create dotted line from fromLocation to toLocation
            let startPoint = CGPoint.zero
            let endPoint = CGPoint(
                x: toLocation.position.x - fromLocation.position.x,
                y: toLocation.position.y - fromLocation.position.y
            )
            
            let dottedLine = createDottedLine(
                from: startPoint,
                to: endPoint,
                color: .gray,
                lineWidth: 3
            )
            
            // Create a solid line node (initially hidden) for when connection is completed
            let solidLine = SKShapeNode()
            let linePath = CGMutablePath()
            linePath.move(to: startPoint)
            linePath.addLine(to: endPoint)
            solidLine.path = linePath
            solidLine.strokeColor = UIColor(hex: "#4F97C7") ?? .blue
            solidLine.lineWidth = 5
            solidLine.alpha = 0 // Hidden initially
            
            // Create a container to hold both the dotted and solid lines
            let pathContainer = SKNode()
            pathContainer.addChild(dottedLine)
            pathContainer.addChild(solidLine)
            pathContainer.position = fromLocation.position
            pathContainer.zPosition = -0.5
            pathContainer.name = "connection_\(connection.index)"
            
            // Store additional data for later use
            pathContainer.userData = NSMutableDictionary()
            pathContainer.userData?.setValue(dottedLine, forKey: "dottedLine")
            pathContainer.userData?.setValue(solidLine, forKey: "solidLine")
            
            addChild(pathContainer)
            connectionPaths[connection.index] = pathContainer // Changed type of connectionPaths
        }
    }
    
    private func createDottedLine(from startPoint: CGPoint, to endPoint: CGPoint, color: UIColor, lineWidth: CGFloat) -> SKNode {
        // Calculate the vector between the points
        let dx = endPoint.x - startPoint.x
        let dy = endPoint.y - startPoint.y
        
        // Calculate the distance
        let distance = sqrt(dx*dx + dy*dy)
        
        // Calculate unit vector for direction
        let unitDx = dx / distance
        let unitDy = dy / distance
        
        // Create a container node
        let lineNode = SKNode()
        lineNode.position = startPoint
        
        // Parameters for dotted line
        let dotLength: CGFloat = 5.0
        let gapLength: CGFloat = 5.0
        let segmentLength = dotLength + gapLength
        let numSegments = Int(distance / segmentLength)
        
        // Create individual dots
        for i in 0..<numSegments {
            let dot = SKShapeNode(rectOf: CGSize(width: dotLength, height: lineWidth))
            dot.fillColor = color
            dot.strokeColor = color
            
            // Position the dot at the appropriate segment
            let segmentDistance = CGFloat(i) * segmentLength
            dot.position = CGPoint(
                x: unitDx * (segmentDistance + dotLength/2),
                y: unitDy * (segmentDistance + dotLength/2)
            )
            
            // Rotate the dot to align with the line direction
            let angle = atan2(dy, dx)
            dot.zRotation = angle
            
            lineNode.addChild(dot)
        }
        
        // Add final dot if needed
        let remainingDistance = distance - CGFloat(numSegments) * segmentLength
        if remainingDistance > 0 {
            let finalDotLength = min(remainingDistance, dotLength)
            let finalDot = SKShapeNode(rectOf: CGSize(width: finalDotLength, height: lineWidth))
            finalDot.fillColor = color
            finalDot.strokeColor = color
            
            // Position the final dot
            let finalSegmentDistance = CGFloat(numSegments) * segmentLength
            finalDot.position = CGPoint(
                x: unitDx * (finalSegmentDistance + finalDotLength/2),
                y: unitDy * (finalSegmentDistance + finalDotLength/2)
            )
            
            // Rotate the final dot
            let angle = atan2(dy, dx)
            finalDot.zRotation = angle
            
            lineNode.addChild(finalDot)
        }
        
        return lineNode
    }
    
    private func setupSelectionPanel() {
        // Create panel at bottom of screen for connection selection
        selectionPanel = SKShapeNode(rectOf: CGSize(width: self.size.width - 40, height: 100))
        selectionPanel.fillColor = .white
        selectionPanel.strokeColor = UIColor.lightGray
        selectionPanel.lineWidth = 1
        selectionPanel.position = CGPoint(x: self.size.width / 2, y: 70)
        addChild(selectionPanel)
        
        // Add title
        let panelTitle = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        panelTitle.text = "Available Connections"
        panelTitle.fontSize = 18
        panelTitle.fontColor = .darkGray
        panelTitle.position = CGPoint(x: 0, y: 30)
        selectionPanel.addChild(panelTitle)
    }
    
    private func updateAvailableConnections() {
        // Clear existing buttons
        for button in availableConnectionButtons {
            button.removeFromParent()
        }
        availableConnectionButtons.removeAll()
        
        // Get available connections
        let available = getAvailableConnections()
        
        if available.isEmpty {
            // No connections available - show completion message
            let messageLabel = SKLabelNode(fontNamed: "ArialRoundedMTBold")
            messageLabel.text = "All connections completed!"
            messageLabel.fontSize = 16
            messageLabel.fontColor = .darkGray
            messageLabel.position = CGPoint(x: 0, y: 0)
            selectionPanel.addChild(messageLabel)
            availableConnectionButtons.append(messageLabel)
            return
        }
        
        // Create buttons for each available connection
        let buttonWidth: CGFloat = 180
        let spacing: CGFloat = 20
        let totalWidth = CGFloat(available.count) * buttonWidth + CGFloat(available.count - 1) * spacing
        let startX = -totalWidth / 2 + buttonWidth / 2
        
        for (i, connectionIndex) in available.enumerated() {
            let connection = connections.first { $0.index == connectionIndex }!
            let fromLocation = getLocationNodeLabel(connection.from)
            let toLocation = getLocationNodeLabel(connection.to)
            
            // Create button
            let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: 40), cornerRadius: 5)
            button.fillColor = UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1.0)
            button.strokeColor = UIColor(red: 0.31, green: 0.59, blue: 0.78, alpha: 1.0)
            button.lineWidth = 2
            button.position = CGPoint(x: startX + CGFloat(i) * (buttonWidth + spacing), y: 0)
            button.name = "button_\(connectionIndex)"
            selectionPanel.addChild(button)
            
            // Add button label
            let buttonLabel = SKLabelNode(fontNamed: "ArialRoundedMTBold")
            buttonLabel.text = "\(fromLocation) → \(toLocation) (\(connection.word.count) letters)"
            buttonLabel.fontSize = 14
            buttonLabel.fontColor = .darkGray
            buttonLabel.verticalAlignmentMode = .center
            buttonLabel.horizontalAlignmentMode = .center
            buttonLabel.position = CGPoint.zero
            button.addChild(buttonLabel)
            
            availableConnectionButtons.append(button)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getLocationNode(_ index: Int) -> SKNode {
        switch index {
        case 0: return startLocation
        case 4: return endLocation
        default: return intermediateLocations[index - 1]
        }
    }
    
    private func getLocationNodeLabel(_ index: Int) -> String {
        if index == 0 {
            return "Start"
        } else if index == 4 {
            return "End"
        } else if let word = discoveredWords[index] {
            return word
        } else {
            return "?"
        }
    }
    
    private func getAvailableConnections() -> [Int] {
        var available: [Int] = []
        
        // Start with connections from Start node
        if !completedConnections.contains(1) {
            available.append(1)
        }
        
        if !completedConnections.contains(2) {
            available.append(2)
        }
        
        // Add other connections if prerequisites are met
        if completedConnections.contains(1) && !completedConnections.contains(3) {
            available.append(3)
        }
        
        if completedConnections.contains(2) && !completedConnections.contains(4) {
            available.append(4)
        }
        
        // Final connection to End requires both path 3 and 4 to be completed
        if completedConnections.contains(3) && completedConnections.contains(4) && !completedConnections.contains(5) {
            available.append(5)
        }
        
        return available
    }
    
    // MARK: - Game State Methods
    
    func completeConnection(index: Int) {
        print("MapScene.completeConnection called with index: \(index)")
        
        // Mark this connection as completed
        completedConnections.insert(index)
        
        // Find the connection in our data to discover the location
        if let connection = connections.first(where: { $0.index == index }) {
            // Update the intermediate location label if needed
            let toLocationIndex = connection.to
            if toLocationIndex > 0 && toLocationIndex < 4 {
                discoveredWords[toLocationIndex] = connection.word
                if let label = locationLabels[toLocationIndex] {
                    label.text = connection.word
                }
            }
        }
        
        // Update the connection visual state
        if let connectionNode = childNode(withName: "connection_\(index)") {
            print("Found connection node: \(connectionNode.name ?? "unnamed")")
            
            // Get the dotted and solid lines from userData
            if let dottedLine = connectionNode.userData?.value(forKey: "dottedLine") as? SKNode,
               let solidLine = connectionNode.userData?.value(forKey: "solidLine") as? SKShapeNode {
                
                // Hide dotted line, show solid line
                dottedLine.run(SKAction.fadeOut(withDuration: 0.3))
                solidLine.run(SKAction.sequence([
                    SKAction.wait(forDuration: 0.1),
                    SKAction.fadeIn(withDuration: 0.3)
                ]))
                
                // Add a pulse animation to the solid line
                let pulseAction = SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.6, duration: 0.5),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.5)
                ])
                solidLine.run(SKAction.repeat(pulseAction, count: 3))
            }
        } else {
            print("Connection node with index \(index) not found")
        }
        
        // Save connection progress
        saveConnectionProgress(index: index)
        
        // Update available connections
        updateAvailableConnections()
        
        // Check if all connections are complete
        if completedConnections.count == connections.count {
            showGameComplete()
        }
    }
    
    // Check if all connections are complete
    private func checkForGameCompletion() {
        // Logic to determine if the player has completed all connections
        // This would depend on how many total connections your game has
    }
    
    // Save completed connection to UserDefaults
    private func saveConnectionProgress(index: Int) {
        // Get current completed connections
        var savedConnections = UserDefaults.standard.array(forKey: "CompletedConnections") as? [Int] ?? []
        
        // Add this index if it's not already included
        if !savedConnections.contains(index) {
            savedConnections.append(index)
            UserDefaults.standard.set(savedConnections, forKey: "CompletedConnections")
            print("Saved connection \(index) to CompletedConnections: \(savedConnections)")
        }
    }

    // Load completed connections when the map scene is created
    func loadCompletedConnections() {
        let savedConnections = UserDefaults.standard.array(forKey: "CompletedConnections") as? [Int] ?? []
        print("Loaded completed connections: \(savedConnections)")
        
        // Update our local set
        completedConnections = Set(savedConnections)
        
        // Process each completed connection
        for index in savedConnections {
            // Find the connection data
            if let connection = connections.first(where: { $0.index == index }) {
                // Update the intermediate location label if needed
                let toLocationIndex = connection.to
                if toLocationIndex > 0 && toLocationIndex < 4 {
                    discoveredWords[toLocationIndex] = connection.word
                    if let label = locationLabels[toLocationIndex] {
                        label.text = connection.word
                    }
                }
            }
            
            // Update the connection visual state
            if let connectionNode = childNode(withName: "connection_\(index)") {
                // Get the dotted and solid lines from userData
                if let dottedLine = connectionNode.userData?.value(forKey: "dottedLine") as? SKNode,
                   let solidLine = connectionNode.userData?.value(forKey: "solidLine") as? SKShapeNode {
                    
                    // Hide dotted line, show solid line
                    dottedLine.alpha = 0
                    solidLine.alpha = 1
                }
            }
        }
        
        // Update available connections
        updateAvailableConnections()
        
        // Check if game is complete
        if completedConnections.count == connections.count {
            // Don't show completion animation here to avoid showing it every time
            // the map loads, but we could add a "completed" indicator
        }
    }
    
    private func showGameComplete() {
        // Create a congratulations message
        let completionMessage = SKLabelNode(fontNamed: "ArialRoundedMTBold")
        completionMessage.text = "Adventure Complete!"
        completionMessage.fontSize = 36
        completionMessage.fontColor = .orange
        completionMessage.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
        completionMessage.zPosition = 10
        completionMessage.setScale(0)
        
        // Add to scene with animation
        addChild(completionMessage)
        completionMessage.run(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.3),
            SKAction.scale(to: 1.0, duration: 0.2)
        ]))
    }
    
    private func handleLocationTap(_ locationIndex: Int) {
        // Find connections that lead to or from this location
        let availableConnections = getAvailableConnections()
        let connectionsForLocation = connections.filter { conn in
            (conn.from == locationIndex || conn.to == locationIndex) &&
            availableConnections.contains(conn.index)
        }
        
        if let firstAvailable = connectionsForLocation.first {
            // Start puzzle with this connection
            print("Starting puzzle via location tap: \(firstAvailable.word)")
            startPuzzle(withWord: firstAvailable.word, connectionIndex: firstAvailable.index)
        } else {
            // If we already completed connections for this location, show a message
            if locationIndex != 0 && locationIndex != 4 && discoveredWords[locationIndex] != nil {
                let completedMessage = SKLabelNode(fontNamed: "ArialRoundedMTBold")
                completedMessage.text = "Location already connected!"
                completedMessage.fontSize = 20
                completedMessage.fontColor = .orange
                completedMessage.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
                completedMessage.zPosition = 10
                completedMessage.alpha = 0
                
                addChild(completedMessage)
                
                // Fade in and out
                let fadeIn = SKAction.fadeIn(withDuration: 0.3)
                let wait = SKAction.wait(forDuration: 1.5)
                let fadeOut = SKAction.fadeOut(withDuration: 0.3)
                let remove = SKAction.removeFromParent()
                let sequence = SKAction.sequence([fadeIn, wait, fadeOut, remove])
                
                completedMessage.run(sequence)
            }
        }
    }
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = self.nodes(at: location)
        
        for node in nodes {
            // Check if a connection button was tapped
            if let name = node.name, name.starts(with: "button_") {
                let index = Int(name.replacingOccurrences(of: "button_", with: ""))!
                
                // Find the connection data
                if let connection = connections.first(where: { $0.index == index }) {
                    // This is where we would transition to the game scene
                    print("Selected connection \(index): \(connection.word)")
                    startPuzzle(withWord: connection.word, connectionIndex: index)
                }
                break
            }
            
            // Check if a location node was tapped
            if let name = node.name, name.starts(with: "location_") {
                let locationIndex = Int(name.replacingOccurrences(of: "location_", with: ""))!
                handleLocationTap(locationIndex)
                break
            }
        }
    }
    
    // MARK: - Game Navigation
    
    func startPuzzle(withWord word: String, connectionIndex: Int) {
        // This method would be called to start a puzzle with the given word
        gameDelegate?.mapScene(self, didSelectPuzzleWithWord: word, connectionIndex: connectionIndex)
        // In a real implementation, this would transition to your GameScene
        print("Starting puzzle with word: \(word), connectionIndex: \(connectionIndex)")
        
    }
    
    // MARK: - Utility Methods
    
    private func isDarkColor(_ color: UIColor) -> Bool {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let brightness = ((red * 299) + (green * 587) + (blue * 114)) / 1000
        return brightness < 0.6
    }
}
