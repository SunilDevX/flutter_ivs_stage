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
            
            // Add stream with local image device to localStreams
            localStreams.append(IVSLocalStageStream(device: camera, config: IVSLocalStageStreamConfiguration()))
        }

        if let microphone = microphone {
            // Add stream with local audio device to localStreams
            localStreams.append(IVSLocalStageStream(device: microphone))
        }
        
        // Notify UI updates
        notifyParticipantsUpdate()
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
        // Clean up video views
        if let localView = localVideoView {
            cleanupLocalVideoPreview(view: localView)
        }
        videoViews.forEach { (participantId, view) in
            cleanupVideoStream(for: participantId, view: view)
        }
        videoViews.removeAll()
        localVideoView = nil
        
        stage?.leave()
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
        localVideoView = view
        // Set up camera preview if we have local streams
        setupLocalVideoPreview()
    }
    
    func setVideoView(_ view: UIView, for participantId: String) {
        videoViews[participantId] = view
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
        if let view = localVideoView {
            // Clean up local video preview
            cleanupLocalVideoPreview(view: view)
            localVideoView = nil
            print("Ivsstage:  removeLocalVideoView")
        }
    }
    
    private func setupLocalVideoPreview() {
        guard let localView = localVideoView else { return }

        let cameraStreams = localStreams.filter { $0.device is IVSImageDevice }
        print("Ivsstage:  setupLocalVideoPreview cameraStreams: \(cameraStreams)")
        if let cameraStream = cameraStreams.first,
           let imageDevice = cameraStream.device as? IVSImageDevice,
           let preview = try? imageDevice.previewView() {
            print("Ivsstage:  setupLocalVideoPreview preview: \(preview)")
            localView.addSubview(preview)
        }
    }
    
    private func setupVideoStream(for participantId: String) {
        guard let view = videoViews[participantId] else { return }
        
        guard let participantData = participantsData.first(where: { $0.participantId == participantId }) else { return }
        
        let videoStreams = participantData.streams.filter { $0.device is IVSImageDevice }
        if let videoStream = videoStreams.first,
           let imageDevice = videoStream.device as? IVSImageDevice , let preview = try? imageDevice.previewView() {
                view.addSubview(preview)
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
        } else {
            participantsData.append(ParticipantData(isLocal: false, participantId: participant.participantId))
        }
    }

    func stage(_ stage: IVSStage, participantDidLeave participant: IVSParticipantInfo) {
        print("[IVSStageRenderer] participantDidLeave - \(participant.participantId)")
        if participant.isLocal {
            participantsData[0].participantId = nil
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
        if participant.isLocal { 
            // For local participant, refresh local video preview
            setupLocalVideoPreview()
            return 
        }

        mutatingParticipant(participant.participantId) { data in
            data.streams.append(contentsOf: streams)
        }
        
        // Set up video stream for this participant if we have a view for them
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
