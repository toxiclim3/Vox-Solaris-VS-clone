# Attribution & Licensing Compliance

This document outlines the licensing framework, third-party asset attributions, and legal compliance guidelines for **Inritus** (SurvivorsClone).

---

## 1. Project License

- **Software License**: [GNU General Public License v3.0 (GPL-3.0-or-later)](LICENSE)
- **Copyright**: Copyright (C) 2026 Team Vox Solaris
- **SPDX Identifier**: `GPL-3.0-or-later`

All original source code (`.gd`, `.gdshader`), scene definitions (`.tscn`), UI themes (`.tres`), and project configurations in this repository are published under the terms of the GNU General Public License version 3 or (at your option) any later version as published by the Free Software Foundation.

Under GPL-3.0, you are free to run, study, share, and modify the software, provided that any derivative works or distributions also make the complete corresponding source code available under GPL-3.0 terms.

---

## 2. Permissive & Open-Licensed Third-Party Assets

The following assets are integrated into the repository under open-source and Creative Commons licenses:

### 2.1 Weather Elements Audio (Helton Yan)
- **Author**: Helton Yan
- **Source**: [Weather Elements Sound Pack (itch.io)](https://heltonyan.itch.io/weatherelements)
- **Location**: `Audio/SoundEffect/BackgroundNoise/`
  - `WE Heavy Inside Rain 1.mp3`
  - `WE Heavy Outside Rain 1.mp3`
  - `WE Heavy Wind Whistle 1.mp3`
  - `WE Light Inside Rain 1.mp3`
  - `WE Light Outside Rain 1.mp3`
  - `WE Light Wind Whistle 1.mp3`
  - `WE Thunder 1.mp3`
  - `WE Thunder 26.mp3`
  - `WE Thunder 29.mp3`
- **License**: [Creative Commons Attribution 4.0 International (CC-BY 4.0)](http://creativecommons.org/licenses/by/4.0/)
- **Modifications**: Transcoded from original WAV to MP3 format for runtime memory and load-time efficiency.
- **Attribution Notice**: Preserved in `Audio/SoundEffect/BackgroundNoise/LICENSE.txt`.

### 2.2 Vampire Survivors in Godot Tutorial Assets (Branno)
- **Author**: Branno
- **Source**: [Vampire Survivors in Godot Tutorial Series (YouTube)](https://youtube.com/playlist?list=PLtosjGHWDab682nfZ1f6JSQ1cjap7Ieeb)
- **Location**:
  - `Textures/Player/player_sprite.png`
  - `Textures/Enemy/kolbold_weak.png`, `kolbold_strong.png`, `cyclops.png`, `juggernaut.png`
  - `Textures/Items/Weapons/ice_spear.png`, `tornado.png`, `javelin_3_new.png`
  - `Audio/SoundEffect/collectgem.mp3`, `enemy_death.ogg`, `enemy_hit.ogg`, `ice.wav`, `levelup.ogg`, `tornado.ogg`
- **Terms**: Provided for open educational tutorial follow-along and non-commercial game development learning.

### 2.3 Fonts & Typography
- **Open Sans**:
  - **Designer**: Steve Matteson / Google Fonts
  - **Location**: `Font/OpenSans-Regular.ttf`, `Font/OpenSans-Medium.ttf`, `Font/OpenSans-Bold.ttf`
  - **License**: [SIL Open Font License 1.1 (OFL-1.1)](https://openfontlicense.org/)
- **Great Vibes**:
  - **Designer**: Rob Leuschke / TypeSETit, LLC
  - **Location**: `Font/GreatVibes-Regular.ttf`
  - **License**: [SIL Open Font License 1.1 (OFL-1.1)](https://openfontlicense.org/)
- **Noto Color Emoji**:
  - **Designer**: Google LLC
  - **Location**: `Font/NotoColorEmoji-Regular.ttf`
  - **License**: [SIL Open Font License 1.1 (OFL-1.1)](https://openfontlicense.org/) / Apache License 2.0
- **Palitura**:
  - **Designer**: Michael Rafailyk
  - **Location**: `Font/Palitura-*.ttf` (10 weights)
  - **Status**: Commercial typeface used in non-commercial university coursework prototyping. Marked for replacement prior to public commercial or standalone release.

### 2.4 Generative AI Visual Assets
- **Title Screen Background Parallax**:
  - **Location**: `Textures/Titlescreen/menu_bg_sky.png`, `menu_bg_city.png`, `menu_bg_terrain.png`, `menu_bg_foreground.png`
  - **Creator**: Team Vox Solaris via Generative AI tools (as disclosed in university coursework documentation).
  - **Status**: Licensed as part of the project repository under GPL-3.0 compatibility terms.

---

## 3. Temporary Placeholder & Proprietary Assets (Non-Commercial Prototyping Only)

> ⚠️ **LEGAL NOTICE**:  
> The following assets are copyrighted property of their respective owners. They are included in the repository **solely for educational, academic coursework, and non-commercial prototyping purposes**. They are **NOT** licensed under GPL-3.0.  
> **These assets MUST be replaced with original or CC0/libre equivalents before any public release, binary distribution, or commercial deployment.**

### 3.1 Terraria Sprites (Re-Logic)
- **Owner**: Re-Logic ([Terraria](https://terraria.org/))
- **Location**: `Textures/Items/Weapons/`
  - `Vampire_Knives.webp` & `Vampire_Knife_(projectile).webp`
  - `Kaleidoscope.webp` & `Kaleidoscope_(projectile).webp`
  - `Leather_Whip.webp` & `Leather_Whip_(projectile).webp`
- **Status**: Proprietary. Used as temporary prototyping graphics.
- **Action Required**: Replace with original pixel art before public distribution.

### 3.2 Risk of Rain Returns Assets (Hopoo Games / Gearbox Publishing)
- **Owner**: Hopoo Games / Gearbox Publishing ([Risk of Rain Returns](https://store.steampowered.com/app/1337520/Risk_of_Rain_Returns/))
- **Sprite Location**: `Textures/rorr/`
  - `sAlienHead.png`, `sBottled.png`, `sChaos.png`, `sDagger.png`, `sDrill.png`, `bPlanet.png`, `construct/sConstruct.png`
- **Sound Effect Location**: `Audio/SoundEffect/`
  - `Difficulty.wav`, `ItemDrop_Equipment.wav`, `ItemDrop_Green.wav`, `ItemDrop_Red.wav`, `ItemDrop_White.wav`, `ItemDrop_Yellow.wav`, `JarSouls.wav`, `Revive.wav`, `Scarf.wav`, `Shatter.wav`, `Shrine.wav`
- **Status**: Proprietary. Used as prototyping placeholders.
- **Action Required**: Replace sprites and audio clips with original SFX and custom icons before public distribution.

### 3.3 Risk of Rain 2 Music Tracks (Chris Christodoulou)
- **Composer / Owner**: Chris Christodoulou
- **Location**: `Audio/Music/Normal/` and `Audio/Music/Boss/` (e.g., *Thermodynamic Equilibrium*, *The Rain Formerly Known as Purple*, etc.)
- **Status**: Proprietary / Copyrighted soundtrack.
- **Repository Isolation**: All `.mp3`, `.wav`, `.ogg`, and `.flac` audio files inside `Audio/Music/` and `Audio/Music_Lite/` are strictly excluded from git tracking via `.gitignore`. They are retained solely in local development environments and are **never** committed or bundled into public release packages.
- **Distribution Note**: Public releases must ship only royalty-free or custom original music tracks.

### 3.4 Minecraft & Community Mod Textures (Mojang Studios / Mod Authors)
- **Owner**: Mojang Studios / Microsoft & Mod Creators (BluSunrize et al.)
- **Backgrounds**: `Textures/Backgrounds/` (`oak_planks.png`, `spruce_planks.png`, `birch_planks.png`, `jungle_planks.png`, `acacia_planks.png`, `dark_oak_planks.png`, `crimson_planks.png`, `warped_planks.png`, `stone.png`, `stone_bricks.png`)
- **GUI Elements**: `Textures/GUI/` (`alloy_smelter_top.png`, `basic_engineering.png`, `coke_oven.png` from Immersive Engineering)
- **Status**: Prototyping placeholders.
- **Action Required**: Replace with original tilemaps and UI icons before public distribution.

---

## 4. GPL-3.0 Compliance Guidelines for Contributors

All future code contributions, tools, and scripts must adhere to the following standards:

1. **SPDX Header Standard**: Every newly authored GDScript (`.gd`), C# (`.cs`), Python (`.py`), or shader (`.gdshader`) file must begin with the standard SPDX tag:
   ```gdscript
   # SPDX-License-Identifier: GPL-3.0-or-later
   # Copyright (C) 2026 Team Vox Solaris
   ```

2. **Incompatible Licenses**:
   - Code licensed under GPL-incompatible licenses (e.g., Apache 2.0 without exception, proprietary code, Non-Commercial CC licenses like CC-BY-NC) must **never** be copied into or merged with the codebase.
   - Permissive code (MIT, BSD-2/3-Clause, ISC) may be incorporated, preserving original copyright notices.

3. **Separation of Software and Assets**:
   - The game engine logic, scripts, and algorithms are strictly GPL-3.0.
   - Media assets (audio, art, typography) are considered separate works aggregated with the program. When distributing the complete package, all media must have clear licenses allowing distribution or be replaced before release.

4. **Release Checklist**:
   - [ ] Audit `Textures/rorr/` and replace all Risk of Rain sprites.
   - [ ] Audit `Textures/Items/Weapons/` and replace all Terraria weapon webp assets.
   - [ ] Audit `Textures/Backgrounds/` and replace Minecraft tile textures.
   - [ ] Audit `Audio/SoundEffect/` and replace Risk of Rain sound cues.
   - [ ] Confirm `.gitignore` prevents un-licensed music files in `Audio/Music/` from being bundled into release zips.
   - [ ] Co-locate OFL license files for all bundled open-source fonts in `Font/`.
