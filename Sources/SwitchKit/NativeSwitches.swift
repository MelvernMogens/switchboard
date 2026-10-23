import Foundation
import IOKit.pwr_mgt
import IOBluetooth

// Switches that talk to system frameworks directly (some private, loaded at runtime
// so a missing symbol hides the row instead of crashing).

// MARK: Keep Awake

public final class KeepAwakeSwitch: SwitchItem, @unchecked Sendable {
    private var assertion: IOPMAssertionID = 0
    private var expiry: Date?
    private var timer: Timer?
    private let lock = NSLock()
    private let store: UserDefaults
    /// Called when a timed session runs out, so the UI can refresh.
    public var onExpire: (() -> Void)?

    static let modeKey = "keepAwakeMode"   // seconds; 0 = indefinitely

    public init(store: UserDefaults = .standard) {
        self.store = store
        super.init(id: "keepAwake", title: "Keep Awake", symbol: "cup.and.saucer", style: .toggle)
    }

    public static let durations: [(String, TimeInterval?)] = [
        ("Indefinitely", nil), ("15 minutes", 900), ("30 minutes", 1800),
        ("1 hour", 3600), ("2 hours", 7200), ("5 hours", 18000),
    ]

    /// The mode the user last picked; the plain toggle turns on with this.
    public var mode: TimeInterval? {
        get {
            let v = store.double(forKey: Self.modeKey)
            return v > 0 ? v : nil
        }
        set { store.set(newValue ?? 0, forKey: Self.modeKey) }
    }

    /// When the current timed session ends. nil = off or indefinitely.
    public var endsAt: Date? {
        lock.lock(); defer { lock.unlock() }
        return assertion != 0 ? expiry : nil
    }

    /// Subtitle while on: "Indefinitely" or "1h 29m left". nil when off.
    public override var detail: String? { status(at: Date()) }

    public func status(at now: Date) -> String? {
        lock.lock(); defer { lock.unlock() }
        guard assertion != 0 else { return nil }
        guard let expiry else { return "Indefinitely" }
        return Self.format(remaining: expiry.timeIntervalSince(now)) + " left"
    }

    static func format(remaining: TimeInterval) -> String {
        let secs = max(0, Int(remaining.rounded(.up)))
        if secs < 60 { return "\(secs)s" }
        let mins = Int((Double(secs) / 60).rounded(.up))
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
    }

    public override func readState() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return assertion != 0
    }

    public override func setState(_ on: Bool) throws {
        if on { try start(for: mode) } else { stop() }
    }

    public func start(for duration: TimeInterval?) throws {
        stop()
        mode = duration
        var id: IOPMAssertionID = 0
        let r = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Switchboard Keep Awake" as CFString, &id)
        guard r == kIOReturnSuccess else { throw SwitchError.failed("Couldn't keep the Mac awake (IOKit \(r)).") }
        lock.lock()
        assertion = id
        expiry = duration.map { Date().addingTimeInterval($0) }
        lock.unlock()
        if let duration {
            DispatchQueue.main.async { [weak self] in
                self?.timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                    self?.stop()
                    self?.onExpire?()
                }
            }
        }
    }

    public func stop() {
        lock.lock()
        if assertion != 0 { IOPMAssertionRelease(assertion) }
        assertion = 0
        expiry = nil
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }
    }
}

// MARK: Night Shift (CoreBrightness, private)

public final class NightShiftSwitch: SwitchItem, @unchecked Sendable {
    private let client: NSObject?

    public init() {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY)
        if let cls = NSClassFromString("CBBlueLightClient") as? NSObject.Type {
            client = cls.init()
        } else {
            client = nil
        }
        super.init(id: "nightShift", title: "Night Shift", symbol: "sunset", style: .toggle)
    }

    public override var isAvailable: Bool {
        guard let cls = NSClassFromString("CBBlueLightClient") else { return false }
        let sel = NSSelectorFromString("supportsBlueLightReduction")
        guard let meta = object_getClass(cls), class_respondsToSelector(meta, sel) else { return client != nil }
        typealias F = @convention(c) (AnyClass, Selector) -> Bool
        let imp = method_getImplementation(class_getClassMethod(cls, sel)!)
        return unsafeBitCast(imp, to: F.self)(cls, sel)
    }

    /// Status struct starts with { BOOL active; BOOL enabled; ... }. Oversized buffer
    /// because the struct has grown across macOS versions.
    public override func readState() -> Bool {
        guard let client else { return false }
        let sel = NSSelectorFromString("getBlueLightStatus:")
        guard client.responds(to: sel) else { return false }
        typealias F = @convention(c) (AnyObject, Selector, UnsafeMutableRawPointer) -> Bool
        let f = unsafeBitCast(client.method(for: sel), to: F.self)
        let buf = UnsafeMutableRawPointer.allocate(byteCount: 256, alignment: 8)
        defer { buf.deallocate() }
        buf.initializeMemory(as: UInt8.self, repeating: 0, count: 256)
        guard f(client, sel, buf) else { return false }
        return buf.load(fromByteOffset: 1, as: Bool.self) // enabled
    }

    public override func setState(_ on: Bool) throws {
        guard let client else { throw SwitchError.unavailable("Night Shift isn't available on this Mac.") }
        let sel = NSSelectorFromString("setEnabled:")
        guard client.responds(to: sel) else { throw SwitchError.unavailable("Night Shift API changed on this macOS.") }
        typealias F = @convention(c) (AnyObject, Selector, Bool) -> Bool
        let f = unsafeBitCast(client.method(for: sel), to: F.self)
        guard f(client, sel, on) else { throw SwitchError.failed("Night Shift refused the change.") }
    }
}

// MARK: Lock Screen (login.framework, private)

public final class LockScreenAction: SwitchItem, @unchecked Sendable {
    private typealias LockFn = @convention(c) () -> Int32
    private let lockFn: LockFn?

    public init() {
        let h = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY)
        if let h, let sym = dlsym(h, "SACLockScreenImmediate") {
            lockFn = unsafeBitCast(sym, to: LockFn.self)
        } else {
            lockFn = nil
        }
        super.init(id: "lockScreen", title: "Lock Screen", symbol: "lock", style: .action)
    }

    public override var isAvailable: Bool { lockFn != nil }

    public override func perform() throws {
        guard let lockFn else { throw SwitchError.unavailable("Lock Screen isn't available on this macOS.") }
        _ = lockFn()
    }
}

// MARK: Bluetooth audio devices (AirPods etc.)

public final class BluetoothAudioSwitch: SwitchItem, @unchecked Sendable {
    private let address: String
    private let name: String

    init(device: IOBluetoothDevice) {
        address = device.addressString ?? ""
        name = device.name ?? device.addressString ?? "Bluetooth Device"
        let isAirPods = name.localizedCaseInsensitiveContains("airpods")
        super.init(id: "bt:\(address)", title: "Connect \(name)",
                   symbol: isAirPods ? "airpodspro" : "headphones", style: .toggle)
    }

    public override var displayTitle: String { name }

    private var device: IOBluetoothDevice? { IOBluetoothDevice(addressString: address) }

    public override func readState() -> Bool { device?.isConnected() ?? false }

    public override func setState(_ on: Bool) throws {
        guard let device else { throw SwitchError.failed("\(name) is no longer paired.") }
        let r = on ? device.openConnection() : device.closeConnection()
        guard r == kIOReturnSuccess else {
            throw SwitchError.failed(on ? "Couldn't connect \(name) — is it nearby and out of the case?"
                                        : "Couldn't disconnect \(name).")
        }
    }

    /// Paired devices whose Class of Device is Audio/Video (major class 0x04).
    public static func pairedAudio() -> [BluetoothAudioSwitch] {
        let devices = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        return devices
            .filter { isAudio(classOfDevice: $0.classOfDevice) || ($0.name ?? "").localizedCaseInsensitiveContains("airpods") }
            .map(BluetoothAudioSwitch.init)
    }

    public static func isAudio(classOfDevice: BluetoothClassOfDevice) -> Bool {
        (classOfDevice >> 8) & 0x1F == 0x04
    }
}
