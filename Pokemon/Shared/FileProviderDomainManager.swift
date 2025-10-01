//
//  FileProviderDomainManager.swift
//  Pokemon
//
//  Created by Samir Lora on 30/09/25.
//

import Foundation
import FileProvider
import Combine
import os.log

class FileProviderDomainManager: ObservableObject {
    static let shared = FileProviderDomainManager()

    private let logger = Logger(subsystem: "lb.pokemon", category: "DomainManager")
    private let domainIdentifier = NSFileProviderDomainIdentifier(rawValue: "pokemon")

    @Published var isConnected = false
    @Published var error: Error?

    private init() {
        // Initialize without checking status immediately to avoid API issues
        isConnected = false
    }

    // MARK: - Public Methods

    func connectDomain() async throws {
        let domain = NSFileProviderDomain(
            identifier: domainIdentifier,
            displayName: "Pokemon Drive"
        )

        do {
            try await NSFileProviderManager.add(domain)
            isConnected = true
        } catch {
            self.error = error
            throw error
        }
    }

    func disconnectDomain() async throws {
        let domain = NSFileProviderDomain(
            identifier: domainIdentifier,
            displayName: "Pokemon Drive"
        )

        do {
            try await NSFileProviderManager.remove(domain)
            isConnected = false
        } catch {
            self.error = error
            throw error
        }
    }

    func refreshDomain() async throws {
        guard isConnected else {
            throw NSError(domain: "FileProviderDomainManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Domain not connected"])
        }

        let domain = NSFileProviderDomain(
            identifier: domainIdentifier,
            displayName: "Pokemon Drive"
        )

        guard let manager = NSFileProviderManager(for: domain) else {
            throw NSError(domain: "FileProviderDomainManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to get file provider manager"])
        }

        try await manager.signalEnumerator(for: NSFileProviderItemIdentifier.rootContainer)

        let pokemonFolderIdentifier = NSFileProviderItemIdentifier("pokemon_folder")
        try await manager.signalEnumerator(for: pokemonFolderIdentifier)
    }

    // MARK: - Helper Methods

    func updateConnectionStatus(_ connected: Bool) {
        isConnected = connected
    }
}