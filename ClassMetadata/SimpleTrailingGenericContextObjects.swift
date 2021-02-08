//
//  SimpleTrailingGenericContextObjects.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/5.
//

import Foundation


// An opaque descriptor describing a class or protocol method. References to these descriptors appear in the method override table of a class context descriptor, or a resilient witness table pattern, respectively.
// Clients should not assume anything about the contents of this descriptor other than it having 4 byte alignment.
struct TargetMethodDescriptor {
    // Flags describing the method.
    var Flags: MethodDescriptorFlags
    // The method implementation.
    var Impl: RelativeDirectPointer<UnsafeMutableRawPointer>
}

struct MethodDescriptorFlags {
    enum Kind {
        case Method
        case Init
        case Getter
        case Setter
        case ModifyCoroutine
        case ReadCoroutine
    }
    enum Mask: UInt32 {
        case KindMask = 0x0F
        case IsInstanceMask = 0x10
        case IsDynamicMask = 0x20
//        case ExtraDiscriminatorShift = 16
        case ExtraDiscriminatorMask = 0xFFFF0000
    }
    
    var Value: UInt32
}


// Header for a class vtable override descriptor. This is a variable-sized structure that provides implementations for overrides of methods defined in superclasses.
struct TargetOverrideTableHeader {
    // The number of MethodOverrideDescriptor records following the vtable override header in the class's nominal type descriptor.
    var NumEntries: UInt32
};

// An entry in the method override table, referencing a method from one of our ancestor classes, together with an implementation.
struct TargetMethodOverrideDescriptor {
    // The class containing the base method.
    var Class: RelativeIndirectablePointer<UnsafeMutableRawPointer>
    // The base method.
    var Method: RelativeIndirectablePointer<UnsafeMutableRawPointer>
    // The implementation of the override.
    var Impl: RelativeDirectPointer<UnsafeMutableRawPointer>
}


// The control structure for performing non-trivial initialization of singleton foreign metadata.
struct TargetForeignMetadataInitialization {
    // The completion function.  The pattern will always be null.
    var CompletionFunction: RelativeDirectPointer<MetadataDependency>
}


struct TargetProtocolDescriptor {
    // 存储在任何上下文描述符的第一个公共标记
    var Flags: ContextDescriptorFlags

    // 复用的RelativeDirectPointer这个类型，其实并不是，但看下来原理一样
    // 父级上下文，如果是顶级上下文则为null。
    var Parent: RelativeDirectPointer<InProcess>
    
    // The name of the protocol.
    var Name: RelativeDirectPointer<CChar>
    
    // The number of generic requirements in the requirement signature of the protocol.
    var NumRequirementsInSignature: UInt32
    
    // The number of requirements in the protocol.
    // If any requirements beyond MinimumWitnessTableSizeInWords are present in the witness table template, they will be not be overwritten with defaults.
    var NumRequirements: UInt32
    
    // Associated type names, as a space-separated list in the same order as the requirements
    var AssociatedTypeNames: RelativeDirectPointer<CChar>
    
    func getProtocolContextDescriptorFlags() -> ProtocolContextDescriptorFlags {
        return ProtocolContextDescriptorFlags.init(Bits: Flags.getKindSpecificFlags())
    }
}


struct GenericParamDescriptor {
    var Value: UInt8
    
    func hasKeyArgument() -> Bool {
        return (Value & 0x80) != 0
    }
    
    func hasExtraArgument() -> Bool {
        return (Value & 0x40) != 0
    }
    
    func getKind() -> GenericParamKind {
        return GenericParamKind.init(rawValue: Value & 0x3F) ?? GenericParamKind.unknow
    }
}

enum GenericParamKind: UInt8 {
    case kType = 0
    case kMax = 0x3F
    // 自己定义
    case unknow
}

struct TargetResilientSuperclass {
    // The superclass of this class.  This pointer can be interpreted using the superclass reference kind stored in the type context descriptor flags.  It is null if the class has no formal superclass.
    // Note that SwiftObject, the implicit superclass of all Swift root classes when building with ObjC compatibility, does not appear here.
    var Superclass: RelativeDirectPointer<UnsafeMutableRawPointer>
}


// A structure that stores a reference to an Objective-C class stub.
// This is not the class stub itself; it is part of a class context descriptor.
struct TargetObjCResilientClassStubInfo {
    
    // A relative pointer to an Objective-C resilient class stub.
    // We do not declare a struct type for class stubs since the Swift runtime does not need to interpret them. The class stub struct is part of the Objective-C ABI, and is laid out as follows:
    // - isa pointer, always 1
    // - an update callback, of type 'Class (*)(Class *, objc_class_stub *)'
    
    // Class stubs are used for two purposes:
    // - Objective-C can reference class stubs when calling static methods.
    // - Objective-C and Swift can reference class stubs when emitting  categories (in Swift, extensions with @objc members).
    var Stub: RelativeDirectPointer<UnsafeMutableRawPointer>
}
