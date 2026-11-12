# Handoff: building the App Store–compliant variation

Read `research/APP_STORE_EVALUATION.md` first (reasons, rule links, confidence levels). This file is the repo map and the work list for a fresh session. Not legal advice.

## Goal
A generic, original-branded 6-operator FM groovebox for iPad that can be sold on the App Store: no GPL-derived code, no third-party photos, no downloaded code, no FM-1 / M-VAVE / SLOOP / Felucca / Melodee / Prophet / CZ-1 / 808 branding, no bundled voices of unclear origin.

## Repo map (about 9,900 lines of Swift, iPadOS 18+, XcodeGen via `project.yml`)

| Path | Role | Compliance status |
|---|---|---|
| `FM1/Engine/FMEngine.swift` (803) | Realtime 6-op engine, voices, envelopes, LFO, ADSR | **Mixed: GPL parts here, see below** |
| `FM1/Engine/Algorithms.swift` (62) | 32 DX7 algorithms | OK (public DX7 data; checked against Apache `dx7core.c`) |
| `FM1/Engine/FMPatch.swift` (236) | DX7 VMEM/SysEx format, ranges, import/export | OK |
| `FM1/Engine/FXChain.swift`, `ArpSeq.swift`, `DrumKit.swift`, `GrooveSeq.swift`, `AudioController.swift` | FX, arp/seq, drums, groovebox, AVAudioEngine and CoreMIDI | Own code; strip "808"/"FM-1" wording |
| `FM1/App/SynthModel.swift` (1257), `SynthModel+Groove.swift`, `FM1App.swift` | Panel state machine, toolbar, help text | Own code; contains FM-1 / M-VAVE / Stock V15 strings |
| `FM1/UI/` (`PanelView`, `PanelComponents`, `ScreenView`, `Theme`, `GrooveScreenView`, `TutorialMode`, `TutorialBrowser`) | Panel art, TFT renderer, tutorial overlay and in-app browser | Panel copies the product look (`research/VISUAL_SPEC.md`); redraw |
| `FM1/FirmwareHost/` | Firmware package system: `Firmware.swift`, `FirmwareCatalog.swift` (installer), `Script/PackageHost.swift` + `Prelude.swift` (JavaScriptCore), `Audio/*` (VASynth, PDSynth, MasterBus, PkgSequencer, PkgArp…), `UI/*` | Audio and sequencer: own code, keep. Installer and download path: remove |
| `Firmwares/` (`stock-v15`, `groove`, `sloop`, `felucca`, `melodee`, `dist/*.fm1fw`, `tools/pack.py`, `README.md`) | Bundled firmware packages, JS + manifest | Rename; remove third-party names and `source`/`credits` brand lines |
| `FM1/Resources/` | `Banks/*.syx` (4 factory banks), 4 OFL fonts, `Assets.xcassets/AppIcon` | Banks: remove. Fonts OK (add OFL notices). Icon: confirm it is your own |
| `tutorial/` | Static HTML guide (11 pages, `fm1.js`, `style.css`), `images/` (9 third-party photos), `SOURCES.md` | Delete photos; reword and rename |
| `research/` | Specs, audits, `images/` (web-sourced photos, not bundled), upstream-comparison notes | Keep out of any public repo; do not ship |
| `FM1UITests/` | XCUITests: firmware menu, packages, tutorial | Update for renamed strings and removed installer |
| `project.yml` | Bundle id `com.oriol.fm1pocket`, team `37UF89K96Y`, iPad-only, landscape, audio background, Bluetooth string, bundles `Firmwares` and `tutorial` as resources | Rename product and bundle id; add privacy manifest and export key |

Build: `xcodegen generate`, then `xcodebuild -project FM1.xcodeproj -scheme FM1 -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' build`. UI tests run through the `FM1` scheme.

Working-tree state when this was written: `FM1/App/FM1App.swift` modified (not by this evaluation), `research/APP_STORE_EVALUATION.md` new. Nothing was committed. Check `git status` and `git log` before starting; consider branching.

## Work list, in order

### 1. Engine: remove GPL-derived code (blocker B1)
Upstream file licences (M-VAVE `fm1_open`): **GPL-3.0-only**: `adsr.c`, `dx7synth.c`, `dx7math.c`, `fm_library.c`, `screen.c`. **Apache-2.0**: `dx7core.c`, `dx7env.c`, `dx7note.c`, `dx7lfo.c`, `dx7pitchenv.c`.
In `FMEngine.swift`:
- `mkSin` (about line 514) and the sine tables (about line 141): replace with the sine implementation from Google's Apache-2.0 MSFA (`google/music-synthesizer-for-android`).
- ADSR (`adsrNext`, `adsrStepSize`, constants around lines 526–560 and 604–607): replace with your own envelope design; do not reuse `adsr.c` numbers or smoothing coefficients.
- Voice start, mono/legato/glide, velocity scaling, CC routing (around lines 252–330, plus the `dx7synth.c` references): redesign from the DX7 manual's documented behaviour and MSFA, not from `dx7synth.c`.
- Keep the Apache-derived parts but re-source them from MSFA directly, and add attribution (Google; also Pascal Gauthier for `dx7note`-derived code; M-VAVE's modifications are Apache for those files).
- Remove or reword comments that cite the GPL files. Do not read `adsr.c` / `dx7synth.c` / `dx7math.c` again while rewriting.
- Re-run a sound regression against MSFA (method in `research/AUDIT_SOURCE_COMPARISON.md` §1) and accept small differences.

### 2. Remove the installer (blocker B3)
- Delete or flag out "Install from URL…" and "Install from Files…" in `FirmwareMenuView.swift` and `install(from:)`, `install(data:baseURL:)`, `fetch` in `FirmwareCatalog.swift`; remove the `installedRoot` runtime-package loading for the store build.
- Keep bundled packages (scripts shipped in the binary). Update `FirmwareMenuTests`/`FirmwarePackageTests`.
- Update `Firmwares/README.md` and the app README so they do not advertise downloads.

### 3. Remove third-party media (blocker B2)
- Delete `tutorial/images/*.jpg` and the `<img>` references in `tutorial/*.html`; replace with simulator screenshots of the new app.
- Do not commit `research/images/` to a public repo.

### 4. Remove or replace voices (blocker B5)
- Remove `FM1/Resources/Banks/*.syx` and `FM1_V15_factory_bank_*.syx` in `research/` from anything shipped. Update `SynthModel.factoryBank()` and the init/reset paths that load them.
- Ship an original bank (64–128 voices, designed in the app's editor and exported as `.syx`), or a smaller bank plus SysEx import (already implemented).

### 5. Rename and rebrand (blocker B4)
- Choose a name after checking the App Store, EUIPO eSearch plus and USPTO. Avoid FM-1, M-VAVE, DX7, Yamaha. "FM Pocket" is not cleared: run the search.
- Replace strings: "FM-1", "M-VAVE", "Stock V15", "SLOOP", "Felucca", "Melodee", "PROPHET", "CZ-1", "808" in `FM1App.swift`, `SynthModel*.swift`, `Firmware.swift`, `TutorialMode.swift`, `TutorialBrowser.swift`, `FirmwareMenuView.swift`, `VASynth.swift`, `PDSynth.swift`, `DrumKit.swift`, `Theme.swift`, `Firmwares/*/manifest.json` (`name`, `credits`, `license`, `source`), `tutorial/*.html`, README. Rename modes by function ("Classic", "Groove", "Mode A/B/C").
- Redraw the panel (colours, shapes, legends, layout details) rather than matching `research/VISUAL_SPEC.md`. Keep functionality; change the look. New icon of your own.
- Add disclaimer text in the app and listing: independent product; "DX7" and "Yamaha" are trademarks of Yamaha Corporation.

### 6. Store administration
- Add `PrivacyInfo.xcprivacy` (UserDefaults, reason `CA92.1`; no tracking, no collected data). Verify the reason code in Apple's docs.
- Add `ITSAppUsesNonExemptEncryption = NO` to `project.yml` info properties (after the installer is gone, only OS HTTPS remains; confirm).
- Privacy policy page and in-app link (Guideline 5.1.1(i)).
- Acknowledgements screen: the four OFL fonts (Orbitron, Nunito, Share Tech, Aldrich: copyright lines and OFL 1.1 text) and Apache-2.0 notices for MSFA/Google.
- Age rating questionnaire, iPad screenshots, review notes (background audio, SysEx file sharing, Bluetooth MIDI), EU trader (DSA) details.
- Change bundle id and display name; keep `DEVELOPMENT_TEAM` unless it differs.

### 7. Optional: ask M-VAVE first
Email the entity in `fm1_open/LICENSE.md` (珠海笙科智能科技有限公司) for: relicence of the GPL files, confirmation of the banks' origin, descriptive use of "FM-1", photo/manual permission (details in `APP_STORE_EVALUATION.md` §6). A yes lets you skip parts of steps 1, 4 and 5. Do not wait on them; do not ship on silence.

### 8. Before submitting
- Grep the final tree for: `FM-1`, `FM1`, `M-VAVE`, `Stock`, `SLOOP`, `Felucca`, `Melodee`, `Prophet`, `CZ-1`, `808`, `DX7`, `Yamaha` and justify each hit (DX7 only in the disclaimer and format description).
- Grep for `mk_sin`, `adsr.c`, `dx7synth`, `fm1_open` and remove source citations of GPL files.
- Run the UI tests; build on a device; check TestFlight.
- Have a lawyer review the open questions in `APP_STORE_EVALUATION.md` §7.

## Decisions the next session should confirm with the owner
1. Strict clean room (someone else writes a behaviour spec) versus "informed rewrite on MSFA". The report recommends the latter and flags it for a lawyer.
2. App name and visual direction.
3. Whether to also keep a GPL-3.0 open-source build (current app, with installer) outside the store, which would need source publication.
4. Free or paid, and the legal entity (individual in Spain versus company).
