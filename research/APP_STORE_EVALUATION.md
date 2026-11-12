# App Store evaluation: can FM Pocket be published, and what would a compliant variation be?

Date: 2026-11-11. Scope: the working tree at `/Users/oriol/Documents/development/fm1` (branch `main`, with uncommitted work by other agents; nothing was modified except this file).

**This is not legal advice.** It is an engineering reading of licence texts, Apple's published rules and the project. Items marked **[V]** were checked against a primary source fetched during this evaluation. Items marked **[I]** are my interpretation. Items marked **[L]** need a lawyer or an answer from M-VAVE. Confidence is given per issue.

---

## 1. Verdict

**Publishable as-is: NO.** There are four independent blockers, any one of which is enough:

1. GPL-3.0-only code from M-VAVE is ported into the engine (cannot be distributed under Apple's terms).
2. Unlicensed third-party photographs are bundled inside the app (`tutorial/images/`).
3. The firmware installer downloads and runs scripts that change app behaviour (Guideline 2.5.2 / DPLA 3.3.1(B)).
4. The app presents itself as M-VAVE's FM-1: product name, trade dress, "Stock V15" emulation, factory banks of unclear provenance (Guidelines 4.1(c), 5.2.1).

**Only with changes: YES.** All four are fixable, none requires M-VAVE's cooperation (though their cooperation would shorten the work, see §6). A compliant variation is a generic, original-branded 6-operator FM groovebox built on the Apache-2.0 MSFA engine, with an original voice bank plus SysEx import, bundled (not downloadable) firmware modes, and its own panel art. Rough effort: **3–5 weeks of solo work**, plus a few hours of lawyer time (§7).

---

## 2. Blockers, most severe first

### B1. GPL-3.0-only code in the engine — BLOCKER (confidence: high on the facts, medium-high on the legal conclusion)

**What triggers it.**
- `FM1/Engine/FMEngine.swift` states it is a port of M-VAVE's `fm1_open` (header lines 1–12) and cites the source files per function. `research/AUDIT_SOURCE_COMPARISON.md` §2 (S1–S9) and §1 say the fixes were made by reading M-VAVE's C and porting it. That is a derivative work by the owner's own record.
- Upstream licensing, read from the repo at HEAD (`LICENSE.md`, `THIRD_PARTY.md`, SPDX headers) **[V]**:
  - `LICENSE.md`: "Company-owned APP sources are licensed under GNU GPL version 3 only", with an additional permission (§7) that covers only **linking with M-VAVE's binary FM1 SDK**. It grants nothing for other linking or for other distribution channels.
  - Per-file headers: **GPL-3.0-only WITH GPL-3.0-linking-exception**: `web/synth/adsr.c`, `dx7synth.c`, `dx7math.c` (contains `mk_sin` and the sine tables), `app/fm_library.c`, `app/screen.c`.
  - **Apache-2.0** (Copyright Google 2012/2013, and for `dx7note.c` also Pascal Gauthier 2016–2025; "Modified for FM1 by M-VAVE, 2026"): `dx7core.c`, `dx7env.c`, `dx7note.c`, `dx7lfo.c`, `dx7pitchenv.c`. `THIRD_PARTY.md` names the origin as MSFA and Dexed's `msfa` folder.
- Which Swift code derives from which licence **[I]**, from the comments in the Swift file:

| Swift code | Derived from | Licence |
|---|---|---|
| `FMEngine.mkSin` (about line 514) and the log-sine/exp tables (line 141) | `dx7math.c` `mk_sin` | **GPL** (note: tables are regenerated from a formula, which weakens but does not remove the derivation) |
| `adsrNext`, `adsrStepSize`, ADSR constants (lines 526–560, 604–607) | `adsr.c` | **GPL** |
| `startVoice`, mono hand-over/glide, velocity scaling `(vel*100)>>7`, CC routing (lines ~252–330) | `dx7synth.c` | **GPL** |
| Operator kernel, flags, feedback chains (line ~722) | `dx7core.c` | Apache |
| Envelopes, pitch EG, LFO, note scaling (lines ~190–250, 417, 635–665) | `dx7env.c`, `dx7pitchenv.c`, `dx7lfo.c`, `dx7note.c` | Apache |
| Page order, labels | `app/screen.c` | GPL, but facts/ordering of a UI are weak expression **[I]** |

**Which rule.** GPL-3.0 §10 last paragraph ("You may not impose any further restrictions on the exercise of the rights granted") and §6 (corresponding source plus no restrictions) **[V, text of LICENSE.md includes full GPLv3]**. Apple's App Store terms add usage restrictions and DRM (FairPlay), which the FSF and VideoLAN treated as incompatible. Precedent **[V via search, not primary documents]**: GNU Go for iPhone was pulled in May 2010 after an FSF complaint ([LWN](https://lwn.net/Articles/391423), [The Register](https://www.theregister.com/2010/05/27/gnu_go_fsf_apple_itunes/)); VLC for iOS was removed in January 2011 after a VideoLAN developer's complaint ([TechSpot](https://www.techspot.com/news/41908-apple-removes-vlc-app-from-app-store-gpl-to-blame.html)). Both were GPLv2; GPLv3 is at least as strict. Later GPL apps exist on the store only because the copyright holders themselves granted a separate permission **[I]**. For Dexed, forum commenters say an iOS release would need a separate non-GPL licence from the author ([Loopy Pro thread](https://forum.loopypro.com/discussion/comment/1468569/)); that is opinion, not a ruling.

**Does the linking exception help?** No. It is limited to M-VAVE's SDK library (`libfm1_engine.a`). `LICENSE.md` also says: "the linking exception does not supply that permission".

**What fixes it.** Either (a) remove every GPL-derived piece and rebuild it from the Apache sources, or (b) get M-VAVE to grant a written exception/relicence for those files (§6). Option (a) is concrete: take the Apache MSFA engine ([google/music-synthesizer-for-android](https://github.com/google/music-synthesizer-for-android), the same upstream M-VAVE adapted) and use its `sin` implementation in place of `mkSin`; write an ADSR and mono/legato logic from your own spec of the *behaviour* (user-visible parameters), not from `adsr.c`/`dx7synth.c`. Caveat **[I]**: because the owner has read the GPL C, this is not a strict clean room. The lower-risk framing is "replace with a different, independently designed implementation and different numbers", accepting small differences from the hardware sound. A truly clean room would need someone else to write the spec. **[L]** whether a different-but-informed rewrite is enough.

Note on copyright holders: the repo's `THIRD_PARTY.md` credits a third-party contributor (Vikram Rojo, PR #2) for "APP / open web engine tuning". M-VAVE may not own all GPL code outright, which limits how far a relicence from M-VAVE alone goes **[L]**.

### B2. Third-party photographs bundled in the app — BLOCKER (confidence: high)

**What triggers it.** `project.yml` bundles the whole `tutorial/` folder as app resources, including `tutorial/images/*.jpg` (nine hardware photos). `tutorial/SOURCES.md` (section "Images") says they come from M-VAVE product images, Synth Anatomy review photos and a review-video still, and that "Their licences are not stated, so keep this folder private or replace the images before publishing". `research/VISUAL_SPEC.md` line 3 lists M-VAVE, AliExpress, Bonedo, china-gadgets, Elektronauts and Gearnews as sources. `research/images/` is not bundled in the app, but is in the repo and would be a problem if the repo is made public.

**Rule.** Copyright in photographs; Guideline 5.2.1 "Don't use protected third-party material such as trademarks, copyrighted works... without permission" **[V]**.

**Fix.** Delete the nine images from the shipping bundle (or take your own photos of your own unit; photos of your own device are yours, though the product's appearance may still be protected, see B4). Replace with in-app screenshots. Effort: 1–2 days.

### B3. Firmware installer that downloads and runs code — BLOCKER for the installer, not for the firmware modes (confidence: medium-high)

**What triggers it.** `FM1/FirmwareHost/FirmwareCatalog.swift` (`install(from:)`, `fetch`): accepts any https/http/file/data URL, writes the JSON/JS package to disk with no signature or allowlist, and `FM1/FirmwareHost/Script/PackageHost.swift` runs it in JavaScriptCore. The packages define screens, key mappings, sequencer behaviour and sound (`Firmwares/README.md`, `research/FIRMWARES.md`). The README advertises "install more firmwares without rebuilding the app".

**Rules (quoted from the pages fetched today) [V].**
- App Review Guideline 2.5.2: apps "may not... download, install, or execute code which introduces or changes features or functionality of the app". The exception is limited to educational apps that make "the source code ... completely viewable and editable by the user".
- DPLA §3.3.1(B) "Executable Code" (Apple Developer Program License Agreement, [current text](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)): interpreted code may be downloaded only if it "(a) does not change the primary purpose of the Application by providing features or functionality that are inconsistent with the intended and advertised purpose... (b) does not bypass signing, sandbox, or other security features...; (c)... does not create a store or storefront".
- Guideline 4.7 permits "HTML5 and JavaScript mini apps ... and plug-ins" not embedded in the binary, but subject to 4.7.1–4.7.5: a filtering and reporting mechanism, an index of all software with universal links, age-restriction handling, and no exposure of native APIs without Apple's permission.

**Reading [I].** A groovebox firmware that rewrites the whole control scheme arguably changes the app's functionality (2.5.2) and the "primary purpose" test is arguable, since one could say the purpose is "firmware-switchable synth". The 4.7 route would force an index, reporting and age mechanisms that this app does not have. Expect rejection or a long review. **[L]** is optional here; practically, avoid the question.

**Fix.** In the store build, remove "Install from URL…" and "Install from Files…" (`FirmwareMenuView.swift`, `FirmwareCatalog.install*`). Keep bundled firmware packages: scripts shipped inside the binary are reviewed with the app, and are not downloaded (2.5.2 concerns code that is downloaded or installed). Effort: about half a day, behind a build flag. Keep the installer in a non-store (GPL/side-loaded) build if desired.

### B4. FM-1 identity, trade dress and names — BLOCKER as shipped, easy to fix (confidence: medium on the law, high on the review risk)

**What triggers it.**
- Names in the UI and help: "FM-1 Stock V15", "FM-1 Tutorial (web guide)", "M-VAVE" (`FM1/App/FM1App.swift:189, 243`, `FM1/FirmwareHost/Firmware.swift:106–116`, `FM1/UI/TutorialMode.swift`, `FM1/UI/TutorialBrowser.swift`, `FM1/App/SynthModel.swift`), plus README ("recreates the M-VAVE FM-1... the panel look"). Target is stated as "the front panel" at the pixel level: `research/VISUAL_SPEC.md` samples the real colours and geometry of the product from product renders; six colourways replicate the product's.
- Names of other people's firmwares used as menu items: SLOOP, Felucca, Melodee (`Firmwares/*/manifest.json`, `Firmware.swift`), and engine labels "PROPHET" and "CZ-1" (`FM1/FirmwareHost/Audio/VASynth.swift`, `PDSynth.swift`, `research/FIRMWARES.md`), "808" for the drum kit.

**Rules.**
- Guideline 4.1(c): "You cannot use another developer's icon, brand, or product name in your app's icon or name, without approval" **[V]**. 4.1(a)/(b) copycat/impersonation **[V]**. 5.2.1: don't use "trademarks, copyrighted works... without permission"; "Apps should be submitted by the person or legal entity that owns or has licensed the intellectual property" **[V]**.
- Law **[I]**: descriptive/nominative use of a competitor's product name to say what you are compatible with is generally permitted (US: nominative fair use; EU: Directive (EU) 2015/2436 art. 14 and Regulation (EU) 2017/1001 art. 14, "indicate the intended purpose... provided it is in accordance with honest practices"), but a product that *is* a visual and behavioural replica of the hardware, named after it and sold in the store, goes beyond "indicating compatibility". Appearance may be protected as a registered design, and in the EU also as an *unregistered Community design* for 3 years after first disclosure, which would still be live for a 2026 product. I did **not** verify any registration (see "not verified" below). **[L]**.
- Third-party firmware names: using SLOOP, Felucca, Melodee as menu names implies the original authors' products. Reimplementing behaviour from a README is generally not copyright infringement (EU: functionality is not protected, [CJEU C‑406/10 SAS Institute](https://curia.europa.eu/juris/liste.jsf?num=C-406/10); US: 17 U.S.C. §102(b), Google v. Oracle 2021) **[I, from memory, not re-fetched]**, but the names and the "after SLOOP 2.8 by isod89" framing are brand use. "Prophet" (Sequential) and "CZ" (Casio) and "808" (Roland) are third-party marks.

**Fix.** Rename and re-skin (§5): product name that does not contain FM-1/M-VAVE; a neutral label in the "Compatibility" line of the description if needed ("MIDI/SysEx compatible with DX7-format voice banks") plus the standard "not affiliated" disclaimer used by other apps, e.g. M2DX's listing says DX7 and Yamaha are trademarks of Yamaha and that the app is independent ([App Store listing, via search result](https://apps.apple.com/app/id6763840208)). Rename firmware modes by function ("Groovebox A/B/C"), drop "PROPHET/CZ-1/808" labels, keep credits for the *ideas* only if the authors agree.

### B5. Factory voices — HIGH RISK, unresolved provenance (confidence: low, I could not establish the origin)

**What triggers it.** `FM1/Resources/Banks/FM1_V15_factory_bank_{A,B,C,D}.syx` (4×32 voices). `research/AUDIT_SOURCE_COMPARISON.md` §1 says the VMEM hash equals M-VAVE's. `THIRD_PARTY.md` states the bank is "extracted without parameter or ordering changes from the bundled M-VAVE V15 recovery image (Apache-2.0)", and the repo README calls them "the M-VAVE FM1 original V15 factory voices".
Names (read from the files): A–C are generic category names (PIANO 1…8, ORGAN, SYN LEAD, GUITAR, BASS, BRASS, STRING, VOICE…), plausibly M-VAVE's own. **Bank D reads like a classic third-party DX7 cartridge** (BOWOAN, BDWHOCARES, TORIMTORA2, MONO M/Z, TUB BELLS, WHAT IF, SAW EM UP, GAMALONG, TIMBALI…). I cannot prove who made them.

**Reading [I].** M-VAVE's Apache grant covers what M-VAVE can license. If bank D is Yamaha or an independent sound designer's work, M-VAVE's grant does not cover it. Individual DX7 voice data is a set of parameters; whether it is copyrightable, and by whom, is unsettled. Practically, Yamaha's ROM patches have circulated freely for 40 years and are shipped in several apps, but "everyone does it" is not a licence. **[L]** and ideally a written answer from M-VAVE on A–D.

**Fix.** Ship an original bank (§5), or ship A–C only after M-VAVE confirms, and always offer SysEx import so users bring their own banks (already implemented: `FMPatch.swift`, `SynthModel.swift`). Drop D from the bundle.

---

## 3. Other issues, in order

| # | Issue | Evidence in project | Rule | Severity / confidence | Fix |
|---|---|---|---|---|---|
| O1 | **No privacy manifest.** App uses `UserDefaults` (`SynthModel.swift:130,131,489`), a "required reason" API | no `PrivacyInfo.xcprivacy` found anywhere in the tree | Apple requires a privacy manifest declaring required-reason API use, enforced at upload since 2024 **[I, from memory of Apple's docs; not re-fetched. Check "Describing use of required reason API" on developer.apple.com]** | Medium; certain it is missing, fairly sure it is enforced | Add the file with `NSPrivacyAccessedAPICategoryUserDefaults` / reason `CA92.1`, no tracking, no collected data. 1 hour |
| O2 | **Export compliance key missing** | `FM1/App/Info.plist` has no `ITSAppUsesNonExemptEncryption`. App uses HTTPS only (URLSession) | App Store Connect asks on each build | Low | Add `ITSAppUsesNonExemptEncryption = NO` if the installer is removed (only standard OS HTTPS) **[I]**; Spain/EU: no extra filing for exempt use |
| O3 | **Privacy policy URL** | none | Guideline 5.1.1(i) "All apps must include a link to their privacy policy... within the app" **[V]** | Medium | A one-page policy stating no data is collected; link in app and Connect. Nutrition label: "Data not collected" |
| O4 | **Bluetooth string** | `NSBluetoothAlwaysUsageDescription` = "Connect Bluetooth MIDI keyboards and controllers." | Fine and specific | OK | None |
| O5 | **Font licences** | Orbitron, Nunito, Share Tech, Aldrich | All four are **SIL OFL 1.1** per the [google/fonts repository](https://github.com/google/fonts) METADATA/OFL.txt **[V]**. OFL allows bundling in commercial apps; requires keeping the copyright notice and the licence with the fonts; fonts may not be sold on their own; do not use the Reserved Font Names for modified versions | Low | Add an Acknowledgements screen with the four copyright lines and OFL text. The project has none |
| O6 | **Apache-2.0 attribution** for MSFA / Dexed / M-VAVE-modified files | none in app | Apache-2.0 §4: ship the licence and NOTICE, mark changes **[V from THIRD_PARTY.md]** | Low | Same Acknowledgements screen |
| O7 | **App icon** | `AppIcon.appiconset/icon.png` 1024 px; origin not documented | 5.2.1 | Unknown, I did not inspect it visually | Confirm it is your own artwork and does not show the FM-1 or M-VAVE logo |
| O8 | **Tutorial text** | `tutorial/*.html`; `SOURCES.md` says text is original but built from the manufacturer's manual (EN/CN), release notes and a MIDI document | Copyright in the manual's expression; facts (page tables, MIDI CC numbers) are not protected **[I]** | Low-medium | Keep it in your own words, rewrite for the renamed product, and don't cite the manual by link inside the shipped app. Tutorial pages also say "FM-1" throughout (B4) |
| O9 | **Stock firmware image analysis** | `AUDIT_SOURCE_COMPARISON.md` §5.10 notes `FM-1_015.fwsc` was "scrambled" and read for strings | The image is Apache-2.0 per `THIRD_PARTY.md` **[V]**, so reading it is unproblematic. Do not reproduce its strings or assets in the app | Low | None, just don't decompile and copy |
| O10 | **Minimum functionality / review basics** | A real instrument with MIDI, audio, tutorial | Guideline 4.2 **[V]** | Not a problem | Provide demo notes for review, with a short video of the hardware-free workflow |
| O11 | **iPad-only, landscape only** | `TARGETED_DEVICE_FAMILY: "2"`, landscape orientations, `UIRequiresFullScreen` | Allowed. iPad apps must support the orientations declared; make sure screenshots are iPad sizes | OK | None |
| O12 | **Background audio** | `UIBackgroundModes: audio` | Allowed for audio apps; reviewers check it is used | OK | Mention in review notes |
| O13 | **File sharing** | `UIFileSharingEnabled = true` | Allowed | OK | State in notes: SysEx import/export |
| O14 | **Age rating** | none | New age-rating questionnaire in App Store Connect | Low | Expect 4+ |
| O15 | **EU trader status (DSA)** | Owner in Spain | For EU distribution Apple requires trader contact details (name, address, phone, email) shown on the product page for paid/commercial developers **[I, from memory; verify in App Store Connect]** | Low, but personal | Use a business address or P.O. box; consider registering as autónomo or a company |

---

## 4. EU versus US, and the DMA alternative

| Topic | US | EU / Spain |
|---|---|---|
| Software functionality copyright | Idea/expression (17 U.S.C. §102(b)); Google v. Oracle (2021) on API reuse **[I]** | Functionality, programming language and data file formats not protected (CJEU C‑406/10); Software Directive 2009/24 art. 5–6 on decompiling for interoperability **[I]** |
| Trademarks | Nominative fair use for compatibility statements | Art. 14 EUTMR "honest practices" and "intended purpose" **[I]** |
| Product appearance | Trade dress needs non-functional distinctive features; design patents | Registered Community designs plus 3-year unregistered Community design right. This is the area where EU law is *more* protective of the panel look than US law **[I, L]** |
| Distribution | App Store only (plus TestFlight / enterprise, not suitable) | App Store, or **alternative marketplaces and web distribution** under the Digital Markets Act (iOS 17.4 onwards) **[I]** |

**Does DMA alternative distribution change the IP problems?** [I] Only partly:
- It does remove Apple's *review* (Guidelines 2.5.2, 4.1) as a gate, replaced by notarization (integrity checks). So the installer and the FM-1 naming would not be refused by Apple.
- It does **not** change GPL, trademarks, designs or photo copyright: those are rights of third parties and apply whatever the channel. Shipping GPL code outside the Apple store is legal *if you comply with the GPL* (offer source under GPLv3, no extra restrictions), which is also possible via your own site or AltStore-style marketplaces. Apple's fee terms for alternative distribution (the Core Technology fee/commission) have changed several times; verify current terms before relying on this.
- Reach is much smaller (EU users only, extra install friction).

So: DMA channel is a viable way to ship the **current** app as open-source GPLv3 software, free or paid, if the remaining problems (photos, names, banks) are fixed. It is not a way to keep it closed source.

---

## 5. The compliant variation

Goal: the same instrument, no one else's code, name, look or content.

**Keep as-is (your own work, or Apache with attribution)**
- All UI code (SwiftUI), `FMPatch.swift` (DX7 VMEM/SysEx format, a public de-facto format), `Algorithms.swift` (32 DX7 algorithms, publicly documented), arpeggiator, sequencer, FX chain, `DrumKit`, `GrooveSeq`, VA/PD synths in `FirmwareHost/Audio` (original code per `FIRMWARES.md`), MIDI handling.
- Apache-derived engine parts: operator kernel, operator envelopes, pitch EG, LFO, note scaling. Better: re-base them on the Google MSFA source directly (Apache-2.0) and carry the licence and NOTICE.

**Rewrite (GPL-derived)**
- `mkSin` + sine tables: use MSFA's `sin` implementation (Apache). 0.5–1 day.
- Global ADSR: your own curves and times; no copy of `adsr.c` constants and smoothing coefficients. 0.5 day.
- Voice allocation, mono/legato/glide, velocity mapping, CC routing: design from the DX7 manual's documented behaviour and MSFA, not from `dx7synth.c`. 1–2 days.
- Re-run the audit procedure against the Apache MSFA reference rather than against M-VAVE's tree (`AUDIT_SOURCE_COMPARISON.md` method); expect tiny level/feel changes. 1–2 days.
- Delete or rewrite `AUDIT_SOURCE_COMPARISON.md` references that tie the code to GPL files if the repo goes public.

**Remove from the store build**
- Install from URL / Files and the unsigned package runtime exposure (B3). Bundled packages remain.
- `tutorial/images/*` photos (B2). Bank D, and A–C unless M-VAVE confirms (B5).
- Names SLOOP, Felucca, Melodee, PROPHET, CZ-1, 808, Stock V15, FM-1, M-VAVE (B4). Credits to the original community authors can stay in a "Thanks" line only if they agree.

**Name and look**
- Name: something that does not contain "FM-1", "M-VAVE", "DX7", "Yamaha" (e.g. a made-up word plus "FM"). Check the App Store, the EUIPO register ([eSearch plus](https://euipo.europa.eu/eSearch/)) and USPTO ([Trademark Search](https://tmsearch.uspto.gov)) before choosing. I could not query these registers from this environment (they are script-driven), so **the trademark register status of "FM-1", "FM Pocket" and "M-VAVE" is not verified.**
- Look: keep the idea (a keyboard, knobs, a small screen) but draw your own layout, palette and typography; don't match the product's colourways, button shapes or legends one to one. A mock-up of a pocket synth is not infringing; a pixel match is the risk. Reference the standard disclaimer: "DX7 is a trademark of Yamaha; this app is independent".
- Firmware modes become built-in "Modes" with your own names.

**Voices**
- Write 64–128 original voices (start from the INIT voice, use the existing editor; a few days of sound design). Or make a smaller bank (32) and rely on SysEx import for the rest.
- Keep SysEx import/export. State in the description that users supply their own banks.

**Store administration**: privacy manifest, privacy policy URL, `ITSAppUsesNonExemptEncryption`, acknowledgements screen, age rating, DSA trader details, iPad screenshots, review notes.

### Effort estimate (one developer who knows the code)

| Work | Days |
|---|---|
| Engine rebase on MSFA, ADSR/mono rewrite, re-audit | 4–6 |
| Original voice bank (64–128 voices) | 3–6 |
| Remove installer (flag), rename firmware modes, strip third-party names | 1–2 |
| Replace tutorial photos with screenshots, reword tutorial, rename | 2–3 |
| New panel art/branding, icon | 5–10 |
| Admin: manifest, policy, acknowledgements, metadata, screenshots, DSA | 2–3 |
| Lawyer review (outside time) | 0.5 day of the lawyer |
| **Total** | **about 17–30 working days (3–5 weeks)** |

If M-VAVE grants the permissions in §6, the engine rewrite (4–6 days) and bank (3–6) can drop out, and the panel redesign shrinks.

---

## 6. Asking M-VAVE: is it realistic?

**Realistic: possibly.** M-VAVE has published its source on GitHub (`LICENSE.md` lists the company as copyright holder), openly supports third-party firmware (README: "migrating from compatible third-party firmware") and states that "Product names identify compatible formats; no upstream endorsement is implied." That reads as a company comfortable with a community. The weaker point: a paid app that imitates their $100 hardware could be seen as competition or as unauthorised branding. I have no evidence of their policy. **[L / ask M-VAVE]**

What to ask for, in writing (email is enough to start, a signed letter for the store):
1. **A relicence or exception** for `adsr.c`, `dx7synth.c`, `dx7math.c` (and any other GPL file used) allowing distribution in a closed-source app on the Apple App Store, under Apache-2.0 or a commercial licence. They hold the copyright as the declared owner, except contributor-owned parts (PR #2 author) **[L]**.
2. **Written confirmation about banks A–D**: who created them, and permission to ship them (and a statement that third-party content is excluded).
3. **Permission to use the names "FM-1" and "M-VAVE" descriptively** (e.g. "emulates the FM-1 interface", "not affiliated"), and whether they object to a visual homage of the panel.
4. **Permission to use their official photos and manual text**, or a pack of press images.
5. Optionally a **partnership**: they might list or endorse the app, which would also solve 4.1(c) ("without approval from the developer").

Do **not** ship before getting the answers; silence is not permission. Get the grant from the legal entity named in `LICENSE.md` (珠海笙科智能科技有限公司), ideally in English and Chinese.

---

## 7. Open questions

For a lawyer (Spain/EU, possibly US):
1. Is a rewrite by someone who has read the GPL C source safe if it is based on the Apache MSFA instead? Where is the line between replacing and deriving for `mkSin`, ADSR and voice handling?
2. Are the DX7-format voice banks (esp. bank D) copyrightable, and does M-VAVE's Apache label cover them?
3. Is the FM-1 panel appearance protected by a registered or unregistered Community design, and what level of change is safe?
4. Wording of nominative/compatibility references to FM-1 and DX7 for the listing.
5. Whether to publish the app as GPLv3 outside the store (DMA or GitHub) as an alternative.
6. Consumer-law and tax set-up as an individual developer in Spain (DSA trader data, VAT, autónomo).

For M-VAVE: items 1–5 of §6.

**Not verified in this evaluation:**
- Trademark and design registers (EUIPO, USPTO, WIPO) for FM-1, M-VAVE, FM Pocket.
- Whether Apple's current privacy-manifest rule and the DSA trader requirement read exactly as I describe (from memory).
- The licences of the community firmwares were taken from `research/FIRMWARES.md` (a survey made earlier in this project), not re-read from their repos. The report relies on the claim that *no code was copied* from them; I did not diff the packages against their originals.
- I did not run a similarity check between the Swift code and the C sources beyond comparing function names and comments.
- Dexed's and any DX7 app's current App Store status beyond the search results cited.

---

## 8. Sources fetched or consulted

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): 2.5.2, 4.1, 4.2, 4.7, 5.1.1, 5.2.1 quoted from the live page, 2026-11-11.
- [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/): section 3.3.1(B) "Executable Code".
- [m-vave/fm1_open](https://github.com/m-vave/fm1_open): `LICENSE.md`, `THIRD_PARTY.md`, README, SPDX headers of `web/synth/*.c`, `app/*.c`, fetched via raw.githubusercontent.com at HEAD (repo `pushed_at` 2026-10-21).
- [google/fonts](https://github.com/google/fonts): `ofl/orbitron`, `ofl/nunito`, `ofl/sharetech`, `ofl/aldrich` METADATA and OFL.txt.
- Precedent searches: [LWN on GNU Go](https://lwn.net/Articles/391423), [The Register](https://www.theregister.com/2010/05/27/gnu_go_fsf_apple_itunes/), [TechSpot on VLC](https://www.techspot.com/news/41908-apple-removes-vlc-app-from-app-store-gpl-to-blame.html), [Synthtopia on Dexed iOS](https://www.synthtopia.com/content/2019/07/29/dexed-ios-fm-synthesizer-updated-with-640000-unique-patches/), the [M2DX App Store listing](https://apps.apple.com/app/id6763840208) (an FM app built on the Apache msfa engine with a Yamaha disclaimer). Search snippets only; the primary pages of the 2010–2011 cases were not read.

---

## 9. Similar apps already in the App Store (market and precedent)

Found by web search on 2026-11-11 (search snippets and listing pages; I did not install or test them, and did not find an M-VAVE FM-1 emulator or an App Store app that copies a hardware product's name and panel):

| App | What it is | Relevance |
|---|---|---|
| [KQ Dixie / KQ Dixie 26](https://apps.apple.com/us/app/kq-dixie-26/id6753167428) ([older listing](https://apps.apple.com/us/app/kq-dixie/id1330269027), [Synth Anatomy](https://synthanatomy.com/2018/01/kq-dixie-new-6-operator-fm-synthesizer-ios-dx7-patch-compatibility.html)) | Paid 6-op FM synth, 32 algorithms, DX7 SysEx/.syx bank import, Volca FM connectivity; also AUv3 and macOS | Closest precedent for the compliant variation: DX7 compatibility is advertised via the format, with its own name and UI. About $9 per the current listing. |
| [M2DX](https://apps.apple.com/us/app/m2dx/id6763840208) | 6-op, 32-algorithm FM synth; engine is a bit-exact port of Dexed/msfa (Apache-2.0); imports DX7 `.syx` banks; listing disclaims Yamaha affiliation | Direct precedent for the MSFA-based engine route in §5, and for the trademark disclaimer wording. |
| [Drambo](https://apps.apple.com/app/id1469365718), [Groove Rider 2](https://apps.apple.com/us/app/id6480135731), [Groove Rider GR-16](https://apps.apple.com/us/app/1318750537) | Modular/groovebox apps with p-lock style sequencing | Competition for the Groove firmware mode; no hardware clone branding. |
| [Korg Electribe Wave](https://www.pressreader.com/australia/computer-music/20181228/281569471827779) | Manufacturer's own groovebox app | Shows hardware makers publishing their own app; a reason M-VAVE might say yes or no. |
| [Groovebox – Beat Synth Studio](https://apps.apple.com/app/id1242847278) (Novation/Focusrite) | Free + IAP groovebox | Competition. |
| Pepp (free iPad synth with FM), Korg Gadget, Ampify Groovebox | Mentioned in roundups | Competition. |

Takeaways:
- The store already hosts DX7-compatible FM synths with their own names (KQ Dixie, M2DX), so the **category is acceptable**; what differs for FM Pocket is the hardware-clone naming and look, the GPL-derived code and the installer.
- Not found in these searches (not evidence they do not exist): the Yamaha Reface/Montage apps, Bleass, FM Player, iFM, "King of FM" listing details. A listing-by-listing check of competitors' licences was not done.
- Dexed itself does not appear as an App Store listing in these results; community discussion says a store release would need a non-GPL licence from the author ([Loopy Pro thread](https://forum.loopypro.com/discussion/comment/1468569/)). The GPL cases on the store that I could name were not found.
