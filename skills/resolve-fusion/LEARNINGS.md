# 學習記錄

新發現先記在這裡，穩定後整理進 [SKILL.md](SKILL.md)。最新的日期放最上面。

## 2026-10-10

### 尚未驗證

下次有機會就測，測完把結果寫進 SKILL.md。

- 這天做的五個範本（Time Slice、Video Wall、Photo Stack、Chapter Bar、Number Counter）都只驗證到「貼進 Fusion 合成能載入、算圖正確」。從 Edit 頁面的特效庫拖到時間軸上，一個都還沒試過。
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

### Resolve 沒回應時

- 做完範本後，`OpenPage("edit")`、`SetCurrentTimeline()`、`GetCurrentPage()` 都不回傳值，時間軸停在 `FX Lab` 切不回去。前面的建置和算圖都正常。原因沒查出來，多半是 Resolve 跳了對話框。遇到就不要重試，請使用者看一下畫面。

### 雜項

- 在 Git Bash 的 heredoc 裡寫 Lua 字串，Windows 路徑的反斜線會出問題，一律用正斜線（`D:/davinci/...`）。
- `timeline:InsertFusionTitleIntoTimeline("名稱")` 在範本尚未被掃描到時回傳 nil，不能拿來當作「不重啟就測試新範本」的方法。
- `scripts/` 裡舊的 Comic Intro 腳本是從暫存資料夾搬進來的，路徑已改成 `D:/davinci/scripts/`，但搬完後還沒重新跑過。新的六支建置腳本都是在 `scripts/` 裡實際跑過的。
- `testsss` 專案裡多了一個實驗用時間軸 `FX Lab`，建置腳本都在那裡面動。合成已清空，不需要時可以刪掉，之後跑 `lab.lua` 會重建。
