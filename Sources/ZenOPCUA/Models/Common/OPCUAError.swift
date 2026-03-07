/// Errors that can occur during OPC UA operations.
public enum OPCUAError: Error, Equatable {
    /// Connection to the OPC UA server failed or was lost.
    case connectionError

    /// Session-related error (e.g., no active session).
    case sessionError

    /// Operation timed out waiting for server response.
    case timeout

    /// Server returned a specific status code with optional reason.
    case code(_ status: StatusCodes, reason: String = "")

    /// Generic error with a descriptive message.
    case generic(_ text: String)

    public static func == (lhs: OPCUAError, rhs: OPCUAError) -> Bool {
        switch (lhs, rhs) {
        case (.connectionError, .connectionError): return true
        case (.sessionError, .sessionError): return true
        case (.timeout, .timeout): return true
        case let (.code(lhsStatus, _), .code(rhsStatus, _)): return lhsStatus == rhsStatus
        case let (.generic(lhsText), .generic(rhsText)): return lhsText == rhsText
        default: return false
        }
    }
}
