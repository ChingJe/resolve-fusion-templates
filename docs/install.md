# 安裝與移除

把 [`templates/`](../templates) 裡的 `.setting` 檔複製到 Resolve 的範本資料夾，依類型放進對應的子資料夾：

```
%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Templates\Edit\
```

| 檔案 | 子資料夾 | 在特效庫的位置 |
|---|---|---|
| `Comic Intro.setting`、`Chapter Bar.setting`、`Kinetic Lines.setting`、`Number Counter.setting` | `Titles` | Titles → Fusion Titles |
| `Comic Intro Video.setting`、`Time Slice.setting`、`Photo Stack.setting`、`Punch Zoom.setting` | `Effects` | Effects → Fusion Effects |
| `Video Wall.setting`、`Paper Tear.setting` | `Transitions` | Video Transitions → Fusion Transitions |

子資料夾不存在就自己建。Resolve 只在啟動時掃描這個資料夾，放進去之後要重啟才會出現。

移除時把檔案刪掉再重啟。

## 三種類型怎麼用

| 類型 | 用法 |
|---|---|
| 標題 | 從特效庫拖到影片上方的軌道，拉成想要的長度 |
| 特效 | 從特效庫拖到片段上。只想套用在開頭一段時，先把那一段切開 |
| 轉場 | 從特效庫拖到兩個片段的交界，拉成想要的長度 |

參數都在 Inspector 調整。所有動畫都跟著長度伸縮：片段、標題或轉場拉多長，動畫就走多久。

[回到總覽](../README.md)
