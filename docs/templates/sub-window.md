# Sub Window

特效 · 檔案 `templates/Effects/Sub Window.setting` · [回到總覽](../../README.md)

把片段縮成角落的一個小窗，有邊框和陰影，會彈進來。綜藝節目放來賓反應的那種子畫面（ワイプ）。小窗以外是透明的。

![Sub Window](../../previews/sub-window.gif)

**用法**：把要當子畫面的片段放在主畫面**上方的軌道**，再把這個特效拖到它上面。用 `Position` 決定小窗放哪裡。

| 參數 | 作用 |
|---|---|
| `Shape` | 形狀：`Circle` 圓形、`Rounded` 圓角矩形、`Rectangle` 矩形 |
| `Position` | 小窗的中心位置 |
| `Size` | 小窗的高度，以畫面高度為 1 |
| `Width / Height` | 寬高比（圓形不適用） |
| `Corner Roundness` | 圓角的程度，只對 `Rounded` 有效 |
| `Zoom Into The Clip` | 放大片段幾倍再放進小窗，用來只取臉的部分 |
| `Part Of The Clip Shown` | 小窗的中心對準片段上的哪一點 |
| `Mirror` | 左右鏡像 |
| `Border`、`Border Colour` | 邊框的粗細和顏色 |
| `Shadow`、`Shadow Distance`、`Shadow Softness` | 陰影的濃度、距離、柔和度 |
| `Entrance` | 進場方式：`Pop` 彈出、`Grow` 長大、`From The Nearest Edge` 從最近的畫面邊緣滑入、`Fade` 淡入、`None` |
| `Entrance Frames`、`Exit Frames` | 進場和退場各花幾格。退場用和進場相反的方式 |

**注意**

- `Position` 和 `Part Of The Clip Shown` 都可以打關鍵幀。
- 小窗顯示的範圍和小窗自己的寬高比相同，所以畫面不會被壓扁。
- 同一個片段既當主畫面又當子畫面時，把片段複製一份放到上方軌道再套。
