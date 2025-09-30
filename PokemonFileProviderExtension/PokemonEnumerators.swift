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
        logger.log("Enumerating root items")

        let items: [NSFileProviderItem] = [PokemonFolderItem()]

        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
    }

    func invalidate() {
        logger.log("Root enumerator invalidated")
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
        logger.log("Enumerating Pokemon folder items")

        Task { @MainActor in
            do {
                let pokemonService = PokeAPIService.shared
                var pokemon = pokemonService.cachedPokemon

                // If no cached data, try to fetch fresh data
                if pokemon.isEmpty {
                    do {
                        pokemon = try await pokemonService.fetchPokemonList()
                    } catch {
                        logger.error("Failed to fetch Pokemon: \(error.localizedDescription)")
                        observer.finishEnumeratingWithError(error)
                        return
                    }
                }

                let items: [NSFileProviderItem] = pokemon.map { pokemon in
                    PokemonFileItem(pokemon: PokemonItem(pokemon: pokemon))
                }

                logger.log("Enumerated \(items.count) Pokemon items")
                observer.didEnumerate(items)
                observer.finishEnumerating(upTo: nil)

            }
        }
    }

    func invalidate() {
        logger.log("Pokemon folder enumerator invalidated")
    }
}

// MARK: - Working Set Enumerator

class PokemonWorkingSetEnumerator: NSObject, NSFileProviderEnumerator {
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
        super.init()
    }

    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
        logger.log("Enumerating working set")

        Task { @MainActor in
            let pokemonService = PokeAPIService.shared
            let pokemon = pokemonService.cachedPokemon

            var items: [NSFileProviderItem] = [
                PokemonRootItem(),
                PokemonFolderItem()
            ]

            let pokemonItems: [NSFileProviderItem] = pokemon.map { pokemon in
                PokemonFileItem(pokemon: PokemonItem(pokemon: pokemon))
            }

            items.append(contentsOf: pokemonItems)

            logger.log("Working set enumerated \(items.count) total items")
            observer.didEnumerate(items)
            observer.finishEnumerating(upTo: nil)
        }
    }

    func invalidate() {
        logger.log("Working set enumerator invalidated")
    }
}
