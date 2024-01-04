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
    
    // Material for plotting data
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
    let dateFormatter = DateFormatter()
    var t0 = String()

    
    @IBOutlet weak var sceneView: ARSCNView!
    var overlay: SKScene!
    
    //ARKit 3D objects
    //ARFaceAnchor's axes (reference node for the face referential)
    let faceAxes = SCNReferenceNode(url: axesURL)!
    
    //Gaze projection on the screen plane, in the world referential
    let projectedNode = SCNNode(geometry: SCNSphere(radius: 0.002))

    //Node which position is lookAtPoint (face referential)
    let lookAtPointNode = SCNNode(geometry: SCNSphere(radius: 0.01))

    //Reference node for the right eye referential (in reality anchored on the user's left eye)
    let rightEyeNode = SCNReferenceNode(url: axesURL)!
    
    //Nodes storing the lookAtPoint's position during calibraton phase
    let upperLeft = SCNNode(geometry: SCNSphere(radius: 0.01))
    let upperRight = SCNNode(geometry: SCNSphere(radius: 0.01))
    let downLeft = SCNNode(geometry: SCNSphere(radius: 0.01))
    
    
    //SpriteKit 2D objects
    //Final gaze's estimation indicator on the screen
    var pointSKNode = SKShapeNode(circleOfRadius: 20)
    //Referential node for calibration
    var calibNode = SKShapeNode(circleOfRadius: 40)

    //Touch node and position
    let touchedNode = SKShapeNode(circleOfRadius: 30)
    var touchPosition: CGPoint = CGPointZero

    // a later stores the width of the screen in CGPoints
    var a = CGFloat()
    // b later stores the length of the screen in CGPoints
    var b = CGFloat()
    // length later stores the estimated length of the screen in meters
    var length = Float()
    // width later stores the estimated width of the screen in meters
    var width = Float()
    // pointsPerMeter later stores the estimated number of CGPoints per meter
    var pointsPerMeter = Float()
    
    //Array of CGPoints storing each frame's estimated position of the gaze
    var pts = [CGPoint(x: 0.0, y: 0)]
    
    //is true when the calibration phase is over
    var run = false
    
    //Called when the app is launched
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the view and the scene
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        
        //Set the SpriteKit overlay to display 2D elements
        overlay = SKScene(size: sceneView.bounds.size)
        overlay.backgroundColor = UIColor.clear
        sceneView.overlaySKScene = overlay
        
        //loading nodes and establishing hierarchy
        faceAxes.load()
        rightEyeNode.load()
        sceneView.scene.rootNode.addChildNode(upperLeft)
        sceneView.scene.rootNode.addChildNode(upperRight)
        sceneView.scene.rootNode.addChildNode(downLeft)
        overlay.addChild(calibNode)
        overlay.addChild(touchedNode)
        
        //node colors
        projectedNode.isHidden = true
        pointSKNode.fillColor = .blue
        pointSKNode.strokeColor = .blue
        touchedNode.fillColor = .green
        touchedNode.strokeColor = .green
        calibNode.fillColor = .black
        
        //The initial position of the gaze's estimator is set to the center of the screen
        pointSKNode.position = CGPoint(x: a/2, y: b/2)

        sceneView.overlaySKScene?.isUserInteractionEnabled = false
        
        //a stores the width of the screen in CGPoint units
        a = sceneView.frame.width
        //b stores the width of the screen in CGPoint units
        b = sceneView.frame.height
        
        run = false
        
        //Material for plotting
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        t0 = dateFormatter.string(from: Date())
    }
    
    //Called when the app opens
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()
        // Set the origin of the world referential to the camera of the device
        configuration.worldAlignment = .camera
        
        // Run the session
        sceneView.session.run(configuration)
        
    }
    
    // Called when the app is closed
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        //Export data to CSV files for plotting
        exportCSV(dataArray: ptsData, filename: "ptsData")
        exportCSV(dataArray: touchData, filename: "touchData")
        exportCSV(dataArray: eulerAnglesData, filename: "eulerData")
        exportCSV(dataArray: distToScreenData, filename: "distData")
        
        // Pause the session
        sceneView.session.pause()
    }
    
    // Called each time the frame is updated, ie. 60 times per seconds (ARKit's fps value)
    func session(_ session: ARSession, didUpdate frame : ARFrame) {
        if let faceAnchor = frame.anchors.compactMap({
            $0 as? ARFaceAnchor
        }).first {
            
            //Material for the CSV export
            let formattedDate = dateFormatter.string(from: Date())
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            let date1 = dateFormatter.date(from: t0)
            let date2 = dateFormatter.date(from: formattedDate)
            let difference = date2!.timeIntervalSince(date1!)
            let formattedDifference = formatTimeInterval(difference)
                

            //set simdTransform of nodes
            faceAxes.simdTransform = faceAnchor.transform
            rightEyeNode.simdTransform = faceAnchor.rightEyeTransform
            
            //Keep the node's position updated with the value of ARKit's lookAtPoint estimation
            lookAtPointNode.simdPosition = faceAnchor.lookAtPoint
            
            //Material for linePlane()
            let p0_line = simd_float3(faceAxes.worldPosition)
            let p1_line = simd_float3(lookAtPointNode.worldPosition)
            let p0_plane = simd_float3(0,0,0)
            let normal_plane = simd_float3(0,0,1)
            
        
            projectedNode.position = SCNVector3(linePlane(p0_line: p0_line , p1_line: p1_line, p0_plane: p0_plane, normal_plane: normal_plane))
            projectedNode.position = SCNVector3(projectedNode.position.x, projectedNode.position.y, -0.05)
            
            
            touchedNode.position = CGPoint(x: Double(self.touchPosition.x), y: Double(self.touchPosition.y))
           
            let point = convertARKitPositionToSpriteKitPoint(worldPosition: simd_float3(projectedNode.worldPosition))
            
            if(run == true){
                ptsData.append(PointData(point: point, timestamp: formattedDifference))
                touchData.append(PointData(point: touchPosition, timestamp: formattedDifference))
                eulerAnglesData.append(PointDiff(timestamp: formattedDifference, Xrot: faceAxes.simdEulerAngles.x, Yrot: faceAxes.simdEulerAngles.y, Zrot: faceAxes.simdEulerAngles.z, Xdiff: abs(point.x - touchedNode.position.x), Ydiff: abs(point.y - touchedNode.position.y)))
                distToScreenData.append(DistanceData(timestamp: formattedDifference, Xface:faceAxes.position.x, Yface:faceAxes.position.y, Zface:-faceAxes.position.z, Xdiff: abs(point.x - touchedNode.position.x), Ydiff: abs(point.y - touchedNode.position.y)))
                
                pts.append(point)
                
                let k = min(10, pts.count)
                pointSKNode.position = averageOfLastKCGPoints(array: pts, k: k)!
            }else{
                pointSKNode.position = point
            }
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
            self.run = true
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


