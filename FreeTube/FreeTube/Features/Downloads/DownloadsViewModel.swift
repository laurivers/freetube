import Foundation
import Observation

/// Tiny façade around `DownloadManager` so the view stays declarative. `DownloadManager`
/// is itself `@Observable`, so the view reads `manager.activeTasks` directly — this
/// view-model only owns the error toast state and the cancel action.
@available(iOS 17.0, *)
@Observable
@MainActor
final class DownloadsViewModel {
    var errorState: ErrorState?
    var showPhotoSaveConfirmation = false
    private(set) var savedPhotoTitle = ""
    private(set) var savingToPhotosIDs: Set<String> = []

    let manager: DownloadManager

    init(manager: DownloadManager = .shared) {
        self.manager = manager
    }

    /// Cancel a transfer-queue row. Routes by snapshot kind:
    ///   - YouTube downloads (id is the snapshot UUID) → `DownloadManager.cancel(taskID:)`.
    ///   - URL downloads (id has `"fetch-"` prefix, set in `URLDownloadManager.transferSnapshotID`)
    ///     → `URLDownloadManager.cancel(url:)`. The original URL is stored in `snapshot.videoID`
    ///     for exactly this lookup.
    func cancel(_ snapshot: DownloadTaskSnapshot) {
        if snapshot.id.hasPrefix("fetch-") {
            URLDownloadManager.shared.cancel(url: snapshot.videoID)
        } else {
            manager.cancel(taskID: snapshot.id)
        }
    }

    /// Copies a downloaded video into Photos without moving or deleting the source file.
    /// Coalesces repeated menu taps for the same item while the system import is running.
    func saveToPhotos(fileURL: URL, itemID: String, title: String) async {
        guard savingToPhotosIDs.insert(itemID).inserted else { return }
        defer { savingToPhotosIDs.remove(itemID) }

        do {
            try await PhotoLibrarySaver.saveVideo(at: fileURL)
            savedPhotoTitle = title
            showPhotoSaveConfirmation = true
        } catch {
            errorState = ErrorState(from: error)
        }
    }
}
