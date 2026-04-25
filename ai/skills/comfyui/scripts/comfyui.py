#!/usr/bin/env python3
"""ComfyUI helper: generate images and download reference images.

Subcommands:
    generate       Queue a ComfyUI workflow and download the result.
    download-ref   Download an image URL and re-encode to PNG.

Configuration via environment variables (with sensible defaults):
    COMFYUI_ENDPOINT     Server URL                (default: http://localhost:8188)
    COMFYUI_OUTPUT_DIR   Generated image output    (default: ~/Pictures/comfyui-generated)
    COMFYUI_CHAR_DB      Character DB root         (default: ~/anime-char-db)
    COMFYUI_MODEL        Default checkpoint name   (default: novaAnimeXL_ilV180.safetensors)
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
ENDPOINT = os.environ.get("COMFYUI_ENDPOINT", "http://localhost:8188").rstrip("/")
OUTPUT_DIR = Path(os.environ.get("COMFYUI_OUTPUT_DIR", str(Path.home() / "Pictures" / "comfyui-generated"))).expanduser()
DEFAULT_MODEL = os.environ.get("COMFYUI_MODEL", "novaAnimeXL_ilV180.safetensors")


def err(msg: str) -> None:
    print(f"comfyui: {msg}", file=sys.stderr)


def fail(msg: str, code: int = 1) -> None:
    err(msg)
    sys.exit(code)


# ===========================================================================
# generate subcommand
# ===========================================================================
RATIO_PRESETS = {
    "square":    (1024, 1024),
    "portrait":  (832, 1216),
    "tall":      (768, 1344),
    "landscape": (1216, 832),
    "wide":      (1344, 768),
}

DEFAULT_NEGATIVE = (
    "(photorealistic, realistic:1.2), 3d, multiple views, split view, grid view, "
    "border, letterboxed, (worst quality, bad quality:1.2), lowres, blurry, "
    "deformed, extra fingers, missing fingers, conjoined fingers, mutated hands "
    "and fingers, wrong hand, bad hands, bad anatomy, bad proportions, extra legs, "
    "extra arms, missing limb, disfigured, ugly, long body, jpeg artifacts, "
    "signature, watermark, text, username, simple background"
)


def build_workflow(prompt, negative, model, width, height, steps, cfg, seed,
                   clip_skip=2, hires=False, hires_scale=1.5, hires_steps=40,
                   hires_denoise=0.4, loras=None):
    """Build a txt2img workflow, optionally with hires fix and LoRA chain."""
    actual_seed = seed if seed >= 0 else int(time.time() * 1000) % (2**32)

    workflow = {
        "4": {"class_type": "CheckpointLoaderSimple", "inputs": {"ckpt_name": model}},
        "5": {"class_type": "EmptyLatentImage", "inputs": {"width": width, "height": height, "batch_size": 1}},
    }

    # LoRA chain
    model_source = ["4", 0]
    clip_source = ["4", 1]
    if loras:
        prev_model, prev_clip = ["4", 0], ["4", 1]
        for i, (lora_name, lora_strength) in enumerate(loras):
            node_id = str(20 + i)
            workflow[node_id] = {
                "class_type": "LoraLoader",
                "inputs": {
                    "lora_name": lora_name,
                    "strength_model": lora_strength,
                    "strength_clip": lora_strength,
                    "model": prev_model,
                    "clip": prev_clip,
                },
            }
            prev_model, prev_clip = [node_id, 0], [node_id, 1]
        model_source, clip_source = prev_model, prev_clip

    workflow["10"] = {"class_type": "CLIPSetLastLayer",
                      "inputs": {"stop_at_clip_layer": -clip_skip, "clip": clip_source}}
    workflow["6"] = {"class_type": "CLIPTextEncode", "inputs": {"text": prompt, "clip": ["10", 0]}}
    workflow["7"] = {"class_type": "CLIPTextEncode", "inputs": {"text": negative, "clip": ["10", 0]}}
    workflow["3"] = {"class_type": "KSampler", "inputs": {
        "seed": actual_seed, "steps": steps, "cfg": cfg,
        "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": 1,
        "model": model_source, "positive": ["6", 0], "negative": ["7", 0],
        "latent_image": ["5", 0],
    }}

    if hires:
        workflow["11"] = {"class_type": "LatentUpscaleBy", "inputs": {
            "samples": ["3", 0], "upscale_method": "nearest-exact", "scale_by": hires_scale,
        }}
        workflow["12"] = {"class_type": "KSampler", "inputs": {
            "seed": actual_seed, "steps": hires_steps, "cfg": cfg,
            "sampler_name": "euler_ancestral", "scheduler": "normal", "denoise": hires_denoise,
            "model": model_source, "positive": ["6", 0], "negative": ["7", 0],
            "latent_image": ["11", 0],
        }}
        workflow["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["12", 0], "vae": ["4", 2]}}
    else:
        workflow["8"] = {"class_type": "VAEDecode", "inputs": {"samples": ["3", 0], "vae": ["4", 2]}}

    workflow["9"] = {"class_type": "SaveImage", "inputs": {"filename_prefix": "ComfyUI", "images": ["8", 0]}}
    return workflow


def queue_prompt(workflow):
    data = json.dumps({"prompt": workflow}).encode("utf-8")
    req = urllib.request.Request(f"{ENDPOINT}/prompt", data=data,
                                  headers={"Content-Type": "application/json"})
    result = json.loads(urllib.request.urlopen(req, timeout=30).read())
    if "error" in result:
        raise RuntimeError(f"Queue error: {result['error']}")
    return result["prompt_id"]


def poll_until_done(prompt_id, poll_interval=2.0, timeout=600.0):
    """Poll history until done. Auto-extends timeout based on queue depth."""
    PER_JOB_SECONDS = 120.0

    # Initial queue probe
    try:
        qd = json.loads(urllib.request.urlopen(f"{ENDPOINT}/queue", timeout=10).read())
        pending, running = qd.get("queue_pending", []), qd.get("queue_running", [])
        ahead = next((i for i, j in enumerate(pending) if len(j) >= 2 and j[1] == prompt_id), len(pending))
        if ahead > 0:
            timeout = max(timeout, timeout + ahead * PER_JOB_SECONDS)
            err(f"Queue: {ahead} ahead, {len(running)} running. Extended timeout to {int(timeout)}s.")
        else:
            err(f"Queue: {len(running)} running, {len(pending)} pending (we're next or active).")
    except Exception as e:
        err(f"Queue probe failed (continuing with timeout={int(timeout)}s): {e}")

    start = time.time()
    last_state = None
    last_heartbeat = start

    while time.time() - start < timeout:
        try:
            info = json.loads(urllib.request.urlopen(f"{ENDPOINT}/history/{prompt_id}", timeout=10).read())
            if prompt_id in info:
                entry = info[prompt_id]
                status = entry.get("status", {}).get("status_str", "")
                if status == "error":
                    raise RuntimeError(f"Generation failed: {entry}")
                if status == "success":
                    for _, out in entry.get("outputs", {}).items():
                        if out.get("images"):
                            if last_state is not None:
                                print("", file=sys.stderr)
                            return out["images"][0]["filename"]
                    raise RuntimeError("No image in output")

            qd = json.loads(urllib.request.urlopen(f"{ENDPOINT}/queue", timeout=10).read())
            running, pending = len(qd.get("queue_running", [])), len(qd.get("queue_pending", []))
            state = (running, pending)
            elapsed = int(time.time() - start)

            if state != last_state:
                if last_state is not None:
                    print("", file=sys.stderr)
                print(f"[{elapsed}s] Queue: {running} running, {pending} pending", file=sys.stderr)
                last_state = state
                last_heartbeat = time.time()
            elif time.time() - last_heartbeat >= 15:
                print(f" [{elapsed}s still {running}R/{pending}P]", end="", file=sys.stderr, flush=True)
                last_heartbeat = time.time()
            else:
                print(".", end="", file=sys.stderr, flush=True)
        except urllib.error.URLError as e:
            print(f"\nPoll error (retrying): {e}", file=sys.stderr)

        time.sleep(poll_interval)

    raise TimeoutError(f"Generation timed out after {timeout}s")


def download_image(filename, output_path):
    url = f"{ENDPOINT}/view?filename={urllib.parse.quote(filename)}"
    urllib.request.urlretrieve(url, output_path)


def cmd_generate(args):
    # Resolve output path
    if not args.output:
        if args.name:
            slug = re.sub(r"[^a-z0-9]+", "-", args.name.lower()).strip("-") or "image"
        else:
            tokens = re.findall(r"[a-z0-9]+", args.prompt.lower())[:6]
            slug = "-".join(tokens) or "image"
        ts = time.strftime("%Y%m%d-%H%M%S")
        output = OUTPUT_DIR / f"{slug}-{ts}.png"
    else:
        output = Path(args.output)
        if not output.is_absolute():
            output = OUTPUT_DIR / output
    output.parent.mkdir(parents=True, exist_ok=True)

    # Negative prompt
    if args.negative:
        negative = args.negative
    elif args.negative_add:
        negative = f"{DEFAULT_NEGATIVE}, {args.negative_add}"
    else:
        negative = DEFAULT_NEGATIVE

    # Dimensions
    if args.width and args.height:
        width, height = args.width, args.height
    else:
        width, height = RATIO_PRESETS[args.ratio]

    use_hires = args.hires and not args.no_hires

    # LoRAs
    loras = None
    if args.lora:
        strengths = args.lora_strength or []
        loras = [(name, strengths[i] if i < len(strengths) else 1.0)
                 for i, name in enumerate(args.lora)]

    err(f"Endpoint: {ENDPOINT}")
    err(f"Model: {args.model}")
    if loras:
        for name, s in loras:
            err(f"LoRA: {name} (strength: {s})")
    err(f"Size: {width}x{height} ({args.ratio})")
    err(f"Steps: {args.steps}, CFG: {args.cfg}")
    if use_hires:
        err(f"Hires: {args.hires_scale}x -> {int(width*args.hires_scale)}x{int(height*args.hires_scale)}, "
            f"{args.hires_steps} steps, denoise {args.hires_denoise}")

    workflow = build_workflow(
        prompt=args.prompt, negative=negative, model=args.model,
        width=width, height=height, steps=args.steps, cfg=args.cfg, seed=args.seed,
        hires=use_hires, hires_scale=args.hires_scale,
        hires_steps=args.hires_steps, hires_denoise=args.hires_denoise, loras=loras,
    )

    err("Queuing prompt...")
    prompt_id = queue_prompt(workflow)
    err(f"Prompt ID: {prompt_id}")

    err("Polling for result (expect ~45s with hires, ~15s without)...")
    filename = poll_until_done(prompt_id, timeout=args.timeout)
    err(f"Generated: {filename}")

    err(f"Downloading to {output}...")
    download_image(filename, str(output))

    print(str(output))


def add_generate_args(p):
    p.add_argument("--prompt", required=True, help="Positive prompt (booru tag style)")
    p.add_argument("--negative", default=None, help="Full negative prompt (replaces defaults)")
    p.add_argument("--negative-add", default=None, help="Append to default negatives")
    p.add_argument("--model", default=DEFAULT_MODEL, help=f"Checkpoint name (default: {DEFAULT_MODEL})")
    p.add_argument("--output", default=None, help=f"Output path (default: auto-named in {OUTPUT_DIR})")
    p.add_argument("--name", default=None, help="Filename slug when --output is auto")
    p.add_argument("--ratio", default="tall", choices=list(RATIO_PRESETS.keys()),
                   help="Aspect ratio preset (default: tall)")
    p.add_argument("--width", type=int, default=None, help="Custom width (overrides --ratio)")
    p.add_argument("--height", type=int, default=None, help="Custom height (overrides --ratio)")
    p.add_argument("--steps", type=int, default=30, help="Base inference steps")
    p.add_argument("--cfg", type=float, default=4.5, help="CFG scale")
    p.add_argument("--seed", type=int, default=-1, help="Seed (-1 for random)")
    p.add_argument("--timeout", type=float, default=600.0, help="Base timeout in seconds")
    p.add_argument("--hires", action="store_true", default=True, help="Enable hires fix (default on)")
    p.add_argument("--no-hires", action="store_true", help="Disable hires fix (~15s vs ~45s)")
    p.add_argument("--hires-scale", type=float, default=1.5)
    p.add_argument("--hires-steps", type=int, default=40)
    p.add_argument("--hires-denoise", type=float, default=0.4)
    p.add_argument("--lora", action="append", default=None, help="LoRA filename (repeatable)")
    p.add_argument("--lora-strength", action="append", type=float, default=None,
                   help="LoRA strengths in order (default: 1.0 each)")


# ===========================================================================
# download-ref subcommand
# ===========================================================================
def cmd_download_ref(args):
    """Download an image URL and re-encode to PNG.

    Many image hosts serve WebP regardless of URL extension. Vision models
    (LM Studio, llama.cpp, vllm) reject WebP-as-JPEG with cryptic errors that
    can poison agent sessions. PNG is universally safe.
    """
    try:
        from PIL import Image
    except ImportError:
        fail("Pillow not installed. Run: pip install --user pillow")

    tmp_dir = Path(os.environ.get("TMPDIR") or os.environ.get("TEMP") or "/tmp")
    tmp_dir.mkdir(parents=True, exist_ok=True)

    stamp = int(time.time())
    src = tmp_dir / f"{args.name}-{stamp}.bin"
    dst = tmp_dir / f"{args.name}-{stamp}.png"

    err(f"Downloading {args.url}")
    try:
        req = urllib.request.Request(args.url, headers={"User-Agent": "comfyui-skill/1.0"})
        with urllib.request.urlopen(req, timeout=30) as resp, open(src, "wb") as f:
            data = resp.read()
            if len(data) < 128:
                fail(f"download too small ({len(data)} bytes), likely not an image")
            f.write(data)
    except Exception as e:
        fail(f"download failed: {e}")

    try:
        with Image.open(src) as img:
            img.convert("RGB" if img.mode in ("RGBA", "LA", "P") else img.mode).save(dst, "PNG")
    except Exception as e:
        fail(f"image decode/encode failed: {e}")
    finally:
        src.unlink(missing_ok=True)

    print(str(dst.resolve()))


# ===========================================================================
# Entrypoint
# ===========================================================================
def main():
    parser = argparse.ArgumentParser(prog="comfyui", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_gen = sub.add_parser("generate", help="Queue a ComfyUI workflow and download the result")
    add_generate_args(p_gen)
    p_gen.set_defaults(func=cmd_generate)

    p_dl = sub.add_parser("download-ref", help="Download an image URL and re-encode to PNG")
    p_dl.add_argument("--url", required=True, help="Image URL")
    p_dl.add_argument("--name", default="charref", help="Filename slug (default: charref)")
    p_dl.set_defaults(func=cmd_download_ref)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
