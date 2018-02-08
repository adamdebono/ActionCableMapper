
public enum CodingError: Error {
    case invalidType
    case missingData
}

public enum TransmitError: Error {
    case notConnected
    case notSubscribed
}
