//
//  File.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/4.
//

import Foundation

protocol FlagSet {
    associatedtype IntType : FixedWidthInteger
    var Bits: IntType { get set }
    
    func lowMaskFor(_ BitWidth: Int) -> IntType
    
    func maskFor(_ FirstBit: Int) -> IntType
    
    func getFlag(_ Bit: Int) -> Bool
    
    func getField(_ FirstBit: Int, _ BitWidth: Int) -> IntType
}

extension FlagSet {
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

// Flags for nominal type context descriptors. These values are used as the kindSpecificFlags of the ContextDescriptorFlags for the type.
struct TypeContextDescriptorFlags: FlagSet {
    
    typealias IntType = UInt16
    var Bits: IntType
    
    // All of these values are bit offsets or widths.
    // Generic flags build upwards from 0.
    // Type-specific flags build downwards from 15.
    enum Specialization: Int {
        // Whether there's something unusual about how the metadata is initialized.
        // Meaningful for all type-descriptor kinds.
        case MetadataInitialization = 0
        // 这里枚举值2表示两个意思，还有一个是HasImportInfo，下面是HasImportInfo的释意
        // Set if the type has extended import information.
        // If true, a sequence of strings follow the null terminator in the descriptor, terminated by an empty string (i.e. by two null terminators in a row).  See TypeImportInfo for the details of these strings and the order in which they appear.
        case MetadataInitialization_width = 2 //HasImportInfo
        
        // The kind of reference that this class makes to its resilient superclass descriptor.  A TypeReferenceKind.
        // Only meaningful for class descriptors.
        case Class_ResilientSuperclassReferenceKind = 9
        case Class_ResilientSuperclassReferenceKind_width = 3
        
        // Whether the immediate class members in this metadata are allocated at negative offsets.  For now, we don't use this.
        case Class_AreImmediateMembersNegative = 12
        
        // Set if the context descriptor is for a class with resilient ancestry.
        // Only meaningful for class descriptors.
        case Class_HasResilientSuperclass = 13
        
        // Set if the context descriptor includes metadata for dynamically installing method overrides at metadata instantiation time.
        case Class_HasOverrideTable = 14
        
        // Set if the context descriptor includes metadata for dynamically constructing a class's vtables at metadata instantiation time.
        // Only meaningful for class descriptors.
        case Class_HasVTable = 15
    }
    
    enum MetadataInitializationKind: Int {
        // There are either no special rules for initializing the metadata or the metadata is generic.  (Genericity is set in the non-kind-specific descriptor flags.)
        case NoMetadataInitialization = 0
        // The type requires non-trivial singleton initialization using the "in-place" code pattern.
        case SingletonMetadataInitialization = 1
        
        // The type requires non-trivial singleton initialization using the "foreign" code pattern.
        case ForeignMetadataInitialization = 2
    }
    
}


struct GenericMetadataPatternFlags: FlagSet {
    
    enum Pattern: Int {
        // All of these values are bit offsets or widths.
        // General flags build up from 0.
        // Kind-specific flags build down from 31.

        /// Does this pattern have an extra-data pattern?
        case HasExtraDataPattern = 0

        /// Do instances of this pattern have a bitset of flags that occur at the
        /// end of the metadata, after the extra data if there is any?
        case HasTrailingFlags = 1

        // Class-specific flags.

        /// Does this pattern have an immediate-members pattern?
        case Class_HasImmediateMembersPattern = 31

        // Value-specific flags.

        /// For value metadata: the metadata kind of the type.
        case Value_MetadataKind = 21
        case Value_MetadataKind_width = 11
      };
    
    typealias IntType = UInt32
    var Bits: IntType
}

// Flags for protocol context descriptors. These values are used as the kindSpecificFlags of the ContextDescriptorFlags for the protocol.
struct ProtocolContextDescriptorFlags: FlagSet {
    
    enum Pattern: Int {
        // Whether this protocol is class-constrained.
        case HasClassConstraint = 0
        case HasClassConstraint_width = 1
        
        // 还有个枚举值也是1，叫：IsResilient，表示的是：Whether this protocol is resilient.

        // Special protocol value.
        case SpecialProtocolKind = 2
        case SpecialProtocolKind_width = 6
      };
    
    typealias IntType = UInt16
    var Bits: IntType
}

struct ExtraClassDescriptorFlags: FlagSet {
    
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
    
}



