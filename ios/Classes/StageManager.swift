import Foundation
import AmazonIVSBroadcast
import UIKit

protocol StageManagerDelegate: AnyObject {
    func stageManager(_ manager: StageManager, didUpdateParticipants participants: [ParticipantData])
    func stageManager(_ manager: StageManager, didChangeConnectionState state: IVSStageConnectionState)
    func stageManager(_ manager: StageManager, didChangeLocalAudioMuted muted: Bool)
    func stageManager(_ manager: StageManager, didChangeLocalVideoMuted muted: Bool)
    func stageManager(_ manager: StageManager, didChangeBroadcasting broadcasting: Bool)
    func stageManager(_ manager: StageManager, didEncounterError error: Error, source: String?)
}

class StageManager: NSObject {
    
    weak var delegate: StageManagerDelegate?
    
    // MARK: - Video Views
    
    private var videoViews: [String: UIView] = [:]
    private var localVideoView: UIView?
    private var aspectMode: String?
    
    // Video mirroring settings
    private var shouldMirrorLocalVideo: Bool = false
    private var shouldMirrorRemoteVideo: Bool = false
    
    // MARK: - Internal State
    
    private let broadcastConfig = IVSPresets.configurations().standardPortrait()
    private let camera: IVSCamera?
    private let microphone: IVSMicrophone?
    private var currentAuthItem: AuthItem?
    
    private var stage: IVSStage?
    private var localUserWantsPublish: Bool = true
    
    private var isVideoMuted = false {
        didSet {
            validateVideoMuteSetting()
            notifyParticipantsUpdate()
        }
    }
    private var isAudioMuted = false {
        didSet {
            validateAudioMuteSetting()
            notifyParticipantsUpdate()
        }
    }
    
    private var localStreams: [IVSLocalStageStream] {
        set {
            participantsData[0].streams = newValue
            updateBroadcastBindings()
            validateVideoMuteSetting()
            validateAudioMuteSetting() 
        }
        get {
            return participantsData[0].streams as? [IVSLocalStageStream] ?? []
        }
    }
    
    private var broadcastSession: IVSBroadcastSession?
    
    private var broadcastSlots: [IVSMixerSlotConfiguration] = [] {
        didSet {
            guard let broadcastSession = broadcastSession else { return }
            let oldSlots = broadcastSession.mixer.slots()
            
            // Removing old slots
            oldSlots.forEach { oldSlot in
                if !broadcastSlots.contains(where: { $0.name == oldSlot.name }) {
                    broadcastSession.mixer.removeSlot(withName: oldSlot.name)
                }
            }
            
            // Adding new slots
            broadcastSlots.forEach { newSlot in
                if !oldSlots.contains(where: { $0.name == newSlot.name }) {
                    broadcastSession.mixer.addSlot(newSlot)
                }
            }
            
            // Update existing slots
            broadcastSlots.forEach { newSlot in
                if oldSlots.contains(where: { $0.name == newSlot.name }) {
                    broadcastSession.mixer.transitionSlot(withName: newSlot.name, toState: newSlot, duration: 0.3)
                }
            }
        }
    }
    
    private var participantsData: [ParticipantData] = [ParticipantData(isLocal: true, participantId: nil)] {
        didSet {
            updateBroadcastSlots()
            notifyParticipantsUpdate()
        }
    }
    
    private var stageConnectionState: IVSStageConnectionState = .disconnected {
        didSet {
            delegate?.stageManager(self, didChangeConnectionState: stageConnectionState)
        }
    }
    
    private var isBroadcasting: Bool = false {
        didSet {
            delegate?.stageManager(self, didChangeBroadcasting: isBroadcasting)
        }
    }
    
    // MARK: - Lifecycle
    
    override init() {
        // Setup default camera and microphone devices
        let devices = IVSDeviceDiscovery().listLocalDevices()
        camera = devices.compactMap({ $0 as? IVSCamera }).first
        microphone = devices.compactMap({ $0 as? IVSMicrophone }).first
        
        // Use `IVSStageAudioManager` to control the underlying AVAudioSession instance
        IVSStageAudioManager.sharedInstance().setPreset(.videoChat)
        IVSStageAudioManager.sharedInstance().isEchoCancellationEnabled = false
        super.init()
        
        camera?.errorDelegate = self
        microphone?.errorDelegate = self
        setupLocalUser()
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    private func setupLocalUser() {
        if let camera = camera {
            // Find front camera input source and set it as preferred camera input source
            if let frontSource = camera.listAvailableInputSources().first(where: { $0.position == .front }) {
                camera.setPreferredInputSource(frontSource) { [weak self] in
                    if let error = $0 {
                        self?.displayErrorAlert(error, logSource: "setupLocalUser")
                    }
                }
            }
            let config = IVSLocalStageStreamConfiguration()
            config.audio.enableNoiseSuppression = false
            // Add stream with local image device to localStreams
            var currentStreams = localStreams
            currentStreams.append(IVSLocalStageStream(device: camera, config: config))
            localStreams = currentStreams
        }
        
        if let microphone = microphone {
            // Add stream with local audio device to localStreams
            var currentStreams = localStreams
            currentStreams.append(IVSLocalStageStream(device: microphone))
            localStreams = currentStreams
        }
        
        // Notify UI updates
        notifyParticipantsUpdate()
        
        // Ensure local video preview is set up now that streams are created
        setupLocalVideoPreview()
    }
    
    /// Ensure local streams exist (used for preview functionality)
    private func ensureLocalStreamsExist() {
        print("Ivsstage: ensureLocalStreamsExist - current streams count: \(localStreams.count)")
        
        // Check if camera stream already exists
        let hasCameraStream = localStreams.contains { $0.device is IVSImageDevice }
        let hasAudioStream = localStreams.contains { $0.device is IVSAudioDevice }
        
        if !hasCameraStream, let camera = camera {
            print("Ivsstage: ensureLocalStreamsExist - creating camera stream")
            let config = IVSLocalStageStreamConfiguration()
            config.audio.enableNoiseSuppression = false
            var currentStreams = localStreams
            currentStreams.append(IVSLocalStageStream(device: camera, config: config))
            localStreams = currentStreams
        }
        
        if !hasAudioStream, let microphone = microphone {
            print("Ivsstage: ensureLocalStreamsExist - creating audio stream")
            var currentStreams = localStreams
            currentStreams.append(IVSLocalStageStream(device: microphone))
            localStreams = currentStreams
        }
        
        // Notify UI updates if streams were added
        if !hasCameraStream || !hasAudioStream {
            notifyParticipantsUpdate()
        }
        
        print("Ivsstage: ensureLocalStreamsExist - final streams count: \(localStreams.count)")
    }
    
    @objc
    private func applicationDidEnterBackground() {
        print("app did enter background")
        let stageState = stageConnectionState
        let connectingOrConnected = (stageState == .connecting) || (stageState == .connected)
        
        if connectingOrConnected {
            // Stop publishing when entering background
            localUserWantsPublish = false
            
            // Switch other participants to audio only subscribe
            participantsData
                .compactMap { $0.participantId }
                .forEach {
                    mutatingParticipant($0) { data in
                        data.requiresAudioOnly = true
                    }
                }
            
            stage?.refreshStrategy()
        }
    }
    
    @objc
    private func applicationWillEnterForeground() {
        print("app did resume foreground")
        // Resume publishing when entering foreground
        localUserWantsPublish = true
        
        // Resume other participants from audio only subscribe
        if !participantsData.isEmpty {
            participantsData
                .compactMap { $0.participantId }
                .forEach {
                    mutatingParticipant($0) { data in
                        data.requiresAudioOnly = false
                    }
                }
            
            stage?.refreshStrategy()
        }
    }
    
    // MARK: - Public Methods
    
    func joinStage(token: String, completion: @escaping (Error?) -> Void) {
        UserDefaults.standard.set(token, forKey: "joinToken")
        
        do {
            self.stage = nil
            let stage = try IVSStage(token: token, strategy: self)
            stage.addRenderer(self)
            try stage.join()
            self.stage = stage
            completion(nil)
        } catch {
            displayErrorAlert(error, logSource: "JoinStageSession")
            completion(error)
        }
    }
    
    func leaveStage() {
        print("Ivsstage: Leaving stage")
        stage?.leave()
        stage = nil 
        
        // Clear participants
        participantsData.removeAll()
        
        // Clear all video views
        for (_, view) in videoViews {
            view.removeFromSuperview()
        }
        videoViews.removeAll()
        
        // Remove local video view
        localVideoView?.removeFromSuperview()
        localVideoView = nil
        
        // Clear streams
        localStreams.removeAll()
        
        // Dispose all devices
        disposeDevices()
        
        delegate?.stageManager(self, didUpdateParticipants: [])
        delegate?.stageManager(self, didChangeConnectionState: .disconnected)
        
        print("Ivsstage: Stage left and all devices disposed")
    }
    
    
    private func disposeDevices() {
        print("Ivsstage: Disposing camera and microphone devices")
        
        // Stop camera capture
        if let camera = camera {
            camera.delegate = nil
        }
        
        // Stop microphone capture
        if let microphone = microphone {
            microphone.delegate = nil
        }
    }
    
    
    func toggleLocalVideoMute() {
        isVideoMuted.toggle()
    }
    
    private func validateVideoMuteSetting() {
        localStreams
            .filter { $0.device is IVSImageDevice }
            .forEach {
                $0.setMuted(isVideoMuted)
                delegate?.stageManager(self, didChangeLocalVideoMuted: isVideoMuted)
            }
    }
    
    func toggleLocalAudioMute() {
        isAudioMuted.toggle()
    }
    
    private func validateAudioMuteSetting() {
        localStreams
            .filter { $0.device is IVSAudioDevice }
            .forEach {
                $0.setMuted(isAudioMuted)
                delegate?.stageManager(self, didChangeLocalAudioMuted: isAudioMuted)
            }
    }
    
    func toggleAudioOnlySubscribe(forParticipant participantId: String) {
        mutatingParticipant(participantId) {
            $0.wantsAudioOnly.toggle()
        }
        
        stage?.refreshStrategy()
    }
    
    // MARK: - Video View Management
    
    func setLocalVideoView(_ view: UIView) {
        print("Ivsstage: Registering local video view - current localVideoView: \(localVideoView != nil ? "exists" : "nil")")
        localVideoView = view
        print("Ivsstage: Local video view registered successfully")
        // Don't set up preview immediately - wait for streams to be created
         setupLocalVideoPreview()
    }
    
    func setVideoView(_ view: UIView, for participantId: String) {
        print("Ivsstage: Registering video view for participant: \(participantId)")
        videoViews[participantId] = view
        print("Ivsstage: Video view registered. Total views: \(videoViews.count)")
        // Set up video stream if participant has video streams
        setupVideoStream(for: participantId)
    }
    
    func removeVideoView(for participantId: String) {
        if let view = videoViews[participantId] {
            // Clean up any video streams attached to this view
            cleanupVideoStream(for: participantId, view: view)
            videoViews.removeValue(forKey: participantId)
        }
    }
    
    func removeLocalVideoView() {
        print("Ivsstage: removeLocalVideoView called - current localVideoView: \(localVideoView != nil ? "exists" : "nil")")
        if let view = localVideoView {
            // Clean up local video preview
            cleanupLocalVideoPreview(view: view)
            localVideoView = nil
            print("Ivsstage: Local video view removed and cleaned up")
        } else {
            print("Ivsstage: removeLocalVideoView called but localVideoView was already nil")
        }
    }
    
    func refreshAllVideoPreviews() {
        print("Ivsstage: refreshAllVideoPreviews - refreshing all video views")
        
        // Only refresh local video preview if it's not already working
        if let localView = localVideoView, localView.subviews.isEmpty {
            print("Ivsstage: refreshAllVideoPreviews - refreshing local video preview")
            setupLocalVideoPreview()
        }
        
        // Refresh all participant video streams
        for participantId in videoViews.keys {
            setupVideoStream(for: participantId)
        }
        
        print("Ivsstage: refreshAllVideoPreviews - completed refreshing \(videoViews.count) participant views")
    }
    
    func setVideoMirroring(localVideo: Bool, remoteVideo: Bool) {
        print("Ivsstage: setVideoMirroring - local: \(localVideo), remote: \(remoteVideo)")
        
        shouldMirrorLocalVideo = localVideo
        shouldMirrorRemoteVideo = remoteVideo
        
        // Apply mirroring to existing local video view
        if let localView = localVideoView {
            applyMirroring(to: localView, shouldMirror: shouldMirrorLocalVideo)
        }
        
        // Apply mirroring to existing remote video views
        for (participantId, view) in videoViews {
            applyMirroring(to: view, shouldMirror: shouldMirrorRemoteVideo)
        }
    }
    
    // MARK: - Camera Preview Methods
    
    /// Initialize camera preview before joining stage
    func initPreview(cameraType: String, aspectMode: String, completion: @escaping (Error?) -> Void) {
        print("Ivsstage: initPreview - cameraType: \(cameraType), aspectMode: \(aspectMode)")
        self.aspectMode = aspectMode
        guard let camera = camera else {
            completion(NSError(domain: "IVSStageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"]))
            return
        }
        
        // Ensure local streams are created for preview
        ensureLocalStreamsExist()
        
        // Set camera input source based on type
        setCameraType(cameraType) { [weak self] error in
            if let error = error {
                completion(error)
                return
            }
            
            // Store aspect mode for preview (could be used in UI implementation)
            // For now, we'll always use 'fill' behavior in the preview view constraints
            completion(nil)
        }
    }
    
    /// Toggle camera between front and back
    func toggleCamera(cameraType: String, completion: @escaping (Error?) -> Void) {
        print("Ivsstage: toggleCamera - switching to: \(cameraType)")
        setCameraType(cameraType, completion: completion)
    }
    
    /// Stop camera preview
    func stopPreview() {
        print("Ivsstage: Stopping camera preview")
        
        // Remove local video view
        localVideoView?.removeFromSuperview()
        localVideoView = nil
        
        // Clear local streams properly
        localStreams.removeAll()
        
        // Dispose camera and microphone devices
        disposeDevices()
        
        print("Ivsstage: Camera preview stopped and devices disposed")
    }
    
    
    
    /// Helper method to set camera input source
    private func setCameraType(_ cameraType: String, completion: @escaping (Error?) -> Void) {
        guard let camera = camera else {
            completion(NSError(domain: "IVSStageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Camera not available"]))
            return
        }
        
        let position: IVSDevicePosition = cameraType == "front" ? .front : .back
        
        if let targetSource = camera.listAvailableInputSources().first(where: { $0.position == position }) {
            camera.setPreferredInputSource(targetSource) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("Ivsstage: setCameraType - failed to set camera to \(cameraType): \(error)")
                        completion(error)
                    } else {
                        print("Ivsstage: setCameraType - successfully set camera to \(cameraType)")
                        // Refresh the local video preview if it exists
                        self.refreshLocalVideoPreview()
                        completion(nil)
                    }
                }
            }
        } else {
            let error = NSError(domain: "IVSStageError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Camera type '\(cameraType)' not available"])
            completion(error)
        }
    }
    
    /// Refresh local video preview (useful after camera switching)
    private func refreshLocalVideoPreview() {
        guard let localView = localVideoView else { return }
        
        // Clear existing preview
        localView.subviews.forEach { $0.removeFromSuperview() }
        
        // Setup preview again with new camera
        setupLocalVideoPreview()
    }
    
    private func applyMirroring(to view: UIView, shouldMirror: Bool) {
        if shouldMirror {
            // Apply horizontal mirroring
            view.transform = CGAffineTransform(scaleX: -1, y: 1)
        } else {
            // Remove mirroring
            view.transform = CGAffineTransform.identity
        }
    }
    
    func refreshVideoPreview(for participantId: String) {
        print("Ivsstage: refreshVideoPreview - refreshing video for participant: \(participantId)")
        
        if participantId == participantsData[0].participantId {
            // This is the local participant
            setupLocalVideoPreview()
        } else {
            // This is a remote participant
            setupVideoStream(for: participantId)
        }
        
        print("Ivsstage: refreshVideoPreview - completed refreshing for participant: \(participantId)")
    }
    
    private func setupLocalVideoPreview() {
        guard let localView = localVideoView else { 
            print("Ivsstage: setupLocalVideoPreview - no local view registered")
            return 
        }
        
        // Check if preview is already set up and working
        if !localView.subviews.isEmpty {
            print("Ivsstage: setupLocalVideoPreview - local preview already exists, skipping setup")
            return
        }
        
        let cameraStreams = localStreams.filter { $0.device is IVSImageDevice }
        print("Ivsstage: setupLocalVideoPreview - cameraStreams count: \(cameraStreams.count)")
        
        if let cameraStream = cameraStreams.first,
           let imageDevice = cameraStream.device as? IVSImageDevice {
            print("Ivsstage: setupLocalVideoPreview - setting up camera preview for device: \(imageDevice)")
            
            do {
                let preview = try imageDevice.previewView(
                    with: aspectMode == "fill" ? .fill :  aspectMode == "fit" ? .fit : .none
                )
                print("Ivsstage: setupLocalVideoPreview - created preview view: \(preview)")
                
                // Add the preview view
                preview.translatesAutoresizingMaskIntoConstraints = false
                localView.addSubview(preview)
                localView.backgroundColor = .clear
                
                NSLayoutConstraint.activate([
                    preview.topAnchor.constraint(equalTo: localView.topAnchor),
                    preview.bottomAnchor.constraint(equalTo: localView.bottomAnchor),
                    preview.leadingAnchor.constraint(equalTo: localView.leadingAnchor),
                    preview.trailingAnchor.constraint(equalTo: localView.trailingAnchor),
                ])
                
                // Apply mirroring if enabled
                applyMirroring(to: localView, shouldMirror: shouldMirrorLocalVideo)
                
                print("Ivsstage: setupLocalVideoPreview - successfully set up camera preview")
            } catch {
                print("Ivsstage: setupLocalVideoPreview - failed to create preview view: \(error)")
            }
        } else {
            print("Ivsstage: setupLocalVideoPreview - no camera stream available yet")
        }
    }
    
    private func setupVideoStream(for participantId: String) {
        guard let view = videoViews[participantId] else { 
            print("Ivsstage: setupVideoStream - no view registered for participant: \(participantId)")
            return 
        }
        
        guard let participantData = participantsData.first(where: { $0.participantId == participantId }) else { 
            print("Ivsstage: setupVideoStream - no participant data for: \(participantId)")
            return 
        }
        
        print("Ivsstage: setupVideoStream - setting up video for participant: \(participantId), streams count: \(participantData.streams.count)")
        
        let videoStreams = participantData.streams.filter { $0.device is IVSImageDevice }
        
        guard let videoStream = videoStreams.first,
              let imageDevice = videoStream.device as? IVSImageDevice else {
            print("Ivsstage: setupVideoStream - no video stream found for participant: \(participantId)")
            return
        }
        
        print("Ivsstage: setupVideoStream - found video stream for participant: \(participantId)")
        
        do {
            // Try to create a preview view from the image device
            let preview = try imageDevice.previewView()
            print("Ivsstage: setupVideoStream - created preview view for participant: \(participantId)")
            
            // Remove any existing subviews
            view.subviews.forEach { $0.removeFromSuperview() }
            
            // Add the preview view
            preview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(preview)
            view.backgroundColor = .clear
            
            NSLayoutConstraint.activate([
                preview.topAnchor.constraint(equalTo: view.topAnchor),
                preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                preview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
            
            // Apply mirroring if enabled for remote videos
            applyMirroring(to: view, shouldMirror: shouldMirrorRemoteVideo)
            
            print("Ivsstage: setupVideoStream - successfully set up preview for participant: \(participantId)")
            
        } catch {
            print("Ivsstage: setupVideoStream - failed to create preview for participant \(participantId): \(error)")
            
            // Create a debug view to show what's happening
            view.subviews.forEach { $0.removeFromSuperview() }
            view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
            
            let containerView = UIView()
            containerView.backgroundColor = UIColor.systemGray6
            containerView.layer.cornerRadius = 8
            containerView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(containerView)
            
            let titleLabel = UILabel()
            titleLabel.text = "Remote Participant"
            titleLabel.textColor = .label
            titleLabel.font = UIFont.boldSystemFont(ofSize: 14)
            titleLabel.textAlignment = .center
            titleLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let idLabel = UILabel()
            idLabel.text = participantId
            idLabel.textColor = .secondaryLabel
            idLabel.font = UIFont.systemFont(ofSize: 12)
            idLabel.textAlignment = .center
            idLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let errorLabel = UILabel()
            errorLabel.text = "Error: \(error.localizedDescription)"
            errorLabel.textColor = .systemRed
            errorLabel.font = UIFont.systemFont(ofSize: 10)
            errorLabel.textAlignment = .center
            errorLabel.numberOfLines = 2
            errorLabel.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(titleLabel)
            containerView.addSubview(idLabel)
            containerView.addSubview(errorLabel)
            
            NSLayoutConstraint.activate([
                containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                containerView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -16),
                containerView.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, constant: -16),
                
                titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
                titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                
                idLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
                idLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                idLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                
                errorLabel.topAnchor.constraint(equalTo: idLabel.bottomAnchor, constant: 8),
                errorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                errorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                errorLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            ])
        }
    }
    
    
    private func cleanupVideoStream(for participantId: String, view: UIView) {
        // Remove all subviews (IVSImageView instances)
        view.subviews.forEach { $0.removeFromSuperview() }
    }
    
    private func cleanupLocalVideoPreview(view: UIView) {
        // Remove all subviews (IVSImagePreviewView instances)
        view.subviews.forEach { $0.removeFromSuperview() }
    }
    
    func toggleBroadcasting(completion: @escaping (Error?) -> Void) {
        guard let authItem = currentAuthItem, let endpoint = URL(string: authItem.endpoint) else {
            let error = NSError(domain: "InvalidAuth", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid Endpoint or StreamKey"
            ])
            displayErrorAlert(error, logSource: "toggleBroadcasting")
            completion(error)
            return
        }
        
        // Create broadcast session if needed
        guard setupBroadcastSessionIfNeeded() else {
            let error = NSError(domain: "BroadcastSetup", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Failed to setup broadcast session"
            ])
            completion(error)
            return
        }
        
        if isBroadcasting {
            // Stop broadcasting if the broadcast session is running
            broadcastSession?.stop()
            isBroadcasting = false
            completion(nil)
        } else {
            // Start broadcasting
            do {
                try broadcastSession?.start(with: endpoint, streamKey: authItem.streamKey)
                isBroadcasting = true
                completion(nil)
            } catch {
                displayErrorAlert(error, logSource: "StartBroadcast")
                isBroadcasting = false
                broadcastSession = nil
                completion(error)
            }
        }
    }
    
    func setBroadcastAuth(endpoint: String, streamKey: String) -> Bool {
        guard URL(string: endpoint) != nil else {
            let error = NSError(domain: "InvalidAuth", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid Endpoint or StreamKey"
            ])
            displayErrorAlert(error, logSource: "setBroadcastAuth")
            return false
        }
        
        UserDefaults.standard.set(endpoint, forKey: "endpointPath")
        UserDefaults.standard.set(streamKey, forKey: "streamKey")
        let authItem = AuthItem(endpoint: endpoint, streamKey: streamKey)
        currentAuthItem = authItem
        return true
    }
    
    func dispose() {
        // Clean up video views
        if let localView = localVideoView {
            cleanupLocalVideoPreview(view: localView)
        }
        videoViews.forEach { (participantId, view) in
            cleanupVideoStream(for: participantId, view: view)
        }
        videoViews.removeAll()
        localVideoView = nil
        
        destroyBroadcastSession()
        leaveStage()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Methods
    
    private func setupBroadcastSessionIfNeeded() -> Bool {
        guard broadcastSession == nil else {
            print("Session not created since it already exists")
            return true
        }
        do {
            self.broadcastSession = try IVSBroadcastSession(configuration: broadcastConfig,
                                                            descriptors: nil,
                                                            delegate: self)
            updateBroadcastSlots()
            return true
        } catch {
            displayErrorAlert(error, logSource: "SetupBroadcastSession")
            return false
        }
    }
    
    private func updateBroadcastSlots() {
        do {
            let participantsToBroadcast = participantsData
            
            broadcastSlots = try StageLayoutCalculator().calculateFrames(participantCount: participantsToBroadcast.count,
                                                                         width: broadcastConfig.video.size.width,
                                                                         height: broadcastConfig.video.size.height,
                                                                         padding: 10)
            .enumerated()
            .map { (index, frame) in
                let slot = IVSMixerSlotConfiguration()
                try slot.setName(participantsToBroadcast[index].broadcastSlotName)
                slot.position = frame.origin
                slot.size = frame.size
                slot.zIndex = Int32(index)
                return slot
            }
            
            updateBroadcastBindings()
            
        } catch {
            let error = NSError(domain: "BroadcastSlots", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "There was an error updating the slots for the Broadcast"
            ])
            displayErrorAlert(error, logSource: "updateBroadcastSlots")
        }
    }
    
    private func updateBroadcastBindings() {
        guard let broadcastSession = broadcastSession else { return }
        
        broadcastSession.awaitDeviceChanges { [weak self] in
            var attachedDevices = broadcastSession.listAttachedDevices()
            
            self?.participantsData.forEach { participant in
                participant.streams.forEach { stream in
                    let slotName = participant.broadcastSlotName
                    if attachedDevices.contains(where: { $0 === stream.device }) {
                        if broadcastSession.mixer.binding(for: stream.device) != slotName {
                            broadcastSession.mixer.bindDevice(stream.device, toSlotWithName: slotName)
                        }
                    } else {
                        broadcastSession.attach(stream.device, toSlotWithName: slotName)
                    }
                    
                    attachedDevices.removeAll(where: { $0 === stream.device })
                }
            }
            
            attachedDevices.forEach {
                broadcastSession.detach($0)
            }
        }
    }
    
    private func destroyBroadcastSession() {
        if isBroadcasting {
            print("Destroying broadcast session")
            broadcastSession?.stop()
            broadcastSession = nil
            isBroadcasting = false
        }
    }
    
    private func dataForParticipant(_ participantId: String) -> ParticipantData? {
        let participant = participantsData.first { $0.participantId == participantId }
        return participant
    }
    
    private func mutatingParticipant(_ participantId: String?, modifier: (inout ParticipantData) -> Void) {
        guard let index = participantsData.firstIndex(where: { $0.participantId == participantId }) else { return }
        
        var participant = participantsData[index]
        modifier(&participant)
        participantsData[index] = participant
    }
    
    private func notifyParticipantsUpdate() {
        delegate?.stageManager(self, didUpdateParticipants: participantsData)
    }
    
    private func displayErrorAlert(_ error: Error, logSource: String? = nil) {
        delegate?.stageManager(self, didEncounterError: error, source: logSource)
    }
}

// MARK: - IVSStageStrategy

extension StageManager: IVSStageStrategy {
    
    func stage(_ stage: IVSStage, shouldSubscribeToParticipant participant: IVSParticipantInfo) -> IVSStageSubscribeType {
        guard let data = dataForParticipant(participant.participantId) else { return .none }
        let subType: IVSStageSubscribeType = data.isAudioOnly ? .audioOnly : .audioVideo
        return subType
    }
    
    func stage(_ stage: IVSStage, shouldPublishParticipant participant: IVSParticipantInfo) -> Bool {
        return localUserWantsPublish
    }
    
    func stage(_ stage: IVSStage, streamsToPublishForParticipant participant: IVSParticipantInfo) -> [IVSLocalStageStream] {
        guard participantsData[0].participantId == participant.participantId else {
            return []
        }
        return localStreams
    }
}

// MARK: - IVSStageRenderer

extension StageManager: IVSStageRenderer {
    
    func stage(_ stage: IVSStage, participantDidJoin participant: IVSParticipantInfo) {
        print("[IVSStageRenderer] participantDidJoin - \(participant.participantId)")
        if participant.isLocal {
            participantsData[0].participantId = participant.participantId
            // Ensure local video preview is set up after local participant joins
            DispatchQueue.main.async { [weak self] in
                self?.setupLocalVideoPreview()
            }
        } else {
            participantsData.append(ParticipantData(isLocal: false, participantId: participant.participantId))
        }
    }
    
    func stage(_ stage: IVSStage, participantDidLeave participant: IVSParticipantInfo) {
        print("[IVSStageRenderer] participantDidLeave - \(participant.participantId)")
        if participant.isLocal {
            print("[IVSStageRenderer] Local participant left - preserving local video view")
            participantsData[0].participantId = nil
            // Don't clear local video view when local participant leaves
            // as it may reconnect and we want to keep the preview stable
        } else {
            if let index = participantsData.firstIndex(where: { $0.participantId == participant.participantId }) {
                participantsData.remove(at: index)
            }
        }
    }
    
    func stage(_ stage: IVSStage, participant: IVSParticipantInfo, didChange publishState: IVSParticipantPublishState) {
        print("[IVSStageRenderer] participant \(participant.participantId) didChangePublishState to \(publishState.description)")
        mutatingParticipant(participant.participantId) { data in
            data.publishState = publishState
        }
    }
    
    func stage(_ stage: IVSStage, participant: IVSParticipantInfo, didChange subscribeState: IVSParticipantSubscribeState) {
        print("[IVSStageRenderer] participant \(participant.participantId) didChangeSubscribeState to \(subscribeState.description)")
        mutatingParticipant(participant.participantId) { data in
            data.subscribeState = subscribeState
        }
    }
    
    func stage(_ stage: IVSStage, participant: IVSParticipantInfo, didAdd streams: [IVSStageStream]) {
        print("[IVSStageRenderer] participant (\(participant.participantId)) didAdd \(streams.count) streams")
        
        for (index, stream) in streams.enumerated() {
            print("[IVSStageRenderer] Stream \(index): device type = \(type(of: stream.device)), urn = \(stream.device.descriptor().urn)")
        }
        
        if participant.isLocal {
            // Local streams are handled by the localStreams setter
            return
        }
        
        mutatingParticipant(participant.participantId) { data in
            data.streams.append(contentsOf: streams)
        }
        
        // Set up video stream for this participant if we have a view for them
        print("[IVSStageRenderer] Setting up video stream for participant: \(participant.participantId)")
        setupVideoStream(for: participant.participantId)
    }
    
    func stage(_ stage: IVSStage, participant: IVSParticipantInfo, didRemove streams: [IVSStageStream]) {
        print("[IVSStageRenderer] participant (\(participant.participantId)) didRemove \(streams.count) streams")
        if participant.isLocal { return }
        
        mutatingParticipant(participant.participantId) { data in
            let oldUrns = streams.map { $0.device.descriptor().urn }
            data.streams.removeAll(where: { stream in
                return oldUrns.contains(stream.device.descriptor().urn)
            })
        }
        
        // Clean up and re-setup video stream for this participant
        if let view = videoViews[participant.participantId] {
            cleanupVideoStream(for: participant.participantId, view: view)
            setupVideoStream(for: participant.participantId)
        }
    }
    
    
    func stage(_ stage: IVSStage, participant: IVSParticipantInfo, didChangeMutedStreams streams: [IVSStageStream]) {
        print("[IVSStageRenderer] participant (\(participant.participantId)) didChangeMutedStreams")
        if participant.isLocal { return }
        if let index = participantsData.firstIndex(where: { $0.participantId == participant.participantId }) {
            // Notify update since stream mute states have changed
            notifyParticipantsUpdate()
        }
    }
    
    func stage(_ stage: IVSStage, didChange connectionState: IVSStageConnectionState, withError error: Error?) {
        print("[IVSStageRenderer] didChangeConnectionStateWithError to \(connectionState.description)")
        stageConnectionState = connectionState
        if let error = error {
            displayErrorAlert(error, logSource: "StageConnectionState")
        }
    }
}

// MARK: - IVSBroadcastSession.Delegate

extension StageManager: IVSBroadcastSession.Delegate {
    
    func broadcastSession(_ session: IVSBroadcastSession, didChange state: IVSBroadcastSession.State) {
        print("[IVSBroadcastSession] state changed to \(state.description)")
        switch state {
        case .invalid, .disconnected, .error:
            isBroadcasting = false
            broadcastSession = nil
        case .connecting, .connected:
            isBroadcasting = true
        default:
            return
        }
    }
    
    func broadcastSession(_ session: IVSBroadcastSession, didEmitError error: Error) {
        print("[IVSBroadcastSession] did emit error \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.displayErrorAlert(error, logSource: "IVSBroadcastSession")
        }
    }
}

// MARK: - IVSErrorDelegate

extension StageManager: IVSErrorDelegate {
    
    func source(_ source: IVSErrorSource, didEmitError error: Error) {
        print("[IVSErrorDelegate] did emit error \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.displayErrorAlert(error, logSource: "\(source)")
        }
    }
}

// MARK: - Supporting Types

struct AuthItem {
    let endpoint: String
    let streamKey: String
}

// MARK: - Extensions

extension IVSBroadcastSession.State {
    var description: String {
        switch self {
        case .invalid: return "Invalid"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .disconnected: return "Disconnected"
        case .error: return "Error"
        @unknown default: return "Unknown"
        }
    }
}

extension IVSStageConnectionState {
    var description: String {
        switch self {
        case .disconnected: return "disconnected"
        case .connecting: return "connecting"
        case .connected: return "connected"
        @unknown default: return "unknown"
        }
    }
}

extension IVSParticipantPublishState {
    var description: String {
        switch self {
        case .notPublished: return "notPublished"
        case .attemptingPublish: return "attemptingPublish"
        case .published: return "published"
        @unknown default: return "unknown"
        }
    }
}

extension IVSParticipantSubscribeState {
    var description: String {
        switch self {
        case .notSubscribed: return "notSubscribed"
        case .attemptingSubscribe: return "attemptingSubscribe"
        case .subscribed: return "subscribed"
        @unknown default: return "unknown"
        }
    }
}

