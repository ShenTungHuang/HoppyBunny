//
//  GameScene.swift
//  HoppyBunny
//
//  Created by STH on 2017/5/22.
//  Copyright © 2017年 STH. All rights reserved.
//

import SpriteKit
import GameplayKit

enum GameSceneState
{
    case Active, GameOver
}

var HighScore: Int = 0

class GameScene: SKScene, SKPhysicsContactDelegate
{
    
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
    
    var hero: SKSpriteNode!
    var sinceTouch : TimeInterval = 0
    let fixedDelta: TimeInterval = 1.0/60.0 /* 60 FPS */
    
    var scrollLayer: SKNode!
    var scrollSpeed: CGFloat = 160
    
    var cloudLayer: SKNode!
    let cloudSpeed: CGFloat = 20
    
    var obstacleLayer: SKNode!
    var spawnTimer: TimeInterval = 0
    
    /* UI Connections */
    var buttonRestart: MSButtonNode!
    
    /* Game management */
    var gameState: GameSceneState = .Active
    
    var scoreLabel: SKLabelNode!
    
    var points = 0
    
    var levelNLabel: SKLabelNode!
    
    var level = 0
    
    var ripple: SKSpriteNode!
    
    var levelHSLabel: SKLabelNode!
    
    
    override func didMove(to view: SKView)
    {
        /* Recursive node search for 'hero' (child of referenced node) */
        hero = self.childNode(withName: "//hero") as! SKSpriteNode
        
        /* Set reference to scroll layer node */
        scrollLayer = self.childNode(withName: "scrollLayer")
        
        /* Set reference to obstacle layer node */
        obstacleLayer = self.childNode(withName: "obstacleLayer")
        
        /* Set reference to cloud layer node */
        cloudLayer = self.childNode(withName: "cloudLayer")
        
        /* Set physics contact delegate */
        physicsWorld.contactDelegate = self
        
        /* Set UI connections */
        buttonRestart = self.childNode(withName: "buttonRestart") as! MSButtonNode
        
        /* Setup restart button selection handler */
        buttonRestart.selectedHandler = { [unowned self] in
            
            /* Grab reference to our SpriteKit view */
            let skView = self.view as SKView!
            
            /* Load Game scene */
            let scene = GameScene(fileNamed:"GameScene") as GameScene!
            
            /* Ensure correct aspect mode */
            scene?.scaleMode = .aspectFill
            
            /* Restart game scene */
            skView?.presentScene(scene)
            
        }
        
        /* Hide restart button */
        buttonRestart.state = .hidden
        
        scoreLabel = self.childNode(withName: "scoreLabel") as! SKLabelNode
        
        /* Reset Score label */
        scoreLabel.text = String(points)
        
        levelNLabel = self.childNode(withName: "levelNLabel") as! SKLabelNode
        
        levelNLabel.text = String(level)
        
        ripple = SKReferenceNode(fileNamed: "ripple")?.childNode(withName: "ripple") as? SKSpriteNode
        
        levelHSLabel = self.childNode(withName: "levelHSLabel") as! SKLabelNode
        
        levelHSLabel.text = String(HighScore)
        
    }
    
    
    func touchDown(atPoint pos : CGPoint) {
        if let n = self.spinnyNode?.copy() as! SKShapeNode? {
            n.position = pos
            n.strokeColor = SKColor.green
            self.addChild(n)
        }
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        if let n = self.spinnyNode?.copy() as! SKShapeNode? {
            n.position = pos
            n.strokeColor = SKColor.blue
            self.addChild(n)
        }
    }
    
    func touchUp(atPoint pos : CGPoint) {
        if let n = self.spinnyNode?.copy() as! SKShapeNode? {
            n.position = pos
            n.strokeColor = SKColor.red
            self.addChild(n)
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?)
    {
        /* Disable touch if game state is not active */
        if gameState != .Active { return }
        
        /* Reset velocity, helps improve response against cumulative falling velocity */
        hero.physicsBody?.velocity = CGVector(dx: 0, dy: 0)
        
        /* Apply vertical impulse */
        hero.physicsBody?.applyImpulse( CGVector(dx: 0, dy: 300) )
        
        /* Apply subtle rotation */
        hero.physicsBody?.applyAngularImpulse(1)
        
        /* Reset touch timer */
        sinceTouch = 0
        
        /* Play SFX */
        let flapSFX = SKAction.playSoundFileNamed("sfx_flap", waitForCompletion: false)
        self.run(flapSFX)

    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    
    override func update(_ currentTime: TimeInterval)
    {
        // Called before each frame is rendered
        
        /* Skip game update if game no longer active */
        if gameState != .Active { return }
        
        /* Grab current velocity */
        let velocityY: CGFloat = hero.physicsBody?.velocity.dy ?? 0
        
        /* Check and cap vertical velocity */
        if ( velocityY > 400 )
        {
            hero.physicsBody?.velocity.dy = 400
        }
        
        /* Apply falling rotation */
        if sinceTouch > 0.1
        {
            let impulse = -20000 * fixedDelta
            hero.physicsBody?.applyAngularImpulse(CGFloat(impulse))
        }
        
        /* Clamp rotation */
        hero.zRotation = hero.zRotation.clamped(CGFloat(-90).degreesToRadians(), CGFloat(30).degreesToRadians())
        hero.physicsBody!.angularVelocity = hero.physicsBody!.angularVelocity.clamped(-2, 2)
        
        /* Update last touch timer */
        sinceTouch += fixedDelta
        
        /* Process world scrolling */
        scrollWorld()
        
        /* Process obstacles */
        updateObstacles()
        
        /* Update Timer */
        spawnTimer += fixedDelta
    }
    
    func scrollWorld()
    {
        /* Scroll World */
        scrollLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        cloudLayer.position.x -= cloudSpeed * CGFloat(fixedDelta)
        
        /* Loop through scroll layer nodes */
        for ground in scrollLayer.children as! [SKSpriteNode]
        {
            
            /* Get ground node position, convert node position to scene space */
            let groundPosition = scrollLayer.convert(ground.position, to: self)
            
            /* Check if ground sprite has left the scene */
            if groundPosition.x <= -ground.size.width - 2
            {
                
                /* Reposition ground sprite to the second starting position */
                let newPosition = CGPoint( x: /*(self.size.width / 2)*/-6 + ground.size.width, y: groundPosition.y)
                
                /* Convert new node position back to scroll layer space */
                ground.position = self.convert(newPosition, to: scrollLayer)
            }
        }
        
        for cloud in scrollLayer.children as! [SKSpriteNode]
        {
            
            /* Get ground node position, convert node position to scene space */
            let cloudPosition = cloudLayer.convert(cloud.position, to: self)
            
            /* Check if ground sprite has left the scene */
            if cloudPosition.x <= -cloud.size.width - 2
            {
                
                /* Reposition ground sprite to the second starting position */
                let newPosition = CGPoint( x: /*(self.size.width / 2)*/-6 + cloud.size.width, y: cloudPosition.y)
                
                /* Convert new node position back to scroll layer space */
                cloud.position = self.convert(newPosition, to: cloudLayer)
            }
        }
    }
    
    func updateObstacles()
    {
        /* Update Obstacles */
        
        obstacleLayer.position.x -= scrollSpeed * CGFloat(fixedDelta)
        
        /* Loop through obstacle layer nodes */
        for obstacle in obstacleLayer.children as! [SKReferenceNode]
        {
            
            /* Get obstacle node position, convert node position to scene space */
            let obstaclePosition = obstacleLayer.convert(obstacle.position, to: self)
            
            /* Check if obstacle has left the scene */
            if obstaclePosition.x <= -132.5
            {
                /* Remove obstacle node from obstacle layer */
                obstacle.removeFromParent()
            }
            
        }
        
        /* Time to add a new obstacle? */
        if spawnTimer >= 1.5
        {
            
            /* Create a new obstacle reference object using our obstacle resource */
            //let resourcePath = NSBundle.mainBundle().pathForResource("Obstacle", ofType: "sks")
            let resourcePath = Bundle.main.path(forResource: "Obstacle", ofType: "sks")
            //let newObstacle = SKReferenceNode(URL: NSURL(fileURLWithPath: resourcePath!))
            let newObstacle = SKReferenceNode(url: NSURL(fileURLWithPath: resourcePath!) as URL)
            obstacleLayer.addChild(newObstacle)
            
            /* Generate new obstacle position, start just outside screen and with a random y value */
            let randomPosition = CGPoint(x: 447.5, y: CGFloat.random(min: -50, max: 160))
            
            /* Convert new node position back to obstacle layer space */
            newObstacle.position = self.convert(randomPosition, to: obstacleLayer)
            
            // Reset spawn timer
            spawnTimer = 0
        }
    }
    
    func didBegin(_ contact: SKPhysicsContact)
    {
        /* Ensure only called while game running */
        if gameState != .Active { return }
        
        /* Get references to bodies involved in collision */
        let contactA:SKPhysicsBody = contact.bodyA
        let contactB:SKPhysicsBody = contact.bodyB
        
        /* Get references to the physics body parent nodes */
        let nodeA = contactA.node!
        let nodeB = contactB.node!
        
        /* Did our hero pass through the 'goal'? */
        if ( nodeA.name == "goal" || nodeB.name == "goal" )
        {
            addRipple()
            
            /* Play SFX */
            let flapSFX = SKAction.playSoundFileNamed("sfx_goal", waitForCompletion: false)
            self.run(flapSFX)
            
            /* Increment points */
            points += 1
            
            /* Update score label */
            scoreLabel.text = String(points)
            
            let temp: Int = level
            level = (points / 5)
            
            if ( level - temp != 0 )
            { scrollSpeed = scrollSpeed + 100 }
            
            levelNLabel.text = String(level)
            
            if ( points > HighScore )
            {
                let color = UIColor(red: CGFloat(1.0), green: CGFloat(0.0), blue: CGFloat(0.0), alpha: CGFloat(1.0))
                scoreLabel.fontColor = color
                scoreLabel.text = String(points)
            }
            
            /* We can return now */
            return
        }
        
        /* Hero touches anything, game over */
        
        /* Change game state to game over */
        gameState = .GameOver
        
        /* Stop any new angular velocity being applied */
        hero.physicsBody?.allowsRotation = false
        
        /* Reset angular velocity */
        hero.physicsBody?.angularVelocity = 0
        
        /* Stop hero flapping animation */
        hero.removeAllActions()
        
        /* Create our hero death action */
        let heroDeath = SKAction.run({
            /* Put our hero face down in the dirt */
            self.hero.zRotation = CGFloat(-90).degreesToRadians()
            /* Stop hero from colliding with anything else */
            self.hero.physicsBody?.collisionBitMask = 0
        })
        
        /* Run action */
        hero.run(heroDeath)
        
        /* Load the shake action resource */
        let shakeScene:SKAction = SKAction.init(named: "Shake")!
        
        /* Loop through all nodes  */
        for node in self.children
        {
            /* Apply effect each ground node */
            node.run(shakeScene)
        }
        
        /* Show restart button */
        buttonRestart.state = .active
        
        if ( points > HighScore )
        {
            HighScore = points
            levelHSLabel.text = String(HighScore)
        }
    }
    
    func addRipple()
    {
        ripple?.removeFromParent()
        ripple = SKReferenceNode(fileNamed: "ripple")?.childNode(withName: "ripple") as? SKSpriteNode
        ripple?.removeFromParent()
        ripple?.alpha = 1.0
        ripple?.zPosition = 20
        if let ripple = ripple, let location = hero?.position
        {
            ripple.position = location // I can't fix, something like scale
            addChild(ripple)
            
            let removeOnFinish = SKAction.run({
                self.ripple?.removeFromParent()
                self.ripple?.removeAllActions()
                self.ripple = nil
            })
            ripple.run(SKAction.sequence([SKAction.wait(forDuration: 3), removeOnFinish]))
        }
    }
}

