//
//  Scheduler.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a serial queue of work items.
@class_protocol
protocol Scheduler {
    // 将 work item 入队，什么时候来实行该工作，主要看其具体的实施情况。
    // 返回一个 diposable 的可选类型，可以用来在其开始前进行一些取消工作。
	/// Enqueues the given work item.
	///
	/// When the work is executed depends on the specific implementation.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func schedule(work: () -> ()) -> Disposable?
}

// ImmediateScheduler 同步分执行所有的工作
/// A scheduler that performs all work synchronously.
@final class ImmediateScheduler: Scheduler {
	func schedule(work: () -> ()) -> Disposable? {
		work()
		return nil
	}
}

// QueueSchedular 后面是由串行的 GCD queue 来支持的。
/// A scheduler backed by a serial GCD queue.
@final class QueueScheduler: Scheduler {
	let _queue = dispatch_queue_create("com.github.RxSwift.QueueScheduler", DISPATCH_QUEUE_SERIAL)
    
    // 从该处到下面 class var mainThreadScheduler 处，实现了一个 mainThreadScheduler 的单例
	struct _Shared {
		static let mainThreadScheduler = QueueScheduler(dispatch_get_main_queue())
	}

    // 使用关键字static来定义值类型的类型属性，关键字class来为类（class）定义类型属性。
    // 运行在主线程的一种特定的 QueueScheduler
	/// A specific kind of QueueScheduler that will run its work items on the
	/// main thread.
	class var mainThreadScheduler: QueueScheduler {
		get {
			return _Shared.mainThreadScheduler
		}
	}
    
    // 以给定的 queue 来初始化 scheduler ,即使你传入的 queue 是并行的，在 QueueScheduler 里面也是以串行的方式工作。
	/// Initializes a scheduler that will target the given queue with its work.
	///
	/// Even if the queue is concurrent, all work items enqueued with the
	/// QueueScheduler will be serial with respect to each other.
	init(_ queue: dispatch_queue_t) {
		dispatch_set_target_queue(_queue, queue)
	}
	
    // 根据传入的优先级，初始化一个工作在 global queue 上的 scheduler 实例.
	/// Initializes a scheduler that will target the global queue with the given
	/// priority.
	convenience init(_ priority: CLong) {
		self.init(dispatch_get_global_queue(priority, 0))
	}
	
    // 初始化一个默认的优先级的 global queue
	/// Initializes a scheduler that will target the default priority global
	/// queue.
	convenience init() {
		self.init(DISPATCH_QUEUE_PRIORITY_DEFAULT)
	}
	
	func schedule(work: () -> ()) -> Disposable? {
		let d = SimpleDisposable()
	
		dispatch_async(_queue, {
			if d.disposed {
				return
			}
			
			work()
		})
		
		return d
	}
}
