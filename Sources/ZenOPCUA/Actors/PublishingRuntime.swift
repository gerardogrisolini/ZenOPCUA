import NIO

actor PublishingRuntime {
    private var publisher: RepeatedTask?
    private var milliseconds: Int64 = 0

    func currentMilliseconds() -> Int64 {
        milliseconds
    }

    func setMilliseconds(_ milliseconds: Int64) {
        self.milliseconds = milliseconds
    }

    func storePublisher(_ publisher: RepeatedTask) {
        self.publisher = publisher
    }

    func takePublisher() -> RepeatedTask? {
        let publisher = publisher
        self.publisher = nil
        return publisher
    }
}
