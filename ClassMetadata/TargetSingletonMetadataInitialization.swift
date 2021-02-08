//
//  TargetSingletonMetadataInitialization.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/5.
//

import Foundation

// The control structure for performing non-trivial initialization of singleton value metadata, which is required when e.g. a non-generic value type has a resilient component type.
struct TargetSingletonMetadataInitialization {
    // The initialization cache.  Out-of-line because mutable.
    var InitializationCache: RelativeDirectPointer<TargetSingletonMetadataCache>
    // The incomplete metadata, for structs, enums and classes without resilient ancestry.
    var IncompleteMetadata: RelativeDirectPointer<TargetMetadata>
    // If the class descriptor's hasResilientSuperclass() flag is set, this field instead points at a pattern used to allocate and initialize metadata for this class, since it's size and contents is not known at compile time.
    var ResilientPattern: RelativeDirectPointer<TargetResilientClassMetadataPattern> {
        return unsafeBitCast(self.IncompleteMetadata as Any, to: RelativeDirectPointer<TargetResilientClassMetadataPattern>.self)
    }
    var CompletionFunction: RelativeDirectPointer<MetadataDependency>
}


// An instantiation pattern for non-generic resilient class metadata.
// Used for classes with resilient ancestry, that is, where at least one ancestor is defined in a different resilience domain.
// The hasResilientSuperclass() flag in the class context descriptor is set in this case, and hasSingletonMetadataInitialization() must be set as well.
// The pattern is referenced from the SingletonMetadataInitialization record in the class context descriptor.
struct TargetResilientClassMetadataPattern {
    // A function that allocates metadata with the correct size at runtime.
    // If this is null, the runtime instead calls swift_relocateClassMetadata(), passing in the class descriptor and this pattern.
    var RelocationFunction: RelativeDirectPointer<TargetMetadata>


  // The heap-destructor function.
    var Destroy: RelativeDirectPointer<HeapObjectDestroyer>

  // The ivar-destructor function.
    var IVarDestroyer: RelativeDirectPointer<ClassIVarDestroyer>

  // The class flags.
    var Flags: ClassFlags

  // The following fields are only present in ObjC interop.

  // Our ClassROData.
    var Data: RelativeDirectPointer<UnsafeMutableRawPointer>

  // Our metaclass.
    var Metaclass: RelativeDirectPointer<TargetAnyClassMetadata>
};



// The cache structure for non-trivial initialization of singleton value metadata.
struct TargetSingletonMetadataCache {
    // The metadata pointer.  Clients can do dependency-ordered loads from this, and if they see a non-zero value, it's a Complete metadata.
    var Metadata: UnsafeMutablePointer<TargetMetadata>

    // The private cache data.
    var Private: UnsafeMutableRawPointer
};

typealias HeapObjectDestroyer = UnsafeMutablePointer<HeapObject>

