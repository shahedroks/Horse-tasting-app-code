package com.example.test_project_glue_u

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Native (Kotlin) object detection for the largest rectangular object in an image.
 * Same pipeline as Dart: grayscale → blur → Sobel edges → mask (edges + dark) →
 * dilate → connected components → filter by area, aspect, fill, center → refine → return bounds.
 * Used via MethodChannel from Flutter on Android for better performance / consistency.
 */
object NativeObjectDetector {

    private const val MAX_SIZE = 500
    private const val EDGE_THRESHOLD = 40
    private const val DARK_THRESHOLD = 170
    private const val MIN_COMPONENT_AREA_FULL = 5000
    private const val MIN_BOX_SIDE = 10
    private const val ASPECT_MIN = 0.4
    private const val ASPECT_MAX = 3.0
    private const val FILL_RATIO_MIN = 0.3
    private const val AREA_RATIO_MAX = 0.8
    private const val CENTER_MARGIN = 0.6

    data class Bounds(
        val centerX: Double,
        val centerY: Double,
        val halfWidth: Double,
        val halfHeight: Double
    )

    fun detect(imageBytes: ByteArray): Bounds? {
        val options = BitmapFactory.Options().apply { inPreferredConfig = Bitmap.Config.ARGB_8888 }
        val original = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, options)
            ?: return null
        val ow = original.width
        val oh = original.height
        if (ow < 20 || oh < 20) return null

        val scale = if (ow > MAX_SIZE || oh > MAX_SIZE) {
            MAX_SIZE.toDouble() / maxOf(ow, oh)
        } else 1.0

        val sw = (ow * scale).toInt().coerceAtLeast(20)
        val sh = (oh * scale).toInt().coerceAtLeast(20)
        val small = if (scale < 1) Bitmap.createScaledBitmap(original, sw, sh, true) else original
        if (scale < 1) original.recycle()

        // Grayscale
        val gray = IntArray(sw * sh)
        for (y in 0 until sh) {
            for (x in 0 until sw) {
                val p = small.getPixel(x, y)
                gray[y * sw + x] = (Color.red(p) + Color.green(p) + Color.blue(p)) / 3
            }
        }

        // Blur copy for edges (5x5 Gaussian approx with radius 2)
        val grayBlur = gray.clone()
        gaussianBlur(grayBlur, sw, sh, 2)

        // Sobel magnitude
        val sobel = FloatArray(sw * sh)
        sobelMagnitude(grayBlur, sobel, sw, sh)

        // Mask: edge OR dark (scale sobel magnitude into ~0-255 for threshold)
        val mask = IntArray(sw * sh)
        for (i in gray.indices) {
            val edge = (sobel[i] / 4f).toInt().coerceIn(0, 255)
            val lum = gray[i]
            if (edge > EDGE_THRESHOLD || lum < DARK_THRESHOLD) mask[i] = 1
        }

        // Dilate once
        val dilated = mask.clone()
        for (y in 1 until sh - 1) {
            for (x in 1 until sw - 1) {
                val idx = y * sw + x
                if (mask[idx] == 1) continue
                var any = false
                for (dy in -1..1) for (dx in -1..1) {
                    if (mask[(y + dy) * sw + (x + dx)] == 1) { any = true; break }
                }
                if (any) dilated[idx] = 1
            }
        }

        val areaScale = (ow * oh).toDouble() / (sw * sh)
        val minArea = (MIN_COMPONENT_AREA_FULL / areaScale).toInt()
        val imgCx = sw / 2.0
        val imgCy = sh / 2.0
        val imgArea = (sw * sh).toDouble()

        var bestArea = 0
        var bestMinX = 0
        var bestMinY = 0
        var bestMaxX = 0
        var bestMaxY = 0
        val visited = IntArray(sw * sh)

        for (y in 0 until sh) {
            for (x in 0 until sw) {
                val start = y * sw + x
                if (dilated[start] == 0 || visited[start] == 1) continue
                val stack = ArrayDeque<Int>()
                stack.addLast(start)
                visited[start] = 1
                var minX = x
                var maxX = x
                var minY = y
                var maxY = y
                var count = 0

                while (stack.isNotEmpty()) {
                    val idx = stack.removeLast()
                    val cx = idx % sw
                    val cy = idx / sw
                    count++
                    if (cx < minX) minX = cx
                    if (cx > maxX) maxX = cx
                    if (cy < minY) minY = cy
                    if (cy > maxY) maxY = cy
                    for (dy in -1..1) for (dx in -1..1) {
                        if (dx == 0 && dy == 0) continue
                        val nx = cx + dx
                        val ny = cy + dy
                        if (nx in 0 until sw && ny in 0 until sh) {
                            val nIdx = ny * sw + nx
                            if (dilated[nIdx] == 1 && visited[nIdx] == 0) {
                                visited[nIdx] = 1
                                stack.addLast(nIdx)
                            }
                        }
                    }
                }

                if (count < minArea) continue
                val boxW = maxX - minX + 1
                val boxH = maxY - minY + 1
                if (boxW < MIN_BOX_SIDE || boxH < MIN_BOX_SIDE) continue
                if (minX == 0 || minY == 0 || maxX == sw - 1 || maxY == sh - 1) continue
                val aspect = boxW.toDouble() / boxH
                if (aspect < ASPECT_MIN || aspect > ASPECT_MAX) continue
                val boxArea = (boxW * boxH).toDouble()
                if (count / boxArea < FILL_RATIO_MIN) continue
                if (boxArea / imgArea > AREA_RATIO_MAX) continue
                val compCx = (minX + maxX) / 2.0
                val compCy = (minY + maxY) / 2.0
                val dxNorm = abs(compCx - imgCx) / imgCx
                val dyNorm = abs(compCy - imgCy) / imgCy
                if (dxNorm > CENTER_MARGIN && dyNorm > CENTER_MARGIN) continue
                if (count > bestArea) {
                    bestArea = count
                    bestMinX = minX
                    bestMinY = minY
                    bestMaxX = maxX
                    bestMaxY = maxY
                }
            }
        }

        if (bestArea <= 0) return null

        // Refine with original mask inside best box
        var refMinX = bestMaxX
        var refMaxX = bestMinX
        var refMinY = bestMaxY
        var refMaxY = bestMinY
        var refCount = 0
        for (y in bestMinY..bestMaxY) {
            for (x in bestMinX..bestMaxX) {
                val idx = y * sw + x
                if (mask[idx] == 1) {
                    refCount++
                    if (x < refMinX) refMinX = x
                    if (x > refMaxX) refMaxX = x
                    if (y < refMinY) refMinY = y
                    if (y > refMaxY) refMaxY = y
                }
            }
        }
        if (refCount < minArea / 2) {
            refMinX = bestMinX
            refMaxX = bestMaxX
            refMinY = bestMinY
            refMaxY = bestMaxY
        }

        val invScale = 1.0 / scale
        val rectMinX = refMinX * invScale
        val rectMaxX = refMaxX * invScale
        val rectMinY = refMinY * invScale
        val rectMaxY = refMaxY * invScale
        val width = rectMaxX - rectMinX + 1
        val height = rectMaxY - rectMinY + 1
        if (width < MIN_BOX_SIDE || height < MIN_BOX_SIDE) return null

        return Bounds(
            centerX = rectMinX + width / 2,
            centerY = rectMinY + height / 2,
            halfWidth = width / 2,
            halfHeight = height / 2
        )
    }

    private fun gaussianBlur(data: IntArray, w: Int, h: Int, radius: Int) {
        val kernelSize = radius * 2 + 1
        val kernel = FloatArray(kernelSize)
        val sigma = radius / 2f
        var sum = 0f
        for (i in 0 until kernelSize) {
            val x = i - radius
            kernel[i] = kotlin.math.exp(-(x * x) / (2 * sigma * sigma))
            sum += kernel[i]
        }
        for (i in 0 until kernelSize) kernel[i] /= sum

        val tmp = IntArray(data.size)
        for (y in 0 until h) {
            for (x in 0 until w) {
                var v = 0f
                for (k in -radius..radius) {
                    val xx = (x + k).coerceIn(0, w - 1)
                    v += data[y * w + xx] * kernel[k + radius]
                }
                tmp[y * w + x] = v.toInt().coerceIn(0, 255)
            }
        }
        for (y in 0 until h) {
            for (x in 0 until w) {
                var v = 0f
                for (k in -radius..radius) {
                    val yy = (y + k).coerceIn(0, h - 1)
                    v += tmp[yy * w + x] * kernel[k + radius]
                }
                data[y * w + x] = v.toInt().coerceIn(0, 255)
            }
        }
    }

    private fun sobelMagnitude(gray: IntArray, out: FloatArray, w: Int, h: Int) {
        val gx = intArrayOf(-1, 0, 1, -2, 0, 2, -1, 0, 1)
        val gy = intArrayOf(-1, -2, -1, 0, 0, 0, 1, 2, 1)
        for (y in 1 until h - 1) {
            for (x in 1 until w - 1) {
                var sx = 0
                var sy = 0
                var ki = 0
                for (dy in -1..1) for (dx in -1..1) {
                    val v = gray[(y + dy) * w + (x + dx)]
                    sx += v * gx[ki]
                    sy += v * gy[ki]
                    ki++
                }
                out[y * w + x] = sqrt((sx * sx + sy * sy).toDouble()).toFloat()
            }
        }
    }
}
