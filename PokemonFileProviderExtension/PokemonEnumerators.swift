//
//  PokemonEnumerators.swift
//  PokemonFileProviderExtension
//
//  Created by Samir Lora on 30/09/25.
//

import FileProvider
import os.log

// MARK: - Root Enumerator

class PokemonRootEnumerator: NSObject, NSFileProviderEnumerator {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        super.init()
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let items: [NSFileProviderItem] = [PokemonFolderItem()]
        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
    }

    func invalidate() {}

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        let items: [NSFileProviderItem] = [PokemonFolderItem()]
        observer.didUpdate(items)

        let currentAnchor = NSFileProviderSyncAnchor(Date().description.data(using: .utf8)!)
        observer.finishEnumeratingChanges(upTo: currentAnchor, moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let anchor = NSFileProviderSyncAnchor(Date().data(using: .utf8)!)
        completionHandler(anchor)
    }
}

// MARK: - Pokemon Folder Enumerator

class PokemonFolderEnumerator: NSObject, NSFileProviderEnumerator {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        super.init()
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        Task {
            do {
                let pokemon = try await PokeAPIService.shared.fetchPokemonList(limit: 151)

                let items: [NSFileProviderItem] = pokemon.map { poke in
                    let pokemonItem = PokemonItem(pokemon: poke)
                    let fileItem = PokemonFileItem(pokemon: pokemonItem)
                    return fileItem
                }

                observer.didEnumerate(items)
                observer.finishEnumerating(upTo: nil)

            } catch {
                logger.error("Failed to fetch Pokemon: \(error.localizedDescription)")
                observer.didEnumerate([])
                observer.finishEnumerating(upTo: nil)
            }
        }
    }

    func invalidate() {
        // Enumerator invalidated
    }

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        Task {
            do {
                let pokemon = try await PokeAPIService.shared.fetchPokemonList(limit: 151)

                let items: [NSFileProviderItem] = pokemon.map { poke in
                    let pokemonItem = PokemonItem(pokemon: poke)
                    return PokemonFileItem(pokemon: pokemonItem)
                }

                observer.didUpdate(items)

                let currentAnchor = NSFileProviderSyncAnchor(Date().description.data(using: .utf8)!)
                observer.finishEnumeratingChanges(upTo: currentAnchor, moreComing: false)

            } catch {
                logger.error("Failed to fetch Pokemon: \(error.localizedDescription)")
                observer.finishEnumeratingChanges(upTo: syncAnchor, moreComing: false)
            }
        }
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let anchor = NSFileProviderSyncAnchor(Date().description.data(using: .utf8)!)
        completionHandler(anchor)
    }
}

// MARK: - Working Set Enumerator

class PokemonWorkingSetEnumerator: NSObject, NSFileProviderEnumerator {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        super.init()
        logger.log("WORKING SET ENUMERATOR CREATED!")

        // Try to trigger enumeration immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.logger.log("WORKING SET: Checking if enumeration is needed...")
        }
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        let items: [NSFileProviderItem] = [PokemonFolderItem()]
        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
    }

    func invalidate() {}

    func enumerateChanges(for observer: NSFileProviderChangeObserver, from syncAnchor: NSFileProviderSyncAnchor) {
        let items: [NSFileProviderItem] = [PokemonFolderItem()]
        observer.didUpdate(items)

        let currentAnchor = NSFileProviderSyncAnchor(Date().description.data(using: .utf8)!)
        observer.finishEnumeratingChanges(upTo: currentAnchor, moreComing: false)
    }

    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        let anchor = NSFileProviderSyncAnchor(Date().data(using: .utf8)!)
        completionHandler(anchor)
    }
}

extension Date {
    func data(using encoding: String.Encoding) -> Data? {
        return self.description.data(using: encoding)
    }
}
