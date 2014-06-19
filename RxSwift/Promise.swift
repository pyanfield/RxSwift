//
//  Promise.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// 延迟工作生成一个 type T 的值
/// Represents deferred work to generate a value of type T.
@final class Promise<T> {
	let _queue = dispatch_queue_create("com.github.RxSwift.Promise", DISPATCH_QUEUE_CONCURRENT)
	let _suspended = Atomic(true)

	var _result: Box<T>? = nil

    // 在 targetQueue 线程上，通过调用执行给定的函数 work() 生成一个值，从而完成 promise 的初始化
	/// Initializes a promise that will generate a value using the given
	/// function, executed upon the given queue.
	init(_ work: () -> T, targetQueue: dispatch_queue_t = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
		dispatch_set_target_queue(self._queue, targetQueue)
        
        //暂缓执行该线程
		dispatch_suspend(self._queue)
		
		dispatch_barrier_async(self._queue) {
			self._result = Box(work())
		}
	}
	
    // 如果当前的 promise 还没有开始，那么现在开始这个 promise.
	/// Starts resolving the promise, if it hasn't been started already.
	func start() {
		self._suspended.modify { b in
			if b {
                // 恢复执行被暂缓的线程 （见初始化中将线程 suspend）
				dispatch_resume(self._queue)
			}
			
			return false
		}
	}
	
    // 如果有需要，开始着手解决该 promise，然后在结果上进行阻塞
	/// Starts resolving the promise (if necessary), then blocks on the result.
	func result() -> T {
		self.start()
		
        // 等待该工作结束
		// Wait for the work to finish.
		dispatch_sync(self._queue) {}
		
		return self._result!
	}
	
    // 当 promise 完成之后，将给定的 action 入队执行，这里不会开始一个 promise
    // 返回一个 disposable 的目的是为了能够在该 action 运行之前将其取消掉
	/// Enqueues the given action to be performed when the promise finishes
	/// resolving.
	///
	/// This does not start the promise.
	///
	/// Returns a disposable that can be used to cancel the action before it
	/// runs.
	func whenFinished(action: T -> ()) -> Disposable {
		let disposable = SimpleDisposable()
		
		dispatch_async(self._queue) {
			if disposable.disposed {
				return
			}
		
			action(self._result!)
		}
		
		return disposable
	}

	func then<U>(action: T -> Promise<U>) -> Promise<U> {
		return Promise<U> {
			action(self.result()).result()
		}
	}
}
