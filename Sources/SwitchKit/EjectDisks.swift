import AppKit
import Foundation

/// A mounted volume that "Eject Disks" may touch.
public struct EjectableVolume: Equatable {
    public let url: URL
    public let name: String
    public init(url: URL, name: String) {
        self.url = url
        self.name = name
    }
}

/// Ejects every external drive, disk image and network share — never the boot disk.
public final class EjectDisksAction: SwitchItem, @unchecked Sendable {
    private let list: () -> [EjectableVolume]
    private let eject: (URL) throws -> Void

    public init(list: @escaping () -> [EjectableVolume] = EjectDisksAction.mountedEjectables,
                eject: @escaping (URL) throws -> Void = { try NSWorkspace.shared.unmountAndEjectDevice(at: $0) }) {
        self.list = list
        self.eject = eject
        super.init(id: "ejectDisks", title: "Eject Disks", symbol: "eject", style: .action)
    }

    public override var detail: String? {
        let n = list().count
        return n == 0 ? nil : "\(n)"
    }

    public override func perform() throws {
        let volumes = list()
        guard !volumes.isEmpty else { throw SwitchError.unavailable("No disks to eject.") }
        var stuck: [String] = []
        for v in volumes {
            do { try eject(v.url) } catch { stuck.append(v.name) }
        }
        if !stuck.isEmpty {
            throw SwitchError.failed("Couldn't eject \(stuck.joined(separator: ", ")) — a file on it is probably still open.")
        }
    }

    public static func mountedEjectables() -> [EjectableVolume] {
        let keys: [URLResourceKey] = [.volumeIsEjectableKey, .volumeIsRemovableKey, .volumeIsLocalKey,
                                      .volumeIsInternalKey, .volumeIsRootFileSystemKey, .volumeLocalizedNameKey]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                         options: [.skipHiddenVolumes]) ?? []
        return urls.compactMap { url in
            guard let v = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            return isEjectable(path: url.path, ejectable: v.volumeIsEjectable, removable: v.volumeIsRemovable,
                               local: v.volumeIsLocal, isInternal: v.volumeIsInternal, root: v.volumeIsRootFileSystem)
                ? EjectableVolume(url: url, name: v.volumeLocalizedName ?? url.lastPathComponent) : nil
        }
    }

    /// Pure rule, unit-tested: only things mounted under /Volumes, never the root/internal disk.
    static func isEjectable(path: String, ejectable: Bool?, removable: Bool?, local: Bool?,
                            isInternal: Bool?, root: Bool?) -> Bool {
        if root == true || !path.hasPrefix("/Volumes/") { return false }
        if ejectable == true || removable == true || local == false { return true }
        return isInternal == false // external drives that don't report ejectable (some SSD enclosures)
    }
}
