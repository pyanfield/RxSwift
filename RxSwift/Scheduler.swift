//
//  Scheduler.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

/// Represents a serial queue of work items.
protocol Scheduler {
    // 将 actoin 入队到 scheduler，什么时候执行改工作，主要依赖于什么时候使用 scheduler。
    // 返回一个 diposable 的可选类型，可以用来在其开始前进行一些取消工作。
	/// Enqueues an action on the scheduler.
	///
	/// When the work is executed depends on the scheduler in use.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func schedule(action: () -> ()) -> Disposable?

	// 安排一个 action 在给定的日期之后执行
	/// Schedules an action for execution at or after the given date.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable?
}

/// A particular kind of scheduler that supports repeating actions.
protocol RepeatableScheduler: Scheduler {
	/// Schedules a recurring action at the given interval, beginning at the
	/// given start time.
	///
	/// Optionally returns a disposable that can be used to cancel the work
	/// before it begins.
	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable?
}

let currentSchedulerKey = "RxSwiftCurrentSchedulerKey"

/// Returns the scheduler upon which the calling code is executing, if any.
var currentScheduler: Scheduler? {
	get {
		return NSThread.currentThread().threadDictionary[currentSchedulerKey] as? Box<Scheduler>
	}
}

/// Performs an action while setting `currentScheduler` to the given
/// scheduler instance.
func _asCurrentScheduler<T>(scheduler: Scheduler, action: () -> T) -> T {
	let previousScheduler = currentScheduler

	NSThread.currentThread().threadDictionary[currentSchedulerKey] = Box(scheduler)
	let result = action()
	NSThread.currentThread().threadDictionary[currentSchedulerKey] = Box(previousScheduler)

	return result
}

// ImmediateScheduler 同步分执行所有的工作
/// A scheduler that performs all work synchronously.
struct ImmediateScheduler: Scheduler {
	func schedule(action: () -> ()) -> Disposable? {
		action()
		return nil
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		NSThread.sleepUntilDate(date)
		return schedule(action)
	}
}


/// A scheduler that performs all work on the main thread.
struct MainScheduler: RepeatableScheduler {
	let _innerScheduler = QueueScheduler(dispatch_get_main_queue())

	func schedule(action: () -> ()) -> Disposable? {
		return _innerScheduler.schedule(action)
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		return _innerScheduler.scheduleAfter(date, action: action)
	}

	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		return _innerScheduler.scheduleAfter(date, repeatingEvery: repeatingEvery, withLeeway: withLeeway, action: action)
	}
}

// QueueSchedular 后面是由串行的 GCD queue 来支持的。
/// A scheduler backed by a serial GCD queue.
struct QueueScheduler: Scheduler {
	let _queue = dispatch_queue_create("com.github.RxSwift.QueueScheduler", DISPATCH_QUEUE_SERIAL)

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
	init(_ priority: CLong) {
		self.init(dispatch_get_global_queue(priority, 0))
	}
	
    // 初始化一个默认的优先级的 global queue
	/// Initializes a scheduler that will target the default priority global
	/// queue.
	init() {
		self.init(DISPATCH_QUEUE_PRIORITY_DEFAULT)
	}
	
	func schedule(action: () -> ()) -> Disposable? {
		let d = SimpleDisposable()
	
		dispatch_async(_queue, {
			if d.disposed {
				return
			}
			
			_asCurrentScheduler(self, action)
		})
		
		return d
	}

	func _wallTimeWithDate(date: NSDate) -> dispatch_time_t {
		var seconds = 0.0
		let frac = modf(date.timeIntervalSince1970, &seconds)
		
		let nsec: Double = frac * Double(NSEC_PER_SEC)
		var walltime = timespec(tv_sec: CLong(seconds), tv_nsec: CLong(nsec))
		
		return dispatch_walltime(&walltime, 0)
	}

	func scheduleAfter(date: NSDate, action: () -> ()) -> Disposable? {
		let d = SimpleDisposable()

		dispatch_after(_wallTimeWithDate(date), _queue, {
			if d.disposed {
				return
			}

			_asCurrentScheduler(self, action)
		})

		return d
	}

	func scheduleAfter(date: NSDate, repeatingEvery: NSTimeInterval, withLeeway leeway: NSTimeInterval, action: () -> ()) -> Disposable? {
		let nsecInterval = repeatingEvery * Double(NSEC_PER_SEC)
		let nsecLeeway = leeway * Double(NSEC_PER_SEC)
		
		let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue)
		dispatch_source_set_timer(timer, _wallTimeWithDate(date), UInt64(nsecInterval), UInt64(nsecLeeway))
		dispatch_source_set_event_handler(timer, action)
		dispatch_resume(timer)

		return ActionDisposable {
			dispatch_source_cancel(timer)
		}
	}
}
