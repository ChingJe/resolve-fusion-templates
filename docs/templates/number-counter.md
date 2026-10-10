# Number Counter

標題 · 檔案 `templates/Titles/Number Counter.setting` · [回到總覽](../../README.md)

數字從一個值跳到另一個值，數完時彈一下。也可以當計次器：照寫好的時間點，每到一個就加一並彈一下（「第 25 顆」）。

![Number Counter](../../previews/number-counter.gif)

左邊是連續跳到結束值，右邊是計次器。

**用法**：拖到影片上方的軌道，拉成想要的長度。背景是透明的。

| 參數 | 作用 |
|---|---|
| `Counts` | `Smoothly To The End Value`：從起始值連續跳到結束值。`One Step At Each Listed Time`：計次器，每到清單上的一個時間點跳一次 |
| `Start Value`、`End Value` | 起始值與結束值 |
| `Decimals` | 小數位數，0 到 3 |
| `Thousands Separator` | 是否加千分位逗號 |
| `Prefix`、`Suffix` | 前後綴，例如 `$`、`%` |
| `Count Finishes At` | 在片段的哪個位置數完，之後停在結束值 |
| `Step Times` | 計次器用：每一次的時間點，一行一個，寫法見[時間清單的寫法](../time-list.md)。也可以用空格或逗號隔開寫在同一行 |
| `Each Step Adds` | 計次器用：每次加多少。填負數就是倒著數 |
| `Step Pop (seconds)` | 計次器用：每次彈一下花幾秒 |
| `Pop` | 彈一下的幅度，0 是不彈 |
| `Font`、`Size`、`Color` | 字型、大小、顏色 |
| `Position` | 位置 |
| `Frame Rate Override` | 計次器的時間點不對時填時間軸的影格率，平常留 0 |

**注意**

- 計次器從 `Start Value` 開始，不看 `End Value` 和 `Count Finishes At`。「第 25 顆」這種寫法是把 `Prefix` 填 `第 `、`Suffix` 填 ` 顆`，字型換成有中文的（例如 `Microsoft JhengHei`）。
- 計次器模式只在實驗用的合成裡用腳本測過。
- 數字跳動時寬度會變。用每個數字等寬的字型（預設的 Open Sans 就是），文字才不會左右晃。
