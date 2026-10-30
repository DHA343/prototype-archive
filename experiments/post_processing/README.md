# Post-processing experiments

このフォルダは実験用ポストプロセスと確認シーンの保存先。正式採用済みの実装を示すものではない。
現在は27グループ、125モードを収録。うち既存実装を参照する5グループを含む。
追加用Resourceの一覧は [CATALOG.md](CATALOG.md)。
グループ・モード・Resourceファイル・スクリプトの対応は `catalog.json`。

## 起動と入力

`testbed/testbed.tscn` または `presets/crt.tscn` を開いてF6で実行する。
初回起動時は実際の `main/main.tscn` を表示し、次回以降は前回の選択を復元する。

- `1`: main。シミュレーションを再開する。
- `2`: 共通テストパターン。背景は黒で固定。
- `3`: 画像フォルダから自動収集した画像を順番に表示する。画像がなければパターンを表示する。
- 画像は画面全体へ引き伸ばす。パターンは1280×720を画面中央に実画素で等倍配置する。
- パターンはプロジェクトの論理解像度による拡大縮小を相殺する。mainの描画倍率は変更しない。
- 1280×720より小さい表示領域では、細線の幅を保つためパターンの外周を切り取る。
- パターンには細線、階調、色、半透明の重なり、文字、線形HDRの1x/2x/4x/8x/16xを含む。

1 / 2 / 3の選択と、画像表示時の画像パスを `res://_temp/testbed_state.cfg` に保存する。
共通testbedと全プリセットで一つの状態を共有し、切替時に更新する。
画像は自動収集済みの一覧からパスで復元し、追加・並べ替えで番号が変わっても同じ画像を選ぶ。
保存画像が見つからない場合はパターンへ、状態ファイルがない・読めない・選択値が無効な場合はmainへ戻る。
Editorからの開発用実行で使用し、`user://`には保存しない。`_temp/`はGit管理対象外。
初期化する場合はゲームを停止し、`_temp/testbed_state.cfg`を削除する。

mainは複製した専用シーンではなく元のPackedSceneを生成するため、mainの保存済み変更は
testbedの次回起動に反映される。testbed実行時の調整はmainの保存ファイルへ書き戻さない。
入力切替時は同じmainインスタンスを保持し、非表示中は処理・カメラ・CanvasLayerを止める。

二重適用を避けるため、生成したmainインスタンスのPostProcessingは空にして無効化する。
mainのLayer1が持つPixelation設定は維持し、実験側の全体ON/OFFに接続する。
エフェクトの構成や調整値はtestbed側で設定する。実験の調整値は正式シーンへ書き戻さない。

## エフェクトの設定

合成段階の仕様は [描画と合成](../../docs/rendering.md) を参照する。
Layer1 / Layer2は描画順に応じた配置先。1・2はCanvasLayer.layerの実際の値とは区別する。
各配列は対応するレイヤーまでに描かれた画面全体へ適用する。Overlayは全エフェクトの後に描く。
testbedのLayer2/Labelsはパターン専用の説明で、Labelsだけを入力に応じて表示切替する。
共通の確認要素はLayer2の別の子、またはOverlayへ配置できる。

実行時のエフェクト編集パネルは設けない。testbedまたは各プリセットシーンのPostProcessingを
Inspectorで編集し、Layer 1 Effects / Layer 2 Effects配列にエフェクトのResourceを設定する。
[一覧](CATALOG.md)にある `<group>.tres` をFileSystemから配列へドラッグする。
例えばPaintingは `effects/painting/painting.tres` を使用する。
各Resourceの表示名は `Painting` のようにエフェクト名のみとする。
実験用であることはフォルダ配置で示し、個別ファイル名・クラス名・表示名へExperimentalを付けない。
まずはそのまま追加し、実行中にResourceの設定値を調整する。
同じResourceを参照するプリセットでは設定が共有される。プリセットごとに分けたい場合は、
FileSystemで.tres自体を複製し、別名のファイルを配列へ追加してから調整する。
実験Resourceの設定はDictionaryに保存するため、通常の「ユニーク化」だけでは
Dictionaryの共有が残る。これを設定分離の手順として使用しない。

- Layer 1 Effects: Layer1までに描かれた画面全体へ適用する。
- Layer 2 Effects: Layer2までに描かれた画面全体へ適用する。Layer1とその加工結果も含む。
- 配列の順序: エフェクトの適用順。追加・削除・並べ替えはInspectorの配列編集を使う。
- 個別Resource: Mode、数値、色、テクスチャなどをInspectorで調整する。
- Enabled: PostProcessingでは全体、個別ResourceではそのエフェクトのON/OFF。
- 同じグループを複数回使う場合は、別のResourceインスタンスを設定する。同一インスタンスの重複登録は無視される。

VHSは録画・再生側の信号加工、CRTは表示側の走査線・マスク・発光を担当する。
組み合わせる場合はVHS → CRTの順に置き、マスクをVHSで揺らさない。
VHSはMode切替を設けず、InspectorをPlayback / Luma / Chroma / Time Base / Dropoutに分ける。
各設定の単位・無加工条件は [VHSの調整](effects/vhs/PARAMETERS.md) を参照する。

保存する設定はシーン・ResourceをInspectorで編集して保存する。
追加用ResourceはLocal to SceneをOFFにし、実行時の自動複製を行わない。
Editorのライブ編集（シーン変更の同期）が有効な状態で、Local InspectorまたはFileSystemから
実行中に使っているResourceを開いて数値・Modeを変更する。設定を残す場合はResourceを保存する。
すでにONで起動したゲームには設定変更が遡及しないため、一度停止して再実行する。
実行中の一時調整にはRemote Inspectorを使う。Remoteでの変更はシーンファイルには自動保存されない。
Mode変更時の処理構成の更新はtestbed側が行うため、実行時パネルに依存しない。
スクリプトから実行中の配列をappend/remove/並べ替えする場合は、変更後にrebuild_effects()を呼ぶ。

入力切替は1 / 2 / 3で行う。画像は`testbed/images/`へ追加すればよく、配列への手動登録は不要。
起動時にフォルダ直下のTexture2Dをファイル名の昇順で収集する。サブフォルダや画像以外は対象外。
GodotがインポートできるPNG / JPEG / WebP / BMP / SVG等の画像を使用できる。
追加・削除はGodotのインポート完了後、testbedの次回起動に反映する。実行中はフォルダを監視しない。
画像はResourceLoaderで読み込み、Ctrl+Oや画像選択ダイアログは設けない。

## 配置と共通基盤

`testbed/testbed.tscn` は入力切替・テスト素材・mainの生成を担当する共通シーン。
`presets/` にエフェクトの組み合わせと調整値を保存する継承シーンをまとめる。
最初のプリセットは `presets/crt.tscn`。グループごとの単体previewは作成しない。

`effects/<group>/` にResourceスクリプト、シェーダー、仕様書を置く。
配列へ追加するための `<group>.tres` も同じフォルダに置く。
追加用Resourceは既存の実装と初期値を使い、Local to SceneをOFFにする。
実験時にLocal Inspectorから値を調整してライブ反映できる構成を優先する。
同じResourceを使う複数のインスタンスでは、変更も共有される。
同じ役割の方式はModeにまとめる。
例外としてCRTは従来の複数パス・仕様書を同じフォルダ内に保持する。
既存のVignette、Chromatic Aberration、Display Texture、Glowは参照する薄いResourceを置く。

`effects/_shared/` はシェーダー関数、動的パラメータ、履歴、縮小・拡大処理を共有する。
新しいResourceはShaderのuniformからInspectorの設定項目を生成する。
RenderLayersとPostProcessingは正式側の共通基盤を参照し、実験用の入力・補助バッファ・UIはtestbed側に置く。

`testbed/patterns/reference_set.tscn` は追加の図形・グラデーション・文字の素材。
`testbed/images/` は共通確認画像の保存先。起動時に自動収集し、表示順はファイル名で決まる。

## プリセットの作成

1. `testbed/testbed.tscn` を元にGodot Editorで「新しい継承シーン」を作成する。
2. `presets/<任意の名前>.tscn` に保存する。プリセットはシーン名で識別する。
3. [一覧](CATALOG.md)の `<group>.tres` を、
   PostProcessingのLayer 1 Effects / Layer 2 Effectsへドラッグする。
4. プリセット専用の設定にしたい場合は、手順3の前に.tresをFileSystemで複製し、
   そのファイルを使用する。Local to SceneはOFFのままにする。Scriptの差し替えは不要。
5. シーンを保存し、F6で実行する。入力切替と画像収集は共通testbedから引き継ぐ。

既存の `presets/crt.tscn` を複製して、配列の構成や調整値を変更してもよい。
外部の同じResourceファイルを参照すれば値も共有される。
プリセット間の設定を独立させる場合は、Resourceファイルも複製して別々に保持する。
従来のCRTプリセットはシーン内の組み込みResourceとLocal to Sceneの設定を保持している。
共通testbedの変更は継承先にも反映される。プリセット側で上書きした項目は、その値を優先する。

## 擬似3D

Pseudo 3Dは2D入力から高さ場を作る。実際の3Dシーンの深度や形状を復元する処理ではない。

- Depth source: 輝度、縦方向の平面、ドーム形状、任意の深度画像を選択する。
- 深度は黒=近、白=遠。Invert depthとDepth scaleで調整する。
- Custom depth: データ画像のRチャンネルを読む。Depth sourceをCustom Depth Mapに設定する。
- 法線は深度の周辺差分から作る。Custom normalを指定し、Use custom normalをONにするとRGB法線を使う。
- 法線画像はRGBを[-1,1]へ変換する。正面はRGB=(0.5,0.5,1)、Yの正方向は画面下。

SSAOは高さ場の近傍遮蔽、SSRは高さ場に対する画面内レイマーチ、接触影は光方向への深度比較。
SSILは深度が近い周辺の色を間接光として加算する。Volumetric Fogは画面上の仮の視線に沿って
ノイズ密度を積分する。実際の3D空間の遮蔽・間接照明・体積を取得するものではない。
画面外の反射や隠れている形状は描画できない。結果は入力の明るさや指定した高さ場に依存する。
被写界深度とボケはフォーカス深度に応じた円盤サンプリング。フォグや法線ライティングも同じ深度を使う。

## 対象マスク・速度・履歴

Target EffectsとMotion Blur用に、mainのOrb・Enemyの円形Visualからマスクと画面速度を描く。
汎用の全ノード自動認識ではない。testbedルートのMask orb / Mask enemiesで対象を選ぶ。
パターンではHDR色パッチ、画像では中央の円を仮の対象とする。
Custom maskはR=対象の重み。Custom velocityはRG=0.5+UV移動量×8、B=対象の重み。
ルートのMask image / Velocity imageは自動生成バッファ全体の上書き用。

時間効果はフレームの履歴を保持する。入力切替、Mode・パラメータ変更、再有効化、解像度変更時に履歴をリセットする。
Frame Holdは指定fpsで入力を更新する。Auto Exposureは入力を縮小して平均対数輝度を求め、露出を追従させる。
Temporal AAは速度で履歴を移動して近傍の色範囲へ制限する実験的な時間フィルタで、投影ジッターは使わない。

履歴・露出は現段階ではGPU画像をCPUへ読み戻すため、複数併用・高解像度では重くなりやすい。
Dual KawaseとMulti-scale BloomはHDR SubViewportの4段の縮小・拡大を使う。
重いサンプリングを行う方式も含むため、最終的なゲーム向けの最適化・品質調整は別途行う。

## LUTとディザ

標準のFilm LUTとBlue Noiseを同梱する。
LUTはN×N×Nの立方体をN²×Nの横長画像に配置し、Bのスライスを左から右に並べる。
各スライスのX=R、Y=G。Lut sizeをNに合わせる。HDR入力は0〜1へ制限して変換する。

## CRT

`effects/crt/crt.gd`（クラス名: `CRT`）と `crt.gdshader` がCRT本体。
他のエフェクトと同じ命名と配列への追加方法を使う。
`presets/crt.tscn` は旧crt_display_testの後継。
従来の色調補正・CRT・ビネットと保存済み調整値を保持し、選択中のmain・パターン・画像に適用する。
個別ON/OFFとパラメータ変更は正式側の調整から独立している。

CRTのスクリプト・シェーダー・UID・仕様書は前の移行でここへ移動済み。
正式側で使用中のCRT参照も移行先を指す。旧phosphor_bloom_testは参照先スクリプトが
削除済みだったため整理済み。CRT内部のBloomの仕様は
[PHOSPHOR_BLOOM.md](effects/crt/PHOSPHOR_BLOOM.md)を参照する。
