# TMD Language Support for VS Code

Official Visual Studio Code extension providing language support, syntax highlighting, and snippets for the **TMD (Text Music Description)** format.

## Features

- **Syntax Highlighting**:
  - `::SCORE::` root score marker.
  - Song title `** Title **`.
  - Global tempo (`!= 120`), key signature (`?= C`), and time signature (`<4/4>`).
  - Paragraph definitions (`intro:Piano@|0|{ ... }`).
  - Section divisions (`<4*>`, `<16*>`).
  - Numbered musical notation (Jianpu) with accidentals (`1'`, `2,`) and octave marks (`1^`, `1_`).
  - Chord symbols (`[Cmaj7]`, `[1]`, `[6m]`).
  - Tuplets and rhythm modifiers (`%(---)`).
  - Arrangement execution flow (`-> intro -> A ->#`).
  - Block comments (`/* ... */`).
- **Snippets**:
  - `score`: Generates a minimal TMD score template.
  - `para`: Generates an instrument paragraph block.
  - `sec`: Inserts a section rhythmic grid.
  - `tup`: Inserts a tuplet group.
  - `ch`: Inserts a chord symbol.
- **Language Configuration**:
  - Auto-closing pairs and surrounding brackets for `{}`, `[]`, `()`, `<>`, `/**/`, `****`.
  - Code folding for paragraph blocks `{ ... }`.

## Installation

### Local Installation (Symlink into Extensions)

You can link this folder directly into your VS Code extensions directory:

```bash
ln -s "$(pwd)/editor/vscode" ~/.vscode/extensions/tmd-vscode
```

Then reload VS Code, open any `.tmd` file (such as `sample/三天三夜.tmd`), and enjoy full syntax highlighting!
