# ボール

- `ball.tscn` を任意の2Dシーンへ配置する。描画・当たり判定・重力・反射を持ち、配置すると自動で物理更新する。
- ルートのBallを選び、Inspectorでインスタンスごとに設定する。
  - Motion → Gravity：重力。0で無重力。単位はpx/s²。
  - Motion → Restitution：反発係数。0〜1。
  - Appearance → Color：色。
  - Appearance → Intensity：色強度。0〜8、標準は1。
- 色と色強度はエディター上の球にも反映する。強度1を超えるHDR表示には、利用先のViewportでHDR 2Dを有効にする。
- 衝突対象はレイヤー1、球はレイヤー2。必要に応じてCollision Layer/Maskを設定する。
- ピンボール専用の落下復帰・フリッパー・バンパー処理は含めない。ピンボール側はこのシーンとスクリプトを継承する。
- 外部で更新を管理する場合は `set_physics_process(false)` で自動更新を止め、`step(delta)` を呼ぶ。
- `godot --headless --path . --script res://experiments/ball/tests/ball_test.gd` で単独動作、重力・反発係数・色強度、設定のシーン保存を検証する。
