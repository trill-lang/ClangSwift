#if SWIFT_PACKAGE
  import cclang
#endif
import Foundation

/// Represents a file ID that's unique to each file in a translation unit.
public struct UniqueFileID: Hashable {
  let clang: CXFileUniqueID

  /// Determines if two unique file IDs are equal.
  public static func ==(lhs: UniqueFileID, rhs: UniqueFileID) -> Bool {
    return lhs.clang.data == rhs.clang.data
  }

  /// A unique integer value representing this unique ID.
  public var hashValue: Int {
    return Int(Int64(bitPattern: clang.data.0 ^ clang.data.1 ^ clang.data.2)
      ^ 0x0a28bf1ac) // xor with a constant for extra mixing.
  }
}

/// A particular source file that is part of a translation unit.
public struct File: Hashable {
  let clang: CXFile

  /// Retrieve the complete file and path name of the given file.
  public var name: String {
    return clang_getFileName(clang).asSwift()
  }

  /// Retrieve the last modification time of the given file.
  public var lastModified: Date {
    return Date(timeIntervalSince1970: TimeInterval(clang_getFileTime(clang)))
  }

  /// Retrieves the unique identifier for this file.
  /// If it failed, returns `nil`.
  public var uniqueID: UniqueFileID? {
    var id = CXFileUniqueID()
    guard clang_getFileUniqueID(clang, &id) != 0 else {
      return nil
    }
    return UniqueFileID(clang: id)
  }

  /// Determines if two files are equal.
  public static func ==(lhs: File, rhs: File) -> Bool {
    return clang_File_isEqual(lhs.clang, rhs.clang) != 0
  }

  /// A unique integer value representing this file.
  public var hashValue: Int {
    let mixin = 0xa24b1bc4
    guard let uniqueID = uniqueID else {
      return name.hashValue ^ mixin
    }
    return uniqueID.hashValue ^ mixin
  }
}

/// Provides the contents of a file that has not yet been saved to disk.
/// Each CXUnsavedFile instance provides the name of a file on the system along
/// with the current contents of that file that have not yet been saved to disk.
public class UnsavedFile {
  /// The underlying CXUnsavedFile value.
  var clang: CXUnsavedFile

  /// A C String that represents the filename.
  private var filenamePtr: UnsafeMutablePointer<CChar>!

  /// A C String that represents the contents buffer.
  private var contentsPtr: UnsafeMutablePointer<CChar>!

  /// Creates an Unsaved file with empty filename, and content.
  public convenience init() {
    self.init(filename: "", contents: "")
  }

  /// Creates an UnsavedFile with initialized `filename` and `contents`.
  /// - Parameter filename: Filename (should exist in the filesystem).
  /// - Parameter contents: Content of the file.
  public init(filename: String, contents: String) {
    clang = CXUnsavedFile()
    self.filename = filename
    self.contents = contents
  }

  /// The file whose contents have not yet been saved.
  /// This file must already exist in the file system.
  public var filename: String {
    get {
      return String(cString: filenamePtr)
    }
    set {
      disposeCStr(filenamePtr)
      filenamePtr = makeCStrFrom(string: newValue)
      clang.Filename = UnsafePointer<CChar>(filenamePtr)
    }
  }

  /// A buffer containing the unsaved contents of this file.
  public var contents: String {
    get {
      return String(cString: contentsPtr)
    }
    set {
      disposeCStr(contentsPtr)

      contentsPtr = makeCStrFrom(string: newValue)
      guard contentsPtr != nil else {
        clang.Contents = nil
        clang.Length = 0
        return
      }

      clang.Contents = UnsafePointer<CChar>(contentsPtr)
      clang.Length = UInt(strlen(contentsPtr))
    }
  }

  /// Creates a C String from a Swift String.
  /// - Parameter string: A Swift String.
  /// - Returns: A C String or nil in case of error.
  private func makeCStrFrom(string: String) -> UnsafeMutablePointer<CChar>? {
    guard let cStr = string.cString(using: .utf8) else {
      return nil
    }

    let ptr = UnsafeMutablePointer<CChar>.allocate(capacity: cStr.count)
    ptr.initialize(from: cStr, count: cStr.count)
    return ptr
  }

  /// Deallocates a C String.
  /// - Parameter ptr: C String.
  private func disposeCStr(_ ptr: UnsafeMutablePointer<CChar>?) {
    ptr?.deallocate()
  }

  deinit {
    disposeCStr(filenamePtr)
    disposeCStr(contentsPtr)
  }
}
