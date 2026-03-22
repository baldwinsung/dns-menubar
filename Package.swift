// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SimpleDNSMenuBar",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "SimpleDNSMenuBar",
            path: "Sources/SimpleDNSMenuBar",
            linkerSettings: [
                .linkedFramework("CoreWLAN"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .executableTarget(
            name: "SimpleDNSHelper",
            path: "Sources/SimpleDNSHelper"
        )
    ]
)
