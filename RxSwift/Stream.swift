//
//  Stream.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-03.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// 使用 operator 来声明自定义运算符， infix 表示该运算符为中置运算符，还有 prefix 表示前置运算符，postfix 为后置
// 定义一个新的中置运算符，为左结合运算符，优先级为默认的 100
operator infix |> { associativity left }

// 通过 @infix func 来实现这个自定义的运算符，该运算符的功能是合并 stream-of-streams 到一个单独的 stream
// 注意这个不是 Stream 类的方法，因为这个只对 stream-of-streams 有效
/// Combines a stream-of-streams into a single stream, using the given policy
/// function.
///
/// This allows code like:
///
///		let sss: Stream<Stream<Stream<T>>>
///		let s = concat(flatten(s))
///
/// to instead be written like:
///
///		let s = s |> flatten |> concat
///
///	This isn't a method within the `Stream` class because it's only valid on
///	streams-of-streams.
@infix func |><T>(stream: Stream<Stream<T>>, f: Stream<Stream<T>> -> Stream<T>) -> Stream<T> {
	return f(stream)
}

// 一元 Event<T> 的数据流
/// A monadic stream of `Event<T>`.
class Stream<T> {
    // class func 创建类方法
    
    // 生成一个空的数据流
	/// Creates an empty stream.
	class func empty() -> Stream<T> {
		return Stream()
	}
	
    // 创建含有单独值的数据流
	/// Creates a stream with a single value.
	class func single(T) -> Stream<T> {
		return Stream()
	}

    // 创建一个含有给定错误信息的数据流
	/// Creates a stream that will generate the given error.
	class func error(error: NSError) -> Stream<T> {
		return Stream()
	}

    // 创建含有给定序列值的数据流
	/// Creates a stream from the given sequence of values.
	@final class func fromSequence(seq: SequenceOf<T>) -> Stream<T> {
		var s = empty()

		for elem in seq {
			s = s.concat(single(elem))
		}

		return s
	}
    
    // 扫描 stream ,积累一个状态，然后映射每一个值到一个新的数据流，然后平展所有的数据流，形成一个数据流
	/// Scans over the stream, accumulating a state and mapping each value to
	/// a new stream, then flattens all the resulting streams into one.
	///
	/// This is rarely useful directly—it's just a primitive from which many
	/// convenient stream operators can be derived.
	func flattenScan<S, U>(initial: S, _ f: (S, T) -> (S?, Stream<U>)) -> Stream<U> {
		return .empty()
	}

    // 将给定数据流中的值添加到接收者的末尾
	/// Concatenates the values in the given stream onto the end of the
	/// receiver.
	func concat(stream: Stream<T>) -> Stream<T> {
		return .empty()
	}

    // 压缩给定数据流的值到接收者中。
    // 合并每个数据流的第一个值，然后第二个，直到其中一个数据流的最后一个值为止。
	/// Zips the values of the given stream up with those of the receiver.
	///
	/// The first value of each stream will be combined, then the second value,
	/// and so forth, until at least one of the streams is exhausted.
	func zipWith<U>(stream: Stream<U>) -> Stream<(T, U)> {
		return .empty()
	}
    
    // 将每个接收者的事件，转化成能够直接操作的事件值。
	/// Converts each of the receiver's events (including those outside of the
	/// monad) into an Event value that can be manipulated directly.
	func materialize() -> Stream<Event<T>> {
		return .empty()
	}

	/// Lifts the given function over the values in the stream.
	@final func map<U>(f: T -> U) -> Stream<U> {
		return flattenScan(0) { (_, x) in (0, .single(f(x))) }
	}

    // 过滤数据流中的值，保留和给定条件相符的值
	/// Keeps only the values in the stream that match the given predicate.
	@final func filter(pred: T -> Bool) -> Stream<T> {
		return map { x in pred(x) ? .single(x) : .empty() }
			|> flatten
	}

    // 从数据流中取出给定个数的值，如果要取出的个数 `count` 大于数据流的长度，则返回整个的数据流
	/// Takes only the first `count` values from the stream.
	///
	/// If `count` is longer than the length of the stream, the entire stream is
	/// returned.
	@final func take(count: Int) -> Stream<T> {
		if (count == 0) {
			return .empty()
		}

		return flattenScan(0) { (n, x) in
			if n < count {
				return (n + 1, .single(x))
			} else {
				return (nil, .empty())
			}
		}
	}

    // 取出符合条件的数据，直到第一个不符合条件的数据出现，将所有的符合条件的数据值放到一条数据流中处理
	/// Takes values while the given predicate remains true.
	///
	///
	/// Returns a stream that consists of all values up to (but not including)
	/// the value where the predicate was first false.
	@final func takeWhile(pred: T -> Bool) -> Stream<T> {
		return flattenScan(0) { (_, x) in
			if pred(x) {
				return (0, .single(x))
			} else {
				return (nil, .empty())
			}
		}
	}

    // 取出最后的 `count` 个数据值到数据流中，如果 `count` 大于数据流包含的数据长度，则返回全部数据
	/// Takes only the last `count` values from the stream.
	///
	/// If `count` is longer than the length of the stream, the entire stream is
	/// returned.
	@final func takeLast(count: Int) -> Stream<T> {
		if (count == 0) {
			return .empty()
		}

		return materialize().flattenScan([]) { (vals: T[], event) in
			switch event {
			case let .Next(value):
				var newVals = vals
				newVals.append(value)

				while newVals.count > count {
					newVals.removeAtIndex(0)
				}

				return (newVals, .empty())

			case let .Error(error):
				return (nil, .error(error))

			case let .Completed:
				return (nil, .fromSequence(SequenceOf(vals)))
			}
		}
	}

    // 跳过前 `count` 个数据，组成新的数据流返回，如果 `count` 大于数据流中的数据长度，则返回空数据流
	/// Skips the first `count` values in the stream.
	///
	/// If `count` is longer than the length of the stream, an empty stream is
	/// returned.
	@final func skip(count: Int) -> Stream<T> {
		return flattenScan(0) { (n, x) in
			if n < count {
				return (n + 1, .empty())
			} else {
				return (count, .single(x))
			}
		}
	}

	/// Skips values while the given predicate remains true.
	///
	/// Returns a stream that consists of all values after (and including) the
	/// value where the predicate was first true.
	@final func skipWhile(pred: T -> Bool) -> Stream<T> {
		return flattenScan(true) { (skipping, x) in
			if skipping && pred(x) {
				return (true, .empty())
			} else {
				return (false, .single(x))
			}
		}
	}
    
    // 当产生错误的时候，转换到 produced stream
	/// Switch to the produced stream when an error occurs.
	@final func catch(f: NSError -> Stream<T>) -> Stream<T> {
		return materialize().flattenScan(0) { (_, event) in
			switch event {
			case let .Next(value):
				return (0, .single(value))

			case let .Error(error):
				return (nil, f(error))

			case let .Completed:
				return (nil, .empty())
			}
		}
	}
}

/// Flattens a stream-of-streams into a single stream of values.
///
/// The exact manner in which flattening occurs is determined by the
/// stream's implementation of `flattenScan()`.
func flatten<T>(stream: Stream<Stream<T>>) -> Stream<T> {
	return stream.flattenScan(0) { (_, s) in (0, s) }
}

/// Converts a stream of Event values back into a stream of real events.
func dematerialize<T>(stream: Stream<Event<T>>) -> Stream<T> {
	return stream.map { event in
		switch event {
		case let .Next(value):
			return .single(value)

		case let .Error(error):
			return .error(error)

		case let .Completed:
			return .empty()
		}
	} |> flatten
}
