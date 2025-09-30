//
//  FileProviderDomainManager.swift
//  Pokémon as Files
//
//  Created by Samir Lora on 30/09/25.
//

import Foundation
import FileProvider
import Combine
import os.log

@MainActor
class FileProviderDomainManager: ObservableObject {
    static let shared = FileProviderDomainManager()

    private let logger = Logger(subsystem: "lb.pokemon-as-files", category: "DomainManager")
    private let domainIdentifier = NSFileProviderDomainIdentifier(rawValue: "pokemon")

    @Published var isConnected = false
    @Published var error: Error?

    private init() {
        // Initialize without checking status immediately to avoid API issues
        isConnected = false
    }

    // MARK: - Public Methods

    func connectDomain() async throws {
        logger.log("Attempting to connect Pokemon domain")

        let domain = NSFileProviderDomain(
            identifier: domainIdentifier,
            displayName: "Pokémon Drive"
        )

        do {
            try await NSFileProviderManager.add(domain)
            isConnected = true
            logger.log("Successfully connected Pokemon domain")
        } catch {
            self.error = error
            logger.error("Failed to connect domain: \(error.localizedDescription)")
            throw error
        }
    }

    func disconnectDomain() async throws {
        logger.log("Attempting to disconnect Pokemon domain")

        let domain = NSFileProviderDomain(
            identifier: domainIdentifier,
            displayName: "Pokémon Drive"
        )

        do {
            try await NSFileProviderManager.remove(domain)
            isConnected = false
            logger.log("Successfully disconnected Pokemon domain")
        } catch {
            self.error = error
            logger.error("Failed to disconnect domain: \(error.localizedDescription)")
            throw error
        }
    }

    func refreshDomain() async throws {
        logger.log("Refreshing Pokemon domain")

        guard isConnected else {
            logger.warning("Domain not connected, cannot refresh")
            return
        }

        // For refresh, we'll rely on the extension to handle updates
        // rather than trying to signal specific enumerators
        logger.log("Domain refresh requested")
    }

    // MARK: - Helper Methods

    func updateConnectionStatus(_ connected: Bool) {
        isConnected = connected
        logger.log("Connection status updated: \(connected)")
    }
}