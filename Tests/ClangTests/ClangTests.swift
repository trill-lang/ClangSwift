import XCTest
#if SWIFT_PACKAGE
  import cclang
#endif
@testable import Clang

class ClangTests: XCTestCase {
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

  static var allTests : [(String, (ClangTests) -> () throws -> Void)] {
    return [
      ("testInitUsingStringAsSource", testInitUsingStringAsSource),
      ("testDiagnostic", testDiagnostic),
      ("testUnsavedFile", testUnsavedFile),
      ("testInitFromASTFile", testInitFromASTFile),
    ]
  }
}
