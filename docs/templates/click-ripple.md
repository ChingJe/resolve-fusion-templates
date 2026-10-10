# Click Ripple

標題 · 檔案 `templates/Titles/Click Ripple.setting` · [回到總覽](../../README.md)

從一個點擴散出去的圓圈，螢幕錄影用來標示「滑鼠點了這裡」或「手指按了這裡」。

![Click Ripple](../../previews/click-ripple.gif)

**用法**，兩種：

- **一條標題點一次**：拖到螢幕錄影上方的軌道，開頭對準點擊的那一刻，把 `Position` 移到游標的位置。清單留空。點擊不多時這樣最直覺，時間直接在時間軸上拖。
- **一條標題標完整段錄影**：把標題拉長蓋住整段錄影，在 `Click Times` 一行寫一個時間（寫法見[時間清單](../time-list.md)）。然後在每個點擊的時間點，把 `Position` 設到游標的位置並打關鍵幀。

| 參數 | 作用 |
|---|---|
| `Position` | 點擊的位置 |
| `Click Times` | 一行一個時間。留空就是標題一開始點一次 |
| `Clicks Each Time` | 每次連點幾下，2 就是雙擊 |
| `Seconds Between Those Clicks` | 連點時每一下隔多久 |
| `Size` | 波紋擴散到最大時的直徑，以畫面高度為 1 |
| `Ripple Lasts (seconds)` | 一次波紋從出現到消失多久 |
| `Rings` | 一次擴散幾圈，0 是不畫圈（只留圓盤和中心點） |
| `Ring Thickness` | 圈的粗細 |
| `Filled Disc` | 圈裡面填色的濃度，0 是不填 |
| `Centre Dot` | 中心實心點的大小，0 是沒有 |
| `Opacity` | 整體不透明度 |
| `Outline`、`Outline Colour` | 外面再包一圈別的顏色，0 是沒有 |
| `Colour` | 波紋的顏色 |
| `Frame Rate Override` | 時間算得不對時填時間軸的影格率，平常留 0 |

**注意**

- 用清單時，每個波紋會留在「點下去那一刻」的位置，就算 `Position` 之後移到別的地方也不會跟著跑。所以只要在每個點擊的時間點把位置設對就好，兩個關鍵幀之間怎麼移動不用管。
- 同一時間最多顯示兩個波紋。兩次點擊隔得比 `Ripple Lasts` 短很多、又連續三次以上時，最早的那個會提早消失。
- 不會自動找游標，位置要自己設。
