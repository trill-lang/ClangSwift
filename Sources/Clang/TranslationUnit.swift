#if SWIFT_PACKAGE
  import cclang
#endif

import Foundation

/// Flags that control the creation of translation units.
/// The enumerators in this enumeration type are meant to be bitwise ORed
/// together to specify which options should be used when constructing the
/// translation unit.
public struct TranslationUnitOptions: OptionSet {
  public typealias RawValue = CXTranslationUnit_Flags.RawValue
  public let rawValue: RawValue

  /// Creates a new TranslationUnitOptions from a raw integer value.
  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

  /// Used to indicate that no special translation-unit options are needed.
  public static let none = TranslationUnitOptions(rawValue:
    CXTranslationUnit_None.rawValue)

  /// Used to indicate that the parser should construct a "detailed"
  /// preprocessing record, including all macro definitions and instantiations.
  /// Constructing a detailed preprocessing record requires more memory and time
  /// to parse, since the information contained in the record is usually not
  /// retained. However, it can be useful for applications that require more
  /// detailed information about the behavior of the preprocessor.
  public static let detailedPreprocessingRecord = TranslationUnitOptions(rawValue:
    CXTranslationUnit_DetailedPreprocessingRecord.rawValue)

  /// Used to indicate that the translation unit is incomplete.
  /// When a translation unit is considered "incomplete", semantic analysis that
  /// is typically performed at the end of the translation unit will be
  /// suppressed. For example, this suppresses the completion of tentative
  /// declarations in C and of instantiation of implicitly-instantiation
  /// function templates in C++. This option is typically used when parsing a
  /// header with the intent of producing a precompiled header.
  public static let incomplete = TranslationUnitOptions(rawValue:
    CXTranslationUnit_Incomplete.rawValue)

  /// Used to indicate that the translation unit should be built with an
  /// implicit precompiled header for the preamble.
  /// An implicit precompiled header is used as an optimization when a
  /// particular translation unit is likely to be reparsed many times
  /// when the sources aren't changing that often. In this case, an
  /// implicit precompiled header will be built containing all of the
  /// initial includes at the top of the main file (what we refer to as
  /// the "preamble" of the file). In subsequent parses, if the
  /// preamble or the files in it have not changed,
  /// `clang_reparseTranslationUnit()`
  /// will re-use the implicit
  /// precompiled header to improve parsing performance.
  public static let precompiledPreamble = TranslationUnitOptions(rawValue:
    CXTranslationUnit_PrecompiledPreamble.rawValue)

  /// Used to indicate that the translation unit should cache some
  /// code-completion results with each reparse of the source file.
  /// Caching of code-completion results is a performance optimization that
  /// introduces some overhead to reparsing but improves the performance of
  /// code-completion operations.
  public static let cacheCompletionResults = TranslationUnitOptions(rawValue:
    CXTranslationUnit_CacheCompletionResults.rawValue)

  /// This option is typically used when parsing a header with the intent of
  /// producing a precompiled header.
  /// Used to indicate that the translation unit will be serialized with
  /// `clang_saveTranslationUnit.`
  public static let forSerialization = TranslationUnitOptions(rawValue:
    CXTranslationUnit_ForSerialization.rawValue)

  /// DEPRECATED: Enabled chained precompiled preambles in C++.
  /// Note: this is a *temporary* option that is available only while we are
  /// testing C++ precompiled preamble support. It is deprecated.
  public static let cxxChainedPCH = TranslationUnitOptions(rawValue:
    CXTranslationUnit_CXXChainedPCH.rawValue)

  /// Used to indicate that function/method bodies should be skipped while
  /// parsing.
  /// This option can be used to search for declarations/definitions while
  /// ignoring the usages.
  public static let skipFunctionBodies = TranslationUnitOptions(rawValue:
    CXTranslationUnit_SkipFunctionBodies.rawValue)

  /// Used to indicate that brief documentation comments should be included into
  /// the set of code completions returned from this translation unit.
  public static let includeBriefCommentsInCodeCompletion = TranslationUnitOptions(rawValue:
    CXTranslationUnit_IncludeBriefCommentsInCodeCompletion.rawValue)

  /// Used to indicate that the precompiled preamble should be created on the
  /// first parse. Otherwise it will be created on the first reparse. This
  /// trades runtime on the first parse (serializing the preamble takes time)
  /// for reduced runtime on the second parse (can now reuse the preamble).
  public static let createPreambleOnFirstParse = TranslationUnitOptions(rawValue:
    CXTranslationUnit_CreatePreambleOnFirstParse.rawValue)

  /// Do not stop processing when fatal errors are encountered.
  /// When fatal errors are encountered while parsing a translation unit,
  /// semantic analysis is typically stopped early when compiling code. A common
  /// source for fatal errors are unresolvable include files. For the purposes
  /// of an IDE, this is undesirable behavior and as much information as
  /// possible should be reported. Use this flag to enable this behavior.
  public static let keepGoing = TranslationUnitOptions(rawValue:
    CXTranslationUnit_KeepGoing.rawValue)
}


/// Flags that control how translation units are saved.
/// The enumerators in this enumeration type are meant to be bitwise ORed
/// together to specify which options should be used when saving the translation
/// unit.
public struct TranslationUnitSaveOptions: OptionSet {
  public typealias RawValue = CXSaveTranslationUnit_Flags.RawValue
  public let rawValue: RawValue

  /// Creates a new TranslationUnitSaveOptions from a raw integer value.
  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

  /// Used to indicate that no special saving options are needed.
  public static let none =
    TranslationUnitSaveOptions(rawValue: CXSaveTranslationUnit_None.rawValue)
}

public class TranslationUnit {
  let clang: CXTranslationUnit

  init(clang: CXTranslationUnit) {
    self.clang = clang
  }


  /// Creates a `TranslationUnit` by parsing the file at the specified path,
  /// passing optional command line arguments and options to clang.
  ///
  /// - parameters:
  ///   - filename: The path you're going to parse
  ///   - index: The index (optional, will use a default index if not
  ///            provided)
  ///   - args: Optional command-line arguments to pass to clang
  ///   - options: Options for how to handle the parsed file
  /// - throws: `ClangError` if the translation unit could not be created
  ///           successfully.
  public init(filename: String,
              index: Index = Index(),
              commandLineArgs args: [String] = [],
              options: TranslationUnitOptions = []) throws {
    self.clang = try args.withUnsafeCStringBuffer { argC in
      var unit: CXTranslationUnit?
      let err = clang_parseTranslationUnit2(index.clang, filename,
                                            argC.baseAddress,
                                            Int32(argC.count),
                                            nil, 0,
                                            options.rawValue, &unit)
      if let clangErr = ClangError(clang: err) {
        throw clangErr
      }
      return unit!
    }
  }

  /// Creates a `TranslationUnit` by parsing the source code passed,
  /// passing optional command line arguments and options to clang.
  ///
  /// - parameters:
  ///   - clangSource: The source code to parse
  ///   - index: The index (optional, will use a default index if not
  ///            provided)
  ///   - args: Optional command-line arguments to pass to clang
  ///   - options: Options for how to handle the parsed file
  /// - throws: `ClangError` if the translation unit could not be created
  ///           successfully.
  public convenience init(clangSource: String,
                          language: Language,
                          index: Index = Index(),
                          commandLineArgs args: [String] = [],
                          options: TranslationUnitOptions = []) throws {
    // Returns URL for temporary directory.
    let temporaryDirectory = { () -> URL in
      if #available(OSX 10.12, *) {
        return FileManager.default.temporaryDirectory
      } else {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      }
    }

    // Returns correct extension depending on the language passed.
    let extensionFromLang = { (lang: Language) -> String in
      switch lang {
      case .c:
        return ".c"
      case .cPlusPlus:
        return ".cc"
      case .objectiveC:
        return ".m"
      }
    }

    // Create random file in temporary directory with `clangSource` as content.
    let randomFileName =
      UUID().uuidString.lowercased() + extensionFromLang(language)
    let temporaryClangFileURL =
      temporaryDirectory().appendingPathComponent(randomFileName)
    FileManager.default.createFile(atPath: temporaryClangFileURL.path,
                                   contents: clangSource.data(using: .utf8))
    defer {
      try? FileManager.default.removeItem(at: temporaryClangFileURL)
    }

    try self.init(filename: temporaryClangFileURL.path,
                  index: index,
                  commandLineArgs: args,
                  options: options)
  }

  /// Creates a `TranslationUnit` from an AST file generated by `-emit-ast`.
  ///
  /// - parameters:
  ///   - astFilename: Filename that points to an AST
  ///   - index: The index (optional, will use a default index if not
  ///            provided)
  /// - throws: `ClangError` if the translation unit could not be created
  ///           successfully.
  public init(astFilename: String, index: Index = Index()) throws {
    var unit: CXTranslationUnit?
    let err = clang_createTranslationUnit2(index.clang,
                                           astFilename,
                                           &unit)
    if let clangErr = ClangError(clang: err) {
      throw clangErr
    }
    
    self.clang = unit!
  }

  /// Retrieve the cursor that represents the given translation unit.
  /// The translation unit cursor can be used to start traversing the various
  /// declarations within the given translation unit.
  public var cursor: Cursor {
    return convertCursor(clang_getTranslationUnitCursor(clang))!
  }

  /// Retrieves diagnostics attached with the given translation unit.
  public var diagnostics: [Diagnostic] {
    let diagnosticSet = clang_getDiagnosticSetFromTU(self.clang)
    defer { clang_disposeDiagnosticSet(diagnosticSet) }

    let count = clang_getNumDiagnosticsInSet(diagnosticSet)
    return (0..<count).map { idx in
      Diagnostic(clang:
        clang_getDiagnosticInSet(diagnosticSet, idx))
    }
  }

  /// Visits each of the children of this translation unit, calling the
  /// provided callback for each child.
  /// - parameter perCursorCallback: The callback to call with each child in
  ///                                the receiver.
  /// - note: The returned value of this callback defines what the next item
  ///         visited will be. See `ChildVisitResult` for a list of possible
  ///         results.
  public func visitChildren(_ perCursorCallback: (Cursor) -> ChildVisitResult) {
    cursor.visitChildren(perCursorCallback)
  }

  /// Get the original translation unit source file name.
  public var spelling: String {
    return clang_getTranslationUnitSpelling(clang).asSwift()
  }

  /// Retrieve a file handle within the given translation unit.
  /// - parameter name: The name of the file.
  /// - returns: The file handle for the named file in the translation unit,
  ///     or `nil` if the file was not a part of this translation unit.
  public func getFile(for name: String) -> File? {
    return File(clang: clang_getFile(self.clang, name))
  }

  /// Tokenizes the source code described by the given range into raw lexical
  /// tokens.
  /// - parameter range: the source range in which text should be tokenized.
  ///                    All of the tokens produced by tokenization will fall
  ///                    within this source range.
  /// - returns: All tokens that fall within the provided source range in this
  ///            translation unit.
  public func tokens(in range: SourceRange) -> [Token] {
    var tokensPtrOpt: UnsafeMutablePointer<CXToken>?
    var numTokens: UInt32 = 0
    clang_tokenize(clang, range.clang, &tokensPtrOpt, &numTokens)
    guard let tokensPtr = tokensPtrOpt else { return [] }
    var tokens = [Token]()
    for i in 0..<Int(numTokens) {
      tokens.append(convertToken(tokensPtr[i]))
    }
    clang_disposeTokens(clang, tokensPtr, numTokens)
    return tokens
  }


  /// Annotate the given set of tokens by providing cursors for each token
  /// that can be mapped to a specific entity within the abstract syntax tree.
  /// This token-annotation routine is equivalent to invoking `cursor(at:)`
  /// for the source locations of each of the tokens. The cursors provided are
  /// filtered, so that only those cursors that have a direct correspondence
  /// to the token are accepted. For example, given a function call `f(x)`,
  /// `cursor(at:)` would provide the following cursors:
  ///
  /// - when the cursor is over the `f`, a `DeclRefExpr` cursor referring to
  ///   `f`.
  /// - when the cursor is over the `(` or the `)`, a `CallExpr` referring to
  ///   `f`.
  /// - when the cursor is over the `x`, a `DeclRefExpr` cursor referring to
  ///   `x`.
  ///
  /// Only the first and last of these cursors will occur within the annotate,
  /// since the tokens "f" and "x' directly refer to a function and a variable,
  /// respectively, but the parentheses are just a small part of the full
  /// syntax of the function call expression, which is not provided as an
  /// annotation.
  ///
  /// - parameter tokens: The set of tokens to annotate
  /// - returns: The cursors corresponding to each token provided
  public func annotate(tokens: [Token]) -> [Cursor] {
    var toks = tokens.map { $0.clang }
    let cursors =
      UnsafeMutablePointer<CXCursor>.allocate(capacity: toks.count)
    toks.withUnsafeMutableBufferPointer { buf in
      clang_annotateTokens(clang, buf.baseAddress,
                           UInt32(buf.count), cursors)
    }
    return (0..<toks.count).flatMap { convertCursor(cursors[$0]) }
  }

  /// Returns the set of flags that is suitable for reparsing a translation unit.
  public var defaultReparseOptions: TranslationUnitOptions {
    return TranslationUnitOptions(rawValue:
      clang_defaultReparseOptions(self.clang))
  }

  /// Reparse the source files that produced this translation unit.
  ///
  /// This routine can be used to re-parse the source files that originally
  /// created the given translation unit, for example because those source files
  /// have changed (either on disk or as passed via unsavedFiles). The
  /// source code will be reparsed with the same command-line options as it
  /// was originally parsed.
  ///
  /// Reparsing a translation unit invalidates all cursors and source locations
  /// that refer into that translation unit. This makes reparsing a translation
  /// unit semantically equivalent to destroying the translation unit and then
  /// creating a new translation unit with the same command-line arguments.
  /// However, it may be more efficient to reparse a translation
  /// unit using this routine.
  ///
  /// - parameters:
  ///   - parameter unsavedFiles: The files that have not yet been saved to disk
  ///       but may be required for parsing, including the contents of
  ///       those files.  The contents and name of these files are copied when
  ///       necessary, so the client only needs to guarantee their validity
  ///       until the call to this function returns.
  ///   - options: Options for how to handle the parsed file. Use
  ///       `defaultReparseOptions` for default reparsing option.
  ///
  /// - throws: `ClangError` if the translation unit could not be created
  ///           successfully.
  public func reparseTransaltionUnit(using unsavedFiles: [UnsavedFile],
                        options: TranslationUnitOptions) throws {
    var cxUnsavedFiles = unsavedFiles.map { $0.clang }
    let err = CXErrorCode(
      UInt32(clang_reparseTranslationUnit(self.clang,
                                          UInt32(unsavedFiles.count),
                                          &cxUnsavedFiles,
                                          options.rawValue)))
    if let clangErr = ClangError(clang: err) {
      throw clangErr
    }
  }

  /// Returns suitable options for saving the current `translation unit`.
  ///
  /// The set of flags returned provide options for `saveTranslationUnit(in:withOption)`
  /// by default. The returned flag set contains an unspecified set of options
  /// that save translation units with the most commonly-requested data.
  public var defaultSaveOptions: TranslationUnitSaveOptions {
    return TranslationUnitSaveOptions(rawValue: clang_defaultSaveOptions(clang))
  }

  /// Saves a translation unit into a serialized representation of that
  /// translation unit on disk.
  ///
  /// Any translation unit that was parsed without error can be saved
  /// into a file. The translation unit can then be deserialized into a
  /// new `TranslationUnit` with `TranslationUnit(astFilename:index:)` or,
  /// if it is an incomplete translation unit that corresponds to a
  /// header, used as a precompiled header when parsing other translation
  /// units.
  ///
  /// - paramaters:
  ///   - in: Filename where to store the translation unit.
  ///   - withOptions: Options that affects how the translation unit is saved.
  ///
  /// - throws: `ClangSaveError` in case an error occurred.
  public func saveTranslationUnit(in filename: String,
                                  withOptions options: TranslationUnitSaveOptions) throws {
    let err = CXSaveError(
      UInt32(clang_saveTranslationUnit(self.clang, filename, options.rawValue)))
    if let clangSaveErr = ClangSaveError(clang: err) {
      throw clangSaveErr
    }
  }

  deinit {
    clang_disposeTranslationUnit(clang)
  }
}
