//
//  ClassMetadata.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/2/3.
//

import Foundation


// swift的类标示，这些标示只有在isTypeMetadata()时才有效
struct ClassFlags: OptionSet {
    let rawValue: UInt32
    
    // 这个swift class是不是来自于ABI稳定之前？如果是在稳定的ABI中，这个值应该为0，Objective-C runtime也可以读取这个bit位
    static let IsSwiftPreStableABI    = ClassFlags(rawValue: 0x1)
    // 是否用了swift的引用计数
    static let UsesSwiftRefcounting  = ClassFlags(rawValue: 0x2)
    // 这个类是否自定义名称，用@objc属性指定
    static let HasCustomObjCName   = ClassFlags(rawValue: 0x4)
    // 该元数据是否是编译期间创建的通用元数据模式的专门化。
    static let IsStaticSpecialization   = ClassFlags(rawValue: 0x8)
    // 该元数据是否是编译期间创建的通用元数据模式的专门化，并通过修改元数据访问器使其规范化。
    static let IsCanonicalStaticSpecialization   = ClassFlags(rawValue: 0x10)

}

// Swift中的class的metadata兼容OC的类
struct ClassMetadata {
    // 在oc中放的就是isa，在swift中kind大于0x7FF表示的就是类
    var Kind: InProcess
    // 父类的Metadata，如果是null说明是最顶级的类了
    var Superclass: UnsafeMutablePointer<ClassMetadata>
    // 缓存数据用于某些动态查找，它由运行时拥有，通常需要与Objective-C的使用进行互操作。（说到底就是OC的东西）
    var CacheData1: UnsafeMutablePointer<UnsafeRawPointer>
    var CacheData2: UnsafeMutablePointer<UnsafeRawPointer>
    // 除了编译器设置低位以表明这是Swift元类型外，这个data里存的指针，用于行外元数据，通常是不透明的（应该也是OC的）
    var Data: InProcess
    
    // 该对象是否是有效的swift类型元数据? 也就是说，它可以安全地向下转换到类元数据(ClassMetadata)吗?
    func isTypeMetadata() -> Bool {
        return ((Data & 2) != 0)
    }
    
    func isPureObjC() -> Bool {
        return !isTypeMetadata()
    }
    
    /**
     源码中
     上面的字段都是TargetAnyClassMetadata父类的，类元数据对象中与所有类兼容的部分，即使是非swift类。
     下面的字段都是TargetClassMetadata的，只有在isTypeMetadata()时才有效，所以在源码在使用时都比较小心，会经常调用isTypeMetadata()
     Objective-C运行时知道下面字段的偏移量
     */
    
    // Swift-specific class flags.
    var Flags: ClassFlags
    // The address point of instances of this type.
    var InstanceAddressPoint: UInt32
    // The required size of instances of this type.(实例对象在堆内存的大小)
    var InstanceSize: UInt32
    // The alignment mask of the address point of instances of this type. (根据这个mask来获取内存中的对齐大小)
    var InstanceAlignMask: UInt16
    // Reserved for runtime use.（预留给运行时使用）
    var Reserved: UInt16
    // The total size of the class object, including prefix and suffix extents.
    var ClassSize: UInt32
    // The offset of the address point within the class object.
    var ClassAddressPoint: UInt32
    // 一个对类型的超行的swift特定描述，如果这是一个人工子类，则为null。目前不提供动态创建非人工子类的机制。
    var Description: UnsafeMutablePointer<TargetClassDescriptor>
    // 销毁实例变量的函数，用于在构造函数早期返回后进行清理。如果为null，则不会执行清理操作，并且所有的ivars都必须是简单的。
    var IVarDestroyer: UnsafeMutablePointer<ClassIVarDestroyer>
    
    
    //获得每个属性的在结构体中内存的起始位置
    mutating func getFieldOffset(index: Int) -> Int {
        if Description.pointee.NumFields == 0 || Description.pointee.FieldOffsetVectorOffset == 0 {
            print("没有属性")
            return 0
        }
        let fieldOffsetVectorOffset = self.Description.pointee.FieldOffsetVectorOffset
        return withUnsafeMutablePointer(to: &self) {
            //获得自己本身的起始位置
            let selfPtr = UnsafeMutableRawPointer($0).assumingMemoryBound(to: InProcess.self)
            //以指针的步长偏移FieldOffsetVectorOffset
            let fieldOffsetVectorOffsetPtr = selfPtr.advanced(by: numericCast(fieldOffsetVectorOffset))
            //属性的起始偏移量已32位整形存储的，转一下指针
            let tramsformPtr = UnsafeMutableRawPointer(fieldOffsetVectorOffsetPtr).assumingMemoryBound(to: InProcess.self)
            return numericCast(tramsformPtr.advanced(by: index).pointee)
        }
    }
}


typealias ClassIVarDestroyer = UnsafeMutablePointer<HeapObject>


// ClassMetadata的父类
struct TargetAnyClassMetadata {
    
    // 在oc中放的就是isa，在swift中kind大于0x7FF表示的就是类
    var Kind: InProcess
    // 父类的Metadata，如果是null说明是最顶级的类了
    var Superclass: UnsafeMutablePointer<ClassMetadata>
    // 缓存数据用于某些动态查找，它由运行时拥有，通常需要与Objective-C的使用进行互操作。（说到底就是OC的东西）
    var CacheData1: UnsafeMutablePointer<UnsafeRawPointer>
    var CacheData2: UnsafeMutablePointer<UnsafeRawPointer>
    // 除了编译器设置低位以表明这是Swift元类型外，这个data里存的指针，用于行外元数据，通常是不透明的（应该也是OC的）
    var Data: InProcess
    
    // 该对象是否是有效的swift类型元数据? 也就是说，它可以安全地向下转换到类元数据(ClassMetadata)吗?
    func isTypeMetadata() -> Bool {
        return ((Data & 2) != 0)
    }
    
    func isPureObjC() -> Bool {
        return !isTypeMetadata()
    }
}


