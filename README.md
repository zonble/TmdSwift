# TmdSwift

A modern Swift implementation of the **TMD** (Timebase Mark Down) markup language parser, toolkit, and music notation exporter.

In memory of **Chen, Chih-Han / [aguai](https://github.com/aguai)** (阿怪, 1974–2019).

Original project: [https://github.com/aguai/TMDLang](https://github.com/aguai/TMDLang)

## About TMD

正式的 TmdSwift 實作語法請參閱
[`docs/TMD-Language-Specification.zh-TW.md`](docs/TMD-Language-Specification.zh-TW.md)（English: [`docs/TMD-Language-Specification.en.md`](docs/TMD-Language-Specification.en.md)）。
原始設計筆記則保留於 [`docs/Band-Score.syntax.zh_TW.md`](docs/Band-Score.syntax.zh_TW.md)。

TMD is a plain-text musical notation DSL designed by composer and music producer 阿怪 (aguai, known for classics such as A-Mei's 《三天三夜》). It allows musicians and arrangers to describe multi-track songs, numbered musical notation (jianpu), chord progressions, tuplets, and playback arrangements in a concise, human-readable text format.

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

## Platform Support

| Platform | Parser & AST (`TmdSwift`) | MIDI Exporter (`TmdMIDI`) | MusicXML (`TmdMusicXML`) | LilyPond (`TmdLilyPond`) | ABC (`TmdABC`) | WAV Audio (`TmdAudio`) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **macOS** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ *(Built-in Roland GS DLS / Custom SF2)* |
| **Linux (Ubuntu)** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ *(Requires external synth / planned)* |
| **Windows** | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ *(Requires external synth / planned)* |
| **iOS / iPadOS** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ *(CoreAudio / Custom SF2)* |

## Installation & Build

Requires Swift 6.0+ / Xcode 16+.

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
- **`TmdUtils`**: Cross-platform file path normalizer and character encoding detector.
- **`TmdCLI`**: Command-line interface executable (`tmd`).

## License

MIT License
