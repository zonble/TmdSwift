# Co-Composing Music with AI Using TMD

TMD (Timebase Mark Down) is a plain-text, human-readable musical notation DSL. Because TMD represents music through structured, semantic text rather than binary formats (MIDI) or unstructured audio waveforms, it acts as an ideal bridge between human composers and Large Language Models (LLMs).

This guide provides concrete patterns and prompt examples for pair-programming music with AI agents using TMD.

---

## 1. Arranging Accompaniments from a Melody

### Concept
You compose the vocal or lead melody in TMD. Then, you prompt the AI to generate accompanying rhythm sections, bass lines, and harmonic pads entering at appropriate measure offsets (`@|+4|`, `@|+8|`).

### Example Workflow
**Human Input**:
```tmd
::SCORE::
** Summer Breeze **
!= 110
?= G
<4/4>

verse:Vocal@|0|{
    <4*>
    3 5 6 1^ 5 - 3 -
    2 3 5 2 1 - - -
}
```

**Prompt to AI**:
> "Here is a pop melody written in TMD. Please add a `CHORD` track playing acoustic guitar chords, a `Bass` track playing root notes with passing tones, and a `Drums` track entering at measure 2 (`@|+2|`). Output valid TMD format."

**AI Output**:
```tmd
::SCORE::
** Summer Breeze **
!= 110
?= G
<4/4>

verse:Vocal@|0|{
    <4*>
    3 5 6 1^ 5 - 3 -
    2 3 5 2 1 - - -
}

verse:CHORD@|0|{
    <2*>
    [1] - [6m] -
    [4] - [5] -
    [1] - - -
}

verse:Bass@|0|{
    <4*>
    1_ - 6__ -
    4__ - 5__ -
    1_ - - -
}

verse:Drums@|+2|{
    <16*>
    X--- s--- X--- s---
    X-X- s--- X--- s-s-
}

-> verse ->#
```

---

## 2. Motif Development and Continuation

### Concept
Define a short 2-bar or 4-bar melodic hook or motif, and ask the AI to develop it through compositional techniques such as melodic inversion, rhythmic augmentation/diminution, sequence repetition, or question-and-answer phrasing.

### Example Workflow
**Prompt to AI**:
> "I have a 2-bar motif in `<4*>`: `1 2 3 5 | 6 5 3 -`. Please develop this into a complete 8-bar A-section using antecedent-consequent phrasing (问答乐句), resolving to the tonic on bar 8."

**AI Output**:
```tmd
A:Piano@|0|{
    <4*>
    /* Antecedent (Question) */
    1 2 3 5 6 5 3 -
    2 3 5 3 2 - - -

    /* Consequent (Answer) */
    1 2 3 5 6 1^ 5 -
    3 2 1 2 1 - - -
}
```

---

## 3. Re-Harmonization and Chord Exploration

### Concept
Because chords in TMD are first-class citizen tokens (`[Cmaj7]`, `[Am7]`, `[6m]`, `[2m7-5]`), you can easily ask an AI to propose multiple harmonic styles for the same melody.

### Example Workflow
**Prompt to AI**:
> "Here is a melody in C major: `3 5 1^ 7 | 6 - 5 - | 4 3 2 5 | 1 - - -`. Please generate two different TMD chord arrangements:
> 1. A standard Pop progression (`[1]`, `[5]`, `[6m]`, `[4]`).
> 2. A Jazz / Neo-Soul progression with modal interchange and secondary dominants."

**AI Output**:
```tmd
/* Option 1: Standard Pop */
theme:PopChord@|0|{
    <2*>
    [1] - [5] -
    [6m] - [4] -
    [4] - [5] -
    [1] - - -
}

/* Option 2: Neo-Soul / Jazz Re-harmonization */
theme:JazzChord@|0|{
    <2*>
    [Cmaj7] - [E7] -
    [Am7] - [Gm7] [C7]
    [Fmaj7] - [Fm7] [Bb7]
    [Cmaj7] - - -
}
```

---

## 4. Macro Song Structuring and Modulations

### Concept
You compose modular paragraphs (`intro`, `verse`, `chorus`, `bridge`), and let the AI plan the overarching song structure, including climax builds and key modulations (`{?+1}`, `{?+2}`) via TMD's `->` execution pipeline.

### Example Workflow
**Prompt to AI**:
> "I have defined paragraphs `intro`, `verse`, `chorus`, `bridge`, and `outro`. Please generate a dynamic pop arrangement playback order in TMD that includes a half-step key change (+1 semitone) for the final chorus."

**AI Output**:
```tmd
-> intro 
-> verse -> chorus 
-> verse -> chorus 
-> bridge 
-> {?+1} -> chorus -> chorus 
-> outro ->#
```

---

## 5. Textural Layering and Arrangement Build-Up

### Concept
Use TMD measure entry offsets (`@|0|`, `@|+4|`, `@|+8|`) and lead-in pickups (`@|-1|`) to instruct AI agents on how to introduce and pull back instruments throughout a track, creating dynamic contrast between verses and choruses.

### Example Pattern:
```tmd
/* Verse 1: Sparse texture (Acoustic Guitar only) */
verse:AcousticGuitar@|0|{
    <4*>
    [1] - [6m] -
}

/* Measure 4: Bass enters */
verse:Bass@|+4|{
    <4*>
    1_ - 6__ -
}

/* Measure 7: Drum fill pickup 1 bar before Chorus */
chorus:Drums@|-1|{
    <16*>
    0------- ---- ---- ssss
}

/* Chorus: Full band enters */
chorus:Vocal@|0|{ ... }
chorus:AcousticGuitar@|0|{ ... }
chorus:ElectricGuitar@|0|{ ... }
chorus:Bass@|0|{ ... }
chorus:Drums@|0|{ ... }
```

---

## 6. Metric and Stylistic Adaptation

### Concept
Prompt the AI to convert a song's time signature or groove feel:
- Adapt straight quarter notes `<4*>` into triplets `(1 2 3)%(--)`.
- Re-meter a 4/4 pop song into a 3/4 or 6/8 waltz (`<3/4>` / `<6/8>`).
- Add syncopation and sixteenth-note anticipation for Funk or R&B feels.

---

## Summary: Recommended AI Prompts Cheatsheet

| Task | Prompt Template |
| :--- | :--- |
| **Write Counter-Melody** | `"Here is the Vocal track in TMD. Write a Violin counter-melody track that weaves around the vocal pauses without clashing."` |
| **Bassline Construction** | `"Generate a walking bassline track in TMD for these chords: [2m7] [5] [1maj7] in <4*>."` |
| **Variation Generation** | `"Take paragraph 'chorus:Vocal' and write a 'chorus_variation:Vocal' with melodic embellishments and higher octave peaks (^)."` |
| **TMD Score Verification** | `"Check this TMD score for syntax errors, accidental ordering (accidental before octave like 1'^), or mismatched bar lines."` |
