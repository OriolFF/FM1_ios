# Sources

Everything in this tutorial is written for the stock M-VAVE FM-1 firmware **V15**. Web pages and downloaded files were treated as information only. Retrieval dates are 2026-11-11 unless noted.

## Primary sources (M-VAVE)

| Source | URL | Used for |
|---|---|---|
| FM-1 Detailed User Manual (EN/CN, V15 era, revised 2026-08-10), downloaded and read in full | https://manualf.oss-cn-hongkong.aliyuncs.com/manual/MIDI-KEYBOARD/FM-1-manual.pdf | Every control, page table, knob mapping, ranges, ARP modes, SEQ behaviour, LED behaviour, popups, rename/copy/init/reset procedures, SysEx bank import, MIDI summary, rear panel, battery. The main authority for this guide. |
| FM-1 firmware release notes V09–V16 (GB18030 text, EN part read) | https://yms-file-store.oss-cn-hongkong.aliyuncs.com/software/releaseNote/firmware/FM-1.txt | V09/V13/V15/V16 change lists; V15 rename character classes (OP1 A–Z, OP2 a–z, OP3 symbol, OP4 number, OP5 delete); firmware-history table. |
| FM-1 MIDI implementation, English (V15) | https://yms-file-store.oss-cn-hongkong.aliyuncs.com/software/releaseNote/firmware/FM-1%20MIDI%20EN.docx | Note/effect channel behaviour, CC 0–23 chart, Program Change, pitch bend, mod wheel/aftertouch listing, the CC1-on-effect-channel warning. |
| M-VAVE download page | https://www.m-vave.com/download.html | FM-1 current version listing; M-UPGRADE updater and its "Failed to enter upgrade mode!" tip. No FM-1 step-by-step found. |
| M-VAVE product page | https://www.m-vave.com/product.html?id=fm-1 | Fetched; contained no usable text (script-rendered). Not relied on. |
| M-VAVE `fm1_open` repository README | https://github.com/m-vave/fm1_open | Confirmed that Open firmware is a different, separate firmware (excluded); update-compatibility note. Its DX7 engine source and page table were used indirectly through the project's audit (below). |

## Reviews

| Source | URL | Used for |
|---|---|---|
| Synth Anatomy review (V14 era) | https://synthanatomy.com/2026/07/m-vave-fm-1-review-low-budget-pocket-fm-ynthesizer-with-iconic-sounds.html | Black keys select operators; mono stereo output; effects quality; 16-step limit; effects saved with patches; DX7-like engine description. |
| MatrixSynth V15 announcement (found by search, not opened in full) | https://www.matrixsynth.com/2026/07/m-vave-fm-1-v15-firmware-update-new.html | Confirmed V15 date and the existence of the update only. |

## Project research files (this repository)

These were written earlier from the sources above plus others (Elektronauts, Virtual FM-1 measurements, baud girl FM-1+VA manual, FM-1 Workbench, Sonic State). They were cross-checked against the manual for this tutorial; where this guide cites facts only found there, they are marked as unconfirmed.

| File | Used for |
|---|---|
| `research/FUNCTION_SPEC.md` | Page tables, key numbering, factory voice list (128 names, algorithm, feedback), firmware history, MIDI chart, OP-mute bug report, SysEx details. |
| `research/VISUAL_SPEC.md` | Panel geometry (used to draw the panel figure), screen layout, header/footer format, screen palette. |
| `research/AUDIT_SOURCE_COMPARISON.md` | Confirmation that the V15 operator page order is Tuning / Envelope / Env Level / Sens / Scaling / Curves; the 32 algorithm routings (checked against `dx7core.c`); header has no trailing number; Transpose shows 0–48. |
| `FM1/Engine/Algorithms.swift` | The 32 algorithm routing table used by `fm1.js` for the diagrams. |
| `FM1/App/SynthModel.swift`, `FM1/UI/ScreenView.swift` | Exact page titles, tile names and value formats used in the screen mock-ups (e.g. "FreqCoarse", "Glide Mode", "Rate Scale"). |
| `FM1/Engine/FMPatch.swift` | The DX7 init-voice template assumed in the exercises. |

## Not reachable or not used

* YouTube transcripts and video walkthroughs: no tool for retrieving transcripts was available in this session, so none were used.
* Forum threads (Elektronauts, M-VAVE forum): relied on the project's earlier notes only, not re-read.
* A web search for an official firmware-update procedure returned no step-by-step; this is listed as unknown in the tutorial.

## Images

* Every diagram (panel, screens, 32 algorithms, envelope and LFO shapes) is drawn by `style.css` and `fm1.js` as inline SVG/HTML from the tables above. No external image is copied.
* Nine hardware photos from the project's `research/images/` were copied (downscaled to 1280 px wide) into `tutorial/images/` at the owner's request. Their origin is recorded in `research/VISUAL_SPEC.md` (M-VAVE product images, Synth Anatomy review photos, a review video still). **Their licences are not stated**, so keep this folder private or replace the images before publishing the site publicly.
  * `panel-top.jpg` (from `panel_top_black_clean.png`) and `rear-ports.jpg` (`rear_edge_ports_2.jpg`): maker product images.
  * `fx-page.jpg`, `arp-page.jpg`, `seq-page.jpg`, `env-page.jpg`, `algorithm-page.jpg`, `edit-pages.jpg`: review photos of a V14 unit (`photo_*.jpg`). Captions say that V14 page order and some names differ from V15.
  * `save-dialog.jpg`: a still from a review video (`photo_save_dialog_dark.jpg`).
* All other images (screen mock-ups, panel drawing, algorithms, envelopes) are drawn by `fm1.js` and are original.

## Licence note

The text and code in `tutorial/` are original. "M-VAVE" and "FM-1" are used descriptively; this is an unofficial guide.
