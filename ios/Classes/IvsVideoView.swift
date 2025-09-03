import Flutter
import UIKit
import AmazonIVSBroadcast

class IvsVideoViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return IvsVideoView(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class IvsVideoView: NSObject, FlutterPlatformView {
    private var _view: UIView
    private var participantId: String?
    private var isLocal: Bool = false

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger messenger: FlutterBinaryMessenger?) {
        _view = UIView()
        super.init()
        createNativeView(view: _view)
        
        // Parse arguments
        if let arguments = args as? [String: Any] {
            participantId = arguments["participantId"] as? String
            isLocal = arguments["isLocal"] as? Bool ?? false
        }
        print("Ivsstage: Participant: \(String(describing: participantId)), Local: \(isLocal)")
        
        // Register this view with the stage manager
        registerWithStageManager()
    }

    func view() -> UIView {
        return _view
    }

    func createNativeView(view: UIView) {
        view.backgroundColor = UIColor.yellow
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
    }
    
    private func registerWithStageManager() {
        guard let stageManager = FlutterIvsStagePlugin.shared?.stageManager else { return }
        
        if isLocal {
            print("Ivsstage: Registering local video view")
            // For local participant, set up camera preview
            stageManager.setLocalVideoView(_view)
        } else if let participantId = participantId {
            print("Ivsstage: Registering remote video view for participant: \(participantId)")
            // For remote participants, register this view for the participant
            stageManager.setVideoView(_view, for: participantId)
        }
    }
    
    deinit {
        // Clean up registration
        if let stageManager = FlutterIvsStagePlugin.shared?.stageManager {
            if isLocal {
                stageManager.removeLocalVideoView()
            } else if let participantId = participantId {
                stageManager.removeVideoView(for: participantId)
            }
        }
    }
}
