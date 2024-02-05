// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SwiftUI
import SwiftletUtilities

/// A utility for working with resources stored inside of this Swift Package.
open class OnDemandResources {
    
    // MARK: - Event Handlers
    public typealias RequestResourceFromBundleEvent = ([String]) -> NSBundleResourceRequest
    
    // MARK: - Enumerations
    /// Defines the source of a file.
    public enum Source {
        /// The file is from the App's Bundle.
        case appBundle
        
        /// The file is from the Swift Package's Bundle.
        case packageBundle
    }
    
    // MARK: - Static Properies
    /// Handles the manager making a resource request from the app's bundle. If this request is made from the package's compiled code is appears to be resulting in an error.
    ///
    /// Example:
    /// ```swift
    /// OnDemandResources.onRequestResourceFromBundle = {tags in
    ///     return NSBundleResourceRequest(tags: [tag])
    /// }
    /// ```
    public static var onRequestResourceFromBundle:RequestResourceFromBundleEvent? = nil
    
    /// The default location that this library should look for images in.
    public static var imageLocation:Source = .packageBundle
    
    /// The default location that this library should look for sound effects in.
    public static var soundLocation:Source = .packageBundle
    
    /// The default font color for `ODRManager` UI elements.
    public static var fontColor:Color = .white
    
    /// The default button background color for `ODRManager` UI elements.
    public static var buttonBackgroundColor:Color = .red
    
    /// The default loading background image for `ODRManager` UI elements.
    public static var loadingBackgroundImage:String = "GridBackground"
    
    /// The default loading failed background image for `ODRManager` UI elements.
    public static var loadingFailedBackgroundImage:String = "GridBackground"
    
    /// The tag of the last On Demand Resource loaded.
    public static var loadResourceTag:String = ""
    
    /// If `true` and On Demand Resource is currently loading.
    public static var isLoadingResouces:Bool = false
    
    /// Holds the las error that occurred when loading On Demand Resources.
    public static var lastResourceLoadError:String = ""
    
    // MARK: - Static Functions
    /// Gets the path to the requested resource stored in the Swift Package's Bundle.
    /// - Parameters:
    ///   - resource: The name of the resource to locate.
    ///   - ofType: The type/extension of the resource to locate.
    /// - Returns: The path to the resource or `nil` if not found.
    public static func pathTo(resource:String?, ofType:String? = nil) -> String?  {
        let path = Bundle.module.path(forResource: resource, ofType: ofType)
        return path
    }
    
    /// Gets the url to the requested resource stored in the Swift Package's Bundle.
    /// - Parameters:
    ///   - resource: The name of the resource to locate.
    ///   - withExtension: The extension of the resource to locate.
    /// - Returns: The path to the resource or `nil` if not found.
    public static func urlTo(resource:String?, withExtension:String? = nil) -> URL? {
        let url = Bundle.module.url(forResource: resource, withExtension: withExtension)
        return url
    }
}
