import Carbon
import Foundation

final class GlobalHotKeyManager {
    struct Shortcut {
        let keyCode: UInt32
        let modifiers: UInt32
        let displayString: String

        static let `default` = Shortcut(
            keyCode: UInt32(kVK_ANSI_C),
            modifiers: UInt32(controlKey | optionKey | cmdKey),
            displayString: "Control + Option + Command + C"
        )
    }

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let shortcut: Shortcut
    private let handler: () -> Void

    init(shortcut: Shortcut = .default, handler: @escaping () -> Void) {
        self.shortcut = shortcut
        self.handler = handler
    }

    deinit {
        stop()
    }

    func start() {
        guard hotKeyRef == nil else { return }

        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                if hotKeyID.id == 1 {
                    manager.handler()
                }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x55494350), id: 1)
        RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    var displayString: String {
        shortcut.displayString
    }
}
