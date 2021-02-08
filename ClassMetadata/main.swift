//
//  main.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/1/21.
//


import Foundation

class Person {
    var name = "Tom"
    var age = 28
}

class Student: Person {
    var score = 98
    
    func printScore() {
        print(score)
    }
}



func printClassType(_ ptr: UnsafeMutablePointer<ClassMetadata>) {

    let descriptionptr = ptr.pointee.Description
    
    let Flags = descriptionptr.pointee.Flags
    print("公共标记的类型：\(Flags.getContextDescriptorKind()!)")

    let Name = descriptionptr.pointee.Name.get()
    print("类名：\(String(cString: Name))")
    
    let areImmediateMembersNegative = descriptionptr.pointee.areImmediateMembersNegative()
    print("直接成员是否是负偏移：\(areImmediateMembersNegative)")
    
    // 打印出的地址可以用反汇编代码查看，例如 dis -s 0x0000000100013ba0
    let hasVTable = descriptionptr.pointee.hasVTable()
    print("是否含有VTable：\(hasVTable)")
    if hasVTable {
        let vTableCount = Int(descriptionptr.pointee.getTargetVTableDescriptorHeaderPointer().resultPtr.pointee.VTableSize)
        print("VTable方法个数：\(vTableCount)")
        print("VTable方法地址")
        print("---------")
        if vTableCount > 0 {
            let vtablePtr = descriptionptr.pointee.getTargetMethodDescriptorPointer().resultPtr
            for i in 0..<vTableCount {
                print("\(vtablePtr.advanced(by: i).pointee.Impl.get())")
            }
        }
        print("---------")
    }
    
    // 打印出的地址可以用反汇编代码查看，例如 dis -s 0x0000000100013ba0
    let hasOverrideTable = descriptionptr.pointee.hasOverrideTable()
    print("是否含有OverrideTable：\(hasOverrideTable)") //有方法重写的话，这个会为YES
    if hasOverrideTable {
        let overrideMethodsCount = Int(descriptionptr.pointee.getTargetOverrideTableHeaderPointer().resultPtr.pointee.NumEntries)
        print("Override方法个数：\(overrideMethodsCount)")
        print("Override方法地址")
        print("---------")
        if overrideMethodsCount > 0 {
            let overridePtr = descriptionptr.pointee.getTargetMethodOverrideDescriptorPointer().resultPtr
            for i in 0..<overrideMethodsCount {
                print("\(overridePtr.advanced(by: i).pointee.Impl.get())")
            }
        }
        print("---------")
    }
    
    let hasResilientSuperclass = descriptionptr.pointee.hasResilientSuperclass()
    print("是否含有ResilientSuperclass：\(hasResilientSuperclass)")
    
    if hasResilientSuperclass {
        let getResilientSuperclassReferenceKind = descriptionptr.pointee.getResilientSuperclassReferenceKind()
        print("弹性父类类型：\(getResilientSuperclassReferenceKind)")
    }
    
    //拿到属性个数，属性名字，属性在内存的起始位置，这样就可以取值，mirror的原理就是这个！！
    let propertyCount = Int(descriptionptr.pointee.NumFields)
    print("不含父类属性个数：\(propertyCount)")
    print("---------")
    (0..<propertyCount).forEach {
        let propertyPtr = descriptionptr.pointee.Fields.get().pointee.getField(index: $0)
        print("""
            属性名：\(String(cString: propertyPtr.pointee.FieldName.get()))
            起始位置：\(ptr.pointee.getFieldOffset(index: $0))
            类型命名重整：\(String(cString: propertyPtr.pointee.MangledTypeName.get()))
            是否是var修饰的变量：\(propertyPtr.pointee.Flags.isVar())
            ---------
            """)
    }
    print("ClassMetadata地址\(ptr)")
    print(ptr.pointee)
    print("__________________________________")
    
    let SuperclassTypeName =  String(cString: descriptionptr.pointee.SuperclassType.get())
    
    if SuperclassTypeName != "" {
        print("以下是父类MetaData")
        print("父类型命名重整：\(SuperclassTypeName)")
        printClassType(ptr.pointee.Superclass)
    }
    
    
}


printClassType(unsafeBitCast(Student.self as Any.Type, to: UnsafeMutablePointer<ClassMetadata>.self))

