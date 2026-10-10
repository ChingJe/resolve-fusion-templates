# resolve-fusion-templates

DaVinci Resolve 的 Fusion 範本：特效、轉場、標題。裝好之後會出現在 Edit 頁面的特效庫，拖到時間軸上就能用，參數在 Inspector 調整。

在 Resolve 21 Studio（Windows）上製作。

## 範本

依用途分成四類。點範本名稱看預覽圖、用法和完整的參數說明。

### 開場

把影片的開頭做成一段有設計感的片頭。

| 範本 | 類型 | 說明 |
|---|---|---|
| [Comic Intro](docs/templates/comic-intro.md) | 標題 | 漫畫頁快速翻動，鏡頭從字裡拉遠，最後定格成紅框白字的標題 |
| [Comic Intro Video](docs/templates/comic-intro-video.md) | 特效 | 同上，但每個漫畫格播的是片段裡不同時間點的畫面 |
| [Photo Stack](docs/templates/photo-stack.md) | 特效 | 影片的幾個片刻變成照片滑到桌上，最後一張放大成全畫面 |

### 強調與節奏

套在片段上，讓畫面在某些時刻更有力道。

| 範本 | 類型 | 說明 |
|---|---|---|
| [Punch Zoom](docs/templates/punch-zoom.md) | 特效 | 在指定的時間點或照拍子推近再彈回，可加 RGB 分離、模糊、震動、閃白 |
| [Time Slice](docs/templates/time-slice.md) | 特效 | 畫面切成直條，每條比隔壁晚幾格，動作像波浪一樣掃過去 |

### 轉場

放在兩個片段的交界。

| 範本 | 類型 | 說明 |
|---|---|---|
| [Paper Tear](docs/templates/paper-tear.md) | 轉場 | 前一段像紙一樣被撕成兩半拉開，露出後一段 |
| [Video Wall](docs/templates/video-wall.md) | 轉場 | 拉遠成一面影片牆，橫移，再推進下一段 |

### 文字與資訊

疊在影片上方的軌道，背景透明。

| 範本 | 類型 | 說明 |
|---|---|---|
| [Kinetic Lines](docs/templates/kinetic-lines.md) | 標題 | 一行行文字照寫好的時間彈出來 |
| [Number Counter](docs/templates/number-counter.md) | 標題 | 數字從一個值跳到另一個值 |
| [Bar Chart](docs/templates/bar-chart.md) | 標題 | 橫向長條圖，長條依序長出來，數字跟著跳 |
| [Chapter Bar](docs/templates/chapter-bar.md) | 標題 | 有章節名稱的進度條 |

預覽圖的輸入是程序產生的測試畫面。畫面上的數字是畫格編號，用來看出每一格取的是哪個時間點。

## 文件

| 文件 | 內容 |
|---|---|
| [安裝與移除](docs/install.md) | 安裝程式做了什麼、手動安裝、三種類型各自怎麼拖 |
| [時間清單的寫法](docs/time-list.md) | Chapter Bar、Kinetic Lines、Punch Zoom 共用的時間點寫法 |
| [docs/templates/](docs/templates) | 每個範本一份：預覽圖、用法、參數、注意事項 |
| [做法與踩過的坑](skills/resolve-fusion/SKILL.md) | 這些範本是怎麼用腳本做出來的，想自己改範本時看這份 |

## 快速安裝

1. 下載這個儲存庫並解壓縮。
2. 對 `install.bat` 點兩下，選「安裝或更新全部範本」。
3. 重新啟動 Resolve。

安裝程式會自己找到 Resolve 的範本資料夾，把每個範本放到對的位置，並告訴你裝了什麼、去哪裡找。之後要更新或移除也是執行同一支。

細節和手動安裝的方式見[安裝與移除](docs/install.md)。

## 已知限制

- 這些範本都是在 Fusion 頁面的合成裡驗證的：能載入、算圖結果正確。從 Edit 頁面的特效庫拖到時間軸上這條路還沒有逐一實測。
- 參數裡的「片段的哪個位置」都是 0 到 1 的比例，不是秒數。

## 自己改範本

範本不是手動拉節點做的，是用腳本在執行中的 Resolve 裡建出節點圖，算圖檢查，再匯出打包。每個範本在 `scripts/` 裡有一支建置腳本，控制項清單也寫在裡面。

需要 Resolve Studio（免費版不開放外部腳本），並在偏好設定裡允許本機腳本。

做法、指令和踩過的坑都寫在 [skills/resolve-fusion/SKILL.md](skills/resolve-fusion/SKILL.md)，還沒整理的新發現在 [LEARNINGS.md](skills/resolve-fusion/LEARNINGS.md)。

## 結構

| 路徑 | 內容 |
|---|---|
| `install.bat` | 安裝、更新、移除範本 |
| `templates/` | 範本檔（`.setting`），依類型分成 `Titles`、`Effects`、`Transitions` |
| `docs/` | 每個範本的說明、安裝方式、時間清單的寫法 |
| `previews/` | 預覽圖 |
| `scripts/` | 建置、匯出、打包、驗證用的腳本 |
| `skills/resolve-fusion/` | 做法文件與學習記錄 |
