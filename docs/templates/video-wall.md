# Video Wall

轉場 · 檔案 `templates/Transitions/Video Wall.setting` · [回到總覽](../../README.md)

從前一段拉遠，發現它只是一面影片牆裡的一格；鏡頭一邊傾斜一邊橫移，再推進另一格變成後一段。螢幕有圓角、邊框，在牆上有陰影，其他螢幕播的是兩個片段別的時間點。

![Video Wall](../../previews/video-wall.gif)

**用法**：拖到兩個片段的交界，拉成想要的長度。

| 參數 | 作用 |
|---|---|
| `Pull Back` | 拉多遠。1 是剛好看到整面 3×3 的牆 |
| `Camera Moves` | 鏡頭往哪邊移：`Right`、`Left`、`Up`、`Down`、`Diagonally Up`（左下到右上）、`Diagonally Down`（左上到右下） |
| `Camera Snap` | 移動的緩急。1 是等速，數字越大起步和收尾越慢、中間越快 |
| `Camera Tilt (degrees)` | 移動時鏡頭歪幾度，移得越快歪越多，頭尾是正的。負數往另一邊歪，0 是不歪 |
| `Motion Blur` | 移動最快那一段的動態模糊，0 是沒有 |
| `Gap` | 螢幕之間的間隔 |
| `Corner Roundness` | 螢幕圓角的大小，0 是直角 |
| `Screen Frame Width` | 螢幕邊框的粗細，0 是沒有 |
| `Depth` | 螢幕落在牆上的陰影，數字越大螢幕看起來離牆越遠。0 是完全平面 |
| `Other Screens Show` | 其他螢幕播什麼。`Other Parts Of The Clips`：把片段分成幾等份，每個螢幕各播一段。`Moments Just Before And After`：前一段稍早、後一段稍晚的畫面 |
| `Before And After: Seconds Apart` | 選 `Moments Just Before And After` 時，每個螢幕之間差幾秒 |
| `Other Screens Brightness` | 其他螢幕的亮度，調低可以突顯主畫面 |
| `Wall Colour`、`Screen Frame Colour` | 牆的顏色、螢幕邊框的顏色 |
| `Frame Rate Override` | 秒數算得不對時填時間軸的影格率，平常留 0 |

**注意**

- 第一格和最後一格就是原本的兩個片段，圓角和傾斜是在開頭、結尾的一小段時間內漸漸出現和收掉的。
- `Depth` 的陰影要牆比較亮才看得出來。牆設成全黑時陰影等於看不見。
- 其他螢幕出現黑畫面，代表它要播的時間點超出片段能提供的範圍。`Other Screens Show` 換另一個選項試試；選 `Moments Just Before And After` 時把秒數調小，調成 0 就一定有畫面（每個螢幕都和主畫面同步）。
- 這個轉場只在實驗用的合成裡用腳本測過，還沒有在 Edit 頁面實際拖到兩個片段之間。`Other Parts Of The Clips` 在那裡取得到片段多大的範圍，沒有測過。
