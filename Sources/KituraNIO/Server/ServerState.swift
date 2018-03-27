/// Enum defining possible server states.
public enum ServerState {

    /// Initial server state.
    case unknown

    /// State indicating that server has been started.
    case started

    /// State indicating that server was stopped.
    case stopped

    /// State indicating that server has thrown an error.
    case failed
}
