# Main2 HD-2D Production Gate V6

Production rendering and offline reference art are separate stages. The **high-quality image renderer** is the existing \`tools/global_art_ai_provider_v3.py\` model bridge, not a pure-Python geometry painter. The V6 gate adds independent checks for 12-frame pose duplication, front/left/back/right differences, 8×8 tile seams, SHA256 source provenance, per-item review and non-destructive staging.

## Run on Main2

\`\`\`powershell
py -m pip install Pillow openai
py tools/hd2d_production_gate_v6.py jobs --project . --scope all
py tools/hd2d_production_gate_v6.py render --project . --scope characters --limit 8 --quality xhigh
py tools/hd2d_production_gate_v6.py audit --project .
\`\`\`

\`jobs\` is free. \`render\` requires \`OPENAI_API_KEY\` and invokes the existing canonical AI provider. \`audit\` reads its real PNG candidates from \`build/starlit_global_art_factory_v3/model_sources\`, writing \`build/starlit_hd2d_production_gate_v6/review.json\`. It does not assert that missing images were rendered.

After visual verification, set **only truly reviewed** rows to \`visual_approved: true\`, preserving their SHA256:

\`\`\`powershell
py tools/hd2d_production_gate_v6.py stage --project . --review build/starlit_hd2d_production_gate_v6/review.json
\`\`\`

The staged PNGs appear under \`build/starlit_hd2d_production_gate_v6/staged/<group>/<id>.png\`, ready as candidate input for \`tools/global_art_factory_v3.py --source-root ...\`. V6 does NOT overwrite active runtime assets, and a successful machine check never equals artistic or real gameplay acceptance.

**Frame and atlas rules:** actor and NPC runtime sheets exactly 96×192 (3 columns × 4 rows, each 32×48); four different directions; every cell nonempty; monsters/bosses 512×128 (four 128px-wide cells); terrain/interiors 256×256, 8×8 cells. V6 rejects duplicated pose sheets and noisy tile seam candidates so failed image outputs do not silently enter the production pack.

Offline illustrated preview / frame compiler source and sample pictures are separately delivered as \`Starlit_Chronicle_HD2D_Studio_V6_Source_And_Demo.zip\`. For Godot real build screenshots, run Main2 game against explicitly approved and installed assets. Model image generation requires API access; no image renders or screenshots are claimed when not actually run.
