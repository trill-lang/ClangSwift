#if SWIFT_PACKAGE
  import cclang
#endif

/// Describes the severity of a particular diagnostic.
public enum DiagnosticSeverity {

  /// A diagnostic that has been suppressed, e.g., by a command-line option.
  case ignored

  /// This diagnostic is a note that should be attached to the previous
  /// (non-note) diagnostic.
  case note

  /// This diagnostic indicates suspicious code that may not be wrong.
  case warning

  /// This diagnostic indicates that the code is ill-formed.
  case error

  /// This diagnostic indicates that the code is ill-formed such that future
  /// parser recovery is unlikely to produce useful results.
  case fatal

  init(clang: CXDiagnosticSeverity) {
    switch clang {
    case CXDiagnostic_Ignored: self = .ignored
    case CXDiagnostic_Note: self = .note
    case CXDiagnostic_Warning: self = .warning
    case CXDiagnostic_Error: self = .error
    case CXDiagnostic_Fatal: self = .fatal
    default: fatalError("invalid CXDiagnosticSeverity \(clang)")
    }
  }
}

/// Describes the kind of error that occurred (if any) in a call to
/// loadDiagnostics
public enum LoadDiagError: Error {
  /// Indicates that an unknown error occurred while attempting to deserialize
  /// diagnostics.
  case unknown

  /// Indicates that the file containing the serialized diagnostics could not
  /// be opened.
  case cannotLoad

  /// Indicates that the serialized diagnostics file is invalid or corrupt.
  case invalidFile

  init?(clang: CXLoadDiag_Error) {
    switch clang {
    case CXLoadDiag_None: return nil
    case CXLoadDiag_Unknown: self = .unknown
    case CXLoadDiag_CannotLoad: self = .cannotLoad
    case CXLoadDiag_InvalidFile: self = .invalidFile
    default: fatalError("invalid CXLoadDiag_Error \(clang)")
    }
  }
}

/// Options to control the display of diagnostics.
/// The values in this enum are meant to be combined to customize the
/// behavior of `clang_formatDiagnostic().`
public struct DiagnosticDisplayOptions: OptionSet {
  public typealias RawValue = CXDiagnosticDisplayOptions.RawValue
  public let rawValue: RawValue
  /// Creates a new DiagnosticDisplayOptions from a raw integer value.
  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

  /// Display the source-location information where the diagnostic was located.
  /// When set, diagnostics will be prefixed by the file, line, and (optionally)
  /// column to which the diagnostic refers. For example,
  /// ```
  /// test.c:28: warning: extra tokens at end of #endif directive
  /// ```
  /// This option corresponds to the clang flag
  /// `-fshow-source-location.`
  public static let sourceLocation = DiagnosticDisplayOptions(rawValue:
    CXDiagnostic_DisplaySourceLocation.rawValue)

  /// If displaying the source-location information of the diagnostic, also
  /// include the column number.
  /// This option corresponds to the clang flag
  /// `-fshow-column.`
  public static let column = DiagnosticDisplayOptions(rawValue:
    CXDiagnostic_DisplayColumn.rawValue)

  /// If displaying the source-location information of the diagnostic, also
  /// include information about source ranges in a machine-parsable format.
  /// This option corresponds to the clang flag
  /// `-fdiagnostics-print-source-range-info.`
  public static let sourceRanges = DiagnosticDisplayOptions(rawValue:
    CXDiagnostic_DisplaySourceRanges.rawValue)

  /// Display the option name associated with this diagnostic, if any.
  /// The option name displayed (e.g., -Wconversion) will be placed in brackets
  /// after the diagnostic text. This option corresponds to the clang flag
  /// `-fdiagnostics-show-option.`
  public static let option = DiagnosticDisplayOptions(rawValue:
    CXDiagnostic_DisplayOption.rawValue)

  /// Display the category number associated with this diagnostic, if any.
  /// The category number is displayed within brackets after the diagnostic
  /// text.
  /// This option corresponds to the clang flag
  /// `-fdiagnostics-show-category=id.`
  public static let categoryId = DiagnosticDisplayOptions(rawValue:
    CXDiagnostic_DisplayCategoryId.rawValue)

  /// Display the category name associated with this diagnostic, if any.
  /// The category name is displayed within brackets after the diagnostic text.
  /// This option corresponds to the clang flag
  /// `-fdiagnostics-show-category=name.`
  public static let categoryName = DiagnosticDisplayOptions(rawValue:
    CXDiagnostic_DisplayCategoryName.rawValue)
}

/// Encapusulates necessary information for appyling a fix it.
public struct FixIt {
  /// A string containing text that should replace the source code indicated by
  /// `replacementRange`.
  let fixit: String

  /// A source range that will be replaced by the content of the `fixit`.
  let replacementRange: SourceRange
}

/// A single diagnostic, containing the diagnostic's severity, location, text,
/// source ranges, and fix-it hints.
public class Diagnostic: CustomStringConvertible {
  let clang: CXDiagnostic

  init(clang: CXDiagnostic) {
    self.clang = clang
  }

  /// Severity of the diagnostic.
  public var severity: DiagnosticSeverity {
    return DiagnosticSeverity(
      clang: clang_getDiagnosticSeverity(self.clang)
    )
  }

  /// Diagnostic spelling.
  public var description: String {
    return clang_getDiagnosticSpelling(self.clang).asSwift()
  }

  /// Source ranges associated with the diagnostic.
  public var ranges: [SourceRange] {
    let count = clang_getDiagnosticNumRanges(clang)
    return (0..<count).map { idx in
      SourceRange(clang: clang_getDiagnosticRange(clang, idx))
    }
  }

  /// Available fixits for the diagnostic.
  public var fixits: [FixIt] {
    let count = clang_getDiagnosticNumFixIts(clang)
    return (0..<count).map { idx in
      var replacementRange = CXSourceRange()
      let fixit =
        clang_getDiagnosticFixIt(clang, idx, &replacementRange).asSwift()
      return FixIt(fixit: fixit,
                   replacementRange: SourceRange(clang: replacementRange))
    }
  }

  /// Format the given diagnostic in a manner that is suitable for display.
  /// - param options: A set of options that control the diagnostic display.
  /// - returns: string containing for formatted diagnostic
  public func format(options: DiagnosticDisplayOptions) -> String {
    return clang_formatDiagnostic(self.clang, options.rawValue).asSwift()
  }

  deinit {
    clang_disposeDiagnostic(self.clang)
  }
}
