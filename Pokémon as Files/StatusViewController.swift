//
//  StatusViewController.swift
//  Pokémon as Files
//
//  Created by Samir Lora on 30/09/25.
//

import Cocoa
import Combine

class StatusViewController: NSViewController {

    private var statusLabel: NSTextField!
    private var pokemonCountLabel: NSTextField!
    private var lastUpdateLabel: NSTextField!
    private var connectButton: NSButton!
    private var refreshButton: NSButton!

    private var cancellables = Set<AnyCancellable>()

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 240))
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindData()
        updateUI()
    }

    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Create UI programmatically
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 12
        stackView.alignment = .leading
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Status label
        statusLabel = NSTextField(labelWithString: "Disconnected")
        statusLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        statusLabel.textColor = .systemRed
        statusLabel.isEditable = false
        statusLabel.isBordered = false
        statusLabel.backgroundColor = .clear

        // Pokemon count label
        pokemonCountLabel = NSTextField(labelWithString: "0 Pokémon loaded")
        pokemonCountLabel.font = NSFont.systemFont(ofSize: 12)
        pokemonCountLabel.textColor = .secondaryLabelColor
        pokemonCountLabel.isEditable = false
        pokemonCountLabel.isBordered = false
        pokemonCountLabel.backgroundColor = .clear

        // Last update label
        lastUpdateLabel = NSTextField(labelWithString: "Never updated")
        lastUpdateLabel.font = NSFont.systemFont(ofSize: 10)
        lastUpdateLabel.textColor = .tertiaryLabelColor
        lastUpdateLabel.isEditable = false
        lastUpdateLabel.isBordered = false
        lastUpdateLabel.backgroundColor = .clear

        // Buttons
        connectButton = NSButton(title: "Connect", target: self, action: #selector(connectAction))
        connectButton.bezelStyle = .rounded

        refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshAction))
        refreshButton.bezelStyle = .rounded

        let buttonStackView = NSStackView()
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 8
        buttonStackView.addArrangedSubview(connectButton)
        buttonStackView.addArrangedSubview(refreshButton)

        stackView.addArrangedSubview(statusLabel)
        stackView.addArrangedSubview(pokemonCountLabel)
        stackView.addArrangedSubview(lastUpdateLabel)
        stackView.addArrangedSubview(NSView()) // Spacer
        stackView.addArrangedSubview(buttonStackView)

        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ])
    }

    private func bindData() {
        // Bind domain manager status
        FileProviderDomainManager.shared.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.updateConnectionStatus(isConnected)
            }
            .store(in: &cancellables)

        // Bind Pokemon service data
        PokeAPIService.shared.$pokemonList
            .receive(on: DispatchQueue.main)
            .sink { [weak self] pokemon in
                self?.pokemonCountLabel.stringValue = "\(pokemon.count) Pokémon loaded"
                self?.updateLastUpdateTime()
            }
            .store(in: &cancellables)
    }

    private func updateUI() {
        Task {
            let isConnected = await FileProviderDomainManager.shared.isConnected
            let pokemonCount = await PokeAPIService.shared.pokemonList.count

            await MainActor.run {
                updateConnectionStatus(isConnected)
                pokemonCountLabel.stringValue = "\(pokemonCount) Pokémon loaded"
                updateLastUpdateTime()
            }
        }
    }

    private func updateConnectionStatus(_ isConnected: Bool) {
        statusLabel.stringValue = isConnected ? "Connected" : "Disconnected"
        statusLabel.textColor = isConnected ? .systemGreen : .systemRed
        connectButton.title = isConnected ? "Disconnect" : "Connect"
    }

    private func updateLastUpdateTime() {
        if let lastUpdate = PokeAPIService.shared.lastUpdateDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            lastUpdateLabel.stringValue = "Updated: \(formatter.string(from: lastUpdate))"
        } else {
            lastUpdateLabel.stringValue = "Never updated"
        }
    }

    @objc private func connectAction() {
        Task {
            if await FileProviderDomainManager.shared.isConnected {
                try? await FileProviderDomainManager.shared.disconnectDomain()
            } else {
                try? await FileProviderDomainManager.shared.connectDomain()
            }
        }
    }

    @objc private func refreshAction() {
        Task {
            try? await PokeAPIService.shared.refreshPokemonList()
            try? await FileProviderDomainManager.shared.refreshDomain()
        }
    }
}
