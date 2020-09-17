---
title: JVM
categories:
  - Java
  - JVM
date: 2020-09-06 16:32:49
---


# JVM 基础概念

- java 的编译到执行的过程
![java 编译到执行的过程](https://gitee.com/h428/img/raw/master/note/00000139.jpg)

- java 为跨平台演变为跨语言，通过 jvm 与 class 可以实现跨语言，任何语言只要能编译为 class 字节码，则可以在 jvm 上执行（基于 class 和 jvm 标准）
![java 跨语言](https://gitee.com/h428/img/raw/master/note/00000140.jpg)


- 常见 jvm 实现，最常见的是 HotSpot，也是 jdk 默认的实现（java -version 可查看）
![常见 jvm](https://gitee.com/h428/img/raw/master/note/00000141.jpg)

# Class 文件结构

- 第一层级，Class 文件按序包含：
    - Magic Number
    - Minor Version：和 Major Version 共同决定 class 文件版本号，1.7 默认为 51,1.8 默认为 52
    - Major Version
    - constant_pool_count
    - constant_pool：长度为 constant_pool_count-1 的表
    - access_flags
    - this_class
    - super_class
    - interfaces_count
    - interfaces
    - field_count
    - fields
    - methods_count
    - methods
    - attributes_count：附加属性
    - attributes
- 开头固定为 `CA FE BA BE 00 00 00 34` 表示这是一个 class 文件
- 观察 ByteCode 方法：javap、JBE、JclassLib（Idea 插件）
- Class 文件结构大致如图所示：
![class 文件结构](https://gitee.com/h428/img/raw/master/note/00000146.jpg)

# 类加载过程

## 类完整加载过程

- loading：把 class 文件加载到内存，采用双亲委派
- linking
    - verification：校验载入的 class 文件符不符合 class 标准
    - preparation：初始化工作，静态变量赋默认值，注意是默认值不是初值
    - resolution：把常量池引用转换为直接的内存地址
- initializing：静态变量赋值为初始值
- 当 jvm 将 class 文件加载到内存后，会生成两块区域，第一块就代表 class 字节码，第二块为 Class 类的内容，且其包含嘞指向字节码的指针，我们通过反射拿到 Class.Method 时，指向的是 Class，当执行方法时，会通过 Class 中的类字节码指针找到方法区，然后翻译成 java 指令并执行
![类加载过程](https://gitee.com/h428/img/raw/master/note/00000150.jpg)

## 类加载器介绍

- JVM 中有好几个 ClassLoader，对于不同类别的 class，会采用不同的类加载器加载（红线为双亲委派，即类加载过程）
![类加载器](https://gitee.com/h428/img/raw/master/note/00000147.jpg)
- 例如下述代码：
```java
public class Main {
    public static void main(String[] args) {

        // 使用 Bootstrap 加载器加载
        System.out.println(String.class.getClassLoader());
        System.out.println(sun.awt.HKSCS.class.getClassLoader());

        // 使用 Extension 加载器加载
        System.out.println(sun.net.spi.nameservice.dns.DNSNameService.class.getClassLoader());

        // classpath 下指定的类使用 Application 加载器加载
        System.out.println(C1.class.getClassLoader());

        // 其他 ClassLoader 的 ClassLoader 使用 Bootstrap 加载器加载
        System.out.println(sun.net.spi.nameservice.dns.DNSNameService.class.getClassLoader().getClass().getClassLoader());
        System.out.println(C1.class.getClassLoader().getClass().getClassLoader());
    }
}
```

## loading 过程：双亲委派及验证

- 下图为类加载过程：
![类加载过程](https://gitee.com/h428/img/raw/master/note/00000148.jpg)
- 为什么采用双亲委派：主要是为了安全，通过双亲委派，jvm 将避免加载用户覆盖标准类库，例如自定义的 java.lang.String 并不会被 jvm 加载；次要则是避免资源浪费问题，避免重复加载
- 注意，双亲委派中的父加载器不是类加载器的加载器，也不是通过 extends 关键字体现的类加载器的父类加载器，而是 ClassLoader 中的 parent 域指明：AppClassLoader 的加载器是 Bootstrap，但其父加载器是 Extension，即 App 找不到会先去 Extension 中找
- 父加载器是通过提前定义好的组合关系来确定的，并不是通过 extends 确定，例如下述代码说明，各个加载器的父子关系为：App --> Extension --> Bootstrap
```java
public class Main {
    public static void main(String[] args) {
        System.out.println(C1.class.getClassLoader()); // App ClassLoader
        System.out.println(C1.class.getClassLoader().getClass().getClassLoader()); // Bootstrap ClassLoader
        System.out.println(C1.class.getClassLoader().getParent()); // Extension ClassLoader
        System.out.println(C1.class.getClassLoader().getParent().getParent()); // BootStrap ClassLoader
    }
}
```
- 验证个加载器的加载范围：
```java
public class Main {
    public static void main(String[] args) {

        // 各加载器为 sun.misc.Launcher 的内部类，这些字符串都来自于这些内部类

        String pathBoot = System.getProperty("sun.boot.class.path");
        System.out.println(pathBoot.replaceAll(";", System.lineSeparator()));

        System.out.println("-------------------------");
        String pathExt = System.getProperty("java.ext.dirs");
        System.out.println(pathExt.replaceAll(";", System.lineSeparator()));


        System.out.println("-------------------------");
        String pathApp = System.getProperty("java.class.path");
        System.out.println(pathApp.replaceAll(";", System.lineSeparator()));

    }
}
```

## 自定义类加载器

- 我们自定义一个类加载器，针对目录 `E:/data/jvm/` 下的 class 文件的加载，代码如下：
```java
/**
 * 自定义 ClassLoader，基于目录 E:/data/jvm 加载类
 *
 * @author hao
 */
public class MyClassLoader extends ClassLoader {

    /**
     * 根据 name 加载类
     *
     * @param name 约定传入的名称为 xxx.xxx.xxx.ClassName
     */
    @Override
    protected Class<?> findClass(String name) throws ClassNotFoundException {

        File f = new File("E:/data/jvm/", name.replaceAll("\\.", "/").concat(".class"));

        try {

            // 读取 class 文件并写到输出流
            FileInputStream fis = new FileInputStream(f);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            int b;
            while ((b = fis.read()) != -1) { // 注意，每字节以十六进制读进来，范围为 0 - FF，对于 int 必定不为 -1
                out.write(b);
            }

            // 输出流转化为字节数组
            byte[] bytes = out.toByteArray();
            out.close();
            fis.close();

            // 将字节数组转化为 Class 对象
            return defineClass(name, bytes, 0, bytes.length);
        } catch (IOException e) {
            e.printStackTrace();
        }

        return super.findClass(name); // throws ClassNotFoundException
    }
}
```
- 定义完毕后，我们在分别提供 `E:/data/jvm/A.java` 和 `E:/data/jvm/com/hao/C.java` 并分别编译：
```java
public class A {
    public static void print() {
        System.out.println("this is A");
    }
}

public class C {
    public static void print() {
        System.out.println("this is C");
    }
}
```
- 然后我们在主类中使用自定义的 MyClassLoader 加载上述 A, C 类，并执行对应的 print 方法进行验证
```java
public class Main {
    public static void main(String[] args) throws Exception {
        ClassLoader classLoader = new MyClassLoader();

        Class<?> clazz = classLoader.loadClass("A");
        Method print = clazz.getDeclaredMethod("print");
        print.invoke(null);

        clazz = classLoader.loadClass("com.hao.C");
        print = clazz.getDeclaredMethod("print");
        print.invoke(null);
    }
}
```
- 补充：JVM 的混合模式
![JVM 混合模式](https://gitee.com/h428/img/raw/master/note/00000149.jpg)


## 打破双亲委派机制（热部署原理）

- 双亲委派机制会被打破，我们可以通过重写 loadClass 方法来打破，双亲委派机制通过 loadClass 模板方法体现，我们覆盖了以后相当于模板方法没了，自然也就打破了双亲委派机制
- 先自定义 MyClassLoader 覆盖 loadClass 方法，只要 `E:/data/jvm/` 目录下存在指定类，则不管父类找没找过，直接再找
```java
public class MyClassLoader extends ClassLoader {

    /**
     * 覆盖 loadClass 会打破双亲委派机制
     */
    @Override
    public Class<?> loadClass(String name) throws ClassNotFoundException {

        File f = new File("E:/data/jvm/", name.replaceAll("\\.", "/").concat(".class"));

        if (!f.exists()) {
            // 文件不存在，则用父类找
            return super.loadClass(name);
        }

        try {

            // 否则，直接自己找，不走双亲委派
            // 读取 class 文件并写到输出流
            FileInputStream fis = new FileInputStream(f);
            ByteArrayOutputStream out = new ByteArrayOutputStream();
            int b;
            while ((b = fis.read()) != -1) { // 注意，每字节以十六进制读进来，范围为 0 - FF，对于 int 必定不为 -1
                out.write(b);
            }

            // 输出流转化为字节数组
            byte[] bytes = out.toByteArray();
            out.close();
            fis.close();

            // 将字节数组转化为 Class 对象
            return defineClass(name, bytes, 0, bytes.length);
        } catch (IOException e) {
            e.printStackTrace();
        }

        return super.loadClass(name);
    }
}
```
- 主方法测试
```java
public class Main {
    public static void main(String[] args) throws Exception {
        ClassLoader classLoader = new MyClassLoader();

        // 先加载 A
        Class<?> clazz = classLoader.loadClass("A");

        // 再次加载 A
        classLoader = new MyClassLoader();
        Class<?> clazzNew = classLoader.loadClass("A");

        System.out.println(clazz == clazzNew);
    }
}
```

## linking

- verification：验证 class 文件是否符合 JVM 规定
- preparation：静态成员变量赋默认值，注意是默认值不是初值
- resolution：是否解析，即 loadClass 的第二个参数 `boolean resolve`，表示是否在加载后将类、方法、属性等符号引用解析为直接引用，即将常量池中的各种符号引用解析为指针、偏移量等内存地址的直接引用

## initializing

- initializing：调用类初始化代码给静态成员变量赋初始值，按静态域顺序执行
- 注意，初始化过程之前有个默认值，这点不管对于静态域还是普通域都成立，静态与是在 linking 时设置的默认值，普通域在执行构造方法之前也有一次设置默认值的操作
- 面试题：
```java
public class Main {
    public static void main(String[] args) throws Exception {
        // 打印的 count 是多少？ ---> 3
        System.out.println(T.count);
    }
}

class T {
    public static int count = 2;
    public static T t = new T();

    public T() {
        count++;
    }
}

// 对比，换了顺序导致值改变
public class Main {
    public static void main(String[] args) throws Exception {
        // 打印的 count 是多少？ ---> 2
        System.out.println(T.count);
    }
}

class T {
    // 换下顺序
    public static T t = new T();
    public static int count = 2;

    public T() {
        count++;
    }
}
```



# Java 内存模型

## 硬件层的并发优化基础

### 硬件基础

- 存储器的存储结构大致如图所示，注意 L1, L2 是 CPU 内部的缓存，L3 是外部缓存且为各个 CPU 共享
![存储器的存储结构](https://gitee.com/h428/img/raw/master/note/00000152.jpg)
- CPU 到访问各个组件数据所需 CPU 时钟周期和时间大致如下：
    - 寄存器：1 cycle,
    - L1 cache：3 - 4 cycles, 1 ns
    - L2 cache：10 cycles, 3 ns
    - L3 cache：40 - 45 cycles, 15 ns
    - QPI 总线传输：20 ns
    - 主存：60 - 80 ns
- 基于上述架构，各个 CPU 内部有自己的 L1、L2，从而导致同一数据在各个 CPU 的 L1, L2 可能有不同版本（例如两个线程并行，一个 CPU + 1，另一个 CPU + 2），导致数据一致性问题
- 硬件级解决并发并行下的数据一致性问题：
    - 对总线加锁（总线锁），老的 CPU 采用，会大大降低并发并行效率，因为锁住了整个总线，导致其他 CPU 无法从内存取数据
    - 线代 CPU 最常见的解决办法是采用各种各样的一致性协议，协议有很多，最常提到的就是 MESI Cache 一致性协议（Intel CPU 采用的协议）
    ![MESI](https://gitee.com/h428/img/raw/master/note/00000154.jpg)


### 缓存行与伪共享问题

- 缓存行：基于局部性原理，CPU 再读取并设置缓存时，并不只是单单设置该数据到缓存，而是当前数据相邻的若干数据一起读到缓存中并缓存，这就是缓存行，一般缓存行为 64 Byte
- 伪共享：位于同一缓存行的不同数据被两个不同 CPU 锁定，产生互相影响的伪共享问题
![缓存行](https://gitee.com/h428/img/raw/master/note/00000153.jpg)
- 缓存行对齐代码举例，下面这个类没有做缓存行对齐，多线程下可能导致伪共享问题，增加运行时间
```java
public class Main {

    private static class T {
        public volatile long x = 0L;
    }

    public static T[] arr = new T[2];

    static {
        arr[0] = new T();
        arr[1] = new T();
    }

    public static void main(String[] args) throws Exception {

        final int count = 1000_0000;

        // 第一个线程，一直改变 arr[0]
        Thread t1 = new Thread(() -> {
            for (int i = 0; i < count; i++) {
                arr[0].x = i;
            }
        });

        // 第二个线程，一直改变 arr[1]
        Thread t2 = new Thread(() -> {
            for (int i = 0; i < count; i++) {
                arr[1].x = i;
            }
        });

        // 由于 arr[0], arr[1] 位于同一缓存行，因此会一直花费时间进行伪共享，导致时间增加
        final long start = System.nanoTime();
        t1.start();
        t2.start();
        t1.join();
        t1.join();
        System.out.println((System.nanoTime() - start) / 100_0000);
    }
}
```
- 使用 Padding 中的 56 字节进行填充后，避免了伪共享问题，增加了时间，可以观察打印，耗时大致为前一份代码的三分之一
```java
public class Main {

    private static class Padding {
        private volatile long p1, p2, p3, p4, p5, p6, p7; // 7 * 8 字节，用于缓存行对齐填充，缓存行一般为 64 Byte
    }

    private static class T extends Padding{ // 这样一个 T 至少 64 Byte，不会和其他对象位于同一缓存行
        public volatile long x = 0L;
    }

    public static T[] arr = new T[2];

    static {
        arr[0] = new T();
        arr[1] = new T();
    }

    public static void main(String[] args) throws Exception {

        final int count = 1000_0000;

        // 第一个线程，一直改变 arr[0]
        Thread t1 = new Thread(() -> {
            for (int i = 0; i < count; i++) {
                arr[0].x = i;
            }
        });

        // 第二个线程，一直改变 arr[1]
        Thread t2 = new Thread(() -> {
            for (int i = 0; i < count; i++) {
                arr[1].x = i;
            }
        });

        // 由于 arr[0], arr[1] 位于同一缓存行，因此会一直花费时间进行伪共享，导致时间增加
        final long start = System.nanoTime();
        t1.start();
        t2.start();
        t1.join();
        t1.join();
        System.out.println((System.nanoTime() - start) / 100_0000);
    }
}
```
- 通过上述例子可以看出，通过缓存行对齐能够避免伪共享问题，提高效率，但会造成一定程度的空间浪费

## 乱序问题

- CPU 为了提高效率，引入了乱序读和合并写

### 乱序读

- 乱序读：CPU 会打乱原来的执行顺序，其可能会在执行一条指令的过程中（比如去内存读数据，慢 100 倍），去同时执行另一条指令，当然前提是两条指令没有依赖关系（有点像是内部多线程）
![乱序读](https://gitee.com/h428/img/raw/master/note/00000155.jpg)
- 下面代码验证了乱序读的问题，比如我一直运行到第 968444 次发生了乱序读，导致 x y 同时为 0，程序终止：
```java
public class Main {

    private static int x = 0, y = 0;
    private static int a = 0, b = 0;

    public static void main(String[] args) throws Exception {

        int i = 0;

        while (true) {
            ++i;

            // 每次进来都初始化一遍
            x = 0; y = 0;
            a = 0; b = 0;

            // 用两个线程验证乱序读
            // 若是没发生乱序读，则每次线程运行完，x 和 y 必定不可能同时为 0，因为一个值必定会被另一个线程置位 1

            Thread one = new Thread(() -> {
                a = 1;
                x = b;
            });

            Thread other = new Thread(() -> {
                b = 1;
                y = a;
            });

            one.start(); other.start();
            one.join(); other.join();

            String result = String.format("第 %d 次 (%d, %d)\n", i, x, y);

            if (x == 0 && y == 0) {
                System.out.println(result);
                break;
            }
        }
    }
}
```
- 由于 CPU 会进行指令重排，因此单例模式的 DCL 实现中，INSTANCE 变量必须添加 volatile 来避免重排，否则若发生了指令重排，将可能导致其他线程获取到一个半初始化的实例
- 使用 volatile 修饰成员变量，那么在变量赋值时，会有一个内存屏障，也就是说只有执行完赋值操作之后，其他线程读取操作时才能看到 instance 这个变量的值，不会造成误判，解决了对象状态不完整的问题


### 合并写

- [合并写](https://www.cnblogs.com/liushaodong/p/4777308.html)
- 下面代码体现了合并写特性，CaseTwo 将 6 次写操作分别拆分成两份 4 次写操作（WC Buffer 很贵，比 L1 缓存还快，但一般只有 4 个位置，故支持 4 次写操作合并），由于合并写，反而使得拆开的两个循环效率更高（无法验证，可能我 CPU 的 WC Buffer 数量不是 4 个）：
```java
public class Main {

    private static final int ITERATIONS = Integer.MAX_VALUE;
    private static final int ITEMS = 1 << 24;
    private static final int MASK = ITEMS - 1;

    private static final byte[] arrayA = new byte[ITEMS];
    private static final byte[] arrayB = new byte[ITEMS];
    private static final byte[] arrayC = new byte[ITEMS];
    private static final byte[] arrayD = new byte[ITEMS];
    private static final byte[] arrayE = new byte[ITEMS];
    private static final byte[] arrayF = new byte[ITEMS];

    public static void main(String[] args) {
        for (int i = 0; i < 3; i++) {
            System.out.println("6 次一起操作：" + runCaseOne());
            System.out.println("拆分为 4 + 4：" + runCaseTwo());
        }
    }

    public static long runCaseOne() {
        long start = System.nanoTime();

        int i = ITERATIONS;

        while (--i != 0) {
            // 7 次赋值一起执行
            int slot = i & MASK;
            byte b = (byte) i;
            arrayA[slot] = b;
            arrayB[slot] = b;
            arrayC[slot] = b;
            arrayD[slot] = b;
            arrayE[slot] = b;
            arrayF[slot] = b;
        }

        return System.nanoTime() - start;
    }

    public static long runCaseTwo() {
        long start = System.nanoTime();

        int i = ITERATIONS;

        while (--i != 0) {
            // 7 次赋值一起执行
            int slot = i & MASK;
            byte b = (byte) i;
            arrayA[slot] = b;
            arrayB[slot] = b;
            arrayC[slot] = b;
        }

        i = ITERATIONS;
        while (--i != 0) {
            // 4 + 4
            int slot = i & MASK;
            byte b = (byte) i;
            arrayD[slot] = b;
            arrayE[slot] = b;
            arrayF[slot] = b;
        }

        return System.nanoTime() - start;
    }

}
```

## 如何保证特定情况不乱序

- 在硬件级别，CPU 通过 CPU 内存屏障实现，不同的 CPU 涉及的汇编指令和具体实现都不同，下面是 Intel CPU 内存屏障实现举例
    - sfence：在 sfence 指令前的写操作必须先于 sfence 指令后的写操作完成
    - lfence：在 lfence 指令前的读操作必须先于 lfence 指令后的读操作完成
    - mfence：在 mfence 指令前的读写操作必须先于 mfence 指令后的读写操作完成
    - sfence 和 lfence 相当于作为分界线，保证它们之前的操作必须完成，才能继续它们后面的操作，因此称作内存屏障
- 除了内存屏障，硬件级别的 lock 指令也能实现有序性保障：lock 是一个原子指令，例如 x86 上的 `lock ...` 指令是一个 Full Barrier，执行时会锁住在内存子系统以确保执行顺序，甚至跨多个 CPU
- Software Locks 通常使用内存屏障或原子指令来实现变量可见性和保持程序顺序，软件的内存屏障基于硬件，例如 JVM 中的 volatile 也基于类似内存屏障的原理，不过其为 JVM 级别的内存屏障
- JSR133 规定了 JVM 的 4 种内存屏障，注意这些屏障是软件层级的，依赖于硬件层级：
![Java 内存屏障](https://gitee.com/h428/img/raw/master/note/00000156.jpg)

## volatile 实现细节

- volatile 有两个作用：保证线程可见性、禁止指令重排
- 现在有一个趋势，就是尽量用 synchronize 而避免采用 volatile，因为 synchronize 在优化后性能已经很高了，volatile 反而很少用，就是面试容易问到
- 字节码层面：access_flags 有一个 volatile 标记：ACC_VOLATILE
- JVM 层面：在所有 volatile 变量的读/写操作前后都会加上相关内存屏障
![volatile 的 jvm 实现](https://gitee.com/h428/img/raw/master/note/00000157.jpg)
- 硬件层面：
    - 针对 jvm 的内存屏障，不同的虚拟机有不同实现，甚至同一虚拟机在不同 OS 实现也不尽相同
    - 要观察硬件层级的实现，需要使用 hsdis 观察汇编码，可发现其本质为通过 `lock xxx`，使得执行 xxx 指令时对内存区域加锁，确保不会出现一致性问题，[参考地址](https://blog.csdn.net/qq_26222859/article/details/52235930)

### 为什么单例模式的 DCL 版本为什么要加 volatile

- 这涉及到现在 CPU 的指令重排问题，首先我们看下面这个简单的例子
```java
public class Main {
    public static void main(String[] args) {
        Main m = new Main();
    }
}
```
- 上述 main 方法生成的字节码如下：
![miain 方法字节码](https://gitee.com/h428/img/raw/master/note/00000151.jpg)
- 我们可以看到，`Main m = new Main();` 会分成好几部执行：
    - `new`：首先创建对象，此时对象为默认值，处于版初始化状态
    - `invokespecial`：为对象执行构造方法初始化，只有执行完构造方法后，对象才真正初始化完毕
    - `astore_1`：把对象赋值给 m
- 本身若是指令正常按序执行，不加 volatile 也不会出任何问题，但由于指令可能会重排，即可能先执行 astore_1 再执行 invokespecial，此时对象会处于半初始化状态，只有等到 invokespecial 执行完毕对象才真正初始化完毕
- 由于在单利模式中这就导致 INSTANCE 变量会先指向半初始化状态的对象，即变量已经有值指向了一块区域，但这块区域还没完全初始化完成
- 基于上述指令重排，我们来看单例模式的 DCL 实现：
```java
public class Singleton {
    private static volatile Singleton singleton;

    private Singleton() { }

    public static Singleton getSingleton() {
        if (singleton == null) {
            synchronized (Singleton.class) {
                if (singleton == null) { // double check
                    singleton = new Singleton(); // volatile here can avoid instructions rearrangement
                }
            }
        }
        return singleton;
    }
}
```
- 机遇上述代码，我们看看在单例模式的 Double Check 中，若不加 volatile 会发生什么：
    - 在单例的 synchronized 内部，我们赋值操作针对的是 static 变量 singleton
    - 若第一个线程首次进入 synchronized 内部，且还好在执行 `singleton = new Singleton();` 时发生了指令重排，此时 singleton 就处于半初始化状态，指向一个未完全初始化完毕的对象，即 singleton 虽然指向了对象，但构造方法还未执行，此时该对象内部全为默认值
    - 恰在此时，另一个线程也获取单例，进入 `getSingleton()` 后，发现 singleton 已经指向了一个未初始化的对象，则外层 check 不为空，则直接返回了一个未初始化的对象
    - 因而，单例模式的单例变量必须添加 volatile 关键字，主要是为了避免指令重排（synchronized 不能避免指令重排）
- 根据 happens-before 原则，对 volatile 的变量的写操作必定先于后续的读操作完成（通过内存屏障保证），从而达到禁止重排的效果，这样另一个线程要么读到 null 进入内部阻塞锁，要么必然读到完整的初始化完毕的对象，这就是为什么单例的 DCL 实现必须加锁的原因

## synchronize 实现细节

- 字节码层面：synchronized 代码块会编译为 monitorenter 和 monitorexit 指令，synchronized 会在方法的 access_flags 打标记，以告诉 jvm 需要加锁
- JVM 层面：C/C++ 调用了操作系统的同步机制
- OS 和硬件层面：通过 `lock copxchg 其他指令` 对该指令加锁实现，[参考地址](https://blog.csdn.net/21aspnet/article/details/88571740)

## 对象内存布局（面试 6 连问）

- 面试题：
    - 解释下对象的创建过程
    - 对象在内存中的存储布局
    - 对象头具体包括什么
    - 对象怎么定位
    - 对象怎么分配，以及 GC 相关内容
    - `Object o = new Object()` 在内存中占用多少字节

### (1) 复习：解释下对象的创建过程

- class loading：双亲委派
- class linking：包括 verification, preparation, resolution
- class initialzing：对象设初始值
- 申请对象内存
- 成员变量赋默认值，注意是默认值不是初始值
- 调用字节码中的 `<init>` 方法，包括：
    - 成员变量的顺序赋值列表，包括定义时的赋值和初始化块
    - 执行构造方法
    - 特别注意，在字节码中，jvm 会将定义域时设置的初始值和初始化块的赋值操作编译成相同的内容，并插入到所有的构造方法之前，因此如果编写了初始化块，在字节码中体现为所有的 init 方法中的开始部分都有相同的赋值操作
    - 还有一点也要特别注意，就是定义时的赋值也被 jvm 看成是一块初始化块，因此若在定义域之前有一块初始化块做赋值操作，则初始化块的赋值操作会先执行，之后才是定义时的赋值操作，可以下述例子
- 比如对于下述代码，我们观察其 3 个构造方法的字节码：
```java
public class C2 {

    {
        age = 10086; // 本句的赋值会先于 age = 100 执行
    }

    private int age = 100; // 本句的赋值会晚于 age = 10086 执行，而不是定义时就执行


    public C2() {
        // 所有构造方法的前面都会添加相同的初始化块操作
        this.age = 200;
    }

    public C2(int age) {
        // 所有构造方法的前面都会添加相同的初始化块操作
        this.age = age;
    }

    public C2(int age, int base) {
        // 所有构造方法的前面都会添加相同的初始化块操作
        this.age = age * base;
    }
}
```
- 无参构造器的字节码
![无参构造器的字节码](https://gitee.com/h428/img/raw/master/note/00000161.jpg)
- 单参构造器的字节码
![单参构造器的字节码](https://gitee.com/h428/img/raw/master/note/00000162.jpg)
- 双参构造器的字节码
![双参构造器的字节码](https://gitee.com/h428/img/raw/master/note/00000163.jpg)

### (2) 对象在内存中的存储布局

- 通过 `java -XX:+PrintCommandLineFlags ...` 打印命令行自带参数
- 对于普通对象和数组对象，他们在内存中的布局不相同

#### 普通对象

- 对象头：也叫 Mark Word，8 Byte
- ClassPointer 指针：指向 Class 的指针，-XX:+UseCompressedClassPointers 为 4 字节，不开启为 8 字节
- 实例数据：
    - 基本数据类型即为基本数据类型类型对应字节长度
    - 引用类型：若开启 -XX:+UseCompressedOops 为 4 字节，不开启为 8 字节
    - Oops：Ordinary Object Pointers，普通对象指针
- Padding 的对齐，8 的倍数

#### 数组对象

- 对象头：Mark Word，8 Byte
- ClassPointer 指针：同上
- 数组长度：视频说是 4 Byte，但经我测试若开启 `+XX:+UseCompressedClassPointers` 是 4 Byte，若用参数 `-XX:+UseCompressedClassPointers` 取消了默认的 class pointer 的压缩，则变为 8 Byte，使用 `ObjectSizeAgent.sizeOf(new byte[1]) == 32` 测试得出的结果
- 数组数据：数据类型长度 * 数组长度
- Padding 的对齐，8 的倍数

#### 观察对象的 size

- 由于 java 并没有 sizeof 这样的运算符，因此我们需要自己实现一个类似 sizeof 运算符的工具类，注意该工具类必须打包成 jar
- 首先，构建一个 maven 工程，并定义下述工具类：
```java
public class ObjectSizeAgent {
    private static Instrumentation instrumentation;

    /**
     * 该方法名称是固定的，通过 META-INF 下的 MANIFEST.MF 中的定义，JVM 会自动调用该方法
     */
    public static void premain(String agentArgs, Instrumentation _inst) {
        instrumentation = _inst;
    }

    /**
     * 计算对象实例的大小，类似 C/C++ 中的 sizeof 运算符
     */
    public static long sizeOf(Object o) {
        return instrumentation.getObjectSize(o);
    }
}
```
- 为了让 jvm 能自动执行上述 premain，我们需要在 MANIFEST.INF 中设置工具类，而在 maven 是在 pom.xml 中进行设置：
```xml
<build>
<plugins>
    <plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-jar-plugin</artifactId>
    <configuration>
        <archive>
        <manifest>
            <addClasspath>true</addClasspath>
        </manifest>
        <manifestEntries>
            <Premain-Class>
            com.hao.util.ObjectSizeAgent
            </Premain-Class>
        </manifestEntries>
        </archive>
    </configuration>
    </plugin>
</plugins>
</build>
```
- 将工程 install 到本地，并引用该工程即可使用工具类，但为了告诉 jvm 我需要这个 premain 我们需要添加 jvm 参数 `-javaagent:E:\data\mavenRepository\com\hao\jar-util\1.0-SNAPSHOT\jar-util-1.0-SNAPSHOT.jar`，这样 java 命令在启动后，jvm 会自动调用 premain 方法
- Java 默认打开 `-XX:+UseCompressedClassPointers -XX:+UseCompressedOops`，我们可以使用 `-XX:+PrintCommandLineFlags` 打印默认的以及配置的 jvm 参数
- 使用该工具类验证类对象发生了 8 Byte 的 Padding 对齐：
```java
// 注意配置 `-XX:+PrintCommandLineFlags -javaagent:xxx.jar` 参数
public class Main {

    public static void main(String[] args) {
        // 8 + 4 + 0 = 12 --> 16 (12 --> 16 表示填充到 16 字节)
        System.out.println(ObjectSizeAgent.sizeOf(new Object()));
        // C1 有一个 int 和 一个 byte
        // 8 + 4 + 5 = 17 --> 24
        System.out.println(ObjectSizeAgent.sizeOf(new C1()));
        // 8 + 4 + 4 + 0 = 16
        System.out.println(ObjectSizeAgent.sizeOf(new int[]{}));
        // 8 + 4 + 4 + 20 = 36 -> 40
        System.out.println(ObjectSizeAgent.sizeOf(new int[5]));
        // 8 + 4 + 4 + 0 = 16
        System.out.println(ObjectSizeAgent.sizeOf(new long[]{}));
        // 8 + 4 + 4 + 16 = 32
        System.out.println(ObjectSizeAgent.sizeOf(new long[2]));
        // 8 + 4 + 4 + 8 = 24，注意 Long 是包装类，算做引用
        System.out.println(ObjectSizeAgent.sizeOf(new Long[2]));
    }
}
```
- 使用 `-XX:-UseCompressedClassPointers` 取消 class pointer 压缩后，再次观察结果，我们可以发现取消压缩后，class pointer 和数组长度都变为 8 Byte
- 使用 `-XX:-UseCompressedOops` 取消引用压缩后，再次观察结果

### (3) 对象头具体包括什么（Mark Word 具体内容）

- Mark Word 非常复杂，且各版本实现都不一样，下面探讨的是 HotSpot 1.8 的实现
- Mark Word 长度为 64/32 位，主要基于最后的 3 位标记对象处于5 不同的状态：4 锁 + 1 GC
- 根据对象所处的不同状态，前面的位有不同的含义，各个状态和对应的位含义如下图所示
![Mark Word](https://gitee.com/h428/img/raw/master/note/00000164.jpg)
- 注意，上图中的 Mark Word 虽为 32 位，但 64 位和其含义一样，多出来的位可能保留未使用或者扩充部分数据使其变得更长，但含义不变，具体对比可参照下图：
![Mark Word2](https://gitee.com/h428/img/raw/master/note/00000165.jpg)
- CMS promoted object 和 GC 有关，free 呢？ // todo
- 详细内容请参考 synchronize 实现原理：新版的 synchronize 有一个锁升级的过程，通过 Mark Word 标记对象的所处的不同锁状态（无锁、偏向、自旋、重量级锁）

**补充问题：当 Java 处在偏向锁、重量级锁状态时，hashCode 存储在哪**

- 当一个对象已经计算过 identity hash code，它就无法进入偏向锁状态
- 当一个对象当前正处于偏向锁状态，并且需要计算其 identity hash code 的话，则它的偏向锁会被撤销，并且锁会膨胀为重量锁
- 重量锁的实现中，ObjectMonitor 类里有字段可以记录下非加锁状态下的 Mark Word，齐总可以存储 identity hash code 的值，或者简单说就是重量级锁可以存下 identity hash code
- synchronize 锁原理：[参考资料1](https://cloud.tencent.com/developer/article/1480590), [参考资料2](https://cloud.tencent.com/developer/article/1484167), [参考资料3](https://cloud.tencent.com/developer/article/1485795), [参考资料4](https://cloud.tencent.com/developer/article/1482500)

### (4) 对象怎么定位

- [参考地址](https://blog.csdn.net/clover_lily/article/details/80095580)
- 对象定位主要有两种方式：句柄池和直接指针，二者各有优劣提到
- 设对于 `T t = new T()`
- 句柄池：引入名为句柄池的简介指针，该简介指针内部有两个指针，一个指向实例对象，一个指向 Class 对象，而 t 指向该句柄池
- 直接指针：t 直接指向实例，实例中包含指向 Class 对象的指针
- HotSpot 采用的是直接指针的方式
- 直接指针对于对象的寻址较快，而句柄池方式对于 GC 算法较为友好效率较高（三色标记），二者各有优劣（深入理解 Java 虚拟机中也有相关内容）


### (5) 对象怎么分配（GC 相关内容）

- 详细原理参考 GC 相关内容，此处给出对象的分配流程图
![分配对象过程](https://gitee.com/h428/img/raw/master/note/00000144.jpg)


### (6) Object o = new Object() 在内存中占用多少字节

- 在 (2) 问中已经分析过原理：8 + 4 + 0 = 12 ---> 16


## JVM 运行时数据区


- JVM 运行时，内存划分为下述区域：
![JVM 运行时数据区](https://gitee.com/h428/img/raw/master/note/00000166.jpg)

- PC：Program Counter，程序计数器，存放指令位置，每个线程都有自己的 PC，虚拟机的运行类似于这样的循环：
```java
while (true) {
    取 PC 中记录的位置，找到对应该位置的指令
    执行该指令
    PC++
}
```
- JVM Stack：每个线程对应一个栈，每个java 编写的方法的调用对应一个栈帧 Frame
- Native Method Stack：本地方法栈，调用的 C/C++ 会在该栈中添加一个栈帧，如调用 JNI
- Direct Memory：直接内存，JDK 1.4 后增加，这部分内存区域不归 JVM 管理，而是给 OS 管理，程序员需要自己释放内存，一般写网络 I/O 程序会用到（NIO 内容，实现 zero copy 提高效率）
- Method Area：方法区，存放 Class 描述以及相关的常量，静态变量，方法字节码等，为所有线程共享，注意方法区包含了常量池 Run-Time Constant Pool
    - Method Area 是逻辑上的概念，主要用于存放 class 及其相关的内容，而 PermGen，MetaSpace 是方法区的具体的实现
    - JDK 1.8 之前，方法区的实现为永久代 PermGen，内部包含了运行时常量池、字符串常量池，但 JDK 1.7 开始，HotSpot 把已经把原本放在永久代的字符串常量池、静态变量等移出，PermGen 只包含了 Class 的描述内容
    - JDK 1.8 及以后，完全取消永久代 PermGen，方法区实现为 MetaSpace
    - 方法区逻辑上包含运行时常量池，在实现上运行时常量池不一定位于方法区中，例如 String 就放在堆区，但是常量池相关的 String Table 应该还是在方法区
- Run-Time Constant Pool：运行时常量池，辅助描述 class 字节码，编译器生成的的字面值、常量会被维护成表，并存储在该区域
    - 在 1.7 之前，HotSpot 直接利用 PermGen 存放字符串常量池，因此在 1.7 之前字符串字面值是分配在方法区内部，FGC 无法回收，过多字面值会导致 OOM（例如循环执行 `String.intern()` 将导致永久代 OOM ）
    - 1.7 及以后，HotSpot 将原本存放在永久代中的字符串常量池移到了 Heap 中，因此最终不使用的字面值会被 FGC 回首（例如循环执行 `String.intern()` 将导致 Heap 的OOM，说明 String 确实分配在 Heap 中）
    - 并非只有编译器才能将常量织入常量池，运行期间也可通过 `String.intern()` 方法进行优化将字符串存入常量池
- Heap：堆，GC 的区域，所有线程共享
- 各线程以及使用的各个区域大致如图：
![线程内存图](https://gitee.com/h428/img/raw/master/note/00000167.jpg)


## 栈帧 Frame 与常用 JVM 指令

- 栈帧用于：存储数据和局部结果、进行动态链接、计算方法返回值、抛出异常
- 每个 Frame 包含下述内容以完成上述功能：
    - Local Variable Table：局部变量表，包括方法参数和方法内部定义的变量
    - Operand Stack：操作栈，用于计算
    - Dynamic Linking：[动态链接](https://blog.csdn.net/qq_41813060/details/88379473)，主要用于方法调用，详细参考 jvms 2.6.3
    - Return Address：返回地址，描述方法的返回值放在什么地方，可以理解为方法出口

### Local Variable & Operand Stack

- 通过解释下面这道面试题，我们可以熟悉 Local Variable Table 和 Operand Stack：
```java
public class Main {
    public static void main(String[] args) {
        int i = 8;
        i = i++; // 8
        // i = ++i; // 9
        System.out.println(i);
    }
}
```
- 首先，不管是 `i = i++;` 还是 `i = ++i;`，涉及的变量相同，因此他们的 Frame 拥有相同的局部变量表，我们使用 jclass lib，可观察到 main 方法共有两个局部变量，一个为 args 一个为 i：
![局部变量表](https://gitee.com/h428/img/raw/master/note/00000168.jpg)
- 对于 `i = i++;`，main 方法的字节码如下：
![i++ 字节码](https://gitee.com/h428/img/raw/master/note/00000169.jpg)
- 我们可以看到，执行流程为（为方便描述，将局部变量表记为 tab，栈顶记为 top，push 和 pop 表示操作栈的入栈出栈）：
    - `bipush 8`：byte 类型 8 入栈，此时 `top = 8`
    - `istore_1`：pop 栈顶并赋值给 `tab[1]`，此时 `tab[1] = 8`
    - `iload_1`：拿到 `tab[1]` 并 push 到栈，此时栈顶 `top = 8, tab[1] = 8`，
    - `iinc 1 by 1`：对 `tab[1]` 执行 + 1 操作，此时 `tab[1] = 9, top = 8`
    - `istore_1`： pop 栈顶并赋值给 `tab[1]`，此时 `tab[1] = 8`
    - 因而最终结果为 8
- 对于 `i = ++i;`，main 方法字节码如下：![ii+ 字节码](https://gitee.com/h428/img/raw/master/note/00000170.jpg)
- 我们可以看到执行流程为：
    - `bipush 8`：byte 类型 8 入栈，此时 `top = 8`
    - `istore_1`：pop 栈顶并赋值给 `tab[1]`，此时 `tab[1] = 8`
    - `iinc 1 by 1`：对 `tab[1]` 执行 + 1 操作，此时 `tab[1] = 9`
    - `iload_1`：拿到 `tab[1]` 并 push 到栈，此时 `tab[1] = 9, top = 9`
    - `istore_1`：pop 栈顶并赋值给 `tab[1]`，此时 `tab[1] = 9`
    - 因而最终结果为 9

**补充**

- 要设计一套机器的指令集，目前主要有两种方法：
    - 基于栈的指令集，我们的 JVM 指令集就采用这种方式
    - 基于寄存器的指令集，汇编语言就是直接基于寄存器的指令集
- JVM 实际上就是参考硬件体系设计的一套指令集和计算解决方案
- JVM 中，Frame 的 Local Variable Table 就类似于临时内存，该临时内存存储了当前方法可用的局部数据，并能直接对其进行取值、赋值、以及很简单的操作
- 而 Frame 的 Operand Stack 则比较类似于体系结构中的通用寄存器，操作一般是针对栈顶的几个元素进行
    - 例如 iadd 指linguisti令会弹出 Operand Stack 栈顶的两个元素，求和并将结果入栈
    - 此时栈顶的两个元素就可以看做是两个通用寄存器
    - iadd 的计算结果仍然存储在栈顶，此时可以看做是存放结算结果的通用寄存器
- 基于栈的指令集设计起来较为简单，而基于寄存器的指令集十分复杂，但速度较快
- 不管软件层级的指令集如何设计，但在硬件层级必定是基于寄存器的

### Dynamic Linking & Return Address

- Dynamic Linking 和 Return Address 主要涉及方法的调用和返回值
- 下面直接给出视频中的例子截图，有问题需要自己手动测试
- Byte 赋值操作：![Byte 赋值操作](https://gitee.com/h428/img/raw/master/note/00000171.jpg)
- Short 赋值操作：![Short 赋值操作](https://gitee.com/h428/img/raw/master/note/00000172.jpg)
- 非静态方法且带参数的 Short 赋值操作：![非静态方法且带参数的 Short 赋值操作](https://gitee.com/h428/img/raw/master/note/00000173.jpg)
- 加法操作：![加法操作](https://gitee.com/h428/img/raw/master/note/00000174.jpg)
- 创建对象及对象方法调用：![创建对象及对象方法调用](https://gitee.com/h428/img/raw/master/note/00000175.jpg)
- 返回值：![返回值](https://gitee.com/h428/img/raw/master/note/00000176.jpg)
- 递归：![递归](https://gitee.com/h428/img/raw/master/note/00000177.jpg)
- invoke 指令：
    - InvokeStatic：调用静态方法
    - InvokeVirtual：多数情况下，实例方法的调用都使用该指令，该指令自带多态
    - InvokeInterface：基于 interface 调用方法时，使用该指令，该指令也具有多态
    - InvokeSpecial：可以直接定位的、不需要多态的方法，使用该指令调用，例如 private 方法，构造方法
    - InvokeDynamic：JVM 最难的指令，主要用于 Lambda 表达式、反射、或者其他动态语言 scala, kotlin、或者 CGLib ASM 动态产生 class 等这些内容会用到的指令
- InvokeDynamic 举例：
```java
public class Main {

    public static void main(String[] args) {
        I i = C::n;
        I i2 = C::n;
        I i3 = C::n;
        System.out.println(i.getClass());
        System.out.println(i2.getClass());
        System.out.println(i3.getClass());
    }

    public static interface I {

        void m();
    }

    public static class C {

        static void n() {
            System.out.println("hello");
        }
    }
}
```
- 上述代码 main 方法中对 lambda 表达式的生成都是使用 InvokeDynamic 指令，其会动态创建 Class 并创建实例，然后赋值给接口，最后对接口执行方法时仍然使用 InvokeVirtual


- 总结：
    - `<cinit>`：静态初始化块
    - `<init>`：构造方法
    - `_store`：pop 栈顶并存到 Local Variable
    - `_load`：取出 Local Variable 并入栈
    - `invoke_XXX`：调用方法

## 补充内容

- jvm 规定的 8 大原子操作，目前 JSR-133 以启用这种描述方式，但 JMM 没有变化，参《深入理解 Java 虚拟机》 P364 ![java 8 大原子操作](https://gitee.com/h428/img/raw/master/note/00000158.jpg)
- Java 并发内存模型，即并发 JMM
![JMM](https://gitee.com/h428/img/raw/master/note/00000159.jpg)
- happens-before 原则
![happens-before 原则](https://gitee.com/h428/img/raw/master/note/00000160.jpg)
- as if serial：不管如何排序，单线程执行结果不会改变


# 垃圾回收

- 目标：熟悉 GC 常用算法，熟悉常见垃圾收集器，具有实际 JVM 调优经验

## 如何定位垃圾

- 引用计数法：对于循环引用问题无法解决
- 根可达性算法：Root Searching，从 GC Roots 开始搜索，标记所有可用及不可用内容，GC Roots 包含：
    - 虚拟机栈：各个线程的局部变量，即所有栈帧中的变量
    - 本地方法栈
    - 常量池
    - 静态变量
    - Clazz：加载的 class
![GC Roots](https://gitee.com/h428/img/raw/master/note/00000179.jpg)

## GC 算法

- Mark-Sweep：标记清除算法
    - 算法相对简单，存活对象比较多的情况下效率较高，因为需要清除的对象很少
    - 其需要两边扫描，执行效率偏低
    - 容易产生碎片
    - 很显然，该算法不适合 Eden 区，因为 Eden 区的存活对象较少
- Copying：拷贝算法
    - 把内存一分为二，执行清除时将剩下的对象拷贝到另一边，自己这边标记全部清除
    - 适用于存活对象较少的情况，因为这样需要拷贝的对象很少
    - 只需扫描一遍，扫描的同时进行拷贝，效率高，没有碎片
    - 缺点：空间浪费，移动复制对象时需要调整对象引用
    - 该算法适合于年轻代，因此 G1 之前的回收器的年轻代采用该种 GC 算法
- Mark-Compact：标记压缩算法
    - 在 Mark-Sweep 的基础上同时进行压缩整理，避免内存碎片
    - 优点：不会产生碎片，不会内存减半
    - 缺点：扫描两次，且需要移动对象，效率偏低
    - 该算法适合于老年代，G1 之前的回收器的老年代采用该种 GC 算法，但由于老年代较大，STW 时间较长，因此 JVM 还做了优化（例如 CMS 的并发标记）

## 分代模型

- 我们前面拿年轻代、老年代举例，但并不是所有的回收器都采用分代模型：
    - 除 Epsilon、ZGC、Shenandoah 之外的 GC 回收器都使用逻辑分代模型
    - 其中 G1 是逻辑上分代，物理上不分代，而是一块块的 Region
    - 除此之外的，不仅逻辑分代，而且物理分代，例如 CMS，Parallel Scavenge + Parallel Old 都采用了逻辑分代
- 逻辑分代对堆内存的划分大致如下：
![堆逻辑分代](https://gitee.com/h428/img/raw/master/note/00000180.jpg)
- 在 JDK 1.7 中，除了年轻代和老年代，还有一个永久代 Permanent Generation，其为 Method Area 的实现，但在 1.8 之后，HotSpot 取消了永久代，采用元数据组 MetaSpace 实现 Method Area
- 还有一个细节上的区别是，字符串常量池在 1.7 放在永久代中，在 1.8 则放在堆中，MetaSpace 只放 Class 和相关方法等元信息
- 年轻代的 GC 称作 MinorGC/YGC，老年代的 GC 称作 MajorGC/FullGC，可使用 `-Xmn -Xms/-Xmx` 分别设置年轻代大小和堆总大小，在 jdk 1.8 中默认比例为 1:2
- 可使用命令 `java -XX:+PrintFlagsFinal -version | grep NewRatio` 查看年轻代、老年代内存比例，经验证在 1.6, 1.7, 1.8 中都为 1:2
![分代设置](https://gitee.com/h428/img/raw/master/note/00000143.jpg)
- 对于年轻代的回收，主要采用 copying 算法，先在栈上分配，分配不下则试图在 Eden 区分配，当 Eden 区满了触发 MinorGC，将存活的变量拷贝到其中一个 survivor 区，清空 eden 区和另一个 survivor 区，当分代年龄达到设定的阈值时，进入老年代
![年轻代回收](https://gitee.com/h428/img/raw/master/note/00000181.jpg)
- 可以使用参数 `-XX:MaxTenuringThreshold` 设置年轻代进入老年代的阈值，需要特别注意的是，根据对象的 Mark Word，我们知道分代年龄只有 4 位，因此最大值为 15，这也是大多数回收器的默认值
- 除了阈值外，还有动态年龄的判断能让对象从年轻代进入老年代，若某次 GC 完成后 survivor 区域超过 50% 空间仍存活对象，则会将年龄最大的部分对象放入老年代
![阈值与动态年龄](https://gitee.com/h428/img/raw/master/note/00000183.jpg)
- 分配担保：YGC 期间，survivor 区空间不够用了，空间担保使得新分配的对象直接进入老年代
- 此外，为了对标 C/C++ 中的 Stack，JVM 引入了栈，对于满足栈分配条件的对象，会先尝试在栈上分配，否则在线程本地 TLAB 分配（位于 Eden 区，为线程独享，避免分配争用）
![分配](https://gitee.com/h428/img/raw/master/note/00000182.jpg)
- 要在栈上分配，需要满足下列条件：
    - 线程私有小对象：是个小对象，且赋值给线程的局部变量
    - 无逃逸：只在某一块代码块内使用，出了代码块没有别人引用它
    - 支持标量替换：可以使用多个普通的成员替换该对象
    - 在栈上分配对象速度比堆快，且无需 GC 接入，在代码块结束后，pop 出栈即可，因而分配和回收的效率较高
- 线程本地分配缓存 TLAB（Thread Local Allocation）也位于 Eden 区，但为各线程私有，避免了多个线程对 Eden 区争用的同步问题，提高内存分配效率
- 下面是关于栈上分配和 TLAB 的测试程序：
```java
public class Main {

    class User {

        int d;
        String name;

        public User(int d, String name) {
            this.d = d;
            this.name = name;
        }
    }

    void alloc(int i) {
        // new User() 在方法外部无引用指向它，逃不出该方法，则为无逃逸
        new User(i, "name " + i);
    }

    // 关闭逃逸分析、标量替换、线程专有对象分配后，可发现运行时间增加，因为将导致不再 Stack 上分配，同时还会有 Eden 区的争用问题
    // -XX:-DoEscapeAnalysis -XX:-EliminateAllocations -XX:-UseTLAB
    // 可以互相组合控制变量观察运行时间
    public static void main(String[] args) {

        Main main = new Main();
        long start = System.nanoTime();

        for (int i = 0; i < 1000_0000; i++) {
            main.alloc(i);
        }

        long end = System.nanoTime();
        System.out.println((end - start) / 100000);

    }
}
```
- 总结一下，分代模型的对象分配过程如下：![对象分配过程](https://gitee.com/h428/img/raw/master/note/00000144.jpg)


## 垃圾回收器

- Java 目前出现了 10 种垃圾回收器：Serial、Serial Old、Parallel Scavenge、Parallel Old、Par New、CMS（ConcurrentMarkSweep）、G1、ZGC、Shenandoah、Eplison
![垃圾回收器](https://gitee.com/h428/img/raw/master/note/00000142.jpg)
- 注意 STW 不是立马停，而是到一个 safe point 才停
- 垃圾收集器与内存大小的关系：
    - Serial：几十兆
    - Parallel：上百兆 - 几个 G
    - CMS：20 G
    - G1：上百 G
    - ZGC：4 T

### Serial + Serial Old

- 初代 JVM 采用的 GC 算法组合
- Serial：年轻代的单线程回收器，采用 copying 回收算法，会 STW，单 CPU 效率最高，虚拟机是 Client 模式时采用的默认垃圾回收器
- Serial Old：老年代的单线程回收器，采用 mark-sweep-compact 算法，会 STW
- 该种组合基本只能用于内存非常小的情况，随着内存的增大，该组合的效率大大降低，因此现在用的极少

### Parallel Scavenge + Parallel Old

- 目前还有很多生产环境采用该组合，这也是 jdk 1.8 默认采用的 GC 算法组合，因此若上线时没做任何 GC 调优设置，采用的就是该种组合
- Parallel Scavenge：年轻代的多线程回收器，采用 copying 回收算法，会 STW，相当于 Serial 的多线程版本
- Parallel Old：老年代的多线程回收器，采用 mark-sweep-compact 算法，会 STW，相当于 Serial Old 的多线程版本
- 10 G 的内存，采用 PS + PO，一次 FullGC 大约需要十几秒
- 特别注意 Parallel 只的是并行标记和回收，并没有并发标记和回收，并发标记和回收是从 CMS 开始才出现的


### ParNew + CMS + Serial Old

- 随着内存的增大，多线程并发回收也难以满足需求，因而出现了 ParNew + CMS 的回收器组合，但实际上该组合很多 bug，因而 jdk 1.8 默认采用 Parallel Scavenge + Parallel Old
- ParNew：即 Parallel New，Parallel Scavenge 变种，为了配合 CMS 而引进的年轻代多线程回收器，默认线程数为 CPU 核数，采用 copying 算法，会 STW
- CMS：即 concurrent mark sweep，并行回收算法，主要针对老年代，配合 ParNew 使用，在 concurrent mark 阶段能让垃圾回收线程和工作线程同时进行，主要包含 4 个阶段：
    - initial mark：会 STW 但只标记 GC Roots，因此时间很短
    - concurrent mark：并发标记，不会 STW，工作线程可以和并发标记同时进行
    - remark：再次 STW 来找出冲突部分（已经被标记删除的又取消了），也是整个并发标记算法的难点（三色标记法）
    - concurrent sweep：并发清理
- CMS 问题 1：Memory Fragment，即内存碎片化，由于 CMS 针对老年代的回收，采用的是 mark-sweep 算法，因此必定会有内存碎片化的问题
- CMS 问题 2：浮动垃圾，在执行第 4 步并发清理的过程中，可能同时产生垃圾，这些垃圾无法在该阶段清理，只能等到下一次 FullGC 才会被清理，这些垃圾称为浮动垃圾
- CMS 重大 Bug：随着老年代碎片化越来越严重导致无法正常分配一个对象时，CMS 会采用极端的做法，采用一个单线程执行 Serial Old 将整个老年代 mark-sweep-compact 一遍，该情况发生时甚至可能直接导致 GC 时卡顿好几天
- 解决方法：降低触发 CMS 的阈值 `-XX:CMSInitiatingOccupancyFraction`
- 由于 CMS 的 bug 比较多，因此任何一个 jdk 的默认垃圾回收器都不是 CMS
- 虽然 CMS 毛病和 bug 比较多，比如会产生碎片化问题，但其作为并发 GC 的里程碑，处于一个承前启后的地位，它开启了并发回收，理解 CMS 是理解并发回收的关键，因此需要理解好 CMS 才能更好的地理解 G1 和 ZGC
- 并发回收算法的关键是如何解决冲突问题，这也是后续包括 G1, ZGC 在内的所有并发回收算法的关键，对于 remark 阶段的算法，CMS、G1、ZGC 分别采用三色标记 + Incremental Update、三色标记 + SATB、颜色指针实现，三色标记参 [并发标记算法：三色标记](#并发标记算法：三色标记)

### G1

- 传统的垃圾回收器，例如 PS + PO，都在物理上分代，当内存特别大时，老年代往往也很大，从而导致 FullGC 十分耗时，基于该原因，G1 横空出世
- [G1](https://www.oracle.com/technical-resources/articles/javalg1gc.html)：号称 STW 在 10 ms 以内，其在逻辑上分代，物理上不分代，而是一个个 Region
- 由于 G1 回收器逻辑上分代，物理不分带的堆内存模型，使得其支持上百 G 内存的回收不卡顿（ZGC、Shenandoah 支持 4 T 内存的回收不卡顿）
- G1 是一种服务端应用使用的垃圾回收器，目标是用在多核、大内存的机器上，它在大多数情况下可以实现指定的 GC 暂停时间，同时还能保持较高的吞吐量，其具有如下特点：
    - 并发收集
    - 压缩空闲空间不会延长 GC 的暂停时间
    - 更易预测的 GC 暂停时间
    - 适用于不需要实现很高的吞吐量的场景
- 据研究，G1 的吞吐量比 PS + PO 降低了 15%，但 STW 时间一般只会在 10 - 200 ms

#### 基本数据结构

**Card Table**

- 在分代模型中，做 YGC 时，对于年轻代的对象，肯定是要扫描一遍的，但对于要查询老年代中的对象也引用了年轻代对象以避免有用的年轻代对象被回收，必须通过扫描老年代得到，这就导致每次 YGC 必须扫描一遍老年代，导致效率十分低下
- **为了避免 YGC 时扫描整个老年代**，引入 Card Table 概念，在逻辑上，将老年代划分为一个个 Card，并标记每个 Card 是否引用年轻代对象，是则标记为 Dirty，这样做 YGC 时只需要Dirty 的 Card 即可，因为只有 Dirty 的 Card 引用了年轻代的对象
- 因此对于 YGC，并不需要完全地执行根可达，当发现某个对象位于非 Dirty 的 Card 后，该分支就不继续往后扫描了，大大节省了效率
- 传统的分代模型都存在该 Card Table，而 G1 的 Region 里面还会进一步划分 Card，对象基于 Card 划分，至少占用一个 Card？（未验证，我是通过 RSet 的 K,V 猜测的，方便自己理解）

**CSet**

- CSet 即 Collection Set，存储一组可以被回收的 Region 的集合
- 在 CSet 的 Region 中存活的数据会在 GC 过程中被移动到另一个可用的 Region，这是通过 copy 完成的，因此没有内存碎片化问题
- 注意 CSet 中的分区可以来自 Eden、Survivor、老年代
- CSet 会占用不到整个堆空间的 1% 大小

**RSet**

- RSet 即 Remembered Set，每个 Region 都拥有一个 RSet，记录了其他 Region 中的对象到本 Region 对象的引用（谁指向了我），有点类似 Card Table，但 RSet 更加细化
- 首先明确，Region 内部进一步被划分为 Card
- 这个 RSet 其实是一个 Hash Table，Key 是别的 Region 的起始地址，Value 是一个集合，里面的元素是 Card Table 的 Index；[参考地址](https://tech.meituan.com/2016/09/23/g1.html#rset)
- 即对于 Region 的 RSet 的一条记录：记录了哪个其他 Region 的哪几个 Card 引用了当前 Region，我们通过 K-V 即 Region-Card 即可快速定位哪个地方引用了当前 Region
- 通过 RSet，在垃圾回收时可以不用扫描整个 Heap，而只需扫描 RSet 即可，这也是 G1 高速回收的关键，也是后续三色标记算法实现的关键
- RSet 缺点：
    - 浪费空间，每个 Region 需要维护 RSet
    - 对赋值操作有一定的影响，每次赋值需要更新引用的原有指向对象所在 Region 的 RSet 和新指向对象所在 Region 的 RSet（这在 GC 中称为写屏障，注意这个和内存屏障完全两个概念；[barrier 参考地址，看不太懂](https://blog.csdn.net/luzhensmart/article/details/106052574)）

#### G1 内存模型

- G1 将内存划分为一个个 Region，Region 在逻辑上可能为 Eden、Suvivor、Old、Humongous，其在 MixedGC 会优先清理垃圾最多的 Old Region，即 Garbage First，即 G1
![G1 内存模型](https://gitee.com/h428/img/raw/master/note/00000188.jpg)
- 需要注意的是，G1 仍然有 FullGC 和 STW，这其实是 GC 算法不可避免的，只能尽量减少 STW 的时间
- 每个 Region 的大小取值可能为 1M, 2M, 4M, 8M, 16M, 32M，也可以通过参数手动指定：`-XX:G1HeapRegionSize`
- G1 新老年代的比例是弹性的，会根据 GC 时间动态调整，一般不用手工指定，也不建议手工指定，因为这是 G1 预测时间的基准
- 若某次 YGC 的 STW 时间较长，超出设定的预期时间，则 G1 动态地将年轻代比例降低一点
- Humongous Object：大对象，超过一个Region 的 50% 则会被当做大对象，若分配内存时检测到超出 Region Size 的一半，则会分配在 Humongous 区域

#### 回收原理

- YGC：
    - 当尝试在 Eden 空间分配发现内存不足时，会触发 YGC
    - YGC 时大多数时间是多线程并行执行的，类似 Parallel Scavenge
    - 其中 RSet 可避免 YGC 时扫描所有的 Old Region，而是直接把 RSet 中的对象 copy 到其他 Region 然后重新指向引用
    - 整个 YGC 期间会 STW，但由于 Eden + Survivor 的比例不会很大，因此不会长时间 STW
    - 此外，G1 根据本次 STW 时间动态调整年轻代大小，以减少下次 YGC 的 STW 时间 
- MixedGC：
    - 当整个 Heap 的已用空间达到一定比例时，则会触发 MixedGC
    - MixedGC 的基本流程和 CMS 基本相同，只有清理阶段阶段略有区别，G1 的清理阶段除了年轻代以外，还会对 Old Region 进行筛选，选择垃圾比例最高的 Old Region 回收，这也是 G1 名称的由来；
    - 还有一个区别就是 G1 清理阶段也是采用的 copying 算法，因此会 STW，但不会有内存碎片；而 CMS 是采用 mark-sweep 的并发清理，不会 STW 但会造成内存碎片问题
    - 默认比例为 45%，可使用 `-XX:InitiatingHeapOccupacyPercent` 手动设置
- FGC：当整个 Heap 空间不足或者手动调用了 `System.gc()` 则触发 FGC，即对象分配不下了会产生 FGC
- 当对象分配的特别快，GC 线程来不及回收导致内存不足时，会触发 FGC，因此针对 G1 的调优，主要是要达到避免 FGC 的目的，YGC 的区域很小，MixedGC 的第二阶段是并发的，因此他们 STW 时间很短，一般不会造成阻塞
- 若 G1 产生了 FGC，如何处理：
    - 扩内存
    - 提高 CPU性能：回收的快，业务逻辑产生对象的速度固定，垃圾回收越快，内存空间越大
    - 降低 MixedGC 触发的阈值，让 MixedGC 提早发生（默认是 45%）
- 生产环境能随便 dum 吗：小堆影响不大，大堆会造成服务暂停或卡顿（加 live 可以缓解），dump 前会有 FGC
- 常见的 OOM 问题有哪些：堆、栈、MethodArea、直接内存
- G1 三色标记 + SATB


### 并发标记算法：三色标记

- CMS 与 G1 都采用三色标记算法实现并发标记与再标记，区别在于 CMS 采用 三色标记 + Incremental Update，G1 采用 三色标记 + SATB
- 三色标记法，为每个对象标记三种颜色，用于辅助 GC 的标记：
    - 白色：未被标记的对象
    - 灰色：自身被标记，成员变量未被标记
    - 黑色：自身和成员变量均已标记完成
- 漏标的充分必要条件，两个条件同时满足则发生漏标：在并发标记的过程中，引用关系改变，黑色指向了白色，与此同时，灰色指向白色消失了，则发生漏标
- B 原本指向 D，A 原本不指向 D，但在并发标记过程的同时指针改变，此时由于 A 已经标记为黑色，不再继续往后标记，从而导致 D 被漏标了，此时若不对黑色 A 重新扫描，会把白色 D 对象当做没有新引用从而回收掉
![漏标](https://gitee.com/h428/img/raw/master/note/00000189.jpg)
- 漏标解决方案：打破上述两个条件的其中一个，即破坏其充要条件
    - 跟踪 A 指向了 D：即 Incremental Update，例如把 A 重新标记为灰色
    - 跟踪 B 到 D 的删除：SATB，Snapshot at the begining，维护引用的删除，当 B 到 D 的引用消失时，把这个引用推到 GC 堆栈，保证 D 还能被 GC 扫描到
- 为什么 G1 使用 SATB：
    - 很显然 SATB 效率更高，采用 Incremental Update 让 A 变为灰色时，将导致重新扫描一遍 A 的成员，若 A 有很多成员，则效率很低
    - 若灰色 B 指向 D 引用消失时，D 并没有黑色成员指向白色，此时由于引用被 push 到 GC 栈，会导致 D 无法回收（此时 D 应该被回收才对）
    - 但由于 G1 恰好有 RSet 的存在，对于 GC 栈中的引用，找到引用对象的 Region 并查询 RSet，可快速判定当前对象是否还有 Region 指向它，没有则可以直接回收，不需要扫描整个堆区查找指向白色 D 的引用，因此 SATB 配合 RSet 浑然天成
- Remark 阶段的算法：
![Remark](https://gitee.com/h428/img/raw/master/note/00000145.jpg)

### ZGC

- ZGC：号称 STW 在 10 ms 一下，实测一般在 1 - 2 ms 左右，十分强大
- ZGC 逻辑物理都不分代，和 Shenandoah 一样都来自于 C4
- ColoredPointer + 写屏障？

### Shenandoah

- ColoredPointer + 读屏障？

### Epsilon

- Epsilon：Debug 用的，不用深究

## 如何选择垃圾回收器

### 垃圾回收器对比

- Serial Old、Parallel Old 的组合基本已经没人用了，这是早期内存较低时采用的回收器，随着内存变大，该种组合回收效率大大降低，导致卡死现象
- jdk 1.8 默认采用 Parallel Scavenge + Parallel Old 的组合（jdk 1.8 默认使用的 `-XX:+UseParallelGC` 就是这种组合），大多数人不知道 GC 原理，因此生产环境大多采用的就是该组合的垃圾回收器，调优大多数调优场景主要针对该组合，因为 G1、ZGC 已经优化得很好，调优参数大大减小
- jdk 1.9 默认采用的垃圾回收器为 G1
- 对于 1.8 以上的 jdk，推荐采用 G1 垃圾回收器，尤其是分布式场合
- 对于分布式锁，一般有一个锁续命问题，但若锁续命时遇上垃圾回收，会导致无法锁续命，因为锁续命是按照时长来的，而若在锁续命过程正好遇到了垃圾回收，尤其是老年代的垃圾回收，会因为超时导致无法续命，锁消失，例如本来 3 秒锁续命一次，但 Parallel Scavenge + Parallel Old 的组合对老年代进行 GC 时，超过 3 秒是很正常的，因此分布式情况下，建议采用 G1

### 常见垃圾回收器组合参数设定（1.8）

- `-XX:+UseSerialGC`：表示 Serial New(DefNew) + Serial Old
    - 小型程序，默认情况下不会是这种选项，HotSpot 会根据计算及配置和 jdk 版本自动选择收集器
- `-XX:+UseParNewGC`：表示 ParNew + SerialOld
    - 这个组合已经很少用，在某些版本已经废弃
    - [参考](https://stackoverflow.com/questions/34962257/why-remove-support-for-parnewserialold-anddefn)
- `-XX:+UseConc(urrent)MarkSweepGC`：ParNew + CMS + Serial Old
- `-XX:+UseParallelGC`：表示 Parallel Scavenge + Parallel Old（1.8 默认组合）
- `-XX:+UseParallelOldGC`：表示 Parallel Scavenge + Parallel Old
- `-XX:+UseG1GC`：表示 G1
- Linux中没找到默认 GC 的查看方法，而 windows 添加下列参数会打印 UseParallelGC
    - `java +XX:+PrintCommandLineFlags -version`
    - 通过 GC 的日志来分辨采用了什么 GC 算法
- Linux 下 1.8 版本默认的垃圾回收器到底是什么
    - 1.8.0_181 默认看不出来 Copy MarkCompact
    - 1.8.0_222默认 PS + PO

# GC 调优（重点）

## JVM 参数分类

- [jvm 命令行参数参考](https://docs.oracle.com/javase/8/docs/technotes/tools/unix/java.html)
- 标准参数：以 `-` 开头，所有 HotSpot 都支持
- 非标准参数：以 `-X` 开头，特定版本 HotSpot 支持特定的命令
- 不稳定：以 `-XX` 开头，下个版本可能取消，例如
    - `java -XX:+PrintFlagsFinal` 设置值，最终生效值
    - `java -XX:+PrintFlagsInitial` 默认值参数值
    - `java -XX:+PrintCommandLineFlags` 命令行参数
- 可以利用 `java -XX:+PrintFlagsFinal -version | grep xxx` 查看 `-XX` 下有那些相关参数，其他类别参数同理

### 常用参数

- `-XX:+PrintFlagsFinal`：打印 `-XX` 类参数最终生效的值
- `-XX:+PrintFlagsInitial`：打印 `-XX` 类参数的默认值
- `-XX:+PrintCommandLineFlags`：打印本次执行设置的虚拟机参数
- `-Xmn10M`：设置年轻代为 10 M
- `-Xms40M -Xmx60M`：设置老年代的最小值为 40 M，最大值为 60 M，注意这两个一般设置为相同的值以避免内存抖动
- `-XX:+PrintGC`：打印 GC 信息
- `-XX:+PrintGCDetails`：打印详细 GC
- `-XX:+PrintGCTimeStamps`：打印 GC 时的时间戳
- `-XX:+PrintGCCause`：打印 GC 产生的原因
- `-XX:+UseConcMarkSweepGC`：使用 CMS + ParNew 组合

### 测试样例

- 我们采用如下的试验小程序：
```java
// 实验用程序，执行时加上 -XX:+PrintCommandLineFlags 以观察 -XX 相关的参数信息以及 GC 信息
public class Main {
    public static void main(String[] args) {
        System.out.println("HelloGc!");
        List<byte[]> list = new LinkedList<>();
        while (true) {
            byte[] b = new byte[1024*1024]; // 每个节点 1 M
            list.add(b);
        }
    }
}
```
- 区分概念：内存泄漏 memory leak 和内存溢出 out of memory
- 我们执行 `java -XX:+PrintCommandLineFlags Main` 观察命令行参数，该命令会打印如下内容： ![设置的 VM 参数](https://gitee.com/h428/img/raw/master/note/00000186.jpg)
- 使用 `java -Xmn10M -Xms40M -Xmx60M -XX:+PrintCommandLineFlags -XX:+PrintGCDetails Main` 设置堆的各分代大小，同时打印 GC 详细信息
- GC 详细信息前半部分解释如下：![GC 详细信息前半部分](https://gitee.com/h428/img/raw/master/note/00000184.jpg)
- GC 详细信息后半部分解释如下：![GC 详细信息后半部分](https://gitee.com/h428/img/raw/master/note/00000185.jpg)


## 调优思路

### 基础概念

- 吞吐量：用户代码执行时间 / （用户代码执行时间 + 垃圾回收时间）
- 响应时间：STW 越短，响应时间越好
- 调优之前，首先确定项目追求啥：吞吐量优先，还是响应时间优先，还是在满足一定响应时间的情况下，需要达到多大的吞吐量，一般分为如下三类：
- 例如：
    - 数据挖掘、科学计算等：吞吐量优先
    - 网站、GUI、对外提供的 API：响应时间优先
- 吞吐量优先的一般选择 PS + PO，响应时间优先则看版本，1.8 尽量选 G1，实在不行选 PS + PO 后再具体调优
- 什么是调优？主要分为如下三类
    - 根据需求进行 JVM 规划和预调优
    - 优化 JVM 运行环境：解决 jvm 越来越慢、卡顿问题
    - 解决 JVM 运行过程中出现的各种问题，例如 OOM、泄露等
- 调优要针对使用的具体的垃圾回收器，设定合适的参数，以尽量减少 Full GC 的次数以及 STW 的时间
- 此外，调优中有一重大利器为重启，对于部分情况，例如游戏服务器，中间对象特别多，重启一下会清空大量内存，再高可用的情况下可以直接利用“重启大法”进行调优，若只有单击，可以通过提前发布通知方式，然后重启服务

**补充概念**

- QPS/TPS：平均每秒钟能处理的请求/事务数量
- 并发：某个时刻有多少个访问同时到来，即需要并发处理多少个请求
- 注意，QPS ≠ 并发数，显然 QPS = 并发数 / 平均响应时间
- 根据日常经验，80% 的访问量集中在 20% 的时间，设每天有 300w 访问量，实际需要机器达到多少 qps 才能满足
    - qps = (300w * 0.8) / (24 * 3600 * 0.2) = 139 qps
- 比如微博每天 1 亿多 pv 的系统一般也就 1500 QPS，5000 QPS 峰值
- 2C 4G 机器单机一般 1000 QPS
- 8C 8G 机器单机可承受 7000 QPS

### 调优规划

- 调优基于特定的业务场景，没有业务场景的调优都是耍流氓
- 无监控，不调优：调优时，需要做压力测试，并能看到结果

**大致步骤**

- 熟悉业务场景（没有最好的垃圾回收器，只有最合适的垃圾回收器）
    - 响应时间、停顿时间（CMS、G1、ZGC）：需要及时给用户响应
    - 吞吐量 = 用户时间 / （用户时间 + GC 时间）
- 选择合适的回收器组合
- 计算内存需求：该步骤很难计算，需要经验
- 选定 CPU，越高越好
- 设定日志参数：
    - `-Xloggc:/opt/logs/xxx-xxx-gc-%t.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=20M -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintGCCause`：5 个日志文件，用生成日期命名，循环产生，每个最大 20 M，最后一个满的时候，重新生成第一个
    - 或者每天产生一个日志文件
- 观察日志情况

#### 垂直电商，最高每日百万订单，处理订单系统需要什么样的服务器配置

- 这个问题问的比较业余，因为根据给定的不够详细的信息，很多不同的服务器配置都能支撑
- 每日 100 w 订单，根据二八原则，有 `qps = (100w * 0.8) / (24 * 3600 * 0.2) = 46.3`
- 或者放大点用，7.2 成订单两个小时来，每小时 360000 订单，即 100 订单每秒，有 qps = 100（高峰），甚至也有可能是 1000 个每秒，因此我们需要找高峰
- 但计算高峰内存是很难的，一般需要足够的经验值，否则只能压测预估
- 非要计算的话，计算一个订单产生需要的内存，然后乘以高峰即为最小内存
- 假设一个订单需要 1 M 内存（实际上已经很高了），则高峰 1000 个订单，1 G 内存搞定了，甚至若处理得够快，最小内存还可降低，因此实际上是很难估计的
- 专业点的问法：要求相应时间 100 ms，然后做压力测试，进行预估服务器配置


#### 12306 遭遇春节大规模抢票如何支撑

- 12306 是中国并发量最大的秒杀网站，号称 100 w 的最高并发量，淘宝双十一才 50
- 架构大致：CDN -> LVS -> Nginx -> 业务系统 -> 每台机器 1W 并发（单击 10 K 问题） -> 100 台机器
- 普通电商系统：下单 -> 订单系统（I/O） -> 减库存 -> 等待用户付款
- 12306 的一种可能模型：下单 -> 减库存和订单（Redis、kafka）同时异步进行 -> 等付款
- 减库存最后还会把压力压到一台服务器
- 可以做分布式本地库存 + 单独服务器做库存均衡
- 大流量处理方法：分而治之

#### 如何得到一个事务会消耗多少内存

- 弄台机器，看能承受多少 TPS，是不是达到目标，扩容或者调优，让它达到
- 用压测来确定


### 优化运行环境思路

- 有一个 50 万 PV 的资料类网站（从磁盘提取文档到内存）原服务器 32 位，1.5 G 的堆，用户反馈网站比较缓慢，因此公司决定升级，新的服务器为 64 位，16 G 的堆内存，结果用户反馈卡顿十分严重，反而比以前效率更低了，为什么？如何优化？
    - 很多用户浏览页面，很多数据加载到内存，内存不足，频繁 GC，STW 时间长，从而导致响应时间变慢
    - 加内存后更卡顿，是因为内存越大，FullGC 时间越长，需要考虑将 PS 换成 PN + CMS、G1
- 系统 CPU 经常 100%，如何调优？（面试高频，需要实战）
    - 1、CPU 100% 一定有线程在真用系统资源，找出哪个进程 CPU 高（top）
    - 2、找出该进程的那个线程 CPU 占用高（top -Hp）
    - 3、导出该线程的堆栈（jstack）
    - 4、查找那个方法（栈帧）消耗时间（jstack）
    - 具体如何解决以及工具的使用参考后续实战调优例子
- 系统内存飙高，如何查找问题？（面试高频，需要实战）
    - 1、导出堆内存（jmap）
    - 2、分析（jhat, jvisualvm, mat, jprofiler）
    - 具体如何解决以及工具的使用参考后续实战调优例子
- 如何监控 JVM：使用 jstate, jvisualvm, jprofiler, arthas, top


## 调优实战：一个例子熟悉工具和命令的使用

- 下述代码模拟风控场景
```java
/**
 * 从数据库中读取信用数据，套用模型，并把结果记录和传输
 *
 * @author hao
 */
public class Main {

    // 数据库实体类
    private static class CardInfo {
        BigDecimal price = new BigDecimal(0.0);
        String name = "张三";
        int age = 5;
        Date birthday = new Date();

        public void m() {} // 模型方法
    }

    // 线程池：定时任务，50 个线程，DiscardOldestPolicy 策略
    private static ScheduledThreadPoolExecutor executor = new ScheduledThreadPoolExecutor(50,
            new DiscardOldestPolicy());

    public static void main(String[] args) throws Exception {
        for (;;) {
            modelFit();
            Thread.sleep(100); // 模拟业务停顿
        }
    }

    private static void modelFit() {
        List<CardInfo> taskList = getAllCatdInfo(); // 查询数据
        taskList.forEach(cardInfo -> {
            executor.scheduleWithFixedDelay(() -> {
                cardInfo.m(); // 对每个对象执行模型判定，进行风控，不通过不予以贷款
            }, 2, 3, TimeUnit.SECONDS);
        });
    }

    // 模拟数据库查询：查询所有 CardInfo 信息
    private static List<CardInfo> getAllCatdInfo() {
        List<CardInfo> taskList = new ArrayList<>();

        for (int i = 0; i < 100; i++) {
            CardInfo cardInfo = new CardInfo();
            taskList.add(cardInfo);
        }

        return taskList;
    }
}
```

### 内置 jdk 分析工具

- `jinfo pid`：打印指定 Java 进程的虚拟机参数的详细信息

#### 线程相关：如 CPU 高占用、死锁等问题

- 启动项目：`java -Xms200M -Xmx200M -XX:+PrintGC Main`
- 一般是运维团队首先收到报警信息，比如 CPU、内存占用率高，此时才开始定位问题
- top 命令：找到内存不断增长，CPU 占用率居高不下的进程 pid
- 使用 `top -Hp pid`：查看该进程的线程信息，找到 CPU 占用率占用率很高的线程
- `jps`：列出当前系统的所有 java 进程
- `jstack pid`：
    - 列出指定 java 进程下的所有线程的详细信息以及运行状态等
    - 需要注意的是其给出的线程 nid 是 16 进制的
    - 若 cpu 占用率很高，但是很多 thread 却都处于 waiting 状态，则程序大概率存在问题
    - 重点关注 waiting blocked 等线程状态信息
    - 处于 waiting 时，要特别关注 waiting on，线程在等待什么导致被阻塞了
    - 加入一个进程中有 100 个线程，很多线程都在 waiting on xxx，一定要找到是哪个线程持有这把锁：搜索 jstack 信息，找到 xxx，看看哪个线程持有该锁
- 作业：
    - 写一个死锁程序，使用 jstack 观察
    - 写一个程序，一个线程持有锁不释放，其他线程等待
- 为什么阿狸规范里规定，线程的名称（尤其是线程池）都要写有意义的名称？怎样自定义线程池里的线程名

#### 内存相关：如 OOM 问题

- 同样显示运维通知、top 定位内存相关进程 id
- `jstat -gc pid`：打印 gc 信息，用于动态观察 gc 情况，阅读 GC 日志发现频繁 GC 则说明发生内存问题，需要进一步定位调优
- `jstat -gc pid 500`：每 500 ms 打印 GC 情况
- 可以使用 jconsole 远程连接并监控 jvm，但依赖于 jmx 协议，服务器启动的同时必须指定 jmx 相关参数和端口，大致内容如下：
    - `java -Djava.rmi.server.hostname=192.168.25.41 -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=11111 -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -XX:+PrintGC -Xms200M -Xmx200M Main`
![jconsole](https://gitee.com/h428/img/raw/master/note/00000187.jpg)
- 上述配置的协议，也可以使用 jvisualvm 进行连接，且 jvisualvm 比 jconsole 界面更加好看一点；jprofiler 号称最好用的图形化监控，但收费
- 很显然，使用图形界面很容易观察出 OOM 问题，但若是面试问起，不能这么回答：因为图形界面基于 JMX，而 JMX 会将进程 attach 到 JMX 从而会影响原进程的执行效率，因此生产环境要避免使用
    - 已经上线不能用图形界面，该用什么呢？：命令行工具，arthas 等在线分析工具
    - 图形界面到底用在什么地方？测试！测试的时候进行监控（压测）
- 对于内存问题，一般我们找出是什么类的对象最多，一般就能找到出问题的地方，因此我们可以用 `jmap -histo pid | head -20` 查看最多数量对象的 20 个，这个命令相当于是在线分析的一种，对系统影响相对较小，可以使用
- jmap 也可以手动导出堆转储文件，但生产环境要避免使用：
    - `jmap -dump:format=b,file=out.dat pid`：将指定进程的堆内存信息以二进制形式导出到 out.dat 文件
    - `jhat -J-mx512M out.dat`：导出的文件下载后，可以在其他机器使用 jhat 分析，还支持 OQL 查询，还可以使用 jvisualvm 图形工具分析
    - 虽然离线分析很强大，但实际上 dump 会导致系统卡顿，尤其对于大内存的系统，在 dump 堆转储文件期间会对进程产生很大影响，导致卡顿，因为其需要把整个堆内存信息存储为文件（电商不适合）
    - 启动 java 程序时若设定了参数 `-XX:+HeapDumpOnOutOfMemoryError` 后，会在 OOM 时自动产生堆转储文件，但同样的对于大内存的 dump 可能造成卡顿，因此实际项目也很少这么干
    - 有一个 trick，若 java 进程因为 OOM 挂了，且没有设置 `-XX:+HeapDumpOnOutOfMemoryError` 参数，但进程挂了后别急着重启，仍然可以使用 jmap 把 Heap 情况 dump 出来？视频提到，不知怎么做
    - 若服务器做了高可用，停掉这台服务器对其他服务器不影响，且无其他可用的分析办法时，可尝试考虑使用 dump
    - 还可以根据业务情况具体分析，若机子内存不那么大，可以挑一个半夜没人的时候或者隔离出机子然后进行 dump
    - 使用 MAT/jhat 进行 dump 文件分析：[参考地址](https://www.cnblogs.com/baihuitestsoftware/articles/6406271.html)
- 推荐的分析方法：在线定位，使用 arthas 用于在线排查，但实际上，一般小点的公司用不到
- 实际上，找到有问题的代码，是最难的地方

### arthas 在线排查工具

- 为什么需要在线排查？
    - 在生产环境我们经常会碰到一些不好排查的问题，例如线程安全问题，使用最简单的 threaddump 或者 heapdump 不好查到问题原因
    - 为了排查这些问题，我们会临时添加一些日志，比如在一些关键的函数里打印入参，然后重新打包发布
    - 如果打了日志还是没找到问题，继续加日志，重新打包发布
    - 对于上线流程复杂而且审核比较严的公司，从改代码到上线需要层层的流转，会大大影响问题排查的进度
- arthas：下载和安装请参考官方 github
- 首先，运行前面的例子，为了避免很快 FullGC，堆内存设置稍大点：`java -Xms20M -Xmx20M -XX:+PrintGC Main`
- 启动 arthas：`java -jar arthas-boot.jar`，然后选择正在运行的 java 程序，arthas 会 attach 该程序，在进入 arthas 界面后，则可以直接执行 arthas 相关命令
- help：查看 arthas 常用指令
- jvm：观察 jvm 信息，有点类似 jinfo 指令
- thread：查看线程信息，定位线程问题
- dashboard：观察系统情况
- jad：反编译，对可能的类即使反编译，十分强大
    - 动态代理生成的类定位问题
    - 第三方的类（观察代码）
    - 版本问题：确定自己最新提交的版本是不是被使用
- redefine：热替换，可用于改小 Bug，目前有些限制条件
    - 可以不用停止进程而直接替换源码
    - 只能该方法实现，方法已经运行完成
    - 不能改方法名，不能改属性
- sc：search class
- watch：watch method
- heapdump：`heapdump /root/out-20200907.dat` 导出堆转储文件，相当于 `jmap -dump:...`，但对主进程影响很大，一般不用
- 没有包含的功能：`jmap -histo pid | head -20`，要使用该功能仍需使用 jmap

**热替换测试**

- 有主类 Main 和调用类 TT，main 会每次读取一次输入创建一个 TT 对象并调用一次 m 方法
```java
public class Main {
    public static void main(String[] args) throws IOException {
        while (true) {
            System.in.read();
            new TT().m();
        }
    }
}

public class TT {
    public void m() {
        System.out.println(1);
    }
}
```
- 首先执行 `java Main` 启动主类，其会调用 TT，输入一次打印一个 1
- 我们假设此时 TT 程序出错，我们希望其打印 2
- 我们启动 arthas 并进入对应进程，执行反编译：`jad TT` 可以看到反编译后的代码
- 直接找到 TT 的源码位置，修改 1 为 2，并编译 `javac TT.java`
- 然后进入 arthas，执行 `redefine /root/rr/TT.class` 进行热替换，成功后会提示 `redefine success, size: 1, classes:TT`
- 回到 Main 的主界面，继续输入，验证输出是否变为 2

# 调优案例

- OOM 产生的原因多种多样，有些程序未必产生 OOM，但仍然会不断 FGC，导致 CPU 飙高，但内存回收特别少，例如前面的测试小程序
- 1、硬件升级反而卡顿的问题（见上）
- 2、线程池不当运用产生 OOM 问题（见上）
    - 或者不断往 List 里加对象导致 OOM（实在太 low 了，不太现实）
- 3、smile jira 问题
    - 系统频繁 FullGC，并且找不到原因
    - 解决：最开始一直重启，后来扩内存，并将垃圾回收器换成 G1，成功解决
- 4、tomcat http-header-size 设置过大
    - `server.max-http-header-size=10000000`
    - 导致每个 http 连接来时，占用大量内存，因为头太大了，这样单个 http 连接就占用很多的内存，连接一多，则快速占满内存，导致频繁 Full GC
    - `java -Xms256m -Xmx256m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=E:/logs/tmp.hprof -Xloggc:E:/logs/gc.log BootApplication`
    - 使用 jmeter 模拟并发测试发现会 OOM
    - 通过分析 dump 发现内存占比最高的类型为 byte[] 字节数组，每个字节数组有 10 M，共有 10 个这样的数组
    - 进一步分析，发现有 Http11InputBuffer 引用它，根据猜测是 Http 请求缓存过大了，但显然我们是简单请求，无请求体，因而进一步猜测请求头过大，但我们并没有发送请求头，因此可能是设置问题（其实真正要定位到问题是很难的）
- 5、Lambda 表达式导致方法区溢出问题（MetaSpace/PermGen），或者过多的动态代理字节码技术也可能导致该问题
- 6、直接内存溢出问题：少见
    - 深入理解 Java 虚拟机，第 59 页，使用 Unsafe 分配直接内存
    - 或者使用 NIO 导致的问题
- 7、栈溢出问题：-Xss 设定太小
- 8、比较一下两段程序的异同，分析一下哪个是更优写法：
```java
// 显然第一个写法
public class Main {
    public static void main(String[] args) {
        Object o;
        for (int i = 0; i < 100; i++) {
            o = new Object();
        }
    }
}

public class Main {
    public static void main(String[] args) {
        // 每次循环都产生个 o 指向堆，若方法不结束，不会被回收
        // 经测试，查看字节码，jvm 好像做了优化
        for (int i = 0; i < 100; i++) {
            Object o = new Object();
        }
    }
}
```
- 9、C++ 程序员重写 finalize 引发频繁 GC
    - 小米云，HBase 同步系统，系统通过 nginx 访问超时报警
    - 查询日志，发现频繁 GC
    - 最后排查，发现是 C++ 程序员重写 finalize 引发频繁 GC 问题
    - 为什么 C++ 程序员会重写 finalize：因为 C++ 有析构函数，C++ 程序员对 Java GC 不了解，以为需要自己手动释放内存
    - 为什么重写 finalize 导致频繁 GC：因为重写的 finalize 耗时比较长（200 ms），每个对象被回首时都会回调该方法，调用不过来从而导致 GC 不过来，从而引发频繁 GC
- 10、如果有一个系统，内存消耗一直不超过 10%，但是观察 GC 日志，却发现 FGC 总是频繁产生，会是什么引起的？ 有人显式调用了 System.gc()
- 11、Distuptor 有个可以设置链的长度，如果过大，然后对象大，消费完不主动释放，会导致溢出（需要后续学习）
- 12、用 jvm 都会溢出，mycat 用崩过，1.6.5 某个临时版本解析 sql 子查询算法有问题，9 个 exists 的联合 sql 就导致生成几百万的对象
- 13、new 大量线程，会产生 native thread OOM
    - （太 low 了）：应该用线程池
    - 解决方案：减少堆内存，太 Low 了，预留更多内存产生 native method
    - JVM 内存占物理内存比例 50% - 80%

# JVM 常用参数

## GC 常用参数

- -Xmn -Xms -Xmx -XsS
- -XX:+UseTLAB
- -XX:+PrintTLAB
- -XX:TLABSize
- -XX:+ResizeTLAB
- -XX:+DisableExplictGC：设置该参数后，`System.gc()` 的显式调用不生效
- -XX:+PrintGC
- -XX:+PrintGCDetails
- -XX:+PrintHeapAtGC
- -XX:+PrintGCTimeStamps
- -XX:+PrintGCApplicationConcurrentTime
- -XX:+PrintGCApplicationStoppedTime
- -XX:+PrintReferenceGC
- -verbose:class
- -XX:+PrintVMOptions
- -XX:+PrintFlagsFinal
- -Xloggc:/opt/log/gc.log
- -XX:PerBlockSpin, -XX:CompileThreshold：锁自旋次数、的代代码检测参数、逃逸分析、标量替换等这些不建议设置


## Parallel 常用参数

- -XX:+UseSerialGC
- -XX:SurvivorRatio
- -XX:PreTenureSizeThreshold
- -XX:MaxTenuringThreshold
- -XX:+ParallelGCThreads
- -XX:MaxGCPauseMillis
- -XX:+UseAdaptiveSizePolicy


## CMS 常用参数（较麻烦）


- -XX:+UseConcMarkSweepGC
- -XX:ParallelCMSThreads
- -XX:CMSInitiatingOccupancyFraction
- -XX:+UseCMSCompactAtFullCollection
- -XX:CMSFullGCsBeforeCompaction
- -XX:+CMSClassUnloadingEnabled
- -XX:CMSInitiatingPermOccupancyFraction
- -XX:UseCMSInitiatingOccupancyOnly
- GCTimeRatio


## G1 常用参数

- -XX:+UseG1GC
- -XX:MaxGCPauseMillis
- -XX:GCPauseIntervalMillis
- -XX:+G1HeapRegionSize
- G1 ReservePercent
- G1 NewSizePercent
- G1 MaxNewSizePercent
- GCTimeRatio


## ZGC 常用参数

- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 
- 