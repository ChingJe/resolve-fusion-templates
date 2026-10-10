# Photo Stack

特效 · 檔案 `templates/Effects/Photo Stack.setting` · [回到總覽](../../README.md)

影片的幾個片刻變成照片，一張張滑到桌上，最後一張放大成全畫面。

![Photo Stack](../../previews/photo-stack.gif)

**用法**：前面幾張照片先疊上來，最後一張才是正片。它在 `Last Photo Arrives After` 設定的秒數（預設 2 秒）飛進來，觀眾從這一刻才第一次看到正片；之後它放大成全畫面，直接接到後面的片段，中間沒有斷點。

所以切法是「從正片想開始的那一格，往前數 2 秒」：

1. 找到正片要開始的那一格，往前 2 秒切一刀。
2. 再往後切一刀，切出開場要的長度（建議 4 到 6 秒）。
3. 把 Photo Stack 拖到這一段上。

這一段開頭的 2 秒不會出現在任何一張照片裡，只會變成很暗很糊的背景，所以那 2 秒拍到什麼都沒關係。

正片就是從來源影片的第一格開始、前面沒有多的 2 秒時，改用另一種做法：把正片複製一份放在它正前方，尾端剪成開場的長度，套上特效，`Last Photo` 選 `Plays, Then Rewinds To The First Frame` 或 `Waits On The First Frame`。這一小段的聲音記得靜音。

| 參數 | 作用 |
|---|---|
| `Last Photo Arrives After` | 最後一張照片在這一段開始後多久飛進來，其他照片會在這之前排完。可以寫秒（`2`、`1.5`）、分秒（`0:02.5`）、格數（`48f`）或這一段的比例（`40%`），和[時間清單的寫法](../time-list.md)相同。留空或寫 0 就改用 `Stack Complete At` 決定 |
| `Frame Rate Override` | 用秒寫而且時間點不對時，填上正確的影格率。0 是自動。用格數或比例寫的不受影響 |
| `Last Photo` | 最後一張照片播什麼。`Plays Along`：跟著片段播，接點無縫。`Plays, Then Rewinds To The First Frame`：飛進來時從這一段的第一格開始播，放大時倒帶回第一格。`Waits On The First Frame`、`Waits On The Last Frame`：停在第一格或最後一格 |
| `Photo Count` | 照片張數，1 到 12 |
| `Slide Time` | 每張滑進來花多久。調大，同時在空中的照片就多 |
| `Stack Complete At` | 整疊在片段的哪個位置排完，之後開始放大。只有 `Last Photo Arrives After` 設成 0 時才有作用 |
| `Layout Seed` | 換一種排法 |
| `Photos Play As Video` | 照片播影片還是定格 |
| `Stills From`、`Stills To` | 其他照片從來源影片的哪個範圍取 |
| `Photo Size`、`Spread`、`Tilt` | 照片大小、散開程度、傾斜程度 |
| `Border`、`Corner Roundness`、`Paper Color` | 白邊的寬度、圓角、顏色 |
| `Shadow`、`Shadow Softness`、`Shadow Distance` | 陰影的濃度、柔和度、距離 |
| `Motion Blur` | 滑動時的動態模糊 |
| `Backdrop` | 照片底下的背景是什麼。`This Clip, Playing` 片段本身、照常播放；`This Clip, Frozen` 片段的某一格、不會動；`This Clip, Slowed Down` 片段本身、放慢播；`Colours` 不用影片，上下兩個顏色的漸層 |
| `Backdrop: Frozen At` | 選 `Frozen` 時停在片段的哪裡，0 是開頭、1 是結尾、0.5 是正中間 |
| `Backdrop: Slowed Down To` | 選 `Slowed Down` 時的速度，0.3 是原速的三成 |
| `Backdrop Brightness`、`Backdrop Blur` | 背景的亮度與模糊。選 `Colours` 時這兩個沒有作用 |
| `Backdrop Colour: Top`、`Backdrop Colour: Bottom` | 選 `Colours` 時漸層上緣和下緣的顏色。兩個設成一樣就是純色 |

**注意**

- `Last Photo Arrives After` 最多只會用到這一段長度的六成，再長就擠不下放大的時間。這一段太短（例如 3 秒）而時間寫 2 秒時，照片實際飛進來的時間會比設定的早，接點還是無縫，但第一眼看到的不是你算好的那一格。把這一段拉長，或把秒數調小。
- 用秒寫的時間是用來源影片的影格率換算成格數的；`48f` 這種寫法數的是來源影片的格，不是時間軸的格。來源和時間軸影格率不同時，用秒寫比較不會錯。變速過的片段沒有測過。
- `Plays, Then Rewinds To The First Frame` 會讓觀眾先看到正片開頭幾秒，再倒回去。
- 背景那層模糊的畫面不受 `Last Photo` 影響，一直是片段正在播的畫面。

- `Stills From`、`Stills To` 是以整支來源影片的比例計，不是剪進時間軸的那一段。
- 算圖偏慢，在 Edit 頁面不會即時播放。嫌慢先關 `Motion Blur`，再不行關 `Photos Play As Video`。
