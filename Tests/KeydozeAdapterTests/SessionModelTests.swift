import Testing
import KeydozeCore
@testable import Keydoze

@Suite("Session navigation without input interception")
@MainActor
struct SessionModelTests {
    @Test("Cancel preparation returns to setup and preserves choices")
    func cancelPreparation() {
        let model = SessionModel(simulation: true)
        model.scope = .pointing
        model.duration = 120
        model.begin()
        #expect(model.screen == .arming)
        model.cancel()
        model.refreshSession()
        #expect(model.screen == .ready)
        #expect(!model.running)
        #expect(model.scope == .pointing)
        #expect(model.duration == 120)
        model.begin()
        #expect(model.screen == .arming)
        model.reset()
    }

    @Test("Finishing an active session still shows completion after release")
    func finishActive() {
        let model = SessionModel(simulation: true)
        model.begin()
        for _ in 0..<61 { model.refreshSession() }
        #expect(model.screen == .active)
        model.cancel()
        model.refreshSession()
        #expect(model.screen == .releasing)
        for _ in 0..<6 { model.refreshSession() }
        #expect(model.screen == .finished(.cancelled))
        model.reset()
    }
}
