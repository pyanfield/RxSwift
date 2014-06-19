//
//  Event.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-02.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// 代表了一个 stream 事件，比如遵从的语法是 `Next * (Error | Completed)?`
/// Represents a stream event.
///
/// Streams must conform to the grammar:
/// `Next* (Error | Completed)?`
enum Event<T> {
    // stream 提供的值通过 Next 事件来传递
	/// A value provided by the stream.
	case Next(Box<T>)
    
    // 出现了错误，stream 发送 Error 事件
	/// The stream terminated because of an error.
	case Error(NSError)

    // stream 成功结束
	/// The stream successfully terminated.
	case Completed
	
    // 说明该事件是否已经终止
	/// Whether this event indicates stream termination (from success or
	/// failure).
	var isTerminating: Bool {
		get {
			switch self {
			case let .Next:
				return false
			
			default:
				return true
			}
		}
	}
	
	/// Lifts the given function over the event's value.
	func map<U>(f: T -> U) -> Event<U> {
		switch self {
		case let .Next(box):
			return .Next(Box(f(box)))
			
		case let .Error(error):
			return .Error(error)
			
		case let .Completed:
			return .Completed
		}
	}
}
