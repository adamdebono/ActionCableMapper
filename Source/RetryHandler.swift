
public enum RetryStrategy {
    case exponentialBackoff(maxRetries: Int, maxInterval: TimeInterval)
    case logarighmicBackoff(maxRetries: Int, maxInterval: TimeInterval)
    case linear(maxRetries: Int, interval: TimeInterval)
    case none

    public static var `default`: RetryStrategy = .exponentialBackoff(maxRetries: 30, maxInterval: 30)

    func nextInterval(_ retries: Int) -> TimeInterval? {
        switch self {
        case .exponentialBackoff(let maxRetries, let maxInterval):
            guard maxRetries >= retries else { return nil }
            let interval = 5 * log(Double(retries))
            return min(interval, maxInterval)
        case .logarighmicBackoff(let maxRetries, let maxInterval):
            guard maxRetries >= retries else { return nil }
            let interval = exp2(Double(retries))
            return min(interval, maxInterval)
        case .linear(let maxRetries, let interval):
            guard maxRetries >= retries else { return nil }
            return interval
        case .none:
            return nil
        }
    }
}

internal class RetryHandler {

    let strategy: RetryStrategy

    init(strategy: RetryStrategy) {
        self.strategy = strategy
    }

    deinit {
        if let timer = self.timer {
            timer.invalidate()
        }
    }

    private var retries: Int = 0
    private var timer: Timer?

    func retry(_ callback: @escaping (() -> Void)) {
        guard self.timer == nil else { return }

        self.retries += 1
        guard let interval = self.strategy.nextInterval(self.retries) else { return }

        self.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false, block: { [weak self] (timer) in
            self?.timer = nil
            callback()
        })
    }
}
