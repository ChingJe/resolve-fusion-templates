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

共用工具（新範本都用這一套），放在 `scripts/` 最上層：

| 檔案 | 用途 |
|---|---|
| `lib.lua` | 建置腳本共用的函式：確認專案與時間軸、清空節點、自訂控制項、程序產生的測試畫面、算圖、匯出。另有 `L.cur`（清單目前輪到哪一行，時間清單或關鍵幀兩種模式）和 `L.inked`（把白色形狀上色並加兩層描邊） |
| `lab.lua` | 開啟（或建立）實驗用時間軸 `FX Lab`，裡面一個片段帶空的 Fusion 合成 |
| `macro.py` | 把 `lib.lua` 匯出的節點和規格包成巨集範本 |
| `check.lua` | 把範本貼進清空的實驗合成、接上測試畫面（`FX_SRC=media` 改接真實片段）、算圖 |
| `compose.lua` | 把同一個範本貼好幾份、各給不同設定、疊在測試畫面上算圖，用來看多個片段組合起來的樣子 |
| `sheet.py` | 畫格拼總覽圖 |
| `t.sh` | 測試用：跑一支建置腳本、算圖、拼總覽圖，一行完成 |
| `gif.py` | 把算好的畫格轉成 GIF |
| `previews.sh` | 一次重算 `previews/` 裡所有的 GIF（或只算指定的幾個），各範本用的設定和 `fixtures/` 裡的文字都寫在裡面 |

每個範本一支建置腳本，放在 `scripts/build/`，控制項清單也寫在裡面：

| 檔案 | 範本 | 類型 |
|---|---|---|
| `comicintro.lua` | Comic Intro，漫畫頁邊翻邊拉遠，退進標題的筆畫裡 | 特效 |
| `timeslice.lua` | Time Slice，畫面切成直條、每條延遲幾格 | 特效 |
| `videowall.lua` | Video Wall，拉遠成影片牆再推進下一段 | 轉場 |
| `photostack.lua` | Photo Stack，影片的幾個瞬間變成照片疊起來 | 特效 |
| `chapterbar.lua` | Chapter Bar，有章節名稱的進度條 | 標題 |
| `counter.lua` | Number Counter，數字跳動 | 標題 |
| `papertear.lua` | Paper Tear，前一段像紙一樣被撕掉 | 轉場 |
| `kinetic.lua` | Kinetic Lines，文字照時間清單一行行彈出 | 標題 |
| `barchart.lua` | Bar Chart，長條依序長出來的橫向長條圖 | 標題 |
| `punchzoom.lua` | Punch Zoom，在指定時間點推近，可加 RGB 分離等 | 特效 |
| `variety.lua` | Variety Caption，厚描邊的綜藝字卡，關鍵幀換句 | 標題 |
| `sidenote.lua` | Side Note，吐槽小字加手繪箭頭 | 標題 |
| `textlabel.lua` | Text Label，文字加自動貼合的外框，九種形狀，用來拼接 | 標題 |
| `reaction.lua` | Reaction Mark，怒氣、汗滴、問號、驚嘆號、集中線 | 標題 |
| `whippan.lua` | Whip Pan，甩鏡 | 轉場 |
| `zoomthrough.lua` | Zoom Through，衝進前一段、衝出來是後一段 | 轉場 |
| `stripewipe.lua` | Stripe Wipe，彩色色帶依序掃過 | 轉場 |
| `glitchcut.lua` | Glitch Cut，訊號不良式的轉場 | 轉場 |
| `glitchhits.lua` | Glitch Hits，在指定時間點故障一下 | 特效 |
| `subwindow.lua` | Sub Window，角落的子畫面 | 特效 |
| `spotlight.lua` | Spotlight，聚光和放大鏡 | 特效 |
| `freezeframe.lua` | Freeze Frame，停格介紹 | 特效 |
| `echo.lua` | Echo，殘影 | 特效 |
| `handmade.lua` | Handmade，定格動畫的手作感 | 特效 |
| `countdown.lua` | Countdown，倒數計時 | 標題 |
| `karaoke.lua` | Karaoke Caption，逐字填色的字幕 | 標題 |
| `hiddenword.lua` | Hidden Word，貼紙蓋住的詞到時間揭曉 | 標題 |

從 `whippan.lua` 開始的腳本用 `lib.lua` 的 `L.panel`（控制項寫成有順序的清單，自動產生匯出規格）、`L.feeds`（影像入口和轉場進度）、`L.ship`（匯出或測試算圖）。新範本照這個寫法，一支腳本可以短很多。另有 `L.glitch`（故障畫面的 `Custom`）、`L.hits`（時間點清單轉成強度）、`L.mirror`（畫面外鏡像補滿）。

一個範本從頭到尾的指令（在 `scripts/` 底下執行，`FU` 是 fuscript 的路徑）：

```bash
"$FU" -l lua lab.lua                       # 開實驗時間軸
"$FU" -l lua build/timeslice.lua           # 建置並算測試畫格到 out/
FX_SRC=media "$FU" -l lua build/timeslice.lua  # 改用真實片段再看一次（畫格不可進 git）
FX_EXPORT=1 "$FU" -l lua build/timeslice.lua   # 匯出節點與規格
python macro.py timeslice "../templates/Effects/Time Slice.setting"
FX_TEMPLATE="../templates/Effects/Time Slice.setting" FX_INPUTS=1 "$FU" -l lua check.lua
cmd.exe //c "..\\install.bat install nopause"          # 同步到 Resolve 的範本資料夾
```

**第一次使用**：把 `scripts/local.example.lua` 複製成 `scripts/local.lua`，填上實驗用的專案名稱、時間軸名稱、媒體池裡一個片段的名稱。這個檔案不進 git。`lib.lua` 會檢查 Resolve 目前開的專案和時間軸是不是這裡寫的那個，不是就拒絕執行，所以腳本不會誤改別的專案。也可以用環境變數 `FX_PROJECT`、`FX_TIMELINE`、`FX_MEDIA` 臨時指定。

腳本用自己所在的位置找 `lib.lua` 和輸出資料夾，repo 放在哪裡、從哪個資料夾執行都可以。`fuscript` 不在預設位置時設環境變數 `FUSCRIPT`，`ffmpeg` 不在 PATH 裡時設 `FFMPEG`。

預覽圖一律用 `lib.lua` 的 `testsource`（漸層、移動的球、轉動的橫條、畫格編號）當輸入，不用真實素材。畫格編號可以直接看出每一格取的是哪個時間點。

`FX_SRC=scenes` 會讓測試畫面每 40 格（`FX_SCENE` 可改）換一個場景：底色、球的顏色大小和路徑、橫條的顏色和位置都不同，共六種。同時顯示好幾個時間點的範本（Comic Intro、Photo Stack、Video Wall、Time Slice）要用這個，不然每一格看起來都一樣。

`previews/` 裡放的是 GIF（寬 480、每秒 12 格、整段 5 秒）。改了範本的外觀就跑 `./previews.sh 範本名稱` 重算那一個。



## 算圖測試的坑

- **不能只算單一畫格**。`comp:Render({Start=f, End=f})` 會把合成的算圖範圍改成那一格，所有用到 `comp.RenderStart`、`comp.RenderEnd` 的運算式都會算錯。永遠算完整範圍，算完用 `comp:SetAttrs({COMPN_RenderStart=..., COMPN_RenderEnd=...})` 設回去。
- **跳格要用 `StepRender = true, Steps = N`**。`Step = N` 會被忽略，整段全算。
- 跳格算圖有時回傳 `false`，但畫格其實都寫出來了，以檔案為準。
- 取樣的畫格可能剛好都落在動態模糊的瞬間，看起來全糊。換一組畫格，或挑邊緣最銳利的再判斷。
- 測試用的中文字串不要走環境變數，會被殼層弄亂。寫進 UTF-8 檔案，在腳本裡用 `io.open` 讀。
- `Saver` 的檔名前綴不要以數字結尾。`cj1.png` 加上畫格編號後不會是預期的 `cj10072.png`。

## Fusion 節點的坑

- **`Custom` 節點的三角函數用「度」**，`atan2` 回傳的也是度。輸入欄位上的 Lua 運算式則是弧度。把弧度寫進 Custom 會得到幾乎不變的值，症狀是圖案整片同色。
- `Custom` 只有 8 個中間變數。不夠用就串兩個：第一個把座標、亂數、邊緣距離存進 RGBA（上游 Background 要設 `Depth = 4` 用 float32），第二個負責上色。
- `Custom` 取樣第二張圖用 `getr2d(x, y)`、`getg2d`、`getb2d`，座標是 0 到 1。
- **自訂控制項**：設定 `tool.UserControls = {...}` 之後要 `tool = tool:Refresh()` 才會出現。把動畫驅動值集中放在一個控制節點上，其他節點用 `控制節點.欄位` 引用。
- **文字可以用運算式連動**：`TitleText.StyledText.Value`、`TitleText.Font`、`TitleText.Style`。
- **自動貼合文字的底框**：再放一個 Text+，設 `ElementShape1 = 2`（填滿邊框）、`Level1 = 0`（整段文字一個框），用 `ExtendHorizontal1`、`ExtendVertical1` 控制留白。
- **動畫用進度運算式，不用關鍵影格**：`P = (time - comp.RenderStart) / (comp.RenderEnd - comp.RenderStart)`，夾在 0 到 1。動畫會自動隨片段長度伸縮。
- **自訂控制項的 ID 會和節點原有的輸入撞名**。在 `Background` 上加一個叫 `Offset` 的控制項，讀到的是漸層的 Offset，症狀是數值永遠不變、沒有錯誤訊息。ID 加上前綴（`CntStart`、`SktAngle`）。
- `Custom` 的 `frac()` 遇到負數不會回到 0 到 1，取樣座標會跑到畫面外變黑。要平鋪時先加一個夠大的整數再取 `frac`。
- `Custom` 最多三張輸入圖，另有四個 `PointIn`（`p1x`、`p1y`…）可以當額外的數值輸入。
- 運算式可以是立即呼叫的匿名函式：`(function(t) return t*t*(3-2*t) end)(...)`，需要區域變數或字串處理時用這個。
- 文字輸入的運算式要回傳 `Text(...)`，讀其他節點的文字用 `節點.欄位.Value`。
- `Text+` 的對齊要設 `HorizontalLeftCenterRight`：`1` 是文字的尾端貼在 `Center`（靠右對齊），`-1` 是開頭貼在 `Center`（靠左對齊），`0` 置中。`HorizontalJustificationNew` 用腳本設定沒有效果。
- 巨集需要單一輸入點時，放一個不改任何設定的 `BrightnessContrast` 當入口，其他節點都接它。
- `tool:AddModifier("輸入ID", "修改器ID")` 可以掛修改器，再用 `tool.輸入:GetConnectedOutput():GetTool()` 取得它。
- `GetToolList(false)` 會連巨集裡面的節點一起列出來，要分辨就看 `tool.ParentTool`。
- **數量可調的元素**：節點數不能在執行時改變，所以照最大數量建好，用控制項決定用幾個。沒用到的那幾層把 `Merge` 的 `Blend` 設成 0。位置不要寫死，用運算式依序號和數量算出來（Photo Stack 用向日葵螺旋：角度 `k*2.39996`、半徑 `sqrt(k/n)`），再加一個種子控制項轉動整個排列。
- 小尺寸顯示的影像先用 `BetterResize` 縮小再接 `TimeStretcher`。接到全尺寸畫布的 `Merge` 時，`Size` 要乘上「畫布寬 ÷ 小圖寬」。
- **不限數量的清單用一個多行文字框**（`TEC_Lines` 設行數），在運算式裡用 `gmatch` 逐行拆。Chapter Bar 的章節清單就是這樣做的，每個需要結果的運算式各自呼叫同一段解析函式（建置腳本裡存成字串再嵌進去）。
- 自訂控制項可以是座標：`LINKID_DataType = "Point"`、`INPID_InputControl = "OffsetControl"`。一個運算式回傳 `Point(a, b)` 就能一次帶出兩個數，其他地方用 `.X`、`.Y` 讀。
- `Custom` 能收的數值總共十六個（8 個 `NumberIn` 加 4 個 `PointIn`）。不夠就再串一個 `Custom` 接著處理。
- 運算式裡可以呼叫 `comp:GetPrefs("Comp.FrameFormat.Rate")` 取得合成的影格率。
- **`Text+` 不會自動換字型**。字型沒有的字會變成方塊，`Open Sans` 就沒有中文。要顯示中文，預設字型用 `Microsoft JhengHei`。
- `comp:Paste()` 在有節點被選取時會自動多插一個 `Merge`。貼之前先呼叫 `comp:SetActiveTool(nil)` 和 `comp.CurrentFrame.FlowView:Select()`，貼完檢查有沒有多出來的節點。

## 影片輸入的坑

- 時間軸片段的 Fusion 合成，**時間單位是來源影片的影格**，不是時間軸的。48fps 的影片在 24fps 時間軸上放 5 秒，合成範圍是 0 到 235。所以翻頁速度之類的參數要用「整段幾次」來定義，不要用「每幾格一次」。
- 合成的**全域範圍涵蓋整支來源影片**（`comp.GlobalStart`、`comp.GlobalEnd`），算圖範圍才是修剪後的那一段。用 `TimeStretcher` 的 `SourceTime` 運算式可以取到修剪範圍外的畫面。
- 多格各播不同時間點的做法：先縮成小圖，接多個 `TimeStretcher`，再用 `Merge` 拼成一張圖集，交給 `Custom` 取樣。

## 轉場

- 轉場範本有兩個影像輸入：`MainInput1` 是前一段，`MainInput2` 是後一段。
- 內建轉場的進度來自 `AnimCurves` 修改器（ID 是 `LUTLookup`），`Source` 設成 `Transition` 時會在合成的算圖範圍內從 0 走到 1，範圍外夾住。在一般片段的合成裡也是同樣行為，所以可以在實驗合成裡測。
- 內建轉場用的是 `GroupOperator`，我們的 Video Wall 用 `MacroOperator`，還沒在 Edit 頁面實際拖過。
- 開頭和結尾那一格要和原片段完全相同，不然接點會跳。在 `Custom` 裡用 `if(進度 <= 0, 原圖A, if(進度 >= 1, 原圖B, ...))` 直接輸出原圖。

## 標題

- 標題沒有影像輸入，輸出要帶透明度。控制節點的 `Background` 記得把 Alpha 設成 0。
- 進度同樣用 `comp.RenderStart`、`comp.RenderEnd` 算，標題片段拉多長動畫就走多久。

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
