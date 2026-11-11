import Foundation

/// Glue between the panel model and script firmwares (FM1/FirmwareHost).
extension SynthModel {
    /// Boots a script firmware: builds its engine and runs its scripts.
    func startPackage(_ fw: Firmware) {
        stopPackage()
        do {
            let host = try PackageHost(firmware: fw, model: self)
            packageHost = host
            host.start()
        } catch {
            showPopup(.message("Firmware error", error.localizedDescription), duration: 3)
            restoreNativeEngine()
        }
        objectWillChange.send()
    }

    /// Stops the running script firmware (if any) and gives the engine back to the native panel.
    func stopPackage() {
        guard let h = packageHost else { return }
        h.stop()
        packageHost = nil
        // keep the detached engine alive past any render callback still holding it
        retiredPackageEngines.append(h.engine)
        let keep = h.engine
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.retiredPackageEngines.removeAll { $0 === keep }
        }
        restoreNativeEngine()
    }

    /// Re-applies the stock edit buffer, preset extras and globals to the engine and FX chain.
    func restoreNativeEngine() {
        engine.blockHook = nil
        engine.allNotesOff()
        pushPatch()
        pushExtra()
        applyGlobals()
    }

    /// Down / up of every rubber button (the panel's hold callback).
    func buttonHold(_ b: PanelButton, _ down: Bool) {
        if let h = packageHost {
            if !isBusyFlashing { h.button(b, down: down) }
            return
        }
        switch b {
        case .rec: recHeld = down
        case .glo:
            gloHeld = down
            if !down { audio.groove.fill = false }
        default: break
        }
    }
}
