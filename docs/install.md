# 安裝與移除

## 用安裝程式

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

## 手動安裝

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

## 三種類型怎麼用

| 類型 | 用法 |
|---|---|
| 標題 | 從特效庫拖到影片上方的軌道，拉成想要的長度 |
| 特效 | 從特效庫拖到片段上。只想套用在開頭一段時，先把那一段切開 |
| 轉場 | 從特效庫拖到兩個片段的交界，拉成想要的長度 |

參數都在 Inspector 調整。所有動畫都跟著長度伸縮：片段、標題或轉場拉多長，動畫就走多久。

[回到總覽](../README.md)
