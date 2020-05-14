/*
 * Created by Ubique Innovation AG
 * https://www.ubique.ch
 * Copyright (c) 2020. All rights reserved.
 */

import BackgroundTasks
import Foundation
import UIKit.UIApplication

@available(iOS 13.5, *)
private class SyncOperation: Operation {
    override func main() {
        DP3TTracing.sync { result in
            switch result {
            case .failure:
                self.cancel()
            default:
                break
            }
        }
    }
}

@available(iOS 13.5, *)
private class OutstandingPublish: Operation {
    override func main() {
        let operations = Default.shared.outstandingPublishes
        for op in operations where op.dayToPublish < DayDate().dayMin{
            //TODO handle outstandingPublish
            Default.shared.outstandingPublishes.remove(op)
        }
    }
}

@available(iOS 13.5, *)
private class HandlerOperation: Operation {
    weak var handler: DP3TBackgroundHandler?

    init(handler: DP3TBackgroundHandler) {
        self.handler = handler
    }

    override func main() {
        handler?.performBackgroundTasks(completionHandler: { success in
            if !success {
                self.cancel()
            }
        })
    }
}

/// Background task registration should only happen once per run
/// If the SDK gets destroyed and initialized again this would cause a crash
private var didRegisterBackgroundTask: Bool = false

@available(iOS 13.5, *)
class DP3TBackgroundTaskManager {
    static let taskIdentifier: String = "org.dpppt.exposure-notification"

    weak var handler: DP3TBackgroundHandler?

    private let log = Logger(DP3TDatabase.self, category: "backgroundTaskManager")


    init(handler: DP3TBackgroundHandler?) {
        self.handler = handler
    }

    /// Register a background task
    func register() {
        log.trace()
        guard !didRegisterBackgroundTask else { return }
        didRegisterBackgroundTask = true

        BGTaskScheduler.shared.register(forTaskWithIdentifier: DP3TBackgroundTaskManager.taskIdentifier, using: .main) { task in
            self.handleBackgroundTask(task)
        }

        scheduleBackgroundTask()
    }

    private func handleBackgroundTask(_ task: BGTask) {
        log.trace()

        let queue = OperationQueue()

        let completionGroup = DispatchGroup()

        if let handler = handler {
            let handlerOperation = HandlerOperation(handler: handler)

            completionGroup.enter()
            handlerOperation.completionBlock = { [weak self] in
                self?.log.info("handlerOperation finished")
                completionGroup.leave()
            }

            queue.addOperation(handlerOperation)
        }

        let syncOperation = SyncOperation()

        completionGroup.enter()
        syncOperation.completionBlock = { [weak self] in
            self?.log.info("syncOperation finished")
            completionGroup.leave()
        }

        queue.addOperation(syncOperation)

        let outstandingPublishOperation = OutstandingPublish()
        completionGroup.enter()
        outstandingPublishOperation.completionBlock = { [weak self] in
            self?.log.info("outstandingPublishOperation finished")
            completionGroup.leave()
        }

        queue.addOperation(outstandingPublishOperation)

        task.expirationHandler = {
            queue.cancelAllOperations()
        }

        completionGroup.notify(queue: .main) {
            let success = !queue.operations.map { $0.isCancelled }.contains(true)
            task.setTaskCompleted(success: success)
        }

        scheduleBackgroundTask()
    }

    private func scheduleBackgroundTask() {
        log.trace()
        let taskRequest = BGProcessingTaskRequest(identifier: DP3TBackgroundTaskManager.taskIdentifier)
        taskRequest.requiresNetworkConnectivity = true
        do {
            try BGTaskScheduler.shared.submit(taskRequest)
        } catch {
            log.error("background task schedule failed %@", error.localizedDescription)
        }
    }
}
