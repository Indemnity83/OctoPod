import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {

    func applicationDidFinishLaunching() {
        // Initiate Watch Connectivity Session so we can talk to the iOS app
        WatchSessionManager.instance.startSession()
                
        // Perform any final initialization of your application.
    }

    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                NSLog("Background task running. Refreshing current job info")
                var oldRequestTimeout = 0.0, oldResourceTimeout = 0.0
                // Make sure we have an OctoPrintClient
                OctoPrintClient.instance.configure()
                // Reduce timeouts since backgound task has 15 seconds limit before it's killed/crashes.
                // This is only used for http traffic (when phone is not around)
                if let restClient = OctoPrintClient.instance.octoPrintRESTClient {
                    // Store old timeouts
                    oldRequestTimeout = restClient.timeoutIntervalForRequest
                    oldResourceTimeout = restClient.timeoutIntervalForResource
                    // Set new timeouts
                    restClient.timeoutIntervalForRequest = 3
                    restClient.timeoutIntervalForResource = 5
                }
                // Refresh information
                PanelManager.instance.refresh(forceRefresh: false) { (refreshed: Bool) in
                    // Restore previous timeout values
                    OctoPrintClient.instance.octoPrintRESTClient?.timeoutIntervalForRequest = oldRequestTimeout
                    OctoPrintClient.instance.octoPrintRESTClient?.timeoutIntervalForResource = oldResourceTimeout
                    // Be sure to complete the background task once you’re done.
                    backgroundTask.setTaskCompletedWithSnapshot(false)
                }
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
                // Be sure to complete the relevant-shortcut task once you're done.
                relevantShortcutTask.setTaskCompletedWithSnapshot(false)
            case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
                // Be sure to complete the intent-did-run task once you're done.
                intentDidRunTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

}
