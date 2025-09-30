//
//  PokeAPIService.swift
//  Pokémon as Files
//
//  Created by Samir Lora on 30/09/25.
//

import Foundation
import Combine
import os.log

@MainActor
class PokeAPIService: ObservableObject {
    static let shared = PokeAPIService()

    private let logger = Logger(subsystem: "lb.pokemon-as-files", category: "PokeAPIService")
    private let session: URLSession
    private let baseURL = "https://pokeapi.co/api/v2/pokemon"

    private static func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.waitsForConnectivity = true

        // Configure for sandbox environment
        config.httpAdditionalHeaders = [
            "User-Agent": "Pokemon-as-Files/1.0"
        ]

        return URLSession(configuration: config)
    }

    @Published var pokemonList: [Pokemon] = []
    @Published var isLoading = false
    @Published var error: Error?

    private init() {
        self.session = Self.createURLSession()
        loadCachedPokemon()
    }

    // MARK: - Public Methods

    func fetchPokemonList(limit: Int = 151) async throws -> [Pokemon] {
        logger.log("Fetching Pokemon list with limit: \(limit)")

        guard let url = URL(string: "\(baseURL)?limit=\(limit)") else {
            throw PokeAPIError.invalidURL
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode else {
                throw PokeAPIError.networkError
            }

            let pokemonResponse = try JSONDecoder().decode(PokemonListResponse.self, from: data)

            pokemonList = pokemonResponse.results
            cachePokemon(pokemonResponse.results)

            logger.log("Successfully fetched \(pokemonResponse.results.count) Pokemon")
            return pokemonResponse.results

        } catch {
            self.error = error
            logger.error("Failed to fetch Pokemon: \(error.localizedDescription)")
            throw error
        }
    }

    func refreshPokemonList() async throws {
        _ = try await fetchPokemonList()
    }

    // MARK: - Caching

    private func loadCachedPokemon() {
        guard let sharedDefaults = UserDefaults(suiteName: AppGroupKeys.groupIdentifier),
              let data = sharedDefaults.data(forKey: AppGroupKeys.pokemonDataKey) else {
            logger.log("No cached Pokemon data found")
            return
        }

        do {
            pokemonList = try JSONDecoder().decode([Pokemon].self, from: data)
            logger.log("Loaded \(self.pokemonList.count) cached Pokemon")
        } catch {
            logger.error("Failed to decode cached Pokemon: \(error.localizedDescription)")
        }
    }

    private func cachePokemon(_ pokemon: [Pokemon]) {
        guard let sharedDefaults = UserDefaults(suiteName: AppGroupKeys.groupIdentifier) else {
            logger.error("Failed to access shared UserDefaults")
            return
        }

        do {
            let data = try JSONEncoder().encode(pokemon)
            sharedDefaults.set(data, forKey: AppGroupKeys.pokemonDataKey)
            sharedDefaults.set(Date(), forKey: AppGroupKeys.lastUpdateKey)
            logger.log("Cached \(pokemon.count) Pokemon successfully")
        } catch {
            logger.error("Failed to cache Pokemon: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    var cachedPokemon: [Pokemon] {
        guard let sharedDefaults = UserDefaults(suiteName: AppGroupKeys.groupIdentifier),
              let data = sharedDefaults.data(forKey: AppGroupKeys.pokemonDataKey),
              let pokemon = try? JSONDecoder().decode([Pokemon].self, from: data) else {
            return []
        }
        return pokemon
    }

    var lastUpdateDate: Date? {
        guard let sharedDefaults = UserDefaults(suiteName: AppGroupKeys.groupIdentifier) else {
            return nil
        }
        return sharedDefaults.object(forKey: AppGroupKeys.lastUpdateKey) as? Date
    }
}

// MARK: - Errors

enum PokeAPIError: LocalizedError {
    case invalidURL
    case networkError
    case decodingError
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError:
            return "Network request failed"
        case .decodingError:
            return "Failed to decode response"
        case .noData:
            return "No data received"
        }
    }
}
