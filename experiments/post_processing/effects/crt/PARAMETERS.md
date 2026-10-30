# CRT parameter ranges and defaults

Resource の初期値は見た目を調整するための出発点。
実機計測から確定した値ではなく、以下の数式上の意味と調整方針を持つ。
Scene に保存された値は初期値を上書きする。

Maskは規則的な粒感と局所的な色・明るさの変化を作る。Mask Modelは描画モデル、Mask Patternは質感の配置。
InspectorのMaskグループはModel / Pattern / Strength / Mask Pitch / Row Heightの5項目。
Gap・Sampling・段のずれ幅・明るさ倍率の設定は持たず、内部の小グループも設けない。

| 項目 | 範囲 | 初期値 | step | 意味・根拠 |
| --- | --- | --- | --- | --- |
| Mode（Chromatic Aberration） | Fixed / Radial | Fixed | — | 一定のXY移動、または画面中心を基準とする拡大・縮小。選択中の方式の設定だけを表示 |
| RGB Red Offset | 各軸 −8〜8 px | (−2, 0.5) px | 0.1 | Fixedで元の像に重ねる赤成分の位置。X正で右、Y正で下。出力pixel基準 |
| RGB Blue Offset | 各軸 −8〜8 px | (2, −0.5) px | 0.1 | Fixedでの青成分の位置。初期値は青が右。緑は元の位置を維持し、赤青は独立したXY設定 |
| RGB Strength | 0〜1 | 0.3 | 0.01 | 元の像の重み1に対するRGB分離像の重み。0で無効。副像へ置換せず元の輪郭を残す |
| Red / Blue Radial | −8〜8 px | −2 / 2 px | 0.1 | Radialでの赤・青の拡大縮小量。画面の隅での像の移動距離。正は外側、負は内側。緑は元の位置 |
| Scanline Count | 180〜720 | 360 | 1 | 縦方向の再構成の行数と走査線模様の周期を共用する。1080pで初期値は1行あたり3出力px。範囲は調整用 |
| Signal Prefilter Enabled | OFF / ON | ON | — | 信号の各サンプルが担当する元画像の範囲を平均してから補間する。細線がサンプル間に落ちて消えることを抑える。OFFで従来の点サンプリング。Signal EnabledがOFFなら無効 |
| Sharpness | 0.5〜1.0 | 0.67 | 0.01 | 横方向のkernelを広げるほど低い値。範囲は半径2〜1サンプル間隔に対応 |
| Signal Pitch | 0.5〜3.0 px | 1.5 px | 0.1 | 横方向の信号サンプル間隔。見た目の調整値で、解像度による自動換算なし |
| Vertical Blur | 0〜1 | 1 | 0.01 | 横方向だけ再構成した画像と、縦も再構成した画像の混合比。0で縦処理を無効、1で縦の再構成を完全適用。走査線の濃淡とは独立 |
| Scanline Strength | 0〜1 | 0.15 | 0.01 | 行方向の明るさの濃淡。0で走査線模様を無効。Signal EnabledがOFFでも使用可能。低解像度では自動的に弱める |
| Beam Width | 0.75〜1.25 lines | 0.9 line | 0.01 | 走査線の発光profileのFWHM。現在は模様だけに使用し、縦の補間へ影響しない。1.0では隣接profileの合計が一定になり、濃淡はほぼ生じない |
| Mask Model | Mask Redistribution / Cell Emission | Mask Redistribution | — | 明るさに応じた色の再配分、またはHDR信号とaperture coverageからの発光。両Modelで全Patternを使用可能 |
| Mask Pattern | Staggered RGB / RGB Stripes / Green / Magenta Stripes | Staggered RGB | — | 半周期ずつ交互にずらすRGB粒状配置、ずらさないRGB縦縞、GとR+Bの縦縞 |
| Mask Strength | 0〜1 | 0.5 | 0.01 | mask適用前と完全適用の混合比。0でmaskを無効化 |
| Mask Pitch | 2〜6 px | 3 px | 1 | RGB triadまたはG/Mの一組の横周期。全Pattern共通、出力pixelの整数単位 |
| Row Height | 1〜8 px | 3 px | 1 | Staggered RGBが半周期ずつずれる段の高さ。縦縞では使用せず読取専用 |
| Texture Enabled | OFF / ON | ON | — | 固定された明暗乗算。OFFでpassと画面コピーを無効にする |
| Texture Strength | 0〜0.5 | 0.2 | 0.01 | 倍率1を基準とした明暗の変動幅。0.2なら0.8〜1.2の範囲。0で無効 |
| Texture Size | 1〜4 px | 1.5 px | 0.1 | 粒の格子間隔。出力pixel基準でMask配置とは独立 |
| Optical Spread Strength | 0〜1 | 0.5 | 0.01 | mask適用後の光を隣接pixelへ移す量。0でpassと画面コピーを無効化。Mask Redistribution / Cell Emission共通 |
| Optical Spread Width | 0〜1 px | 0.75 px | 0.05 | 4つのbilinear sampleのfootprint幅。±Width / 2pxを読む。0で無効。GaussianのFWHMではない |
| Near Width | 0.5〜8.0 px @1080p | 4.0 px | 0.1 | すぐ周囲のにじみ。現在のCRT testで使用する調整値を初期値に採用 |
| Far Width | 4.0〜64.0 px @1080p | 32.0 px | 0.1 | 広いhalo。現在のCRT testで使用する調整値を初期値に採用 |
| Near Strength | 0〜0.25 | 0.1 | 0.01 | sourceからNearへ再配分する割合。初期値10%、上限25%は調整用 |
| Far Strength | 0〜0.1 | 0.05 | 0.001 | sourceからFarへ再配分する割合。初期値5%、上限10%は調整用 |
| HDR Limit | 1.0〜32.0 | 16.0 | 0.1 | sourceの最大RGB成分の漸近値。1は意味のある端点、16と上限32は調整用 |

stepは原則1 / 0.1 / 0.01 / 0.001。Mask PitchとRow Heightは整数。
Far Strength は0.001刻みで微調整する。初期値0.05の2%ずつ調整できる。
初期値・範囲・Scene保存値はstep変更に合わせて丸めない。

## Chromatic Aberration

Pass 0で元の信号からRGB分離像を作り、その後にSignal / Scanline、Mask、
Texture、Optical Spread、Bloomを適用する。MaskやTextureの配置を移動しない。
Fixed / Radialを選ぶ。Fixedの既存XY値は保持し、方式を戻せば再使用できる。
フルカラー副像を重ねるGhostの設定・処理は持たない。

Radialは画面中心(0.5, 0.5)で一致する一様な拡大・縮小。
出力pixelで測った画面の半対角長をR、Radialの値をaとして、像の倍率を `1 + a / R` とする。
読み取りは `center + (uv - center) / scale`。像の移動距離は中心からの距離に比例し、隅でa px。
縦横比が変わってもpixel空間で同じ倍率になる。正は拡大、負は縮小。
極端に小さいViewportで負の値がRを超えても反転しないよう、倍率の下限を0.01とする。

合成は `(original + r * rgb_separated) / (1 + r)`。rはRGB Strength。
Strength 0または選択中の方式のズレ量が全て0ならPass 0と画面コピーを止める。
Strength 1では元の像とRGB分離像を半分ずつ混合する。
均一なRGB / HDR値を保ち、clampや加算による明るさ増加は行わない。alphaは元のpixelを維持する。
FixedのOffsetは副像の見える方向を表し、読み取りは逆方向へ行う。画面外は端のpixelを延長する。
線形補間により整数未満の位置も連続して変化する。

## Mask ModelとPattern

Mask Redistributionは中心の再構成信号を使い、明るさに応じて各色成分を配置へ再配分する。
Cell Emissionは横4区間のHDR入力とaperture coverageの積を近似積分し、各channelの占有率で正規化する。
両Modelの違いはsamplingだけでなく、明るさへの応答にもある。両Modelで全Patternを使用する。

Staggered RGBはRow Heightごとに横位相をMask Pitchの半分ずらす。
RGB Stripesは同じRGB apertureを段のずれなしで使用する。
Green / Magenta Stripesは前半G、後半R+B。Pitch 2は1pxずつの細かな変調、Pitchを広げると太い縞になる。
Patternは成分配置を表す。coverageの重なり・入力色・Modelの応答により最終pixelが原色のみになるとは限らない。
共通geometryは `mask_geometry.gdshaderinc`。出力座標に固定し、解像度で自動換算しない。
黒い隙間は設けない。暗いpixelや低いchannel値は入力とcoverageの結果として生じる。

Cell Emissionは横±0.125 / ±0.375px、Y中心に固定する。縦平均を追加しない。
RGBは従来のPixel Center（0.5px）の横位相を維持する。
G/Mは0pxの横位相とし、Pitch 2で両色が毎pixel平均されて模様が消えるのを防ぐ。
これはPatternの固定geometryで、調整項目ではない。

Mask Strength = 0はSignal / Scanline後の信号、1は完全なmask出力、中間は両者の混合。
0ではCell passと画面コピーを無効にする。独立したOptical Spread・Bloom・Textureは引き続き作用する。

旧RGB RowsはStaggered RGBへ、RGB Row PairsはRow Heightを旧Row Pitchの2倍にして移す。
旧Green / Magenta StripesはMask Pitch 2に移し、従来の固定2px周期を維持する。
Sampling 2x2・Gap・Row Offset Mode・Brightness Compensation・RGB Pixel Patternの実装と旧名aliasは削除。
現在のCRT testはCell Emission / Staggered RGB / Mask Pitch 4 / Row Height 2 / Strength 1。
Signal・Optical Spread・Bloom・後段の色調整の保存値は変更していない。
旧Noiseの有効状態をTextureへ移行している。

詳細は[Cell Emissionの仕様](PHOSPHOR_CELLS.md)を参照。

## Signal Prefilter

横幅は `max(1, Signal Pitch)` 出力px、縦幅は `max(1, Viewport高さ / Scanline Count)` 出力px。
この矩形と元画像の各pixelとの重なりを重みにして平均する。
隣接pixelの重みをbilinear samplingへまとめ、2×2 pixelを最大1回のtexture readで取得する。
入力のRGB / HDR値をclampせず、画面の外側は端のpixelを延長する。

サンプル間の細線を拾うための処理であり、輪郭を強調する処理ではない。
ボケで線が広がり、ピークの明るさが下がることは残る。
均一な色は維持するが、細線や細かな模様は従来より柔らかく、安定した見え方になる。
現在のScene保存値を変えず、Resource / Shaderの初期値ONで適用する。
比較時はSignal ReconstructionのSignal Prefilter EnabledをOFFにする。

追加passは使用しない。texture read数はサンプル範囲に応じて増える。
高解像度でScanline Countを低くすると縦の範囲が広くなり、描画負荷も増える。
同じshaderを使うBloomのCore再描画にも設定が反映される。

## Sharpness

`w(d) = 1 - smoothstep(0, 1, d * sharpness)` を正規化して使用する。
kernelの半径とFWHMは、ともに `1 / sharpness` サンプル間隔となる。
0.67では約1.493間隔、Signal Pitch = 1.5ならkernel自体のFWHMは約2.239出力px。
これはkernelの幅であり、再構成された図形の実測FWHMと常に一致するわけではない。
0.5〜1.0は固定5サンプルの中にkernelを収め、広めから狭めへ調整できる範囲。
0.67に物理的・数学的な必然性はなく、必ず0.67でなければならないわけではない。

## Vertical BlurとScanline Strength

Signal Enabledは横・縦の信号再構成を切り替える。
Vertical Blur = 0なら、元の縦座標から横方向だけ再構成する。
1なら、隣接する信号行の面積平均をcosineの重みで補間する。
中間値は両者の混合。縦の柔らかさの量を調整する値で、ブラーのFWHMではない。
0と1は必要な経路だけを描画し、中間値は両方を読み取るため追加負荷がある。

縦の補間の重みは `lower = 0.5 - 0.5 * cos(π * row_phase)`、`upper = 1 - lower`。
以前のBeam Width = 1と同じ補間の形を基準にし、Beam Widthから独立させた。
Scanline Strengthを0にしても、この補間とPrefilterは残る。
Vertical Blurを0にしても、走査線の濃淡は残せる。

走査線の明るさは `mix(1, 平均光量を補正したprofile, Strength × Visibility)` を掛ける。
profileを出力pixel内の縦4点で平均し、狭い帯の輪郭を柔らかくする。
Visibilityは1pixelあたり0.4〜0.5行でなだらかに弱くなり、0.5行以上では模様を適用しない。
2px以下の周期で現れるaliasingを抑えるための実用的な制限。
Scanline Countは信号行と模様の周期で共用し、密度を変えると両方に影響する。
maskのrow patternやCell EmissionのVertical Gapは別の処理なので、Scanline Strength = 0でも残る。

初期値はVertical Blur = 1、Scanline Strength = 0.15、Beam Width = 0.9。
横線を強く見せず、弱い行方向の質感を足す出発点。
既存の保存済みBeam Widthは優先されるが、現在は縦の補間には使わない。
Beam Width = 1の保存値では、Strengthを上げてもほぼ濃淡は出ない。

## Beam Width

`profile(d) = cos(πd/2)^p`、`p = ln(0.5) / ln(cos(π * width / 4))`。
width = 1ならp = 2で、均一信号では隣接する2本の合計が一定になる基準点。
width = 1の光量補正倍率も1となる。初期値は弱い模様を作れる0.9とする。
1より細いと走査線の隙間が目立ち、1より太いと重なりが強くなる。

旧Width = 0.42の式では `p = 2 + 0.5 * (1/0.42 - 1/0.55) ≈ 2.281385`。
このprofileのFWHMは約0.943104で、以前の初期値0.94は旧形状をほぼ保つ換算値だった。
1.0は走査線の濃淡がほぼなくなる比較の基準として使用できる。

現在の光量補正はpに対する多項式近似で、旧範囲0.5〜1.25全体での精度は成立しない。
選択範囲は0.75〜1.25を維持する。
shader式の連続profileを数値積分すると、補正後の均一信号の平均倍率は以下となる。
表示解像度・走査線位相による離散化は、この計算に含まない。

| Beam Width | 補正後の平均倍率 |
| --- | --- |
| 0.50 | 約0.188 |
| 0.60 | 約0.799 |
| 0.70 | 約0.992 |
| 0.75 | 約0.9994 |
| 0.94 | 約1.0000 |
| 1.00 | 1.0000 |
| 1.25 | 約1.0027 |

TODO: 将来幅0.5付近まで広げるなら自動補正方式を見直す。
光量補正の調整項目は追加せず、見た目の明るさ調整にはBrightness Compensationを使用する。
Beamのprofileと光量補正の式は変更していない。出力pixelでの平均とStrengthの混合を追加した。

## Optical Spread

Signal / Scanline → Mask RedistributionまたはCell Emission → Texture → Optical Spread → Bloomの順。
maskを大きくせず、セル周辺のごく狭い光の広がりを加える。
全mask方式で使用でき、maskやsignalを無効にしても使用可能。
処理としては、mask適用後の画像への狭い対称ブラー。maskだけでなく映像の輪郭にも作用する。

4つの対角位置、`(±Width / 2, ±Width / 2)` 出力pxでbilinear samplingしたRGBを平均する。
出力は `mix(中心RGB, 平均RGB, Strength)`。HDRの上限clamp、加算gain、輝度thresholdは設けない。
Widthが0〜1の場合、各軸の離散kernelは `[Width / 4, 1 - Width / 2, Width / 4]`。
Width = 1は3×3のbinomial kernelに相当する。これを超えてpixel周期の模様を反転させないため上限を1にする。
初期値はStrength = 0.5、Width = 0.75。単独1px線の中心の明るさは0.8125、周囲を含む合計は1になる。
光を移す量を増やすとmaskのRGB分離・Gapの硬さが減り、細線のピークも下がる。
強くするとmaskの粒感そのものが弱くなる。周期や配置を変える設定ではない。

画面端は端のpixelを延長する。入力RGBの符号と画面テクスチャの中心alphaを維持する。
透明Sceneのalphaには画面コピー側の制約がある。
出力pixel単位で、表示解像度による自動換算はしない。

StrengthまたはWidthが0の場合、メイン描画とBloom Core再描画のpass / BackBufferCopyを非表示にする。
有効時は全画面passと画面コピーが各1つ増える。追加SubViewportは作らない。
Bloomが有効ならCoreにも同じ広がりを適用してからBloom sourceを生成する。
Near / Far BloomのGaussianやHDR応答制限とは独立した、狭い光の再配分。
Textureは前段で適用するため、この処理で柔らかくなる。

## Texture

Signal / Scanline → Mask RedistributionまたはCell Emission → Texture → Optical Spread → Bloomの順。
画面に固定された細かな明暗のムラを、Mask後のlinear HDR RGBへ共通倍率で乗算する。
色差・時間更新・大きなムラは含めない。旧Noiseの加算応答・Oklab変換・Rate・Softnessは削除。

倍率は `1 + Strength × variation`、variationは-1〜1。Strengthの最大値0.5でも倍率は正。
RGB比率・純黒・符号付きRGB・画面テクスチャの中心alphaを保持し、HDRを1でclampしない。
純黒は粒だけでは明るくならない。ただし後段のSpread / Bloomは周囲の光を広げる。
hashの期待値は0なので平均倍率の基準は1。有限画面や画像内容との相関により、画面の平均明るさが厳密に一定とは限らない。

出力pixel座標から単一サイズの格子を作り、各格子の値をsmoothstepで補間する。
Sizeは格子間隔で、実測の粒径やFWHMではない。Size 1ではpixel中心に格子が一致する。
Softnessは独立した設定にせず、滑らかな補間へ固定。複数サイズの合成はしない。
模様は左上を基準に固定され、映像の移動や時間更新に追従しない。解像度の自動換算なし。

TextureはDispersed Randomに固定。設定はEnabled / Strength / Sizeの3項目。
中心hashから上下左右4点の平均を引き、低周波の塊を抑える。
係数0.894427191を掛けて-1〜1へ制限し、前述の格子上でsmoothstep補間する。
最適化したblue-noise textureではない。色量子化・階調数制限はしない。

Enabled OFFまたはStrength 0が無加工の基準。
Strengthは変動の上限であり、出力での実測contrastを表すものではない。
後段のSpread / BloomとMaskの配置で、細かい模様の見え方や干渉も変わる。
各格子に5回のhashを使う。方式を固定してもpass数・texture数は増えない。

Textureはpass 3。Enabled OFFまたはStrength 0で、メイン描画とBloom Core再描画のpass / BackBufferCopyを無効化する。
Optical Spreadはpass 4、Bloomはpass 5。BloomのCoreにもChromatic Aberration・Texture・Spreadを同じ順序・同じ設定で再描画する。
有効時はSpreadで粒が柔らかくなり、Bloomでムラを含む発光が広がる。後段を含めた色比率・平均輝度の不変は保証しない。
全画面pass数は最大6。Radial用のpassは追加せず、Texture用SubViewport・textureも追加しない。
旧Noise Enabledの保存値はTexture Enabledへ移行した。
名称整理時のCRT testはON / Dispersed Random / Strength 0.25 / Size 1.8。
Resourceの新規作成時のStrength初期値は引き続き0.2。

## Bloom

Near/FarのWidthはGaussianのFWHMで、Viewport高さ / 1080を掛けて換算する。
初期値4pxと32pxは、CRT testで調整した発光感を採用した値。
以前の2pxと16pxより広く、Nearは直近の発光としてやや広め、Farは広いhaloとなる。
下限・上限はアルゴリズムの厳密な限界ではなく、役割と調整しやすさに合わせて決めた。
Near/Farは独立なので、設定次第ではNearの方が広くなることも許容する。
Farの64px上限は幅に応じて増えるGaussianの描画負荷にも関係する。

StrengthはCore全体ではなく、HDR応答制限後のsourceに対する再配分率。
Near/Farの合計は設定範囲内で最大0.35となり、sourceの全部を周辺へ移すことはない。
現在の初期値はNearが0.1、Farが0.05で、合計15%のsourceを再配分する。
以前の0.06 / 0.01より周辺光を強く出す設定で、FarはNearより弱くする。
上限0.25と0.1自体に必然性はなく、見た目を確定した後に範囲を絞る余地がある。

HDR Limitは1のときsourceの最大成分を1に制限する。
初期値16では高輝度sourceが16へ漸近する。32は入力HDRの上限ではない。
以前の初期値2より制限が弱く、入力16のsource代表強度は約10.48になる。
式と過去の数値検証は [PHOSPHOR_BLOOM.md](PHOSPHOR_BLOOM.md) を参照。
