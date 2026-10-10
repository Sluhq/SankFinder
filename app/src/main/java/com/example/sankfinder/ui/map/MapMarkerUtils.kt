package com.example.sankfinder.ui.map

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable

object MapMarkerUtils {

    /**
     * Hitri, zanesljivi CartoDB Voyager zemljevidi (brez 403 blokad in v stilu Google Maps)
     */
    val CARTO_VOYAGER = org.osmdroid.tileprovider.tilesource.XYTileSource(
        "CartoVoyager",
        0, 19, 256, ".png",
        arrayOf(
            "https://a.basemaps.cartocdn.com/rastertiles/voyager/",
            "https://b.basemaps.cartocdn.com/rastertiles/voyager/",
            "https://c.basemaps.cartocdn.com/rastertiles/voyager/",
            "https://d.basemaps.cartocdn.com/rastertiles/voyager/"
        ),
        "© OpenStreetMap contributors, © CARTO"
    )

    /**
     * Ustvari zelen označevalec za lokal (zelena pikica v slogu Google Maps).
     */
    fun createPubMarkerDrawable(context: Context, isSelected: Boolean = false): Drawable {
        val density = context.resources.displayMetrics.density
        val sizeDp = if (isSelected) 36f else 28f
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(32)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cx = sizePx / 2f
        val cy = sizePx / 2f
        val radius = (sizePx / 2f) - (3f * density)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Zunanja senca
        paint.color = Color.parseColor("#33000000")
        canvas.drawCircle(cx, cy + (1.5f * density), radius, paint)

        // Glavni zeleni krog
        paint.color = if (isSelected) Color.parseColor("#2E7D32") else Color.parseColor("#43A047")
        canvas.drawCircle(cx, cy, radius, paint)

        // Beli zunanji obroč
        paint.color = Color.WHITE
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2.5f * density
        canvas.drawCircle(cx, cy, radius - (1.25f * density), paint)

        // Notranja pika
        paint.style = Paint.Style.FILL
        paint.color = if (isSelected) Color.parseColor("#FFD54F") else Color.WHITE
        canvas.drawCircle(cx, cy, 3.5f * density, paint)

        return BitmapDrawable(context.resources, bitmap)
    }

    /**
     * Ustvari zlati označevalec za prijatelja iz Pivske Klape z začetnico imena.
     */
    fun createSquadFriendMarkerDrawable(context: Context, name: String, drinksCount: Int = 0): Drawable {
        val density = context.resources.displayMetrics.density
        val sizeDp = 36f
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(36)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cx = sizePx / 2f
        val cy = sizePx / 2f
        val radius = (sizePx / 2f) - (3f * density)

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // Senca
        paint.color = Color.parseColor("#44000000")
        canvas.drawCircle(cx, cy + (1.5f * density), radius, paint)

        // Zlati krog za pivo / prijatelja
        paint.color = Color.parseColor("#F59E0B")
        canvas.drawCircle(cx, cy, radius, paint)

        // Beli zunanji obroč
        paint.color = Color.WHITE
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2.5f * density
        canvas.drawCircle(cx, cy, radius - (1.25f * density), paint)

        // Začetnica
        paint.style = Paint.Style.FILL
        paint.color = Color.BLACK
        paint.textSize = 15f * density
        paint.textAlign = Paint.Align.CENTER
        paint.isFakeBoldText = true

        val initial = if (name.isNotBlank()) name.take(1).uppercase() else "P"
        val yPos = cy - ((paint.descent() + paint.ascent()) / 2)
        canvas.drawText(initial, cx, yPos, paint)

        return BitmapDrawable(context.resources, bitmap)
    }

    /**
     * Ustvari čisto, ostro modro pikico s smerno puščico v Google Maps slogu brez kakršnihkoli kvadratnih ali modrih ozadij.
     */
    fun createUserMarkerDrawable(context: Context): Drawable {
        val density = context.resources.displayMetrics.density
        val sizeDp = 44f
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(48)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cx = sizePx / 2f
        val cy = sizePx / 2f

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // 1. Nežna zunanja senca pod krogcem (za globino na zemljevidu)
        paint.style = Paint.Style.FILL
        paint.color = Color.parseColor("#33000000") // 20% črna senca
        canvas.drawCircle(cx, cy + (1.5f * density), 11f * density, paint)

        // 2. Smerni trikotnik / puščica smeri (orientacija proti vrhu)
        val path = Path()
        paint.color = Color.parseColor("#1A73E8") // Prepoznavna Google Maps modra
        path.moveTo(cx, cy - (17f * density))
        path.lineTo(cx - (5.5f * density), cy - (8f * density))
        path.lineTo(cx + (5.5f * density), cy - (8f * density))
        path.close()
        canvas.drawPath(path, paint)

        // 3. Beli zunanji obroč (daje oster kontrast na vseh podlagah zemljevida)
        paint.color = Color.WHITE
        canvas.drawCircle(cx, cy, 10.5f * density, paint)

        // 4. Glavna modra pika
        paint.color = Color.parseColor("#1A73E8")
        canvas.drawCircle(cx, cy, 7.5f * density, paint)

        // 5. Majhna bela sredinska pika za natančnost
        paint.color = Color.WHITE
        canvas.drawCircle(cx, cy, 2.2f * density, paint)

        return BitmapDrawable(context.resources, bitmap)
    }

    fun formatDistance(meters: Double): String {
        return if (meters < 1000) {
            "${meters.toInt()} m"
        } else {
            String.format(java.util.Locale.US, "%.1f km", meters / 1000.0)
        }
    }

    fun formatDuration(seconds: Double): String {
        val minutes = (seconds / 60).toInt()
        return if (minutes < 1) {
            "1 min"
        } else if (minutes < 60) {
            "$minutes min"
        } else {
            val h = minutes / 60
            val m = minutes % 60
            "${h} h ${m} min"
        }
    }

    fun formatEta(remainingSeconds: Double): String {
        val etaMillis = System.currentTimeMillis() + (remainingSeconds * 1000).toLong()
        return java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(java.util.Date(etaMillis))
    }

    /**
     * Ustvari usmerjevalno puščico na sami liniji poti (v slogu Google Maps navigacije),
     * ki se zasuče točno v smeri nadaljevanja poti (bearing_after).
     */
    /**
     * Ustvari lepo, veliko ukrivljeno navigacijsko puščico na ovinku,
     * ki se točno prilagodi dejanskemu kotu ceste (turnAngleDeg)
     * ter leži 100% na liniji poti (vhodni repek na prihodni cesti, izhodna konica na odhodni cesti).
     */
    fun createDynamicTurnArrowDrawable(
        context: Context,
        turnAngleDeg: Float
    ): Drawable {
        val density = context.resources.displayMetrics.density
        val sizeDp = 72f
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(80)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cx = sizePx / 2f
        val cy = sizePx / 2f
        val d = density

        // Omeji kot zavoja med -155° in +155° za naraven izgled
        val angle = turnAngleDeg.coerceIn(-155f, 155f)

        // Smer izhodnega kraka v lokalnih koordinatah (-Y je naravnost gor v smeri prihoda)
        val rad = Math.toRadians(angle.toDouble())
        val dirX = Math.sin(rad).toFloat()
        val dirY = -Math.cos(rad).toFloat()

        // Dolžina repka in dolžina izhodnega kraka
        val stemLen = 20f * d
        val outLen = 22f * d

        val startX = cx
        val startY = cy + stemLen

        val shaftEndX = cx + dirX * outLen
        val shaftEndY = cy + dirY * outLen

        // 1. Pot stebla puščice
        val shaftPath = Path().apply {
            moveTo(startX, startY)
            if (kotlin.math.abs(angle) < 14f) {
                // Vožnja / hoja naravnost
                lineTo(shaftEndX, shaftEndY)
            } else {
                // Zavoj: gladek prehod skozi center križišča (cx, cy)
                lineTo(cx, cy + 5f * d)
                quadTo(cx, cy - 2f * d, shaftEndX, shaftEndY)
            }
        }

        // 2. Glava puščice (konica in krilca)
        val headLen = 13f * d
        val headHalfWidth = 9.5f * d

        val tipX = shaftEndX + dirX * (5.5f * d)
        val tipY = shaftEndY + dirY * (5.5f * d)

        val normX = -dirY
        val normY = dirX

        val wing1X = shaftEndX - dirX * (headLen * 0.65f) + normX * headHalfWidth
        val wing1Y = shaftEndY - dirY * (headLen * 0.65f) + normY * headHalfWidth

        val wing2X = shaftEndX - dirX * (headLen * 0.65f) - normX * headHalfWidth
        val wing2Y = shaftEndY - dirY * (headLen * 0.65f) - normY * headHalfWidth

        val notchX = shaftEndX - dirX * (headLen * 0.3f)
        val notchY = shaftEndY - dirY * (headLen * 0.3f)

        val headPath = Path().apply {
            moveTo(tipX, tipY)
            lineTo(wing1X, wing1Y)
            lineTo(notchX, notchY)
            lineTo(wing2X, wing2Y)
            close()
        }

        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.FILL
        }

        // 1. Zunanja senca za globino
        strokePaint.color = Color.parseColor("#35000000")
        strokePaint.strokeWidth = 16f * d
        canvas.save()
        canvas.translate(0f, 1.8f * d)
        canvas.drawPath(shaftPath, strokePaint)
        fillPaint.color = Color.parseColor("#35000000")
        canvas.drawPath(headPath, fillPaint)
        canvas.restore()

        // 2. Krepek beli rob (casing), ki se natanko ujema z robom poti
        strokePaint.color = Color.WHITE
        strokePaint.strokeWidth = 14f * d
        canvas.drawPath(shaftPath, strokePaint)
        fillPaint.color = Color.WHITE
        strokePaint.strokeWidth = 3f * d
        canvas.drawPath(headPath, fillPaint)
        canvas.drawPath(headPath, strokePaint)

        // 3. Notranje smaragdno zeleno jedro (#0F9D58, barva poti)
        strokePaint.color = Color.parseColor("#0F9D58")
        strokePaint.strokeWidth = 8f * d
        canvas.drawPath(shaftPath, strokePaint)

        fillPaint.color = Color.parseColor("#0F9D58")
        canvas.drawPath(headPath, fillPaint)

        return BitmapDrawable(context.resources, bitmap)
    }

    fun createTurnJunctionDrawable(
        context: Context,
        modifier: String? = null,
        type: String? = null
    ): Drawable {
        val density = context.resources.displayMetrics.density
        val sizeDp = 42f
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(48)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cx = sizePx / 2f
        val cy = sizePx / 2f
        val d = density

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // 1. Zunanja senca
        paint.color = Color.parseColor("#44000000")
        paint.style = Paint.Style.FILL
        canvas.drawCircle(cx, cy + 1.5f * d, 16.5f * d, paint)

        // 2. Glavni smaragdno zeleni krog
        paint.color = Color.parseColor("#0F9D58")
        canvas.drawCircle(cx, cy, 15.5f * d, paint)

        // 3. Beli rob
        paint.color = Color.WHITE
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2.5f * d
        canvas.drawCircle(cx, cy, 14.5f * d, paint)

        // 4. Bela ikona zavoja v sredini
        val mod = modifier?.lowercase().orEmpty()
        val path = Path()
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 3f * d
        paint.strokeCap = Paint.Cap.ROUND
        paint.strokeJoin = Paint.Join.ROUND

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }

        if (mod.contains("left")) {
            // Zavoj levo: steblo spodaj, zavije v levo
            path.moveTo(cx + 4f * d, cy + 8f * d)
            path.lineTo(cx + 4f * d, cy)
            path.quadTo(cx + 4f * d, cy - 4f * d, cx - 1f * d, cy - 4f * d)
            path.lineTo(cx - 5f * d, cy - 4f * d)
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx - 9.5f * d, cy - 4f * d)
                lineTo(cx - 4.5f * d, cy - 8.5f * d)
                lineTo(cx - 4.5f * d, cy + 0.5f * d)
                close()
            }
            canvas.drawPath(head, fillPaint)
        } else if (mod.contains("right")) {
            // Zavoj desno: steblo spodaj, zavije v desno
            path.moveTo(cx - 4f * d, cy + 8f * d)
            path.lineTo(cx - 4f * d, cy)
            path.quadTo(cx - 4f * d, cy - 4f * d, cx + 1f * d, cy - 4f * d)
            path.lineTo(cx + 5f * d, cy - 4f * d)
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx + 9.5f * d, cy - 4f * d)
                lineTo(cx + 4.5f * d, cy - 8.5f * d)
                lineTo(cx + 4.5f * d, cy + 0.5f * d)
                close()
            }
            canvas.drawPath(head, fillPaint)
        } else if (mod.contains("uturn")) {
            // U-turn
            path.moveTo(cx + 4.5f * d, cy + 8f * d)
            path.lineTo(cx + 4.5f * d, cy - 2f * d)
            path.quadTo(cx + 4.5f * d, cy - 8f * d, cx, cy - 8f * d)
            path.quadTo(cx - 4.5f * d, cy - 8f * d, cx - 4.5f * d, cy - 2f * d)
            path.lineTo(cx - 4.5f * d, cy + 4f * d)
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx - 4.5f * d, cy + 8.5f * d)
                lineTo(cx - 9f * d, cy + 3.5f * d)
                lineTo(cx - 0f * d, cy + 3.5f * d)
                close()
            }
            canvas.drawPath(head, fillPaint)
        } else {
            // Naravnost
            path.moveTo(cx, cy + 8f * d)
            path.lineTo(cx, cy - 4f * d)
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx, cy - 9.5f * d)
                lineTo(cx - 4.8f * d, cy - 3.8f * d)
                lineTo(cx + 4.8f * d, cy - 3.8f * d)
                close()
            }
            canvas.drawPath(head, fillPaint)
        }

        return BitmapDrawable(context.resources, bitmap)
    }

    /**
     * Ustvari usmerjevalno puščico / chevron, ki leži natanko na liniji poti
     * in se usmeri natančno po azimutu ceste (P1 -> P2).
     */
    fun createRouteChevronDrawable(context: Context): Drawable {
        val density = context.resources.displayMetrics.density
        val sizeDp = 22f
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(24)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cx = sizePx / 2f
        val cy = sizePx / 2f
        val d = density

        val path = Path().apply {
            moveTo(cx, cy - 7f * d) // konica usmerjena gor (sever / 0°)
            lineTo(cx - 6f * d, cy + 5f * d)
            lineTo(cx, cy + 2f * d) // vdolbina za chevron
            lineTo(cx + 6f * d, cy + 5f * d)
            close()
        }

        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        // 1. Zunanja senca
        paint.color = Color.parseColor("#40000000")
        paint.style = Paint.Style.FILL
        canvas.save()
        canvas.translate(0f, 1f * d)
        canvas.drawPath(path, paint)
        canvas.restore()

        // 2. Čist bel rob
        paint.color = Color.WHITE
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 3f * d
        paint.strokeCap = Paint.Cap.ROUND
        paint.strokeJoin = Paint.Join.ROUND
        canvas.drawPath(path, paint)

        // 3. Notranja smaragdno zelena barva (#0F9D58)
        paint.color = Color.parseColor("#0F9D58")
        paint.style = Paint.Style.FILL
        canvas.drawPath(path, paint)

        return BitmapDrawable(context.resources, bitmap)
    }

    /**
     * Ustvari veliko ikono smerne puščice za potisno obvestilo (enako kot Google Maps na sliki 3).
     */
    fun createNotificationManeuverBitmap(
        context: Context,
        modifier: String?,
        type: String?
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val sizePx = (64f * density).toInt().coerceAtLeast(96)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val cx = sizePx / 2f
        val cy = sizePx / 2f

        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1E293B") // Temna elegantna barva kot v Google Maps
            style = Paint.Style.STROKE
            strokeWidth = 6f * density
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#1E293B")
            style = Paint.Style.FILL
        }

        val mod = modifier?.lowercase().orEmpty()
        val path = Path()

        if (mod.contains("right")) {
            // Zavoj desno
            path.moveTo(cx - (10f * density), cy + (16f * density))
            path.lineTo(cx - (10f * density), cy)
            path.quadTo(cx - (10f * density), cy - (10f * density), cx, cy - (10f * density))
            path.lineTo(cx + (10f * density), cy - (10f * density))
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx + (18f * density), cy - (10f * density))
                lineTo(cx + (7f * density), cy - (18f * density))
                lineTo(cx + (7f * density), cy - (2f * density))
                close()
            }
            canvas.drawPath(head, fillPaint)
        } else if (mod.contains("left")) {
            // Zavoj levo
            path.moveTo(cx + (10f * density), cy + (16f * density))
            path.lineTo(cx + (10f * density), cy)
            path.quadTo(cx + (10f * density), cy - (10f * density), cx, cy - (10f * density))
            path.lineTo(cx - (10f * density), cy - (10f * density))
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx - (18f * density), cy - (10f * density))
                lineTo(cx - (7f * density), cy - (18f * density))
                lineTo(cx - (7f * density), cy - (2f * density))
                close()
            }
            canvas.drawPath(head, fillPaint)
        } else if (mod.contains("uturn")) {
            // U-turn
            path.moveTo(cx + (10f * density), cy + (16f * density))
            path.lineTo(cx + (10f * density), cy - (4f * density))
            path.quadTo(cx + (10f * density), cy - (16f * density), cx, cy - (16f * density))
            path.quadTo(cx - (10f * density), cy - (16f * density), cx - (10f * density), cy - (4f * density))
            path.lineTo(cx - (10f * density), cy + (8f * density))
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx - (10f * density), cy + (18f * density))
                lineTo(cx - (18f * density), cy + (7f * density))
                lineTo(cx - (2f * density), cy + (7f * density))
                close()
            }
            canvas.drawPath(head, fillPaint)
        } else if (type == "arrive") {
            fillPaint.color = Color.parseColor("#2E7D32")
            canvas.drawCircle(cx, cy, 14f * density, fillPaint)
            paint.color = Color.WHITE
            paint.strokeWidth = 3f * density
            canvas.drawCircle(cx, cy, 7f * density, paint)
        } else {
            // Naravnost
            path.moveTo(cx, cy + (16f * density))
            path.lineTo(cx, cy - (8f * density))
            canvas.drawPath(path, paint)

            val head = Path().apply {
                moveTo(cx, cy - (18f * density))
                lineTo(cx - (8f * density), cy - (7f * density))
                lineTo(cx + (8f * density), cy - (7f * density))
                close()
            }
            canvas.drawPath(head, fillPaint)
        }

        return bitmap
    }

    fun translateManeuver(type: String?, modifier: String?, name: String?): String {
        val street = if (!name.isNullOrBlank()) " na $name" else ""
        return when (modifier?.lowercase()) {
            "left" -> "Zavijte levo$street"
            "right" -> "Zavijte desno$street"
            "sharp left" -> "Ostro levo$street"
            "sharp right" -> "Ostro desno$street"
            "slight left" -> "Rahlo levo$street"
            "slight right" -> "Rahlo desno$street"
            "straight" -> "Nadaljujte naravnost$street"
            "uturn" -> "Polkrožno obrnite$street"
            else -> {
                when (type?.lowercase()) {
                    "depart" -> "Začnite pot proti cilju$street"
                    "arrive" -> "Prispeli ste na šank!"
                    "roundabout" -> "Vstopite v krožišče$street"
                    else -> if (!street.isBlank()) "Pojdite$street" else "Nadaljujte po poti"
                }
            }
        }
    }
}
