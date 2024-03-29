/*
 * Copyright (c) 2020 Ubique Innovation AG <https://www.ubique.ch>
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * SPDX-License-Identifier: MPL-2.0
 */

import BackgroundTasks
import Foundation
import UIKit.UIApplication
import ExposureNotification

@available(iOS 12.5, *)
class DP3TBackgroundTaskManager {
    static let exposureNotificationTaskIdentifier: String = "org.dpppt.exposure-notification"
    static let refreshTaskIdentifier: String = "org.dpppt.refresh"

    /// Background task registration should only happen once per run
    /// If the SDK gets destroyed and initialized again this would cause a crash
    private static var didRegisterBackgroundTask: Bool = false

    weak var handler: DP3TBackgroundHandler?

    private let logger = Logger(DP3TBackgroundTaskManager.self, category: "backgroundTaskManager")

    private weak var keyProvider: DiagnosisKeysProvider!

    private let serviceClient: ExposeeServiceClientProtocol

    private weak var tracer: Tracer!
    
    var shouldReschedule: Bool = true {
        didSet {
            if shouldReschedule == false {
                if #available(iOS 13.0, *) {
                    cancelScheduledTask()
                }
            }
        }
    }

    init(handler: DP3TBackgroundHandler?,
         keyProvider: DiagnosisKeysProvider,
         serviceClient: ExposeeServiceClientProtocol,
         tracer: Tracer,
         manager: ENManager) {
        self.handler = handler
        self.keyProvider = keyProvider
        self.serviceClient = serviceClient
        self.tracer = tracer

        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)

        // this is only needed for iOS 12.5
        if #available(iOS 13.0, *) {}
        else {
            manager.setLaunchActivityHandler { [weak self] (activityFlags) in
                if activityFlags.contains(.periodicRun) {
                    self?.handleiOS12BackgroundLaunch()
                }
            }
        }

    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Register a background task
    func register() {
        logger.trace()
        guard !Self.didRegisterBackgroundTask else { return }
        Self.didRegisterBackgroundTask = true

        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.exposureNotificationTaskIdentifier, using: .main) { task in
                self.handleExposureNotificationBackgroundTask(task)
            }
            BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.refreshTaskIdentifier, using: .main) { task in
                // Downcast the parameter to an app refresh task as this identifier is used for a refresh request.
                self.handleRefreshTask(task as! BGAppRefreshTask)
            }
        }
    }

    @objc func appDidEnterBackground(){
        if #available(iOS 13.0, *) {
            scheduleBackgroundTasks()
        }
    }

    private func handleiOS12BackgroundLaunch() {
        logger.trace()
        
        if !shouldReschedule {
            return
        }
        
        let queue = OperationQueue()

        if let handler = handler {
            let handlerOperation = HandlerOperation(handler: handler)

            handlerOperation.completionBlock = { [weak self] in
                self?.logger.log("Exposure notification handlerOperation finished")
            }

            queue.addOperation(handlerOperation)
        }

        let syncOperation = SyncOperation()
        syncOperation.completionBlock = { [weak self] in
            self?.logger.log("SyncOperation finished")
        }
        queue.addOperation(syncOperation)
    }

    @available(iOS 13.0, *)
    private func handleExposureNotificationBackgroundTask(_ task: BGTask) {
        logger.trace()
        scheduleBackgroundTasks()
        
        if !shouldReschedule {
            return
        }

        let queue = OperationQueue()

        let completionGroup = DispatchGroup()

        if let handler = handler {
            let handlerOperation = HandlerOperation(handler: handler)

            completionGroup.enter()
            handlerOperation.completionBlock = { [weak self] in
                self?.logger.log("Exposure notification handlerOperation finished")
                completionGroup.leave()
            }

            queue.addOperation(handlerOperation)
        }

        let syncOperation = SyncOperation()

        completionGroup.enter()
        syncOperation.completionBlock = { [weak self] in
            self?.logger.log("SyncOperation finished")
            completionGroup.leave()
        }

        queue.addOperation(syncOperation)

        task.expirationHandler = { [weak self] in
            self?.logger.error("Exposure notification task expiration handler called")
            queue.cancelAllOperations()
        }

        completionGroup.notify(queue: .main) { [weak self] in
            self?.logger.log("Exposure notification task completed")

            let success = !queue.operations.map { $0.isCancelled }.contains(true)
            task.setTaskCompleted(success: success)
        }
    }

    @available(iOS 13.0, *)
    private func handleRefreshTask(_ task: BGTask) {
        logger.trace()
        scheduleBackgroundTasks()
        
        if !shouldReschedule {
            return
        }

        let queue = OperationQueue()
        let completionGroup = DispatchGroup()

        if let handler = handler {
            let handlerOperation = HandlerOperation(handler: handler)

            completionGroup.enter()
            handlerOperation.completionBlock = { [weak self] in
                self?.logger.log("Refresh handlerOperation finished")
                completionGroup.leave()
            }

            queue.addOperation(handlerOperation)
        }

        task.expirationHandler = { [weak self] in
            self?.logger.error("Refresh task expiration handler called")
            queue.cancelAllOperations()
        }

        completionGroup.notify(queue: .main) { [weak self] in
            self?.logger.log("Refresh task completed")

            let success = !queue.operations.map { $0.isCancelled }.contains(true)
            task.setTaskCompleted(success: success)
        }
    }

    @available(iOS 13.0, *)
    private func scheduleBackgroundTasks() {
        guard self.shouldReschedule else { return }
        
        logger.trace()

        // Schedule next app refresh task 12h in the future
        let refreshRequest = BGAppRefreshTaskRequest(identifier: DP3TBackgroundTaskManager.refreshTaskIdentifier)
        refreshRequest.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(refreshRequest)
        } catch {
            logger.error("Scheduling refresh task failed error: %{public}@", error.localizedDescription)
        }

        // Only schedule exposure notification task after EN is authorized
        guard tracer.isAuthorized else {
            logger.log("Skipping scheduling of exposure notification task because ENManager is not authorized")
            return
        }
        let taskRequest = BGProcessingTaskRequest(identifier: DP3TBackgroundTaskManager.exposureNotificationTaskIdentifier)
        taskRequest.requiresNetworkConnectivity = true
        do {
            handler?.didScheduleBackgrounTask()
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch {
            logger.error("Exposure notification task schedule failed error: %{public}@", error.localizedDescription)
        }
    }
    
    @available(iOS 13.0, *)
    func cancelScheduledTask() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
    }
}
