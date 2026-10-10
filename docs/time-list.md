# 時間清單的寫法

Chapter Bar、Kinetic Lines、Punch Zoom、Glitch Hits、Freeze Frame、Karaoke Caption、Click Ripple、Typing、Chat Bubbles 都用一個多行文字框來列時間點，寫法相同：一行一個，開頭寫時間，後面寫內容。Variety Caption 和 Side Note 勾選 `Lines Start With A Time` 之後也是同一種寫法。

Number Counter 的計次器模式（`Step Times`）只寫時間、後面不寫內容。Photo Stack 的 `Last Photo Arrives After` 和 Hidden Word 的 `Reveal After` 只填一個時間點，寫法也一樣。

不想寫時間的話，Kinetic Lines、Variety Caption、Side Note 可以改用關鍵幀換句，做法見 [Variety Caption](templates/variety-caption.md)。

```
0:00 開場
1:25 第一段
4:10 第二段
```

## 時間的三種寫法

可以混用：

| 寫法 | 例子 | 說明 |
|---|---|---|
| 時間 | `1:25`、`1:02:03`、`0:07.5`、`42` | 秒可以帶小數，會四捨五入到最近的一格。只寫一個數字就是秒 |
| 影格數 | `120f` | 精確到格 |
| 比例 | `25%` | 片段長度的百分比，片段拉長縮短時會跟著移動 |

時間一律從片段（或標題）在時間軸上的開頭算起，不是整條時間軸的時間碼。

## 時間後面寫什麼

| 範本 | 時間後面 | 例子 |
|---|---|---|
| [Chapter Bar](templates/chapter-bar.md) | 章節名稱 | `1:25 第一段` |
| [Kinetic Lines](templates/kinetic-lines.md) | 要顯示的文字，直線符號（&#124;）是換行；不寫就是清空畫面 | `0:05 這一句` |
| [Punch Zoom](templates/punch-zoom.md) | 那一下的力道倍數，可以不寫 | `0:03 1.5` |
| [Glitch Hits](templates/glitch-hits.md) | 那一下的強度倍數，可以不寫 | `0:03 1.5` |
| [Freeze Frame](templates/freeze-frame.md) | 停幾秒，不寫就是 1 秒 | `0:02 1.5` |
| [Click Ripple](templates/click-ripple.md) | 不用寫，只要時間 | `0:03` |
| [Karaoke Caption](templates/karaoke-caption.md) | 那一句字幕 | `0:05 這一句` |
| [Typing](templates/typing.md) | 要打出來的那一句 | `0:05 這一句` |
| [Chat Bubbles](templates/chat-bubbles.md) | `<` 或 `>` 加一則訊息 | `0:05 > 快到了` |

## 規則

- 開頭不是上面三種寫法的行會被略過。
- 順序寫亂了會自動排好。
- 行數沒有上限。

## 時間點不準的時候

時間是用影格率換算成格數的。換算用的影格率抓錯時，時間點會整體偏快或偏慢，這時在範本的 `Frame Rate Override` 填上正確的影格率。用影格數（`120f`）或比例（`25%`）寫的時間點不受影響。
