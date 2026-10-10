# Comic Intro

標題 · 檔案 `templates/Comic Intro.setting` · 安裝到 `Titles` · [回到總覽](../../README.md)

漫畫頁快速翻動，鏡頭從字裡拉遠，最後定格成紅框白字的標題。漫畫格裡是程序畫出來的圖案，不需要素材。

![Comic Intro](../../previews/comic-intro.png)

**用法**：拖到時間軸上，拉成想要的長度。

| 參數 | 作用 |
|---|---|
| `Text` | 標題文字 |
| `Font`、`Style` | 字型 |
| `Text Size`、`Text Color` | 文字大小與顏色 |
| `Box Color` | 文字底框的顏色 |
| `Box Padding X`、`Box Padding Y` | 底框在文字四周的留白，底框會自動貼合文字 |
| `Background Color` | 最後定格時的背景色 |
| `Frames Per Page` | 每一頁停留幾格，數字越小翻得越快 |
| `Start Zoom` | 開頭放大幾倍 |
| `Zoom Pivot X`、`Zoom Pivot Y` | 鏡頭從畫面上哪一點拉遠 |

**注意**

- `Zoom Pivot` 要落在某個字母的筆畫上，開頭才會是「從字裡面看出去」。改了文字之後通常要跟著調。
