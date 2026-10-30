# Cell Emission

CRT ResourceのMask ModelをCell Emissionに設定する。
Chromatic Aberration（pass 0）→ Signal / Scanline（pass 1）→ Cell Emission（pass 2）→ Texture（pass 3）→ Optical Spread（pass 4）→ Phosphor Bloom（pass 5）。
Mask Redistributionはpass 1でmaskを適用し、pass 2を止める。
Cell専用のSubViewportは追加しない。Bloom Coreにも同じMask設定が反映される。

## Maskの役割と設定

規則的な粒感と、局所的な色・明るさの変化を作る。純粋なRGB素子のpixel再現だけを目的にしない。
MaskグループはModel・Pattern・Strength・Mask Pitch・Row Heightの5項目。

| Pattern | 配置 | 高さの設定 |
| --- | --- | --- |
| Staggered RGB | 等幅RGBを横半周期ずつ交互にずらす | Row Heightは位相が切り替わる段の高さ |
| RGB Stripes | 等幅RGBの縦縞、段のずれなし | 使用しない |
| Green / Magenta Stripes | 等幅G / R+Bの縦縞 | 使用しない |

Mask Pitchは横一組の周期、2〜6出力px、整数step、初期値3。
Row Heightは1〜8出力px、整数step、初期値3。旧2段groupingも高さへ集約する。
RGBの横位相は0.5px固定、G/Mは0px固定。Pitch 2のG/Mが毎pixelの平均で消えることを避ける。
`mask_geometry.gdshaderinc`を両Modelで共用する。境界を整数へ丸めず、矩形coverageを解析積分する。
出力座標に固定し、解像度による自動換算は行わない。

## Samplingと強度

横4区間の中心、X ±0.125 / ±0.375px、Y中心の入力をbilinear samplingする。
各区間の発光は `input_rgb(sample) × coverage`。coverageには区間面積が含まれ、sample数で再度割らない。
aperture自体は解析積分、変化する入力との積は区間中心による近似。
縦方向の追加平均と非発光Gapは設けない。

各channelの占有率はRGBで1/3、G/Mで1/2。発光をそれぞれ3倍 / 2倍にして平均光量を補償する。
均一入力の完全な周期では平均RGBを保つ。HDRを1でclampせず、別channelへ再配分しない。
Mask Redistributionは明るさに応じた非線形の再配分を使うため、同じ配置でも色応答は異なる。

Strength 0は再構成信号、1は正規化した発光、中間は両者の混合。
0ではCell passと画面コピーを無効にする。Optical Spread・Bloom・Textureは独立して有効にできる。
画面テクスチャ中心のalphaを保持する。透明Sceneは画面コピー側の制約がある。

## 整理と移行

| 整理前 | 整理後 |
| --- | --- |
| RGB Rows、Row Offset Half Period | Staggered RGB、Row Height = 旧Row Pitch |
| RGB Row Pairs、Row Offset Half Period | Staggered RGB、Row Height = 旧Row Pitch × 2 |
| Triad Pitch | Mask Pitch（RGBでは同じ幅） |
| 固定2pxのGreen / Magenta Stripes | Pattern ID 2、Mask Pitch 2 |
| Cell Sampling | 横4点固定、2x2の実装を削除 |
| Horizontal / Vertical Gap | 設定と非発光部分の計算を削除 |
| Row Offset Mode | 設定を削除、Staggered RGBは半周期・Stripesは0に固定 |
| Brightness Compensation | 設定と倍率を削除、追加gainなし |
| RGB Pixel Pattern | RGB/黒の固定配列を実装ごと削除 |
| Mask Pixel Preview | Scene・Script・Shader・UID・READMEを削除 |

現在のCRT testのCell Emission / pitch 4 / height 2 / Strength 1を維持する。
mainの旧Row Pairsはheight 6、post_processingの旧G/Mはpitch 2に移行。
両SceneのSamplingとGapはRedistributionでは使われていなかったため、削除による描画変更はない。
旧名aliasやReference用shaderは残さない。外部保存Resourceは上表に沿って移行が必要。

大きなPitchは色分離と規則性を増やす。光の広がりは後段のOptical SpreadとBloomで調整する。
SDR表示の局所HDR飽和は残る。均一な平均光量の維持は、最終画面での色・明るさの不変を保証しない。

## 整理時の検証

Godot 4.7.2のHDR描画で、整理前後のCell Emission / Pitch 4 / Row Height 2の出力は
全pixelの生バイト列で一致した。
両Model・Pitch 2〜6・高さ1〜4の40条件では31条件が一致し、残り9条件の最大差は
0.0009765625だった。演算簡略化による16bit floatの微小差で、全設定の完全一致は保証しない。
均一linear RGB 0.2の平均値、全Patternの描画、Strength 0でのpass / 画面コピー停止と復帰も確認した。
