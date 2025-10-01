//
//  PokeAPIService.swift
//  Pokemon
//
//  Created by Samir Lora on 30/09/25.
//

import Foundation
import Combine
import os.log

class PokeAPIService: ObservableObject {
    static let shared = PokeAPIService()

    private let logger = Logger(subsystem: "lb.pokemon", category: "PokeAPIService")
    private let session: URLSession
    private let baseURL = "https://pokeapi.co/api/v2/pokemon"

    private static func createURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30    // Increased from 30
        config.timeoutIntervalForResource = 60  // Increased from 60
        config.allowsCellularAccess = true
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.waitsForConnectivity = true

        // Additional network configuration for sandbox
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.requestCachePolicy = .useProtocolCachePolicy

        // Configure for sandbox environment
        config.httpAdditionalHeaders = [
            "User-Agent": "Pokemon/1.0",
            "Accept": "application/json",
            "Accept-Encoding": "gzip, deflate"
        ]

        return URLSession(configuration: config)
    }

    @Published var pokemonList: [Pokemon] = []
    @Published var isLoading = false
    @Published var error: Error?

    private init() {
        self.session = Self.createURLSession()
    }

    // MARK: - Public Methods

    func fetchPokemonList(limit: Int = 151) async throws -> [Pokemon] {
        guard let url = URL(string: "\(baseURL)?limit=\(limit)") else {
            throw PokeAPIError.invalidURL
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PokeAPIError.networkError
            }

            guard 200...299 ~= httpResponse.statusCode else {
                throw PokeAPIError.networkError
            }

            let pokemonResponse = try JSONDecoder().decode(PokemonListResponse.self, from: data)

            await MainActor.run {
                pokemonList = pokemonResponse.results
            }

            return pokemonResponse.results

        } catch let urlError as URLError {
            let errorMsg = "Network error: \(urlError.localizedDescription) (Code: \(urlError.code.rawValue))"
            logger.error("\(errorMsg)")
            await MainActor.run {
                self.error = urlError
            }
            throw PokeAPIError.networkError
        } catch let decodingError as DecodingError {
            logger.error("Decoding error: \(decodingError.localizedDescription)")
            await MainActor.run {
                self.error = decodingError
            }
            throw PokeAPIError.decodingError
        } catch {
            let errorMsg = "Unknown error: \(error.localizedDescription)"
            logger.error("\(errorMsg)")
            await MainActor.run {
                self.error = error
            }
            throw error
        }
    }

    func refreshPokemonList() async throws {
        _ = try await fetchPokemonList()
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
