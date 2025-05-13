//
//  ODRManager.swift
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

/// Class to handle loading and releasing On Demand Resources for a Swift app.
open class ODRManager {
    // MARK: - Type Alias
    /// Handler for starting to load a resource.
    public typealias loadingHandler = () -> Void
    
    // MARK: - Shared Properties
    /// A common, shared instance of the `ODRManager`.
    public nonisolated(unsafe) static let shared:ODRManager = ODRManager()
    
    // MARK: - Properties
    /// Holds the list of requested resources for the app.
    public var requests:[ODRRequest] = []
    
    // MARK: Functions
    /// Checks to see if the requested resource for the give tag has been loaded and starts to load the resource if it is not already available.
    /// - Parameters:
    ///   - tag: The tag to load resources for.
    ///   - onLoadingResource: A handler that gets called if the requested resource needs to be loaded from the cloud.
    ///   - onSuccess: A handler that gets called when the resource already exists or after it has successfully finished loading.
    ///   - onFailure: A handler that is called if the resouce fails to load.
    ///   - shouldReload: If `true`, the resource should always be reloaded when requested. If `false`, the system will check to see if the resouce has cached and will gain a lock on the cache.
    public func requestResourceWith(tag:String, onLoadingResource:@escaping loadingHandler, onSuccess:@escaping ODRRequest.successHandler, onFailure:@escaping ODRRequest.failureHandler, shouldReload:Bool = true) {
        
        // Capture callback handlers
        nonisolated(unsafe) let onLoadingResource = onLoadingResource
        nonisolated(unsafe) let onSuccess = onSuccess
        nonisolated(unsafe) let onFailure = onFailure
        
        // Has a tag been requested?
        guard tag != "" else {
            // No tag, signal success
            Execute.onMain {
                onSuccess()
            }
            return
        }
        
        // Create a unique id for a new requestor
        let id = UUID().uuidString
        
        // Get a new or existing requestor for this tag
        let requestor = requestorForTag(tag: tag, id: id)
        
        // Take action based on the requestor's status
        switch requestor.status {
        case .loading:
            // The resource is currently loading, inform the caller.
            Execute.onMain {
                onLoadingResource()
            }
        case .loaded:
            // The resource was previously loaded.
            Execute.onMain {
                onSuccess()
            }
            return
        case .failed:
            // The resource had previously failed to load
            Execute.onMain {
                onFailure(requestor.error)
            }
            return
        case .released:
            // This resource is being released, do nothing.
            return
        default:
            // Has this resource already been requested?
            if requestor.id != id {
                // Yes, don't make another request for this resource
                return
            }
        }
        
        // Ensure that the requestor exists.
        guard let request = requestor.request else {
            Execute.onMain {
                onFailure("Unable to request resource for tag: \(tag)")
                OnDemandResources.lastResourceLoadError = "Unable to request resource for tag: \(tag)"
            }
            return
        }
        
        // Should the resouce be reloaded?
        if shouldReload {
            // Inform caller of start
            Execute.onMain {
                onLoadingResource()
                
                // Begin attempting to load resource
                request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                requestor.requestResource(onSuccess: onSuccess, onFailure: onFailure)
            }
        } else {
            // Check to see if the resource has already been loaded.
            request.conditionallyBeginAccessingResources() { isLoaded in
                if isLoaded {
                    // The resource was previously loaded.
                    Execute.onMain {
                        onSuccess()
                    }
                } else {
                    // Inform caller of start
                    Execute.onMain { [request, requestor] in
                        onLoadingResource()
                        
                        // Begin attempting to load resource
                        request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                        requestor.requestResource(onSuccess: onSuccess, onFailure: onFailure)
                    }
                }
            }
        }
    }
    
    /// Returns an existing requestor for the given resource tag or creates a new one as needed. The requestor contains an embedded `NSBundleResourceRequest` that is used to load and retain the resources.
    /// - Parameter tag: The tag the requestor is handling resources for.
    /// - Parameter id: If a new requestor is created, it will have this unique ID.
    /// - Returns: Either an existing `ODRRequest` or a new `ODRRequest` for the given tag.
    public func requestorForTag(tag:String, id:String) -> ODRRequest {
        // Do we already have a request for this resource?
        for request in requests {
            if request.tag == tag {
                return request
            }
        }
        
        // Ensure we can make the request
        guard let resourceRequest = OnDemandResources.onRequestResourceFromBundle else {
            Log.error(subsystem: "ODRManager", category: "requestorForTag", "ERROR: Required `OnDemandResources.onRequestResourceFromBundle` has not been defined. Ignoring NSBundleResourceRequest.")
            return ODRRequest(tag: tag, request: NSBundleResourceRequest(tags: [tag]))
        }
        
        // Create a new requestor
        let request = resourceRequest(tag) //NSBundleResourceRequest(tags: [tag])
        let requestor = ODRRequest(tag: tag, request: request)
        requestor.id = id
        
        // Add to collection
        requests.append(requestor)
        
        // Return the new requestor
        return requestor
    }
    
    /// Returns the requestor matching othe tag being requested.
    /// - Parameter tag: The desired ODR tag.
    /// - Returns: Either returns the `ODRRequestor` matching the tag or returns `nil` if not found.
    public func findRequestor(for tag:String) -> ODRRequest? {
        // Do we already have a request for this resource?
        for request in requests {
            if request.tag == tag {
                return request
            }
        }
        
        return nil
    }
    
    /// Allows the app to prefecth a resource that will be needed soon, this allows the user to continue in the app without delays, since the content should already be loaded in the background before it is needed.
    /// - Parameters:
    ///   - tag: The tag for the resource to prefetch.
    ///   - shouldReload: If `true`, the resource should always be reloaded when requested. If `false`, the system will check to see if the resouce has cached and will gain a lock on the cache.
    public func prefetchResourceWith(tag:String, shouldReload:Bool = true) {
        if tag.contains(",") {
            let tags = tag.components(separatedBy: ",")
            for item in tags {
                prefetchResourcehandler(tag: item, shouldReload: shouldReload)
            }
        } else {
            prefetchResourcehandler(tag: tag, shouldReload: shouldReload)
        }
    }
    
    /// Allows the app to prefecth a resource that will be needed soon, this allows the user to continue in the app without delays, since the content should already be loaded in the background before it is needed.
    /// - Parameters:
    ///   - tag: The tag for the resource to prefetch.
    ///   - shouldReload: If `true`, the resource should always be reloaded when requested. If `false`, the system will check to see if the resouce has cached and will gain a lock on the cache.
    private func prefetchResourcehandler(tag:String, shouldReload:Bool = true) {
        // Has a tag been specified?
        guard tag != "" else {
            return
        }
        
        // Create a unique id for a new requestor
        let id = UUID().uuidString
        
        // Get the requestor for this tag
        let requestor = requestorForTag(tag: tag, id: id)
        
        // Ensure that the requestor exists.
        guard let request = requestor.request else {
            return
        }
        
        // Take action based on the requestor's status
        switch requestor.status {
        case .loading, .loaded, .failed:
            // The resource has already been handled.
            return
        default:
            // Has this resource already been requested?
            if requestor.id != id {
                // Yes, don't make another request for this resource
                return
            }
        }
        
        // Reload the resource?
        if shouldReload {
            // Set to a lower load priority.
            request.loadingPriority = 0.5
            
            // Ask the system to load the requested resource.
            requestor.requestResource(onSuccess: {
                requestor.status = .loaded
                //Debug.info(subsystem: "ODRManager", category: "prefetchResourceHandler", ">> Prefetch: \(tag)")
            }, onFailure: {error in
                requestor.status = .failed
                Log.error(subsystem: "ODRManager", category: "prefetchResourceHandler", "Prefetch \(tag) Failed: \(requestor.error)")
                OnDemandResources.lastResourceLoadError = requestor.error
            })
        } else {
            // Check to see if the resource has already been loaded.
            request.conditionallyBeginAccessingResources() { [requestor] isLoaded in
                if isLoaded {
                    requestor.status = .loaded
                } else {
                    // Set to a lower load priority.
                    request.loadingPriority = 0.5
                    
                    // Ask the system to load the requested resource.
                    requestor.requestResource(onSuccess: {[requestor] in
                        requestor.status = .loaded
                    }, onFailure: {[requestor] error in
                        requestor.status = .failed
                        Log.error(subsystem: "ODRManager", category: "prefetchResourceHandler", "Prefetch \(tag) Failed: \(requestor.error)")
                        OnDemandResources.lastResourceLoadError = requestor.error
                    })
                }
            }
        }
        
    }
    
    /// Releases the resouce with the given tag or list of tags separated by a comma.
    /// - Parameter tag: The tag to release resources for.
    public func releaseResourceWith(tag:String) {
        if tag.contains(",") {
            let tags = tag.components(separatedBy: ",")
            for item in tags {
                releaseResourceHandler(tag: item)
            }
        } else {
            releaseResourceHandler(tag: tag)
        }
    }
    
    /// Releases the resouce with the given tag.
    /// - Parameter tag: The tag to release resources for.
    public func releaseResourceHandler(tag:String) {
        
        // Has a tag been specified?
        guard tag != "" else {
            return
        }
        
        // Search all resource requests
        for n in 0...(requests.count - 1) {
            let request = requests[n]
            
            // Has the requested resource been found?
            if request.tag == tag {
                // Yes, release the resource and remove the request from the collection.
                request.releaseResource()
                requests.remove(at: n)
                return
            }
        }
    }
    
    /// Releases all resources that have been loaded for the app.
    public func releaseAllResources() {
        
        for request in requests {
            request.releaseResource()
        }
        
        requests.removeAll()
    }
    
    public func releaseFailedResourceLoads() {
        
        for requestor in requests {
            if requestor.status == .failed {
                // Release
                requestor.releaseResource()
            }
        }
    }
}
