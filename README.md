# Swift原生类底层ClassMetadata


---
# 主题列表：juejin, github, smartblue, cyanosis, channing-cyan, fancy, hydrogen, condensed-night-purple, greenwillow, v-green, vue-pro, healer-readable, mk-cute
# 贡献主题：https://github.com/xitu/juejin-markdown-themes
theme: juejin
highlight:
---

# 前言
`ClassMetadata`在底层源码代码有点多，所以会挑一些注意点，或者理解起来难度的地方写。一些比较基础的就跳过了，因为全写有点多。我前面写过一篇[StructMetadata](https://juejin.cn/post/6919717099619221517)，会简单点，还有些相同的内容。

同样，`ClassMetadata`我也翻译成`Swift`代码实现了一遍，附上[GitHub链接地址](https://github.com/harryphone/ClassMetadata)，参照着翻译看源码会简单一点。

本文必须结合着`Swift`源码一起看，脱离源码看文章并没有任何意义。本文的旨意在于加速对源码的理解。

# `ClassMetadata`

进入主题，直接在源码里搜`ClassMetadata`，我们可以找到这么一句代码：
```c++
using ClassMetadata = TargetClassMetadata<InProcess>;
```

然后我们点开`TargetClassMetadata`后，可以发现，所有的属性都在`TargetClassMetadata`和他的父类`TargetAnyClassMetadata`中，以及在根类中`Kind`，这里我就合并到一起写出来
```c++
// TargetMetadata中的
StoredPointer Kind;

// TargetAnyClassMetadata中的
ConstTargetMetadataPointer<Runtime, swift::TargetClassMetadata> Superclass;
TargetPointer<Runtime, void> CacheData[2];
StoredSize Data;

// TargetClassMetadata中的
ClassFlags Flags;
uint32_t InstanceAddressPoint;
uint32_t InstanceSize;
uint16_t InstanceAlignMask;
uint16_t Reserved;
uint32_t ClassSize;
uint32_t ClassAddressPoint;
TargetSignedPointer<Runtime, const TargetClassDescriptor<Runtime> * __ptrauth_swift_type_descriptor> Description;
TargetSignedPointer<Runtime, ClassIVarDestroyer * __ptrauth_swift_heap_object_destructor> IVarDestroyer;
```

其中比较注意的一点就是`CacheData[2]`，这里是一个指针数组，总共占16个字节。

不知道有没有很熟悉的感觉？和OC中的类结构很像吧。所以`Swift`中的类兼容`OC`中的类的

翻译成Swift代码：
```swift
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
}
    
```

# `TargetClassDescriptor`
在`TargetClassMetadata`中就`TargetClassDescriptor`和`ClassIVarDestroyer`不知道是什么。

`ClassIVarDestroyer`点开发现是一个`HeapObject`的别名，并没有多余让我探索的地方。。。

还是重点看`TargetClassDescriptor`吧，`Class`的好多信息都是通过`ClassIVarDestroyer`来查找的。

先看下`ClassIVarDestroyer`的定义：

```c++
class TargetClassDescriptor final
    : public TargetTypeContextDescriptor<Runtime>,
      public TrailingGenericContextObjects<TargetClassDescriptor<Runtime>,
                              TargetTypeGenericContextDescriptorHeader,
                              /*additional trailing objects:*/
                              TargetResilientSuperclass<Runtime>,
                              TargetForeignMetadataInitialization<Runtime>,
                              TargetSingletonMetadataInitialization<Runtime>,
                              TargetVTableDescriptorHeader<Runtime>,
                              TargetMethodDescriptor<Runtime>,
                              TargetOverrideTableHeader<Runtime>,
                              TargetMethodOverrideDescriptor<Runtime>,
                              TargetObjCResilientClassStubInfo<Runtime>>
```

我们可以看到`TargetClassDescriptor`继承了`TargetTypeContextDescriptor`了，这块和[StructMetadata](https://juejin.cn/post/6919717099619221517)文章中`TargetStructDescriptor`的父类一样，这边就不再多说了，看下`TargetClassDescriptor`独有的属性：
```c++
TargetRelativeDirectPointer<Runtime, const char> SuperclassType;
union {
    uint32_t MetadataNegativeSizeInWords;
    TargetRelativeDirectPointer<Runtime,
                                TargetStoredClassMetadataBounds<Runtime>>
      ResilientMetadataBounds;
  };
  
  union {
    uint32_t MetadataPositiveSizeInWords;
    ExtraClassDescriptorFlags ExtraClassFlags;
  };

  uint32_t NumImmediateMembers;
  uint32_t NumFields;
  uint32_t FieldOffsetVectorOffset;

```

`TargetRelativeDirectPointer`这个在[StructMetadata](https://juejin.cn/post/6919717099619221517)文章中也讲过。

这里比较有意思的是`union`，`union`公用同一块内存空间，所以翻译成`swift`代码的时候，不能都直接翻译成存储属性，可以把其中一个翻译成计算属性。

看下`swift`的翻译：
```swift

struct TargetClassDescriptor {
    // 存储在任何上下文描述符的第一个公共标记
    var Flags: ContextDescriptorFlags

    // 复用的RelativeDirectPointer这个类型，其实并不是，但看下来原理一样
    // 父级上下文，如果是顶级上下文则为null。
    var Parent: RelativeDirectPointer<InProcess>

    // 获取类的名称
    var Name: RelativeDirectPointer<CChar>

    // 这里的函数类型是一个替身，需要调用getAccessFunction()拿到真正的函数指针（这里没有封装），会得到一个MetadataAccessFunction元数据访问函数的指针的包装器类，该函数提供operator()重载以使用正确的调用约定来调用它（可变长参数），意外发现命名重整会调用这边的方法（目前不太了解这块内容）。
    var AccessFunctionPtr: RelativeDirectPointer<UnsafeRawPointer>

    // 一个指向类型的字段描述符的指针(如果有的话)。类型字段的描述，可以从里面获取结构体的属性。
    var Fields: RelativeDirectPointer<FieldDescriptor>
    
    // The type of the superclass, expressed as a mangled type name that can refer to the generic arguments of the subclass type.
    var SuperclassType: RelativeDirectPointer<CChar>
    
    // 下面两个属性在源码中是union类型，所以取size大的类型作为属性（这里貌似一样），具体还得判断是否have a resilient superclass
    
    // 有resilient superclass，用ResilientMetadataBounds，表示对保存元数据扩展的缓存的引用
    var ResilientMetadataBounds: RelativeDirectPointer<TargetStoredClassMetadataBounds>
    // 没有resilient superclass使用MetadataNegativeSizeInWords，表示该类元数据对象的负大小(用字节表示)
    var MetadataNegativeSizeInWords: UInt32 {
        get {
            return UInt32(ResilientMetadataBounds.offset)
        }
    }

    // 有resilient superclass，用ExtraClassFlags，表示一个Objective-C弹性类存根的存在
    var ExtraClassFlags: ExtraClassDescriptorFlags
    // 没有resilient superclass使用MetadataPositiveSizeInWords，表示该类元数据对象的正大小(用字节表示)
    var MetadataPositiveSizeInWords: UInt32 {
        get {
            return ExtraClassFlags.Bits
        }
    }
    
    /**
     此类添加到类元数据的其他成员的数目。默认情况下，这些数据对运行时是不透明的，而不是在其他成员中公开;它实际上只是NumImmediateMembers * sizeof(void*)字节的数据。
     这些字节是添加在地址点之前还是之后，取决于areImmediateMembersNegative()方法。
     */
    var NumImmediateMembers: UInt32
    
    
    // 属性个数，不包含父类的
    var NumFields: Int32
    // 存储这个结构的字段偏移向量的偏移量（记录你属性起始位置的开始的一个相对于metadata的偏移量，具体看metadata的getFieldOffsets方法），如果为0，说明你没有属性
    // 如果这个类含有一个弹性的父类，那么从他的弹性父类的metaData开始偏移
    var FieldOffsetVectorOffset: Int32

}
```

还有写比如`ExtraClassDescriptorFlags`之类的这种就不写了，看着源码和翻译，对应着很好理解。

#  `FlagSet`

在你翻看源码的时候，经常看到有`Flag`类继承`FlagSet`，就比如说刚才上面被我忽略的`ExtraClassDescriptorFlags`。

看下`FlagSet`的源码：
```c++
template <typename IntType>
class FlagSet {
 
  IntType Bits;

protected:
  template <unsigned BitWidth>
  static constexpr IntType lowMaskFor() {
    return IntType((1 << BitWidth) - 1);
  }

  template <unsigned FirstBit, unsigned BitWidth = 1>
  static constexpr IntType maskFor() {
    return lowMaskFor<BitWidth>() << FirstBit;
  }

  /// Read a single-bit flag.
  template <unsigned Bit>
  bool getFlag() const {
    return Bits & maskFor<Bit>();
  }

  /// Read a multi-bit field.
  template <unsigned FirstBit, unsigned BitWidth, typename FieldType = IntType>
  FieldType getField() const {
    return FieldType((Bits >> FirstBit) & lowMaskFor<BitWidth>());
  }

  // A convenient macro for defining a getter and setter for a flag.
  // Intended to be used in the body of a subclass of FlagSet.
#define FLAGSET_DEFINE_FLAG_ACCESSORS(BIT, GETTER, SETTER) \
  bool GETTER() const {                                    \
    return this->template getFlag<BIT>();                  \
  }                                                        \
  void SETTER(bool value) {                                \
    this->template setFlag<BIT>(value);                    \
  }

  // A convenient macro for defining a getter and setter for a field.
  // Intended to be used in the body of a subclass of FlagSet.
#define FLAGSET_DEFINE_FIELD_ACCESSORS(BIT, WIDTH, TYPE, GETTER, SETTER) \
  TYPE GETTER() const {                                                  \
    return this->template getField<BIT, WIDTH, TYPE>();                  \
  }                                                                      \
  void SETTER(TYPE value) {                                              \
    this->template setField<BIT, WIDTH, TYPE>(value);                    \
  }

};
```

我只复制了一些我们需要的方法

首先看下属性，只有一个`IntType Bits`，`IntType`相当于范型，需要外部传进来指定，不过需要是整型。

方法有4个，其中`lowMaskFor`和`maskFor`是为了`getFlag`和`getField`服务的。细心的你可能还会发现缺少几个参数，例如`BIT`、`WIDTH`、`TYPE`等，这些也是外部决定的，会传进来。

最后的两个是方法生成的便利宏，我们可以看`ExtraClassDescriptorFlags`的例子：
```c++
class ExtraClassDescriptorFlags : public FlagSet<uint32_t> {
  enum {
    HasObjCResilientClassStub = 0,
  };

public:
  explicit ExtraClassDescriptorFlags(uint32_t bits) : FlagSet(bits) {}
  constexpr ExtraClassDescriptorFlags() {}

  FLAGSET_DEFINE_FLAG_ACCESSORS(HasObjCResilientClassStub,
                                hasObjCResilientClassStub,
                                setObjCResilientClassStub)
};
```

我们很明显看到`FLAGSET_DEFINE_FLAG_ACCESSORS`生成了判断`Flag`和设置`Flag`便利方法。

因为有很多`Flag`类继承`FlagSet`类，所以我在翻译成`swift`代码的时候，把它抽出来变成一个协议：
```swift
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

struct ExtraClassDescriptorFlags: FlagSet {
    
    enum kType: Int {
        case HasObjCResilientClassStub = 0
    }
    
    typealias IntType = UInt32
    var Bits: IntType
    
}
```

`ExtraClassDescriptorFlags`继承了协议，这样就能很快的判断是否存在该`Flag`了。

# `TrailingGenericContextObjects`

这块个人认为有点难，我也是通过断点运行进行理解的。

我们回到`TargetClassDescriptor`的定义，除了前面我们分析的继承了`TargetTypeContextDescriptor`之外，还继承了`TrailingGenericContextObjects`，在`TrailingGenericContextObjects`类中传入了10个模版类。

我们看一下`TrailingGenericContextObjects`的定义：
```c++
template<class Runtime,
         template <typename> class TargetSelf,
         template <typename> class TargetGenericContextHeaderType,
         typename... FollowingTrailingObjects>
class TrailingGenericContextObjects<TargetSelf<Runtime>,
                                    TargetGenericContextHeaderType,
                                    FollowingTrailingObjects...> :
  protected swift::ABI::TrailingObjects<TargetSelf<Runtime>,
      TargetGenericContextHeaderType<Runtime>,
      GenericParamDescriptor,
      TargetGenericRequirementDescriptor<Runtime>,
      FollowingTrailingObjects...>
```

我们看到，除了`TargetSelf`和`TargetGenericContextHeaderType`是固定的模版外，`FollowingTrailingObjects`是一个可变长的模版，我们可以通过`TargetClassDescriptor`传进来的模版一一对应。

`TrailingGenericContextObjects`继承的`TrailingObjects`，我们把传入的所有模版放入`TrailingObjects`中，就能得到真正的`TrailingObjects`对象了。

整理下所有的`TrailingObject`顺序：
* `TargetClassDescriptor`
* `TargetTypeGenericContextDescriptorHeader`
* `GenericParamDescriptor`
* `TargetGenericRequirementDescriptor`
* `TargetResilientSuperclass`
* `TargetForeignMetadataInitialization`
* `TargetSingletonMetadataInitialization`
* `TargetVTableDescriptorHeader`
* `TargetMethodDescriptor`
* `TargetOverrideTableHeader`
* `TargetMethodOverrideDescriptor`
* `TargetObjCResilientClassStubInfo`

从断点调试理解下来就是，这些所有的类对象都是紧挨在一起的（可能会做内存对齐处理）。当然这些对象的个数是不固定的，有些是0，说明没有，有些是1，也有些是几个，需要某处内存处获取个数。

所以你要获取其中一个类对象的内存地址，你必须判断该类对象是否存在，并且需要知道前一项类对象的内存地址。

获取`TrailingObject`的方法实现：
```c++
static NextTy *
  getTrailingObjectsImpl(BaseTy *Obj,
                         TrailingObjectsBase::OverloadToken<NextTy>) {
    auto *Ptr = TopTrailingObj::getTrailingObjectsImpl(
                    Obj, TrailingObjectsBase::OverloadToken<PrevTy>()) +
                TopTrailingObj::callNumTrailingObjects(
                    Obj, TrailingObjectsBase::OverloadToken<PrevTy>());

    if (requiresRealignment())
      return reinterpret_cast<NextTy *>(
          llvm::alignAddr(Ptr, llvm::Align(alignof(NextTy))));
    else
      return reinterpret_cast<NextTy *>(Ptr);
  }
```

这个看着复杂，就两个核心方法：`getTrailingObjectsImpl`和`callNumTrailingObjects`。

`getTrailingObjectsImpl`这个递归调用了，获取上一个对象的地址，然后`callNumTrailingObjects`获取该对象的个数。用上一个对象的地址，在加上该对象步长的个数，就能获取你想获取对象的起始位置了。

我们看下`TrailingObjects`核心实现：
```c++

// These two methods are the base of the recursion for this method.
  static const BaseTy *
  getTrailingObjectsImpl(const BaseTy *Obj,
                         TrailingObjectsBase::OverloadToken<BaseTy>) {
    return Obj;
  }

  static BaseTy *
  getTrailingObjectsImpl(BaseTy *Obj,
                         TrailingObjectsBase::OverloadToken<BaseTy>) {
    return Obj;
  }

  // callNumTrailingObjects simply calls numTrailingObjects on the
  // provided Obj -- except when the type being queried is BaseTy
  // itself. There is always only one of the base object, so that case
  // is handled here. (An additional benefit of indirecting through
  // this function is that consumers only say "friend
  // TrailingObjects", and thus, only this class itself can call the
  // numTrailingObjects function.)
  static size_t
  callNumTrailingObjects(const BaseTy *Obj,
                         TrailingObjectsBase::OverloadToken<BaseTy>) {
    return 1;
  }

  template <typename T>
  static size_t callNumTrailingObjects(const BaseTy *Obj,
                                       TrailingObjectsBase::OverloadToken<T>) {
    return Obj->numTrailingObjects(TrailingObjectsBase::OverloadToken<T>());
  }
```

我们可以很明显看到，如果获取的是对象本身，`getTrailingObjectsImpl`直接返回参数自己`Obj`，结束了递归调用，`callNumTrailingObjects`个数也返回1。

如果对象不是本身的话，那么`getTrailingObjectsImpl`在递归调用，`callNumTrailingObjects`返回是的`Obj->numTrailingObjects(TrailingObjectsBase::OverloadToken<T>())`

`numTrailingObjects`在前面的`TargetClassDescriptor`和`TrailingGenericContextObjects`类有实现，我复制到一起：
```c++
size_t numTrailingObjects(OverloadToken<GenericContextHeaderType>) const {
    return asSelf()->isGeneric() ? 1 : 0;
  }
  
  size_t numTrailingObjects(OverloadToken<GenericParamDescriptor>) const {
    return asSelf()->isGeneric() ? getGenericContextHeader().NumParams : 0;
  }

  size_t numTrailingObjects(OverloadToken<GenericRequirementDescriptor>) const {
    return asSelf()->isGeneric() ? getGenericContextHeader().NumRequirements : 0;
  }
  
  size_t numTrailingObjects(OverloadToken<ResilientSuperclass>) const {
    return this->hasResilientSuperclass() ? 1 : 0;
  }

  size_t numTrailingObjects(OverloadToken<ForeignMetadataInitialization>) const{
    return this->hasForeignMetadataInitialization() ? 1 : 0;
  }

  size_t numTrailingObjects(OverloadToken<SingletonMetadataInitialization>) const{
    return this->hasSingletonMetadataInitialization() ? 1 : 0;
  }

  size_t numTrailingObjects(OverloadToken<VTableDescriptorHeader>) const {
    return hasVTable() ? 1 : 0;
  }

  size_t numTrailingObjects(OverloadToken<MethodDescriptor>) const {
    if (!hasVTable())
      return 0;

    return getVTableDescriptor()->VTableSize;
  }

  size_t numTrailingObjects(OverloadToken<OverrideTableHeader>) const {
    return hasOverrideTable() ? 1 : 0;
  }

  size_t numTrailingObjects(OverloadToken<MethodOverrideDescriptor>) const {
    if (!hasOverrideTable())
      return 0;

    return getOverrideTable()->NumEntries;
  }

  size_t numTrailingObjects(OverloadToken<ObjCResilientClassStubInfo>) const {
    return hasObjCResilientClassStub() ? 1 : 0;
  }
  
```

所以如何获得对应的类对象很清楚了，看我翻译的`Swift`代码：
```swift
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
```

其实代码比较雷同，可能可以抽取出来有更好的封装，源码里有内存对齐的操作`alignAddr`，我比较懒，没遇上错误就没做，哈哈。

这里看有没有错的方法是：看`TargetMethodDescriptor`类里的`Impl`属性地址是否正确，可以用反汇编命令`dis -s 0x0000000100013ba0`查看，例如：
![](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/9c851ea35f6646f09f8008569f948208~tplv-k3u1fbpfcp-watermark.image)


# 尝试`Swift`类的方法替换

通过上面的方法，我们可以拿到函数实现的地址，有没有想过替换他们呢？

我尝试了下，发现不行哈
![](https://p6-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/673074ed2244436093fa7bf37df76ede~tplv-k3u1fbpfcp-watermark.image)

一个地址的坏的访问，我用插件查了下这个地址：
![](https://p3-juejin.byteimg.com/tos-cn-i-k3u1fbpfcp/3502168b3e9e417ca95ce45d6daf1834~tplv-k3u1fbpfcp-watermark.image)

发现`0x10001fd58`在`__TEXT`段，说明这块内容在运行时是只读的，一旦修改了，就会像我一样报错了。

# 总结

如果不想看源码也不要紧，`ClassMetadata`的结构在我翻译的Swift代码中已经全部体现出来了。

通过方法替换的失败，我们也能感觉出`Swift`的安全性，也能体验出`Swift`是一门静态语言。但这并不意味着`Swift`的编译出来的程序就不可修改了，我们可以直接通过查找Macho文件的符号表，修改Macho文件中函数的实现地址，重新签名，被修改过的文件Macho就又能在手机上跑了。只能说，用`Swift`编译出来的代码，逆向难度又更高了。




