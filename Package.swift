// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "Clang",
    products: [
      .library(
        name: "Clang",
        targets: ["Clang"]),
      .library(name: "ClangStatic",
               type: .static,
               targets: ["Clang"])
    ],
    dependencies: [ ],
    targets: [
      .systemLibrary(
        name: "cclang",
        pkgConfig: "cclang",
        providers: [
          .brew(["llvm"]),
        ]),
      .target(
        name: "Clang",
        dependencies: ["cclang"]),
      .testTarget(
        name: "ClangTests",
        dependencies: ["Clang"])
    ]
)
