//
//  MapboxGLAnnotations.swift
//
//  Created by Andrea Cremaschi on 26/05/15.
//  Copyright (c) 2015 andreacremaschi. All rights reserved.
//

import Foundation
import Mapbox
import MapKit

// MARK: - MGLShape creation convenience function

public protocol GEOSwiftMapboxGL {
    /**
    A convenience method to create a `MGLShape` ready to be added to a `MGLMapView`.
    Mapbox has limited support to GEOS geometry types: be aware that when dealing with polygons, interior rings are not handled by MapBoxGL, we must drop this information while building a polygon shape.

    :returns: A MGLShape representing this geometry.
    */
    func mapboxShape() -> MGLShape
}

//extension Geometry : GEOSwiftMapboxGL {
//    public func mapboxShape() -> MGLShape {
//        if let geom = self as? MultiPolygon {
//            let geometryCollectionOverlay = MGLShapesCollection(geometryCollection: geom)
//            return geometryCollectionOverlay
//        } else
//            if let geom = self as? MultiLineString {
//                let geometryCollectionOverlay = MGLShapesCollection(geometryCollection: geom)
//                return geometryCollectionOverlay
//            } else
//                if let geom = self as? MultiPoint {
//                    let geometryCollectionOverlay = MGLShapesCollection(geometryCollection: geom)
//                    return geometryCollectionOverlay
//                } else
//                    if let geom = self as? GeometryCollection {
//                        let geometryCollectionOverlay = MGLShapesCollection(geometryCollection: geom)
//                        return geometryCollectionOverlay
//        }
//        
//        // this method is just a workaround for limited extension capabilities in Swift 1.2
//        // and should NEVER actually return MGLShape()
//        return MGLShape()
//    }
//}

extension Waypoint : GEOSwiftMapboxGL {
    public func mapboxShape() -> MGLShape {
        let pointAnno = MGLPointAnnotation()
        pointAnno.coordinate = CLLocationCoordinateFromCoordinate(self.coordinate)
        return pointAnno
    }
}

extension LineString : GEOSwiftMapboxGL {
    public func mapboxShape() -> MGLShape {
        var coordinates = self.points.map({ (point: Coordinate) ->
            CLLocationCoordinate2D in
            return CLLocationCoordinateFromCoordinate(point)
        })
        let polyline = MGLPolyline(coordinates: &coordinates,
            count: UInt(coordinates.count))
        return polyline
    }
}

extension Polygon : GEOSwiftMapboxGL {
    public func mapboxShape() -> MGLShape {
        var exteriorRingCoordinates = self.exteriorRing.points.map({ (point: Coordinate) ->
            CLLocationCoordinate2D in
            return CLLocationCoordinateFromCoordinate(point)
        })

        // interior rings are not handled by MapBoxGL, we must drop this info!
//        let interiorRings = self.interiorRings.map({ (linearRing: LinearRing) ->
//            MGLPolygon in
//            return MGLPolygonWithCoordinatesSequence(linearRing.points)
//        })
        
        let polygon = MGLPolygon(coordinates: &exteriorRingCoordinates, count: UInt(exteriorRingCoordinates.count)/*, interiorPolygons: interiorRings*/)
        return polygon
    }
}

extension GeometryCollection : GEOSwiftMapboxGL {
    public func mapboxShape() -> MGLShape {
        let geometryCollectionOverlay = MGLShapesCollection(geometryCollection: self)
        return geometryCollectionOverlay
    }
}

private func MGLPolygonWithCoordinatesSequence(coordinates: CoordinatesCollection) -> MGLPolygon {
    var coordinates = coordinates.map({ (point: Coordinate) ->
        CLLocationCoordinate2D in
        return CLLocationCoordinateFromCoordinate(point)
    })
    return MGLPolygon(coordinates: &coordinates,
        count: UInt(coordinates.count))
    
}

/**
MGLShape subclass for GeometryCollections.
The property `shapes` contains MGLShape subclasses instances. When drawing shapes on a map be careful to the fact that that these shapes could be overlays OR annotations.
*/
public class MGLShapesCollection : MGLShape, MGLOverlay {
    let shapes: Array<MGLShape>
    public let centroid: CLLocationCoordinate2D
    public let overlayBounds: MGLCoordinateBounds
    
    // inserting the where clause in the following generic create some confusion in the precompiler that raise the following error:
    // Cannot invoke initializer for type ... with an argument list of type (geometryCollection: GeometryCollection<T>)
    // 1. Expected an argument list of type (geometryCollection: GeometryCollection<T>)
    required public init<T /* where T: GEOSwiftMapboxGL */>(geometryCollection: GeometryCollection<T>) {
        let shapes = geometryCollection.geometries.map({ (geometry: T) ->
            MGLShape in
            if let geom = geometry as? GEOSwiftMapboxGL {
                return geom.mapboxShape()
            }
            return MGLShape()
        })
        self.centroid = CLLocationCoordinateFromCoordinate(geometryCollection.centroid().coordinate)
        self.shapes = shapes
        
        if let envelope = geometryCollection.envelope() as? Polygon {
            let exteriorRing = envelope.exteriorRing
            let sw = CLLocationCoordinateFromCoordinate(exteriorRing.points[0])
            let ne = CLLocationCoordinateFromCoordinate(exteriorRing.points[2])
            self.overlayBounds = MGLCoordinateBounds(sw:sw, ne:ne)
        } else {
            let zeroCoord = CLLocationCoordinate2DMake(0, 0)
            self.overlayBounds = MGLCoordinateBounds(sw:zeroCoord, ne:zeroCoord)
        }
    }
    
    override public var coordinate: CLLocationCoordinate2D { get {
        return centroid
        }}
    
    // TODO: implement using "intersect" method (actually it seems that mapboxgl never calls it...)
    public func intersectsOverlayBounds(overlayBounds: MGLCoordinateBounds) -> Bool {
        return true
    }
}
