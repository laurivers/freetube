import Foundation

/// Narrow fallback for public X/Twitter posts whose media is omitted by both of yt-dlp's
/// unauthenticated APIs. FxTwitter receives only the public post ID; no FreeTube session data,
/// cookies, or credentials are sent.
struct TwitterMediaFallbackService: Sendable {
    enum FallbackError: Error {
        case notTwitterStatusURL
        case invalidResponse
        case noVideo
    }

    func fetch(url originalURL: String) async throws -> RemoteMedia {
        guard let statusID = Self.statusID(from: originalURL) else {
            throw FallbackError.notTwitterStatusURL
        }
        guard let endpoint = URL(string: "https://api.fxtwitter.com/status/\(statusID)") else {
            throw FallbackError.invalidResponse
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw FallbackError.invalidResponse
        }

        let payload = try JSONDecoder().decode(Response.self, from: data)
        let videos = payload.tweet.media?.videos ?? []
        let formats = videos.flatMap(Self.remoteFormats)
        guard !formats.isEmpty else { throw FallbackError.noVideo }

        let firstVideo = videos.first
        return RemoteMedia(
            id: payload.tweet.id,
            webpageURL: URL(string: payload.tweet.url) ?? URL(string: originalURL),
            title: payload.tweet.text.isEmpty ? "X video" : payload.tweet.text,
            uploader: payload.tweet.author?.name ?? payload.tweet.author?.screenName,
            thumbnailURL: firstVideo.flatMap { URL(string: $0.thumbnailURL) },
            duration: firstVideo?.duration,
            isLive: false,
            formats: formats,
            subtitles: [],
            descriptionText: payload.tweet.text.isEmpty ? nil : payload.tweet.text,
            extractor: "Twitter"
        )
    }

    private static func statusID(from rawURL: String) -> String? {
        guard let url = URL(string: rawURL),
              let host = url.host?.lowercased(),
              host == "x.com" || host.hasSuffix(".x.com")
                || host == "twitter.com" || host.hasSuffix(".twitter.com") else { return nil }
        let components = url.pathComponents.filter { $0 != "/" }
        guard let statusIndex = components.firstIndex(where: { $0.lowercased() == "status" }),
              components.indices.contains(statusIndex + 1) else { return nil }
        let id = components[statusIndex + 1]
        return id.allSatisfy(\.isNumber) ? id : nil
    }

    private static func remoteFormats(from video: Video) -> [RemoteFormat] {
        video.variants.compactMap { variant in
            guard variant.contentType.lowercased() == "video/mp4",
                  let url = URL(string: variant.url) else { return nil }
            let dimensions = dimensions(from: url)
            let bitrateKbps = variant.bitrate.map { Double($0) / 1_000 }
            return RemoteFormat(
                id: "twitter-\(dimensions?.height ?? 0)-\(variant.bitrate ?? 0)",
                url: url,
                ext: "mp4",
                width: dimensions?.width,
                height: dimensions?.height,
                fps: nil,
                vcodec: "h264",
                acodec: "aac",
                vbr: bitrateKbps,
                abr: nil,
                filesize: nil,
                protocolKind: .https,
                rawProtocol: "https"
            )
        }
    }

    private static func dimensions(from url: URL) -> (width: Int, height: Int)? {
        for component in url.pathComponents.reversed() {
            let parts = component.split(separator: "x", maxSplits: 1)
            if parts.count == 2, let width = Int(parts[0]), let height = Int(parts[1]) {
                return (width, height)
            }
        }
        return nil
    }

    private struct Response: Decodable {
        let tweet: Tweet
    }

    private struct Tweet: Decodable {
        let url: String
        let id: String
        let text: String
        let author: Author?
        let media: Media?
    }

    private struct Author: Decodable {
        let name: String?
        let screenName: String?

        enum CodingKeys: String, CodingKey {
            case name
            case screenName = "screen_name"
        }
    }

    private struct Media: Decodable {
        let videos: [Video]?
    }

    private struct Video: Decodable {
        let thumbnailURL: String
        let duration: TimeInterval?
        let variants: [Variant]

        enum CodingKeys: String, CodingKey {
            case thumbnailURL = "thumbnail_url"
            case duration
            case variants
        }
    }

    private struct Variant: Decodable {
        let url: String
        let bitrate: Int?
        let contentType: String

        enum CodingKeys: String, CodingKey {
            case url
            case bitrate
            case contentType = "content_type"
        }
    }
}
