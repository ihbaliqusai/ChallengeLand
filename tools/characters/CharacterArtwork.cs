using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

// Remove only black pixels connected to the backdrop, preserving dark details
// inside the character. Video playback uses the existing ChromaVideoView shader.
public static class CharacterArtwork {
    public static void Prepare(string source, string bodyPath, string facePath) {
        using (var original = new Bitmap(source))
        using (var image = new Bitmap(original.Width, original.Height, PixelFormat.Format32bppArgb)) {
            using (var graphics = Graphics.FromImage(image)) graphics.DrawImageUnscaled(original, 0, 0);
            int width = image.Width, height = image.Height;
            var rect = new Rectangle(0, 0, width, height);
            var pixels = image.LockBits(rect, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
            var bytes = new byte[pixels.Stride * height];
            Marshal.Copy(pixels.Scan0, bytes, 0, bytes.Length);
            var outside = new bool[width * height];
            var queue = new Queue<int>();
            Action<int, int> visit = (x, y) => {
                if (x < 0 || x >= width || y < 0 || y >= height) return;
                int index = y * width + x;
                if (outside[index]) return;
                int offset = y * pixels.Stride + x * 4;
                if (Math.Max(bytes[offset], Math.Max(bytes[offset + 1], bytes[offset + 2])) > 24) return;
                outside[index] = true;
                queue.Enqueue(index);
            };
            for (int x = 0; x < width; x++) { visit(x, 0); visit(x, height - 1); }
            for (int y = 0; y < height; y++) { visit(0, y); visit(width - 1, y); }
            while (queue.Count > 0) {
                int index = queue.Dequeue(), x = index % width, y = index / width;
                visit(x - 1, y); visit(x + 1, y); visit(x, y - 1); visit(x, y + 1);
            }
            int left = width, right = 0, top = height, bottom = 0;
            for (int y = 0; y < height; y++) for (int x = 0; x < width; x++) {
                int offset = y * pixels.Stride + x * 4;
                if (outside[y * width + x]) {
                    bytes[offset] = bytes[offset + 1] = bytes[offset + 2] = bytes[offset + 3] = 0;
                } else {
                    left = Math.Min(left, x); right = Math.Max(right, x);
                    top = Math.Min(top, y); bottom = Math.Max(bottom, y);
                }
            }
            Marshal.Copy(bytes, 0, pixels.Scan0, bytes.Length);
            image.UnlockBits(pixels);
            if (right <= left || bottom <= top) throw new Exception("Empty character frame: " + source);
            int padding = 8;
            var body = Rectangle.FromLTRB(Math.Max(0, left - padding), Math.Max(0, top - padding),
                Math.Min(width, right + padding + 1), Math.Min(height, bottom + padding + 1));
            SaveCrop(image, body, bodyPath, 960);
            int headLeft = width, headRight = 0;
            int headBottom = top + (int)((bottom - top) * .16);
            for (int y = top; y <= headBottom; y++) for (int x = left; x <= right; x++) {
                if (bytes[y * pixels.Stride + x * 4 + 3] == 0) continue;
                headLeft = Math.Min(headLeft, x); headRight = Math.Max(headRight, x);
            }
            int faceSide = (int)((bottom - top) * .28);
            var face = Rectangle.Intersect(rect, new Rectangle(
                (headLeft + headRight - faceSide) / 2, Math.Max(0, top - 6), faceSide, faceSide));
            SaveCrop(image, face, facePath, 256);
        }
    }

    private static void SaveCrop(Bitmap image, Rectangle region, string path, int maxSize) {
        double ratio = Math.Min(1.0, (double)maxSize / Math.Max(region.Width, region.Height));
        using (var result = new Bitmap(Math.Max(1, (int)(region.Width * ratio)),
                Math.Max(1, (int)(region.Height * ratio)), PixelFormat.Format32bppArgb)) {
            using (var graphics = Graphics.FromImage(result)) {
                graphics.InterpolationMode = InterpolationMode.HighQualityBicubic;
                graphics.CompositingMode = CompositingMode.SourceCopy;
                graphics.PixelOffsetMode = PixelOffsetMode.HighQuality;
                graphics.DrawImage(image, new Rectangle(0, 0, result.Width, result.Height), region, GraphicsUnit.Pixel);
            }
            result.Save(path, ImageFormat.Png);
        }
    }
}
