# 安裝與移除

## 用範本包安裝（建議）

所有範本包成一個檔案：[Resolve-Fusion-Templates.drfx](https://github.com/ChingJe/resolve-fusion-templates/releases/latest/download/Resolve-Fusion-Templates.drfx)。每次範本有更新，這個連結下載到的就是最新的。

1. 下載 `Resolve-Fusion-Templates.drfx`。
2. 開著 Resolve，對這個檔點兩下（或把它拖進 Resolve 的視窗），在跳出來的視窗按 **Install**。
3. 到 Edit 頁面左上角的 Effects 特效庫找範本，位置見下面「[手動安裝](#手動安裝windows)」的表。

在 Windows 的 Resolve 21.1.1 Studio 上試過：按下 Install 之後不用重新啟動就能用。如果特效庫裡沒看到，重啟 Resolve 一次。

它做的事很單純：把這個 `.drfx` 檔複製到 Resolve 的範本資料夾，Resolve 直接讀裡面的範本。

- **Windows**：`%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Templates\`
- **Mac**：`~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Templates/`

**移除**：到上面的資料夾把 `Resolve-Fusion-Templates.drfx` 刪掉，重啟 Resolve。

**更新**：下載新的檔案再裝一次。這一步還沒有實際試過（會不會直接蓋掉舊的）；保險的做法是先照上面移除舊的再裝。

**不要和 `install.bat` 混用**。兩種方式都裝的話，同一個範本會有兩份，在特效庫裡會怎麼顯示沒有試過。換方式之前先把原本的移除。

**Mac**：`.drfx` 是 Resolve 自己的格式，Mac 上一樣是點兩下安裝。但這些範本都是在 Windows 上做的，手邊沒有 Mac，**Mac 上沒有實際試過**，有問題歡迎回報。另外，有中文的範本預設用微軟正黑體，Mac 沒有這個字型，中文可能變成方塊；在範本的 `Font` 參數改成 Mac 有的中文字型，例如 `PingFang TC`。

## 用安裝程式（Windows，從原始檔安裝）

`install.bat` 是 Windows 的批次檔，Mac 不能執行。它適合下載了整個 repo、想照原始檔安裝的人（例如自己改了範本）。

在檔案總管裡對 `install.bat` 點兩下。它會先檢查，再顯示選單：

| 選項 | 作用 |
|---|---|
| 1 安裝或更新全部範本 | 還沒裝的裝上去，內容不同的換成這裡的版本，已經相同的不動 |
| 2 移除這些範本 | 只刪除和這裡同名的範本檔，會先問一次確認 |
| 3 只看目前裝了哪些 | 列出每個範本是沒安裝、需要更新還是已是最新，不改任何東西 |

它會幫你擋掉的狀況：

- **從壓縮檔裡直接執行**：找不到 `templates` 資料夾時會停下來，請你先解壓縮。
- **這台電腦沒有 Resolve，或這個帳號還沒開過 Resolve**：找不到 Resolve 的設定資料夾時不會建立任何東西。
- **Resolve 正開著**：照樣安裝，但會提醒你要重新啟動才看得到。
- **複製失敗**：每個檔案複製完會比對內容，不一致就標成失敗。

你自己放在 Resolve 範本資料夾裡的其他範本不會被動到。

下載了新版之後再執行一次、選 1，就是更新。

也可以從命令列直接指定動作，不顯示選單：

```bat
install.bat install
install.bat remove
install.bat status
```

## 手動安裝（Windows）

`templates/` 底下有 `Titles`、`Effects`、`Transitions` 三個資料夾，把它們裡面的 `.setting` 檔複製到下面位置的同名資料夾：

```
%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Templates\Edit\
```

| 資料夾 | 類型 | 在特效庫的位置 |
|---|---|---|
| `Titles` | 標題 | Toolbox → Titles → Fusion Titles |
| `Effects` | 特效 | Toolbox → Effects → Fusion Effects |
| `Transitions` | 轉場 | Toolbox → Video Transitions → Fusion Transitions |

資料夾不存在就自己建。Resolve 只在啟動時掃描這個位置，放進去之後要重啟才會出現。

移除時把檔案刪掉再重啟。

## 在 Mac 上手動安裝

建議用上面的範本包。要手動放的話（**沒有實際試過**）：把 `templates/` 底下 `Titles`、`Effects`、`Transitions` 三個資料夾裡的 `.setting` 檔，複製到下面位置的同名資料夾，再重啟 Resolve。資料夾不存在就自己建。

```
~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Templates/Edit
```

從 Mac App Store 安裝的 Resolve 位置不同：

```
~/Library/Containers/com.blackmagic-design.DaVinciResolve/Data/Library/Application Support/Fusion/Templates/Edit
```

## 三種類型怎麼用

| 類型 | 用法 |
|---|---|
| 標題 | 從特效庫拖到影片上方的軌道，拉成想要的長度 |
| 特效 | 從特效庫拖到片段上。只想套用在開頭一段時，先把那一段切開 |
| 轉場 | 從特效庫拖到兩個片段的交界，拉成想要的長度 |

參數都在 Inspector 調整。所有動畫都跟著長度伸縮：片段、標題或轉場拉多長，動畫就走多久。

[回到總覽](../README.md)
