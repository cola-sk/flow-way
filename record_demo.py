#!/usr/bin/env python3
"""
绕川(flow-way) 功能演示录制脚本
===================================
执行方式：
  python3 record_demo.py

脚本会自动：
  1. 启动 flutter run -d chrome（后台进程）
  2. 等待 Flutter web 就绪
  3. 用 Playwright 打开浏览器，按 STEPS 执行操作
  4. 全程录屏（含鼠标点击动效）
  5. 合成带字幕的 MP4 视频

依赖：
  pip3 install playwright pillow --break-system-packages
  playwright install chromium
  brew install ffmpeg

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ACTION 类型说明（无需坐标）
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{"type": "navigate",         "url": "http://..."}
    → 导航到 URL

{"type": "tap",              "label": "去设置"}
    → 点击 aria-label 精确匹配的元素

{"type": "tap",              "label_contains": "设置"}
    → 点击 aria-label 包含关键词的元素

{"type": "tap_if_exists",    "label_contains": "去设置"}
    → 若元素存在则点击，不存在则跳过（不报错）

{"type": "tap_nth",          "label_contains": "结果", "nth": 0}
    → 点击第 nth 个匹配元素（0=第一个），用于下拉列表选第一项

{"type": "type",             "text": "北京体育大学西门"}
    → 键盘输入文字（需先 tap 输入框获得焦点）

{"type": "key",              "key": "Meta+a"}
    → 按键（Meta+a 全选、Enter 确认、Escape 关闭、Backspace 删除）

{"type": "wait",             "ms": 1500}
    → 等待指定毫秒（等页面/动画/网络）

{"type": "reload"}
    → 刷新页面

{"type": "plan_and_save",    "retry_label": "重试"}
    → 点击「开始规划」，等待结果：
        - 若出现成功提示 → 保存路线
        - 若未出现成功提示 → 点击 retry_label 按钮

{"type": "debug_labels"}
    → 打印当前页面所有 aria-label（调试用）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

import asyncio, subprocess, sys, time, urllib.request
from pathlib import Path
from playwright.async_api import async_playwright
from PIL import Image, ImageDraw, ImageFont

# ══════════════════════════════════════════════
# 全局配置
# ══════════════════════════════════════════════

FLUTTER_PORT   = 50227
APP_URL        = f"http://localhost:{FLUTTER_PORT}"
FLUTTER_CMD    = ["flutter", "run", "-d", "chrome", f"--web-port={FLUTTER_PORT}"]
FLUTTER_CWD    = Path(__file__).parent

SCREENSHOT_DIR = Path("demo_screenshots")
VIDEO_RAW_DIR  = Path("demo_video_raw")     # Playwright 录屏输出目录
FRAME_DIR      = Path("demo_frames")
OUTPUT_VIDEO   = "demo_flow_way.mp4"

# Mobile 尺寸（iPhone 14 Pro）
VIEWPORT = {"width": 393, "height": 852}

VIDEO_CONFIG = {
    "fps":       30,
    "crf":       18,    # 画质（越小越好，18 接近无损）
    "font":      "/System/Library/Fonts/PingFang.ttc",
    "font_size": 24,
    "bar_height": 52,
}

# 规划结果等待上限（毫秒），超时后触发重试
PLAN_TIMEOUT_MS = 20_000

# ══════════════════════════════════════════════
# 演示步骤
# ══════════════════════════════════════════════

STEPS = [

    # ─── 初始化：打开 App ────────────────────
    {
        "name":    "00_launch",
        "caption": "启动绕川 App",
        "duration": 3,
        "wait_ms": 4000,
        "actions": [
            {"type": "navigate", "url": APP_URL},
        ],
    },

    # ─── 切换用户标识 ────────────────────────
    # 若出现过期弹窗则点「去设置」，否则直接进设置
    {
        "name":    "01_go_settings",
        "caption": "进入设置页 - 切换用户标识",
        "duration": 2,
        "wait_ms": 2000,
        "actions": [
            {"type": "tap_if_exists", "label": "去设置"},
            # 若弹窗不存在，改用下面这行（取消注释）：
            # {"type": "tap", "label_contains": "设置"},
        ],
    },

    {
        "name":    "02_input_token",
        "caption": "输入用户标识 test_token_v2026",
        "duration": 3,
        "wait_ms": 500,
        "actions": [
            {"type": "tap",  "label_contains": "用户标识"},
            {"type": "key",  "key": "Meta+a"},
            {"type": "type", "text": "test_token_v2026"},
        ],
    },

    {
        "name":    "03_save_token",
        "caption": "保存用户标识 - 验证通过",
        "duration": 3,
        "wait_ms": 3000,
        "actions": [
            {"type": "tap", "label_contains": "保存"},
        ],
    },

    # ─── 进入路线规划页 ──────────────────────
    {
        "name":    "04_open_plan",
        "caption": "进入路线规划页面",
        "duration": 2,
        "wait_ms": 1500,
        "actions": [
            {"type": "tap", "label_contains": "Plan"},
        ],
    },

    # ─── Case 1：北京体育大学西门 → 清河站地铁 ─
    {
        "name":    "05_case1_start_input",
        "caption": "Case 1｜输入起点：北京体育大学西门",
        "duration": 3,
        "wait_ms": 1200,
        "actions": [
            {"type": "tap",  "label_contains": "起点"},
            {"type": "type", "text": "北京体育大学西门"},
            {"type": "wait", "ms": 1200},
        ],
    },

    {
        "name":    "06_case1_start_select",
        "caption": "Case 1｜选择起点第一个结果",
        "duration": 2,
        "wait_ms": 1000,
        "actions": [
            {"type": "tap_nth", "label_contains": "北京体育大学", "nth": 0},
        ],
    },

    {
        "name":    "07_case1_dest_input",
        "caption": "Case 1｜输入终点：清河站地铁",
        "duration": 3,
        "wait_ms": 1200,
        "actions": [
            {"type": "tap",  "label_contains": "终点"},
            {"type": "type", "text": "清河站地铁"},
            {"type": "wait", "ms": 1200},
        ],
    },

    {
        "name":    "08_case1_dest_select",
        "caption": "Case 1｜选择终点第一个结果",
        "duration": 2,
        "wait_ms": 1000,
        "actions": [
            {"type": "tap_nth", "label_contains": "清河", "nth": 0},
        ],
    },

    {
        "name":    "09_case1_plan_result",
        "caption": "Case 1｜规划成功 → 保存路线",
        "duration": 5,
        "wait_ms": 500,
        "actions": [
            # 点击开始规划，等结果，成功则保存，失败则重试
            {"type": "plan_and_save", "retry_label": "重试"},
        ],
    },

    # ─── Case 2：修改终点 → 圆明园遗址公园东门 ─
    {
        "name":    "10_case2_dest_input",
        "caption": "Case 2｜修改终点：圆明园遗址公园东门",
        "duration": 3,
        "wait_ms": 1200,
        "actions": [
            {"type": "tap",  "label_contains": "终点"},
            {"type": "key",  "key": "Meta+a"},
            {"type": "type", "text": "圆明园遗址公园东门"},
            {"type": "wait", "ms": 1200},
        ],
    },

    {
        "name":    "11_case2_dest_select",
        "caption": "Case 2｜选择终点第一个结果",
        "duration": 2,
        "wait_ms": 1000,
        "actions": [
            {"type": "tap_nth", "label_contains": "圆明园", "nth": 0},
        ],
    },

    {
        "name":    "12_case2_plan_result",
        "caption": "Case 2｜规划完成 → 保存路线",
        "duration": 5,
        "wait_ms": 500,
        "actions": [
            {"type": "plan_and_save", "retry_label": "重试"},
        ],
    },

]

# ══════════════════════════════════════════════
# 执行引擎（通常不需要修改）
# ══════════════════════════════════════════════

# ── Flutter 启动 ──────────────────────────────

def wait_for_flutter(port, timeout=90):
    url = f"http://localhost:{port}/"
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            urllib.request.urlopen(url, timeout=2)
            return True
        except Exception:
            time.sleep(2)
    return False


def start_flutter():
    print("▶ 启动 Flutter web...")
    proc = subprocess.Popen(
        FLUTTER_CMD,
        cwd=str(FLUTTER_CWD),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    if not wait_for_flutter(FLUTTER_PORT):
        proc.terminate()
        raise RuntimeError(f"Flutter 启动超时（端口 {FLUTTER_PORT} 未就绪）")
    print(f"✅ Flutter web 就绪: {APP_URL}\n")
    return proc


# ── Flutter Accessibility ─────────────────────

async def enable_flutter_a11y(page):
    placeholder = page.locator("flt-semantics-placeholder")
    if await placeholder.count() > 0:
        try:
            box = await placeholder.first.bounding_box()
            if box:
                await page.mouse.click(box["x"] + 1, box["y"] + 1)
        except Exception:
            pass
        await page.wait_for_timeout(1000)


# ── 鼠标点击动效注入 ──────────────────────────

CLICK_RIPPLE_JS = """
(() => {
    if (window.__ripple_injected) return;
    window.__ripple_injected = true;
    const style = document.createElement('style');
    style.textContent = `
        @keyframes _ripple { to { transform: scale(3); opacity: 0; } }
        ._click_dot {
            position: fixed; width: 28px; height: 28px; border-radius: 50%;
            background: rgba(255, 80, 80, 0.65); pointer-events: none;
            z-index: 2147483647; transform: scale(0);
            animation: _ripple 0.45s ease-out forwards;
            border: 2px solid rgba(255,255,255,0.8);
        }
    `;
    document.head.appendChild(style);
    document.addEventListener('click', e => {
        const el = document.createElement('div');
        el.className = '_click_dot';
        el.style.left = (e.clientX - 14) + 'px';
        el.style.top  = (e.clientY - 14) + 'px';
        document.body.appendChild(el);
        setTimeout(() => el.remove(), 500);
    }, true);
})();
"""


async def inject_click_ripple(page):
    try:
        await page.evaluate(CLICK_RIPPLE_JS)
    except Exception:
        pass


# ── 元素操作 ──────────────────────────────────

async def tap_by_label(page, label=None, label_contains=None, nth=None):
    if label:
        loc = page.locator(f'[aria-label="{label}"]')
        desc = f'aria-label="{label}"'
    else:
        loc = page.locator(f'[aria-label*="{label_contains}"]')
        desc = f'aria-label*="{label_contains}"'

    count = await loc.count()
    if count == 0:
        raise RuntimeError(
            f'找不到元素: {desc}\n'
            f'  → 在 actions 中加 {{"type":"debug_labels"}} 查看当前可用标签'
        )

    target = loc.nth(nth) if nth is not None else loc.first
    box = await target.bounding_box()
    if not box:
        raise RuntimeError(f'元素不可见: {desc} [nth={nth}]')

    cx = box["x"] + box["width"] / 2
    cy = box["y"] + box["height"] / 2
    await page.mouse.click(cx, cy)


async def tap_if_exists(page, label=None, label_contains=None):
    try:
        loc = page.locator(f'[aria-label="{label}"]') if label \
              else page.locator(f'[aria-label*="{label_contains}"]')
        if await loc.count() > 0:
            box = await loc.first.bounding_box()
            if box:
                await page.mouse.click(
                    box["x"] + box["width"] / 2,
                    box["y"] + box["height"] / 2,
                )
    except Exception:
        pass


async def label_exists(page, label_contains):
    return await page.locator(f'[aria-label*="{label_contains}"]').count() > 0


async def plan_and_save(page, retry_label="重试"):
    await tap_by_label(page, label_contains="开始规划")
    deadline = asyncio.get_event_loop().time() + PLAN_TIMEOUT_MS / 1000
    success = False
    while asyncio.get_event_loop().time() < deadline:
        await page.wait_for_timeout(1000)
        if await label_exists(page, "保存"):
            success = True
            break
    if success:
        print("  ✅ 规划成功，保存路线")
        await tap_by_label(page, label_contains="保存")
    else:
        print(f"  ⚠️  未检测到成功提示，点击「{retry_label}」")
        await tap_if_exists(page, label_contains=retry_label)


async def debug_labels(page):
    labels = await page.evaluate("""() =>
        Array.from(document.querySelectorAll('[aria-label]'))
            .map(e => e.getAttribute('aria-label'))
            .filter(l => l && l.trim())
    """)
    print("\n  ── debug_labels ─────────────────────────────")
    for l in labels:
        print(f"    {repr(l)}")
    print("  ─────────────────────────────────────────────\n")


# ── 主录制流程 ────────────────────────────────

async def run_steps():
    SCREENSHOT_DIR.mkdir(exist_ok=True)
    VIDEO_RAW_DIR.mkdir(exist_ok=True)
    FRAME_DIR.mkdir(exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False)
        ctx = await browser.new_context(
            viewport=VIEWPORT,
            record_video_dir=str(VIDEO_RAW_DIR),
            record_video_size=VIEWPORT,
        )
        page = await ctx.new_page()

        page.on("load", lambda _: asyncio.ensure_future(inject_click_ripple(page)))

        a11y_enabled = False

        for i, step in enumerate(STEPS):
            print(f"[{i+1}/{len(STEPS)}] {step['name']}")

            for action in step["actions"]:
                t = action["type"]

                if t == "navigate":
                    await page.goto(action["url"])
                    a11y_enabled = False

                elif t == "reload":
                    await page.reload()
                    a11y_enabled = False

                elif t == "wait":
                    await page.wait_for_timeout(action["ms"])

                elif t == "debug_labels":
                    if not a11y_enabled:
                        await enable_flutter_a11y(page)
                        a11y_enabled = True
                    await debug_labels(page)

                elif t in ("tap", "tap_nth"):
                    if not a11y_enabled:
                        await enable_flutter_a11y(page)
                        a11y_enabled = True
                    await tap_by_label(
                        page,
                        label=action.get("label"),
                        label_contains=action.get("label_contains"),
                        nth=action.get("nth"),
                    )

                elif t == "tap_if_exists":
                    if not a11y_enabled:
                        await enable_flutter_a11y(page)
                        a11y_enabled = True
                    await tap_if_exists(
                        page,
                        label=action.get("label"),
                        label_contains=action.get("label_contains"),
                    )

                elif t == "plan_and_save":
                    if not a11y_enabled:
                        await enable_flutter_a11y(page)
                        a11y_enabled = True
                    await plan_and_save(page, retry_label=action.get("retry_label", "重试"))

                elif t == "type":
                    await page.keyboard.type(action["text"])

                elif t == "key":
                    await page.keyboard.press(action["key"])

            await page.wait_for_timeout(step.get("wait_ms", 1000))

            shot = SCREENSHOT_DIR / f"{step['name']}.png"
            await page.screenshot(path=str(shot), full_page=False)
            print(f"  📸 {shot}")

        await page.wait_for_timeout(500)
        await ctx.close()
        await browser.close()

    webm_files = sorted(VIDEO_RAW_DIR.glob("*.webm"), key=lambda f: f.stat().st_mtime)
    return webm_files[-1] if webm_files else None


# ── 字幕合成 ─────────────────────────────────

def annotate_and_make_video(raw_webm):
    cfg   = VIDEO_CONFIG
    W, H  = VIEWPORT["width"], VIEWPORT["height"]
    BAR_H = cfg["bar_height"]

    try:
        font = ImageFont.truetype(cfg["font"], cfg["font_size"])
    except Exception:
        font = ImageFont.load_default()

    concat_lines = []
    for i, step in enumerate(STEPS):
        src = SCREENSHOT_DIR / f"{step['name']}.png"
        if not src.exists():
            print(f"  ⚠️  截图缺失，跳过: {src}")
            continue

        img = Image.open(src).convert("RGB").resize((W, H - BAR_H), Image.LANCZOS)
        canvas = Image.new("RGB", (W, H), (15, 15, 15))
        canvas.paste(img, (0, 0))

        draw = ImageDraw.Draw(canvas)
        draw.rectangle([(0, H - BAR_H), (W, H)], fill=(10, 10, 10))

        text = step["caption"]
        bbox = draw.textbbox((0, 0), text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        tx = max((W - tw) // 2, 8)
        ty = H - BAR_H + (BAR_H - th) // 2 - 2

        for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
            draw.text((tx + dx, ty + dy), text, font=font, fill=(0, 0, 0))
        draw.text((tx, ty), text, font=font, fill=(255, 215, 50))

        frame_path = FRAME_DIR / f"frame_{i:04d}.png"
        canvas.save(str(frame_path))
        concat_lines += [f"file '{frame_path.resolve()}'", f"duration {step['duration']}"]

    concat_lines += [concat_lines[-2], "duration 0.1"]
    list_file = Path("demo_concat_list.txt")
    list_file.write_text("\n".join(concat_lines))

    if raw_webm and raw_webm.exists():
        print(f"\n📹 使用实际录屏: {raw_webm}")
        cmd = [
            "ffmpeg", "-y", "-i", str(raw_webm),
            "-c:v", "libx264", "-pix_fmt", "yuv420p",
            "-crf", str(cfg["crf"]),
            OUTPUT_VIDEO,
        ]
    else:
        print("\n📹 回退：截图幻灯片合成")
        cmd = [
            "ffmpeg", "-y",
            "-f", "concat", "-safe", "0", "-i", str(list_file),
            "-r", str(cfg["fps"]),
            "-c:v", "libx264", "-pix_fmt", "yuv420p",
            "-crf", str(cfg["crf"]),
            OUTPUT_VIDEO,
        ]

    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        size_kb = Path(OUTPUT_VIDEO).stat().st_size // 1024
        print(f"✅ 视频完成: {OUTPUT_VIDEO} ({size_kb} KB)")
    else:
        print("❌ ffmpeg 失败:\n" + result.stderr[-2000:])


# ── 入口 ─────────────────────────────────────

if __name__ == "__main__":
    flutter_proc = None
    try:
        flutter_proc = start_flutter()
        raw_webm = asyncio.run(run_steps())
        print("\n=== 合成视频 ===\n")
        annotate_and_make_video(raw_webm)
    finally:
        if flutter_proc:
            flutter_proc.terminate()
            print("Flutter 进程已终止")
    print("\n=== 完成 ===")
