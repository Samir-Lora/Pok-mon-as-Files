//
//  PokemonModels.swift
//  Pokémon as Files
//
//  Created by Samir Lora on 30/09/25.
//

import Foundation

// MARK: - API Response Models
struct PokemonListResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [Pokemon]
}

struct Pokemon: Codable, Identifiable {
    let name: String
    let url: String

    var id: Int {
        // Extract Pokemon ID from URL: https://pokeapi.co/api/v2/pokemon/1/
        let components = url.components(separatedBy: "/")
        return Int(components[components.count - 2]) ?? 0
    }
}

// MARK: - File Provider Models
struct PokemonItem {
    let pokemon: Pokemon
    let identifier: String

    init(pokemon: Pokemon) {
        self.pokemon = pokemon
        self.identifier = "pokemon_\(pokemon.id)"
    }

    var filename: String {
        return "\(pokemon.name).txt"
    }

    var displayName: String {
        return pokemon.name.capitalized
    }
}

// MARK: - App Groups Keys
enum AppGroupKeys {
    static let groupIdentifier = "group.lb.pokemon-as-files"
    static let pokemonDataKey = "cached_pokemon_data"
    static let lastUpdateKey = "last_pokemon_update"
}
