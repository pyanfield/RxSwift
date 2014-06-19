//
//  Atomic.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// @final 该特性用于修饰一个类或类中的属性，方法，以及下标成员。如果用它修饰一个类，那么这个类则不能被继承。
// 如果用它修饰类中的属性，方法或下标，则表示在子类中，它们不能被重写。
// 一个原子变量。
/// An atomic variable.
@final class Atomic<T> {
	let _lock = SpinLock()
	
	let _box: MutableBox<T>
	
    // 获取和设置变量的值，并已经加锁
	/// Atomically gets or sets the value of the variable.
	var value: T {
		get {
			return _lock.withLock {
				return self._box
			}
		}
	
		set(newValue) {
			_lock.lock()
			_box.value = newValue
			_lock.unlock()
		}
	}
	
    // 初始化变量为给定的初始值
	/// Initializes the variable with the given initial value.
	init(_ value: T) {
		_box = MutableBox(value)
	}
	
    // 替换变量的内容
	/// Atomically replaces the contents of the variable.
	///
	/// Returns the new value.
	func replace(newValue: T) -> T {
		return modify { oldValue in newValue }
	}
	
    // 修改变量的值
	/// Atomically modifies the variable.
	///
	/// Returns the new value.
	func modify(action: T -> T) -> T {
		_lock.lock()
		let newValue = action(_box)
		_box.value = newValue
		_lock.unlock()
		
		return newValue
	}
	
	/// Atomically performs an arbitrary action using the current value of the
	/// variable.
	///
	/// Returns the result of the action.
	func withValue<U>(action: T -> U) -> U {
		_lock.lock()
		let result = action(_box)
		_lock.unlock()
		
		return result
	}

    // 隐式类型转换
	@conversion
	func __conversion() -> T {
		return value
	}
}
