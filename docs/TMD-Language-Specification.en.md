# TMD Language Specification (TmdSwift Implementation)

Version: 0.1 (corresponding to the current TmdSwift parser)  
Language: English ([繁體中文版](TMD-Language-Specification.zh-TW.md))

## 1. Purpose of this Document

This document defines the TMD (Timebase Mark Down) text format accepted by the current TmdSwift implementation. It describes the **behavior currently implemented**, rather than proposals for future features. For historical design notes, original TMDLang documents, and unimplemented syntax proposals, please refer to [`Band-Score.syntax.zh_TW.md`](Band-Score.syntax.zh_TW.md).

TMD is a plain-text format for describing song structure, instrument tracks, movable-do numbered musical notation (jianpu), chords, and playback arrangement order. A parsed TMD file forms an abstract syntax tree (`Sheet`), which can then be consumed by MIDI, MusicXML, LilyPond, ABC, or WAV audio rendering modules.

## 2. Minimal File Structure

```text
::SCORE::
** Song Title **
!= 120
?= C
<4/4>

verse:Piano@|0|{
    <4*>
    1 2 3 4
}

-> verse ->#
```

A file must begin with `::SCORE::`. Following this marker, header fields (song title, tempo, key, time signature), paragraph blocks, and the playback order declaration may appear. The parser allows flexibility in the order of these elements; when the same header field appears multiple times, the subsequent value overrides the preceding one.

## 3. Whitespace and Comments

Whitespace, tabs, and newlines are ignored as separators. The following forms are lexically equivalent:

```text
!=120
!= 120
! = 120
```

Block comments use `/*` and `*/` and can span multiple lines:

```text
/* This text is ignored and will not become musical data */
```

There is currently no single-line comment syntax. An unclosed block comment will be ignored through to the end of the file.

## 4. Song Title, Tempo, Key, and Time Signature

### 4.1 Title

```text
** Three Days and Three Nights **
```

Identifiers, numbers, and scale-degree digits enclosed between `**` delimiters are concatenated into the title, separated by single spaces. The title is optional; if omitted, `Sheet.name` defaults to an empty string.

### 4.2 Tempo

```text
!= 133
!= 120.5
```

Tempo is stored as a `Double` representing beats per minute (BPM). Both integer and decimal values are supported. Inside sections, `{!=145}` or `{!+30}` can also be used to alter the absolute or relative playback tempo downstream.

### 4.3 Key Signature

```text
?= A'
? = C
```

The key signature is stored as a string without strict validation at the parser level. Thus, `C`, `A'`, `Bb`, or any token readable as an identifier can be accepted. Key modulation such as `{?+5}` represents relative transposition in the playback order rather than this header field.

### 4.4 Time Signature

```text
<4/4>
<3/4>
```

The first number indicates the number of beats per measure, and the second indicates the note value of each beat. The time signature is parsed and stored as `Beat(count:noteValue)`.

## 5. Paragraphs and Tracks

The paragraph syntax is structured as follows:

```text
sectionName:instrumentName@{
    section+
}

sectionName:instrumentName@|startMeasure|{
    section+
}
```

For example:

```text
intro:Piano@|0|{
    <4*>
    1 2 3 4
}

intro:Guitar@|+4|{
    <16*>
    1_ - 1_ -
}
```

The components have the following meanings:

| Field | Meaning |
| --- | --- |
| Section Name | e.g. `intro`, `A`, `verse`, `chorus` |
| Instrument Name | e.g. `Piano`, `Guitar`, `CHORD` |
| Start Measure | Expressed as an integer offset; defaults to `0` if omitted |

The start measure can be positive, zero, or negative. A negative offset indicates an upbeat or early entry, such as `@|-1|`.

Multiple instrument paragraphs can share the same section name. Each is stored independently as a `Paragraph` and is not merged at the parser stage.

## 6. Sections and Basic Rhythm Units

Each section begins with `<n*>`:

```text
<4*>
1 2 3 4

<16*>
1_ - 1_ -
```

`n` is stored as `Section.noteLength`, indicating the base division unit (e.g. `4` for quarter notes, `16` for sixteenth notes) used by musical units in this section. The section continues parsing units until the next `<n*>`, closing brace `}`, or end-of-file is reached.

The barline symbol `|` can be used within sections for visual formatting. It is ignored by the parser:

```text
| 1 2 | 3 4 |
```

### 6.1 Section Directives

Directives can be placed among musical units within a section. Their position is recorded as the number of base units preceding them:

```tmd
<4*>
1 2 {!=140} 3 4
{!+10}
{?+2}
{?=D}
{<3/4>}
```

Supported directive kinds include absolute/relative tempo, absolute/relative key, and local time signature changes. MIDI exports tempo and meter changes into the conductor track; MusicXML, LilyPond, and ABC output corresponding annotations and musical directives.

## 7. Musical Units

### 7.1 Movable-Do Numbered Notes (Jianpu)

Basic scale degrees are digits `1` through `7`:

```text
1 2 3 4 5 6 7
```

Accidentals must immediately follow the scale degree digit:

```text
1'     /* C# / sharp 1 */
2,     /* Db / flat 2 */
```

Octaves are indicated with `^` (higher) or `_` (lower), where each repeated character shifts by one octave:

```text
1^     /* One octave up */
1^^    /* Two octaves up */
1_     /* One octave down */
1__    /* Two octaves down */
1'^    /* Sharp 1, one octave up */
```

The order of accidentals and octave marks is fixed: accidentals come first, followed by octave marks. If multiple accidentals are specified, the last accidental determines the pitch alteration; octave characters accumulate additively.

### 7.2 Chords

Chords are enclosed in square brackets:

```text
[Cmaj7]
[Am]
[1]
[6m]
```

The parser parses the enclosed content into a `ChordSymbol`. Roots support letter names (C–B) or numbered scale degrees (1–7). Recognized chord qualities include major, minor, seventh, diminished, augmented, suspended, and power chords. Suffixes not in the standard enumeration are preserved as `.custom(String)`, allowing extensions such as `C7#9`. Surrounding whitespace is trimmed, but the parser does not enforce harmonic adherence to the key signature.

### 7.3 Ties and Sustains

A single `-` is parsed as a tie / sustain:

```text
1 - - -
[Cmaj7] -
```

The actual duration is resolved by exporters based on the adjacent musical units and the section's rhythm division.

### 7.4 Tuplets and Rhythm Groups

Multiple musical units wrapped in parentheses followed by `%(...)` define a rhythm group:

```text
(1 2 3)%(--)
(7, 1)%(--)
```

In `%(--)`, each `-` represents one base division unit length. In the example above, the `length` of the tuplet group is `2` base units. The parentheses can contain notes, chords, ties, or any other valid units.

When no grouping parentheses are present, an individual musical unit forms a `UnitGroup` with `length = 1`:

```text
1 2 [C] -
```

This is equivalent to four distinct `UnitGroup` instances of length 1.

## 8. Playback Order and Modulation

The playback arrangement begins with `->` and concludes with `->#`:

```text
-> intro -> A -> B ->#
```

Section names are stored in `Order.name`:

```text
-> intro
```

Relative key modulation:

```text
-> {?-3}
-> {?+3}
```

The transposition offset is stored as a string in `Order.relative` (e.g. `"-3"`, `"+3"`). Absolute key changes:

```text
-> {?=C}
-> {?=A'}
```

The target key is stored as a string in `Order.absolute`.

`->#` marks the termination of the playback order. When the parser encounters this token, sheet parsing finishes; any content following it is ignored.

## 9. AST Mapping

| TMD Concept | Swift Type |
| --- | --- |
| Time Signature | `Beat` |
| Note | `Note` |
| Chord | `ChordSymbol` (Root: `ChordRoot`, Quality: `ChordQuality`) |
| Note / Chord / Tie / Rest / Drum | `Unit` |
| Tuplet / Rhythm Group | `UnitGroup` |
| `<n*>` Division & Content | `Section` |
| Section & Instrument Track | `Paragraph` |
| Playback Order Step | `Order` |
| Complete Score | `Sheet` |

`Unit` supports `.note`, `.chord`, `.tie`, `.rest`, and `.percussion`. Document metadata is stored in `Sheet.metadata`, and section directives in `Section.directives`.

## 10. Exporter Capability Matrix

Different export formats have different data models and capabilities. In the table below, "Partial" indicates the exporter reads the syntax but may output partial information or fallback annotations; "Indirect" indicates WAV synthesis is rendered via MIDI and inherits MIDI's behavior.

| Feature / Syntax | MIDI | MusicXML | LilyPond | ABC | WAV |
| --- | --- | --- | --- | --- | --- |
| metadata | Partially ignored | Mapped to `creator` | Uses `composer` | Uses `composer` | Indirect (via MIDI) |
| tempo | Supported | Supported | Supported | Supported | Indirect (via MIDI) |
| relative tempo | Supported | Accumulated & output | Accumulated & output | Accumulated & output | Indirect (via MIDI) |
| time signature | Supported | Supported | Supported | Supported | Indirect (via MIDI) |
| absolute key | Supported | Supported | Supported | Supported | Indirect (via MIDI) |
| relative key | Transposes pitch | Partial (annotations/local) | Partial (annotations/local) | Partial (annotations/local) | Indirect (via MIDI) |
| rest | Supported | Supported | Supported | Supported | Indirect (via MIDI) |
| percussion | Supported | Supported | Supported | Supported | Indirect (via MIDI) |
| typed chord | Supported | Supported | Supported | Supported | Indirect (via MIDI) |
| negative start | Timeline offset | Partial / planned | Partial / planned | Partial / planned | Indirect (via MIDI) |
| show-program | Ignored | Ignored | Ignored | Ignored | Ignored |
| execution-time | Ignored | Ignored | Ignored | Ignored | Ignored |
| playback orders | Supported | Supported | Supported | Supported | Indirect (via MIDI) |

Notable differences:
1. Exporters accumulate `relative tempo` changes via a unified playback timeline; differences lie mainly in target syntax conventions.
2. Notation exporters do not yet fully align non-measure directive positions.
3. `relative key` in LilyPond, ABC, and MusicXML is largely treated via local pitch transposition or comment annotations rather than formal key change signatures.
4. Negative `paragraph.start` offsets are handled in the MIDI timeline.
5. `show-program` and `execution-time` are currently retained in AST and TMD formatters without mapping to musical notation outputs.

## 11. Show Program

Non-musical stage and execution control scripts can be declared using triple-quoted blocks:

```tmd
show:Lighting@intro{
"""
cue black
wait 4
"""
}
```

The raw text content is preserved in `Paragraph.showProgram`, and the identifier following `@` is stored in `Paragraph.executionTime`. This specification does not prescribe the syntax of script bodies; hardware runners and executors can build upon this AST field independently.

## 12. Parsing and Encodings

`TmdParser` supports parsing from:

- Swift `String`
- `Data`
- Local file `URL`
- File paths or `file://` URL strings

When parsing from `Data`, the parser automatically detects character encodings, supporting UTF-8, Big5, GB18030, and other common encodings. If parsing fails, the API returns `nil`; structured diagnostics with line and column numbers are planned for future revisions.

## 13. Compatibility and Evolution

This specification version only guarantees syntax currently parsed and stored in the AST by TmdSwift. Future additions should adhere to the following principles:

1. Preserve the musical meaning of existing valid TMD scores.
2. Clearly document exporter handling whenever new AST types or fields are introduced.
3. Provide tests covering the parser, formatter, and at least one exporter for each new syntax construct.
4. Differentiate between original TMDLang syntax and TmdSwift extensions.
5. Increment the specification version and provide migration documentation when breaking changes are unavoidable.

## 14. Complete Example

```tmd
::SCORE::
** Sample Song **
!= 120
?= C
<4/4>

intro:CHORD@|0|{
    <4*>
    [Cmaj7] - [Am] -
}

intro:Piano@|0|{
    <16*>
    1 2 3 4 (5 6 7 1^)%(--)
}

-> intro -> {?+3} -> intro ->#
```

This file defines a 4/4 song with two tracks in the `intro` section (chords and melody), a 2-unit tuplet group, and a playback arrangement that repeats the intro after transposing up three semitones.
