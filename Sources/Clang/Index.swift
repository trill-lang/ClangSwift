#if SWIFT_PACKAGE
  import cclang
#endif

/// An index is a context in which translation units are created.
public class Index {
  let clang: CXIndex


  /// Creates a new index in which translation units can be created.
  /// - Parameters:
  ///  - excludeDeclarationsFromPCH: When non-zero, allows enumerationof "local"
  ///                                declarations (when loading any new
  ///                                translation units). A "local" declaration
  ///                                is one that belongs in the translation unit
  ///                                itself and not in a precompiled header that
  ///                                was used by the translation unit. If zero,
  ///                                all declarations will be enumerated.
  ///                                This process of creating the 'pch', loading
  ///                                it separately, and using it (via
  ///                                -include-pch) allows clang to remove
  ///                                redundant callbacks (which gives the
  ///                                indexer the same performance benefit as the
  ///                                compiler).
  ///  - displayDiagnostics: Whether or not to display diagnostics to standard
  ///                        error while parsing any declarations in this index.
  public init(excludeDeclarationsFromPCH: Bool = true,
              displayDiagnostics: Bool = true) {
    self.clang = clang_createIndex(excludeDeclarationsFromPCH.asClang(),
                                   displayDiagnostics.asClang())
  }

  /// The general options associated with an Index.
  var globalOptions: GlobalOptions {
    get {
      return GlobalOptions(rawValue: clang_CXIndex_getGlobalOptions(clang))
    }
    set {
      clang_CXIndex_setGlobalOptions(clang, newValue.rawValue)
    }
  }

  deinit {
    clang_disposeIndex(clang)
  }
}

/// Global options used to inform the Index.
public struct GlobalOptions: OptionSet {
  public typealias RawValue = CXGlobalOptFlags.RawValue
  public let rawValue: RawValue

  /// Creates a new GlobalOptions from a raw integer value.
  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

  /// Used to indicate that no special CXIndex options are needed.
  public static let none = GlobalOptions(rawValue:
    CXGlobalOpt_None.rawValue)

  /// Used to indicate that threads that libclang creates for indexing purposes
  /// should use background priority.
  /// Affects #clang_indexSourceFile, #clang_indexTranslationUnit,
  /// #clang_parseTranslationUnit, #clang_saveTranslationUnit.
  public static let threadBackgroundPriorityForIndexing = GlobalOptions(rawValue:
    CXGlobalOpt_ThreadBackgroundPriorityForIndexing.rawValue)

  /// Used to indicate that threads that libclang creates for editing purposes
  /// should use background priority.
  /// Affects #clang_reparseTranslationUnit, #clang_codeCompleteAt,
  /// #clang_annotateTokens
  public static let threadBackgroundPriorityForEditing = GlobalOptions(rawValue:
    CXGlobalOpt_ThreadBackgroundPriorityForEditing.rawValue)

  /// Used to indicate that all threads that libclang creates should use
  /// background priority.
  public static let threadBackgroundPriorityForAll = GlobalOptions(rawValue:
    CXGlobalOpt_ThreadBackgroundPriorityForAll.rawValue)
}


/// Options for used for indexing actions.
public struct IndexOptFlags: OptionSet {
  public typealias RawValue = CXIndexOptFlags.RawValue
  public let rawValue: RawValue

  /// Creates a new IndexOptFlags from a raw integer value.
  public init(rawValue: RawValue) {
    self.rawValue = rawValue
  }

  /// Used to indicate that no special indexing options are needed.
  public static let none =
    IndexOptFlags(rawValue: CXIndexOpt_None.rawValue)

  /// Used to indicate that IndexerCallbacks#indexEntityReference should
  /// be invoked for only one reference of an entity per source file that does
  /// not also include a declaration/definition of the entity.
  public static let supressRedundantRefs =
    IndexOptFlags(rawValue: CXIndexOpt_SuppressRedundantRefs.rawValue)

  /// Function-local symbols should be indexed. If this is not set
  /// function-local symbols will be ignored.
  public static let indexFunctionLocalSymbols =
    IndexOptFlags(rawValue: CXIndexOpt_IndexFunctionLocalSymbols.rawValue)

  /// Implicit function/class template instantiations should be indexed.
  /// If this is not set, implicit instantiations will be ignored.
  public static let indexImplicitTemplateInstantiations =
    IndexOptFlags(rawValue: CXIndexOpt_IndexImplicitTemplateInstantiations.rawValue)

  /// Suppress all compiler warnings when parsing for indexing.
  public static let supressWarnings =
    IndexOptFlags(rawValue: CXIndexOpt_SuppressWarnings.rawValue)

  /// Skip a function/method body that was already parsed during an
  /// indexing session associated with a \c CXIndexAction object.
  /// Bodies in system headers are always skipped
  public static let skipParsedBodiesInSession =
    IndexOptFlags(rawValue: CXIndexOpt_SkipParsedBodiesInSession.rawValue)
}

/// An indexing action/session, to be applied to one or multiple translation
/// units.
public class IndexAction {
  let clang: CXIndexAction

  /// Initializes an indexion action.
  /// - parameter index: An Index.
  public init(index: Index = Index()) {
    clang = clang_IndexAction_create(index.clang)
  }

  deinit {
    clang_IndexAction_dispose(clang)
  }
}
