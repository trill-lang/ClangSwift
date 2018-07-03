#if SWIFT_PACKAGE
  import cclang
#endif

/// A cursor representing some element in the abstract syntax tree for a
/// translation unit.
///
/// The cursor abstraction unifies the different kinds of entities in a
/// program--declaration, statements, expressions, references to declarations,
/// etc.--under a single "cursor" abstraction with a common set of operations.
/// Common operation for a cursor include: getting the physical location in a
/// source file where the cursor points, getting the name associated with a
/// cursor, and retrieving cursors for any child nodes of a particular cursor.
/// Cursors can be produced in two specific ways.
/// 
/// `TranslationUnit.cursor`
/// produces a cursor for a translation unit, from which one can use
/// `children() to explore the rest of the translation unit.
///
/// `SourceLocation.cursor` maps from a physical source location to the entity
/// that resides at that location, allowing one to map from the source code into
/// the AST.
public protocol Cursor: CustomStringConvertible {
  /// Converts this cursor value to a CXCursor value to be consumed by
  /// libclang APIs
  func asClang() -> CXCursor
}

/// Used as the return type for `Cursor.visitChildren`. Describes what to do
/// after each iteration of a child visitation.
public enum ChildVisitResult {
  /// Stop visitation.
  case abort

  /// Recurse into this cursor (if it has children).
  case recurse

  /// Continue to the next sibling without visiting this cursor's children.
  case `continue`
}

/// Represents a cursor type that is simply backed by a CXCursor
internal protocol ClangCursorBacked: Cursor {
  var clang: CXCursor { get }
}

extension ClangCursorBacked {
  /// Returns the underlying CXCursor value
  public func asClang() -> CXCursor {
    return clang
  }
}

extension CXCursor: Cursor {
  /// Returns `self` unmodified.
  public func asClang() -> CXCursor {
    return self
  }
}

/// Compares two `Cursor`s and determines if they are equivalent.
public func ==(lhs: Cursor, rhs: Cursor) -> Bool {
  return clang_equalCursors(lhs.asClang(), rhs.asClang()) != 0
}

extension Cursor {

  /// Retrieve a name for the entity referenced by this cursor.
  public var description: String {
    return clang_getCursorSpelling(asClang()).asSwift()
  }

  /// Retrieve a Unified Symbol Resolution (USR) for the entity referenced by
  /// the given cursor.
  /// A Unified Symbol Resolution (USR) is a string that identifies a
  /// particular entity (function, class, variable, etc.) within a program.
  /// USRs can be compared across translation units to determine, e.g., when
  /// references in one translation refer to an entity defined in another
  /// translation unit.
  public var usr: String {
    return clang_getCursorUSR(asClang()).asSwift()
  }

  /// For a cursor that is either a reference to or a declaration of some
  /// entity, retrieve a cursor that describes the definition of that entity.
  /// Some entities can be declared multiple times within a translation unit,
  /// but only one of those declarations can also be a definition. For
  /// example, given:
  /// ```
  /// int f(int, int);
  /// int g(int x, int y) { return f(x, y); }
  /// int f(int a, int b) { return a + b; }
  /// int f(int, int);
  /// ```
  /// there are three declarations of the function "f", but only the second
  /// one is a definition. This variable, accessed on any cursor pointing to a
  /// declaration of "f" (the first or fourth lines of the example) or a
  /// cursor referenced that uses "f" (the call to "f' inside "g"), will
  /// return a declaration cursor pointing to the definition (the second "f"
  /// declaration).
  ///
  /// If given a cursor for which there is no corresponding definition, e.g.,
  /// because there is no definition of that entity within this translation
  /// unit, returns a `NULL` cursor.
  public var definition: Cursor? {
    return convertCursor(clang_getCursorDefinition(asClang()))
  }

  /// Retrieve the display name for the entity referenced by this cursor.
  /// The display name contains extra information that helps identify the
  /// cursor, such as the parameters of a function or template or the
  /// arguments of a class template specialization.
  public var displayName: String {
    return clang_getCursorDisplayName(asClang()).asSwift()
  }

  /// Determine the lexical parent of the given cursor.
  /// The lexical parent of a cursor is the cursor in which the given cursor
  /// was actually written.  For many declarations, the lexical and semantic
  /// parents are equivalent. They diverge when declarations or definitions
  /// are provided out-of-line. For example:
  ///
  /// ```
  /// class C {
  ///   void f();
  /// };
  /// void C::f() { }
  /// ```
  ///
  /// In the out-of-line definition of `C::f`, the semantic parent is the class
  /// `C`, of which this function is a member. The lexical parent is the place
  /// where the declaration actually occurs in the source code; in this case,
  /// the definition occurs in the translation unit. In general, the lexical
  /// parent for a given entity can change without affecting the semantics of
  /// the program, and the lexical parent of different declarations of the
  /// same entity may be different. Changing the semantic parent of a
  /// declaration, on the other hand, can have a major impact on semantics,
  /// and redeclarations of a particular entity should all have the same
  /// semantic context.
  ///
  /// In the example above, both declarations of `C::f` have `C` as their
  /// semantic context, while the lexical context of the first `C::f` is `C`
  /// and the lexical context of the second `C::f` is the translation unit.
  /// For global declarations, the semantic parent is the translation unit.
  public var lexicalParent: Cursor? {
    return convertCursor(clang_getCursorLexicalParent(asClang()))
  }

  /// Determine the semantic parent of the given cursor.
  /// The semantic parent of a cursor is the cursor that semantically contains
  /// the given cursor. For many declarations, the lexical and semantic
  /// parents are equivalent. They diverge when declarations or definitions
  /// are provided out-of-line. For example:
  ///
  /// ```
  /// class C {
  ///   void f();
  /// };
  /// void C::f() { }
  /// ```
  ///
  /// In the out-of-line definition of `C::f`, the semantic parent is the class
  /// `C`, of which this function is a member. The lexical parent is the place
  /// where the declaration actually occurs in the source code; in this case,
  /// the definition occurs in the translation unit. In general, the lexical
  /// parent for a given entity can change without affecting the semantics of
  /// the program, and the lexical parent of different declarations of the
  /// same entity may be different. Changing the semantic parent of a
  /// declaration, on the other hand, can have a major impact on semantics,
  /// and redeclarations of a particular entity should all have the same
  /// semantic context.
  ///
  /// In the example above, both declarations of `C::f` have `C` as their
  /// semantic context, while the lexical context of the first `C::f` is `C`
  /// and the lexical context of the second `C::f` is the translation unit.
  /// For global declarations, the semantic parent is the translation unit.
  public var semanticParent: Cursor? {
    return convertCursor(clang_getCursorSemanticParent(asClang()))
  }

  /// For a cursor that is a reference, retrieve a cursor representing the
  /// entity that it references.
  /// Reference cursors refer to other entities in the AST. For example, an
  /// Objective-C superclass reference cursor refers to an Objective-C class.
  /// This function produces the cursor for the Objective-C class from the
  /// cursor for the superclass reference. If the input cursor is a
  /// declaration or definition, it returns that declaration or definition
  /// unchanged. Otherwise, returns the `NULL` cursor.
  public var referenced: Cursor? {
    return convertCursor(clang_getCursorReferenced(asClang()))
  }

  /// Retrieves the type of this cursor (if any).
  public var type: CType? {
    return convertType(clang_getCursorType(asClang()))
  }

  /// Returns the translation unit that a cursor originated from.
  public var translationUnit: TranslationUnit {
    return TranslationUnit(clang: clang_Cursor_getTranslationUnit(asClang()), owned: false)
  }

  /// Retrieves all the children of the provided cursor.
  ///
  /// - returns: An array of `Cursors` that are children of this cursor.
  public func children() -> [Cursor] {
    var children = [Cursor]()
    clang_visitChildrenWithBlock(asClang()) { child, _ in
      if let cursor = convertCursor(child) {
        children.append(cursor)
      }
      return CXChildVisit_Continue
    }
    return children
  }

  /// Describe the visibility of the entity referred to by a cursor.
  /// This returns the default visibility if not explicitly specified by a
  /// visibility attribute. The default visibility may be changed by
  /// commandline arguments.
  public var visiblity: VisibilityKind? {
    return VisibilityKind(clang: clang_getCursorVisibility(asClang()))
  }

  /// Retrieve the physical extent of the source construct referenced by the
  /// given cursor.
  /// The extent of a cursor starts with the file/line/column pointing at the
  /// first character within the source construct that the cursor refers to
  /// and ends with the last character within that source construct. For a
  /// declaration, the extent covers the declaration itself. For a reference,
  /// the extent covers the location of the reference (e.g., where the
  /// referenced entity was actually used).
  public var range: SourceRange {
    return SourceRange(clang: clang_getCursorExtent(asClang()))
  }

  /// Describes any availability information that specifies if the declaration
  /// in question is deprecated or marked unavailable, and on which platforms
  /// and versions this availability declaration applies.
  public var availability: Availability {
    let maxNumPlatforms = 10 // 10 ought to be enough for anybody...
    let platformAvailabilities =
      UnsafeMutablePointer<CXPlatformAvailability>.allocate(capacity: maxNumPlatforms)
    var alwaysDeprecated: Int32 = 0
    var deprecatedMessage = CXString()
    var alwaysUnavailable: Int32 = 0
    var unavailableMessage = CXString()
    let numPlatforms = clang_getCursorPlatformAvailability(asClang(),
                                                           &alwaysDeprecated,
                                                           &deprecatedMessage,
                                                           &alwaysUnavailable,
                                                           &unavailableMessage,
                                                           platformAvailabilities,
                                                           Int32(maxNumPlatforms))

    var platforms = [PlatformAvailability]()
    for i in 0..<Int(numPlatforms) {
      var platform = platformAvailabilities[i]
      platforms.append(PlatformAvailability(clang: platform))
      clang_disposeCXPlatformAvailability(&platform)
    }

    return Availability(alwaysDeprecated: alwaysDeprecated != 0,
                        deprecationMessage: deprecatedMessage.asSwiftOptional(),
                        alwaysUnavailable: alwaysUnavailable != 0,
                        unavailableMessage: unavailableMessage.asSwiftOptional(),
                        platforms: platforms)
  }

  /// Returns the storage class for a function or variable declaration.
  public var storageClass: StorageClass? {
    return StorageClass(clang: clang_Cursor_getStorageClass(asClang()))
  }

  /// Returns the access control level for the referenced object.
  /// If the cursor refers to a C++ declaration, its access control level
  /// within its parent scope is returned. Otherwise, if the cursor refers to
  /// a base specifier or access specifier, the specifier itself is returned.
  public var accessSpecifier: CXXAccessSpecifierKind? {
    return CXXAccessSpecifierKind(clang: clang_getCXXAccessSpecifier(asClang()))
  }

  /// Given a cursor that represents a documentable entity (e.g.,
  /// declaration), return the associated parsed comment
  public var fullComment: FullComment? {
    return convertComment(clang_Cursor_getParsedComment(asClang())) as? FullComment
  }

  /// Given a cursor that represents a declaration, return the associated
  /// comment text, including comment markers.
  public var rawComment: String? {
    return clang_Cursor_getRawCommentText(asClang()).asSwiftOptional()
  }

  /// Given a cursor that represents a documentable entity (e.g.,
  /// declaration), return the associated \brief paragraph; otherwise return
  /// the first paragraph.
  public var briefComment: String? {
    return clang_Cursor_getBriefCommentText(asClang()).asSwiftOptional()
  }

  /// Determine the "language" of the entity referred to by a given cursor.
  public var language: Language? {
    return Language(clang: clang_getCursorLanguage(asClang()))
  }

  /// Determine whether the declaration pointed to by this cursor
  // is also a definition of that entity.
  public var isDefinition: Bool {
    return clang_isCursorDefinition(asClang()) != 0
  }

  /// Determine whether the given cursor represents a declaration.
  public var isDeclaration: Bool {
    return clang_isDeclaration(asClang().kind) != 0
  }

  /// Determine whether the given cursor kind represents a simple reference.
  /// Note that other kinds of cursors (such as expressions) can also refer to
  /// other cursors. Use clang_getCursorReferenced() to determine whether a
  /// particular cursor refers to another entity.
  public var isReference: Bool {
    return clang_isReference(asClang().kind) != 0
  }

  /// Determine whether the given cursor represents an expression.
  public var isExpression: Bool {
    return clang_isExpression(asClang().kind) != 0
  }

  /// Determine whether the given cursor represents an attribute.
  public var isAttribute: Bool {
    return clang_isAttribute(asClang().kind) != 0
  }

  /// Determine whether the given cursor has any attributes.
  public var hasAttributes: Bool {
    return clang_Cursor_hasAttrs(asClang()) != 0
  }

  /// Determine whether the given cursor represents a translation unit.
  public var isTranslationUnit: Bool {
    return clang_isTranslationUnit(asClang().kind) != 0
  }

  /// Determine whether the given cursor represents an invalid cursor.
  public var isInvalid: Bool {
    return clang_isInvalid(asClang().kind) != 0
  }

  /// Determine whether the given cursor represents a preprocessing element,
  /// such as a preprocessor directive or macro instantiation.
  public var isPreprocessing: Bool {
    return clang_isPreprocessing(asClang().kind) != 0
  }

  /// Determine whether the given cursor represents a currently unexposed piece
  /// of the AST.
  public var isUnexposed: Bool {
    return clang_isUnexposed(asClang().kind) != 0
  }

  /// Determine whether the given cursor is `nil` or not.
  public var isNull: Bool {
    return clang_Cursor_isNull(asClang()) != 0
  }

  /// If cursor is a statement declaration tries to evaluate the statement and
  /// if its variable, tries to evaluate its initializer, into its
  /// corresponding type.
  public func evaluate() -> EvalResult? {
    guard let result = clang_Cursor_Evaluate(asClang()) else { return nil }
    return convertEvalResult(result)
  }

  /// Visits each of the children of this cursor, calling the provided
  /// callback for each child.
  /// - parameter perCursorCallback: The callback to call with each child in
  ///                                the receiver.
  /// - note: The returned value of this callback defines what the next item
  ///         visited will be. See `ChildVisitResult` for a list of possible
  ///         results.
  public func visitChildren(_ perCursorCallback: (Cursor) -> ChildVisitResult) {
    withoutActuallyEscaping(perCursorCallback) { callback -> Void in
      clang_visitChildrenWithBlock(asClang()) {
        (thisCursor, parentCursor) -> CXChildVisitResult in
        guard let cursor = convertCursor(thisCursor) else {
          return CXChildVisit_Continue
        }

        let result = callback(cursor)
        switch result {
        case .abort: return CXChildVisit_Break
        case .recurse: return CXChildVisit_Recurse
        case .continue: return CXChildVisit_Continue
        }
      }
    }
  }

  /// Retrieve the nil cursor, which represents no entity.
  public static var null: Cursor {
    return clang_getNullCursor()
  }
}

/// Describes the visibility of a given symbol at link time.
public enum VisibilityKind {
  /// Symbol not seen by the linker.
  case hidden
  /// Symbol seen by the linker but resolves to a symbol inside this object.
  case protected
  /// Symbol seen by the linker and acts like a normal symbol.
  case `default`

  internal init?(clang: CXVisibilityKind) {
    switch clang {
    case CXVisibility_Hidden: self = .hidden
    case CXVisibility_Protected: self = .protected
    case CXVisibility_Default: self = .default
    default: return nil
    }
  }
}

/// Describes the kind of a template argument.
public enum TemplateArgumentKind {
  /// Represents an empty template argument, e.g., one that has not been
  /// deduced.
  case null

  /// The template argument is a type, i.e. `std::vector<int>`
  case type

  /// The template argument is a declaration that was provided for a pointer,
  /// reference, or pointer to member non-type template parameter.
  case declaration

  /// The template argument is a null pointer or null pointer to member that
  /// was provided for a non-type template parameter.
  case nullPtr

  /// The template argument is an integral value that was provided for an
  /// integral non-type template parameter.
  case integral

  /// The template argument is a template name that was provided for a
  /// `template <template <...>>` parameter.
  case template

  /// The template argument is a pack expansion of a template name that was
  /// provided for a `template<template<...>>` parameter.
  case templateExpansion

  /// The template argument is an expression, and we've not resolved it to one
  /// of the other forms yet, either because it's dependent or because we're
  /// representing a non-canonical template argument (for instance, in a
  /// TemplateSpecializationType).
  /// Also used to represent a non-dependent `__uuidof` expression (a Microsoft
  /// extension).
  case expression

  /// The template argument is actually a parameter pack.
  case pack

  init?(clang: CXTemplateArgumentKind) {
    switch clang {
    case CXTemplateArgumentKind_Null: self = .null
    case CXTemplateArgumentKind_Type: self = .type
    case CXTemplateArgumentKind_Declaration: self = .declaration
    case CXTemplateArgumentKind_NullPtr: self = .nullPtr
    case CXTemplateArgumentKind_Integral: self = .integral
    case CXTemplateArgumentKind_Template: self = .template
    case CXTemplateArgumentKind_TemplateExpansion: self = .templateExpansion
    case CXTemplateArgumentKind_Expression: self = .expression
    case CXTemplateArgumentKind_Pack: self = .pack
    case CXTemplateArgumentKind_Invalid: return nil
    default: fatalError("invalid CXTemplateArgumentKind \(clang)")
    }
  }
}

/// Represents the C++ access control level to a base class for a cursor.
public enum CXXAccessSpecifierKind {
  /// The declaration is marked `public`.
  case `public`

  /// The declaration is marked `protected`.
  case protected

  /// The declaration is marked `private`.
  case `private`

  init?(clang: CX_CXXAccessSpecifier) {
    switch clang {
    case CX_CXXInvalidAccessSpecifier: return nil
    case CX_CXXPublic: self = .public
    case CX_CXXProtected: self = .protected
    case CX_CXXPrivate: self = .private
    default: fatalError("invalid CX_CXXAccessSpecifier \(clang)")
    }
  }
}

/// Represents the storage classes as declared in the source.
public enum StorageClass {
  /// No storage class was declared for the declaration.
  case none

  /// The declaration was declared `extern`, meaning its value will exist in
  /// another object file.
  case extern

  /// The declaration was declared static, rendering it inacessible outside this
  /// source file.
  case `static`

  /// The declaration was declared private extern.
  case privateExtern

  /// The declaration was declared local to the current OpenCL work group.
  case openCLWorkGroupLocal

  /// The declaration was declared `auto`matic.
  case auto

  /// The declaration was declared with the `register` storage class.
  case register

  init?(clang: CX_StorageClass) {
    switch clang {
    case CX_SC_Invalid: return nil
    case CX_SC_None: self = .none
    case CX_SC_Extern: self = .extern
    case CX_SC_Static: self = .static
    case CX_SC_PrivateExtern: self = .privateExtern
    case CX_SC_OpenCLWorkGroupLocal: self = .openCLWorkGroupLocal
    case CX_SC_Auto: self = .auto
    case CX_SC_Register: self = .register
    default: fatalError("invalid CX_StorageClass \(clang)")
    }
  }
}
