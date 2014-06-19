//
//  SpinLock.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// spin lock 旋转锁，一种为了防止多处理器并发引入的一种锁。
// 在这里初始化了一个 OS_SPINLOCK_INIT, 在此 spinlick 使用了 memory barrier 来同步访问被 lock 保护的共享内存。
// OS_SPINLOCK_INIT 的默认值为 OSSpinLock， 如果未被锁定值为 0，被锁之后值为非零值。
/// An abstraction over spin locks.
@final class SpinLock {
	var _spinlock = OS_SPINLOCK_INIT
	
    // spinlock 加锁
	/// Locks the spin lock.
	func lock() {
		withUnsafePointer(&_spinlock, OSSpinLockLock)
	}
	
    // spinlock 解锁
	/// Unlocks the spin lock.
	func unlock() {
		withUnsafePointer(&_spinlock, OSSpinLockUnlock)
	}
	
    // 为 action 请求一个 spinlock ,然后再解锁
	/// Acquires the spin lock, performs the given action, then releases the
	/// lock.
	func withLock<T>(action: () -> T) -> T {
		withUnsafePointer(&_spinlock, OSSpinLockLock)
		let result = action()
		withUnsafePointer(&_spinlock, OSSpinLockUnlock)
		
		return result
	}
	
    // 尝试请求一个 spin lock 给 action,如果请求加锁成功，那么执行这个 action, 否则立即放弃执行该 action
	/// Tries to acquire the spin lock, performing the given action if it's
	/// available, or else aborting immediately without running the action.
	func tryLock<T>(action: () -> T) -> T? {
		if !withUnsafePointer(&_spinlock, OSSpinLockTry) {
			return nil
		}
		
		let result = action()
		withUnsafePointer(&_spinlock, OSSpinLockUnlock)
		
		return result
	}
}
