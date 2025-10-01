//
//  AppDelegate.swift
//  Pokemon
//
//  Created by Samir Lora on 30/09/25.
//

import Cocoa
import os.log

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let logger = Logger(subsystem: "lb.pokemon", category: "AppDelegate")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.log("Application launched")

        // Hide the main window and dock icon for menu bar app
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()
        setupPopover()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        logger.log("Application terminating")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - Menu Bar Setup

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.title = "🔴"
            button.action = #selector(togglePopover)
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let connectItem = NSMenuItem(title: "Connect Domain", action: #selector(connectDomain), keyEquivalent: "")
        let disconnectItem = NSMenuItem(title: "Disconnect Domain", action: #selector(disconnectDomain), keyEquivalent: "")
        let refreshItem = NSMenuItem(title: "Refresh", action: #selector(refreshDomain), keyEquivalent: "r")

        menu.addItem(connectItem)
        menu.addItem(disconnectItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(refreshItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 360, height: 240)
        popover?.behavior = .transient
        popover?.contentViewController = StatusViewController()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func connectDomain() {
        logger.log("Connect domain requested")
        Task {
            do {
                try await FileProviderDomainManager.shared.connectDomain()
                FileProviderDomainManager.shared.updateConnectionStatus(true)
                updateStatusIcon(connected: true)
                logger.log("Domain connected successfully")

                // Give the system a moment to register the domain, then signal refresh
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                try? await FileProviderDomainManager.shared.refreshDomain()
            } catch {
                logger.error("Failed to connect domain: \(error.localizedDescription)")
                showAlert(title: "Connection Failed", message: error.localizedDescription)
            }
        }
    }

    @objc private func disconnectDomain() {
        logger.log("Disconnect domain requested")
        Task {
            do {
                try await FileProviderDomainManager.shared.disconnectDomain()
                updateStatusIcon(connected: false)
                logger.log("Domain disconnected successfully")
            } catch {
                logger.error("Failed to disconnect domain: \(error.localizedDescription)")
                showAlert(title: "Disconnection Failed", message: error.localizedDescription)
            }
        }
    }

    @objc private func refreshDomain() {
        logger.log("Refresh domain requested")
        Task {
            do {
                // First refresh the Pokemon data
                try await PokeAPIService.shared.refreshPokemonList()

                // Then refresh the file provider domain
                try await FileProviderDomainManager.shared.refreshDomain()
                logger.log("Domain refreshed successfully")
            } catch {
                logger.error("Failed to refresh domain: \(error.localizedDescription)")
                showAlert(title: "Refresh Failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Helper Methods

    private func updateStatusIcon(connected: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.button?.title = connected ? "🟢" : "🔴"
        }
    }

    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
