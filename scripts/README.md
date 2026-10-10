# scripts

做範本用的腳本。只是要裝範本來用的話不需要這個資料夾，執行上一層的 `install.bat` 就好。

完整的做法、指令和踩過的坑在 [skills/resolve-fusion/SKILL.md](../skills/resolve-fusion/SKILL.md)。

| 路徑 | 內容 |
|---|---|
| `build/` | 每個範本一支建置腳本：在 Resolve 的實驗合成裡建出節點圖，算測試畫格，或匯出成巨集的原料 |
| `lib.lua` | 建置腳本共用的函式 |
| `lab.lua` | 開啟或建立實驗用的時間軸 |
| `macro.py` | 把匯出的節點包成 `.setting` 範本 |
| `check.lua` | 把做好的範本貼回合成裡算圖，確認能載入 |
| `compose.lua` | 把同一個範本貼好幾份、各給不同設定，看組合起來的樣子 |
| `sheet.py`、`gif.py` | 把算好的畫格拼成總覽圖、轉成 GIF |
| `t.sh` | 測試用：跑一支建置腳本、算圖、拼總覽圖 |
| `previews.sh` | 重算 `previews/` 裡的 GIF |
| `fixtures/` | 預覽用的範例文字和設定 |
| `local.example.lua` | 複製成 `local.lua` 並填上自己的 Resolve 專案名稱，腳本才會執行 |
| `out/` | 算圖和匯出的暫存檔，不進 git |

需要 Resolve Studio（免費版不開放外部腳本）、Python 3 加 Pillow、ffmpeg。在 Windows 的 Git Bash 裡執行。
