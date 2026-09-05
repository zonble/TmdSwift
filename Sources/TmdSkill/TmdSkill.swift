import Foundation

/// Provides skill definition content and installation utilities for AI agents (Codex, Antigravity, Claude, etc.).
public enum TmdSkill {
    /// Unique identifier for the skill.
    public static let skillName = "tmd"

    /// The complete SKILL.md markdown text containing YAML frontmatter and comprehensive instructions for writing TMD music scores.
    public static let skillMarkdown: String = """
---
name: tmd
description: >-
  Comprehensive guide and reference for writing, parsing, and exporting music scores using TMD (Timebase Mark Down).
  Use this skill whenever you need to create, edit, debug, or generate .tmd music scores, lead sheets, chord progressions,
  numbered musical notation (jianpu), multi-track arrangements, or compile them with the tmd CLI tool.
---

# TMD (Timebase Mark Down) Music Score Specification & Guide

TMD is a plain-text musical notation DSL designed by Taiwanese composer and music producer Chen, Chih-Han / aguai (阿怪, 1974–2019, composer of A-Mei's "Three Days and Three Nights").
It allows musicians and arrangers to describe multi-track songs, numbered musical notation (jianpu / movable-do solfege), chord progressions, tuplets, and playback arrangements in a concise, human-readable text format.

The `tmd` CLI tool compiles `.tmd` files and can export them to MIDI, MusicXML, LilyPond (.ly / PDF), ABC notation (.abc), or render offline audio to WAV.

---

## 1. Minimal File Structure

Every TMD score MUST start with `::SCORE::`.
A minimal valid TMD file consists of:

```tmd
::SCORE::
** Song Title **
!= 120
?= C
<4/4>

intro:Piano@|0|{
    <4*>
    1 2 3 4
}

-> intro ->#
```

### Essential Components:
1. **Header**: `::SCORE::` (must be at the beginning of the score).
2. **Title**: `** Title **` (enclosed in double asterisks).
3. **Tempo**: `!= 120` (in BPM, supports integer or decimals like `!= 120.5`).
4. **Key Signature**: `?= C` (tonic letter `C`..`B`, optional sharp `'` or flat `,`, e.g., `?= A'`, `?= E,`).
5. **Time Signature**: `<4/4>` (numerator/denominator, e.g. `<3/4>`, `<6/8>`).
6. **Paragraphs / Instrument Tracks**: `name:instrument@|offset|{ ... }`.
7. **Playback Flow**: `-> section1 -> section2 ->#` (must start with `->` and terminate with `->#`).

---

## 2. Metadata and Comments

### Comments
Block comments use `/* ... */` and can span multiple lines:
```tmd
/* This is a comment. It will be ignored by the parser. */
```

### Song Metadata Credits
TMD supports credit shorthand using `~ "..."` and named metadata using `=~:__KEY__= "..."`:
```tmd
~ "lyrics: aguai"
~ "composer: aguai"
~ "arranger: Martin Tang"
=~:__ALBUM__= "May 1998"
```
Recognized credit prefix mappings for `~` include:
- Chinese prefixes `詞：`, `曲：`, `編：` or direct keys.

---

## 3. Paragraphs and Instrument Tracks

Syntax:
```tmd
section_name:instrument_name@|start_measure|{
    <note_length*>
    music_units...
}
```

- **`section_name`**: Logical section name (e.g. `intro`, `verse`, `chorus`, `A`, `B`, `bridge`, `ending`).
- **`instrument_name`**: Track/instrument label (e.g. `Piano`, `Guitar`, `Bass`, `Drums`, `Vocal`, `CHORD`, `Strings`).
  Common names are mapped to General MIDI instruments automatically (e.g., `Piano` -> Grand Piano, `Guitar` -> Steel String Guitar, `Drums` / `Groove` -> Channel 10 Drum kit).
- **`start_measure`**: Entry measure offset inside `|...|` (e.g. `@|0|`, `@|+4|`, `@|-1|`).
  - `@|0|` or `@|+0|`: Enters at the beginning of the section.
  - `@|+4|`: Enters 4 measures after the section begins.
  - `@|-1|`: Enters 1 measure before the section begins (pick-up / anticipation measure).
  - Can also omit pipes: `@0` or `@|0|`.

Multiple tracks can share the same section name:
```tmd
intro:CHORD@|0|{
    <2*>
    [1] - [4] -
}

intro:Piano@|0|{
    <4*>
    1 2 3 4
}
```

---

## 4. Sections and Rhythm Grid

Inside a paragraph, music is organized into sections defined by a base subdivision:
```tmd
<note_length*>
```
Where `note_length` defines how many notes of this unit equal a whole note (semibreve):
- `<1*>`: Whole notes
- `<2*>`: Half notes
- `<4*>`: Quarter notes
- `<8*>`: Eighth notes
- `<16*>`: Sixteenth notes

Bar line dividers `|` are optional visual separators for readability and are ignored by the parser:
```tmd
<4*>
| 1 2 3 4 | 5 - 5 - |
```

---

## 5. Musical Units

### 5.1 Numbered Musical Notation (Jianpu / Movable-Do Solfege)
Numbered scale degrees:
- `1`: Do
- `2`: Re
- `3`: Mi
- `4`: Fa
- `5`: Sol
- `6`: La
- `7`: Ti

### 5.2 Accidentals
- `'` (single quote): Sharp (♯)
- `,` (comma): Flat (♭)

Examples: `1'` (C# / Sharp Do), `7,` (B♭ / Flat Ti).

### 5.3 Octave Displacements
- `^`: Higher octave. Multiple `^` raise by multiple octaves (e.g., `1^^`).
- `_`: Lower octave. Multiple `_` lower by multiple octaves (e.g., `1__`).

> **CRITICAL RULE**: Always write the accidental FIRST, then the octave displacement:
> - Correct: `1'^` (Sharp Do, one octave up), `7,_` (Flat Ti, one octave down).
> - Incorrect: `1^'` or `7_,` (syntax error).

### 5.4 Rests
- `0`: Rest of 1 base note length.
- `0 - - -`: Whole-measure rest in `<4*>` (or `0---`).

### 5.5 Ties and Duration Extensions
- `-`: Extends the previous note, chord, or rest by 1 base unit length.
Example in `<4*>` (quarter-note grid):
```tmd
1 -        /* Half note (2 beats) */
1 - - -    /* Whole note (4 beats) */
```

### 5.6 Chords
Chords are wrapped in square brackets `[...]`.
Can be written as:
- Letter roots: `[C]`, `[Cmaj7]`, `[Am]`, `[Am7]`, `[F]`, `[G7]`, `[Bb]`, `[D7#9]`, `[Dm7-5]`, `[Csus4]`
- Movable-do numbered chord degrees: `[1]` (I), `[6m]` (vi), `[4]` (IV), `[5]` (V), `[2m7]` (ii7)
- Chords can also take octaves: `[6_m]` (lower octave minor sixth), `[1^]`
- Chords can be sustained with ties: `[Cmaj7] - - -`

### 5.7 Percussion
Percussion tracks accept velocity / pitch tokens:
- `X`, `x`, `T`, `t`, `S`, `s` representing high-to-low / strong-to-weak percussion hits.
Example:
```tmd
intro:Drums@|0|{
    <16*>
    XsTt x-- XtXs X-x- ts
}
```

### 5.8 Tuplets and Rhythmic Groupings
Syntax:
```tmd
(units...)%(dashes)
```
The number of dashes in `%(...)` defines how many base beats the group occupies:
- `(1 2 3)%(--)`: Triplet fitting 3 notes into the time of 2 base beats.
- `(7, 1)%(--)`: 2 notes fitting into 2 base beats.
- `(1 2 3 4 5)%(--)`: 5-tuplet over 2 base beats.

---

## 6. Section Directives (Mid-Score Changes)

You can place inline directives anywhere inside a section between notes:
- `{!= 140}`: Absolute tempo change (BPM).
- `{!+ 10}`: Relative tempo change (+10 BPM).
- `{?= D}`: Absolute key change to D.
- `{?+ 2}`: Relative key transposition up 2 semitones.
- `{<3/4>}`: Time signature change to 3/4.

Example:
```tmd
<4*>
1 2 {!=140} 3 4
```

---

## 7. Arrangement and Playback Orders

The playback arrangement directs the performance flow and modulations from beginning to end:
```tmd
-> intro -> A -> B -> {?+3} -> C -> ending ->#
```

Rules:
- Starts with `->`.
- References section names defined in paragraphs: `-> intro -> verse -> chorus`.
- Supports key modulations during playback:
  - `{?+3}`: Modulate up 3 semitones.
  - `{?-2}`: Modulate down 2 semitones.
  - `{?=G}`: Modulate to absolute key G.
- Ends with `->#` (terminator).

---

## 8. Complete Working Example

```tmd
::SCORE::
** Sample Track **
!= 133
?= A'
<4/4>

intro:CHORD@|0|{
    <2*>
    |[1] - | - [7,] |
    |[1] - | - [7,] |
    <4*>
    [1] - - - [7,] - - -
}

intro:Chorus-1@|+4|{
    <16*>
    1_- 1_ - 1_ - - 1_ - 1_ - 1_ 1_ - - -
    1_- 1_ - 1_ - - 1_ - 1_ - 1_ 1_ - - -
}

intro:Guitar@|0|{
    <16*>
    (7,1)%(--) 1 (7,1)%(--) 1 (7,1)%(--) 1 (7,1)%(--) 6 7, 6 7, 6
    (7,1)%(--) 1 (7,1)%(--) 1 (7,1)%(--) 1 (7,1)%(--) 6 7, 6 7, 6
}

A:CHORD@|0|{
    <2*>
    |[1] - | - - |
    |[5] - | - - |
    |[6m] -| [5] -|
    |[4] - | [5] - |
}

-> intro -> A -> {?-3} -> A -> {?+3} -> ending ->#
```

---

## 9. Using the `tmd` CLI Tool

Compile and verify TMD files:
```bash
# 1. Parse and print score summary
tmd score.tmd -p

# 2. Export to Standard MIDI file (.mid)
tmd score.tmd -m score.mid

# 3. Export to MusicXML (.musicxml) for MuseScore/Sibelius
tmd score.tmd -x score.musicxml

# 4. Export to LilyPond (.ly) or render PDF
tmd score.tmd -l score.ly
tmd score.tmd --pdf-output score.pdf

# 5. Export to ABC notation (.abc) for web sheets (abcjs)
tmd score.tmd -a score.abc

# 6. Render offline WAV audio (macOS DLS / SoundFont)
tmd score.tmd -w output.wav

# 7. Install this skill into AI agent directories
tmd --install-skills
```
"""

    /// Standard installation paths for AI agent skills across the system.
    public static var defaultInstallPaths: [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent(".codex/skills/tmd"),
            home.appendingPathComponent(".gemini/skills/tmd"),
            home.appendingPathComponent(".gemini/config/skills/tmd"),
            home.appendingPathComponent(".claude/skills/tmd"),
            home.appendingPathComponent(".agent/skills/tmd"),
            home.appendingPathComponent(".agents/skills/tmd")
        ]
    }

    /// Result of installing the TMD skill.
    public struct InstallResult: Sendable {
        public let targetURL: URL
        public let success: Bool
        public let message: String
    }

    /// Installs the TMD skill into known AI agent skill directories.
    /// - Parameters:
    ///   - customPaths: Optional custom target directory paths. If nil, defaults to `defaultInstallPaths`.
    /// - Returns: List of installation results for each target path.
    @discardableResult
    public static func installSkills(to customPaths: [URL]? = nil) -> [InstallResult] {
        let targets: [URL]
        let isCustom = customPaths != nil
        targets = customPaths ?? defaultInstallPaths
        let fm = FileManager.default
        var results: [InstallResult] = []

        for targetDir in targets {
            if !isCustom {
                let parent = targetDir.deletingLastPathComponent()
                let toolRoot = parent.deletingLastPathComponent()
                guard fm.fileExists(atPath: toolRoot.path) || fm.fileExists(atPath: parent.path) else {
                    continue
                }
            }

            do {
                try fm.createDirectory(at: targetDir, withIntermediateDirectories: true, attributes: nil)
                let skillFile = targetDir.appendingPathComponent("SKILL.md")
                try skillMarkdown.write(to: skillFile, atomically: true, encoding: .utf8)
                results.append(InstallResult(targetURL: targetDir, success: true, message: "Installed TMD skill to \(targetDir.path)"))
            } catch {
                results.append(InstallResult(targetURL: targetDir, success: false, message: "Failed installing to \(targetDir.path): \(error.localizedDescription)"))
            }
        }

        return results
    }
}
