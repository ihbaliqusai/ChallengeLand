#!/usr/bin/env python3
"""
Reusable idle-loop animator for cartoon avatars: subtle breathing + natural blinking.
The animation logic is generic. Only a few LANDMARKS differ per avatar -> set them in CONFIG.

WORKFLOW
  1) Fill CONFIG below for your avatar (or loop over many avatars, see bottom).
  2) python3 avatar_animator.py calibrate   # saves <name>_calibration.png to VERIFY landmarks
  3) python3 avatar_animator.py render      # saves <name>_idle.mp4 (+ .webm with --webm)

If your avatars share the SAME template (same podium / pose / canvas size), the same
landmarks usually work for all of them with little or no change.
"""
import numpy as np, cv2, os, sys, time
from PIL import Image
from scipy.ndimage import gaussian_filter1d

# ============================== CONFIG (edit per avatar) ==============================
CONFIG = {
    "image":  "/mnt/user-data/uploads/contestant_green.png",
    "outdir": "/mnt/user-data/outputs",
    "name":   "contestant",          # output file prefix

    # --- REQUIRED landmarks (pixel coordinates in the source image) ---
    "left_eye":   (410, 419, 478, 494),   # [x0, y0, x1, y1]  (image-left eye)
    "right_eye":  (584, 417, 654, 492),   # [x0, y0, x1, y1]  (image-right eye)
    "static_below_y": 1255,               # everything at/below this Y is FROZEN

    # --- OPTIONAL (None => auto-derived from image size) ---
    "center_x":  545,     # torso center x        (default: width / 2)
    "chest_y":   970,     # breathing band center  (default: ~0.78 * static_below_y)

    # --- motion + timing (usually identical across avatars) ---
    "fps":            30,
    "breath_period":  4.0,    # seconds per breath (~15 / min)
    "n_cycles":       3,      # loop length = n_cycles * breath_period (=> seamless)
    "amp_vertical":   10.0,   # px the shoulders rise on inhale
    "amp_horizontal": 3.0,    # px the chest widens on inhale
    "head_floor":     0.16,   # how much the head rides the breath (0..1, keep small)

    # blink start-times in seconds. Must be inside the loop and away from the 0/seam.
    # Tip: ~1 blink every 2.5-4 s; include one quick double-blink for naturalness.
    "blinks": [1.70, 4.55, 7.30, 7.66, 10.45],

    # encoding quality
    "crf": 16,                # H.264 quality (lower = better, 16-18 is high quality)
}
# ======================================================================================


def smoothstep(t):
    t = np.clip(t, 0.0, 1.0)
    return t * t * (3 - 2 * t)


class AvatarAnimator:
    def __init__(self, cfg):
        self.cfg = cfg
        self.base = np.array(Image.open(cfg["image"]).convert("RGB")).astype(np.float32)
        self.H, self.W, _ = self.base.shape
        self.A   = int(cfg["static_below_y"])
        self.cx  = int(cfg["center_x"]) if cfg.get("center_x") else self.W // 2
        self.cy  = int(cfg["chest_y"])  if cfg.get("chest_y")  else int(round(0.78 * self.A))
        self.left_eye  = tuple(cfg["left_eye"])
        self.right_eye = tuple(cfg["right_eye"])
        self._build_fields()
        self._build_blink_patches()
        self._check_loop()

    # ---------- breathing displacement fields (peak at chest, minimal head) ----------
    def _build_fields(self):
        H, W, A, cy = self.H, self.W, self.A, self.cy
        hf = float(self.cfg["head_floor"])
        yy = np.arange(H, dtype=np.float32)

        plateau = max(28, int(round(0.043 * A)))     # half-height of the peak plateau
        ramp    = max(90, int(round(0.105 * A)))      # ramp length below the head floor
        c1, c2  = cy - plateau, cy + plateau          # peak plateau band
        c0      = max(0, c1 - ramp)                    # where it leaves the head floor
        pts = [(0, hf), (max(0, c0 - 80), hf), (c0, hf + (1 - hf) * 0.25),
               (c1, 1.0), (c2, 1.0), (A, 0.0), (H - 1, 0.0)]
        px = np.array([p[0] for p in pts]); pv = np.array([p[1] for p in pts])
        prof = np.interp(yy, px, pv).astype(np.float32)
        prof = gaussian_filter1d(prof, 22)
        prof[yy >= A] = 0.0                            # guarantee frozen below anchor
        self.prof_col = prof[:, None]

        # horizontal chest expansion
        h_sigma = max(90, int(round(0.095 * A)))
        env = np.exp(-((yy - (cy + 30)) ** 2) / (2 * h_sigma ** 2))
        gate = smoothstep((yy - (cy - 50)) / 55.0) * (1 - smoothstep((yy - (A - 75)) / 55.0))
        env = (env * gate).astype(np.float32)
        env[yy >= A] = 0.0
        self.env_col = env[:, None]

        xx = np.arange(W, dtype=np.float32)[None, :]
        self.horiz_shape = np.clip((xx - self.cx) / (0.216 * W), -1.4, 1.4)
        self.base_x = np.tile(xx, (H, 1))
        self.base_y = np.tile(yy[:, None], (1, W))

    def _warp(self, img, breath):
        Av = float(self.cfg["amp_vertical"]); Ah = float(self.cfg["amp_horizontal"])
        map_y = self.base_y + (Av * breath) * self.prof_col
        map_x = self.base_x - (Ah * breath) * self.env_col * self.horiz_shape
        return cv2.remap(img, map_x.astype(np.float32), map_y.astype(np.float32),
                         cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=(0, 0, 0))

    # ---------- blink: clean feathered skin patch per eye (auto-matches skin tone) ----------
    def _skin_tone(self, eye):
        x0, y0, x1, y1 = eye
        b = self.base
        strips = [b[y0-28:y0-14, x0+6:x1-6], b[y1+5:y1+22, x0+6:x1-6],
                  b[y0+8:y1-8, x0-14:x0-4], b[y0+8:y1-8, x1+4:x1+14]]
        px = np.concatenate([s.reshape(-1, 3) for s in strips if s.size], 0)
        px = px[px.mean(1) > 150]
        return np.median(px, 0) if len(px) else np.array([245., 184., 116.])

    def _make_patch(self, eye, padx=14, padt=16, padb=10):
        x0, y0, x1, y1 = eye
        X0, Y0, X1, Y1 = x0-padx, y0-padt, x1+padx, y1+padb
        region = self.base[Y0:Y1, X0:X1].astype(np.float32).copy()
        h, w, _ = region.shape
        sub = self.base[Y0:Y1, X0:X1]
        br = sub.mean(2); mn = sub.min(2); mx = sub.max(2)
        mask = ((br < 120) | ((mn > 175) & ((mx - mn) < 45))).astype(np.uint8)
        mask = cv2.dilate(mask, np.ones((5, 5), np.uint8), 1)
        maskf = np.clip(cv2.GaussianBlur(mask.astype(np.float32), (0, 0), 4.2), 0, 1)[:, :, None]
        S = self._skin_tone(eye)
        top = S * np.array([1.0, 1.005, 1.01]); bot = S * np.array([1.005, 0.99, 0.97])
        g = np.linspace(0, 1, h, dtype=np.float32)[:, None]
        skin = np.repeat((top[None, :] * (1 - g) + bot[None, :] * g)[:, None, :], w, axis=1)
        yy_ = np.linspace(-1, 1, h, dtype=np.float32)[:, None]
        skin *= (1.0 - 0.035 * np.clip(-yy_, 0, 1))[:, :, None]
        patch = maskf * skin + (1 - maskf) * region
        return (X0, Y0, X1, Y1), cv2.GaussianBlur(patch, (0, 0), 1.0)

    def _build_blink_patches(self):
        self.patchL = self._make_patch(self.left_eye)
        self.patchR = self._make_patch(self.right_eye)

    def _apply_blink(self, img, c):
        if c <= 0.001:
            return img
        out = img.copy()
        for eye, (box, patch) in ((self.left_eye, self.patchL), (self.right_eye, self.patchR)):
            ex0, ey0, ex1, ey1 = eye
            X0, Y0, X1, Y1 = box
            T = ey0 - 3; Bmax = ey1 + 3; span = Bmax - T
            cb = T + c * span
            region = out[Y0:Y1, X0:X1].astype(np.float32)
            rows = np.arange(Y0, Y1)[:, None].astype(np.float32)
            alpha = np.clip((cb - rows) / 2.6 + 0.5, 0.0, 1.0)
            col = np.arange(X0, X1)[None, :].astype(np.float32)
            xin = np.clip((col - (ex0 - 2)) / 2.0, 0, 1) * np.clip(((ex1 + 2) - col) / 2.0, 0, 1)
            a = (alpha * xin)[:, :, None]
            dte = np.clip(cb - rows, 0, None)
            shadow = 1.0 - 0.08 * np.exp(-(dte / 4.5) ** 2)
            blended = a * (patch * shadow[:, :, None]) + (1 - a) * region
            la = smoothstep((c - 0.6) / 0.32)
            if la > 0.01:
                cxe = (ex0 + ex1) / 2.0; rw = ex1 - ex0
                cols = np.arange(X0, X1)
                arc = (T + 0.58 * span) + 5.0 * ((cols - cxe) / (rw / 2.0)) ** 2 - 1.0
                yidx = np.arange(Y0, Y1)[:, None]
                wl = np.clip(1 - np.abs(yidx - arc[None, :]) / 2.2, 0, 1) * la
                wl = wl * ((cols >= ex0 - 1) & (cols <= ex1 + 1))[None, :]
                wl = wl[:, :, None]
                blended = (1 - wl) * blended + wl * np.array([95., 60., 42.])
            out[Y0:Y1, X0:X1] = np.clip(blended, 0, 255)
        return out

    # ---------- timing ----------
    def duration(self):
        return self.cfg["breath_period"] * self.cfg["n_cycles"]

    def n_frames(self):
        return int(round(self.duration() * self.cfg["fps"]))

    def _blink_closure(self, t):
        CLOSE, HOLD, OPEN = 0.10, 0.04, 0.17
        dur = CLOSE + HOLD + OPEN
        c = 0.0
        for e in self.cfg["blinks"]:
            dt = t - e
            if dt < 0.0 or dt > dur:
                continue
            if dt < CLOSE:
                cc = smoothstep(dt / CLOSE)
            elif dt < CLOSE + HOLD:
                cc = 1.0
            else:
                cc = 1.0 - smoothstep((dt - CLOSE - HOLD) / OPEN)
            c = max(c, cc)
        return float(c)

    def _check_loop(self):
        dur = self.duration(); blink_dur = 0.31
        for b in self.cfg["blinks"]:
            if not (0.35 < b and b + blink_dur < dur - 0.05):
                raise ValueError(f"blink at {b}s is too close to the loop seam (loop = {dur}s)")

    # ---------- one frame ----------
    def frame_at(self, i):
        t = i / self.cfg["fps"]
        breath = 0.5 - 0.5 * np.cos(2 * np.pi * t / self.cfg["breath_period"])
        img = self._apply_blink(self.base, self._blink_closure(t))
        img = self._warp(img, breath)
        return np.clip(img, 0, 255).astype(np.uint8)

    # ---------- calibration overlay (VERIFY landmarks before rendering) ----------
    def calibrate(self):
        img = self.base.astype(np.uint8).copy()
        def line_h(y, color, th=4): cv2.line(img, (0, y), (self.W, y), color, th)
        def line_v(x, color, th=4): cv2.line(img, (x, 0), (x, self.H), color, th)
        for eye in (self.left_eye, self.right_eye):
            x0, y0, x1, y1 = eye
            cv2.rectangle(img, (x0, y0), (x1, y1), (0, 230, 0), 3)
        line_h(self.A, (230, 40, 40))                     # red  = freeze line
        line_v(self.cx, (60, 120, 255))                   # blue = torso center
        plateau = max(28, int(round(0.043 * self.A)))
        line_h(self.cy - plateau, (240, 200, 30), 2)      # yellow = breathing band
        line_h(self.cy + plateau, (240, 200, 30), 2)
        cv2.putText(img, "freeze line (everything below = static)", (12, self.A - 12),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.1, (230, 40, 40), 3)
        cv2.putText(img, "breathing band", (12, self.cy - plateau - 12),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.9, (240, 200, 30), 2)
        out = os.path.join(self.cfg["outdir"], f"{self.cfg['name']}_calibration.png")
        scale = min(1.0, 900 / self.H)
        if scale < 1.0:
            img = cv2.resize(img, (int(self.W * scale), int(self.H * scale)), interpolation=cv2.INTER_AREA)
        Image.fromarray(img).save(out)
        print("calibration ->", out)
        return out

    # ---------- render the seamless loop ----------
    def render(self, make_webm=False):
        import imageio
        os.makedirs(self.cfg["outdir"], exist_ok=True)
        mp4 = os.path.join(self.cfg["outdir"], f"{self.cfg['name']}_idle.mp4")
        N = self.n_frames(); t0 = time.time()
        w = imageio.get_writer(mp4, fps=self.cfg["fps"], codec="libx264", macro_block_size=1,
                               ffmpeg_params=["-crf", str(self.cfg["crf"]), "-pix_fmt", "yuv420p",
                                              "-preset", "slow", "-movflags", "+faststart"])
        first = last = None
        for i in range(N):
            fr = self.frame_at(i)
            if i == 0: first = fr
            if i == N - 1: last = fr
            w.append_data(fr)
            if i % 60 == 0:
                print(f"  frame {i}/{N}  ({time.time()-t0:.1f}s)", flush=True)
        w.close()
        d = np.abs(first.astype(np.int32) - last.astype(np.int32)).sum(2)
        print(f"rendered {mp4} in {time.time()-t0:.1f}s")
        print(f"  loop-seam diff mean={d.mean():.3f} max={d.max()} | below-freeze max={d[self.A:].max()} (must be 0)")
        if make_webm:
            webm = mp4[:-4] + ".webm"
            os.system(f'ffmpeg -v error -y -i "{mp4}" -c:v libvpx-vp9 -crf 30 -b:v 0 '
                      f'-row-mt 1 -threads 8 -speed 2 -pix_fmt yuv420p -an "{webm}"')
            print("webm ->", webm)
        return mp4


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "render"
    anim = AvatarAnimator(CONFIG)
    if cmd == "calibrate":
        anim.calibrate()
    else:
        anim.render(make_webm=("--webm" in sys.argv))

# ------------------------------------------------------------------------------------
# BATCH over many avatars: copy CONFIG, change image/name/landmarks, then:
#
#   AVATARS = [
#       {**CONFIG, "image": ".../contestant_green.png", "name": "green",
#        "left_eye": (410,419,478,494), "right_eye": (584,417,654,492), "static_below_y": 1255},
#       {**CONFIG, "image": ".../contestant_blue.png",  "name": "blue",
#        "left_eye": (...), "right_eye": (...), "static_below_y": ...},
#   ]
#   for c in AVATARS:
#       a = AvatarAnimator(c); a.calibrate(); a.render(make_webm=True)
# ------------------------------------------------------------------------------------
