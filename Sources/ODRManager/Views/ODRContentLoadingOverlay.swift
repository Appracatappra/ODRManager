//
//  ODRContentLoadingOverlay.swift
//  ReedWriteCycle (iOS)
//
//  Created by Kevin Mullins on 11/21/22.
//

import SwiftUI
import LogManager
import SwiftletUtilities
import SwiftUIKit
import SwiftUIGamepad

/// A SwiftUI `View` that displays a standardized On Demand Content Loading Overlay. The overlay has built in support for gamepads using the `SwiftUIGamepad` package.
public struct ODRContentLoadingOverlay: View {
    /// A handler for any On Demand Resource loading events.
    public typealias ResourceLoadEvent = () -> Void
    
    // MARK: - Properties
    /// The name of the app loading the On Demand Resources.
    public var appName:String = OnDemandResources.appName
    
    /// The resuested On Demand Resource Tag.
    public var resourceTag:String = OnDemandResources.loadResourceTag
    
    /// The default font color for `ODRManager` UI elements.
    public var fontColor:Color = OnDemandResources.fontColor
    
    /// The default button background color for `ODRManager` UI elements.
    public var buttonBackgroundColor:Color = OnDemandResources.buttonBackgroundColor
    
    /// The default loading background image for `ODRManager` UI elements.
    public var loadingBackgroundImage:String = OnDemandResources.loadingBackgroundImage
    
    /// The default loading failed background image for `ODRManager` UI elements.
    public var loadingFailedBackgroundImage:String = OnDemandResources.loadingFailedBackgroundImage
    
    /// Handler that will be called if the resource is successfully loaded.
    public var onLoadedSuccessfully:ResourceLoadEvent? = nil
    
    /// Handler that will be called if the user wants to cancel the On Demand Resource load.
    public var onCancelDownload:ResourceLoadEvent? = nil
    
    // MARK: - State Management
    /// If `true` a gamepad is connected to the device the app is running on.
    @State var isGamepadConnected:Bool = false
    
    /// The On Demand Resource `ODRRequest` handling the current request.
    @State var requestor:ODRRequest? = nil
    
    /// A timer that handles updating the download progress percent.
    @State var timer:Timer? = nil
    
    /// The current percent of downloading completed.
    @State var percentComplete:Double = 0
    
    /// Tracks changes in the manga page orientation.
    @State private var screenOrientation:UIDeviceOrientation = HardwareInformation.deviceOrientation
    
    // MARK: - Computed Properties
    /// The width of the displayed text.
    private var textWidth:CGFloat {
        return CGFloat(HardwareInformation.screenWidth) - 100.0
    }
    
    /// The size to scale the Gamepad Quick Tip buttons to.
    private var controlButtonScale:Float {
        #if os(tvOS)
        return 0.25
        #else
        if HardwareInformation.isPhone {
            return 0.15
        } else if HardwareInformation.isPad {
            switch HardwareInformation.deviceOrientation {
            case .landscapeLeft, .landscapeRight:
                return 0.18
            default:
                return 0.25
            }
        } else {
            return 0.25
        }
        #endif
    }
    
    // MARK: Initializers
    /// Create a new instance
    /// - Parameters:
    ///   - appName: The name of the app loading the On Demand Resources.
    ///   - resourceTag: The resuested On Demand Resource Tag.
    ///   - fontColor: The default font color for `ODRManager` UI elements.
    ///   - buttonBackgroundColor: The default button background color for `ODRManager` UI elements.
    ///   - loadingBackgroundImage: The default loading background image for `ODRManager` UI elements.
    ///   - loadingFailedBackgroundImage: The default loading failed background image for `ODRManager` UI elements.
    ///   - onLoadedSuccessfully: Handler that will be called if the resource is successfully loaded.
    ///   - onCancelDownload: Handler that will be called if the user wants to cancel the On Demand Resource load.
    public init(appName: String = OnDemandResources.appName, resourceTag: String = OnDemandResources.loadResourceTag, fontColor: Color = OnDemandResources.fontColor, buttonBackgroundColor: Color = OnDemandResources.buttonBackgroundColor, loadingBackgroundImage: String = OnDemandResources.loadingBackgroundImage, loadingFailedBackgroundImage: String = OnDemandResources.loadingFailedBackgroundImage, onLoadedSuccessfully: ResourceLoadEvent? = nil, onCancelDownload: ResourceLoadEvent? = nil) {
        
        self.appName = appName
        self.resourceTag = resourceTag
        self.fontColor = fontColor
        self.buttonBackgroundColor = buttonBackgroundColor
        self.loadingBackgroundImage = loadingBackgroundImage
        self.loadingFailedBackgroundImage = loadingFailedBackgroundImage
        self.onLoadedSuccessfully = onLoadedSuccessfully
        self.onCancelDownload = onCancelDownload
    }
    
    // MARK: - Computed Properties
    /// Gets the background color based on the loading state.
    private var backgroundColor:Color {
        if OnDemandResources.lastResourceLoadError == "" {
            return OnDemandResources.loadingBackgroundColor
        } else {
            return OnDemandResources.loadingFailedBackgroundColor
        }
    }
    
    // MARK: - Control Body
    /// The body of the control.
    public var body: some View {
        content(screenOrientation: screenOrientation)
        .onAppear {
            connectGamepad(viewID: "ODROverlay", handler: { controller, gamepadInfo in
                isGamepadConnected = true
                buttonMenuUsage(viewID: "ODROverlay", "Return to the **Cover Page Menu**.")
                buttonAUsage(viewID: "ODROverlay", "Show or hide **Gamepad Help**.")
            })
            
            // Find the requestor for the content being loaded.
            requestor = ODRManager.shared.findRequestor(for: resourceTag)
            
            // Create a timer to update the percentage loaded.
            timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                if let requestor {
                    Execute.onMain {
                        // Update the percent completed loading
                        percentComplete = requestor.request?.progress.fractionCompleted ?? 0.0
                        
                        // Check for content getting stuck at 100%
                        if Int(percentComplete * 100.0) == 100 {
                            // Assume the data has fully completed and inform caller
                            if let onLoadedSuccessfully {
                                onLoadedSuccessfully()
                            }
                        }
                    }
                }
            }
        }
        .onRotate {orientation in
            screenOrientation = orientation
        }
        .onDisappear {
            // Release the timer
            if let timer {
                timer.invalidate()
            }
            
            // Release the connection to the gamepad.
            disconnectGamepad(viewID: "ODROverlay")
        }
        .onGampadAppBecomingActive(viewID: "ODROverlay") {
            reconnectGamepad()
        }
        .onGamepadDisconnected(viewID: "ODROverlay") { controller, gamepadInfo in
            isGamepadConnected = false
        }
        .onGamepadLeftTrigger(viewID: "ODROverlay") { isPressed, pressure in
            if isPressed {
                requestCancelDownload()
            }
        }
    }
    
    // MARK: - Functions
    /// Handle the user requesting to cancel the download.
    private func requestCancelDownload() {
        if let onCancelDownload {
            onCancelDownload()
        }
    }
    
    /// Generates the main contents of the overlay.
    /// - Returns: The main contents of the overlay.
    @ViewBuilder private func content(screenOrientation:UIDeviceOrientation) -> some View {
        ZStack {
            if OnDemandResources.lastResourceLoadError == "" {
                // Display background based on settings
                if OnDemandResources.imageLocation == .appBundle {
                    Image(loadingBackgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: CGFloat(HardwareInformation.screenWidth), height: CGFloat(HardwareInformation.screenHeight))
                } else {
                    let url = SwiftUIGamepad.urlTo(resource: loadingBackgroundImage, withExtension: "png")
                    ScaledImageView(imageURL: url, scale: 1.0, ignoreSafeArea: true)
                }
                
                VStack {
                    Spacer()
                    
                    Text("Waiting For Additional App Content")
                        .font(.title2)
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.vertical)
                    
                    Text("\(appName) needs to load addition content (\(resourceTag)) from the cloud to continue running the next section.")
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.bottom)
                    
                    Text("Please ensure that you have networking enabled and that your device is connected to the internet.")
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.bottom)
                    
                    Text("It can take a few moments the content to load, so please standby...")
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.bottom)
                    
                    Spacer()
                    
                    Group {
                        ScaleableWaitingIndicator()
                            .frame(width: 100, height: 100)
                            .padding(.bottom)
                        
                        ProgressView(value: percentComplete) {
                            Text("\(Int(percentComplete * 100.0))% progress")
                                .foregroundColor(fontColor)
                        }
                        .frame(width: textWidth)
                        .padding([.leading, .bottom, .trailing])
                    }
                    
                    Spacer()
                        
                    
                    if isGamepadConnected {
                        GamepadControlTip(iconName: GamepadManager.gamepadOne.gampadInfo.leftTriggerImage, title: "Cancel Download", scale: controlButtonScale, enabledColor: fontColor)
                            .padding(.bottom)
                    } else {
                        IconButton(icon: "x.circle.fill", text: "Cancel Download", backgroundColor: buttonBackgroundColor) {
                            Execute.onMain {
                                requestCancelDownload()
                            }
                        }
                        .padding(.bottom)
                    }
                    
                    Spacer()
                }
            } else {
                // Display background based on settings
                if OnDemandResources.imageLocation == .appBundle {
                    Image(loadingFailedBackgroundImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: CGFloat(HardwareInformation.screenWidth), height: CGFloat(HardwareInformation.screenHeight))
                } else {
                    let url = SwiftUIGamepad.urlTo(resource: loadingFailedBackgroundImage, withExtension: "png")
                    ScaledImageView(imageURL: url, scale: 1.0, ignoreSafeArea: true)
                }
                
                VStack {
                    Spacer()
                    
                    Text("Unable to Load Additional Game Content: \(resourceTag)")
                        .font(.title2)
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.vertical)
                    
                    Text("\(appName) was unable to load the addition content from the cloud required to continue running the next section.")
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.bottom)
                    
                    if NetworkConnection.isConnectedToNetwork() {
                        Text("Error: \(OnDemandResources.lastResourceLoadError)")
                            .fontWeight(.bold)
                            .foregroundColor(fontColor)
                            .multilineTextAlignment(.center)
                            .frame(width: textWidth)
                            .padding(.bottom)
                    } else {
                        Text("\(appName) is unable to find an active network. Please check your device settings before continuing.")
                            .font(.title2)
                            .foregroundColor(fontColor)
                            .multilineTextAlignment(.center)
                            .frame(width: textWidth)
                            .padding(.bottom)
                    }
                    
                    Text("Please ensure that you have an active network connection and your device is connected to the internet.")
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.bottom)
                    
                    Text("Please **Cancel** the download and try again.")
                        .foregroundColor(fontColor)
                        .multilineTextAlignment(.center)
                        .frame(width: textWidth)
                        .padding(.bottom)
                    
                    Spacer()
                    
                    if isGamepadConnected {
                        GamepadControlTip(iconName: GamepadManager.gamepadOne.gampadInfo.leftTriggerImage, title: "OK", scale: controlButtonScale, enabledColor: fontColor)
                            .padding(.bottom)
                    } else {
                        IconButton(icon: "x.circle.fill", text: "OK", backgroundColor: buttonBackgroundColor) {
                            Execute.onMain {
                                requestCancelDownload()
                            }
                        }
                        .padding(.bottom)
                    }
                    
                    Spacer()
                }
            }
        }
        .background(backgroundColor)
        .frame(width: CGFloat(HardwareInformation.screenWidth), height: CGFloat(HardwareInformation.screenHeight))
        .ignoresSafeArea()
    }
}

#Preview("Loading") {
    ODRContentLoadingOverlay(resourceTag: "Unknown")
}
