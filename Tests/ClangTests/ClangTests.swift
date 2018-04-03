import XCTest
#if SWIFT_PACKAGE
  import cclang
#endif
@testable import Clang

class ClangTests: XCTestCase {
  func testInitTranslationUnitUsingArguments() {
    do {
      let unit = try TranslationUnit(clangSource: "int main(void) {int a; return 0;}",
                                     language: .c,
                                     commandLineArgs: ["-Wall"])
      XCTAssertEqual(unit.diagnostics.map{$0.description},
                     ["unused variable \'a\'"])
    } catch {
      XCTFail("\(error)")
    }
  }

  func testInitUsingStringAsSource() {
    do {
      let unit = try TranslationUnit(clangSource: "int main() {}", language: .c)
      let lexems =
        unit.tokens(in: unit.cursor.range).map {$0.spelling(in: unit)}
      XCTAssertEqual(lexems, ["int", "main", "(", ")", "{", "}"])
    } catch {
      XCTFail("\(error)")
    }
  }

  func testDiagnostic() {
    do {
      let src = "void main() {int a = \"\"; return 0}"
      let unit = try TranslationUnit(clangSource: src, language: .c)
      let diagnostics = unit.diagnostics
      XCTAssertEqual(diagnostics.count, 4)
    } catch {
      XCTFail("\(error)")
    }
  }

  func testUnsavedFile() {
    let unsavedFile = UnsavedFile(filename: "a.c", contents: "void f(void);")

    XCTAssertEqual(unsavedFile.filename, "a.c")
    XCTAssertTrue(strcmp(unsavedFile.clang.Filename, "a.c") == 0)

    XCTAssertEqual(unsavedFile.contents, "void f(void);")
    XCTAssertTrue(strcmp(unsavedFile.clang.Contents, "void f(void);") == 0)
    XCTAssertEqual(unsavedFile.clang.Length, 13)


    unsavedFile.filename = "b.c"
    XCTAssertEqual(unsavedFile.filename, "b.c")
    XCTAssertTrue(strcmp(unsavedFile.clang.Filename, "b.c") == 0)

    unsavedFile.contents = "int add(int, int);"
    XCTAssertEqual(unsavedFile.contents, "int add(int, int);")
    XCTAssertTrue(strcmp(unsavedFile.clang.Contents, "int add(int, int);") == 0)
    XCTAssertEqual(unsavedFile.clang.Length, 18)
  }

  func testTUReparsing() {
    do {
      let filename = "input_tests/reparse.c"
      let index = Index()
      let unit = try TranslationUnit(filename: filename, index: index)

      let src = "int add(int, int);"
      let unsavedFile = UnsavedFile(filename: filename, contents: src)

      try unit.reparseTransaltionUnit(using: [unsavedFile],
                         options: unit.defaultReparseOptions)

      XCTAssertEqual(
        unit.tokens(in: unit.cursor.range).map { $0.spelling(in: unit) },
        ["int", "add", "(", "int", ",", "int", ")", ";"]
      )
    } catch {
      XCTFail("\(error)")
    }
  }

  func testInitFromASTFile() {
    do {
      let filename = "input_tests/init-ast.c"
      let astFilename = "/tmp/JKN-23-AC.ast"

      let unit = try TranslationUnit(filename: filename)
      try unit.saveTranslationUnit(in: astFilename,
                                   withOptions: unit.defaultSaveOptions)
      defer {
        try? FileManager.default.removeItem(atPath: astFilename)
      }

      let unit2 = try TranslationUnit(astFilename: astFilename)
      XCTAssertEqual(
        unit2.tokens(in: unit2.cursor.range).map { $0.spelling(in: unit2) },
        ["int", "main", "(", "void", ")", "{", "return", "0", ";", "}"]
      )
    } catch {
      XCTFail("\(error)")
    }
  }

  func testLocationInitFromLineAndColumn() {
    do {
      let filename = "input_tests/locations.c"
      let unit = try TranslationUnit(filename: filename)
      let file = File(clang: clang_getFile(unit.clang, filename))

      let start =
        SourceLocation(translationUnit: unit, file: file, line: 2, column: 3)
      let end =
        SourceLocation(translationUnit: unit, file: file, line: 4, column: 17)
      let range = SourceRange(start: start, end: end)

      XCTAssertEqual(
        unit.tokens(in: range).map { $0.spelling(in: unit) },
        ["int", "a", "=", "1", ";", "int", "b", "=", "1", ";", "int", "c", "=",
         "a", "+", "b", ";"]
      )
    } catch {
      XCTFail("\(error)")
    }
  }

  func testLocationInitFromOffset() {
    do {
      let filename = "input_tests/locations.c"
      let unit = try TranslationUnit(filename: filename)
      let file = unit.getFile(for: unit.spelling)!

      let start = SourceLocation(translationUnit: unit, file: file, offset: 19)
      let end = SourceLocation(translationUnit: unit, file: file, offset: 59)
      let range = SourceRange(start: start, end: end)

      XCTAssertEqual(
        unit.tokens(in: range).map { $0.spelling(in: unit) },
        ["int", "a", "=", "1", ";", "int", "b", "=", "1", ";", "int", "c", "=",
         "a", "+", "b", ";"]
      )
    } catch {
      XCTFail("\(error)")
    }
  }

  func testIndexAction() {
    do {
      let filename = "input_tests/index-action.c"
      let unit = try TranslationUnit(filename: filename)

      let indexerCallbacks = Clang.IndexerCallbacks()
      var functionsFound = Set<String>()
      indexerCallbacks.indexDeclaration = { decl in
        if decl.cursor is FunctionDecl  {
          functionsFound.insert(decl.cursor!.description)
        }
      }

      try unit.indexTranslationUnit(indexAction: IndexAction(),
                                    indexerCallbacks: indexerCallbacks,
                                    options: .none)

      XCTAssertEqual(functionsFound,
                     Set<String>(arrayLiteral: "main", "didLaunch"))
    } catch {
      XCTFail("\(error)")
    }
  }
      
  func testParsingWithUnsavedFile() {
    do {
      let filename = "input_tests/unsaved-file.c"
      let src = "int main(void) { return 0; }"
      let unsavedFile = UnsavedFile(filename: filename, contents: src)
      let unit = try TranslationUnit(filename: filename,
                                     unsavedFiles: [unsavedFile])

      XCTAssertEqual(
        unit.tokens(in: unit.cursor.range).map { $0.spelling(in: unit) },
        ["int", "main", "(", "void", ")", "{", "return", "0", ";", "}"]
      )
    } catch {
      XCTFail("\(error)")
    }
  }

  func testIsFromMainFile() {
    do {
      let unit = try TranslationUnit(filename: "input_tests/is-from-main-file.c")

      var functions = [Cursor]()
      unit.visitChildren { cursor in
        if cursor is FunctionDecl && cursor.range.start.isFromMainFile {
          functions.append(cursor)
        }
        return .recurse
      }

      XCTAssertEqual(functions.map{$0.description}, ["main"])
    } catch {
      XCTFail("\(error)")

    }
  }

  static var allTests : [(String, (ClangTests) -> () throws -> Void)] {
    return [
      ("testInitUsingStringAsSource", testInitUsingStringAsSource),
      ("testDiagnostic", testDiagnostic),
      ("testUnsavedFile", testUnsavedFile),
      ("testInitFromASTFile", testInitFromASTFile),
      ("testLocationInitFromLineAndColumn", testLocationInitFromLineAndColumn),
      ("testLocationInitFromOffset", testLocationInitFromOffset),
      ("testIndexAction", testIndexAction),
      ("testParsingWithUnsavedFile", testParsingWithUnsavedFile),
      ("testIsFromMainFile", testIsFromMainFile),
    ]
  }
}
