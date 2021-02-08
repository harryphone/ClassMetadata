//
//  TargetGenericRequirementDescriptor.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/4.
//

import Foundation


struct TargetGenericRequirementDescriptor {
    var Flags: GenericRequirementFlags
    // The type that's constrained, described as a mangled name.
    var Param: RelativeDirectPointer<CChar>
    
    // 这里是union，但其他类型都是相对位移的对象，但我们都是结构体，所以注意被值复制了，值所在的地址被改了。
    // The kind of layout constraint.
    // Only valid if the requirement has Layout kind.
    var Layout: UInt32
    
    // A mangled representation of the same-type or base class the param is constrained to.
    // Only valid if the requirement has SameType or BaseClass kind.
    var kType: RelativeDirectPointer<CChar> {
        return unsafeBitCast(self.Layout as Any, to: RelativeDirectPointer<CChar>.self)
    }
    // The protocol the param is constrained to.
    // Only valid if the requirement has Protocol kind.
    var kProtocol: RelativeTargetProtocolDescriptorPointer {
        return unsafeBitCast(self.Layout as Any, to: RelativeTargetProtocolDescriptorPointer.self)
    }
    // The conformance the param is constrained to use.
    // Only valid if the requirement has SameConformance kind.
    var Conformance: RelativeIndirectablePointer<TargetProtocolConformanceDescriptor> {
        return unsafeBitCast(self.Layout as Any, to: RelativeIndirectablePointer<TargetProtocolConformanceDescriptor>.self)
    }
}

struct GenericRequirementFlags {
    var Value: UInt32
    
    func hasKeyArgument() -> Bool {
        return (Value & 0x80) != 0
    }
    
    func hasExtraArgument() -> Bool {
        return (Value & 0x40) != 0
    }
    
    func getKind() -> GenericRequirementKind {
        return GenericRequirementKind.init(rawValue: UInt8(Value & 0x1F)) ?? GenericRequirementKind.unknow
    }
}

enum GenericRequirementKind: UInt8 {
    
    // A protocol requirement.
    case kProtocol = 0
    // A same-type requirement.
    case SameType = 1
    // A base class requirement.
    case BaseClass = 2
    // A "same-conformance" requirement, implied by a same-type or base-class constraint that binds a parameter with protocol requirements.
    case SameConformance = 3
    // A layout constraint.
    case Layout = 0x1F
    // 自己定义
    case unknow
}

// A relative pointer to a protocol descriptor, which provides the relative-pointer equivalent to \c TargetProtocolDescriptorRef.
struct RelativeTargetProtocolDescriptorPointer {
    // Relative pointer to an ObjC protocol descriptor. The \c bool value will be false to indicate that the protocol is a Swift protocol, or true to indicate that this references an Objective-C protocol.
    // 这里也是一个union，在swift中的协议是swiftPointer，如果是oc的协议那么变成了：
    // var objcPointer: RelativeIndirectablePointerIntPair<Protocol>，Protocol就是runtime文件里的Protocol，这里就不翻译了。
    var swiftPointer: RelativeIndirectablePointerIntPair<TargetProtocolDescriptor>
    
    func isObjC() -> Bool {
        return (swiftPointer.getInt() != 0);
    }
    
    mutating func getProtocol() -> TargetProtocolDescriptorRef {
        let storage = InProcess(bitPattern: swiftPointer.getPointer())
        return TargetProtocolDescriptorRef.init(storage: storage)
    }
}

// A reference to a protocol within the runtime, which may be either a Swift protocol or (when Objective-C interoperability is enabled) an Objective-C protocol.
// This type always contains a single target pointer, whose lowest bit is used to distinguish between a Swift protocol referent and an Objective-C protocol referent.
struct TargetProtocolDescriptorRef { //这里的OC协议都过滤了
    // A direct pointer to a protocol descriptor for either an Objective-C protocol (if the low bit is set) or a Swift protocol (if the low bit is clear).
    var storage: InProcess
    // The bit used to indicate whether this is an Objective-C protocol.
    static let IsObjCBit = 0x1
    
    mutating func getSwiftProtocol() -> UnsafeMutablePointer<TargetProtocolDescriptor> {
        let value: InProcess = (storage & ~InProcess(TargetProtocolDescriptorRef.IsObjCBit))
        return UnsafeMutablePointer<TargetProtocolDescriptor>(bitPattern: value)!
    }
}




struct RelativeIndirectablePointerIntPair<T> {
    var RelativeOffsetPlusIndirectAndInt: Int32
    
    func getIntMask() -> Int32 {
        return (Int32(MemoryLayout<Int32>.alignment) - 1) & ~Int32(0x01)
    }
    
    func getInt() -> Int32 {
        return (RelativeOffsetPlusIndirectAndInt & getIntMask()) >> 1
    }
    
    func isNull() -> Bool {
        return (RelativeOffsetPlusIndirectAndInt & ~getIntMask()) == 0
    }
    
    mutating func getPointer() -> UnsafeMutablePointer<T> {
        let offset = (RelativeOffsetPlusIndirectAndInt & ~getIntMask()) & ~1
        return withUnsafeMutablePointer(to: &self) {
            return UnsafeMutableRawPointer($0).advanced(by: numericCast(offset)).assumingMemoryBound(to: T.self)
        }
    }
}


struct RelativeIndirectablePointer<T> {
    var RelativeOffsetPlusIndirect: Int32 //存放的与当前地址的偏移值

    //通过地址的相对偏移值获得真正的地址
    mutating func get() -> UnsafeMutablePointer<T> {
        let offsetPlusIndirect = RelativeOffsetPlusIndirect & ~1
        return withUnsafeMutablePointer(to: &self) {
            return UnsafeMutableRawPointer($0).advanced(by: numericCast(offsetPlusIndirect)).assumingMemoryBound(to: T.self)
        }
    }
}

struct TargetProtocolConformanceDescriptor {
    // The protocol being conformed to.
    var kProtocol: RelativeIndirectablePointer<TargetProtocolDescriptor>
    // Some description of the type that conforms to the protocol.
    var TypeRef: TargetTypeReference
    // The witness table pattern, which may also serve as the witness table.
    var WitnessTablePattern: RelativeDirectPointer<TargetWitnessTable>
    // Various flags, including the kind of conformance.
    var Flags: ConformanceFlags
}

// 吐了 ，不想写了，里面又是一个union，感兴趣的自己看源码
struct TargetTypeReference {
    var offset: Int32
}


// A witness table for a protocol.
// With the exception of the initial protocol conformance descriptor,  the layout of a witness table is dependent on the protocol being represented.
struct TargetWitnessTable {
    // The protocol conformance descriptor from which this witness table was generated.
    var Description: UnsafeMutablePointer<TargetProtocolConformanceDescriptor>
}

struct ConformanceFlags {
    
    var Value: UInt32
    
    enum Flags: UInt32 {
        case UnusedLowBits = 0x07 // historical conformance kind
        
        case TypeMetadataKindMask = 0x38 //0x07 << 3 // 8 type reference kinds
        case TypeMetadataKindShift = 3
        
        case IsRetroactiveMask = 0x40 // 0x01 << 6
        case IsSynthesizedNonUniqueMask = 0x80 //0x01 << 7
        
        case NumConditionalRequirementsMask = 0xFF00 //0xFF << 8
        case NumConditionalRequirementsShift = 8
        
        case HasResilientWitnessesMask = 0x400000 //0x01 << 16
        case HasGenericWitnessTableMask = 0x800000 //0x01 << 17
    }

}



