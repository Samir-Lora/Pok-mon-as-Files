//
//  FileProviderExtension.swift
//  PokemonFileProviderExtension
//
//  Created by Samir Lora on 30/09/25.
//

import FileProvider
import UniformTypeIdentifiers
import os.log

class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {
    private let logger = Logger(subsystem: "lb.pokemon.extension", category: "FileProvider")
    let domain: NSFileProviderDomain

    required init(domain: NSFileProviderDomain) {
        self.domain = domain
        super.init()
    }

    func invalidate() {}

    func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        completionHandler(nil, NSFileProviderError(.noSuchItem))
    }

    // MARK: - Item Management

    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        let progress = Progress(totalUnitCount: 1)

        Task {
            do {
                let item = try await fetchItem(for: identifier)
                completionHandler(item, nil)
                progress.completedUnitCount = 1
            } catch {
                logger.error("Failed to fetch item \(identifier.rawValue): \(error.localizedDescription)")
                completionHandler(nil, error)
            }
        }

        return progress
    }

    private func fetchItem(for identifier: NSFileProviderItemIdentifier) async throws -> NSFileProviderItem {
        if identifier == .rootContainer {
            return PokemonRootItem()
        }

        if identifier.rawValue == "pokemon_folder" {
            return PokemonFolderItem()
        }

        // Check if it's a Pokemon file - fetch from API
        if identifier.rawValue.hasPrefix("pokemon_") {
            let pokemon = try await PokeAPIService.shared.fetchPokemonList(limit: 151)
            if let found = pokemon.first(where: { "pokemon_\($0.id)" == identifier.rawValue }) {
                return PokemonFileItem(pokemon: PokemonItem(pokemon: found))
            }
        }

        throw NSFileProviderError(.noSuchItem)
    }

    // MARK: - Enumeration

    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        if containerItemIdentifier == .rootContainer {
            return PokemonRootEnumerator(logger: logger)
        } else if containerItemIdentifier.rawValue == "pokemon_folder" {
            return PokemonFolderEnumerator(logger: logger)
        } else if containerItemIdentifier == .workingSet {
            return PokemonWorkingSetEnumerator(logger: logger)
        } else if containerItemIdentifier == .trashContainer {
            return PokemonRootEnumerator(logger: logger)
        }

        throw NSFileProviderError(.noSuchItem)
    }

    // MARK: - Content Fetching

    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        logger.log("📥 FETCH CONTENTS - Fetching contents for item: \(itemIdentifier.rawValue, privacy: .public)")

        let progress = Progress(totalUnitCount: 1)

        Task {
            do {
                let item = try await fetchItem(for: itemIdentifier)

                // Create temporary file with content
                if let pokemonFileItem = item as? PokemonFileItem {
                    logger.log("📄 Creating temp file for Pokemon: \(pokemonFileItem.filename, privacy: .public)")
                    let tempURL = try await createTempFile(for: pokemonFileItem)
                    completionHandler(tempURL, item, nil)
                } else {
                    logger.log("⚠️ Item is not a file, cannot fetch contents")
                    completionHandler(nil, item, NSFileProviderError(.noSuchItem))
                }

                progress.completedUnitCount = 1
            } catch {
                logger.error("❌ Failed to fetch contents for \(itemIdentifier.rawValue, privacy: .public): \(error.localizedDescription)")
                completionHandler(nil, nil, error)
            }
        }

        return progress
    }

    private func createTempFile(for pokemonItem: PokemonFileItem) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(pokemonItem.filename)

        let content = pokemonItem.fileContent
        try content.write(to: tempURL, atomically: true, encoding: .utf8)

        return tempURL
    }

    // MARK: - Required Protocol Methods (Read-Only Implementation)

    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        // This is a read-only file provider, so we don't support creating items
        let progress = Progress(totalUnitCount: 1)
        let error = NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.Code.noSuchItem.rawValue, userInfo: [NSLocalizedDescriptionKey: "Operation not supported"])
        completionHandler(nil, [], false, error)
        progress.completedUnitCount = 1
        return progress
    }

    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        // This is a read-only file provider, so we don't support modifying items
        let progress = Progress(totalUnitCount: 1)
        let error = NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.Code.noSuchItem.rawValue, userInfo: [NSLocalizedDescriptionKey: "Operation not supported"])
        completionHandler(nil, [], false, error)
        progress.completedUnitCount = 1
        return progress
    }

    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        // This is a read-only file provider, so we don't support deleting items
        let progress = Progress(totalUnitCount: 1)
        let error = NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.Code.noSuchItem.rawValue, userInfo: [NSLocalizedDescriptionKey: "Operation not supported"])
        completionHandler(error)
        progress.completedUnitCount = 1
        return progress
    }
}

// MARK: - File Provider Items

class PokemonRootItem: NSObject, NSFileProviderItem {
    var itemIdentifier: NSFileProviderItemIdentifier = .rootContainer
    var parentItemIdentifier: NSFileProviderItemIdentifier = .rootContainer
    var filename: String = "Pokemon Drive"
    var contentType: UTType = .folder
    var childItemCount: NSNumber? = 1  // Only the "Pokemon" folder

    var capabilities: NSFileProviderItemCapabilities {
        return [.allowsReading, .allowsContentEnumerating]
    }

    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(contentVersion: Data("1".utf8), metadataVersion: Data("1".utf8))
    }

    var creationDate: Date? {
        return Date()
    }

    var contentModificationDate: Date? {
        return Date()
    }
}

class PokemonFolderItem: NSObject, NSFileProviderItem {
    var itemIdentifier: NSFileProviderItemIdentifier = NSFileProviderItemIdentifier("pokemon_folder")
    var parentItemIdentifier: NSFileProviderItemIdentifier = .rootContainer
    var filename: String = "Pokemon"
    var contentType: UTType = .folder
    var childItemCount: NSNumber? = 151  // We have 5 static Pokemon

    // Add required properties
    var capabilities: NSFileProviderItemCapabilities {
        return [.allowsReading, .allowsContentEnumerating]
    }

    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(contentVersion: Data("1".utf8), metadataVersion: Data("1".utf8))
    }

    var creationDate: Date? {
        return Date()
    }

    var contentModificationDate: Date? {
        return Date()
    }
}

class PokemonFileItem: NSObject, NSFileProviderItem {
    private let pokemonItem: PokemonItem

    init(pokemon: PokemonItem) {
        self.pokemonItem = pokemon
        super.init()
    }

    var itemIdentifier: NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier(pokemonItem.identifier)
    }

    var parentItemIdentifier: NSFileProviderItemIdentifier {
        return NSFileProviderItemIdentifier("pokemon_folder")
    }

    var filename: String {
        return pokemonItem.filename
    }

    var contentType: UTType {
        return .plainText
    }

    var documentSize: NSNumber? {
        return NSNumber(value: fileContent.utf8.count)
    }

    // Add required properties
    var capabilities: NSFileProviderItemCapabilities {
        return [.allowsReading]
    }

    var itemVersion: NSFileProviderItemVersion {
        return NSFileProviderItemVersion(contentVersion: Data(pokemonItem.identifier.utf8), metadataVersion: Data("1".utf8))
    }

    var creationDate: Date? {
        return Date()
    }

    var contentModificationDate: Date? {
        return Date()
    }

    var fileContent: String {
        return """
        Pokemon Information
        ==================

        Name: \(pokemonItem.displayName)
        ID: \(pokemonItem.pokemon.id)
        API URL: \(pokemonItem.pokemon.url)

        This file represents a Pokemon from the PokéAPI database.
        The Pokemon app creates virtual files for each of the
        first 151 Pokemon, allowing you to browse them in Finder.

        Last updated: \(Date().formatted())
        """
    }
}
