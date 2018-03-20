#if SWIFT_PACKAGE
import cclang
#endif

/// Represents the errors that can be thrown by libclang.
public enum ClangError: Error {
  /// Clang had an internal failure while processing the request.
  case failure

  /// Clang crashed while processing the request.
  case crashed

  /// The arguments provided to the clang invocation were invalid.
  case invalidArguments

  /// Clang failed to parse an AST from the provided source file(s).
  case astRead

  /// Constructs a ClangError from the provided CXErrorCode
  init?(clang: CXErrorCode) {
    switch clang {
    case CXError_Failure: self = .failure
    case CXError_Crashed: self = .crashed
    case CXError_ASTReadError: self = .astRead
    case CXError_InvalidArguments: self = .invalidArguments
    default: return nil
    }
  }
}

/// Represents the errors that can be thrown by libclang when saving a
/// `TranslationUnit`.
public enum ClangSaveError: Error {
  /// Indicates that an unknown error occurred while attempting to save the
  /// file.
  /// This error typically indicates that file I/O failed when attempting to
  /// write the file.
  case unknown

  /// Indicates that errors during translation prevented this attempt to save
  /// the translation unit.
  /// Errors that prevent the translation unit from being saved can be extracted
  /// using diagnostics.
  case translationErrors

  /// Indicates that the translation unit to be saved was somehow invalid.
  case invalidTranslationUnit

  /// Constructs a ClangSaveError from the provided CXSaveError.
  init?(clang: CXSaveError) {
    switch clang {
    case CXSaveError_Unknown: self = .unknown
    case CXSaveError_TranslationErrors: self = .translationErrors
    case CXSaveError_InvalidTU: self = .invalidTranslationUnit
    default: return nil
    }
  }
}
