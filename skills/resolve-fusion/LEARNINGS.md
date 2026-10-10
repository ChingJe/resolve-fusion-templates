# 學習記錄

新發現先記在這裡，穩定後整理進 [SKILL.md](SKILL.md)。最新的日期放最上面。

## 2026-10-10

### 尚未驗證

下次有機會就測，測完把結果寫進 SKILL.md。

- 這天做的五個範本（Time Slice、Video Wall、Photo Stack、Chapter Bar、Number Counter）都只驗證到「貼進 Fusion 合成能載入、算圖正確」。從 Edit 頁面的特效庫拖到時間軸上，一個都還沒試過。
- Chapter Bar 用時間寫章節（`1:25 名稱`）時，要靠合成的影格率把秒換成影格。在實驗用的片段合成裡換算正確（47.95 fps、1 秒落在第 48 格）。標題從 Edit 頁面拖進時間軸後，讀到的影格率和時間單位是不是時間軸的，還沒試過。不對的話用 `Frame Rate Override` 手動填，或改用百分比寫法。
- Video Wall 是第一個轉場。不確定 `MacroOperator` 包的轉場能不能從特效庫拖到剪接點上；不行的話把最外層改成 `GroupOperator`。
- Video Wall 的其他螢幕會取前一段更早、後一段更晚的畫格。轉場合成裡拿不拿得到這些畫格不知道，拿不到的話螢幕會是黑的或定格，把 `Time Offset` 調成 0 可以避開。
- Photo Stack 的靜態照片取自整支來源影片（用 `Stills From`、`Stills To` 控制範圍），和影片版 Comic Intro 有同樣的疑問。

- 影片版範本從 Edit 頁面的 Effects 拖到片段上時，能不能取到片段修剪範圍外的畫面。目前只驗證過「進片段的 Fusion 頁面貼上巨集」這條路。
- 複合片段修剪後，全域範圍是否仍涵蓋整個複合片段。
- 圖案版範本從 Edit 頁面的 Titles 拖進時間軸是否正常。
- 變速過的片段，合成時間和來源影格的對應關係。

### 已知瑕疵

- 樞紐點不在字母筆畫上時，拉遠途中樞紐位置會短暫出現一個半透明小方塊。那是正在淡出的「頁面視窗」。可以試著讓 `WinFade` 更早結束，在視窗還大的時候就淡完。

### 提新範本前先查內建的

- Resolve 內建的 Fusion 範本打包在 `C:\Program Files\Blackmagic Design\DaVinci Resolve\Fusion\Templates\Templates.drfx`，是 zip 檔。用 `unzip -Z1 Templates.drfx | grep "^Edit/"` 可以列出所有內建的轉場、特效、標題、產生器名稱。
- 提議做新範本前先對這份清單。故障、磁磚、雜訊溶解、甩鏡、鏡頭震動、漫畫濾鏡（`Comic Book`）、集中線（`Comic Speed Lines`）、擬聲字（`Pow!!`）內建都有，不必重做。
- Resolve FX（Halftone、Analog Damage 之類）不在這個檔案裡，沒辦法用同樣方式列出。

### 效能

- 在 `Custom` 裡對鄰近像素多次取樣很慢。做過一個線稿特效（每像素取樣 12 次），1080p 一格約 0.8 秒，Edit 頁面無法即時播放。使用者看過後不喜歡，已移除；以後要做邊緣偵測先找內建節點。

- Photo Stack 算圖偏慢：12 層 `Transform` 開動態模糊，加上每張照片各自播放影片，1080p 一格大約 1.2 到 1.5 秒。要快就關 `Motion Blur` 或關 `Photos Play As Video`。

### Resolve 沒回應時

- 做完範本後，`OpenPage("edit")`、`SetCurrentTimeline()`、`GetCurrentPage()` 都不回傳值，時間軸停在 `FX Lab` 切不回去。前面的建置和算圖都正常。原因沒查出來，多半是 Resolve 跳了對話框。遇到就不要重試，請使用者看一下畫面。

### 雜項
- 在 Git Bash 的 heredoc 裡跑 Python 改檔時，字串裡的 `\n` 會被吃成真的換行，比對不到原文。含跳脫字元的修改改用編輯工具。

- 在 Git Bash 的 heredoc 裡寫 Lua 字串，Windows 路徑的反斜線會出問題，一律用正斜線（`D:/davinci/...`）。
- `timeline:InsertFusionTitleIntoTimeline("名稱")` 在範本尚未被掃描到時回傳 nil，不能拿來當作「不重啟就測試新範本」的方法。
- `scripts/` 裡舊的 Comic Intro 腳本是從暫存資料夾搬進來的，路徑已改成 `D:/davinci/scripts/`，但搬完後還沒重新跑過。新的六支建置腳本都是在 `scripts/` 裡實際跑過的。
- `testsss` 專案裡多了一個實驗用時間軸 `FX Lab`，建置腳本都在那裡面動。合成已清空，不需要時可以刪掉，之後跑 `lab.lua` 會重建。

## 2026-10-10

### 不規則的邊緣

- 要一條固定不變的不規則邊（Paper Tear 的撕邊），放一張靜止的 `FastNoise`（`SeetheRate = 0`、`Depth = 4`）接到 `Custom` 的第三張圖，沿著邊的方向取一條線：`getr3b(0.27, 沿邊座標)`。回傳值在 0.5 上下，減 0.5 再乘幅度就是邊的偏移量。換一個 x 位置取樣就是另一條互不相關的曲線，紙芯寬度用的是這個。`Seethe` 的數值當種子，改了就換一個形狀。
- `Custom` 裡有 `w`、`h` 兩個變數是影像的寬高，要算長寬比不必另外傳數值進去。
- 旋轉座標時 y 要先乘 `h/w`，兩個方向才是同一個單位，不然斜向的邊會被壓扁。

### 撕紙要怎麼動才自然

- 第一版 Paper Tear 是一條形狀固定的撕邊橫掃過畫面，使用者覺得不自然：真的撕紙時，撕邊的形狀是留在紙上不動的。改成撕裂線固定在紙上，裂口沿著線從一頭走到另一頭，後面留下一道窄縫，接著兩半不變形地往兩邊滑開。
- 試過讓兩半位移量隨「裂口經過多久」線性增加（楔形張開），結果是剪切變形，畫面裡的圓會被拉成橢圓，不能用。位移只能有很小一段是漸變的（裂口尖端），其餘要整塊一起動。
- 被移開的那一半取樣原圖時座標會超出 0 到 1，要自己判斷並改顯示後一段，不然是黑的。
- `Custom` 的中間變數是照編號依序算的，`i1` 的式子裡用到 `i2` 會整張變黑，沒有錯誤訊息。
- 這一版每個像素的式子很長，1080p 一格約 0.6 秒，Edit 頁面不會即時播放。

### 尚未驗證

- Paper Tear、Kinetic Lines 和其他範本一樣，只在 Fusion 頁面的實驗合成裡驗證過（巨集貼得回來、控制項齊全、算圖正確），還沒從 Edit 頁面拖過。
- Kinetic Lines 的 `Pop Frames`、`Fade Out Frames` 是以合成的影格計。標題放上時間軸後合成的影格率是否等於時間軸的，還沒確認。
