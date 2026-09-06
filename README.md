# TmdSwift

A modern Swift implementation of the **TMD** (Timebase Mark Down) markup language parser, toolkit, and music notation exporter.

In memory of **Chen, Chih-Han / [aguai](https://github.com/aguai)** (阿怪, 1974–2019).

Original project: [https://github.com/aguai/TMDLang](https://github.com/aguai/TMDLang)

## About TMD

TMD is a plain-text musical notation DSL designed by composer and music producer 阿怪 (aguai, known for classics such as A-Mei's 《三天三夜》). It allows musicians and arrangers to describe multi-track songs, numbered musical notation (jianpu), chord progressions, tuplets, and playback arrangements in a concise, human-readable text format.

In the age of generative AI, TMD can also serve as a music-native intermediate representation between a creator's intent and final music files:
- **More reliable musical generation**: AI can describe reusable motifs, chord progressions, arrangement changes, and key transpositions without regenerating every note, reducing structural and consistency errors.
- **Lower token usage**: Repetition, variation, and transposition can be expressed as structure instead of duplicated note data.
- **Preserved musical relationships**: The connection between a motif, its variations, and the overall song arrangement remains explicit.
- **Verifiable and reproducible output**: Structured text is easier to validate, edit, regenerate, and review than unstructured generated audio.
- **Interoperability**: TMD can be converted into MIDI, MusicXML, LilyPond, ABC notation, or audio for downstream tools.

At its core, TMD reflects the practical workflow and mental model of modern popular music songwriting and arrangement:
- **Lead-sheet and Jianpu thinking**: Melodies are expressed in movable-do numbered scale degrees (`1`–`7`), octaves (`^`, `_`), and accidentals (`'`, `,`), making transpositions and melodic contours intuitive without the visual clutter of traditional staves.
- **Harmony-first architecture**: Chord symbols (both harmonic scale degrees like `[1]`, `[6m]` and standard chord names like `[Cmaj7]`) are treated as first-class citizens alongside melody lines.
- **Section-oriented modularity**: Songs are broken down into named song forms (`intro`, `verse`, `chorus`, `bridge`), with independent multi-instrument tracks entering at specified measure offsets (`@|+4|`).
- **Arrangement as linear execution flow**: Song playback and modulations (`{?+3}`, `{?-3}`) are declared as an explicit execution sequence (`-> intro -> A -> B -> C ->#`), mirroring how musicians and producers compose, rehearse, and structure arrangements in their minds.

**TmdSwift** re-implements the original parser into a clean, modern Swift architecture featuring:
- A two-stage Lexer + TokenParser pipeline.
- Normalized musical AST structures (`Beat`, `Note`, `Unit`, `Section`, `Paragraph`, `Order`, `Sheet`).
- Formatter to serialize AST back to standard TMD syntax.
- **Multi-track MIDI (SMF Type 1)** exporter (`TmdMIDI`).
- **MusicXML 4.0** notation exporter (`TmdMusicXML`) for MuseScore, Sibelius, and web renderers.
- **LilyPond** engraver exporter (`TmdLilyPond`) for publication-grade score typesetting and PDF rendering.
- **ABC Notation** exporter (`TmdABC`) for web sheet rendering (`abcjs`) and text-based score sharing.
- **Offline WAV Audio** synthesizer (`TmdAudio`) powered by CoreAudio DLS SoundFont.
- A command-line interface (`tmd`) powered by `swift-argument-parser`.

## Co-Composing with AI Using TMD

Because TMD is a concise, text-based, and human-readable musical notation DSL, it serves as an ideal bridge between human musical ideas and generative AI / Large Language Models (LLMs). Instead of wrestling with opaque binary formats (MIDI) or unstructured audio waveforms, creators and AI agents can pair-program music interactively in TMD.

### 🚀 Equip Your AI Assistant in One Command

`TmdSwift` comes with an official AI Agent skill (`SKILL.md`) covering TMD syntax, modular section chunking, human composition principles, motif development, and counterpoint rules. You can install it directly into your local AI environment (supporting Codex, Claude Code, Antigravity, and Gemini):

```bash
tmd --install-skills
```

Once installed, your AI agent will automatically understand how to compose, arrange, debug, and orchestrate music using TMD.

### What AI Can Help You Achieve

1. **Arranging Accompaniments from Melody**:
   Draft a vocal line or melody in TMD, then prompt the AI to generate supporting tracks (bass lines, rhythm guitar grooves, string pads, or drum patterns) with specific entry offsets (`@|+4|`).

2. **Motif Development & Continuation**:
   Define a short 2-bar or 4-bar melodic motif, and let the AI develop it into complete phrases through inversion, retrograde, rhythmic variations, or antecedent-consequent question-and-answer phrasing.

3. **Re-Harmonization & Chord Exploration**:
   Provide a melody and have the AI propose multiple chord progressions—from standard pop and rock progressions to modal jazz substitutions and Neo-Soul extensions (`[Cmaj7]`, `[Am7]`, `[Dm7-5]`).

4. **Macro Song Structuring & Modulations**:
   Compose core song blocks (`intro`, `verse`, `chorus`, `bridge`) and have the AI plan the overarching playback sequence (`-> intro -> A -> B -> {?+1} -> B ->#`), complete with key modulations and emotional dynamics.

5. **Textural Layering & Arrangement Build-Up**:
   Use measure entry offsets (`@|0|`, `@|+4|`, `@|-1|`) to guide the AI in orchestrating gradual instrumentation build-ups, pick-up measures (anticipation notes), and dynamic contrast across sections.

6. **Style & Metric Variations**:
   Prompt the AI to adapt a 4/4 ballad into a 3/4 waltz, re-groove straight rhythms into syncopated Funk/R&B patterns, or add tuplet ornaments `(1 2 3)%(--)`.

> 📖 **Detailed Guide & Prompt Examples**: See [`docs/AI-Co-Composing-With-TMD.md`](docs/AI-Co-Composing-With-TMD.md) for concrete workflows, step-by-step examples, and copy-pasteable prompt templates.

## Platform Support

| Platform | Parser & AST (`TmdSwift`) | MIDI Exporter (`TmdMIDI`) | MusicXML (`TmdMusicXML`) | LilyPond (`TmdLilyPond`) | ABC (`TmdABC`) | WAV Audio (`TmdAudio`) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **macOS** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ *(Built-in Roland GS DLS / Custom SF2)* |
| **Linux (Ubuntu)** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ *(Requires external synth / planned)* |
| **Windows** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ *(Requires external synth / planned)* |
| **iOS / iPadOS** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ *(CoreAudio / Custom SF2)* |

## Installation & Build

Requires Swift 6.0+ / Xcode 16+.

### Install on macOS / Linux from Homebrew tap

```bash
brew tap zonble/tmd
brew tap --trust zonble/tmd  # allow this third-party tap
brew install tmd
```

If Homebrew refuses to install from an untrusted third-party tap, run the `brew tap --trust zonble/tmd` line and install again.

On Linux, the Homebrew formula builds `tmd` with Homebrew's `swift` package (`brew install swift`). Without Homebrew, install Swift 6 from your distribution or Swift.org.

### Using Mint

You can install the `tmd` CLI tool via [Mint](https://github.com/yonaskolb/Mint):

```bash
mint install zonble/TmdSwift
```

### Build from Source

```bash
git clone https://github.com/zonble/TmdSwift.git
cd TmdSwift
swift build -c release
```

## CLI Usage (`tmd`)

You can run the command line tool directly with `swift run tmd`:

```bash
# 1. Parse and print score summary
swift run tmd sample/三天三夜.tmd -p

# 2. Export to Standard MIDI file
swift run tmd sample/三天三夜.tmd -m score.mid

# 3. Export to MusicXML (open with MuseScore, Sibelius, Finale, etc.)
swift run tmd sample/三天三夜.tmd -x score.musicxml

# 4. Export to LilyPond (.ly) source file
swift run tmd sample/三天三夜.tmd -l score.ly

# 5. Render directly to PDF using the local lilypond compiler
swift run tmd sample/三天三夜.tmd --pdf-output score.pdf

# 6. Export to ABC notation file (for abcjs or Markdown web rendering)
swift run tmd sample/三天三夜.tmd -a score.abc

# 7. Render to WAV audio file (macOS built-in DLS or custom SoundFont)
swift run tmd sample/三天三夜.tmd -w score.wav

# 8. Install TMD skill definition for AI agents (Codex, Antigravity, Claude, etc.)
swift run tmd --install-skills
```

## Swift Package Usage

Add `TmdSwift` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/zonble/TmdSwift.git", branch: "main")
]
```

Then import the modules:

```swift
import TmdSwift
import TmdMIDI
import TmdMusicXML
import TmdLilyPond
import TmdABC

// Parse TMD from file or URL
guard let sheet = try TmdParser.parse(filePathOrURL: "sample/三天三夜.tmd") else {
    fatalError("Failed to parse")
}

// Inspect summary
print(sheet.summary())

// Export to MIDI Data
let midiData = TMDMIDIGenerator.generateMIDI(from: sheet)

// Export to MusicXML string
let musicXML = TMDMusicXMLGenerator.generateMusicXML(from: sheet)

// Export to LilyPond string
let lilyPond = TMDLilyPondGenerator.generateLilyPond(from: sheet)

// Export to ABC notation string
let abc = TMDABCGenerator.generateABC(from: sheet)
```

## Modules

- **`TmdSwift`**: Lexer, Parser, AST data structures, and TMD source formatter.
- **`TmdMIDI`**: Binary SMF Type 1 multi-track MIDI file generator.
- **`TmdMusicXML`**: W3C MusicXML 4.0 Partwise generator.
- **`TmdLilyPond`**: LilyPond engraving source generator.
- **`TmdABC`**: Standard ABC Notation (v2.1+) generator.
- **`TmdAudio`**: Offline WAV audio synthesizer using CoreAudio / DLS SoundFont.
- **`TmdSkill`**: AI agent skill definitions and automated installation utilities for AI co-pilots.
- **`TmdUtils`**: Cross-platform file path normalizer and character encoding detector.
- **`TmdCLI`**: Command-line interface executable (`tmd`).

## Editor Support

You can edit TMD files with syntax highlighting, snippets, and export tools in both desktop and terminal editors:

### 1. Visual Studio Code

The repository includes an official VS Code extension in [`editor/vscode`](editor/vscode):
- **Syntax Highlighting & Snippets**: Full grammar for TMD metadata, tracks, numbered notation, chords, tuplets, and arrangement flow.
- **Export & Playback Commands** (via `tmd` CLI):
  - `TMD: Play Audio Preview in Terminal` (editor top-right title bar & context menu)
  - `TMD: Export to MIDI (.mid)`
  - `TMD: Export to MusicXML (.musicxml)`
  - `TMD: Export to ABC Notation (.abc)`
  - `TMD: Export to LilyPond (.ly)`
  - `TMD: Render to PDF via LilyPond (.pdf)`
  - `TMD: Render to WAV Audio (.wav)`
  - `TMD: Install AI Agent Skills`

To install locally:
```bash
ln -s "$(pwd)/editor/vscode" ~/.vscode/extensions/tmd-vscode
```

### 2. zago (Terminal Editor with Native TMD Integration)

[**zago**](https://github.com/zonble/zago) is a modern modal terminal editor (with Web & desktop editions) that provides first-class native TMD score support:
- **Real-time TMD Playback**: Press `Ctrl+P` or use `:tmd play` to preview scores directly within the terminal or browser (via Web MIDI / JZZ synth).
- **Export Menu & Shortcuts**: Press `Ctrl+E` or run `:tmd export <format>` to export to MIDI, MusicXML, ABC, LilyPond, PDF, or WAV on the fly.
- **Syntax Highlighting**: Dedicated TMD syntax highlighting and buffer status notifications.

## Documentation & Language Specification

For the formal TMD language specification implemented in TmdSwift, please refer to:
- English: [`docs/TMD-Language-Specification.en.md`](docs/TMD-Language-Specification.en.md)
- Traditional Chinese: [`docs/TMD-Language-Specification.zh-TW.md`](docs/TMD-Language-Specification.zh-TW.md)

Historical draft notes and original design concepts are preserved in [`docs/Band-Score.syntax.zh_TW.md`](docs/Band-Score.syntax.zh_TW.md).

## License

MIT License
