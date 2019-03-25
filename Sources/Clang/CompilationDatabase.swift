#if SWIFT_PACKAGE
import cclang
#endif

import Foundation

/// Error code for Compilation Database
///
/// - noError: no error.
/// - canNotLoadDatabase: failed to load database.
public enum CompilationDatabaseError: Error {
  
  case canNotLoadDatabase
  
  init?(clang: CXCompilationDatabase_Error) {
    switch clang {
    case CXCompilationDatabase_CanNotLoadDatabase:
      self = .canNotLoadDatabase
    default:
      return nil
    }
  }
}

/// Contains the results of a search in the compilation database.
public struct CompileCommand: Equatable {
  
  // the working directory where the CompileCommand was executed from.
  let directory: String
  
  // the filename associated with the CompileCommand.
  let filename: String
  
  // the array of argument value in the compiler invocations.
  let arguments: [String]
    
  fileprivate init(command: CXCompileCommand) {
    // get directory and filename
    self.directory = clang_CompileCommand_getDirectory(command).asSwift()
    self.filename = clang_CompileCommand_getFilename(command).asSwift()
    
    // get arguments
    let args = clang_CompileCommand_getNumArgs(command)
    self.arguments = (0 ..< args).map { i in
      return clang_CompileCommand_getArg(command, i).asSwift()
    }
    
    // MARK: - unsupported api by cclang yet?
    //    let mappedSourcesCount = clang_CompileCommand_getNumMappedSources(command)
    //    (0 ..< mappedSourcesCount).forEach { i in
    //      let path = clang_CompileCommand_getMappedSourcePath(command, UInt32(i)).asSwift()
    //      let content = clang_CompileCommand_getMappedSourceContent(command, UInt32(i)).asSwift()
    //    }
  }
}

/// A compilation database holds all information used to compile files in a project.
public class CompilationDatabase {
  let db: CXCompilationDatabase
  private let owned: Bool
  
  public init(directory: String) throws {
    var err = CXCompilationDatabase_NoError
    
    // check `compile_commands.json` file existence in directory folder.
    let cmdFile = URL(fileURLWithPath: directory, isDirectory: true)
        .appendingPathComponent("compile_commands.json").path
    guard FileManager.default.fileExists(atPath: cmdFile) else {
        throw CompilationDatabaseError.canNotLoadDatabase
    }
    
    // initialize compilation db
    self.db = clang_CompilationDatabase_fromDirectory(directory, &err)
    if let error = CompilationDatabaseError(clang: err) {
      throw error
    }
    
    self.owned = true
  }
  
  /// the array of all compile command in the compilation database.
  public lazy private(set) var compileCommands: [CompileCommand] = {
    guard let commands = clang_CompilationDatabase_getAllCompileCommands(self.db) else {
      return []
    }
    // the compileCommands needs to be disposed.
    defer {
      clang_CompileCommands_dispose(commands)
    }
    
    let count = clang_CompileCommands_getSize(commands)
    return (0 ..< count).map { i in
      // get compile command
      guard let cmd = clang_CompileCommands_getCommand(commands, UInt32(i)) else {
        fatalError("Failed to get compile command for an index \(i)")
      }
      return CompileCommand(command: cmd)
    }
  }()
  
  
  /// Returns the array of compile command for a file.
  ///
  /// - Parameter filename: a filename containing directory.
  /// - Returns: the array of compile command.
  public func compileCommands(forFile filename: String) -> [CompileCommand] {
    guard let commands = clang_CompilationDatabase_getCompileCommands(self.db, filename) else {
      fatalError("failed to load compileCommands for \(filename).")
    }
    // the compileCommands needs to be disposed.
    defer {
      clang_CompileCommands_dispose(commands)
    }
    
    let size = clang_CompileCommands_getSize(commands)
    
    return (0 ..< size).map { i in
      guard let cmd = clang_CompileCommands_getCommand(commands, UInt32(i)) else {
        fatalError("Failed to get compile command for an index \(i)")
      }
      return CompileCommand(command: cmd)
    }
  }
  
  deinit {
    if self.owned {
      clang_CompilationDatabase_dispose(self.db)
    }
  }
}
