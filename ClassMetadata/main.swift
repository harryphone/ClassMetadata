//
//  main.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/1/21.
//


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

import Foundation

class Person {var name = "Tom";var age = 28};var p = Person()
let mirror = Mirror(reflecting: p)

mirror.children.forEach { print($0) }


class Student: Person {
    var score = 98
}

enum ClassFlags: UInt32 {
    case IsSwiftPreStableABI = 0x1
    case UsesSwiftRefcounting = 0x2
    case HasCustomObjCName = 0x4
    case IsStaticSpecialization = 0x8
    case IsCanonicalStaticSpecialization = 0x10
}


struct ClassMetadata {
    var Kind: UInt
    var Superclass: UnsafeMutablePointer<ClassMetadata>
    var CacheData1: UnsafeMutablePointer<UnsafeRawPointer>
    var CacheData2: UnsafeMutablePointer<UnsafeRawPointer>
    var Data: UnsafeRawPointer
    var Flags: ClassFlags
    var InstanceAddressPoint: UInt32
    var InstanceSize: UInt32
    var InstanceAlignMask: UInt16
    var Reserved: UInt16
    var ClassSize: UInt32
    var ClassAddressPoint: UInt32
    var Description: UnsafeMutablePointer<TargetClassDescriptor>
    var IVarDestroyer: UnsafeMutablePointer<ClassIVarDestroyer>
}

//这个类型是通过当前地址的偏移值获得真正的地址，有点像文件目录，用当前路径的相对路径获得绝对路径。
struct RelativeDirectPointer<T> {
    var offset: Int32 //存放的与当前地址的偏移值

    //通过地址的相对偏移值获得真正的地址
    mutating func get() -> UnsafeMutablePointer<T> {
        let offset = self.offset
        return withUnsafeMutablePointer(to: &self) {
            return UnsafeMutableRawPointer($0).advanced(by: numericCast(offset)).assumingMemoryBound(to: T.self)
        }
    }
}

struct FieldDescriptor {

    enum FieldDescriptorKind: UInt16 {
        case Struct
        case Class
        case Enum
        // Fixed-size multi-payload enums have a special descriptor format that encodes spare bits.
        case MultiPayloadEnum
        // A Swift opaque protocol. There are no fields, just a record for the type itself.
        case kProtocol
        // A Swift class-bound protocol.
        case ClassProtocol
        // An Objective-C protocol, which may be imported or defined in Swift.
        case ObjCProtocol
        // An Objective-C class, which may be imported or defined in Swift.
        // In the former case, field type metadata is not emitted, and must be obtained from the Objective-C runtime.
        case ObjCClass
    }

    var MangledTypeName: RelativeDirectPointer<CChar>//类型命名重整
    var Superclass: RelativeDirectPointer<CChar>//父类名
    var Kind: FieldDescriptorKind//类型，看枚举
    var FieldRecordSize: Int16 //这个值乘上NumFields会拿到RecordSize
    var NumFields: Int32//还是属性个数

    //获取每个属性，得到FieldRecord
    mutating func getField(index: Int) -> UnsafeMutablePointer<FieldRecord> {
        return withUnsafeMutablePointer(to: &self) {
            let arrayPtr = UnsafeMutableRawPointer($0.advanced(by: 1)).assumingMemoryBound(to: FieldRecord.self)
            return arrayPtr.advanced(by: index)
        }
    }
}

struct FieldRecord {

    struct FieldRecordFlags {

        var Data: UInt32

        /// Is this an indirect enum case?
        func isIndirectCase() -> Bool {
            return (Data & 0x1) == 0x1;
        }

        /// Is this a mutable `var` property?
        func isVar() -> Bool {
            return (Data & 0x2) == 0x2;
        }
    }

    var Flags: FieldRecordFlags //标记位
    var MangledTypeName: RelativeDirectPointer<CChar>//类型命名重整
    var FieldName: RelativeDirectPointer<CChar>//属性名
}



struct TargetClassDescriptor {
    // 存储在任何上下文描述符的第一个公共标记
    var Flags: ContextDescriptorFlags

    // 复用的RelativeDirectPointer这个类型，其实并不是，但看下来原理一样
    // 父级上下文，如果是顶级上下文则为null。获得的类型为InProcess，里面存放的应该是一个指针，测下来结构体里为0，相当于null了
    var Parent: RelativeDirectPointer<UInt>

    // 获取Struct的名称
    var Name: RelativeDirectPointer<CChar>

    // 这里的函数类型是一个替身，需要调用getAccessFunction()拿到真正的函数指针（这里没有封装），会得到一个MetadataAccessFunction元数据访问函数的指针的包装器类，该函数提供operator()重载以使用正确的调用约定来调用它（可变长参数），意外发现命名重整会调用这边的方法（目前不太了解这块内容）。
    var AccessFunctionPtr: RelativeDirectPointer<UnsafeRawPointer>

    // 一个指向类型的字段描述符的指针(如果有的话)。类型字段的描述，可以从里面获取结构体的属性。
    var Fields: RelativeDirectPointer<FieldDescriptor>
    
    
    
    var SuperclassType: RelativeDirectPointer<CChar>
    
    // uint32_t MetadataNegativeSizeInWords;
    var ResilientMetadataBounds: RelativeDirectPointer<TargetStoredClassMetadataBounds>
    
    var ExtraClassFlags: ExtraClassDescriptorFlags
    
    var NumImmediateMembers: UInt32
    
    
    // 结构体属性个数
    var NumFields: Int32
    // 存储这个结构的字段偏移向量的偏移量（记录你属性起始位置的开始的一个相对于metadata的偏移量，具体看metadata的getFieldOffsets方法），如果为0，说明你没有属性
    var FieldOffsetVectorOffset: Int32

}

struct ExtraClassDescriptorFlags {
    
    enum kType: Int {
        /// Set if the context descriptor includes a pointer to an Objective-C
        /// resilient class stub structure. See the description of
        /// TargetObjCResilientClassStubInfo in Metadata.h for details.
        ///
        /// Only meaningful for class descriptors when Objective-C interop is
        /// enabled.
        case HasObjCResilientClassStub = 0
    }
    
    typealias IntType = UInt32
    var Bits: IntType
    
    func lowMaskFor(_ BitWidth: Int) -> IntType {
        return IntType((1 << BitWidth) - 1)
    }
    
    func maskFor(_ FirstBit: Int) -> IntType {
        return lowMaskFor(1) << FirstBit
    }
    
    func getFlag(_ Bit: Int) -> Bool {
        return ((Bits & maskFor(Bit)) != 0)
    }
    
    func getField(_ FirstBit: Int, _ BitWidth: Int) -> IntType {
        return IntType((Bits >> FirstBit) & lowMaskFor(BitWidth));
    }
    
}

struct ClassIVarDestroyer {
    
}


struct ContextDescriptorFlags {

    enum ContextDescriptorKind: UInt8 {
        case Module = 0         //表示一个模块
        case Extension          //表示一个扩展
        case Anonymous          //表示一个匿名的可能的泛型上下文，例如函数体
        case kProtocol          //表示一个协议
        case OpaqueType         //表示一个不透明的类型别名
        case Class = 16         //表示一个类
        case Struct             //表示一个结构体
        case Enum               //表示一个枚举
    }

    var Value: UInt32

    /// The kind of context this descriptor describes.
    func getContextDescriptorKind() -> ContextDescriptorKind? {
        return ContextDescriptorKind.init(rawValue: numericCast(Value & 0x1F))
    }

    /// Whether the context being described is generic.
    func isGeneric() -> Bool {
        return (Value & 0x80) != 0
    }

    /// Whether this is a unique record describing the referenced context.
    func isUnique() -> Bool {
        return (Value & 0x40) != 0
    }

    /// The format version of the descriptor. Higher version numbers may have
    /// additional fields that aren't present in older versions.
    func getVersion() -> UInt8 {
        return numericCast((Value >> 8) & 0xFF)
    }

    /// The most significant two bytes of the flags word, which can have
    /// kind-specific meaning.
    func getKindSpecificFlags() -> UInt16 {
        return numericCast((Value >> 16) & 0xFFFF)
    }
}

struct TargetMetadataBounds {

  /// The negative extent of the metadata, in words.
    var NegativeSizeInWords: UInt32
    
  /// The positive extent of the metadata, in words.
    var PositiveSizeInWords: UInt32

  /// Return the total size of the metadata in bytes, including both
  /// negatively- and positively-offset members.
    func getTotalSizeInBytes() -> UInt {
        return (UInt(NegativeSizeInWords) + UInt(PositiveSizeInWords)) * UInt(MemoryLayout<UnsafeRawPointer>.size)
    }

  /// Return the offset of the address point of the metadata from its
  /// start, in bytes.
    func getAddressPointInBytes() -> UInt {
        return UInt(NegativeSizeInWords) * UInt(MemoryLayout<UnsafeRawPointer>.size)
    }
}

struct TargetStoredClassMetadataBounds {
    var ImmediateMembersOffset: UInt
    var Bounds: TargetMetadataBounds
}

func printClassType(_ type: AnyObject.Type) {
    let ptr = unsafeBitCast(type.self as Any.Type, to: UnsafeMutablePointer<ClassMetadata>.self)
//    print("ClassMetadata地址\(ptr)")
//    print(ptr.pointee)
//    print("__________________________________")
    let descriptionptr = ptr.pointee.Description

    let Flags = descriptionptr.pointee.Flags
    print(Flags.getContextDescriptorKind()!)  // 公共标记中获取kind为Struct

    let ParentPtr = descriptionptr.pointee.Parent.get()
    print(ParentPtr.pointee) // 结果为0，说明已经是顶级上下文了

    let structName = descriptionptr.pointee.Name.get()
    print(String(cString: structName)) // 拿到Teacher字符串

    //拿到属性个数，属性名字，属性在内存的起始位置，这样就可以取值，mirror的原理就是这个！！
    let propertyCount = Int(descriptionptr.pointee.NumFields)
    print("属性个数：\(propertyCount)")
    print("---------")
    (0..<propertyCount).forEach {
        let propertyPtr = descriptionptr.pointee.Fields.get().pointee.getField(index: $0)
        print("""
            属性名：\(String(cString: propertyPtr.pointee.FieldName.get()))
            类型命名重整：\(String(cString: propertyPtr.pointee.MangledTypeName.get()))
            是否是var修饰的变量：\(propertyPtr.pointee.Flags.isVar() ? "是" : "否" )
            ---------
            """)
    }
    print("ClassMetadata地址\(ptr)")
    print(ptr.pointee)
    print("__________________________________")
}

printClassType(Person.self)
//printClassType(Student.self)
