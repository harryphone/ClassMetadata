//
//  Extension.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/3.
//

import Foundation


extension TargetClassDescriptor {
    
    func getTypeContextDescriptorFlags() -> TypeContextDescriptorFlags {
        return TypeContextDescriptorFlags.init(Bits: Flags.getKindSpecificFlags())
    }
    
    func getResilientSuperclassReferenceKind() -> TypeReferenceKind {
        let MetadataInitialization = TypeContextDescriptorFlags.Specialization.MetadataInitialization.rawValue
        let MetadataInitialization_width = TypeContextDescriptorFlags.Specialization.MetadataInitialization_width.rawValue
        let result = getTypeContextDescriptorFlags().getField(MetadataInitialization, MetadataInitialization_width)
        return TypeReferenceKind.init(rawValue: UInt32(result)) ?? TypeReferenceKind.myEnum
    }
    
    // Are the immediate members of the class metadata allocated at negative offsets instead of positive?
    func areImmediateMembersNegative() -> Bool {
        let Class_AreImmediateMembersNegative = TypeContextDescriptorFlags.Specialization.Class_AreImmediateMembersNegative.rawValue
        let result = getTypeContextDescriptorFlags().getFlag(Class_AreImmediateMembersNegative)
        return result
    }
    
    func hasSingletonMetadataInitialization() -> Bool {
        let referenceKind = TypeContextDescriptorFlags.Specialization.Class_ResilientSuperclassReferenceKind.rawValue
        let referenceKind_width = TypeContextDescriptorFlags.Specialization.Class_ResilientSuperclassReferenceKind_width.rawValue
        let result = getTypeContextDescriptorFlags().getField(referenceKind, referenceKind_width)
        return Int(result) == TypeContextDescriptorFlags.MetadataInitializationKind.SingletonMetadataInitialization.rawValue
    }
    
    func hasForeignMetadataInitialization() -> Bool {
        let referenceKind = TypeContextDescriptorFlags.Specialization.Class_ResilientSuperclassReferenceKind.rawValue
        let referenceKind_width = TypeContextDescriptorFlags.Specialization.Class_ResilientSuperclassReferenceKind_width.rawValue
        let result = getTypeContextDescriptorFlags().getField(referenceKind, referenceKind_width)
        return Int(result) == TypeContextDescriptorFlags.MetadataInitializationKind.ForeignMetadataInitialization.rawValue
    }
    
    func hasVTable() -> Bool {
        let Class_HasVTable = TypeContextDescriptorFlags.Specialization.Class_HasVTable.rawValue
        let result = getTypeContextDescriptorFlags().getFlag(Class_HasVTable)
        return result
    }
    
    func hasOverrideTable() -> Bool {
        let Class_HasOverrideTable = TypeContextDescriptorFlags.Specialization.Class_HasOverrideTable.rawValue
        let result = getTypeContextDescriptorFlags().getFlag(Class_HasOverrideTable)
        return result
    }
    
    func hasResilientSuperclass() -> Bool {
        let Class_HasResilientSuperclass = TypeContextDescriptorFlags.Specialization.Class_HasResilientSuperclass.rawValue
        let result = getTypeContextDescriptorFlags().getFlag(Class_HasResilientSuperclass)
        return result
    }
    
    func hasObjCResilientClassStub() -> Bool {
        if !hasResilientSuperclass() {
            return false
        }
        return ExtraClassFlags.getFlag(ExtraClassDescriptorFlags.kType.HasObjCResilientClassStub.rawValue);
    }
    
    func getNonResilientImmediateMembersOffset() -> Int32 {
        return areImmediateMembersNegative() ? -Int32(MetadataNegativeSizeInWords) : Int32(MetadataPositiveSizeInWords - NumImmediateMembers)
    }
    
    func getNonResilientMetadataBounds() -> TargetClassMetadataBounds {
        return TargetClassMetadataBounds.init(NegativeSizeInWords: MetadataNegativeSizeInWords, PositiveSizeInWords: MetadataPositiveSizeInWords, ImmediateMembersOffset: Int(getNonResilientImmediateMembersOffset())
                                                * MemoryLayout<UnsafeRawPointer>.size)
    }
    
    mutating func getResilientMetadataBounds() -> TargetClassMetadataBounds {
        let Bounds = ResilientMetadataBounds.get().pointee
        return TargetClassMetadataBounds.init(NegativeSizeInWords: Bounds.Bounds.NegativeSizeInWords, PositiveSizeInWords: Bounds.Bounds.PositiveSizeInWords, ImmediateMembersOffset: Bounds.ImmediateMembersOffset)
    }
    
    mutating func getMetadataBounds() -> TargetClassMetadataBounds {
        if !hasResilientSuperclass() {
            return getNonResilientMetadataBounds()
        }
       return getResilientMetadataBounds()
    }
    
    
}

//获取 Tailling  Objects
// 取跟在TargetClassDescriptor后面的数据，不一定有，看count是否为0，如果为0，则为无效的指针，依次取
// 源码里做了内存对齐处理判断，我这里没有，如果某个奇奇怪怪的类调用这里的方法后，发现数据错误或者崩溃，请不要特别奇怪  = =
extension TargetClassDescriptor {
    
    mutating func getTargetTypeGenericContextDescriptorHeaderPointer() -> (resultPtr: UnsafeMutablePointer<TargetTypeGenericContextDescriptorHeader>, count: Int) {
        let pointer = withUnsafeMutablePointer(to: &self) {
            return UnsafeMutableRawPointer($0.advanced(by: 1)).assumingMemoryBound(to: TargetTypeGenericContextDescriptorHeader.self)
        }
        let count = Flags.isGeneric() ?  1 : 0
        return (pointer, count)
    }
    
    mutating func getGenericParamDescriptorPointer() -> (resultPtr: UnsafeMutablePointer<GenericParamDescriptor>, count: Int) {
        let (lastPointer, lastCount) = getTargetTypeGenericContextDescriptorHeaderPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: GenericParamDescriptor.self)
        let count = Flags.isGeneric() ?  Int(lastPointer.pointee.Base.NumParams) : 0
        return (pointer, count)
    }
    
    mutating func getTargetGenericRequirementDescriptorPointer() -> (resultPtr: UnsafeMutablePointer<TargetGenericRequirementDescriptor>, count: Int) {
        let (lastPointer, lastCount) = getGenericParamDescriptorPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetGenericRequirementDescriptor.self)
        let GenericContextDescriptorHeaderPointer = getTargetTypeGenericContextDescriptorHeaderPointer().resultPtr
        let count = Flags.isGeneric() ?  Int(GenericContextDescriptorHeaderPointer.pointee.Base.NumRequirements) : 0
        return (pointer, count)
    }
    
    mutating func getTargetResilientSuperclassPointer() -> (resultPtr: UnsafeMutablePointer<TargetResilientSuperclass>, count: Int) {
        let (lastPointer, lastCount) = getTargetGenericRequirementDescriptorPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetResilientSuperclass.self)
        let count = hasResilientSuperclass() ? 1 : 0
        return (pointer, count)
    }
    
    mutating func getTargetForeignMetadataInitializationPointer() -> (resultPtr: UnsafeMutablePointer<TargetForeignMetadataInitialization>, count: Int) {
        let (lastPointer, lastCount) = getTargetResilientSuperclassPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetForeignMetadataInitialization.self)
        let count = hasForeignMetadataInitialization() ? 1 : 0
        return (pointer, count)
    }
    
    mutating func getTargetSingletonMetadataInitializationPointer() -> (resultPtr: UnsafeMutablePointer<TargetSingletonMetadataInitialization>, count: Int) {
        let (lastPointer, lastCount) = getTargetForeignMetadataInitializationPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetSingletonMetadataInitialization.self)
        let count = hasSingletonMetadataInitialization() ? 1 : 0
        return (pointer, count)
    }
    
    mutating func getTargetVTableDescriptorHeaderPointer() -> (resultPtr: UnsafeMutablePointer<TargetVTableDescriptorHeader>, count: Int) {
        let (lastPointer, lastCount) = getTargetSingletonMetadataInitializationPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetVTableDescriptorHeader.self)
        let count = hasVTable() ? 1 : 0
        return (pointer, count)
    }
    
    mutating func getTargetMethodDescriptorPointer() -> (resultPtr: UnsafeMutablePointer<TargetMethodDescriptor>, count: Int) {
        let (lastPointer, lastCount) = getTargetVTableDescriptorHeaderPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetMethodDescriptor.self)
        let count = hasVTable() ? Int(lastPointer.pointee.VTableSize) : 0
        return (pointer, count)
    }
    
    mutating func getTargetOverrideTableHeaderPointer() -> (resultPtr: UnsafeMutablePointer<TargetOverrideTableHeader>, count: Int) {
        let (lastPointer, lastCount) = getTargetMethodDescriptorPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetOverrideTableHeader.self)
        let count = hasOverrideTable() ? 1 : 0
        return (pointer, count)
    }
    
    mutating func getTargetMethodOverrideDescriptorPointer() -> (resultPtr: UnsafeMutablePointer<TargetMethodOverrideDescriptor>, count: Int) {
        let (lastPointer, lastCount) = getTargetOverrideTableHeaderPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetMethodOverrideDescriptor.self)
        let count = hasOverrideTable() ? Int(lastPointer.pointee.NumEntries) : 0
        return (pointer, count)
    }
    
    mutating func getTargetObjCResilientClassStubInfoPointer() -> (resultPtr: UnsafeMutablePointer<TargetObjCResilientClassStubInfo>, count: Int) {
        let (lastPointer, lastCount) = getTargetMethodOverrideDescriptorPointer()
        let pointer = UnsafeMutableRawPointer(lastPointer.advanced(by: lastCount)).assumingMemoryBound(to: TargetObjCResilientClassStubInfo.self)
        let count = hasObjCResilientClassStub() ? 1 : 0
        return (pointer, count)
    }
}

/// Kinds of type metadata/protocol conformance records.
enum TypeReferenceKind: UInt32 {
    // The conformance is for a nominal type referenced directly; getTypeDescriptor() points to the type context descriptor.
    case DirectTypeDescriptor = 0x00
    // The conformance is for a nominal type referenced indirectly; getTypeDescriptor() points to the type context descriptor.
    case IndirectTypeDescriptor = 0x01
    // The conformance is for an Objective-C class that should be looked up by class name.
    case DirectObjCClassName = 0x02
    // The conformance is for an Objective-C class that has no nominal type descriptor. getIndirectObjCClass() points to a variable that contains the pointer to the class object, which then requires a runtime call to get metadata.  On platforms without Objective-C interoperability, this case is unused.
    case IndirectObjCClass = 0x03
    
    // 我自己写的，做容错处理
    case myEnum = 0x04
}



// The bounds of a class metadata object.
// This type is a currency type and is not part of the ABI. See TargetStoredClassMetadataBounds for the type of the class metadata bounds variable.
struct TargetClassMetadataBounds {
    // The negative extent of the metadata, in words.
    var NegativeSizeInWords: UInt32
    
    // The positive extent of the metadata, in words.
    var PositiveSizeInWords: UInt32
    
    // The offset from the address point of the metadata to the immediate members.
    var ImmediateMembersOffset: Int
    
    // Return the total size of the metadata in bytes, including both negatively- and positively-offset members.
    func getTotalSizeInBytes() -> UInt {
        return (UInt(NegativeSizeInWords) + UInt(PositiveSizeInWords)) * UInt(MemoryLayout<UnsafeRawPointer>.size)
    }
    
    // Return the offset of the address point of the metadata from its start, in bytes.
    func getAddressPointInBytes() -> UInt {
        return UInt(NegativeSizeInWords) * UInt(MemoryLayout<UnsafeRawPointer>.size)
    }
    
}




