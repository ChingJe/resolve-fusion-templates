# Split Screen

特效 · 檔案 `templates/Effects/Split Screen.setting` · [回到總覽](../../README.md)

分割畫面。這個特效做的事是：讓一個片段只出現在畫面的其中一格，其他地方變透明。幾個片段各套一次、各佔一格，就拼成分割畫面。分隔線可以是斜的，每一格可以依序滑進來。

![Split Screen](../../previews/split-screen.gif)

**用法**

1. 把要同時出現的片段疊在不同軌道，時間對齊。
2. 每個片段都套這個特效，`Layout` 選同一個。
3. 每個片段的 `This Clip Is Part` 填不同的數字（第一個填 1、第二個填 2…）。
4. 主體不在格子中間時，調那個片段的 `Picture: What Goes In The Middle`。

`Slant`、`Gap` 這幾個值每個片段要設成一樣，不然格子會對不起來。設好一個之後，可以複製片段的屬性貼到其他片段，再改 `This Clip Is Part`。

| 參數 | 作用 |
|---|---|
| `Layout` | `2 Side By Side` 左右兩格、`2 Stacked` 上下兩格、`3 Side By Side` 左中右、`3 Stacked` 上中下、`4 In A Grid` 四宮格 |
| `This Clip Is Part` | 這個片段是第幾格。左右排列是由左到右，上下排列是由上到下，四宮格是左上、右上、左下、右下 |
| `Slant` | 分隔線傾斜的角度。四宮格只有直的那條會斜 |
| `Gap` | 格子之間的空隙 |
| `Gap Colour Opacity`、`Gap Colour` | 空隙要不要填色。0 是透明，會看到更下面軌道的東西（沒有東西就是黑的） |
| `Picture: What Goes In The Middle` | 這個片段的哪一點要放在格子正中間。預設是片段的中心 |
| `Picture: Zoom` | 格子裡的畫面放大或縮小 |
| `Appears By` | `Sliding In` 滑進來、`Fading In` 淡入 |
| `Slides In From` | 從哪邊滑進來。`Automatic`：左右排列的各格輪流從上、下進來，上下排列的輪流從左、右，四宮格各從自己的角落 |
| `Appear (seconds, 0 = already there)` | 出現花幾秒 |
| `Each Part Starts Later By (seconds)` | 第 2 格比第 1 格晚多久開始，第 3 格再晚一次 |
| `Leave (seconds, 0 = stays)` | 結尾原路退出花幾秒 |
| `Frame Rate Override` | 秒數算得不對時填時間軸的影格率，平常留 0 |

**注意**

- 格子比原畫面窄，所以畫面兩側一定會被切掉。把主體移到中間靠 `Picture: What Goes In The Middle`，不夠就再用 `Picture: Zoom` 縮小。縮得太小、原畫面蓋不滿格子時，露出來的地方是透明的。
- 預覽圖是用腳本把三份特效疊起來算的。在 Edit 頁面實際把三個片段疊起來這件事，沒有測過。
