#!/usr/bin/env swift
import Foundation

#if os(Linux)
  typealias Process = Task
#elseif os(macOS)
#endif

/// Runs the specified program at the provided path.
/// - parameter path: The full path of the executable you
///                   wish to run.
/// - parameter args: The arguments you wish to pass to the
///                   process.
/// - returns: The standard output of the process, or nil if it was empty.
func run(_ path: String, args: [String] = []) -> String? {
  print("Running \(path) \(args.joined(separator: " "))...")
  let pipe = Pipe()
  let process = Process()
  process.launchPath = path
  process.arguments = args
  process.standardOutput = pipe
  process.launch()
  process.waitUntilExit()
  
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  guard let result = String(data: data, encoding: .utf8)?
    .trimmingCharacters(in: .whitespacesAndNewlines),
    !result.isEmpty else { return nil }
  return result
}

/// Finds the location of the provided binary on your system.
func which(_ name: String) -> String? {
  return run("/usr/bin/which", args: [name])
}

extension String: Error {
  /// Replaces all occurrences of characters in the provided set with
  /// the provided string.
  func replacing(charactersIn characterSet: CharacterSet,
                 with separator: String) -> String {
    let components = self.components(separatedBy: characterSet)
    return components.joined(separator: separator)
  }
}

func build() throws {
  let projectRoot = URL(fileURLWithPath: #file)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  
  // ${project_root}/.build/build.input_tests url
  let buildURL = projectRoot.appendingPathComponent(".build/build.input_tests", isDirectory: true)
  //  print(buildURL.path)
  
  let sourceURL = projectRoot.appendingPathComponent("input_tests", isDirectory: true)
  //  print(sourceURL.path)
  
  // make `${projectRoot}/.build.input_tests` folder if it doesn't exist.
  if !FileManager.default.fileExists(atPath: buildURL.path) {
    try FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true)
  }
  
  // run `CMake ../` command at `input_tests/build` folder.
  //  -S <path-to-source>          = Explicitly specify a source directory.
  //  -B <path-to-build>           = Explicitly specify a build directory.
  guard let cmake = which("cmake") else { return }
  let args: [String] = [
    "-S", sourceURL.path,
    "-B", buildURL.path
  ]
  
  // run `cmake -S ${sourcePath} -B {buildPath}` command.
  _ = run(cmake, args: args)
  print("\nThe `compile_commands.json` is generated at \(buildURL.path)")
}

do {
  try build()
} catch {
#if os(Linux)
  // FIXME: Printing the thrown error that here crashes on Linux.
  print("Unexpected error occured while writing the config file. Check permissions and try again.")
#else
  print("error: \(error)")
#endif
  exit(-1)
}
