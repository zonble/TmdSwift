# TmdSwift

A modern Swift implementation of the **TMD** (Text Music Description) markup language parser, toolkit, and music notation exporter.

In memory of **Chen, Chih-Han / aguai** (阿怪, 1974–2019).

Original project: [https://github.com/aguai/TMDLang](https://github.com/aguai/TMDLang)

## About TMD

TMD is a plain-text musical notation DSL designed by composer and music producer 阿怪 (aguai, known for classics such as A-Mei's 《三天三夜》). It allows musicians and arrangers to describe multi-track songs, numbered musical notation (jianpu), chord progressions, tuplets, and playback arrangements in a concise, human-readable text format.

**TmdSwift** re-implements the original parser into a clean, modern Swift architecture featuring:
- A two-stage Lexer + TokenParser pipeline.
- Normalized musical AST structures (`Beat`, `Note`, `Unit`, `Section`, `Paragraph`, `Order`, `Sheet`).
- Formatter to serialize AST back to standard TMD syntax.
- **Multi-track MIDI (SMF Type 1)** exporter (`TmdMIDI`).
- **MusicXML 4.0** notation exporter (`TmdMusicXML`) for MuseScore, Sibelius, and web renderers.
- **LilyPond** engraver exporter (`TmdLilyPond`) for publication-grade score typesetting and PDF rendering.
- A command-line interface (`tmd`) powered by `swift-argument-parser`.

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

# 6. Render to WAV audio file (macOS built-in DLS or custom SoundFont)
swift run tmd sample/三天三夜.tmd -w score.wav
```

## Swift Package Usage

Add `TmdSwift` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/zonble/TmdSwift.git", branch: "main")
]
```

### Example

```swift
import TmdSwift
import TmdMIDI
import TmdMusicXML
import TmdLilyPond

let tmdString = """
::SCORE::
** Sample **
!= 120
?= C
<4/4>

intro:Piano@|0|{
<4*>
1 2 3 4
}
-> intro ->#
"""

guard let sheet = TmdParser.parse(string: tmdString) else {
    fatalError("Failed to parse TMD score")
}

// Inspect summary
print(sheet.summary())

// Export to MIDI Data
let midiData = TMDMIDIGenerator.generateMIDI(from: sheet)

// Export to MusicXML string
let musicXML = TMDMusicXMLGenerator.generateMusicXML(from: sheet)

// Export to LilyPond string
let lilyPond = TMDLilyPondGenerator.generateLilyPond(from: sheet)
```

## Modules

- **`TmdSwift`**: Lexer, Parser, AST data structures, and TMD source formatter.
- **`TmdMIDI`**: Binary SMF Type 1 multi-track MIDI file generator.
- **`TmdMusicXML`**: W3C MusicXML 4.0 Partwise generator.
- **`TmdLilyPond`**: LilyPond engraving source generator.
- **`TmdAudio`**: Offline WAV audio synthesizer using CoreAudio / DLS SoundFont.
- **`TmdUtils`**: Cross-platform file path normalizer and character encoding detector.
- **`TmdCLI`**: Command-line interface executable (`tmd`).

## License

MIT License
