//
//  DelayedExecutor.swift
//  CreditCapacitySwift
//
//  Created by Nikita Pavlov on 29.09.2020.
//  Copyright © 2020 Sberbank. All rights reserved.
//

import Foundation

/**
Класс позволяет отсрочить вызов блока на указанный период времени.
Что позволяет объединить множество частых вызовов в один за указанный период времени.

@discussion Каждый раз, когда происходит отправка блока на исполнение, класс LNSDelayedExecutor
засекает указанный промежуток времени и запоминает переданный блок (класс всегда запоминает только
последний переданный блок). По истечению периода времени последний переданный блок выполняется на заданной очереди.
*/
final class DelayedExecutor {

	private let coalescingPeriod: TimeInterval

	private var actualBlock: (() -> Void)?
	private var resumed: Bool
	private let timer: DispatchSourceTimer
	private let lock = NSLock()

	init(withCoalescing period: TimeInterval, queue: DispatchQueue?) {
		coalescingPeriod = period
		resumed = false
		timer = DispatchSource.makeTimerSource(queue: queue)
		timer.setEventHandler { [weak self] in
			if let block = self?.actualBlock {
				block()
			}
		}
	}

	func dispatchCoalesced(block: @escaping () -> Void) {
		lock.lock()
		actualBlock = block
		let timeWall = DispatchWallTime.now() + coalescingPeriod
		timer.schedule(wallDeadline: timeWall, repeating: .never, leeway: DispatchTimeInterval.milliseconds(10))

		if !resumed {
			timer.resume()
			resumed = true
		}
		lock.unlock()
	}

	deinit {
		lock.lock()
		if !resumed {
			timer.resume()
		}
		timer.cancel()
		lock.unlock()
	}
}
