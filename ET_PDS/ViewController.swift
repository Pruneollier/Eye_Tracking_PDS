//
//  ViewController.swift
//  ET_PDS
//
//  Created by prune ollier on 30.10.2023.
//

import UIKit
import SceneKit
import ARKit
import SpriteKit

let axesURL = Bundle.main.url(forResource: "axes", withExtension: "scn")!


class ViewController: UIViewController, ARSessionDelegate {
    
    struct PointData {
        var point: CGPoint
        var timestamp: String
    }
    
    struct PointDiff{
        var timestamp: String
        var Xrot: Float
        var Yrot: Float
        var Zrot: Float
        var Xdiff: CGFloat
        var Ydiff: CGFloat
    }
    
    struct DistanceData{
        var timestamp: String
        var Xface: Float
        var Yface: Float
        var Zface: Float
        var Xdiff: CGFloat
        var Ydiff: CGFloat
    }
    
    var ptsData = [PointData]()
    var touchData = [PointData]()
    var eulerAnglesData = [PointDiff]()
    var distToScreenData = [DistanceData]()
        
    @IBOutlet weak var sceneView: ARSCNView!
    var overlay: SKScene!
    
    let dateFormatter = DateFormatter()

    // axes fixes au milieu de l'écran
    let axes = SCNReferenceNode(url: axesURL)!
    
    //axes rattachés au visage
    let faceAxes = SCNReferenceNode(url: axesURL)!
    
    //node final du regard sur l'écran (vert)
    let projectedNode = SCNNode(geometry: SCNSphere(radius: 0.002))

    //lookAtPoint as a node (in face coordinates)
    let lookAtPointNode = SCNNode(geometry: SCNSphere(radius: 0.01))

    //node de l'oeil droit (gauche en réalité?)
    let rightEyeNode = SCNReferenceNode(url: axesURL)!
    
    //node rouge pour les tests
    let sphereNode = SCNNode(geometry: SCNSphere(radius: 0.01))
    
    
    //nodes for calibraton
    let upperLeft = SCNNode(geometry: SCNSphere(radius: 0.01))
    let upperRight = SCNNode(geometry: SCNSphere(radius: 0.01))
    let downLeft = SCNNode(geometry: SCNSphere(radius: 0.01))
    
    //node SpriteKit
    var pointSKNode = SKShapeNode(circleOfRadius: 20)
    let markerNode = SKSpriteNode(color: UIColor.red, size: CGSize(width: 20, height: 20))
    var calibNode = SKShapeNode(circleOfRadius: 40)

    // ADD
    let touchedNode = SKShapeNode(circleOfRadius: 30)
    var touchPosition: CGPoint = CGPointZero
    
    var a = CGFloat()
    var b = CGFloat()
    var PPI = CGFloat()
    var length = Float()
    var width = Float()
    var pointsPerMeter = Float()
    
    var pts = [CGPoint(x: 0.0, y: 0)]
    var touchPositions = [CGPoint(x: 0.0, y: 0)]
    var run = false
    var t0 = String()
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        
        
        //Set the SpriteKit overlay to display 2D elements
        
        /*let skScene = SKScene(size: .zero)
        skScene.scaleMode = .resizeFill
        
        sceneView.overlaySKScene = skScene*/
        
        overlay = SKScene(size: sceneView.bounds.size)
        overlay.backgroundColor = UIColor.clear
        markerNode.position = CGPoint(x: overlay.size.width / 2, y: overlay.size.height / 2)
        overlay.addChild(markerNode)
        sceneView.overlaySKScene = overlay
        overlay.addChild(calibNode)
        calibNode.fillColor = .black
        overlay.addChild(touchedNode)

        
        //loading nodes
        faceAxes.load()
        rightEyeNode.load()
        sceneView.scene.rootNode.addChildNode(sphereNode)
        sceneView.scene.rootNode.addChildNode(upperLeft)
        sceneView.scene.rootNode.addChildNode(upperRight)
        sceneView.scene.rootNode.addChildNode(downLeft)

        sphereNode.position = SCNVector3(0.1,0.1,-0.5)
        /*axes.load()
        sceneView.scene.rootNode.addChildNode(axes)
        axes.position = SCNVector3(0, 0, -0.05)*/
        
        //node colors
        projectedNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 65/255, green: 220/255, blue: 23/255, alpha: 0.8)
        sphereNode.geometry?.firstMaterial?.diffuse.contents = UIColor(red: 220/255, green: 65/255, blue: 23/255, alpha: 0.8)
        pointSKNode.fillColor = .blue
        pointSKNode.strokeColor = .blue
        touchedNode.fillColor = .green
        touchedNode.strokeColor = .green

        /*print("rootNode worldTransform : \n", sceneView.scene.rootNode.worldTransform, "\n")
        print("rootNode transform : \n", sceneView.scene.rootNode.transform, "\n")
        print("rootNode simdTransform : \n", sceneView.scene.rootNode.simdTransform , "\n")
        print("rootNode.orientation : \n", sceneView.scene.rootNode.orientation)*/
        
        //Pourquoi le touch est détecté alors ??
        sceneView.overlaySKScene?.isUserInteractionEnabled = false
        
        a = sceneView.frame.width
        print("a:", a)
        
        b = sceneView.frame.height
        print("b:", b)
        PPI = UIScreen.main.scale
        print(PPI)
        
        pointSKNode.position = CGPoint(x: a/2, y: b/2)
        run = false
        
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        t0 = dateFormatter.string(from: Date())
        print(t0)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        print(ARFaceTrackingConfiguration.isSupported)
        guard ARFaceTrackingConfiguration.isSupported else { return }

        
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()
        configuration.worldAlignment = .camera
        
        // Run the view's session
        sceneView.session.run(configuration)
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        exportCSV(dataArray: ptsData, filename: "ptsData")
        exportCSV(dataArray: touchData, filename: "touchData")
        exportCSV(dataArray: eulerAnglesData, filename: "eulerData")
        exportCSV(dataArray: distToScreenData, filename: "distData")
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    func session(_ session: ARSession, didUpdate frame : ARFrame) {
        if let faceAnchor = frame.anchors.compactMap({
            $0 as? ARFaceAnchor
        }).first {
            
            let formattedDate = dateFormatter.string(from: Date())
            
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            
            let date1 = dateFormatter.date(from: t0)
            let date2 = dateFormatter.date(from: formattedDate)
            let difference = date2!.timeIntervalSince(date1!)
            let formattedDifference = formatTimeInterval(difference)
                

            //set simdTransform of nodes
            faceAxes.simdTransform = faceAnchor.transform
            rightEyeNode.simdTransform = faceAnchor.rightEyeTransform
            
            //create a node for lookAtPoint
            lookAtPointNode.simdPosition = faceAnchor.lookAtPoint

            /*print("pointOfView.worldPosition :", sceneView.pointOfView?.worldPosition)
            print("rootNode.worldPosition : ",sceneView.scene.rootNode.worldPosition)
            print("lookAtPointNode.worldPosition : ", lookAtPointNode.worldPosition)*/
            
            // afficher le projectedNode si la position de lookAtPoint est estimée être à plus ou moins 10 cm de l'écran
            /*if(lookAtPointNode.worldPosition.z > -0.1 && lookAtPointNode.worldPosition.z < 0.1){
                print("lookAtPoint : ", lookAtPointNode.worldPosition)
                projectedNode.position = SCNVector3(lookAtPointNode.worldPosition.x, lookAtPointNode.worldPosition.y, -0.05 )
            }*/
            
            
            //projectedNode.position = SCNVector3(lookAtPointNode.worldPosition.x , lookAtPointNode.worldPosition.y, -0.05)
            //projectedNode.position = SCNVector3(b/2,0,0)
            
            
            let p0_line = simd_float3(faceAxes.worldPosition)
            let p1_line = simd_float3(lookAtPointNode.worldPosition)
            let p0_plane = simd_float3(0,0,0)
            let normal_plane = simd_float3(0,0,1)
            
            
            projectedNode.position = SCNVector3(linePlane(p0_line: p0_line , p1_line: p1_line, p0_plane: p0_plane, normal_plane: normal_plane))
            //print("projectedNode position: ", projectedNode.position)
            projectedNode.position = SCNVector3(projectedNode.position.x, projectedNode.position.y, -0.05)
            
            
            touchedNode.position = CGPoint(x: Double(self.touchPosition.x), y: Double(self.touchPosition.y))
            /*pointSKNode.position = convertARKitPositionToSpriteKitPoint(worldPosition: SIMD3(projectedNode.position))*/
            
            /*pointSKNode.position = frame.camera.projectPoint(simd_float3(-projectedNode.simdPosition.x, projectedNode.simdPosition.y, projectedNode.simdPosition.z), orientation: .portrait , viewportSize: sceneView.frame.size)
            pointSKNode.position = CGPoint(x: pointSKNode.position.x , y: pointSKNode.position.y + b/2)*/
            let point = convertARKitPositionToSpriteKitPoint(worldPosition: simd_float3(projectedNode.worldPosition))
            
            if(run == true){
                ptsData.append(PointData(point: point, timestamp: formattedDifference))
                touchData.append(PointData(point: touchPosition, timestamp: formattedDifference))
                eulerAnglesData.append(PointDiff(timestamp: formattedDifference, Xrot: faceAxes.simdEulerAngles.x, Yrot: faceAxes.simdEulerAngles.y, Zrot: faceAxes.simdEulerAngles.z, Xdiff: abs(point.x - touchedNode.position.x), Ydiff: abs(point.y - touchedNode.position.y)))
                distToScreenData.append(DistanceData(timestamp: formattedDifference, Xface:faceAxes.position.x, Yface:faceAxes.position.y, Zface:-faceAxes.position.z, Xdiff: abs(point.x - touchedNode.position.x), Ydiff: abs(point.y - touchedNode.position.y)))
                
                pts.append(point)
                touchPositions.append(touchedNode.position)
                
                let k = min(10, pts.count)
                pointSKNode.position = averageOfLastKCGPoints(array: pts, k: k)!
            }else{
                pointSKNode.position = point
            }
            
            //print("pointSKNode position : ", pointSKNode.position)
            
            //print(frame.camera.projectionMatrix.columns.2)
            //print(frame.camera.viewMatrix(for: .landscapeLeft))
            //print("camera projection matrix: ", frame.camera.projectionMatrix)
        }
    }
    
    
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        if anchors.compactMap({
            $0 as? ARFaceAnchor
        }).first != nil {
            sceneView.scene.rootNode.addChildNode(faceAxes)
            sceneView.scene.rootNode.addChildNode(projectedNode)
            faceAxes.addChildNode(lookAtPointNode)
            faceAxes.addChildNode(rightEyeNode)
            overlay.addChild(pointSKNode)
            calibration()

        }
    }
    
    // Convert ARKit node's position to SpriteKit point
    func convertARKitPositionToSpriteKitPoint(worldPosition: SIMD3<Float>) -> CGPoint {
        
        return CGPoint(x: a/2 + CGFloat(Float(worldPosition.y) * pointsPerMeter), y: b - CGFloat(Float(worldPosition.x) * pointsPerMeter) )
    }
    
    func linePlane(p0_line: SIMD3<Float>, p1_line: SIMD3<Float>, p0_plane: SIMD3<Float> , normal_plane:SIMD3<Float>) -> SIMD3<Float> {
        
        var ret = simd_float3.zero
        var w = simd_float3.zero
        var fac: Float = 0.0
        
        let epsilon: Float = 0.01
        let u = p1_line - p0_line
        let dot = simd_dot(normal_plane, u)
        
        if (dot > epsilon) {
            w = p0_line - p0_plane
            fac = -simd_dot(normal_plane, w) / dot
            ret = p0_line + (u * fac)
        }
        //print(dot, u, w, fac)
        return ret
    }
    
    func calibration(){
        // Separate events by 2 seconds
        let delayInSeconds: TimeInterval = 2.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) {
            self.calibNode.position = (CGPoint(x:0,y:0))
            self.sceneView.unprojectPoint(SCNVector3(self.calibNode.position.x, self.calibNode.position.y, 0))
            
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (2 * delayInSeconds)) {
            self.upperLeft.position = self.lookAtPointNode.worldPosition
            print(self.upperLeft.worldPosition)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (3 * delayInSeconds)) {
            // Code to be executed after another 2 seconds
            self.calibNode.position = (CGPoint(x:0,y:self.b))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (4 * delayInSeconds)) {
            self.upperRight.position = self.lookAtPointNode.worldPosition
            print(self.upperRight.worldPosition)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (5 * delayInSeconds)) {
            // Code to be executed after another 2 seconds
            self.calibNode.position = (CGPoint(x:self.a,y:0))
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (6 * delayInSeconds)) {
            self.downLeft.position = self.lookAtPointNode.worldPosition
            print(self.downLeft.worldPosition)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (7 * delayInSeconds)) {
            self.length = self.upperLeft.position.x - self.upperRight.position.x
            print(self.length)
            self.width = self.downLeft.position.y - self.upperRight.position.y
            print(self.width)
            self.pointsPerMeter = Float(self.b) / self.length
            print(self.pointsPerMeter)
            self.pointsPerMeter = Float(self.a) / self.width
            print(self.pointsPerMeter)
            //self.pointsPerMeter = Float(self.a + self.b) / (self.width + self.length)
            //print(self.pointsPerMeter)
            self.run = true
        }
        
    }
    
    func calibration2(){
        // Separate events by 2 seconds
        let delayInSeconds: TimeInterval = 3.0

        DispatchQueue.main.asyncAfter(deadline: .now() + delayInSeconds) {
            self.calibNode.position = (CGPoint(x:0,y:0))
            self.upperLeft.position = self.sceneView.unprojectPoint(SCNVector3(self.calibNode.position.x, self.calibNode.position.y, 1))
            print(self.upperLeft.worldPosition)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (2 * delayInSeconds)) {
            // Code to be executed after another 2 seconds
            self.calibNode.position = (CGPoint(x:0,y:self.b))
            self.upperRight.position = self.sceneView.unprojectPoint(SCNVector3(self.calibNode.position.x, self.calibNode.position.y, 1))
            print(self.upperRight.worldPosition)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (3 * delayInSeconds)) {
            // Code to be executed after another 2 seconds
            self.calibNode.position = (CGPoint(x:self.a,y:self.b))
            self.downLeft.position = self.sceneView.unprojectPoint(SCNVector3(self.calibNode.position.x, self.calibNode.position.y, 1))
            print(self.downLeft.worldPosition)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (4 * delayInSeconds)) {
            self.length = self.upperLeft.position.x - self.upperRight.position.x
            print(self.length)
            self.width = self.downLeft.position.y - self.upperRight.position.y
            print(self.width)
            self.pointsPerMeter = Float(self.b) / self.length
            print(self.pointsPerMeter)
            self.run = true
        }
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            self.touchPosition = touch.location(in: sceneView.overlaySKScene!)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            self.touchPosition = touch.location(in: sceneView.overlaySKScene!)
        }
    }
    
    func averageOfLastKCGPoints(array: [CGPoint], k: Int) -> CGPoint? {
        // Check if the array has enough elements
        guard array.count >= k else {
            return nil // Return nil if there are not enough elements
        }
        
        // Extract the last k elements from the array
        let lastKCGPoints = Array(array.suffix(k))
        
        // Calculate the sum of the last k elements
        let sumX = lastKCGPoints.reduce(0) { $0 + $1.x }
        let sumY = lastKCGPoints.reduce(0) { $0 + $1.y }
        
        
        // Calculate the average
        let averageX = sumX / CGFloat(k)
        let averageY = sumY / CGFloat(k)
        
        let averageCGPoint = CGPoint(x: averageX, y: averageY)
        return averageCGPoint
    }
    
    func exportCSV(dataArray: [PointData], filename : String){
        print("export called")
        var csvText = "X,Y,Timestamp\n"
        
        for data in dataArray {
                let line = "\(data.point.x),\(data.point.y),\(data.timestamp)\n"
                csvText.append(line)
        }
        
        // Get the document directory URL
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            // Add a file name
            let fileURL = documentsDirectory.appendingPathComponent("\(filename).csv")

            // Write to the file
            do {
                try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file created at \(fileURL)")
            } catch {
                print("Error writing CSV file:", error.localizedDescription)
            }
        }
        
    }
    
    func exportCSV(dataArray: [PointDiff], filename : String){
        print("export called")
        var csvText = "Timestamp,Xrot,Yrot,Zrot,Xdiff,Ydiff\n"
        
        for data in dataArray {
            let line = "\(data.timestamp),\(data.Xrot),\(data.Yrot),\(data.Zrot),\(data.Xdiff),\(data.Ydiff)\n"
                csvText.append(line)
        }
        
        // Get the document directory URL
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            // Add a file name
            let fileURL = documentsDirectory.appendingPathComponent("\(filename).csv")

            // Write to the file
            do {
                try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file created at \(fileURL)")
            } catch {
                print("Error writing CSV file:", error.localizedDescription)
            }
        }
        
    }
    
    func exportCSV(dataArray: [DistanceData], filename: String){
        print("export called")
        var csvText = "Timestamp, Xface, Yface, Zface, Xdiff, Ydiff\n"
        
        for data in dataArray {
            let line = "\(data.timestamp),\(data.Xface),\(data.Yface),\(data.Zface),\(data.Xdiff),\(data.Ydiff)\n"
                csvText.append(line)
        }
        
        // Get the document directory URL
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {

            // Add a file name
            let fileURL = documentsDirectory.appendingPathComponent("\(filename).csv")

            // Write to the file
            do {
                try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
                print("CSV file created at \(fileURL)")
            } catch {
                print("Error writing CSV file:", error.localizedDescription)
            }
        }
    }
   
    // Function to format TimeInterval to "mm:ss.sss"
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        let milliseconds = Int(interval.truncatingRemainder(dividingBy: 1) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }


}


