# Photo Stack

特效 · 檔案 `templates/Effects/Photo Stack.setting` · [回到總覽](../../README.md)

影片的幾個片刻變成照片，一張張滑到桌上，最後一張放大成全畫面。

![Photo Stack](../../previews/photo-stack.png)

**用法**：最後一張照片就是片段本身，它放大成全畫面後接回影片。怎麼接有兩種做法，用 `Last Photo` 選。

當開場用（預設，`Waits On The First Frame`）：最後一張照片停在第一格等，放大後正片才從頭開始播，正片一格都不會少。

1. 在時間軸上把正片複製一份，放在正片的正前方。
2. 把前面那一份的尾端往前剪，留下開場要的長度（例如 5 秒）。開頭不要動，它要和正片從同一格開始。
3. 把 Photo Stack 拖到前面這一小段上。
4. 把這一小段的聲音靜音或換成音樂，不然正片開始後同一段聲音會再播一次。

直接套在片段開頭（`Plays Along`）：先把片段開頭切出想要的長度，再拖到那一段上。最後一張照片跟著片段一起播，放大時影片已經播到這一段的結尾，所以這一段的內容只會在小照片裡出現。

| 參數 | 作用 |
|---|---|
| `Last Photo` | 最後一張照片顯示什麼：`Waits On The First Frame` 停在這一段的第一格、`Plays Along` 跟著片段播、`Waits On The Last Frame` 停在這一段的最後一格 |
| `Photo Count` | 照片張數，1 到 12 |
| `Slide Time` | 每張滑進來花多久。調大，同時在空中的照片就多 |
| `Stack Complete At` | 整疊在片段的哪個位置排完，之後開始放大 |
| `Layout Seed` | 換一種排法 |
| `Photos Play As Video` | 照片播影片還是定格 |
| `Stills From`、`Stills To` | 其他照片從來源影片的哪個範圍取 |
| `Photo Size`、`Spread`、`Tilt` | 照片大小、散開程度、傾斜程度 |
| `Border`、`Corner Roundness`、`Paper Color` | 白邊的寬度、圓角、顏色 |
| `Shadow`、`Shadow Softness`、`Shadow Distance` | 陰影的濃度、柔和度、距離 |
| `Motion Blur` | 滑動時的動態模糊 |
| `Backdrop Brightness`、`Backdrop Blur` | 背景的亮度與模糊，背景是片段本身的畫面 |

**注意**

- `Waits On The Last Frame` 用在把片段開頭切一段下來套特效、但不想讓最後那張照片動的時候：它停在這一段的最後一格，後面那一段接著播。
- 背景那層模糊的畫面不受 `Last Photo` 影響，一直是片段正在播的畫面。

- `Stills From`、`Stills To` 是以整支來源影片的比例計，不是剪進時間軸的那一段。
- 算圖偏慢，在 Edit 頁面不會即時播放。嫌慢先關 `Motion Blur`，再不行關 `Photos Play As Video`。
