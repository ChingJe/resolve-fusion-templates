# 學習記錄

新發現先記在這裡，穩定後整理進 [SKILL.md](SKILL.md)。最新的日期放最上面。

## 2026-10-10

### 尚未驗證

下次有機會就測，測完把結果寫進 SKILL.md。

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

### 雜項

- 在 Git Bash 的 heredoc 裡寫 Lua 字串，Windows 路徑的反斜線會出問題，一律用正斜線（`D:/davinci/...`）。
- `timeline:InsertFusionTitleIntoTimeline("名稱")` 在範本尚未被掃描到時回傳 nil，不能拿來當作「不重啟就測試新範本」的方法。
- `scripts/` 裡的腳本是從暫存資料夾搬進來的，路徑已改成 `D:/davinci/scripts/`，但搬完後還沒重新跑過。
