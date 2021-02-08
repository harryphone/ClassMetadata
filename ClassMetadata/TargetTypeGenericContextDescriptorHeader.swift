//
//  TargetTypeGenericContextDescriptorHeader.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/4.
//

import Foundation


struct TargetTypeGenericContextDescriptorHeader {
    /// The metadata instantiation cache.
    var InstantiationCache: RelativeDirectPointer<TargetGenericMetadataInstantiationCache>
    var DefaultInstantiationPattern: RelativeDirectPointer<TargetGenericMetadataPattern>
    /// The base header.  Must always be the final member.
    var Base: TargetGenericContextDescriptorHeader
}

/// The instantiation cache for generic metadata.  This must be guaranteed
/// to zero-initialized before it is first accessed.  Its contents are private
/// to the runtime.
struct TargetGenericMetadataInstantiationCache {
  /// Data that the runtime can use for its own purposes.  It is guaranteed
  /// to be zero-filled by the compiler.
//  TargetPointer<Runtime, void>
//  PrivateData[swift::NumGenericMetadataPrivateDataWords];
    var PrivateData: UnsafePointer<UnsafeRawPointer>
}

struct TargetGenericContextDescriptorHeader {
    var NumParams: UInt16
    var NumRequirements: UInt16
    var NumKeyArguments: UInt16
    var NumExtraArguments: UInt16
 
    func getNumArguments() -> UInt32 {
        return numericCast(NumKeyArguments + NumExtraArguments)
    }
    
    func hasArguments() -> Bool {
        return getNumArguments() > 0
    }
}

/// An instantiation pattern for type metadata.
struct TargetGenericMetadataPattern {
  /// The function to call to instantiate the template.
//    var InstantiationFunction: RelativeDirectPointer<MetadataInstantiator>
    var InstantiationFunction: RelativeDirectPointer<TargetMetadata>

  /// The function to call to complete the instantiation.  If this is null,
  /// the instantiation function must always generate complete metadata.

    var CompletionFunction: RelativeDirectPointer<MetadataDependency>

  /// Flags describing the layout of this instantiation pattern.
    var PatternFlags: GenericMetadataPatternFlags

//  bool hasExtraDataPattern() const {
//    return PatternFlags.hasExtraDataPattern();
//  }
};
