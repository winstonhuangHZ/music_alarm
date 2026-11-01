import AppKit
import Carbon

/// Optional application-wide shortcut: Command-Option-M opens Music Alarm.
final class GlobalShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    func start(onTrigger: @escaping () -> Void) {
        stop()
        self.onTrigger = onTrigger
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return noErr }
            let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
            var hotKeyID = EventHotKeyID()
            var size = MemoryLayout<EventHotKeyID>.size
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           &size,
                                           &hotKeyID)
            if status == noErr {
                manager.onTrigger?()
            }
            return noErr
        }
        let installStatus = InstallEventHandler(GetApplicationEventTarget(),
                                                callback,
                                                1,
                                                &eventSpec,
                                                Unmanaged.passUnretained(self).toOpaque(),
                                                &handlerRef)
        guard installStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: 0x4D414C52, id: 1)
        let registerStatus = RegisterEventHotKey(UInt32(kVK_ANSI_M),
                                                 UInt32(cmdKey | optionKey),
                                                 hotKeyID,
                                                 GetApplicationEventTarget(),
                                                 0,
                                                 &hotKeyRef)
        if registerStatus != noErr {
            stop()
        }
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
        onTrigger = nil
    }

    deinit {
        stop()
    }
}
