#!/usr/bin/env swift
import Foundation

#if os(Linux)
  typealias Process = Task
#elseif os(macOS)
#endif

 /// Runs the specified program at the provided path.
 ///
 /// - Parameters:
 ///   - exec: The full path of the executable binary.
 ///   - dir: The process working directory. If this is nil, the current directory will be used.
 ///   - args: The arguments you wish to pass to the process.
 /// - Returns: The standard output of the process, or nil if it was empty.
func run(exec: String, at dir: URL? = nil, args: [String] = []) -> String? {
  let pipe = Pipe()
  let process = Process()

  process.executableURL = URL(fileURLWithPath: exec)
  process.arguments = args
  process.standardOutput = pipe

  if let dir = dir {
    print("Running \(dir.path) \(exec) \(args.joined(separator: " "))...")
    process.currentDirectoryURL = dir
  } else {
    print("Running \(args.joined(separator: " "))...")
  }
 

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
  return run(exec: "/usr/bin/which", args: [name])
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
  let sourceURL = projectRoot.appendingPathComponent("input_tests", isDirectory: true)

  print("project root \(projectRoot.path)")
  print("build folder \(buildURL.path)")
  // print(sourceURL.path)
  
  // make `${projectRoot}/.build.input_tests` folder if it doesn't exist.
  if !FileManager.default.fileExists(atPath: buildURL.path) {
    try FileManager.default.createDirectory(at: buildURL, withIntermediateDirectories: true)
  }
  
  // get `cmake` command path.
  guard let cmake = which("cmake") else { return }

  // run `cd {buildPath}; cmake ${sourcePath}` command.
  let results = run(exec: cmake, at: buildURL, args: [sourceURL.path])
  print(results!)
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
