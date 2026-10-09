---
name: resolve-fusion
description: 在使用者正在執行的 DaVinci Resolve Studio 裡，用腳本 API 建立、測試、打包 Fusion 特效／轉場／標題範本。工作牽涉到 Resolve、Fusion 節點、.setting 範本、fuscript，或要修改這個儲存庫的 templates/ 與 scripts/ 時使用。
---

# 用腳本操作 Resolve 製作 Fusion 範本

這份文件記錄「怎麼做」和「踩過的坑」。每次工作學到新東西，照最後一節的規則寫回來。

## 基本原理

不碰滑鼠鍵盤，也看不到 Resolve 畫面。全部透過 Resolve Studio 的腳本 API：

1. 寫一支 Lua 腳本。
2. 用 `"C:\Program Files\Blackmagic Design\DaVinci Resolve\fuscript.exe" -l lua <腳本>` 執行，它會連上執行中的 Resolve。
3. 腳本呼叫 API，結果用 `print` 印回來。

```lua
local resolve = bmd.scriptapp("Resolve")
local comp = resolve:Fusion():GetCurrentComp()
local t = comp:AddTool("TextPlus", -2, -2)
t:SetInput("StyledText", "YOUR TITLE")
t.Size:SetExpression("ComicCtrl.TextSize * ComicCtrl.Zoom")
```

前提：Studio 版、Resolve 開著、偏好設定允許本機外部腳本。

## 開工前一定要先確認

- **目前開的是哪個專案**。使用者中途切換專案，腳本就會改到別的專案。每次執行會改動內容的腳本前，先印出 `GetCurrentProject():GetName()` 核對。
- **Resolve 是否停在專案管理器**。停在那裡時 `GetCurrentPage()` 不回傳值、建不了時間軸，要先開啟或建立專案。

## 製作循環

1. 寫建置腳本，從頭建出整張節點圖。先刪掉舊節點再建，方便反覆執行；保留 `MediaIn`、`MediaOut`、`AudioDisplay` 不刪。
2. 臨時加 `BetterResize`（640×360）和 `Saver`（PNG），算圖後刪掉。
3. 用 `scripts/sheet.py` 把畫格拼成總覽圖，讀圖檢查。
4. 改腳本，重跑，直到畫面正確。
5. 匯出並包成巨集（見「打包成範本」），貼回合成裡再算一次，確認巨集能載入。

現成的腳本：

| 檔案 | 用途 |
|---|---|
| `build.lua` | 圖案版 Comic Intro 的節點圖 |
| `vbuild.lua` | 影片版，每個漫畫格播輸入片段的不同時間點 |
| `export.lua`、`vexport.lua` | 把目前節點圖傾印成設定文字 |
| `wrap.py`、`vwrap.py` | 包成 `MacroOperator` 並開出 Inspector 參數 |
| `validate.lua`、`vvalidate.lua` | 把巨集貼回合成、算圖、再清掉 |
| `sheet.py` | 畫格拼總覽圖 |
| `pivot.py` | 找出文字筆畫最深處，當作拉遠的樞紐點 |

## 算圖測試的坑

- **不能只算單一畫格**。`comp:Render({Start=f, End=f})` 會把合成的算圖範圍改成那一格，所有用到 `comp.RenderStart`、`comp.RenderEnd` 的運算式都會算錯。永遠算完整範圍，算完用 `comp:SetAttrs({COMPN_RenderStart=..., COMPN_RenderEnd=...})` 設回去。
- **跳格要用 `StepRender = true, Steps = N`**。`Step = N` 會被忽略，整段全算。
- 跳格算圖有時回傳 `false`，但畫格其實都寫出來了，以檔案為準。
- 取樣的畫格可能剛好都落在動態模糊的瞬間，看起來全糊。換一組畫格，或挑邊緣最銳利的再判斷。

## Fusion 節點的坑

- **`Custom` 節點的三角函數用「度」**，`atan2` 回傳的也是度。輸入欄位上的 Lua 運算式則是弧度。把弧度寫進 Custom 會得到幾乎不變的值，症狀是圖案整片同色。
- `Custom` 只有 8 個中間變數。不夠用就串兩個：第一個把座標、亂數、邊緣距離存進 RGBA（上游 Background 要設 `Depth = 4` 用 float32），第二個負責上色。
- `Custom` 取樣第二張圖用 `getr2d(x, y)`、`getg2d`、`getb2d`，座標是 0 到 1。
- **自訂控制項**：設定 `tool.UserControls = {...}` 之後要 `tool = tool:Refresh()` 才會出現。把動畫驅動值集中放在一個控制節點上，其他節點用 `控制節點.欄位` 引用。
- **文字可以用運算式連動**：`TitleText.StyledText.Value`、`TitleText.Font`、`TitleText.Style`。
- **自動貼合文字的底框**：再放一個 Text+，設 `ElementShape1 = 2`（填滿邊框）、`Level1 = 0`（整段文字一個框），用 `ExtendHorizontal1`、`ExtendVertical1` 控制留白。
- **動畫用進度運算式，不用關鍵影格**：`P = (time - comp.RenderStart) / (comp.RenderEnd - comp.RenderStart)`，夾在 0 到 1。動畫會自動隨片段長度伸縮。
- `comp:Paste()` 在有節點被選取時會自動多插一個 `Merge`。貼之前先呼叫 `comp:SetActiveTool(nil)` 和 `comp.CurrentFrame.FlowView:Select()`，貼完檢查有沒有多出來的節點。

## 影片輸入的坑

- 時間軸片段的 Fusion 合成，**時間單位是來源影片的影格**，不是時間軸的。48fps 的影片在 24fps 時間軸上放 5 秒，合成範圍是 0 到 235。所以翻頁速度之類的參數要用「整段幾次」來定義，不要用「每幾格一次」。
- 合成的**全域範圍涵蓋整支來源影片**（`comp.GlobalStart`、`comp.GlobalEnd`），算圖範圍才是修剪後的那一段。用 `TimeStretcher` 的 `SourceTime` 運算式可以取到修剪範圍外的畫面。
- 多格各播不同時間點的做法：先縮成小圖，接多個 `TimeStretcher`，再用 `Merge` 拼成一張圖集，交給 `Custom` 取樣。

## 打包成範本

1. 用 `bmd.writestring(comp:CopySettings(tools))` 取得設定文字。
2. 取出 `Tools = ordered() { ... }` 的內容，包進 `MacroOperator`，用 `InstanceInput` 開出參數。顏色的 R、G、B 用同一個 `ControlGroup`。
3. 有影像輸入的巨集，要把內部指向 `MediaIn1` 的連線拿掉，改用 `MainInput1 = InstanceInput {...}`。
4. 範本放到 `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Templates\Edit\` 底下的 `Titles`、`Generators`、`Transitions` 或 `Effects`。
5. **Resolve 只在啟動時掃描範本資料夾**，新範本要重啟才會出現。

## 做不到、要請使用者做的事

- 看 Resolve 的介面、關掉跳出的對話框。指令突然不回傳值時，通常就是有對話框擋著。
- 把特效拖到片段上、重啟 Resolve、刪除專案。
- `SaveProject()` 可能不回傳值，無法確認是否存檔，請使用者按 Ctrl+S。

## 持續記錄

每次工作結束前，把新學到的事寫進 [LEARNINGS.md](LEARNINGS.md)，一則一段，歸在當天日期底下。標準：

- 是下次會再遇到的事，不是這次任務的流水帳。
- 寫明症狀、原因、做法，讓沒看過那次對話的人也能照做。
- 發現舊的記錄有錯，直接改掉或刪除，不要只在後面補一句。

某一則已經穩定、而且屬於上面某個章節時，把它整理進本文，並從 LEARNINGS.md 移除。
