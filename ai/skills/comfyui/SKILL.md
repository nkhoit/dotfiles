---
name: illustrious
description: Generate anime images using ComfyUI with Illustrious/NovaAnimeXL model. Default image generation method for booru-style tag prompts. Use this unless user explicitly requests "lumina" or "netayume".
---

# ComfyUI Skill (Illustrious)

Generate images via a remote ComfyUI server. **This is the default image generation method.**

## Configuration

The skill reads its config from environment variables. Defaults shown below; override per machine in your shell rc:

| Variable | Default | Purpose |
|----------|---------|---------|
| `COMFYUI_ENDPOINT` | `http://localhost:8188` | ComfyUI server URL |
| `COMFYUI_OUTPUT_DIR` | `~/Pictures/comfyui-generated` | Where generated images land |
| `COMFYUI_CHAR_DB` | `~/anime-char-db` | Character DB root (markdown only) |
| `COMFYUI_MODEL` | `novaAnimeXL_ilV180.safetensors` | Default checkpoint |

The model checkpoint must exist on the ComfyUI server. The endpoint must be reachable from the machine running the skill.

## Scripts

The skill ships one Python entry point at `scripts/comfyui.py` with two subcommands: `generate` and `download-ref`. Pillow is required for `download-ref` (`pip install --user pillow`).

Resolve the script path via the skill directory the agent loaded — don't hardcode it. On invocation, the agent already knows where the skill lives.

## Workflow

**Responsibility split:** the main session owns ALL character DB work and prompt crafting. Sub-agents NEVER touch the DB — they only invoke `comfyui.py generate` and return the result path.

When a user requests an image:

### Step 0 — Character DB lookup (main session only)

If the request involves a named character:

1. Read `$COMFYUI_CHAR_DB/INDEX.md` (check aliases too).
2. Check `$COMFYUI_CHAR_DB/BLOCKED.md` — refuse if listed.
3. **If found:** read `<franchise>/<slug>/profile.md`. Use its **Prompt Block** as your positive-prompt base and its **Negative Hints** as your negative-add base.
4. **If missing — add to DB BEFORE generating (all done in main session):**
   a. Find 1–2 reference image URLs (Danbooru search pattern below).
   b. For each ref URL, run `comfyui.py download-ref --url <url> --name <slug>` to get a normalized PNG in temp.
   c. Show the user which URLs you used (so they can sanity-check the references).
   d. Vision-analyze the best ref (single image per Read call — see vision rules below).
   e. Write `<franchise>/<slug>/profile.md` following `_TEMPLATE.md`.
   f. Write `<franchise>/<slug>/metadata.json` with: `name`, `franchise`, `slug`, `character_tag`, `aliases`, `added_by`, `added_on`, `source_refs` (list the URLs from step a).
   g. Append entry to `INDEX.md` (table row + "By Franchise" section).
   h. Verify the new slug dir contains `profile.md` and `metadata.json`. **Do NOT commit the downloaded reference images** — they live in temp and expire on their own.
   i. Tell user: "Added <name> to the character DB."

### Step 1 — Build positive prompt (main session)

Start from the profile's Prompt Block, then add:
- Character details if not in the block (hair, eye color)
- Pose, expression, action
- Composition (framing, camera angle)
- Lighting and atmosphere
- Quality tags: `masterpiece, best quality, newest, absurdres, highres`

### Step 2 — Build negative prompt (main session)

Start from the profile's Negative Hints, then add:
- Unwanted alternatives (want black dress? block `white dress, red dress`)
- Composition conflicts (want close-up? block `wide shot, full body`)
- Pose defaults (want specific pose? block common defaults)
- Multi-character issues (2+ chars? block `solo`)
- For most images, `--negative-add` suffices (appends to defaults)
- Only use `--negative` for full override if defaults interfere

### Step 3 — Generate

Run `comfyui.py generate` directly, or spawn a minimal sub-agent whose only job is to invoke the script and return the path. Sub-agents do NOT touch the DB.

## Usage

### Single-line invocation (mandatory)

opencode/Copilot's shell integration is brittle with multi-line PowerShell — backtick continuations, `$env:TEMP` expansion, and nested quotes have caused escape loops. Keep invocations on **one line** with **literal paths**:

```
python <skill-dir>/scripts/comfyui.py generate --prompt "1girl, march 7th \(honkai: star rail\), short pink hair, cheerful, masterpiece, best quality, newest, absurdres, highres" --negative-add "long hair, blonde hair" --ratio portrait --name march7
```

The script writes to `$COMFYUI_OUTPUT_DIR/<slug>-<timestamp>.png` by default. Pass `--name` to control the slug, or `--output <absolute-path>` to override entirely. The script prints the final absolute path on the **last line of stdout** — grab that and return it to the user. All progress messages go to stderr.

**Do not** use `powershell -Command "..."` wrapping, `$env:TEMP`, backtick line continuations, or `python3` on Windows (use `python`). If the same invocation fails twice with quoting errors, stop and write a `.ps1` file instead.

### Expected polling output (not a loop)

```
[0s] Queue: 1 running, 0 pending
.........[15s still 1R/0P]........[30s still 1R/0P]...
[45s] Queue: 0 running, 0 pending
Generated: ComfyUI_00268_.png
```

Identical consecutive dots are **not** a retry loop — it's just the worker churning. Give it up to ~60s with hires before worrying.

## Danbooru reference search (for char DB)

**Base query:** `<character_tag> solo rating:g order:score`

**Prefer official art first:** try `<character_tag> official_art rating:g` — if ≥3 results, use those. Otherwise fall back to high-score fanart.

**Post-fetch filters (apply in code before downloading):**
1. **Max 3 character tags** — reject posts where `tag_string_character` has >3 entries.
2. **Min resolution** — reject posts below 800px on either dimension.
3. **Exclude style tags** — skip `monochrome`, `greyscale`, `sketch`, `lineart`, `pixel_art`, `chibi`.
4. **Prefer `highres` tag** when sorting.

**Search snippet:**
```python
import json, urllib.request

def search_danbooru(character_tag, limit=10, ref_filter_tags=None):
    for tags_extra in ['official_art', 'score:>15']:
        url = f'https://danbooru.donmai.us/posts.json?tags={character_tag}+{tags_extra}+solo+rating:g&limit={limit}&order=score'
        req = urllib.request.Request(url, headers={'User-Agent': 'comfyui-skill/1.0'})
        posts = json.loads(urllib.request.urlopen(req, timeout=15).read())
        good = []
        for p in posts:
            chars = p.get('tag_string_character', '').split()
            gen = p.get('tag_string_general', '').split()
            if len(chars) > 3: continue
            if (p.get('image_width', 0) < 800 or p.get('image_height', 0) < 800): continue
            if any(t in gen for t in ('monochrome', 'greyscale', 'sketch', 'lineart', 'pixel_art', 'chibi')): continue
            if ref_filter_tags and not any(t in gen for t in ref_filter_tags): continue
            good.append(p)
        if len(good) >= 3:
            return good[:limit]
    return good
```

## CRITICAL: Downloading reference images (the WebP trap)

Many image hosts (Zerochan, Pinterest, Twitter, Reddit, Pixiv) serve **WebP** even when the URL ends in `.jpg`. Saving WebP as `.jpg` and Reading it makes vision endpoints fail with `'url' field must be a base64 encoded image` — and that **poisons the session**: every subsequent turn replays the bad message.

**Rule:** always download via `comfyui.py download-ref`. It re-encodes to PNG and prints the final path.

```
python <skill-dir>/scripts/comfyui.py download-ref --url "https://example.com/character.jpg" --name "belle"
# Prints: <tmp>/belle-<timestamp>.png
# Then: Read that path
```

The script exits non-zero on failure.

**Never Read a raw downloaded image directly. Always go through the helper.**

### If you do poison the session

Symptom: every new turn returns `'url' field must be a base64 encoded image` before the model even thinks.

Recovery, in order:
1. `/compact` — usually drops the raw attachment.
2. Re-encode the offending file to a valid PNG in place.
3. Manually edit session storage to delete the message with the bad attachment.
4. `/new` and restate context.

## Vision analysis for character refs

DO NOT batch multiple images into one Read call — multi-image payloads can timeout or silently drop images. Instead:

- Read ONE image per call.
- For multiple angles, do 2–3 separate Reads and merge findings into `profile.md`.

## Generation pattern

```
python <skill-dir>/scripts/comfyui.py generate --prompt "1girl, <character tags>, <scene tags>, masterpiece, best quality, newest, absurdres, highres" --negative-add "unwanted tags" --ratio portrait --name <slug>
```

Send the absolute path (last line of stdout) back to the user.

### Speed vs quality cues

| User says... | Action |
|--------------|--------|
| "quick", "fast", "draft", "simple" | Add `--no-hires` (~15s) |
| "high quality", "detailed", "best quality" | Keep hires on (~45s, default) |
| No preference | Use default (hires on) |

## Script parameters (`generate` subcommand)

### Core
- `--prompt`: positive prompt (booru tag style)
- `--negative`: full negative prompt (replaces defaults)
- `--negative-add`: additional negatives (appended to defaults) ← **use this usually**
- `--output`: explicit output path (default: auto-named in `$COMFYUI_OUTPUT_DIR`; relative paths resolve inside it)
- `--name`: filename slug when `--output` is auto (default: derived from prompt)
- `--ratio`: `square` / `portrait` / `tall` / `landscape` / `wide`

### Advanced
- `--width`, `--height`: custom dimensions (overrides ratio)
- `--steps`: base inference steps (default: 30)
- `--cfg`: CFG scale (default: 4.5)
- `--seed`: seed (-1 for random)
- `--no-hires`: disable hires fix (~15s vs ~45s)
- `--hires-scale`: upscale factor (default: 1.5)
- `--hires-steps`: hires pass steps (default: 40)
- `--hires-denoise`: hires denoise strength (default: 0.4)
- `--lora NAME`: load a LoRA (repeatable)
- `--lora-strength N`: LoRA strengths in order (default: 1.0 each)

### Default negative prompt
```
(photorealistic, realistic:1.2), 3d, multiple views, split view, grid view,
border, letterboxed, (worst quality, bad quality:1.2), lowres, blurry,
deformed, extra fingers, missing fingers, conjoined fingers, mutated hands
and fingers, wrong hand, bad hands, bad anatomy, bad proportions, extra legs,
extra arms, missing limb, disfigured, ugly, long body, jpeg artifacts,
signature, watermark, text, username, simple background
```

## Prompting tips

Use **booru tag style**:
```
1girl, character name, franchise, hair color, eye color, expression, action, setting, masterpiece, best quality, newest, absurdres, highres
```

### Positive prompting

**Weights for emphasis** — `(element:1.2)` to strengthen something being ignored:
```
(black sundress:1.2), (floating hair:1.1)
```

**Layered descriptions:**
```
off-shoulder crop top over black tank top, open jacket
```

**Pose vocabulary:**
- Body: `contrapposto, arched back, leaning forward, sitting, kneeling`
- Arms: `arms up, reaching, hugging own legs, hand on hip`
- Head: `head tilt, turning head, looking back, looking at viewer`

**Camera/angle stacking:**
```
from above, dutch angle, portrait, close-up, upper body
```

**BREAK separator** — separates subject from background/lighting:
```
1girl, outfit, pose, expression, BREAK, night sky, city lights, volumetric lighting
```

**Lighting:**
- Dramatic: `rim light, backlit, volumetric lighting, cinematic lighting`
- Soft: `dappled sunlight, soft lighting, diffused light`
- Effects: `bokeh, lens flare, light particles, depth of field`

### Negative prompting strategy

Think about what the model might do *instead* of what you want:

| Want... | Block... |
|---------|----------|
| Black dress | `white dress, red dress` |
| Close-up | `wide shot, full body` |
| Night scene | `sunset, daylight` |
| Specific pose | `arms behind back, standing` |
| 2+ characters | `solo` |
| Chibi on head | `same size, standing side by side` |

## Notes
- No content filter — use character names directly
- Hires fix on by default for sharper details
- Final output: 1.5× base resolution (e.g., tall → 1152×2016)
- Generation time: ~45s with hires, ~15s without
