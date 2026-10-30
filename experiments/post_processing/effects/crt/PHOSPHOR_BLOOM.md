# Phosphor Bloom

Chromatic AberrationはPass 0で元信号へ適用する。
Mask ModelがMask RedistributionならPass 1、Cell EmissionならPass 2でmaskを適用し、Pass 3のTextureとPass 4のOptical Spreadを適用した後に使う。
BloomはPass 5で、mask・固定の明暗乗算・狭い光の広がりを適用したHDR出力をsourceにする。
Bloom source の HDR 応答を制限する方式（旧 Limited）に一本化した。
Near/Far の Gaussian と光量再配分は比較時から変更していない。

Coreの再描画にはTextureとOptical Spreadも含め、無効なpassはColorRectとBackBufferCopyをどちらも非表示にする。
filterのparameter更新は、初期化時に渡されたBloom pass indexを使用する。
以前の固定index 1ではCell用のparameterを送っていたため、HDR Limitの変更がfilterへ届かなかった。今回、Bloom用の値が反映されるよう修正した。

## 初期値

| 項目 | 値 |
| --- | --- |
| Near Width | 4.0 px FWHM @1080p |
| Far Width | 32.0 px FWHM @1080p |
| Near Strength | 0.1 |
| Far Strength | 0.05 |
| Bloom HDR Limit | 16.0 |

CRT test で調整した値を初期値に採用した。
旧初期値よりにじみを強く出す設定で、sourceの合計15%をNear/Farへ再配分する。
Near 4pxは直近の発光としてやや広め、Far 32pxは広いhaloを出す。
HDR Limit 16は旧初期値2より制限が弱く、高輝度ほど周辺光が強くなる。
1080pでFarの各方向のサンプル数は16px時の23から32px時の43へ増える。
この比率はGPU時間そのものの計測結果ではない。

HDR Limit の設定範囲は 1.0〜32.0、step は 0.1。
これは Bloom source の代表強度の漸近値で、入力 HDR の最大値とは別。
32 はアルゴリズムの上限ではなく調整用の上限。
大きな Limit ほど制限が弱まり、線形応答に近づく。

Width は Viewport の高さ / 1080 を掛けて pixel 幅に換算する。
Gaussian は σ = FWHM / √(8 ln 2)、片側 3σ までの離散 kernel を正規化する。
画面端は反射境界を使用し、均一面と端の輝点の光量を保つ。

## HDR 応答と合成

最大 RGB 成分を代表強度 I とし、I ≤ 1 はそのまま通す。
I > 1 かつ L > 1 では `I' = 1 + (L - 1) * (1 - exp(-(I - 1) / (L - 1)))`。
`S = original.rgb * (I' / I)` として RGB 比率を保つ。
L = 1 は余裕がゼロになる極限として `I' = 1` に分岐し、ゼロ除算を避ける。

L は Bloom HDR Limit。L > 1 では白付近の傾きは 1、強度が上がると L に漸近する。
調整項目は Limit のみに絞り、Threshold と Response は持たせていない。
Core 自体の HDR RGB は変更しない。

合成は `original + n * (near(S) - S) + f * (far(S) - S)`。
指定された再配分式と等価で、均一面での相殺誤差を抑える。
Gaussian も中心との差分で計算し、合成ではぼかしに使った同じ S を参照する。

## 確認シーン

`res://experiments/post_processing/presets/crt.tscn`

専用 Bloom シーンと A/B 切替は削除し、CRTプリセットで確認する。
パターン・画像切替は共通の `res://experiments/post_processing/testbed/testbed.tscn` を継承する。
Inspector の Phosphor Bloom から ON/OFF と各パラメータを調整する。

線形 HDR 1x / 2x / 4x / 8x / 16x、細線、文字、色、階調などを既存パターンで確認する。
CanvasItem の描画色を linear_to_srgb() で渡し、HDR バッファの値が意図した倍率になるようにする。

## 検証記録

以下は一本化前の A/B 比較時の記録。Godot 4.7.2 / Forward+ / D3D12 / HDR 2D、
当時の初期値 Near Width = 2、Far Width = 16、Near Strength = 0.06、
Far Strength = 0.01、HDR Limit = 2 で確認した。
A は現在と同じ HDR 制限式、B は旧線形応答。
数値検証では Signal と Mask を無効にした独立 Viewport も使用した。

| 検証 | 結果 |
| --- | --- |
| 均一な RGB 比率 1:0.3:0.1、線形 HDR 1 / 2 / 4 / 8 / 16 | A/B とも OFF と画像データが完全一致。端も一致 |
| 16x の単一輝点、中央 / 端 / 角 | 最終画像の総光量誤差は 0.06% 未満 |
| 単色 R / G / B | source・halo に他チャンネルの混入なし |
| Limited の HDR source | 最大成分は 1 / 約1.63 / 約1.95 / 約2 / 約2。RGB 比率を維持 |
| Linear で Limit を 1.01 / 16 に変更 | 画像データが完全一致 |
| 540 / 720 / 1080 / 2160p | Near/Far 幅を高さに比例して換算。Far 実測は1080p換算で約16.03px |
| 移動する 8x 輝点 | 現在位置と同じフレームで source / Bloom 更新。旧位置に残像なし |
| Layer 1 / Layer 2 の前段処理 | Bloom source の Core 画像と OFF の最終画像が完全一致 |
| 強度ゼロ、Resource 変更後の PostProcessing 再構築 | Bloom pass と中間描画の停止、再構築後の正常動作を確認 |

Near は低解像度で 1px 前後になるため離散化の影響があり、
実測 FWHM の1080p換算は約1.90〜2.13px。
線形 HDR 16x の比較では Linear でも図形の輪郭は保たれた。
Limited は周辺光を抑えるが、当時の検証だけで制限が必須とは判断していない。
比較後、周辺光を抑える方式を採用し、現在は A/B 切替を保持していない。

## Pass source の API

`create_pass_source(pass_index, context: PassSourceContext, material)` を拡張点とする。
context は main_viewport、layer_index、preceding_passes、is_enabled() を提供する。
preceding_passes は同じ CanvasLayer 上の先行 pass のみを描画順に含み、現在の pass は含まない。
配列は読み取り専用で、各 pass は共有 ShaderMaterial と is_enabled() のみを公開する。
有効状態は現在の状態を取得し、前段の ON/OFF や PostProcessing 全体の ON/OFF に追従する。
context と source の寿命は一回の生成から次の再構築まで。
Bloom は PostProcessing 内部の EffectBinding や描画ノード、親 PostProcessing の型を参照しない。

移行後の確認では、Layer 1 / Layer 2 の前段処理を含む 256×1080 の HDR 画像が
移行前と全ピクセル完全一致した。前段・Bloom・Effect・PostProcessing 全体の ON/OFF と
Resource 変更後の再構築も確認した。
Limit = 1.0 / 1.1 / 2.0 / 16.0 で値は有限、均一面は OFF と完全一致。
既存 CRT test の入力は線形 1 / 約1.999 / 4 / 8 / 16 と alpha = 1 を確認した。
約1.999 は HDR バッファの半精度丸めによる。

## 描画構成と負荷

Emissionへ共有するCanvasLayerの変換には、追従を含まない`transform`を使用する。
共有CanvasはWorld2Dの親Canvasとの関係を保持しており、カメラ追従は親から適用される。
`get_final_transform()`を渡すと追従が二重に適用され、Layer2のダメージ表示と
Bloom sourceの位置がずれる。合成でずれた位置から発光分を差し引くため、黒い数字状の跡になる。

Godot 4.7.2で実際のDamageNumberシーンを使い、320×180のHDR Viewportで確認した。
Bloom以外のCRT処理を無効にして、Bloom OFFの画像とEmissionの画像を比較したところ、
カメラの平行移動、1.2倍拡大と平行移動の両方で修正後は全ピクセルが完全一致した。
旧変換ではそれぞれ1,837 / 3,790ピクセルにRGB差0.001を超える不一致が発生した。

全解像度の HDR SubViewport を 6 枚使用する。
Core を前段処理ごと再描画した Emission、共通 Source、Near の縦横、Far の縦横で構成する。
元画像に戻る循環依存を作らず、同じフレームの Core 出力を取得する。
無効時は中間 Viewport の描画を止める。確保したテクスチャは保持する。
メモリと描画負荷の最適化は未実施。

TODO: 見た目とパラメータの確定後に 1080p / 1440p / 2160p で GPU 時間を計測する。
重い場合は Near を全解像度のまま、Far だけ 1/2 または 1/4 解像度化を検討する。
低解像度化時には FWHM 換算、正規化、光量保存、画面端を再検証する。

既存 Beam shader と Glow は変更していない。
共通 PostProcessing の変更は pass source の context 提供に限る。
