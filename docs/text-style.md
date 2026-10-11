# 文字外觀

[回到總覽](../README.md)

以文字為主的五個標題，「字長什麼樣子」這一段的參數是同一組：名稱、順序、單位都一樣。在其中一個學會怎麼調，其他的都一樣調；填同樣的數字，得到同樣的外觀。

| 範本 | 有這一組 | 有底框 |
|---|---|---|
| [Caption](templates/caption.md) | ✓ | ✓ |
| [Kinetic Lines](templates/kinetic-lines.md) | ✓ | ✓ |
| [Variety Caption](templates/variety-caption.md) | ✓ | |
| [Side Note](templates/side-note.md) | ✓ | |
| [Text Label](templates/text-label.md) | ✓ | 它有自己的外框 |

## 參數

在檢查器裡從 `Font` 到 `Shadow Softness`（有底框的到 `Box Roundness`）就是這一組。

| 參數 | 作用 |
|---|---|
| `Font` | 字型和字重 |
| `Size` | 字級，畫面寬度的幾分之幾。0.07 是一個字大約佔畫面寬的 7% |
| `Letter Spacing` | 字距，1 是字型原本的間距 |
| `Colour` | 字的顏色 |
| `Outline`、`Outline Colour` | 內層描邊的粗細和顏色。粗細是畫面寬度的幾分之幾，0 是沒有 |
| `Outer Outline`、`Outer Outline Colour` | 外層描邊，包在內層外面。0 是沒有 |
| `Shadow` | 陰影的濃度，0 是沒有 |
| `Shadow Distance` | 陰影往右下偏多遠，畫面寬度的幾分之幾 |
| `Shadow Softness` | 陰影的模糊程度，0 是銳利的 |
| `Box Opacity`、`Box Colour` | 底框的不透明度和顏色，0 是沒有底框（只有 Caption 和 Kinetic Lines 有） |
| `Box Padding` | 底框在字四周的留白，畫面寬度的幾分之幾 |
| `Box Roundness` | 底框的圓角，0 是直角、1 是最圓 |

各範本的預設值不一樣（旁白小字本來就比字卡小），但同一個數字在每個範本裡代表的大小、粗細是一樣的。

## 讓不同的標題長得一樣

- **同一種範本**：把調好的那個片段複製貼上（同一條時間軸或另一條時間軸都可以），再改文字。
- **不同種範本**：把這一組的數字和顏色照抄過去。欄位的名稱和順序相同，由上到下對著填就好。

## 有配色選單的兩個範本

Variety Caption 和 Text Label 有 `Colours` 配色選單。選了預設配色就用配色的顏色，這一組裡的顏色欄位（`Colour`、`Outline Colour`，Variety Caption 還有 `Outer Outline Colour`）不起作用；要用這些欄位就把 `Colours` 選成 `Custom`。字型、字級、描邊粗細、陰影不受配色影響。

## 注意

- 這一組參數只在實驗用的合成裡用腳本測過，還沒有在 Edit 頁面的檢查器裡實際操作過。
- 預設字型是微軟正黑體粗體。換字型時要選有中文字的，不然中文會變成方塊。
- 字級很大時描邊不會跟著變粗，描邊和陰影距離是照畫面寬度算的，不是照字級。
