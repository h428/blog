---
title: 多线程：AQS
categories:
  - 多线程
date: 2020-09-18 23:24:52
---

# AQS 基础

## 数据结构

- AQS 最核心的数据结构为 CLH 队列 + state + currentThread
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

## 继承关系：Sync、FairSync、NonfairSync

- AQS 提供了锁编程的通用接口，其中 `acquire()`, `release()` 为模板方法，AQS 在这两个方法内部会调用 `tryAcquire()`, `tryRelease()`，这两个方法在 AQS 中为空实现，由具体的子类自己实现，以提供不同的加锁、解锁逻辑
- 当我们想要自定义一个锁 MyLock 时，一般会在内部类定义一个继承 AQS 的内部类 Sync，并覆写 `tryAcquire()`, `tryRelease()` 以定义加锁、解锁逻辑，其最简单的框架大致如下：
```java
public class MyLock {
    
    private Sync sync = new Sync();
    
    public void lock() {
        sync.acquire(1);
    }
    
    public void unlock() {
        sync.release(1);
    }
    
    private static class Sync extends AbstractQueuedSynchronizer {

        @Override
        protected boolean tryAcquire(int arg) {
            // setState(getState() + arg);
            return true;
        }

        @Override
        protected boolean tryRelease(int arg) {
            // setState(getState() - arg);
            return true;
        }
    }
}
```
- 比如，ReentrantLock 内部就定义了内部类 Sync 来表示当前锁要如何加锁、解锁
- 但由于 ReentrantLock 同时提供了非公平锁和公平锁，因此 RL 还从 Sync 派生出了 FairSync、NonfairSync，他们对 lock 方法有不同的锁实现；而解锁逻辑一样，故在 Sync 中实现 `tryRelease()` 进行复用
- 除了上述内容，还有一个 `acquireInterruptibly()` 模板方法也会调用 `tryAcquire()`，该模板方法主要用于对 lock 调用 `lockInterruptibly()` 时调用
- 接下来，我们重点研究 FairSync、NonFairSync 的 `lock() `, `unlock()`, `lockInterruptibly()` 调用时涉及的调用过程以及 `tryAcquire()`, `tryRelease()` 具体实现

# ReentrantLock$FairSync

- ReentrantLock$FairSync 为 RL 内部的提供的公平锁，基于 AQS 框架

## lock()

- 主要 debug 下述代码：
```java
public class Main {
    public static void main(String[] args) {
        ReentrantLock lock = new ReentrantLock(true);
        lock.lock();
    }
}
```
- RL$FairSync 的一次 lock() 的调用过程大致如图所示：![lock](https://gitee.com/h428/img/raw/master/note/00000196.jpg)
- 我们先明确，在 RL 中，state = 0 的含义表示锁可用，acquire 就是获取锁并更改 state，最终会通过 `tryAcquire(1)` 完成，其内部会修改 state，重入时还会累加

### 不争用锁的情况

 - 对于单个线程或多个线程交替执行时，RL 不会触发锁的争用，不会涉及到对 CLH 队列的操作，只会在 jdk 级别解决锁同步问题（有点类似 synchronized 的偏向锁，即不争用锁不会自旋，就好像没加锁一样）
 - 若多个线程争用锁时，就需要用到 CLH 队列的相关操作，CLH 队列后续再探讨

#### AQS.acquire()

- 前面的 `lock.lock()` 和 `sync.lock()` 就是逐步往里面调用，没啥好说
- `sync.lock()` 是 Sync 定义的抽象方法，FariSync 的具体实现为：
```java
final void lock() {
    acquire(1); // 调用 AQS 的模板方法以获得锁
}
```
- 真正的 AQS 框架就从这行 `acquire(1)` 开始，我们接下来重点看 `AQS.acquire()` 的源码，这是 AQS 提供的一个模板方法，也是 AQS 锁框架的核心之一，执行步骤请参考注释
```java
// 模板方法，最终会调用子类的 tryAcquire(arg) 实现尝试获取锁，
// 若获取锁失败时为当前线程创建节点并加入 CLH 队列（返回值控制是否阻塞），等待 unpark 唤醒重新竞争锁
public final void acquire(int arg) {
    // AQS 的 tryAcquire 为空实现，运行时会去调用不同的实现
    // 例如在本例中会去调用 FairSync 的 tryAcquire 实现
    if (!tryAcquire(arg) && 
            acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```

#### FairSync.tryAcquire()

- 可以看到，`AQS.acquire()` 会调用 `FairSync.tryAcquire()` 获得锁，因此我们继续看 `FairSync.tryAcquire()`
```java
/**
 * 尝试获取锁，只有队列中没有更早的等待节点或者是重入才会授权成功
 * Fair version of tryAcquire.  Don't grant access unless
 * recursive call or no waiters or is first.
 */
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) { // state = 0，表示锁可用
        if (!hasQueuedPredecessors() && // 由于公平锁，需要先判断是否已经有节点在排队，没有才可以上锁
                compareAndSetState(0, acquires)) { // CAS 操作获取锁
            setExclusiveOwnerThread(current); // 若成功则设置当前持有锁的线程
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
- 无锁争用的情况，`tryAcquire()` 必定返回 true，从而结束 `acquire()`，从而结束 `sync.lock()`，从而结束 `lock.lock()`，本次加锁逻辑结束，继续运行线程的后续代码
- 其中 `hasQueuedPredecessors()` 涉及到多种不同情况下的判断，我们在讨论了各种加锁流程后再统一讨论其判断情况，现在只知道该方法能判断是否已经有更早的节点在排队，有则返回 true，没有则返回 false，没有更早的节点在排队，说明可以拿到锁

### 争用锁的情况

- 若涉及到锁的争用，根据前面 `tryAcquire()` 的实现，由于只能有一个线程获得锁资源，因此其会返回 false，从而导致模板方法中继续执行 `acquireQueued(addWaiter(Node.EXCLUSIVE), arg)` 以及满足阻塞条件后的 `selfInterrupt()`
- `addWaiter(Node.EXCLUSIVE)`：主要为当前线程创建一个 CLH Node 同时入队，然后返回该 Node
- `acquireQueued(node, arg)`：对这个新入队的 node，若前面没有排队的节点，还会尝试自旋 2 次获取锁（拿到锁的那个可能结束了），两次自旋获取锁失败后会进入阻塞状态；若前面有排队的节点会直接进入阻塞状态
- `selfInterrupt()`：非打断锁的情况，用于恢复中断标记，由于 `parkAndCheckInterrupt()` 内部使用 `Thread.interrupted()` 消耗了中断标记，因此此处要恢复中断标记，无实际作用

#### AQS.addWaiter

- 为了方便，再次粘贴模板方法
```java
// 模板方法，最终会调用子类的 tryAcquire(arg) 实现尝试获取锁，
// 若获取锁失败时为当前线程创建节点并加入 CLH 队列（返回值控制是否阻塞），等待 unpark 唤醒重新竞争锁
public final void acquire(int arg) {
    // AQS 的 tryAcquire 为空实现，运行时会去调用不同的实现
    // 例如在本例中会去调用 FairSync 的 tryAcquire 实现
    if (!tryAcquire(arg) && 
            acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}
```
- 由于争用锁失败，`tryAcquire()` 返回 false，模板方法的 if 条件继续执行，因此就先调用了 `addWaiter(Node.EXCLUSIVE)`
- `addWaiter(Node.EXCLUSIVE)`：创建一个排他性的 CLH Node，同时入队，实现细节如下：
```java
/**
 * Creates and enqueues node for current thread and given mode.
 *
 * @param mode Node.EXCLUSIVE for exclusive, Node.SHARED for shared
 * @return the new node
 */
private Node addWaiter(Node mode) {
    // 创建指定 mode 的 CLH Node
    Node node = new Node(Thread.currentThread(), mode);
    // Try the fast path of enq; backup to full enq on failure
    Node pred = tail;
    if (pred != null) {
        // 若 tail 不为空，表示队列已经初始化过，则一次 CAS 入队
        node.prev = pred;
        if (compareAndSetTail(pred, node)) {
            pred.next = node;
            return node;
        }
    }
    // 若队列还没初始化过，或者一次 CAS 入队失败，会导致执行 enq(node)，其内部带有自旋
    enq(node);
    return node;
}
```
- 若是队列已经初始化过，一次 CAS 操作入队；若是队列还未初始化过或者一次 CAS 操作入队失败，则触发 `enq(node)` 的调用：
```java
/**
 * CAS + 自旋以将 node 插入到队列，若是队列没初始化会先执行初始化
 * Inserts node into queue, initializing if necessary. See picture above.
 * @param node the node to insert
 * @return node's predecessor
 */
private Node enq(final Node node) {
    for (;;) {
        Node t = tail;
        if (t == null) { // Must initialize
            // tail 为 null 表示队列还未初始化，执行初始化
            // 设置一个空头结点，并让 head, tail 都指向它
            // 这个空的头结点含义为：当前已经拿到锁的那个 thread(注意不是当前 thread)，其 thread 域为 null
            // 空节点的含义需要结合 acquireQueued 中的 setHead 一起分析
            if (compareAndSetHead(new Node()))
                tail = head;
        } else {
            // 若已经初始化过，则一直自旋直至 CAS 入队成功
            node.prev = t;
            if (compareAndSetTail(t, node)) {
                t.next = node;
                return t;
            }
        }
    }
}
```
- 自此，`addWaiter()` 成功创建一个 CLH Node 并加入到队尾（若没初始化会先初始化队列），同时返回这个新创建的节点

#### AQS.acquireQueued

- `addWaiter()` 实际上已经完成了创建 CLH 节点并入队的操作，但由于入队后，可能此时拿到锁的那个线程执行了 unlock 释放了锁，因此我们希望当前线程入队后并不是马上进入阻塞状态，而是尝试自旋一定次数获取锁，若还是没拿到锁才进入阻塞状态
- 对这个新创建的节点，`acquire()` 方法会调用 `acquireQueued(node, arg)` 尝试获取锁或者直接阻塞
    - 如果这个 node 之前没有别的 node 排队，则会自旋两次 `tryAcquire()` 尝试获取锁，若都失败，则通过 `LockSupport.park()` 进入阻塞状态
    - 如果这个 node 之前有别的 node 排队，由于是公平锁不可抢占，则直接通过 `LockSupport.park()` 进入阻塞状态
- 实现细节如下，详细参考源码注释：
```java
/**
 * Acquires in exclusive uninterruptible mode for thread already in
 * queue. Used by condition wait methods as well as acquire.
 *
 * @param node the node
 * @param arg the acquire argument
 * @return {@code true} if interrupted while waiting
 */
final boolean acquireQueued(final Node node, int arg) {
    boolean failed = true;
    try {
        boolean interrupted = false;
        for (;;) { // 自旋
            // 拿到当前 node 的前驱
            final Node p = node.predecessor();
            // 若前驱是 head，表示当前 node 是第一个排队的节点，尝试获取锁
            if (p == head && tryAcquire(arg)) {
                // CLH 队列的 head 从语义上可以理解为当前成功拿到锁的那个线程，其后继为第一个排队的线程，但这个 head 节点的 thread 是为 null 的，它只是从语义上指代
                // 因此若队列中有一个排队的节点，但整个队列应该有两个节点，head 和 head 的后继，分别表示拿到锁的线程、第一个排队的线程
                // 若此时正好 head 指代的那个线程释放了锁，则此时会获取锁成功
                setHead(node); // 移除队列的原有 head 并设置新 head
                p.next = null; // help GC，完全将旧的 head 从队列中移除
                failed = false;
                return interrupted;
            }
            if (shouldParkAfterFailedAcquire(p, node) && // 判断本次自旋后是否需要阻塞
                    parkAndCheckInterrupt()) // 若是需要阻塞则执行阻塞
                // parkAndCheckInterrupt() 内部会消耗一次中断标记，此处要通过 interrupted 返回表示中断过
                // 如果本来没中断过，不会执行这一行，那本来就 false
                // 返回的中断标记会在模板方法 acquire() 中识别到，然后执行恢复中断标记，实际上几乎没什么用
                // 若是打断式的 lockInterruptibly()，这会在此处直接抛出中断异常
                interrupted = true; 
        }
    } finally { // 这段可能是其他并发性问题？有待研究
        if (failed)
            cancelAcquire(node);
    }
}
```
- 其中，`setHead(node)` 配合 `p.next = null` 用于移除旧 head 同时设置新 head 为 node：
```java
/**
 * Sets head of queue to be node, thus dequeuing. Called only by
 * acquire methods.  Also nulls out unused fields for sake of GC
 * and to suppress unnecessary signals and traversals.
 *
 * @param node the node
 */
private void setHead(Node node) {
    head = node;
    node.thread = null;
    node.prev = null;
}
```
- `shouldParkAfterFailedAcquire(p, node)` 通过判断与设置前驱节点的 waitStatus 来决定当前节点线程是否休眠，细节如下：
```java
/**
 * Checks and updates status for a node that failed to acquire.
 * Returns true if thread should block. This is the main signal
 * control in all acquire loops.  Requires that pred == node.prev.
 *
 * @param pred node's predecessor holding status
 * @param node the node
 * @return {@code true} if thread should block
 */
private static boolean shouldParkAfterFailedAcquire(Node pred, Node node) {
    // 通过 addWaiter 创建的 Node，waitStatus 默认值为 0
    // 这个默认值 0 很重要，可以配合 acquireQueued 来使得每个第一排队的 node 有两次自旋 tryAcquire() 的机会

    // 拿到前驱的 waitStatus，对于没有更改过的，默认值为 0
    // 不出意外，队尾元素的 waitStatus 默认值必定为 0
    int ws = pred.waitStatus;
    if (ws == Node.SIGNAL) 
        // 第二次 CAS 后会进入该分支，返回 true 最终导致阻塞
        // 且 Node.SIGNAL 表示 pred 节点释放锁后需要手动 unpark 后继节点
        // 由于有这个机制，你才能放心地返回 true 并执行 park
        /*
         * This node has already set status asking a release
         * to signal it, so it can safely park.
         */
        return true;
    if (ws > 0) {
        /*
         * Predecessor was cancelled. Skip over predecessors and
         * indicate retry.
         */
        do {
            node.prev = pred = pred.prev;
        } while (pred.waitStatus > 0);
        pred.next = node;
    } else {
        /*
         * waitStatus must be 0 or PROPAGATE.  Indicate that we
         * need a signal, but don't park yet.  Caller will need to
         * retry to make sure it cannot acquire before parking.
         */
        // 设置 pred 节点的 waitStatus 为 Node.SIGNAL
        // Node.SIGNAL 表示 pred 节点在释放锁后需要手动 unpark 后继节点
        compareAndSetWaitStatus(pred, ws, Node.SIGNAL);
    }
    return false;
}
```
- 对于所有 node，`shouldParkAfterFailedAcquire(p, node)` 至少都会自旋两次，唯一的区别就是，如果此时 node 是第一个排队的节点，这两次自旋都会尝试 `tryAcquire()`，如果拿到了就直接出队了；如果不是第一个排队的节点，由于是公平锁则必须阻塞，而为了能被正常 unpark，因此第一次会把 node 的前驱 pred 的 waitStatus 设置为 Node.SIGNAL，表示 pred 释放锁后需要手动 unpark 后继节点；第二次真正发现 waitStatus 为 Node.SIGNAL 因此可以放心 unpark
- waitStatus 默认值为 0 的设计，通过配合 acquireQueued 使得每个 node 的至少都有两次自旋的机会获得锁，两次后没有获得锁就会进入阻塞状态
- 若判断可以阻塞，则会调用 `parkAndCheckInterrupt()` 执行阻塞：
```java
/**
 * Convenience method to park and then check if interrupted
 *
 * @return {@code true} if interrupted
 */
private final boolean parkAndCheckInterrupt() {
    // 可以看到，是通过 LockSupport.park() 执行的阻塞操作，因此需要前驱节点释放锁时手动 unpark
    LockSupport.park(this);
    // 该句判断阻塞期间是否被人打断过，同时会消耗中断标记
    // 这也是为什么公平锁的 acquireQueued() 在检测到 true 后也要返回 true
    // 返回 true 后，让 acquire() 也检测到 true，然后执行 selfInterrupt() 恢复中断标记
    // 至于为什么这么设计主要是为了复用当前的 parkAndCheckInterrupt() 方法可以复用
    // 因为如果是 lockInterruptibly() 锁方法，则会在 acquireQueued() 中检测到中断标记后直接抛出中断异常
    return Thread.interrupted(); 
}
```
- 当前 node 被 park 后，则必须等待前驱节点 unpark 当前 node，且由于是公平锁实现，其他新加入的节点不会抢占，因此在队首中的 node 被唤醒后必定 `tryAcquire()` 成功 

#### selfInterrupt()

- 该句的作用在 `parkAndCheckInterrupt()` 中大致解释过了，若是 node 在阻塞的过程中被 interrupt 过，则在线程恢复时使用 `Thread.interrupted()` 可以判断出来
- 但 `Thread.interrupted()` 这行代码会消耗中断标记，导致用户无法判断到中断标记，因此 AQS 在检测到 `parkAndCheckInterrupt()` 返回 true 后，会让 `acquireQueued()` 也返回 true，从而让模板方法 `acquire()` 执行 `selfInterrupt()` 恢复中断标记
```java
/**
 * Convenience method to interrupt current thread.
 */
static void selfInterrupt() {
    Thread.currentThread().interrupt();
}
```
- 至于为什么这么设计，前面也提到过，是为了复用 `parkAndCheckInterrupt()` 方法，对于 `lockInterruptibly()` 版本的方法，检测到 true 后会直接抛出中断异常

### hasQueuedPredecessors()

- 在讨论了所有的加锁流程后，我们再来看一看 `hasQueuedPredecessors()` 方法的具体实现，该方法也是 AQS 的一大难点：
```java
/**
 * Queries whether any threads have been waiting to acquire longer
 * than the current thread.
 *
 * <p>An invocation of this method is equivalent to (but may be
 * more efficient than):
 *  <pre> {@code
 * getFirstQueuedThread() != Thread.currentThread() &&
 * hasQueuedThreads()}</pre>
 *
 * <p>Note that because cancellations due to interrupts and
 * timeouts may occur at any time, a {@code true} return does not
 * guarantee that some other thread will acquire before the current
 * thread.  Likewise, it is possible for another thread to win a
 * race to enqueue after this method has returned {@code false},
 * due to the queue being empty.
 *
 * <p>This method is designed to be used by a fair synchronizer to
 * avoid <a href="AbstractQueuedSynchronizer#barging">barging</a>.
 * Such a synchronizer's {@link #tryAcquire} method should return
 * {@code false}, and its {@link #tryAcquireShared} method should
 * return a negative value, if this method returns {@code true}
 * (unless this is a reentrant acquire).  For example, the {@code
 * tryAcquire} method for a fair, reentrant, exclusive mode
 * synchronizer might look like this:
 *
 *  <pre> {@code
 * protected boolean tryAcquire(int arg) {
 *   if (isHeldExclusively()) {
 *     // A reentrant acquire; increment hold count
 *     return true;
 *   } else if (hasQueuedPredecessors()) {
 *     return false;
 *   } else {
 *     // try to acquire normally
 *   }
 * }}</pre>
 *
 * @return {@code true} if there is a queued thread preceding the
 *         current thread, and {@code false} if the current thread
 *         is at the head of the queue or the queue is empty
 * @since 1.7
 */
public final boolean hasQueuedPredecessors() {
    // The correctness of this depends on head being initialized
    // before tail and on head.next being accurate if the current
    // thread is first in queue.
    Node t = tail; // Read fields in reverse initialization order
    Node h = head;
    Node s;
    return h != t && // 该行表示队列还没初始化或者只有一个空的头结点，没有排队节点，会直接返回 false
            ((s = h.next) == null || s.thread != Thread.currentThread()); // 该行表示队列中有排队节点，但当前节点就是第一个正在排队的节点，同样返回 false，表示当前线程可以拿锁，该种情况主要配合 acquireQueue() 使用
}
```
- 若队列还未初始化的情况，head 和 tail 都为 null，此时 h != t 结果为 false，整个方法返回 false，即没有更早的排队节点，配合 ! 操作表示当前线程可以获取锁
- 若队列只有一个空的头结点，head 和 tail 指向同一个地址，此时 h != t 结果为 false，结果和上述相同
- 若队列中有第一个排队节点 s，且 s 代表的线程恰好就是当前线程，`s.thread != Thread.currentThread()` 也会返回 false，说明当前线程的优先级最高，可以拿到锁，结果同上
- 第三种情况主要和 `acquireQueued()` 方法配合，在 `acquireQueued()` 中，node 在入队后，会有两次自旋获取锁的机会，若此时前面的节点恰好释放了锁，c = 0，就会进入到该方法判定，此时 h != t 判定失效，因为队列中有排队元素，这时通过第三种情况就表示这个第一个排队的线程能够返回 false，从而继续执行获取锁的 CAS 操作

## unlock()

- 和加锁逻辑相比，解锁逻辑比较简单，而且非公平锁和公平锁的解锁逻辑一样，即他们复用 `tryRelease()` 方法
- `unlock()` 的调用流程大致如图所示：![unlock](https://gitee.com/h428/img/raw/master/note/00000197.jpg)
- 解锁就没有所谓的争用情况，对于排它锁，只有当前拿到锁的线程可以解锁，当然由于是可重入锁，支持多次加锁解锁操作
- 首先，同样是 AQS 提供了模板方法 `release()`，其会调用不同锁的子类实现
- 对于公平锁和非公平锁的解锁逻辑相同，因此直接在 Sync 中实现了 `tryRelease()` 方法并让公平锁和非公平锁复用

### release()

- 同样的，前面的解锁逻辑也是逐步往里调用
- 首先，`lock.unlock()` 中调用 `sync.release()`
```java
/**
 * Attempts to release this lock.
 *
 * <p>If the current thread is the holder of this lock then the hold
 * count is decremented.  If the hold count is now zero then the lock
 * is released.  If the current thread is not the holder of this
 * lock then {@link IllegalMonitorStateException} is thrown.
 *
 * @throws IllegalMonitorStateException if the current thread does not
 *         hold this lock
 */
public void unlock() {
    sync.release(1); // release() 为 AQS 提供的模板方法，用于解锁
}
```
- 由于 Sync 继承自 AQS，因此实际上上述代码调用的是 AQS 的模板方法，该模板方法的实现细节如下：
```java
/**
 * Releases in exclusive mode.  Implemented by unblocking one or
 * more threads if {@link #tryRelease} returns true.
 * This method can be used to implement method {@link Lock#unlock}.
 *
 * @param arg the release argument.  This value is conveyed to
 *        {@link #tryRelease} but is otherwise uninterpreted and
 *        can represent anything you like.
 * @return the value returned from {@link #tryRelease}
 */
public final boolean release(int arg) {
    if (tryRelease(arg)) { // 调用子类的解锁逻辑尝试解锁
        Node h = head;
        // 这里的 waitStatus 要和前面的 acquireQueued 结合起来看
        // 前面我们讲到每个 CLH Node 入队后有两次自旋获取锁的机会，并且第一次自旋会将 prev 的 waitStatus 设置为 Node.SIGNAL(-1)，只有检测到 prev 为 -1 才会返回 true 让当前 node 的线程 park
        // 结合此处就可以明白，当前节点的 waitStatus 不为 0，则表示需要唤醒后继节点
        // 若前面入队时，第一次自旋若不把 prev 节点的 waitStatus 设置为 SIGNAL 则此处将不会唤醒后继节点（waitStatus 默认为 0）
        if (h != null && h.waitStatus != 0)
            unparkSuccessor(h); // 解锁成功后唤醒 h 的后继节点，注意传进去的是 head
        return true;
    }
    return false;
}
```

### tryRelease()

- 从模板方法中可以看到，真正的解锁逻辑有不同子类的 tryRelease() 实现
- 下面我们看 ReentrantLock$Sync 的解锁逻辑：
```java
protected final boolean tryRelease(int releases) {
    int c = getState() - releases; // 获取 state 并解锁
    if (Thread.currentThread() != getExclusiveOwnerThread())
        // 只有持有锁的线程才能解锁，否则异常
        throw new IllegalMonitorStateException(); 
    boolean free = false; // 标记解锁后锁是否释放
    if (c == 0) { 
        // 若本次解锁后，state 变为 0，表示可以释放锁
        // 注意因为是可重入锁，可能会有多次重叠加锁和解锁的过程
        free = true; // 可以释放锁
        setExclusiveOwnerThread(null); // 占有锁的线程置位空
    }
    setState(c); // 更新 state
    // 返回锁是否释放，注意可重入锁，只有 state 变为 0 表示锁释放了
    // 正数说明虽然本次成功降低了 state 的值，但当前线程仍然持有锁
    return free; 
}
```

### unparkSuccessor

```java
/**
 * Wakes up node's successor, if one exists.
 *
 * @param node the node，注意在 RL 中解锁时传进来的是 head
 */
private void unparkSuccessor(Node node) {
    /*
     * If status is negative (i.e., possibly needing signal) try
     * to clear in anticipation of signalling.  It is OK if this
     * fails or if status is changed by waiting thread.
     */
    // 注意解锁时传进来的 node 是 head，我们要唤醒 head 的后继节点
    int ws = node.waitStatus; // 获取 head 的 waitStatus
    if (ws < 0) 
        // 唤醒之前需要同时需求清除 head 节点的 waitStatus 在唤醒 head.next
        compareAndSetWaitStatus(node, ws, 0);

    /*
     * Thread to unpark is held in successor, which is normally
     * just the next node.  But if cancelled or apparently null,
     * traverse backwards from tail to find the actual
     * non-cancelled successor.
     */
    Node s = node.next; // s 为待唤醒的节点
    if (s == null || s.waitStatus > 0) {
        s = null;
        for (Node t = tail; t != null && t != node; t = t.prev)
            if (t.waitStatus <= 0)
                s = t;
    }
    if (s != null)
        // 唤醒第一个正在排队的节点
        LockSupport.unpark(s.thread);
}
```


## lockInterruptibly()



# ReentrantLock$NonfairSync

