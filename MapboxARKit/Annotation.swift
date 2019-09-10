import CoreLocation

open class Annotation: NSObject {
    
    public weak var location: CLLocation?
    public weak var anchor: MBARAnchor?
    
    public init(location: CLLocation) {
        self.location = location
    }
    
}
