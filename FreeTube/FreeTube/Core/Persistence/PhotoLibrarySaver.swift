import Foundation
import Photos

/// Writes an already-downloaded local video into the system photo library.
/// Requests add-only access so the app cannot read or enumerate the user's photos.
enum PhotoLibrarySaver {
    private static let supportedVideoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    enum SaveError: LocalizedError {
        case permissionDenied
        case permissionRestricted
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Photos access was denied. Allow FreeTube to add photos in Settings, then try again."
            case .permissionRestricted:
                "Photos access is restricted on this device."
            case .unsupportedFormat:
                "This file format can't be saved to Photos. Use Open in… to export it instead."
            }
        }
    }

    static func saveVideo(at fileURL: URL) async throws {
        guard fileURL.isFileURL, FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        guard canSaveVideo(at: fileURL) else {
            throw SaveError.unsupportedFormat
        }

        let status = await authorizationStatus()
        switch status {
        case .authorized, .limited:
            break
        case .denied:
            throw SaveError.permissionDenied
        case .restricted:
            throw SaveError.permissionRestricted
        case .notDetermined:
            // `authorizationStatus()` resolves `.notDetermined` by requesting access.
            throw SaveError.permissionDenied
        @unknown default:
            throw SaveError.permissionDenied
        }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: fileURL, options: nil)
        }
    }

    static func canSaveVideo(at fileURL: URL) -> Bool {
        supportedVideoExtensions.contains(fileURL.pathExtension.lowercased())
    }

    private static func authorizationStatus() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
