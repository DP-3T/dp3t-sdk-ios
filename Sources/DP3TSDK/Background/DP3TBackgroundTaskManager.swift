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

    /// Background task registration should only happen once per run
    /// If the SDK gets destroyed and initialized again this would cause a crash
    private static var didRegisterBackgroundTask: Bool = false

    weak var handler: DP3TBackgroundHandler?

    private let logger = Logger(DP3TBackgroundTaskManager.self, category: "backgroundTaskManager")

    private weak var keyProvider: DiagnosisKeysProvider!

    private let serviceClient: ExposeeServiceClientProtocol

    private let tracer: Tracer

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
    }

    @objc func appDidEnterBackground(){
        scheduleBackgroundTask()
    }

    private func handleExposureNotificationBackgroundTask(_ task: BGTask) {
        logger.trace()

        let queue = OperationQueue()

        let completionGroup = DispatchGroup()

        if let handler = handler {
            let handlerOperation = HandlerOperation(handler: handler)

            completionGroup.enter()
            handlerOperation.completionBlock = { [weak self] in
                self?.logger.log("handlerOperation finished")
                completionGroup.leave()
            }

            queue.addOperation(handlerOperation)
        }

        let syncOperation = SyncOperation()

        completionGroup.enter()
        syncOperation.completionBlock = { [weak self] in
            self?.logger.log("syncOperation finished")
            completionGroup.leave()
        }

        queue.addOperation(syncOperation)

        task.expirationHandler = { [weak self] in
            self?.logger.error("DP3TBackgroundTaskManager expiration handler called")
            queue.cancelAllOperations()
        }

        completionGroup.notify(queue: .main) { [weak self] in
            self?.logger.log("DP3TBackgroundTaskManager task completed")

            let success = !queue.operations.map { $0.isCancelled }.contains(true)
            task.setTaskCompleted(success: success)
        }

        scheduleBackgroundTask()
    }

    private func scheduleBackgroundTask() {
        logger.trace()
        guard tracer.isAuthorized else {
            logger.log("skipping schedule because ENManager is not authorized")
            return
        }
        let taskRequest = BGProcessingTaskRequest(identifier: DP3TBackgroundTaskManager.exposureNotificationTaskIdentifier)
        taskRequest.requiresNetworkConnectivity = true
        do {
            handler?.didScheduleBackgrounTask()
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch {
            logger.error("background task schedule failed error: %{public}@", error.localizedDescription)
        }
    }
}
