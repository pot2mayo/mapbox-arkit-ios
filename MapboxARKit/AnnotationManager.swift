import ARKit
import SpriteKit
import CoreLocation

open class AnnotationManager: NSObject {
    
    public private(set) weak var session: ARSession?
    public private(set) weak var sceneView: ARSCNView?
    public private(set) var anchors = [ARAnchor]()
    public private(set) var annotationsByAnchor = [ARAnchor: Annotation]()
    public private(set) var annotationsByNode = [SCNNode: Annotation]()
    public var originLocation: CLLocation?
    
    public init(session: ARSession) {
        self.session = session
    }
    
    var orientation: SCNQuaternion? = nil
    var pos: SCNVector3? = nil
    
    public init(sceneView: ARSCNView) {
        super.init()
        self.session = sceneView.session
        self.sceneView = sceneView
        self.sceneView?.allowsCameraControl = true
        
        print("🙂 🙂 🙂 🙂 🙂 sceneView!.pointOfView!.orientation :: \(sceneView.pointOfView?.orientation)")
        
//        SKCameraNode
        session = sceneView.session
        sceneView.delegate = self
        
        
        if let cameraNode = self.sceneView?.pointOfView {
            let dir = calculateCameraDirection(cameraNode: cameraNode)
            self.pos = pointInFrontOfPoint(point: cameraNode.position, direction: dir, distance: 8)
            self.orientation = cameraNode.orientation
        }
    }

    func pointInFrontOfPoint(point: SCNVector3, direction: SCNVector3, distance: Float) -> SCNVector3 {
        var x = Float()
        var y = Float()
        var z = Float()

        x = point.x + distance * direction.x
        y = point.y + distance * direction.y
        z = point.z + distance * direction.z

        let result = SCNVector3Make(x, y, z)
        return result
    }

    func calculateCameraDirection(cameraNode: SCNNode) -> SCNVector3 {
        let x = -cameraNode.rotation.x
        let y = -cameraNode.rotation.y
        let z = -cameraNode.rotation.z
        let w = cameraNode.rotation.w
        let cameraRotationMatrix = GLKMatrix3Make(cos(w) + pow(x, 2) * (1 - cos(w)),
                                                  x * y * (1 - cos(w)) - z * sin(w),
                                                  x * z * (1 - cos(w)) + y*sin(w),

                                                  y*x*(1-cos(w)) + z*sin(w),
                                                  cos(w) + pow(y, 2) * (1 - cos(w)),
                                                  y*z*(1-cos(w)) - x*sin(w),

                                                  z*x*(1 - cos(w)) - y*sin(w),
                                                  z*y*(1 - cos(w)) + x*sin(w),
                                                  cos(w) + pow(z, 2) * ( 1 - cos(w)))

        let cameraDirection = GLKMatrix3MultiplyVector3(cameraRotationMatrix, GLKVector3Make(0.0, 0.0, -1.0))
        return SCNVector3FromGLKVector3(cameraDirection)
    }
    
    open func addAnnotation(annotation: Annotation) {
        guard let originLocation = originLocation else {
            print("Warning: \(type(of: self)).\(#function) was called without first setting \(type(of: self)).originLocation")
            return
        }
        
        guard annotation.location != nil else {
            print("annotation's location is missing :: \(dump(annotation))")
            return
        }
        // Create a Mapbox AR anchor anchor at the transformed position
        let anchor = MBARAnchor(originLocation: originLocation, location: annotation.location!)
        
        annotation.anchor = anchor
        
        addAnnotationAnchorToARSession(annotation: annotation)
    }
    
    // If it is nil, default node will be created.
    open func createNode(for annotation: Annotation) -> SCNNode? {
        return nil
    }
    
    public func addAnnotationAnchorToARSession(annotation: Annotation) {
        guard let anchor = annotation.anchor else { return }
        // Add the anchor to the session
        session?.add(anchor: anchor)
        
        anchors.append(anchor)
        annotationsByAnchor[anchor] = annotation
    }
    
    public func addAnnotations(annotations: [Annotation]) {
        for annotation in annotations {
            addAnnotation(annotation: annotation)
        }
    }
    
    public func removeAllAnnotations() {
        for anchor in anchors {
            session?.remove(anchor: anchor)
        }
        
        sceneView!.scene.rootNode.enumerateChildNodes { (node, stop) in
            
            node.removeFromParentNode()
            node.enumerateHierarchy({ (node, _) in
                node.removeFromParentNode()
            })
        }
        
        annotationsByNode.removeAll()
        anchors.removeAll()
        
        for e in annotationsByAnchor {
            e.value.location = nil
        }
        annotationsByAnchor.removeAll()
    }
    
    public func removeAnnotations(annotations: [Annotation]) {
        for annotation in annotations {
            removeAnnotation(annotation: annotation)
        }
    }
    
    public func removeAnnotation(annotation: Annotation) {
        if let anchor = annotation.anchor {
            session?.remove(anchor: anchor)
            anchors.remove(at: anchors.firstIndex(of: anchor)!)
            
            for e in annotationsByAnchor {
                e.value.location = nil
            }
            
            annotationsByAnchor.removeValue(forKey: anchor)
            annotation.anchor = nil
        }
    }
    
    public func hideAllNodes(isHidden: Bool) {
        for node in annotationsByNode.keys {
            node.isHidden = isHidden
        }
    }
    
    public func setAnchorDistance(max: Float?, min: Float?) {
        if max != nil { MBARAnchor.ANCHOR_DISTANCE_MAX = max! }
        if min != nil { MBARAnchor.ANCHOR_DISTANCE_MIN = min! }
    }
    
    public func getAnchorDistance() -> (max: Float, min: Float) {
        return (max: MBARAnchor.ANCHOR_DISTANCE_MAX, min: MBARAnchor.ANCHOR_DISTANCE_MIN)
    }
}

// MARK: - ARSCNViewDelegate

extension AnnotationManager: ARSCNViewDelegate {
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        // Handle MBARAnchor
        if let anchor = anchor as? MBARAnchor {
            guard let annotation = annotationsByAnchor[anchor] else {
                print("[MapboxARKit.AnnotationManager.renderer didAdd node:] Cannot render node :: annotationsByAnchor[anchor] is nil")
                return
            }
            
            var newNode: SCNNode!
            
            // If the delegate supplied a node then use that, otherwise provide a basic default node
            if let suppliedNode = self.createNode(for: annotation) {
                newNode = suppliedNode
            } else {
                newNode = createDefaultNode()
            }
            
            print("🙂 🙂 🙂 🙂 🙂 111 node.orientation :: \(node.orientation), scene.rootNode.camera :: \(sceneView?.scene.rootNode.camera)")
            print("🙂 🙂 🙂 🙂 🙂 2222 sceneView!.pointOfView!.orientation :: \(sceneView?.pointOfView!.orientation)")
            print("🙂 🙂 🙂 🙂 🙂 333 newNode.orientation :: \(newNode.orientation)")
//            newNode.simdTransform = anchor.transform
//            node.orientation = sceneView!.pointOfView!.orientation
            
            if pos != nil {
                newNode.position = pos!
            }
            if orientation != nil {
                newNode.orientation = orientation!
            }
            
            node.addChildNode(newNode)
//            node.simdTransform = anchor.transform
            
            annotationsByNode[newNode] = annotation
        }
        
        // TODO: let delegate provide a node for a non-MBARAnchor
    }
    
    // MARK: - Utility methods for ARSCNViewDelegate
    
    func createDefaultNode() -> SCNNode {
        let geometry = SCNSphere(radius: 10)
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        return SCNNode(geometry: geometry)
    }
    
}
