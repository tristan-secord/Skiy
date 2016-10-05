//
//  Copyright (c) 2016 Daniel Rhodes <rhodes.daniel@gmail.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
//  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
//  USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

public enum RetryStrategy {
  
  case ExponentialBackoff(maxRetries: Int, maxIntervalTime: NSTimeInterval)
  case LogarithmicBackoff(maxRetries: Int, maxIntervalTime: NSTimeInterval)
  case Linear(maxRetries: Int, intervalTime: Int)
  case None
  
  func calculateInterval(retries : Int) -> NSTimeInterval  {
    switch self {
    case .LogarithmicBackoff(let maxRetries, let maxIntervalTime):
      if (retries > maxRetries) { return 0.0 }
      let interval = 5 * log(Double(retries))
      return NSTimeInterval(clamp(interval, lower: 0.1, upper: Double(maxIntervalTime)))
    case .ExponentialBackoff(let maxRetries, let maxIntervalTime):
      if (retries > maxRetries) { return 0.0 }
      let interval = exp2(Double(retries))
      return NSTimeInterval(clamp(Double(interval), lower: 0.1, upper: Double(maxIntervalTime)))
    case .Linear(let maxRetries, let intervalTime):
      if (retries > maxRetries) { return 0.0 }
      return NSTimeInterval(intervalTime)
    default:
      return 0.0
    }
  }
}

internal class RetryHandler : NSObject {
    var retries : Int = 0
    var strategy: RetryStrategy
    var callback: ((Void) -> (Void))?
    var timer: NSTimer?
    
    internal required init(strategy : RetryStrategy) {
        self.strategy = strategy
    }
    
    func retry(callback: ((Void) -> (Void)))  {
        self.retries += 1
        
        // Save callback
        self.callback = callback
      
        if let aTimer = self.timer { aTimer.invalidate() }
      
        // Calculate interval based on strategy
        let interval: NSTimeInterval = self.strategy.calculateInterval(self.retries)

        if (interval > 0.0) {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(interval,
                target: self,
                selector: #selector(self.fire(_:)),
                userInfo: nil,
                repeats: false)
        }
    }
    
    internal func fire(timer : NSTimer) {
      
        if let callback = self.callback {
            callback()
        }
    }
    
    deinit {
        // Clean Up
        if let timer = self.timer {
            timer.invalidate()
        }
    }
}