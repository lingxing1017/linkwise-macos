import Foundation

public enum LinkwiseError: LocalizedError, Equatable, Sendable {
    case invalidServerURL
    case invalidBookmarkURL(String)
    case invalidResponse
    case httpStatus(Int, message: String?, code: String?)
    case duplicateURL(message: String, bookmark: Bookmark?)
    case decoding(String)
    case network(String)
    case cache(String)
    case unsupportedBrowser
    case permissionDenied(String)
    case noCurrentPage(String)

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "拾链服务地址无效。"
        case .invalidBookmarkURL:
            return "书签 URL 无效。"
        case .invalidResponse:
            return "拾链服务返回无效响应。"
        case let .httpStatus(_, message, _):
            return message ?? "拾链服务请求失败。"
        case let .duplicateURL(message, _):
            return message
        case let .decoding(message):
            return "无法解析拾链返回数据：\(message)"
        case let .network(message):
            return "无法连接拾链服务：\(message)"
        case let .cache(message):
            return "本地缓存不可用：\(message)"
        case .unsupportedBrowser:
            return "当前应用暂不支持读取页面，请切换到 Safari、Chrome、Edge、Brave 或 Helium 后重试。"
        case let .permissionDenied(message):
            return message
        case let .noCurrentPage(message):
            return message
        }
    }
}
