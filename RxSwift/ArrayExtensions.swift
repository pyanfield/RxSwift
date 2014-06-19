//
//  ArrayExtensions.swift
//  RxSwift
//
//  Created by Justin Spahr-Summers on 2014-06-10.
//  Copyright (c) 2014 GitHub. All rights reserved.
//

import Foundation

// 将给定的对象从数组中移除
/// Removes all occurrences of the given object from the array.
func removeObjectIdenticalTo<T: AnyObject>(value: T, #fromArray: T[]) -> T[] {
	return fromArray.filter({
		$0 === value
	})
}