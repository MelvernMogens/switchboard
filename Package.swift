// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Switchboard",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Switchboard", targets: ["Switchboard"])],
    targets: [
        .target(
            name: "SwitchKit",
            linkerSettings: [.linkedFramework("IOKit"), .linkedFramework("IOBluetooth")]
        ),
        .executableTarget(name: "Switchboard", dependencies: ["SwitchKit"]),
        .testTarget(name: "SwitchKitTests", dependencies: ["SwitchKit"]),
    ]
)
