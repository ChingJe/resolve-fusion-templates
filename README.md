# resolve-fusion-templates

DaVinci Resolve 的 Fusion 範本：特效、轉場、標題。裝好之後會出現在 Edit 頁面的特效庫，拖到時間軸上就能用，參數在 Inspector 調整。

在 Resolve 21 Studio（Windows）上製作。

## 範本

| 範本 | 類型 | 說明 |
|---|---|---|
| [Comic Intro](#comic-intro) | 標題 | 漫畫頁快速翻動，鏡頭從字裡拉遠，最後定格成紅框白字的標題 |
| [Comic Intro Video](#comic-intro) | 特效 | 同上，但每個漫畫格播的是片段裡不同時間點的畫面 |
| [Time Slice](#time-slice) | 特效 | 畫面切成直條，每條比隔壁晚幾格 |
| [Photo Stack](#photo-stack) | 特效 | 影片的幾個片刻變成照片滑到桌上，最後一張放大成全畫面 |
| [Video Wall](#video-wall) | 轉場 | 拉遠成一面影片牆，橫移，再推進下一段 |
| [Chapter Bar](#chapter-bar) | 標題 | 有章節的進度條 |
| [Number Counter](#number-counter) | 標題 | 數字跳動 |

預覽圖的輸入是程序產生的測試畫面，畫面上的數字是畫格編號，用來看出每一格取的是哪個時間點。

### Comic Intro

圖案版，漫畫格裡是程序畫出來的圖案：

![Comic Intro](previews/comic-intro.png)

影片版，每個漫畫格播的是片段裡不同時間點的畫面：

![Comic Intro Video](previews/comic-intro-video.png)

整個片段多長，動畫就走多久。影片版要套在片段上，所以先把開頭切出想要的長度再套。

主要參數：文字、字型、文字大小與顏色、底框顏色與留白、翻頁次數、起始放大倍率、拉遠的中心點。

### Time Slice

![Time Slice](previews/time-slice.png)

主要參數：`Slices`（條數，2 到 16）、`Delay Per Slice`（每條延遲幾格）、`Horizontal Strips`（改成橫條）、`From Center`（從中間往兩邊延遲）、`Reverse`、`Edge Softness`。

畫面動得慢時效果不明顯，把 `Delay Per Slice` 調大。

### Photo Stack

![Photo Stack](previews/photo-stack.png)

和 Comic Intro 一樣，動畫長度等於片段長度，先切出開頭那一段再套。最後一張照片就是片段本身正在播的畫面，所以放大之後可以無縫接回原片。

| 參數 | 作用 |
|---|---|
| `Photo Count` | 照片張數，1 到 12 |
| `Slide Time` | 每張滑進來花多久。調大，同時在空中的照片就多 |
| `Stack Complete At` | 整疊在片段的哪個位置排完，之後開始放大 |
| `Layout Seed` | 換一種排法 |
| `Photos Play As Video` | 照片播影片還是定格 |
| `Stills From`、`Stills To` | 其他照片從來源影片的哪個範圍取，以整支來源影片的比例計 |
| `Photo Size`、`Spread`、`Tilt` | 照片大小、散開程度、傾斜程度 |
| `Border`、`Corner Roundness`、`Paper Color` | 白邊 |
| `Shadow`、`Shadow Softness`、`Shadow Distance` | 陰影 |
| `Motion Blur` | 動態模糊 |
| `Backdrop Brightness`、`Backdrop Blur` | 背景，用的是片段本身模糊壓暗後的畫面 |

算圖偏慢。嫌慢先關 `Motion Blur`，再不行關 `Photos Play As Video`。

### Video Wall

![Video Wall](previews/video-wall.png)

主要參數：`Pull Back`（拉多遠）、`Gap`（螢幕之間的間隔）、`Time Offset`（其他螢幕和主畫面差幾格）、`Other Screens Brightness`。

牆上其他螢幕顯示的是前一段較早、後一段較晚的畫面。如果出現黑色螢幕，把 `Time Offset` 調成 0。

### Chapter Bar

![Chapter Bar](previews/chapter-bar.png)

放在影片上方的軌道，拉到和影片一樣長。進度跟著這個標題片段的長度走。

章節寫在 `Chapters` 文字框裡，一行一章，和 YouTube 說明欄的寫法相同：

```
0:00 開場
1:25 第一段
4:10 第二段
9:30 結尾
```

每行開頭可以是：

| 寫法 | 例子 | 說明 |
|---|---|---|
| 時間 | `1:25`、`1:02:03`、`0:07.5`、`42` | 從標題片段開頭算起，秒可以帶小數，會四捨五入到最近的一格 |
| 影格數 | `120f` | 精確到格 |
| 比例 | `25%` | 片段長度的百分比 |

三種可以混用。開頭不是這三種的行會被略過；順序寫亂了會自動排好。

章節名稱不限數量，進度條上的缺口最多畫 19 個，也就是 20 章。超過的章節名稱照常切換，只是條上不再切開。

換章的時間點不對時，在 `Frame Rate Override` 填上時間軸的影格率。

其他參數：進度條與底條的顏色、底條透明度、位置、粗細、左右留白、缺口寬度、圓點大小、是否顯示名稱、名稱的字型、大小、顏色。名稱的預設字型是微軟正黑體；換字型時要選有中文字的，不然中文會變成方塊。

### Number Counter

![Number Counter](previews/number-counter.png)

主要參數：`Start Value`、`End Value`、`Decimals`（小數位數）、`Thousands Separator`（千分位）、`Prefix`、`Suffix`（前後綴，例如 `$`、`%`）、`Count Finishes At`（在片段的哪個位置數完）、`Pop`（數完時彈一下的幅度）、字型、大小、顏色、位置。

## 安裝

把 `templates/` 裡的 `.setting` 檔複製到 Resolve 的範本資料夾，依類型放進對應的子資料夾：

```
%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Templates\Edit\
```

| 檔案 | 子資料夾 | 在特效庫的位置 |
|---|---|---|
| `Comic Intro.setting`、`Chapter Bar.setting`、`Number Counter.setting` | `Titles` | Titles → Fusion Titles |
| `Comic Intro Video.setting`、`Time Slice.setting`、`Photo Stack.setting` | `Effects` | Effects → Fusion Effects |
| `Video Wall.setting` | `Transitions` | Video Transitions → Fusion Transitions |

子資料夾不存在就自己建。Resolve 只在啟動時掃描這個資料夾，放進去之後要重啟才會出現。

移除時把檔案刪掉再重啟。

## 已知限制

- 這些範本都是在 Fusion 頁面的合成裡驗證的：能載入、算圖結果正確。從 Edit 頁面的特效庫拖到時間軸上這條路還沒有逐一實測。
- Comic Intro Video 和 Photo Stack 取的是整支來源影片的畫面，不只是剪進時間軸的那一段。
- Photo Stack 算圖慢，在 Edit 頁面不會即時播放，要等算圖快取。

## 自己改範本

範本不是手動拉節點做的，是用腳本在執行中的 Resolve 裡建出節點圖，算圖檢查，再匯出打包。每個範本在 `scripts/` 裡有一支建置腳本，控制項清單也寫在裡面。

需要 Resolve Studio（免費版不開放外部腳本），並在偏好設定裡允許本機腳本。

做法、指令和踩過的坑都寫在 [skills/resolve-fusion/SKILL.md](skills/resolve-fusion/SKILL.md)，還沒整理的新發現在 [LEARNINGS.md](skills/resolve-fusion/LEARNINGS.md)。

## 結構

| 路徑 | 內容 |
|---|---|
| `templates/` | 範本檔（`.setting`） |
| `previews/` | 預覽圖 |
| `scripts/` | 建置、匯出、打包、驗證用的腳本 |
| `skills/resolve-fusion/` | 做法文件與學習記錄 |
