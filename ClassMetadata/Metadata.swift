//
//  Metadata.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/4.
//

import Foundation


//struct InProcess {
//  static constexpr size_t PointerSize = sizeof(uintptr_t);
//  using StoredPointer = uintptr_t;
//  using StoredSignedPointer = uintptr_t;
//  using StoredSize = size_t;
//  using StoredPointerDifference = ptrdiff_t;
//
//  static_assert(sizeof(StoredSize) == sizeof(StoredPointerDifference),
//                "target uses differently-sized size_t and ptrdiff_t");
//
//  template <typename T>
//  using Pointer = T*;
//
//  template <typename T>
//  using SignedPointer = T;
//
//  template <typename T, bool Nullable = false>
//  using FarRelativeDirectPointer = FarRelativeDirectPointer<T, Nullable>;
//
//  template <typename T, bool Nullable = false>
//  using RelativeIndirectablePointer =
//    RelativeIndirectablePointer<T, Nullable>;
//
//  template <typename T, bool Nullable = true>
//  using RelativeDirectPointer = RelativeDirectPointer<T, Nullable>;
//};

// 进程内的本机运行时目标。对于运行时中的交互，这应该等同于使用普通的老式指针类型。
// 个人理解下来就是一个指针大小的空间，在OC的Class中就是isa指针，在swift原生类型中放的是MetaKind。相当于在swift中的所有Type，首个指针大小的空间中，存放了区分Type的数据
typealias InProcess = UInt

/// A dependency on the metadata progress of other type, indicating that
/// initialization of a metadata cannot progress until another metadata
/// reaches a particular state.
///
/// For performance, functions returning this type should use SWIFT_CC so
/// that the components are returned as separate values.
struct MetadataDependency {
  /// Either null, indicating that initialization was successful, or
  /// a metadata on which initialization depends for further progress.
    var Value: UnsafePointer<TargetMetadata>

  /// The state that Metadata needs to be in before initialization
  /// can continue.
    typealias MetadataState = InProcess
    var Requirement: MetadataState
}

struct TargetMetadata {
    var Kind: InProcess
}


struct HeapObject {
    var metadata: TargetMetadata
    var refCounts: UInt
    
}

