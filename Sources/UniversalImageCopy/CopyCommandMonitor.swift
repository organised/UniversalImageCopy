import AppKit
import ApplicationServices
import Carbon
import Foundation

final class CopyCommandMonitor {
    var onCopyCommand: (() -> Void)?
    var onAccessChanged: ((Bool) -> Void)?

    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var lastTriggerAt: Date?

    private(set) var hasListenAccess: Bool = false {
        didSet {
            if oldValue != hasListenAccess {
                onAccessChanged?(hasListenAccess)
            }
        }
    }

    init() {
        refreshAccess()
    }

    deinit {
        stop()
    }

    func start() {
        refreshAccess()
        startEventTap()
    }

    func stop() {
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            eventTapSource = nil
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    func refreshAccess() {
        hasListenAccess = CGPreflightListenEventAccess()
    }

    func requestAccess() {
        hasListenAccess = CGRequestListenEventAccess()
    }

    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else { return }
        NSWorkspace.shared.open(url)
    }

    private func startEventTap() {
        guard eventTap == nil else { return }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<CopyCommandMonitor>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = monitor.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            if type == .keyDown {
                monitor.handle(event: event)
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(event: CGEvent) {
        guard hasListenAccess else { return }
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)
        let hasOption = flags.contains(.maskAlternate)
        let hasControl = flags.contains(.maskControl)

        guard keyCode == kVK_ANSI_C,
              hasCommand,
              !hasOption,
              !hasControl else {
            return
        }

        let now = Date()
        if let lastTriggerAt, now.timeIntervalSince(lastTriggerAt) < 0.25 {
            return
        }
        lastTriggerAt = now

        DispatchQueue.main.async { [weak self] in
            self?.onCopyCommand?()
        }
    }
}
