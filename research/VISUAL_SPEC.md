# M-VAVE FM-1 — Visual Spec (for SwiftUI recreation)

Sources: product renders (M-VAVE/AliExpress/Bonedo/china-gadgets/Elektronauts), Synth Anatomy review photos (07/2026), Gearnews colorway shots. All images live in `research/images/`.
Colors were pixel-sampled (5x5 average) from images. Renders are more reliable for body and rubber colors. Photos are more reliable for the actual on-device screen palette, but camera white balance pushes those toward blue.
Confidence: **H** = high, **M** = medium, **L** = low.

Branding note: the rear edge carries the "M-VAVE" wordmark. We will NOT reproduce it. The front panel has no logo at all (H). The box reads "M-VAVE | FM-1".

---

## 1. Body

| Property | Value | Conf |
|---|---|---|
| Size | **161.5 × 96.5 × 28.6 mm**, ~250 g (china-gadgets spec) | H |
| Aspect (top face) | 1.67 : 1 (measured 978×580 px in the clean render = 1.686) | H |
| Corner radius (plan view) | ~5% of width, about 8 mm. Large, soft "phone-like" corners | M |
| Edges | Flat top face, slightly rounded vertical edge, thin chamfer/lip around the top. Matte soft-touch plastic | M |
| Top face texture | Matte, very fine grain. Renders show a subtle vertical gradient, lighter at the top-left | M |
| Bottom | Four round rubber feet, 6 screws, a rectangular label plate in the center, and a **speaker grille** (round, with a radial/spiral "fan" pattern) near the bottom-right corner, seen from below | H |

### Colorways (all share the layout; the rubber keyboard and button pad are a contrasting color)
| Variant | Body | Rubber keys / button pad | Knobs | Legends | Conf |
|---|---|---|---|---|---|
| **Black** (default, "all black") | `#3c3d3d`–`#4d4e4d` (render, lighter top-left `#5a5a5a`) | Pads `#262626`, keyboard well `#363838`, keys `#2b2b2b` | black `#1c1c1c` | silkscreen light gray `#c8c8c8`; key LED stripes white | H |
| **White/cream + blue** | `#eeebe6` cream | slate blue `#4f6f8d`–`#577694` | black | panel labels dark `#2d2926`; button legends white | H |
| **Purple** | lilac `#b88dc8`–`#bc93cd` | violet `#7469ad`–`#776ba6` | black | dark/ white | M |
| **Orange** | bright orange ≈ `#e0662c` (estimated, not sampled) | terracotta `#8b4c40` | black | dark | M |
| **Black + mint** | dark `#37363b` | mint/teal `#65c7b9`–`#6ab2a9` | black | dark | M |
| **Cream + charcoal** | `#d3c8c0` | charcoal `#363a3d` | black | | M |

Accents: on the panel, only the LED-backlit button legends and the key LED stripes. PLAY/STOP lights **red** (`#ff3b30`-ish) while playing.

---

## 2. Front-panel layout (black render `panel_top_black_clean.png`, % of body W/H; origin top-left)

```
 x%: 0    8   18.5  25.7        49.4  53.5 56.8  67.8  79.0  90.1  96.4 100
y%  +--------------------------------------------------------------------+
 7  |  MASTER  SELECT  +-----------+       KNOB1  KNOB2  KNOB3  KNOB4      |
15  |   (O)     (O)    |  ######## |        (O)    (O)    (O)    (O)      |
    |                  |  # TFT  # |                                      |
25  |  PRESETS ALGORITHM  #240x # |    +-----------------------------+    |
27  |                  |  # 240? # |    | [FX][SEL][ENV][LFO][EDIT][GLO] |  34
33  |   (O)     (O)    |  #      # |    |           .                 |    |
    |                  |  ######## |    |[HOME][SAVE][ARP][SEQ][P/S][REC]| 44.5
43  | +--------------+ |           |    +-----------------------------+    |
46  | | [OCT-][OCT+] | +-----------+                                 51   |
50  | +--------------+   (47)                                             |
57  | +----------------------------------------------------------------+ |
    | |  (|)(|)(|)    (|)(|)    (|)(|)(|)    (|)(|)    (|)            | | 66 upper row
    | |  OP1 OP2 OP3  OP4 OP5   OP6 PIT GLO  MONO POLY                 | |
    | | (|)(|)(|)(|).(|)(|)(|)(|).(|)(|)(|)(|).(|)(|)(|).(|)(|)      | | 84 lower row
94  | +----------------------------------------------------------------+ |
100 +--------------------------------------------------------------------+
```

### 2.1 Knobs (8 total = 7 + MASTER volume) — H
- Small knurled black knobs, ~4.3% W (~7 mm) in diameter, with a white dot indicator. Labels sit above, centered, in the silkscreen font.
- Left 2×2 block: **MASTER** (x 8%, y 15%), **SELECT** (18.5%, 15%), **PRESETS** (8%, 33%), **ALGORITHM** (18.5%, 33%). Label baselines at y ≈ 7.5% and 25%.
- Right row: **KNOB1..KNOB4** at x = 56.8 / 67.8 / 79.0 / 90.1%, y 15%. Labels at y ≈ 7.5%.
- They are endless encoders, judging by the UI (values jump with the page). Only MASTER is clearly a pot with a pointer (M).

### 2.2 OCT buttons — H
- One recessed rounded-rect tray at x 5.1–21.1%, y 42.8–50.3%. It holds two rubber buttons, **OCT-** and **OCT+**, each about 6.3% W × 5.9% H, radius ~1.5 mm, with a bold white legend.

### 2.3 Screen — H (position), M (size)
- Black glossy bezel, **square**, at x 25.7–49.4% W and y 6.9–46.9% H (about 38 × 38 mm), corner radius ~13% of its side. Bezel color `#060908`.
- Active area is about 72% of the bezel side (~27 mm square), which suggests a **1.54" 240×240 IPS TFT** (M/L). The active area sits roughly centered, with slightly more bezel at the bottom.

### 2.4 Function button pad — H
- Recessed tray `#363838` (black variant) at x 53.5–96.4%, y 27.2–50.9%, radius ~4 mm.
- 2 rows × 6 square rubber keys, each ~5.3% W (~8.6 mm), radius ~1.5 mm, pitch ~6.2% W.
  - Row 1 (y 34%): **FX, SEL, ENV, LFO, EDIT, GLO**
  - Row 2 (y 44.5%): **HOME, SAVE, ARP, SEQ, PLAY/STOP** (two lines, with a rule between PLAY and STOP), **REC**
  - Column centers x: 57.6, 63.8, 69.9, 76.0, 82.2, 88.3%.
  - A small dot is silkscreened between rows, under ENV/LFO.
- Legends: bold sans, white. They are **LED-backlit**. Off = dim gray (`#5a5a5a` on black). Active page = bright white. Some states glow blue (ENV/ARP seen blue-white in photos). PLAY/STOP glows **red** while running.

### 2.5 Keyboard (27 silicone pads) — H
- Recessed well at x 3.4–96.7% W, y 56.9–94% H, radius ~5 mm, slightly darker than the body.
- Pads are **vertical pills** (stadium shape), raised and soft. Each has a **thin vertical light stripe** in the center: white LED (black variant, `#b7b7b7` when off-but-white) or a darker tone on colored variants. The stripes light (white/cyan) for notes and sequencer steps.
- **Lower row = 16 "white" keys**: pill ~4.9% W × 15.5% H, centers y 83.6%, x from 8.8% to 93.8% at a pitch of 5.67% W.
- **Upper row = 11 "black" keys**: pill ~4.6% W × 13% H, centers y 66.4%. They sit between the white keys in piano layout, in groups of **3-2-3-2-1**.
- Note mapping (derived from geometry, H): **lowest key = F**, highest = G. Whites: F G A B C D E F G A B C D E F G. Blacks: F# G# A# | C# D# | F# G# A# | C# D# | F#. Octave number unknown (L; probably F2/F3 + OCT shift).
- Small silkscreened dots sit at the E–F and B–C gaps on the line between the rows (x ≈ 27.7, 44.5, 67.3, 84.2%).
- Secondary labels printed under the upper pads (inside the bottom of the pill area): **OP1, OP2, OP3 | OP4, OP5 | OP6, PIT, GLO | MONO, POLY | (none)**. In edit mode, labeled pads flash.

### 2.6 Silkscreen fonts
- Panel labels (MASTER, KNOB1…): thin monoline **squarish techno font**, all caps, slightly letter-spaced, with squared "O" and "M". Close matches: *Share Tech Mono*, *Aldrich*, *Orbitron Light*. About 2.2% H cap height. (M)
- Button legends: **bold**, rounded-ish sans, all caps (like *Arial Rounded MT Bold* / *SF Pro Rounded Heavy*). (M)

### 2.7 Rear edge (ports, left→right as seen from behind) — H
"M-VAVE" wordmark on the left (don't reproduce). Then a recessed port bar: **3.5 mm stereo out** (in a square bezel), **3.5 mm TRS MIDI in**, **USB-C**, **power slide switch**, and a tiny **charge LED**. The bar sits behind the MASTER/SELECT side. Bluetooth MIDI is built in.

---

## 3. Screen UI

General style: **smooth anti-aliased UI, not pixel/bitmap.** Rounded rectangles with 1 px darker outlines and a light inner highlight (slightly "skeuo-flat"). Text uses a humanist sans in the Tahoma/Verdana/Ubuntu family; *SF Pro Rounded* or *Nunito* are close.

### 3.1 Common frame (all pages) — H
- **Header** (top ~15% of screen): `NNN NAME  N`, e.g. `001 PIANO  1`, `128 WHAT IF`, `006 STONED DX`. The 3-digit preset number + name, then a trailing small number (probably octave or MIDI channel; L). A **battery icon** sits at the right (rounded rect with 2 fill bars). Header text is dark gray/navy.
- A thin 1 px horizontal divider sits under the header and another above the footer.
- **Footer** (bottom ~13%): a full-width rounded **pill** with the centered page title. Format `p/n Title` for multi-page sections (`1/2 Arpeggio`, `1/2 Sequencer`, `1/6 OP1 Envelope`, `3/6 OP1 Tuning`). Otherwise just the section name (`OSC`, `ENV`, `Globe` [sic]). In FX it shows the focused parameter (`Type: Low Pass`, `Freq:30%`).

### 3.2 Parameter pages (ENV, ARP, SEQ, operator pages, Global) — H
- **2 × 2 grid of tiles = KNOB1..KNOB4** (TL=KNOB1, TR=KNOB2, BL=KNOB3, BR=KNOB4; mapping M).
- Tile: rounded rect (~8% radius), parameter name on top (regular, ~10% screen height), value below in a smaller size (~7%). Some values show a tiny dot to their left (focus/changed marker, L).
- Examples:
  - ENV: Attack / Decay / Sustain / Release (labels only)
  - ARP p1: Up, Octave 1, Rate 1/16, Tempo 120
  - SEQ p1: Pattern 1, Clear, Rate 1/16, Tempo 106
  - OP1 Envelope p1: Rate1 28, Rate2 40, Rate3 32, Rate4 36
  - OP1 Tuning p3: Detune 1, FreqCoarse 3, FreqFine 33, OscMode Ratio
  - Global: Algorithm 9, Feedback 0, Osc Sync ON, Transpose 18
- SELECT knob scrolls the pages (p/n). OP1–OP6 pads choose the operator.

### 3.3 FX page — H
- **3 × 2 grid**: Filter, Reverb, Delay / Distortion ("Distort-ion" wraps onto 2 lines), Chorus, Phaser. A **small red dot** (`#d75f51`) under a tile marks the selected/active effect. The footer shows the focused parameter and its value.

### 3.4 Home / OSC page — H
- Dark background **`#20495f`–`#3b575b`** (dark teal-slate). A thin horizontal **oscilloscope trace** runs across the middle, yellow-green ≈ `#a8c070`, flat when silent. Footer pill reads `OSC`. Header as usual.

### 3.5 Algorithm page — H (style), M (colors)
- Same light background. Top-left: a rounded badge with the algorithm number, zero-padded (`08`).
- Diagram: small rounded-square **operator boxes** (~9% of screen width) with numbers 1–6, cyan fill, dark 1 px outline. They are connected by thin dark vertical/horizontal lines. **Feedback** is drawn as a square bracket loop on the side of the feedback operator. Carriers sit on the bottom row and join into a wider **`OUT`** pill.
- The diagram is centered in the body. A faint horizontal guide line crosses mid-screen. Footer: `OSC`.

### 3.6 Save dialog
- Dark rounded box with the text `32 Voice Save To ...`, plus a row of 4 circular buttons **A B C D** (dark fill, white letters, light ring). Footer `OSC`.

### 3.7 Screen palette
Two sources disagree. Pick (a) for "real device" fidelity.

(a) **Real device (photos, white-balance corrected, M):**
- background: light sky/ice blue `#bfe6f7` (photo raw `#58b8fa`)
- tiles: brighter cyan `#7fdcf5` (raw `#55cdfb`), 1 px outline `#3a7fa0`, inner highlight `#d6f6ff`
- text: dark navy `#1e3446`. Header text `#2a3a48` (faded `#8aa2b0` on the algorithm page)
- algo op boxes: `#78eef5`
- footer pill: same cyan as the tiles

(b) **Marketing renders (H, older firmware look):**
- background: pale gray-blue `#b5d5e1`–`#c4e0ec`
- tiles: steel gray `#93a9b2` with a dark edge `#687678`
- text: `#2a2f35`
- footer pill: `#bfe2e7`
- red dot: `#d75f51`

---

## 4. Image index
| File | Content |
|---|---|
| panel_top_black_clean.png | **Best top-down render**, black, FX page (859×515) |
| panel_top_black_render.jpg | Same render on a space background, 1920×1080 |
| panel_top_black_fx_screen(_2,_3).jpg | Top-down renders, black, FX page |
| panel_top_white_blue.jpg | Top-down, cream/blue, Home/OSC page |
| panel_purple_angle_home_screen.jpg | Purple, 3/4 view, OSC page (`006 STONED DX`) |
| panel_black_angle_home_screen.jpg | Black, rotated, OSC page |
| panel_black_rear_angle.jpg | Rear 3/4: ports, depth, rear wordmark |
| panel_orange_algorithm_screen.jpg | Orange unit in hands, algorithm page |
| colorways_all_promo.jpg, colorways_promo_angle.jpg | All 6 colorways |
| photo_env_page.jpg | Real photo, ENV page, HOME+ENV lit |
| photo_arp_page.jpg | Real photo, Arpeggio page, ARP lit |
| photo_seq_page_keys_lit.jpg | Real photo, Sequencer, PLAY/STOP red, key LEDs lit |
| photo_algorithm_page.jpg | Real photo, algorithm 08 diagram |
| photo_fx_page.jpg | Real photo, FX page, `Freq:30%` |
| photo_screens_op_env_tuning_globe.jpg | Composite of OP Envelope / OP Tuning / Global pages |
| photo_save_dialog_dark.jpg | Save dialog (A/B/C/D) |
| photo_rear_ports.jpg, rear_edge_ports.png, rear_edge_ports_2.jpg | Rear edge / ports |
| bottom_black_speaker.png | Underside with speaker grille |
| photo_unboxing.jpg | Box line-art of the panel + manual |
| aliexpress_listing_screenshot.jpg | Listing (SK15 model code) |
