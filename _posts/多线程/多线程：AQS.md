---
title: 多线程：AQS
categories:
  - 多线程
date: 2020-09-18 23:24:52
---

# AQS 基本数据结构

- AQS 最核心的内容为 CLH 队列 + state + currentThread
- CLH 队列体现为 head, tail 两个变量，是一个双向链表，主要存储没有竞争到锁资源的线程，用于等待 unpark
- 在 AQS 类中，核心变量主要如下：
```java
private transient volatile Node head; // 队首
private transient volatile Node tail; // 队尾
private volatile int state; // 锁状态，不同的实现有不用的含义，在 RL 中，0 表示锁可用，正数则表示以上锁，+1 表示可重入
private transient Thread exclusiveOwnerThread; // 当前持有排它锁的线程
```
- [AQS](https://tech.meituan.com/2019/12/05/aqs-theory-and-apply.html)
- [AQS](https://www.cnblogs.com/waterystone/p/4920797.html)
- 我们主要通过 ReentrantLock 来学习 AQS 的源码

# ReentrantLock

## Sync、FairSync、NonfairSync

- AQS 提供了通用的锁的模板方法和接口，我们自定义的锁一般会在内部类实现一个继承 AQS 的 Sync，以实现你当前要写的锁的锁方式
- 比如，ReentrantLock 内部定义了内部类 Sync 来表示当前锁要如何加锁，但由于 ReentrantLock 同时提供了非公平锁和公平锁，因此 Sync 派生出了 FairSync、NonfairSync，他们对 lock 方法有不同的锁实现，默认为非公平锁
- 因此 Sync 实现了公共的部分，而 FairSync、NonfairSync 各自实现了如何 lock, unlock
- 接下来，我们重点研究 FairSync、NonFairSync 的 lock() 方法和 tryAcquire() 方法


## FairSync 不争用锁的情况

- 主要 debug 下述代码：
```java
public class Main {
    public static void main(String[] args) {
        ReentrantLock lock = new ReentrantLock(true);
        lock.lock();
    }
}
```
- 采用 FairSync 的 RL 的一次 lock() 的调用过程大致如图所示：![ThreadLocal](https://gitee.com/h428/img/raw/master/note/00000196.jpg)
- 我们先明确，在 RL 中，state = 0 的含义表示锁可用，acquire 就是获取锁并更改 state，最终会通过 `tryAcquire(1)` 完成，其内部会修改 state，重入时还会累加
- 前面的 lock 调用没啥好说，我们接下来重点看 `AQS.acquire()` 的源码，这是 AQS 提供的一个模板方法，也是 AQS 锁框架的核心之一，执行步骤请参考注释
```java
// 模板方法，最终会调用 tryAcquire 竞争锁，
// 或者锁竞争失败时为当前线程创建节点并加入 CLH 队列（返回值控制是否阻塞），等待 unpark 唤醒重新竞争锁
public final void acquire(int arg) {
    // AQS 的 tryAcquire 为空实现，运行时会去调用不同的实现
    // 例如在本例中会去调用 FairSync 的 tryAcquire 实现
    if (!tryAcquire(arg) && 
            acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```
- 可以看到，`AQS.acquire()` 会调用 `FairSync.tryAcquire()` 获得锁，因此我们继续看`FairSync.tryAcquire()`
```java
/**
 * Fair version of tryAcquire.  Don't grant access unless
 * recursive call or no waiters or is first.
 */
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) { // state = 0，表示锁可用
        if (!hasQueuedPredecessors() && // 由于公平锁，需要先判断队列是否为空才可以上锁
                compareAndSetState(0, acquires)) { // CAS 操作上锁
            setExclusiveOwnerThread(current); // 设置当前持有锁的线程
            return true; // 获取锁成功
        }
    }
    else if (current == getExclusiveOwnerThread()) { // 表示重入
        int nextc = c + acquires; // 重入会更新 state
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true; // 获取锁成功
    }
    return false; // 获取锁失败
}
```
 - 对于单个线程或多个线程交替执行时，RL 不会触发锁的争用，不会涉及到对 CLH 队列的操作，只会在 jdk 级别解决锁同步问题（有点类似偏向锁，不争用锁不会自旋）
 - 若多个线程争用锁时，就需要用到 CLH 队列的相关操作，CLH 队列后续再探讨


## FairSync 争用锁的情况