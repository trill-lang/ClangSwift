#if SWIFT_PACKAGE
import cclang
#endif

/// A `Comment` is a parsed documentation comment in a C/C++/Objective-C source
/// file.
public protocol Comment {
  var clang: CXComment { get }
}

extension Comment {
  /// Retreives all children of this comment.
  public var children: AnyRandomAccessCollection<Comment?> {
    let count = clang_Comment_getNumChildren(clang)
    return AnyRandomAccessCollection(count: Int(count), indexingOperation: child)
  }

  /// - parameter index: The index of the child you're getting.
  /// - returns: The specified child of the AST node.
  public func child(at index: Int) -> Comment? {
    return convertComment(clang_Comment_getChild(clang, UInt32(index)))
  }

  /// The first child of this comment, if there are any children.
  public var firstChild: Comment? {
    let count = clang_Comment_getNumChildren(clang)
    if count == 0 { return nil }
    return convertComment(clang_Comment_getChild(clang, 0))
  }
}

public struct FullComment: Comment {
  public let clang: CXComment

  /// Convert a given full parsed comment to an HTML fragment.
  /// Specific details of HTML layout are subject to change. Don't try to parse
  /// this HTML back into an AST, use other APIs instead.
  /// Currently the following CSS classes are used:
  /// - `para-brief` for \brief paragraph and equivalent commands
  /// - `para-returns` for \returns paragraph and equivalent commands
  /// - `word-returns` for the `Returns` word in \returns paragraph.
  /// Function argument documentation is rendered as a <dl> list with arguments
  /// sorted in function prototype order. CSS classes used:
  /// - `param-name-index-NUMBER` for parameter name (<dt>)
  /// - `param-descr-index-NUMBER` for parameter description (<dd>)
  /// - `param-name-index-invalid` and `param-descr-index-invalid` are used if
  ///    parameter index is invalid.
  /// Template parameter documentation is rendered as a <dl> list with
  /// parameters sorted in template parameter list order. CSS classes used:
  /// - `tparam-name-index-NUMBER` for parameter name (<dt>)
  /// - `tparam-descr-index-NUMBER` for parameter description (<dd>)
  /// - `tparam-name-index-other` and `tparam-descr-index-other` are used for
  ///    names inside template template parameters
  /// - `tparam-name-index-invalid` and `tparam-descr-index-invalid` are used if
  ///   parameter position is invalid.
  public var html: String {
    return clang_FullComment_getAsHTML(clang).asSwift()
  }

  /// Convert a given full parsed comment to an XML document.
  /// A Relax NG schema for the XML can be found in comment-xml-schema.rng file
  /// inside the clang source tree.
  public var xml: String {
    return clang_FullComment_getAsXML(clang).asSwift()
  }
}

/// A plain text comment.
public struct TextComment: Comment {
  public let clang: CXComment

  /// Retrieves the text contained in the AST node.
  public var text: String {
    return clang_TextComment_getText(clang).asSwift()
  }
}

/// A command with word-like arguments that is considered inline content.
/// For example: `\c command`
public struct InlineCommandComment: Comment {
  public let clang: CXComment

  /// Retrieves all arguments of this inline command.
  public var arguments: AnyRandomAccessCollection<String> {
    let count = clang_InlineCommandComment_getNumArgs(clang)
    return AnyRandomAccessCollection(count: count) { index in
      return clang_InlineCommandComment_getArgText(self.clang, index).asSwift()
    }
  }
}

/// Describes the attributes in an HTML tag, for example:
/// ```
/// <a href='https://example.org'>
/// ```
/// Would have 1 attribute, with a name `"href"`, and value
/// `"https://example.org"`
public struct HTMLAttribute {
  /// The name of the attribute, which comes before the `=`.
  public let name: String

  /// The value in the attribute, which comes after the `=`.
  public let value: String
}

/// An HTML start tag with attributes (name-value pairs). Considered inline
/// content.
/// For example:
/// ```
/// <a href="http://example.org/">
/// ```
public struct HTMLStartTagComment: Comment {
  public let clang: CXComment

  /// Retrieves all attributes of this HTML start tag.
  public var attributes: AnyRandomAccessCollection<HTMLAttribute> {
    let count = clang_HTMLStartTag_getNumAttrs(clang)
    return AnyRandomAccessCollection(count: count) { index in
      let name = clang_HTMLStartTag_getAttrName(self.clang, index).asSwift()
      let value = clang_HTMLStartTag_getAttrValue(self.clang, index).asSwift()
      return HTMLAttribute(name: name, value: value)
    }
  }
}

/// An HTML end tag. Considered inline content.
/// For example:
/// ```
/// </a>
/// ```
public struct HTMLEndTagComment: Comment {
  public let clang: CXComment
}

/// A paragraph, contains inline comment. The paragraph itself is block content.
public struct ParagraphComment: Comment {
  public let clang: CXComment
}

/// A command that has zero or more word-like arguments (number of word-like
/// arguments depends on command name) and a paragraph as an argument. Block
/// command is block content.
/// Paragraph argument is also a child of the block command.
/// For example: `\brief` has 0 word-like arguments and a paragraph argument.
/// AST nodes of special kinds that parser knows about (e. g., the `\param`
/// command) have their own node kinds.
public struct BlockCommandComment: Comment {
  public let clang: CXComment

  /// Retrieves the name of this block command.
  public var name: String {
    return clang_BlockCommandComment_getCommandName(clang).asSwift()
  }

  /// Retrieves all attributes of this HTML start tag.
  public var arguments: AnyRandomAccessCollection<String> {
    let count = clang_BlockCommandComment_getNumArgs(clang)
    return AnyRandomAccessCollection(count: count) { index in
      return clang_BlockCommandComment_getArgText(self.clang, index).asSwift()
    }
  }

  /// Retrieves the paragraph argument of the block command.
  public var paragraph: ParagraphComment {
    return ParagraphComment(clang: clang_BlockCommandComment_getParagraph(clang))
  }
}

/// Describes parameter passing direction for \param or \arg command.
/// This determines how the callee of a function intends to use the argument.
/// For example, an `.in` argument is meant to be consumed or read by the
/// caller. An `.out` argument is usually a pointer and is meant to be filled
/// by the caller, usually to return multiple pieces of data from a function.
/// An `.inout` argument is meant to be read and written out to by the caller.
public enum ParamPassDirection {
  /// The parameter is an input parameter.
  case `in`

  /// The parameter is an output parameter.
  case out

  /// The parameter is an input and output parameter.
  case `inout`

  init(clang: CXCommentParamPassDirection) {
    switch clang {
    case CXCommentParamPassDirection_In: self = .in
    case CXCommentParamPassDirection_Out: self = .out
    case CXCommentParamPassDirection_InOut: self = .inout
    default: fatalError("invalud CXCommentParamPassDirection: \(clang)")
    }
  }
}

/// A \param or \arg command that describes the function parameter (name,
/// passing direction, description).
/// For example:
/// ```
/// \param [in] ParamName description.
/// ```
public struct ParamCommandComment: Comment {
  public let clang: CXComment

  /// Retrieves the zero-based parameter index in the function prototype.
  public var index: Int {
    return Int(clang_ParamCommandComment_getParamIndex(clang))
  }

  /// The direction this parameter is passed by.
  public var passDirection: ParamPassDirection {
    return ParamPassDirection(clang: clang_ParamCommandComment_getDirection(clang))
  }

  /// Retrieves the name of the declared parameter.
  public var name: String {
    return clang_ParamCommandComment_getParamName(clang).asSwift()
  }

  /// Determine if this parameter is actually a valid parameter in the declared
  /// function
  public var isValidIndex: Bool {
    return clang_ParamCommandComment_isParamIndexValid(clang) != 0
  }

  /// Determines if the parameter's direction was explicitly stated in the
  /// function prototype.
  public var isExplicitDirection: Bool {
    return clang_ParamCommandComment_isDirectionExplicit(clang) != 0
  }
}

/// A \tparam command that describes a template parameter (name and description).
/// For example:
/// ```
/// \tparam T description.
/// ```
public struct TParamCommandComment: Comment {
  public let clang: CXComment

  /// Determines the zero-based nesting depth of this parameter in the template
  /// parameter list.
  /// For example,
  /// ```
  /// template<typename C, template<typename T> class TT>
  /// void test(TT<int> aaa);
  /// ```
  /// for `C` and `TT` the nesting depth is 0, and for `T` the nesting
  /// depth is `1`.
  public var depth: Int {
    return Int(clang_TParamCommandComment_getDepth(clang))
  }
}

/// A verbatim block command (e. g., preformatted code). Verbatim block has an
/// opening and a closing command and contains multiple lines of text
/// (VerbatimBlockLine child nodes).
/// For example:
/// ```
/// \verbatim
///   aaa
/// \endverbatim
/// ```
public struct VerbatimBlockCommandComment: Comment {
  public let clang: CXComment

  /// Retrieves the name of this block command.
  public var name: String {
    return clang_BlockCommandComment_getCommandName(clang).asSwift()
  }

  /// Retrieves all attributes of this HTML start tag.
  public var arguments: AnyRandomAccessCollection<String> {
    let count = clang_BlockCommandComment_getNumArgs(clang)
    return AnyRandomAccessCollection(count: count) { index in
      return clang_BlockCommandComment_getArgText(self.clang, index).asSwift()
    }
  }

  /// Retrieves the paragraph argument of the block command.
  public var paragraph: ParagraphComment {
    return ParagraphComment(clang: clang_BlockCommandComment_getParagraph(clang))
  }
}

/// A line of text that is contained within a `VerbatimBlockCommand`
/// node.
public struct VerbatimBlockLineComment: Comment {
  public let clang: CXComment

  /// The text of this comment.
  public var text: String {
    return clang_VerbatimBlockLineComment_getText(clang).asSwift()
  }
}

/// A verbatim line command. Verbatim line has an opening command, a single
/// line of text (up to the newline after the opening command) and has no
/// closing command.
public struct VerbatimLineComment: Comment {
  public let clang: CXComment

  /// The text of this comment.
  public var text: String {
    return clang_VerbatimLineComment_getText(clang).asSwift()
  }
}

/// Converts a `CXComment` into a `Comment`.
internal func convertComment(_ clang: CXComment) -> Comment? {
  switch clang_Comment_getKind(clang) {
  case CXComment_Null: return nil
  case CXComment_Text: return TextComment(clang: clang)
  case CXComment_InlineCommand: return InlineCommandComment(clang: clang)
  case CXComment_HTMLStartTag: return HTMLStartTagComment(clang: clang)
  case CXComment_HTMLEndTag: return HTMLEndTagComment(clang: clang)
  case CXComment_Paragraph: return ParagraphComment(clang: clang)
  case CXComment_BlockCommand: return BlockCommandComment(clang: clang)
  case CXComment_ParamCommand: return ParamCommandComment(clang: clang)
  case CXComment_TParamCommand: return TParamCommandComment(clang: clang)
  case CXComment_VerbatimBlockCommand: return VerbatimBlockCommandComment(clang: clang)
  case CXComment_VerbatimBlockLine: return VerbatimBlockLineComment(clang: clang)
  case CXComment_VerbatimLine: return VerbatimLineComment(clang: clang)
  case CXComment_FullComment: return FullComment(clang: clang)
  default: fatalError("invalid kind \(clang)")
  }
}
