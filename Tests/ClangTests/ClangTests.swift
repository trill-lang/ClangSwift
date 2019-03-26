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
  
  func testVisitInclusion() {
    func fileName(_ file: File) -> String {
        return file.name.components(separatedBy: "/").last!
    }
    do {
      let inclusionEx = [
        ["inclusion.c"],
        ["inclusion-header.h", "inclusion.c"],
      ]
      let unit = try TranslationUnit(filename: "input_tests/inclusion.c")
      var inclusion: [[String]] = []
      unit.visitInclusion { file, stack in
        let inc = [fileName(file)] + stack.map { fileName($0.file) }
        inclusion.append(inc)
      }
      XCTAssertEqual(inclusion, inclusionEx)
    } catch {
      XCTFail("\(error)")
    }
  }
    
    func testGetFile() {
        do {
            let fileName = "input_tests/init-ast.c"
            let unit = try TranslationUnit(filename: fileName)
            XCTAssertNotNil(unit.getFile(for: fileName))
            XCTAssertNil(unit.getFile(for: "42"))
        } catch {
            XCTFail("\(error)")
        }
    }
  
  func testDisposeTranslateUnit() {
    do {
      let filename = "input_tests/init-ast.c"
      let unit = try TranslationUnit(filename: filename)
      let cursor = unit.cursor
      for _ in 0..<2 {
        _ = cursor.translationUnit
      }
    } catch {
      XCTFail("\(error)")
    }
  }
  
  // ${projectRoot}/ folder URL.
  var projectRoot: URL {
    return URL(fileURLWithPath: #file).appendingPathComponent("../../../", isDirectory: true).standardized
  }
  
  // ${projectRoot}/input_tests folder URL.
  var inputTestUrl: URL {
    return projectRoot.appendingPathComponent("input_tests", isDirectory: true)
  }
  
  // ${projectRoot}/.build/build.input_tests folder URL
  var buildUrl: URL {
    return projectRoot.appendingPathComponent(".build/build.input_tests", isDirectory: true)
  }
  
  func testInitCompilationDB() {
    do {
      let db = try CompilationDatabase(directory: buildUrl.path)
      XCTAssertNotNil(db)
      XCTAssertEqual(db.compileCommands.count, 7)
      
    } catch {
      XCTFail("\(error)")
    }
  }
  
  func testCompileCommand() {
    do {
      // intialize CompilationDatabase.
      let db = try CompilationDatabase(directory: buildUrl.path)
      XCTAssertNotNil(db)
      
      // test first compileCommand
      let cmd = db.compileCommands[0]
      XCTAssertEqual(cmd.directory, buildUrl.path)
      XCTAssertGreaterThan(cmd.arguments.count, 0)
      
      // test all compileCommands
      let filenames = db.compileCommands.map { URL(fileURLWithPath: $0.filename) }
      
      let expectation: Set<URL> = [
        inputTestUrl.appendingPathComponent("inclusion.c"),
        inputTestUrl.appendingPathComponent("index-action.c"),
        inputTestUrl.appendingPathComponent("init-ast.c"),
        inputTestUrl.appendingPathComponent("is-from-main-file.c"),
        inputTestUrl.appendingPathComponent("locations.c"),
        inputTestUrl.appendingPathComponent("reparse.c"),
        inputTestUrl.appendingPathComponent("unsaved-file.c"),
      ]
      XCTAssertEqual(Set(filenames), expectation)
    } catch {
      XCTFail("\(error)")
    }
  }
  
  func testCompileCommandForFile() {
    do {
      // intialize CompilationDatabase.
      let db = try CompilationDatabase(directory: buildUrl.path)
      XCTAssertNotNil(db)
      
      let inclusionFile = inputTestUrl.appendingPathComponent("inclusion.c")
      
      // test compileCommand for file `inclusion.c`
      let cmds = db.compileCommands(forFile: inclusionFile.path)
      XCTAssertEqual(cmds.count, 1)
      XCTAssertEqual(cmds[0].filename, inclusionFile.path)
      XCTAssertEqual(cmds[0].directory, buildUrl.path)
      XCTAssertGreaterThan(cmds[0].arguments.count, 0)
    } catch {
      XCTFail("\(error)")
    }
  }
  
  func testInitTranslationUnitUsingCompileCommand() {
    do {
      // intialize CompilationDatabase.
      let filename = inputTestUrl.path + "/locations.c"
      let db = try CompilationDatabase(directory: buildUrl.path)
      
      // get first compile command and initialize TranslationUnit using it.
      let cmd = db.compileCommands(forFile: filename).first!
      let unit = try TranslationUnit(compileCommand: cmd)
      
      // verify.
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
      ("testVisitInclusion", testVisitInclusion),
      ("testGetFile", testGetFile),
      ("testInitCompilationDB", testInitCompilationDB),
      ("testCompileCommand", testCompileCommand),
      ("testCompileCommandForFile", testCompileCommandForFile),
      ("testInitTranslationUnitUsingCompileCommand", testInitTranslationUnitUsingCompileCommand)
    ]
  }
}
