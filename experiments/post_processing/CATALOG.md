# Effect catalog

共通testbedから追加・並べ替え・調整できる27グループ、125モード。
各行のリンクは配列へ追加する実験用Resource（.tres）。
組み合わせと調整値はpresets/の継承シーンに保存する。スクリプトとの対応はcatalog.jsonを参照。
作成方法は[README](README.md#プリセットの作成)を参照。

| 追加用Resource | モード | 数 |
| --- | --- | ---: |
| [Color Grading](effects/color_grading/color_grading.tres) | Exposure / Temperature / Tint / Vibrance / Shadows / Midtones / Highlights / Channel Mixer / Brightness / Contrast / Saturation / Hue / Gamma | 11 |
| [Color Transform](effects/color_transform/color_transform.tres) | Monochrome / Sepia / Negative / Duotone / Gradient Map / LUT / Solarization / Selective Color / Thermal / Night Vision | 10 |
| [Dithering](effects/dithering/dithering.tres) | Posterize / Palette / Bayer / Random / Blue Noise | 5 |
| [Pixelation](effects/pixelation/pixelation.tres) | Rectangular Mosaic / Hexagonal Mosaic / LED Dots / Low Resolution Nearest / Low Resolution Bilinear | 5 |
| [Print](effects/print/print.tres) | Halftone / CMYK Screens / Crosshatch / Paper / Misregistration | 5 |
| [Detail](effects/detail/detail.tres) | Sharpen / Unsharp Mask / Sobel / Outline / Emboss | 5 |
| [Painting](effects/painting/painting.tres) | Kuwahara / Bilateral / Color Planes / Comic | 4 |
| [Blur](effects/blur/blur.tres) | Gaussian / Dual Kawase / Directional / Radial / Zoom / Tilt Shift | 6 |
| [Lens](effects/lens/lens.tres) | Multi-scale Bloom / Soft Focus / Halation / Anamorphic Streak / Starburst / Lens Ghosts / Lens Dirt | 7 |
| [Distortion](effects/distortion/distortion.tres) | Barrel / Pincushion / Fisheye / Ripple / Waves / Heat Haze / Swirl / Kaleidoscope | 8 |
| [Film](effects/film/film.tres) | Film Grain / Color Noise / Monochrome Noise / Dust and Scratches / Flicker / Film Weave | 6 |
| [VHS](effects/vhs/vhs.tres) | 輝度・色の劣化、横揺れ、局所的な横ずれ | 1 |
| [Glitch](effects/glitch/glitch.tres) | Block Displacement / Horizontal Bands / Channel Dropout / Local Inversion / Compression Damage | 5 |
| [Display](effects/display/display.tres) | CRT Glass / LCD Grid / Dot Matrix / Glass Reflection | 4 |
| [Screen Cues](effects/overlay/overlay.tres) | Flash / Colored Edge / Letterbox / Circular Mask / Wipe / Dissolve | 6 |
| [Temporal](effects/temporal/temporal.tres) | Afterimage / Frame Blend / LCD Response / Phosphor Persistence / Feedback / Frame Hold / Temporal AA | 7 |
| [Auto Exposure](effects/auto_exposure/auto_exposure.tres) | Auto Exposure | 1 |
| [Target Effects](effects/target/target.tres) | Target Outline / Target Glow / Target Distortion | 3 |
| [Motion Blur](effects/motion_blur/motion_blur.tres) | Object Motion Blur | 1 |
| [CRT](effects/crt/crt.tres) | CRT | 1 |
| [Pseudo 3D](effects/pseudo_3d/pseudo_3d.tres) | Depth of Field / Bokeh / Depth Fog / SSAO (pseudo) / SSR (pseudo) / Contact Shadows / Light Shafts / Normal Lighting / Depth Outline / SSIL (pseudo) / Volumetric Fog (pseudo) | 11 |
| [Antialiasing](effects/antialiasing/antialiasing.tres) | FXAA / Morphological AA | 2 |
| [Vignette](effects/vignette/vignette.tres) | Vignette | 1 |
| [Chromatic Aberration](effects/chromatic_aberration/chromatic_aberration.tres) | Chromatic Aberration | 1 |
| [Texture Overlay](effects/display_texture/display_texture.tres) | Texture Overlay | 1 |
| [Glow](effects/glow/glow.tres) | Glow (existing) | 1 |
| [Tone Mapping](effects/tone_mapping/tone_mapping.tres) | Linear Clamp / Reinhard / Extended Reinhard / ACES Approximation / Hable / Filmic / Logarithmic | 7 |

方式の名前が同じでも映画機材や実機の完全再現を意味しない。VHS・圧縮劣化・LCD等は画面加工による近似。
FXAAとMorphological AAは実験的な画面エッジ平滑化。Morphological AAはSMAAの専用検索テーブルを使わない。
ACES Approximationは近似曲線であり、正式なACES全体の色管理パイプラインではない。
SSAO / SSR等の擬似3Dと時間フィルタの条件は[README](README.md)を参照。

モードを変更するuniformはmode。Resourceのparameters辞書に初期値との差分を保存する。
新しいエフェクトはcatalog.jsonにも登録する。確認用シーンが必要な組み合わせだけ、
共通testbedを継承してpresets/に保存する。
