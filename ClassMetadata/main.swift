//
//  main.swift
//  ClassMetadata
//
//  Created by HarryPhone on 2021/1/21.
//


import Foundation

class Person {var name = "Tom";var age = 28};var p = Person()
let mirror = Mirror(reflecting: p)

mirror.children.forEach { print($0) }


class Student: Person {
    var score = 98
}



func printClassType(_ type: AnyObject.Type) {
    let ptr = unsafeBitCast(type.self as Any.Type, to: UnsafeMutablePointer<ClassMetadata>.self)
//    print("ClassMetadata地址\(ptr)")
//    print(ptr.pointee)
//    print("__________________________________")
    let descriptionptr = ptr.pointee.Description
    descriptionptr.pointee.getTargetObjCResilientClassStubInfoPointer()
    let Flags = descriptionptr.pointee.Flags
    print("公共标记的类型：\(Flags.getContextDescriptorKind()!)")

    let Name = descriptionptr.pointee.Name.get()
    print("类名：\(String(cString: Name))")
    
    let SuperclassType = descriptionptr.pointee.SuperclassType.get()
    print("父类型命名重整：\(String(cString: SuperclassType))")
    
    let areImmediateMembersNegative = descriptionptr.pointee.areImmediateMembersNegative()
    print("直接成员是否是负偏移：\(areImmediateMembersNegative)")
    
    let hasVTable = descriptionptr.pointee.hasVTable()
    print("是否含有VTable：\(hasVTable)")
    
    let hasOverrideTable = descriptionptr.pointee.hasOverrideTable()
    print("是否含有OverrideTable：\(hasOverrideTable)") //有方法重写的话，这个会为YES
    
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
            类型命名重整：\(String(cString: propertyPtr.pointee.MangledTypeName.get()))
            是否是var修饰的变量：\(propertyPtr.pointee.Flags.isVar())
            ---------
            """)
    }
    print("ClassMetadata地址\(ptr)")
    print(ptr.pointee)
    print("__________________________________")
}

//printClassType(Person.self)
printClassType(Student.self)
