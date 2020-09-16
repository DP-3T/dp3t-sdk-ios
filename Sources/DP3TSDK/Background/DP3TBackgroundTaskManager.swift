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

    private let tracer: Tracer

    /// The minimal execution time is needed to prevent any status hickups from iOS
    /// we make sure that every task is running for at least 5 seconds before we complete it
    private let minimalExecutionTime: TimeInterval = 5

    init(handler: DP3TBackgroundHandler?,
         keyProvider: DiagnosisKeysProvider,
         serviceClient: ExposeeServiceClientProtocol,
         tracer: Tracer) {
        self.handler = handler
        self.keyProvider = keyProvider
        self.serviceClient = serviceClient
        self.tracer = tracer

        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Register a background task
    func register() {
        logger.trace()
        guard !Self.didRegisterBackgroundTask else { return }
        Self.didRegisterBackgroundTask = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.exposureNotificationTaskIdentifier, using: .main) { task in
            self.handleExposureNotificationBackgroundTask(task)
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.refreshTaskIdentifier, using: .main) { task in
            // Downcast the parameter to an app refresh task as this identifier is used for a refresh request.
            self.handleRefreshTask(task as! BGAppRefreshTask)
        }
    }

    @objc func appDidEnterBackground(){
        scheduleBackgroundTasks()
    }

    private func handleExposureNotificationBackgroundTask(_ task: BGTask) {
        let startingTime = Date()
        logger.trace()
        scheduleBackgroundTasks()

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

        var taskDidExpire = false
        task.expirationHandler = { [weak self] in
            self?.logger.error("Exposure notification expiration handler called ")
            taskDidExpire = true
            if queue.operationCount != 0 {
                // if operations are running we cancel all of them which then triggers the notify
                self?.logger.log("cancelAllOperations")
                queue.cancelAllOperations()
            } else {
                // if we dont have any operations running we got killed while trying to run for minimalExecutionTime
                // so we just end the task
                self?.logger.log("setTaskCompleted")
                task.setTaskCompleted(success: false)
            }
        }

        completionGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            func complete() {
                self.logger.log("Exposure notification completed")
                let success = !queue.operations.map { $0.isCancelled }.contains(true)
                task.setTaskCompleted(success: success)
            }
            let remainingtime = self.minimalExecutionTime + startingTime.timeIntervalSinceNow
            // if the task did not expire and we did not reach minimalExecutionTime we wait for the remainig time difference
            // if we do expire in the meantime we will complete the task in the expirationHandler
            if !taskDidExpire || remainingtime > 0 {
                self.logger.log("sleeping for %{public}f seconds till ending task", remainingtime)
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingtime) {
                    complete()
                }
            } else {
                self.logger.log("ending task since minimalExecutionTime was reached")
                complete()
            }
        }
    }

    private func handleRefreshTask(_ task: BGTask) {
        let startingTime = Date()

        logger.trace()
        scheduleBackgroundTasks()

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

        let outstandingPublishOperation = OutstandingPublishOperation(keyProvider: keyProvider,
                                                                      serviceClient: serviceClient,
                                                                      runningInBackground: true,
                                                                      tracer: tracer)
        completionGroup.enter()
        outstandingPublishOperation.completionBlock = {
            completionGroup.leave()
        }
        queue.addOperation(outstandingPublishOperation)

        var taskDidExpire = false
        task.expirationHandler = { [weak self] in
            self?.logger.error("Refresh task expiration handler called ")
            taskDidExpire = true
            if queue.operationCount != 0 {
                // if operations are running we cancel all of them which then triggers the notify
                self?.logger.log("cancelAllOperations")
                queue.cancelAllOperations()
            } else {
                // if we dont have any operations running we got killed while trying to run for minimalExecutionTime
                // so we just end the task
                self?.logger.log("setTaskCompleted")
                task.setTaskCompleted(success: false)
            }
        }

        completionGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            func complete() {
                self.logger.log("Refresh task completed")
                let success = !queue.operations.map { $0.isCancelled }.contains(true)
                task.setTaskCompleted(success: success)
            }
            let remainingtime = self.minimalExecutionTime + startingTime.timeIntervalSinceNow
            // if the task did not expire and we did not reach minimalExecutionTime we wait for the remainig time difference
            // if we do expire in the meantime we will complete the task in the expirationHandler
            if !taskDidExpire || remainingtime > 0 {
                self.logger.log("sleeping for %{public}f seconds till ending task", remainingtime)
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingtime) {
                    complete()
                }
            } else {
                self.logger.log("ending task since minimalExecutionTime was reached")
                complete()
            }
        }
    }

    private func scheduleBackgroundTasks() {
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
}
