//
//  TargetVTableDescriptorHeader.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/5.
//

import Foundation


// 类vtable描述符的头文件。这是一个可变大小的结构，用于描述如何在类的类型元数据中查找和解析虚函数表。
struct TargetVTableDescriptorHeader {
    // The offset of the vtable for this class in its metadata, if any, in words.
    // If this class has a resilient superclass, this offset is relative to the start of the immediate class's metadata. Otherwise, it is relative to the metadata address point.
    var VTableOffset: UInt32
    
    // The number of vtable entries. This is the number of MethodDescriptor records following the vtable header in the class's nominal type descriptor, which is equal to the number of words this subclass's vtable entries occupy in instantiated class metadata.
    var VTableSize: UInt32
    
    func getVTableOffset(description: UnsafeMutablePointer<TargetClassDescriptor>) -> UInt32 {
        if description.pointee.hasResilientSuperclass() {
            let bounds = description.pointee.getMetadataBounds()
            return UInt32(bounds.ImmediateMembersOffset / MemoryLayout<UnsafeRawPointer>.size) + VTableOffset
        }
        
        return VTableOffset
    }
}
