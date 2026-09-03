# Exporter 共用語意重構計畫

## 1. 目的

目前 MIDI、MusicXML、LilyPond 與 ABC exporter 各自處理 order、start、tempo、key
與 directive position。這會造成同一份 TMD 在不同輸出格式中產生不同的音樂語意。

本計畫的目標，是將 TMD 的音樂語意集中計算一次，再交給各格式 exporter 輸出。
格式 exporter 不應重新推導 TMD 的時間軸、調性或速度。

## 2. 目標架構

```text
TMD source
   ↓
Lexer + Parser
   ↓
Immutable AST
   ↓
TMDPlaybackRenderer
   ↓
PlaybackEvent
   ├── MIDI exporter → TMDMIDIEncoder
   ├── MusicXML exporter
   ├── LilyPond exporter
   └── ABC exporter
```

AST 負責保存來源語法；`TMDPlaybackRenderer` 負責將 AST 展開成具有絕對位置的
共用事件；各 exporter 只負責格式化這些事件。

## 3. 共用語意模型

預計新增格式無關的中間模型：

```swift
struct PlaybackEvent {
    let position: Int
    let duration: Int
    let content: PlaybackContent
}

enum PlaybackContent {
    case note(Note)
    case chord(ChordSymbol)
    case rest
    case percussion(String)
    case tie
}
```

directive 也應以明確位置保存：

```swift
struct TimedDirective {
    let position: Int
    let kind: SectionDirectiveKind
}
```

必要時可在事件上下文中附帶：

- 目前絕對 key offset
- 目前 tempo
- paragraph 與 section 名稱
- instrument
- source range，供錯誤與除錯使用

中間模型不得包含 MIDI status byte、MusicXML tag、LilyPond token 或 ABC token。

## 4. 語意規則

在開始改 exporter 前，先將以下規則寫入正式語法規格：

### 4.1 播放順序

- `Order.name` 展開對應 paragraph。
- `Order.relative` 改變目前調性 offset。
- `Order.absolute` 設定相對於初始 key 的絕對調性。
- `->#` 結束 order 解析。
- 沒有 order 時，依 paragraph 宣告順序播放一次。

### 4.2 時間位置

- paragraph 的 `start` 以小節為單位。
- section 內的 position 以 section base unit 為單位。
- unit group 的 `length` 同時代表事件跨度與下一個 position 的增量。
- directive 在指定 position 的事件之前生效。
- 負數 start 的行為必須明確定義；預設 playback 會裁切到非負時間。

### 4.3 Tempo

- `tempo(value)` 設定絕對 BPM。
- `relativeTempo(value)` 以目前 BPM 加上 value。
- BPM 不得低於有效下限；目前預設下限為 1。
- tempo directive 的 position 必須保留到 playback timeline。

### 4.4 Key

- `absoluteKey` 設定絕對 key signature。
- `relativeKey` 以半音為單位調整目前 key offset。
- note 與 chord 的 pitch 計算使用同一個 key offset。
- `KeySignature`、`ScaleDegree` 與 `Accidental` 是 key 計算的唯一來源。

### 4.5 音樂單位

- `Note` 使用 typed `ScaleDegree`、`Accidental` 與 octave。
- `ChordSymbol` 使用 typed `ChordRoot` 與 `ChordQuality`。
- 未知 chord suffix 使用 `.custom(String)` 保存。
- `rest` 不產生音高，但佔用 duration。
- `tie` 的延長語意由 playback layer 統一處理。
- percussion pattern 的字元映射由共用 mapping 管理。

## 5. 實作階段

### Phase 1：建立共用時間軸

- 新增 `TMDPlaybackRenderer`。
- 將 order 展開、paragraph start、section position 與 unit group duration 集中處理。
- 先輸出只有 note、chord、rest、percussion 的 `PlaybackEvent`。
- 保留現有 exporter 作為比較基準。

完成條件：共用時間軸測試通過，且現有 19 個測試不退化。

### Phase 2：導入 directive 狀態

- 將 tempo、relative tempo、absolute key、relative key、time signature 納入事件上下文。
- 確認 directive position 的套用順序。
- 移除各 exporter 自己的 key offset 與 tempo 累加邏輯。

完成條件：同一份 fixture 在所有 exporter 的事件位置與狀態一致。

### Phase 3：改造 MIDI 與 WAV

- MIDI generator 消費共用 `PlaybackEvent`。
- `TMDMIDIEncoder` 只處理 typed MIDI message 到 SMF binary 的轉換。
- WAV 維持透過 MIDI render，避免重新實作 playback 語意。
- 驗證負數 start、relative tempo 與 relative key 的 binary 結果。

完成條件：MIDI header、track、note event、tempo event 與 WAV render regression tests
全部通過。

### Phase 4：改造 MusicXML、LilyPond 與 ABC

- MusicXML 將共用 directive 轉成 `<direction>`、`<attributes>`、`<harmony>`。
- LilyPond 將共用 directive 轉成 `\\tempo`、`\\key`、`\\time`。
- ABC 將共用 directive 轉成 field 或 inline directive。
- 對無法完整表達的語意，使用文件定義的降級策略，不在 exporter 中自行猜測。

完成條件：四種 exporter 對同一 fixture 產生等價的時間軸與調性結果。

### Phase 5：清理與相容性

- 移除各 exporter 的重複 parse key、parse chord、scale step 與 tempo 邏輯。
- 移除沒有新語意的一行 wrapper。
- 保留必要的 public API 相容層，並明確標示 deprecated 或 migration path。
- 更新正式語法規格與 exporter 能力矩陣。

## 6. TDD 測試策略

先建立共用語意測試，再建立格式測試。

### 共用語意測試

- order 展開順序
- paragraph start offset
- section 與 unit group position
- rest、tie 與 duration
- tempo 絕對設定
- relative tempo 累加
- absolute key
- relative key
- note 與 chord 的共同 transposition
- percussion timing

### Exporter 測試

- MIDI event 與 binary bytes
- WAV RIFF header 與 PCM data
- MusicXML measure、direction、harmony
- LilyPond key、tempo、time 與 note output
- ABC field、voice、inline directive

每一個語意規則至少要有一個跨 exporter fixture，避免只測單一格式。

## 7. 文件同步規則

每新增或改變一個 AST 語意，都必須同步更新：

1. `TMD-Language-Specification.zh-TW.md`
2. Exporter 能力矩陣
3. 共用 playback semantics 說明
4. 至少一個 parser、formatter、playback 與 exporter 測試

若某格式無法完整表達語意，文件必須記錄：

- 已支援的部分
- 降級輸出的形式
- 尚未支援的部分
- 對使用者可見的影響

## 8. 完成定義

本計畫完成時，應符合以下條件：

- exporter 不再各自計算 TMD playback timeline。
- tempo、key、position 與 duration 在所有 exporter 使用同一份共用結果。
- binary encoder 與音樂語意完全分離。
- 所有已實作語法都有 parser、formatter、playback 與 exporter 測試。
- 文件與實際支援狀態一致。
- 既有測試與新增跨 exporter regression tests 全部通過。
