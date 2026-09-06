# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Windows / Linux CI & Release Automation**:
  - Added comprehensive multi-platform CI pipeline (`.github/workflows/ci.yml`) covering macOS, Ubuntu Linux, and Windows x64.
  - Added automated GitHub Release deployment workflow (`.github/workflows/release.yml`) producing Linux static binaries (`x86_64`, `aarch64`), macOS Universal Binaries (`arm64` + `x86_64`), and Windows x64 zip bundles packaged with required Swift runtime DLLs.
- **VS Code Extension TMD Export Integration**:
  - Added export commands to VS Code extension (`editor/vscode/extension.js` and `package.json`):
    - Export to MIDI (`.mid`), MusicXML (`.musicxml`), ABC Notation (`.abc`), LilyPond (`.ly`), PDF via LilyPond (`.pdf`), and offline WAV audio (`.wav`).
    - Audio preview playback directly in terminal from editor title bar and context menu.
    - Added one-click command to install AI agent skills (`tmd.installSkills`).

## [0.1.3] - 2026-09-06

### Added
- **AI Agent Skill Target (`TmdSkill`)**:
  - Added `TmdSkill` framework target and `tmd --install-skills` CLI command to automatically deploy TMD skill documentation (`SKILL.md`) to Codex, Claude Code, Antigravity, and Gemini agent directories.
  - Added comprehensive AI composition methodology covering Modular Section-Based Chunking, motif-driven architecture, human composition principles, and counterpoint techniques (Strict Canon with measure offsets `@|+N|` and Fugue structures).
- **AI Co-Composing Documentation**:
  - Added `docs/AI-Co-Composing-With-TMD.md` detailing collaborative patterns: melody arranging, motif continuation, re-harmonization, song structuring, and audio validation loops.
- **AI Collaboration Section in README**:
  - Highlighted AI co-composition capabilities and one-click skill installation instructions.

### Fixed
- **WAV Audio Offline Rendering Truncation**:
  - Fixed rendered WAV files clipping before final notes decayed. Durations are now computed precisely via CoreAudio's `MusicSequenceGetSecondsForBeats` with dynamic tempo mapping plus a 2.5-second release reverb tail.
- **CI Test Graph Stability**:
  - Configured `swift test --no-parallel` to prevent macOS system-level CoreAudio AUGraph concurrency collisions during test execution.

## [0.1.2] - 2026-09-05

### Added
- **Sample Scores & Syntax Enhancements**:
  - Added comprehensive sample scores including `sample/zk3.tmd` and `sample/zk3_symphony.tmd`.
  - Added chord octave shifting support (`[6_m]`, `[1^]`).
  - Added support for tie extensions and negative measure offsets.

### Fixed
- Fixed section divider parsing issues and legacy section marker compatibility.

## [0.1.1] - 2026-09-04

### Fixed
- Fixed integer arithmetic overflow handling during fast tempo tick calculations.

## [0.1.0] - 2026-09-04

### Added
- Initial public release of `TmdSwift`.
- Modern Swift parser, tokenizer, AST, and formatter for TMD (Timebase Mark Down).
- Multi-track Standard MIDI (SMF Type 1) exporter (`TmdMIDI`).
- MusicXML 4.0 Partwise exporter (`TmdMusicXML`).
- LilyPond source and PDF rendering exporter (`TmdLilyPond`).
- ABC Notation v2.1+ exporter (`TmdABC`).
- CoreAudio offline WAV synthesizer (`TmdAudio`).
- Command-line tool `tmd` (`TmdCLI`).
- Initial VS Code syntax highlighting extension (`editor/vscode`).
