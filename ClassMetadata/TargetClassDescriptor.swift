//
//  TargetClassDescriptor.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/4.
//

import Foundation


struct TargetClassDescriptor {
    // 存储在任何上下文描述符的第一个公共标记
    var Flags: ContextDescriptorFlags

    // 复用的RelativeDirectPointer这个类型，其实并不是，但看下来原理一样
    // 父级上下文，如果是顶级上下文则为null。
    var Parent: RelativeDirectPointer<InProcess>

    // 获取类的名称
    var Name: RelativeDirectPointer<CChar>

    // 这里的函数类型是一个替身，需要调用getAccessFunction()拿到真正的函数指针（这里没有封装），会得到一个MetadataAccessFunction元数据访问函数的指针的包装器类，该函数提供operator()重载以使用正确的调用约定来调用它（可变长参数），意外发现命名重整会调用这边的方法（目前不太了解这块内容）。
    var AccessFunctionPtr: RelativeDirectPointer<UnsafeRawPointer>

    // 一个指向类型的字段描述符的指针(如果有的话)。类型字段的描述，可以从里面获取结构体的属性。
    var Fields: RelativeDirectPointer<FieldDescriptor>
    
    // The type of the superclass, expressed as a mangled type name that can refer to the generic arguments of the subclass type.
    var SuperclassType: RelativeDirectPointer<CChar>
    
    // 下面两个属性在源码中是union类型，所以取size大的类型作为属性（这里貌似一样），具体还得判断是否have a resilient superclass
    
    // 有resilient superclass，用ResilientMetadataBounds，表示对保存元数据扩展的缓存的引用
    var ResilientMetadataBounds: RelativeDirectPointer<TargetStoredClassMetadataBounds>
    // 没有resilient superclass使用MetadataNegativeSizeInWords，表示该类元数据对象的负大小(用字节表示)
    var MetadataNegativeSizeInWords: UInt32 {
        get {
            return UInt32(ResilientMetadataBounds.offset)
        }
    }

    // 有resilient superclass，用ExtraClassFlags，表示一个Objective-C弹性类存根的存在
    var ExtraClassFlags: ExtraClassDescriptorFlags
    // 没有resilient superclass使用MetadataPositiveSizeInWords，表示该类元数据对象的正大小(用字节表示)
    var MetadataPositiveSizeInWords: UInt32 {
        get {
            return ExtraClassFlags.Bits
        }
    }
    
    /**
     此类添加到类元数据的其他成员的数目。默认情况下，这些数据对运行时是不透明的，而不是在其他成员中公开;它实际上只是NumImmediateMembers * sizeof(void*)字节的数据。
     这些字节是添加在地址点之前还是之后，取决于areImmediateMembersNegative()方法。
     */
    var NumImmediateMembers: UInt32
    
    
    // 属性个数，不包含父类的
    var NumFields: Int32
    // 存储这个结构的字段偏移向量的偏移量（记录你属性起始位置的开始的一个相对于metadata的偏移量，具体看metadata的getFieldOffsets方法），如果为0，说明你没有属性
    // 如果这个类含有一个弹性的父类，那么从他的弹性父类的metaData开始偏移
    var FieldOffsetVectorOffset: Int32

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
    var ImmediateMembersOffset: Int
    var Bounds: TargetMetadataBounds
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
