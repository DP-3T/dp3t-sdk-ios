/*
* Created by Ubique Innovation AG
* https://www.ubique.ch
* Copyright (c) 2020. All rights reserved.
*/

import Foundation
import UIKit.UIApplication
import BackgroundTasks

@available(iOS 13.0, *)
class DP3TBackgroundTaskManager {
    static let taskIdentifier: String = "org.dpppt.synctask"
    
    static let syncInterval: TimeInterval = 15 * .minute

    /// A logger for debugging
    #if CALIBRATION
        public weak var logger: LoggingDelegate?
    #endif

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func register() {
        #if CALIBRATION
        logger?.log(type: .sdk ,"DP3TBackgroundTaskManager.register")
        #endif
        BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.taskIdentifier, using: .global()) { (task) in
            self.handleBackgroundTask(task)
        }
    }

    private func handleBackgroundTask(_ task: BGTask){
        #if CALIBRATION
        logger?.log(type: .sdk ,"DP3TBackgroundTaskManager.handleBackgroundTask")
        #endif
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            self.scheduleBackgroundTask()
        }

        do {
            try DP3TTracing.sync { (_) in
                task.setTaskCompleted(success: true)
                self.scheduleBackgroundTask()
            }
        } catch {
            task.setTaskCompleted(success: false)
            self.scheduleBackgroundTask()
        }

    }

    private func scheduleBackgroundTask(){
        #if CALIBRATION
        logger?.log(type: .sdk ,"DP3TBackgroundTaskManager.scheduleBackgroundTask")
        #endif
        let syncTask = BGAppRefreshTaskRequest(identifier: DP3TBackgroundTaskManager.taskIdentifier)
        syncTask.earliestBeginDate = Date(timeIntervalSinceNow: DP3TBackgroundTaskManager.syncInterval)
        do {
            try BGTaskScheduler.shared.submit(syncTask)
        } catch {
            #if CALIBRATION
            logger?.log(type: .sdk ,"Unable to submit task: \(error.localizedDescription)")
            #endif
        }
    }

    @objc func didEnterBackground(){
        scheduleBackgroundTask()
    }

}
