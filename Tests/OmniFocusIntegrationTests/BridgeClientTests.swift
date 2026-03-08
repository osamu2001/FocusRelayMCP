import Foundation
import Testing
@testable import OmniFocusAutomation

@Test
func bridgeClientConfigurationDefaults() {
    let configuration = BridgeClientConfiguration.fromEnvironment([:])

    #expect(configuration.responseTimeout == 45.0)
    #expect(configuration.responsePollInterval == 0.05)
}

@Test
func bridgeClientConfigurationUsesEnvironmentOverrides() {
    let configuration = BridgeClientConfiguration.fromEnvironment([
        "FOCUS_RELAY_BRIDGE_RESPONSE_TIMEOUT_SECONDS": "30",
        "FOCUS_RELAY_BRIDGE_RESPONSE_POLL_MS": "25"
    ])

    #expect(configuration.responseTimeout == 30.0)
    #expect(configuration.responsePollInterval == 0.025)
}

@Test
func bridgeClientConfigurationIgnoresInvalidEnvironmentOverrides() {
    let configuration = BridgeClientConfiguration.fromEnvironment([
        "FOCUS_RELAY_BRIDGE_RESPONSE_TIMEOUT_SECONDS": "0",
        "FOCUS_RELAY_BRIDGE_RESPONSE_POLL_MS": "-1"
    ])

    #expect(configuration.responseTimeout == 45.0)
    #expect(configuration.responsePollInterval == 0.05)
}

@Test
func strandedRedispatchDelayIsBounded() {
    #expect(strandedRedispatchDelay(timeout: 45.0) == 2.0)
    #expect(abs(strandedRedispatchDelay(timeout: 12.0) - 1.2) < 0.000_001)
    #expect(strandedRedispatchDelay(timeout: 3.0) == 0.5)
}
