/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation
import UIKit.UIApplication
import BackgroundTasks

fileprivate class SyncOperation: Operation {
    override func main() {
        try! DP3TTracing.sync { result in
            switch result {
            case .failure(_):
                self.cancel()
            default:
                break
            }
        }
    }
}

class DP3TBackgroundTaskManager {
    static let taskIdentifier: String = "org.dpppt.synctask"
    
    static let syncInterval: TimeInterval = 15 * .minute

    /// A logger for debugging
    #if CALIBRATION
        public weak var logger: LoggingDelegate?
    #endif

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }

    func register() {
        if #available(iOS 13.0, *) {
            #if CALIBRATION
            logger?.log(type: .sdk ,"DP3TBackgroundTaskManager.register")
            #endif
            BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.taskIdentifier, using: .global()) { (task) in
                self.handleBackgroundTask(task)
            }
        } else {
            UIApplication.shared.setMinimumBackgroundFetchInterval(DP3TBackgroundTaskManager.syncInterval)
        }
    }

    func performFetch(with completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.addOperation(SyncOperation())
        let lastOperation = queue.operations.last
        lastOperation?.completionBlock = {
            let success = !(lastOperation?.isCancelled ?? false)
            completionHandler(success ? .newData : .failed)
        }
    }

    @available(iOS 13.0, *)
    private func handleBackgroundTask(_ task: BGTask){
        #if CALIBRATION
        logger?.log(type: .sdk ,"DP3TBackgroundTaskManager.handleBackgroundTask")
        #endif

        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1

        queue.addOperation(SyncOperation())
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        let lastOperation = queue.operations.last
        lastOperation?.completionBlock = {
            task.setTaskCompleted(success: !(lastOperation?.isCancelled ?? false))
        }

        scheduleBackgroundTask()
    }

    private func scheduleBackgroundTask(){
        if #available(iOS 13.0, *) {
            let syncTask = BGAppRefreshTaskRequest(identifier: DP3TBackgroundTaskManager.taskIdentifier)
            syncTask.earliestBeginDate = Date(timeIntervalSinceNow: DP3TBackgroundTaskManager.syncInterval)
            #if CALIBRATION
            logger?.log(type: .sdk ,"DP3TBackgroundTaskManager.scheduleBackgroundTask earliestBeginDate: \(syncTask.earliestBeginDate!)")
            #endif
            do {
                try BGTaskScheduler.shared.submit(syncTask)
            } catch {
                #if CALIBRATION
                logger?.log(type: .sdk ,"Unable to submit task: \(error.localizedDescription)")
                #endif
            }
        } else {
            // Fallback on earlier versions
        }
    }

    @objc func didEnterBackground(){
        scheduleBackgroundTask()
    }

}
