# VHSの調整

- 録画・再生による信号の劣化を近似する。実機のエンコード・復号や磁気記録の物理シミュレーションではない。
- CRTと併用する場合はVHS → CRTの順に置く。走査線・蛍光体マスク・発光はCRT側で付ける。
- 設定は既存のExperimentEffectと同じDictionaryに保存する。VHSだけがInspectorのグループを構成する。
- 既存のAmount / Radius / Speedのキーと保存値を維持する。新しい設定はShaderの初期値を使う。
- 全体のON/OFFはResourceのEnabledで切り替える。全体Strengthは持たず、各パラメータをそのまま適用する。
- 追加設定の初期値とCRTプリセットは、作り込み前の4項目VHSを基準にする。Luma Blur / Chroma Offset / Dropout Amountは0、Saturationは1、Frame Rateは30。

## グループと設定

| グループ | 設定 | 意味 |
| --- | --- | --- |
| Playback | Speed | 全ての時間変化の倍率。0で模様・歪みを静止させる。効果そのものは消さない |
| Playback | Frame Rate | ランダムな横揺れの更新回数。局所的な横ずれは4更新ごとに切り替える。ゲームの描画fpsは変更しない |
| Playback | Signal Lines | Dropoutの基準行数。元の横揺れは出力pixelの各行を使い、この設定に影響されない |
| Luma | Luma Blur | 輝度だけの横ぼけ。Gaussianの標準偏差を出力pxで指定。5点、±2σの近似。0で無効 |
| Chroma | Radius | 元の9点等重み平均のサンプル間隔。出力px。±4 × Radiusを読み取る。Gaussianへ変更しない |
| Chroma | Chroma Offset | 色だけの水平移動。出力px、正で右へ移動 |
| Chroma | Saturation | 色差の倍率。1で維持、0で無彩色 |
| Time Base | Amount | 元の横揺れ。各出力行のランダム変位±4 × Amount pxと、sin(row × 0.03 + TIME × Speed)による±3 × Amount pxの連続変位を共に調整する |
| Time Base | Row Group Size | 同じランダム変位を共有する行数。出力px単位の整数1〜32。1で以前の各行独立。元のsin成分は各出力行で連続する |
| Time Base | Time Smoothing | 更新間の変位の時間補間量。0で以前の段階的な切り替え、1で次の変位へsmoothstep補間。途中の値では切り替えの段差も残る |
| Dropout | Dropout Amount | 4更新・1行・1区間あたりの局所的な横ずれの発生確率。0で無効 |
| Dropout | Dropout Length | 局所的に横ずれする区間の幅。出力px。両端では変位を滑らかに0へ戻す |
| Dropout | Dropout Shift | 元映像の部分的な横ずれの最大変位。出力px。方向は区間ごとに変わる。0で無効 |

## 合成とサンプリング

- 横揺れ・連続歪み・局所的な横ずれで入力座標を移動し、輝度と色差を別々に横ぼかしする。
- 元の横揺れは `row = floor(uv.y / pixel_size.y)`、`frame = floor(TIME × Speed × Frame Rate)`。ランダム変位とsinによる変位を元と同じ符号でサンプル座標へ加える。
- 色にじみは元のYIQ変換と9点等重み平均で復元する。輝度ぼけ・色ずれ・彩度変更は追加設定で、初期状態では作用しない。
- 時間変化はShaderのTIMEを使う。履歴画像やCPU読み戻しは不要。TIMEのエンジン側の一周で模様は切り替わる。
- 画面外は端の色を延長し、中心pixelのalphaを維持する。元と同じく最終RGBの負値だけを0へ制限し、HDRの上限は制限しない。明るさや色のランダム加算・灰色の線への置換は行わない。
- 元のYIQ往復変換の近似誤差も含めて維持するため、全加工量0・Saturation 1でもRGBの完全な恒等変換ではない。元画像そのものとの比較にはEnabled OFFを使う。
- 各px値は出力解像度基準で自動換算しない。信号行単位の値はSignal Linesに対する比率で表示上の高さが変わる。

- Noiseグループと輝度・色ノイズは削除した。Dropoutはランダムな無彩色への置換が白線として目立つため、元映像の部分的な横ずれに変更した。

## Time Base

- 追加したWave Amount / Heightは削除した。Amountに連動する元のsin成分は維持する。
- Row Group Size = 1、Time Smoothing = 0で作り込み前の横揺れと一致する。既存のAmount / Speed / Frame Rateは変更しない。
- 行のグループは画面上端を起点にし、グループ先頭の出力行番号をhashへ渡す。Signal Linesには依存しない。
- Time Smoothingは現在と次の更新時刻のhash値を使う。最大1更新分の時間内で補間し、保持用の画像・行バッファ・CPU読み戻しは追加しない。
- Time Smoothingを上げると変位を平均する区間が増え、細かな震えも弱く見える。振幅の自動補正は行わない。
- Frame Rateを下げると変位の更新間隔が長くなり、Time Smoothing = 1ではゆっくりした揺れになる。Speed = 0では時間変化を停止する。
