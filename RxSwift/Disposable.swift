//
//  Disposable.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// class_protocol 该特性用于修饰一个协议表明该协议只能被类类型采用
// 代表一个对象能够被废弃，通常是用于释放一些资源或者取消一些工作。
// 比如在事件中可以用来表示“分离”，在 Timer 中表示中止，异步的时候表示取消。
/// Represents an object that can be “disposed,” usually associated with freeing
/// resources or canceling work.
@class_protocol
protocol Disposable {
    // 表示是否已经被废弃了。
	/// Whether this disposable has been disposed already.
	var disposed: Bool { get }

	func dispose()
}

// 一个简单地 disposable 处理，只是实现了简单地 'disposed' 变量的值的翻转，没有进行其他工作
/// A disposable that only flips `disposed` upon disposal, and performs no other
/// work.
class SimpleDisposable: Disposable {
	var _disposed = Atomic(false)

	var disposed: Bool {
		get {
			return _disposed
		}
	}
	
	func dispose() {
		_disposed.value = true
	}
}

// 基于 action 的 disposal
/// A disposable that will run an action upon disposal.
class ActionDisposable: Disposable {
	var _action: Atomic<(() -> ())?>

	var disposed: Bool {
		get {
			return _action == nil
		}
	}

	/// Initializes the disposable to run the given action upon disposal.
	init(action: () -> ()) {
		_action = Atomic(action)
	}

	func dispose() {
		let action = _action.swap(nil)
		action?()
	}
}

/// A disposable that will dispose of any number of other disposables.
class CompositeDisposable: Disposable {
	var _disposables: Atomic<Disposable[]?>
	
	var disposed: Bool {
		get {
			return _disposables.value == nil
		}
	}

	/// Initializes a CompositeDisposable containing the given list of
	/// disposables.
	init(_ disposables: Disposable[]) {
		_disposables = Atomic(disposables)
	}
    
    // convenience 提供了一个无参数的便利的构造器
	/// Initializes an empty CompositeDisposable.
	convenience init() {
		self.init([])
	}
	
	func dispose() {
		if let ds = _disposables.swap(nil) {
			for d in ds {
				d.dispose()
			}
		}
	}
	
    // 将给定的 disposable 添加到列表中
	/// Adds the given disposable to the list.
	func addDisposable(d: Disposable?) {
		if d == nil {
			return
		}
	
		let shouldDispose: Bool = _disposables.withValue {
			if var ds = $0 {
				ds.append(d!)
				return false
			} else {
				return true
			}
		}
		
		if shouldDispose {
			d!.dispose()
		}
	}
	
    // 将给定的 disposable 从列表中移除
	/// Removes the given disposable from the list.
	func removeDisposable(d: Disposable?) {
		if d == nil {
			return
		}
	
		_disposables.modify {
			if let ds = $0 {
				return removeObjectIdenticalTo(d!, fromArray: ds)
			} else {
				return nil
			}
		}
	}
}

// 基于 "取消初始化" 的 disposal,将自动的去执行另一个 disposable 的 dispose 方法
/// A disposable that, upon deinitialization, will automatically dispose of
/// another disposable.
class ScopedDisposable: Disposable {
	/// The disposable which will be disposed when the ScopedDisposable
	/// deinitializes.
	let innerDisposable: Disposable
	
	var disposed: Bool {
		get {
			return innerDisposable.disposed
		}
	}
	
	/// Initializes the receiver to dispose of the argument upon
	/// deinitialization.
	init(_ disposable: Disposable) {
		innerDisposable = disposable
	}
	
    // 析构函数
	deinit {
		dispose()
	}
	
	func dispose() {
		innerDisposable.dispose()
	}
}

/// A disposable that will optionally dispose of another disposable.
class SerialDisposable: Disposable {
	struct _State {
		var innerDisposable: Disposable? = nil
		var disposed = false
	}

	var _state = Atomic(_State())

	var disposed: Bool {
		get {
			return _state.value.disposed
		}
	}

	/// The inner disposable to dispose of.
	///
	/// Whenever this is set to a new disposable, the old one is automatically
	/// disposed.
	var innerDisposable: Disposable? {
		get {
			return _state.value.innerDisposable
		}

		set(d) {
			_state.modify {
				var s = $0
				if s.innerDisposable === d {
					return s
				}

				s.innerDisposable?.dispose()
				s.innerDisposable = d
				if s.disposed {
					d?.dispose()
				}

				return s
			}
		}
	}

	/// Initializes the receiver to dispose of the argument when the
	/// SerialDisposable is disposed.
	convenience init(_ disposable: Disposable) {
		self.init()
		innerDisposable = disposable
	}

	func dispose() {
		innerDisposable = nil
	}
}
