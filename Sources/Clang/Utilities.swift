#if SWIFT_PACKAGE
import cclang
#endif

internal extension Bool {
  func asClang() -> Int32 {
    return self ? 1 : 0
  }
}


extension CXString {
  func asSwiftOptionalNoDispose() -> String? {
    guard self.data != nil else { return nil }
    guard let cStr = clang_getCString(self) else { return nil }
    let swiftStr = String(cString: cStr)
    return swiftStr.isEmpty ? nil : swiftStr
  }
  func asSwiftOptional() -> String? {
    defer { clang_disposeString(self) }
    return asSwiftOptionalNoDispose()
  }
  func asSwiftNoDispose() -> String {
    return asSwiftOptionalNoDispose() ?? ""
  }
  func asSwift() -> String {
    return asSwiftOptional() ?? ""
  }
}

extension Collection where Iterator.Element == String {

  func withUnsafeCStringBuffer<Result>(
    _ f: (UnsafeMutableBufferPointer<UnsafePointer<Int8>?>) throws -> Result)
    rethrows -> Result {
    var arr = [UnsafePointer<Int8>?]()
    defer {
      for cStr in arr {
        free(UnsafeMutablePointer(mutating: cStr))
      }
    }
    for str in self {
      str.withCString { cStr in
        arr.append(UnsafePointer(strdup(cStr)))
      }
    }
    return try arr.withUnsafeMutableBufferPointer { buf in
      return try f(UnsafeMutableBufferPointer(start: buf.baseAddress,
                                              count: buf.count))
    }
  }
}

internal class Box<T> {
  public var value: T
  init(_ value: T) { self.value = value }
}

extension AnyRandomAccessCollection {
  init<T: Strideable & ExpressibleByIntegerLiteral>(count: T, transform: (T) -> Element) {
    self.init(stride(from: 0, to: count, by: 1).lazy.map(transform))
  }
}
