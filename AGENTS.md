# resolve-fusion-templates

DaVinci Resolve 的 Fusion 範本（特效、轉場、標題），以及用腳本在執行中的 Resolve 裡產生這些範本的工具。

## 結構

| 路徑 | 內容 |
|---|---|
| `templates/` | 範本原始檔（`.setting`），依類型放在 `Titles`、`Effects`、`Transitions` |
| `install.bat` | 給使用者的安裝程式，把 `templates/` 同步到 Resolve 的範本資料夾 |
| `scripts/drfx.py` | 把 `templates/` 包成一個 `.drfx`（使用者點兩下就能裝）。推到 `main` 時 GitHub Actions 會自動打包並更新 Release，不用手動上傳 |
| `scripts/` | 建置、匯出、打包、驗證用的腳本 |
| `docs/` | 給使用者看的說明：每個範本一份、安裝方式、時間清單的寫法。README 只放總覽和分類 |
| `previews/` | 預覽圖 |
| `skills/resolve-fusion/` | 做法文件與學習記錄 |

## 開始工作前

只要工作牽涉到 Resolve、Fusion 節點、`.setting` 範本或 `scripts/`，先讀：

@skills/resolve-fusion/SKILL.md

## 規矩

- **動 Resolve 前先確認目前開的是哪個專案**。腳本改的是使用者正在用的那個 Resolve，不是預期的專案就停下來問。不要自行切換、關閉或刪除專案。
- **預覽圖和任何進 git 的檔案都不能含使用者的私人素材**。需要預覽時用程序產生的畫面。
- 影片等大型素材不進 git，也不要搬動位置，Resolve 專案是用絕對路徑連結的。
- `templates/` 是原始檔，Resolve 實際讀的是 `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Templates\Edit\` 底下那份。改完範本要複製過去（執行 `install.bat install nopause`），並提醒使用者重啟 Resolve。新增範本時放進對應類型的子資料夾，安裝程式就會自動帶到，不用改它。
- 回報時，沒有實測過的部分要明講沒測過。
- 用繁體中文和使用者溝通。

## 工作結束前

把這次新學到、下次還會用到的事寫進 `skills/resolve-fusion/LEARNINGS.md`，規則見 SKILL.md 最後一節。
