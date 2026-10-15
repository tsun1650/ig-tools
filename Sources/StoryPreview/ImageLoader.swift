import Foundation
import ImageIO

/// Bounded decoding keeps scrolling from flooding the disk and decoder threads.
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()
    private let cache = NSCache<NSString, CGImage>()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "StoryPreview.image-decoding"
        queue.maxConcurrentOperationCount = 3
        queue.qualityOfService = .userInitiated
        return queue
    }()
    init() { cache.totalCostLimit = 160 * 1024 * 1024 }
    private func key(_ url: URL, _ size: Int) -> String {
        let values = try? URL(fileURLWithPath: url.path).resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return "\(url.path)|\(size)|\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0)|\(values?.fileSize ?? 0)"
    }
    func cached(_ url: URL, maxPixel: Int) -> CGImage? { cache.object(forKey: key(url, maxPixel) as NSString) }
    func load(_ url: URL, maxPixel: Int, priority: Operation.QueuePriority = .normal) async -> CGImage? {
        let key = key(url, maxPixel)
        if let image = cache.object(forKey: key as NSString) { return image }
        let operation = BlockOperation()
        operation.queuePriority = priority
        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                operation.addExecutionBlock { [self, weak operation] in
                    guard operation?.isCancelled == false else { return }
                    let image = cache.object(forKey: key as NSString) ?? Imaging.load(url, maxPixel: maxPixel)
                    if let image { cache.setObject(image, forKey: key as NSString, cost: image.bytesPerRow * image.height) }
                    // Completion below resumes even when an operation is cancelled before starting.
                }
                operation.completionBlock = { [self] in
                    continuation.resume(returning: cache.object(forKey: key as NSString))
                }
                queue.addOperation(operation)
            }
        }, onCancel: { operation.cancel() })
    }
}
