---
categories:
  - Java
---


# HashMap 实现原理

- HashMap 的本质是一个散列，也叫哈希表，不过其是根据 key 的 hashCode 值计算散列地址
- HashMap 内部有一个 Entry 数组，当添加元素时，根据 key 的 hashCode 计算对应的散列 idx 值，存储在对应的元素位置
- 若发生碰撞，jdk 1.7 和 1.8 采用的碰撞处理方法不同
- 在 1.8 之前，发生碰撞时采用链地址法，即 Entry 本身也可作为链表节点，若发生了碰撞则添加到该链表上
- jdk 1.8 之后，对碰撞处理做了优化，当链表的长度大于 8 时，会将链表优化为红黑树，以减少查询时间
- 此外，HashMap 内部还有一个平衡因子用于控制扩容，当放入的元素数量大于 len * loadFactor 时，会触发 resize 操作，将内部数组扩容为原来两倍，并对所有元素再散列，由于扩容操作比较耗时，因此创建 HashMap 时最好提供合适的初始大小，默认初始大小为 16
- HashMap 线程不安全，若要多线程下使用哈希表，则可考虑使用 HashTable 或者 ConcurrentHashMap

# ConcurrentHashMap 实现原理

- [ConcurrentHashMap 实现原理](https://crossoverjie.top/2018/07/23/java-senior/ConcurrentHashMap/)
- HashMap 线程不安全，而 HashTable 是线程安全，但是它使用了 synchronized 进行方法同步，插入、读取数据都使用了synchronized，当插入数据的时候不能进行读取（相当于把整个Hashtable 都锁住了，全表锁），当多线程并发的情况下，都要竞争同一把锁，导致效率极其低下
- 而在 JDK1.5 后为了改进 Hashtable 的痛点，ConcurrentHashMap 应运而生

**1.7 及之前**

- 在 1.7 及之前，ConcurrentHashMap 使用 Segment 数组来解决锁住整个 table 数组的问题
- 首先引入长度为 16 的 Segment 数组，其中 ReentrantLock 继承于 ReentrantLock，每个 Segment 内部有自己的 volatile table，确保数据多线程下的可见性，同时内部的 HashEntry 以及 value 都是 volatile 的
- 当执行 put 时，先计算得 hash 然后定位到 segment，然后对该 segment 执行并发 put 操作，主要涉及 CAS 即自旋
- put 操作：
    - 计算 hash 并定位到 HashEntry，注意该操会自旋获取对该 segment 的锁直至获取成功（多次自旋失败还会变为同步锁）
    - 遍历该 HashEntry 并和 key 比对，若 key 相等表示原来以存在该 key，则设置 value，或者直至 null
    - 若为 null 则准备在链表或者红黑树上加入新元素
    - put 成功后 cnt++，并判断是否扩容，若达到扩容阈值则会进行扩容并再散列
- 注意 put 时，该 segment 的 table 触发扩容时，则会对该 segment 上锁，此时不影响其他 segment 的并发
- 但若 get/put 的元素恰好处于同一个 segment 则仍然触发阻塞

**1.8**

- 1.8 之后，取消了 Segment，采用了 CAS + synchronize 来对每个 bucket 单独加锁，只要不发生 hash 冲突，就不会并发安全性问题
- 首先，在 1.8 中将 HashEntry 改为 Node，


# CAS 与 volatile




# 序列化方式及对比
