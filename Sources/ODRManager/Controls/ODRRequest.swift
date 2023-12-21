//
//  ODRRequest.swift
//  ReedWriteCycle (iOS)
//
//  Created by Kevin Mullins on 11/21/22.
//
//  On Demand Resources: https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/index.html#//apple_ref/doc/uid/TP40015083-CH2-SW1
//  Video Introduction: https://developer.apple.com/videos/play/wwdc2015/214/
//  Background Assets: https://developer.apple.com/videos/play/wwdc2022/110403
//  Path to ODR Assets: https://stackoverflow.com/questions/33824601/how-to-detect-where-the-on-demand-resources-are-located-after-being-downloaded/48327239#48327239
//  Catch NSErrors: https://stackoverflow.com/questions/32758811/catching-nsexception-in-swift


import Foundation
import LogManager
import SwiftletUtilities

/// Handles downloading the requested resources from the cloud for the given tag and informing the caller of the success or failure of the download.
open class ODRRequest {
    // MARK: - Type Alias
    // Handler for the resource loading successfully.
    public typealias successHandler = () -> Void
    
    // Handler for the resource failing to load.
    public typealias failureHandler = (String) -> Void
    
    // MARK: - Enumerations
    /// Provides the status of a resource request being managed by a `ODRRequest` instance.
    public enum RequestStatus {
        /// The resource has been queued, but hasn't started loading yet.
        case notLoaded
        
        /// The resource has started loading.
        case loading
        
        /// The resource has finished loading and is available for use.
        case loaded
        
        /// The resource has failed to load. Check the `error` property of the `ODRRequest` instance for the failure reason.
        case failed
        
        /// The resource is in the process of being released.
        case released
    }
    
    // MARK: - Properties
    /// Holds the `NSBundleResourceRequest` used to load the requested resource and keep it in scope while it is in use.
    public var request:NSBundleResourceRequest? = nil
    
    /// The unique identifier for this requestor.
    public var id:String = ""
    
    /// Holds the tag that was loaded by this request.
    private var requestedTag:String = ""
    
    /// Holds that state of the request.
    public var status:RequestStatus = .notLoaded
    
    /// Holds any error message if the requested resource could not be loaded.
    public var error:String = ""
    
    /// Returns the tag that was loaded by this request.
    public var tag:String {
        return requestedTag
    }
    
    // MARK: - Initializers
    /// Creates a new instance of the `ODRRequest`object with the given parameters.
    /// - Parameters:
    ///   - tag: The tag of the resource to load.
    ///   - request: The `NSBundleResourceRequest` object to handle the actual request.
    public init(tag:String, request:NSBundleResourceRequest) {
        self.requestedTag = tag
        self.request = request
    }
    
    // MARK: - Functions
    /// Attemps to load the resources for the given tag and informs the caller of the success or failure of the download.
    /// - Parameters:
    ///   - onSuccess: The handler called if the resource is successfully loaded.
    ///   - onFailure: The handler called if the resource fails to load.
    public func requestResource(onSuccess:@escaping successHandler, onFailure:@escaping failureHandler) {
        
        // Ensure we can reques the resource
        guard let request else {
            onFailure("Unable to request resource for tag: \(tag)")
            OnDemandResources.lastResourceLoadError = "Unable to request resource for tag: \(tag)"
            return
        }
        
        // Take action based on the requestor's status
        switch status {
        case .loaded:
            // This resource was previously loaded.
            Execute.onMain {
                onSuccess()
            }
            return
        case .loading:
            // Still loading this resource, do nothing.
            return
        case .failed:
            // Failed to load resource
            Execute.onMain {
                onFailure(self.error)
            }
            return
        case .released:
            // This resource is being released, do nothing.
            return
        default:
            break;
        }
        
        // Attempt to load the resource from the cloud
        status = .loading
        request.beginAccessingResources() { rawError in
            // Was there an issue loading the resource?
            if let error = rawError as? NSError {
                self.status = .failed
                
                // Decode the error message.
                switch error.code {
                case NSBundleOnDemandResourceOutOfSpaceError:
                    self.error = "You don't have enough space available to download the resource for tag (\(self.tag))."
                case NSBundleOnDemandResourceExceededMaximumSizeError:
                    self.error = "The bundle resource for tag (\(self.tag)) was too big."
                case NSBundleOnDemandResourceInvalidTagError:
                    self.error = "The requested tag (\(self.tag)) does not exist."
                default:
                    self.error = "Unknown Error (\(self.tag)): \(error.description)"
                }
                
                // Inform caller of error
                Execute.onMain {
                    Log.error(subsystem: "ODRRequest", category: "requestResource", "\(self.tag) Failure: \(self.error)")
                    OnDemandResources.lastResourceLoadError = self.error
                    onFailure(self.error)
                }
            } else if let error = rawError {
                // A generic error has occurred.
                self.error = "\(error)"
                Log.error(subsystem: "ODRRequest", category: "requestResource", "\(self.tag) Failure: \(self.error)")
                OnDemandResources.lastResourceLoadError = self.error
                self.status = .failed
                
                // Inform caller of error
                Execute.onMain {
                    onFailure(self.error)
                }
            } else {
                self.error = ""
                self.status = .loaded
                
                // Inform the caller that the resource loaded successfully.
                Execute.onMain {
                    // Inform caller of successful load
                    onSuccess()
                }
            }
        }
    }
    
    /// Inform the operating system that the resource can be unloaded as needed.
    public func releaseResource() {
        self.status = .released
        if let request {
            Log.info(subsystem: "ODRRequest", category: "releaseResource", "Releasing Resource: \(tag)")
            request.endAccessingResources()
        }
        requestedTag = ""
        request = nil
        error = ""
    }
}
