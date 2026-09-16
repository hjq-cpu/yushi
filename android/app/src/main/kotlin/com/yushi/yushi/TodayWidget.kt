package com.yushi.yushi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.database.sqlite.SQLiteDatabase
import android.os.Bundle
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

open class TodayWidget : AppWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context, manager: AppWidgetManager, id: Int, options: Bundle,
    ) {
        refresh(context)
    }
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(
                REFRESH, COMPLETE_TASK, Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED,
            )
        ) {
            val pending = goAsync()
            executor.execute {
                try {
                    if (intent.action == COMPLETE_TASK) {
                        intent.getStringExtra(TASK_ID)?.let { completeTask(context, it) }
                    }
                    update(context)
                } finally {
                    pending.finish()
                }
            }
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        executor.execute { try { update(context) } finally { pending.finish() } }
    }

    companion object {
        private const val REFRESH = "com.yushi.yushi.REFRESH_WIDGET"
        private const val COMPLETE_TASK = "com.yushi.yushi.COMPLETE_WIDGET_TASK"
        private const val TASK_ID = "task_id"
        private val executor = Executors.newSingleThreadExecutor()
        private val taskViewIds = intArrayOf(
            R.id.widget_task_1, R.id.widget_task_2, R.id.widget_task_3, R.id.widget_task_4,
            R.id.widget_task_5, R.id.widget_task_6, R.id.widget_task_7, R.id.widget_task_8,
        )

        fun refresh(context: Context) {
            context.sendBroadcast(Intent(context, TodayWidget::class.java).setAction(REFRESH))
        }

        private fun JSONArray.objects(): List<JSONObject> =
            (0 until length()).map { getJSONObject(it) }

        private fun readSnapshot(context: Context): JSONObject {
            val file = context.getDatabasePath("yushi.sqlite")
            if (!file.exists()) return JSONObject()
            return SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                db.rawQuery("SELECT snapshot FROM app_state WHERE id = 1", null).use { cursor ->
                    if (cursor.moveToFirst()) JSONObject(cursor.getString(0)) else JSONObject()
                }
            }
        }

        private fun completeTask(context: Context, taskId: String) {
            val file = context.getDatabasePath("yushi.sqlite")
            if (!file.exists()) return
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
            val timestamp = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSXXX", Locale.US).format(Date())
            SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                db.beginTransaction()
                try {
                    val data = db.rawQuery("SELECT snapshot FROM app_state WHERE id = 1", null).use { cursor ->
                        if (cursor.moveToFirst()) JSONObject(cursor.getString(0)) else null
                    }
                    if (data != null) {
                        val records = data.optJSONArray("completions") ?: JSONArray().also {
                            data.put("completions", it)
                        }
                        val completion = JSONObject()
                            .put("id", "$taskId@$today")
                            .put("taskId", taskId)
                            .put("date", today)
                            .put("status", "completed")
                            .put("note", "")
                            .put("updatedAt", timestamp)
                        val existing = (0 until records.length()).firstOrNull { index ->
                            records.getJSONObject(index).let {
                                it.optString("taskId") == taskId && it.optString("date") == today
                            }
                        }
                        if (existing == null) records.put(completion) else records.put(existing, completion)
                        db.update(
                            "app_state",
                            ContentValues().apply { put("snapshot", data.toString()) },
                            "id = 1",
                            null,
                        )
                    }
                    db.setTransactionSuccessful()
                } finally {
                    db.endTransaction()
                }
            }
        }

        private fun update(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = listOf(TodayWidget::class.java, CompactTodayWidget::class.java,
                LargeTodayWidget::class.java).flatMap {
                manager.getAppWidgetIds(ComponentName(context, it)).toList()
            }
            if (ids.isEmpty()) return
            // Read once per refresh, even when several sizes are on the desktop.
            val data = runCatching { readSnapshot(context) }.getOrNull()
            for (id in ids) {
            val options = manager.getAppWidgetOptions(id)
            val landscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
            val width = options.getInt(if (landscape) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
            val height = options.getInt(if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 180)
            val fontScale = context.resources.configuration.fontScale.coerceAtLeast(1f)
            val rowHeight = maxOf(48f, 24f * fontScale + 16)
            val rowCount = ((height - 32 - maxOf(48f, 26f * fontScale) - 22 * fontScale - 8) / rowHeight).toInt().coerceIn(1, 8)
            val views = RemoteViews(context.packageName, R.layout.today_widget)
            views.setTextViewText(R.id.widget_heading, SimpleDateFormat(if (width < 220) "M月d日" else "M月d日 EEEE", Locale.CHINA).format(Date()))
            views.setTextViewTextSize(R.id.widget_heading, TypedValue.COMPLEX_UNIT_SP, 20f)
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, open)
            views.setOnClickPendingIntent(
                R.id.widget_refresh,
                PendingIntent.getBroadcast(
                    context, 1, Intent(context, TodayWidget::class.java).setAction(REFRESH),
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            try {
                showTasks(context, views, data ?: throw IllegalStateException("Snapshot unavailable"), rowCount, width < 220)
            } catch (_: Exception) {
                views.setTextViewText(R.id.widget_progress, "读取失败 · 点击刷新")
                views.setViewVisibility(R.id.widget_task_list, View.GONE)
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty, "暂时无法读取计划")
            }
            manager.updateAppWidget(id, views)
            }
        }

        private fun showTasks(context: Context, views: RemoteViews, data: JSONObject, rowCount: Int, compact: Boolean) {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            val cal = Calendar.getInstance()
            val today = dateFormat.format(cal.time)
            val weekday = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1
            val startsOn = data.optJSONObject("settings")?.optInt("weekStartsOn", 1) ?: 1
            cal.add(Calendar.DAY_OF_MONTH, -((weekday - startsOn + 7) % 7))
            val weekStart = dateFormat.format(cal.time)
            cal.add(Calendar.DAY_OF_MONTH, 7)
            val weekEnd = dateFormat.format(cal.time)
            val projects = (data.optJSONArray("projects") ?: JSONArray()).objects()
            val records = (data.optJSONArray("completions") ?: JSONArray()).objects()
            val completed: (JSONObject) -> Boolean = { task ->
                records.any {
                    it.optString("taskId") == task.optString("id") &&
                        it.optString("status") == "completed" &&
                        if (task.getJSONObject("recurrence").optString("type") == "none") {
                            it.optString("date") <= today
                        } else it.optString("date") == today
                }
            }
            val tasks = (data.optJSONArray("tasks") ?: JSONArray()).objects().filter { task ->
                val project = if (task.isNull("projectId")) null else task.optString("projectId")
                val planned = if (task.isNull("plannedDate")) "" else task.optString("plannedDate")
                val rule = task.getJSONObject("recurrence")
                val entries = records.filter { it.optString("taskId") == task.optString("id") }
                task.optString("status") in listOf("active", "planned") &&
                    (project == null || projects.any {
                        it.optString("id") == project && it.optString("status") == "active"
                    }) && planned <= today && task.optString("createdAt").take(10) <= today &&
                    (entries.any { it.optString("date") == today } || when (rule.optString("type")) {
                        "none" -> planned == today && !completed(task)
                        "daily" -> true
                        "weekdays" -> weekday <= 5
                        "selectedWeekdays" -> rule.getJSONArray("weekdays").let { days ->
                            (0 until days.length()).any { days.getInt(it) == weekday }
                        }
                        "weeklyTarget" -> entries.count {
                            it.optString("status") == "completed" &&
                                it.optString("date") >= weekStart && it.optString("date") < weekEnd
                        } < rule.optInt("weeklyTarget", 1)
                        else -> false
                    })
            }.sortedWith(
                compareByDescending<JSONObject> { it.optBoolean("isFocus") }
                    .thenBy { if (it.isNull("timeMinutes")) 1440 else it.optInt("timeMinutes") }
                    .thenBy { it.optString("createdAt") }.thenBy { it.optString("id") },
            )
            val pending = tasks.filter { task ->
                !completed(task) && !records.any {
                    it.optString("taskId") == task.optString("id") &&
                        it.optString("date") == today && it.optString("status") == "skipped"
                }
            }
            views.setTextViewText(
                R.id.widget_progress,
                "今天的安排",
            )
            views.setViewVisibility(R.id.widget_task_list, if (pending.isEmpty()) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_progress, if (tasks.isEmpty()) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, if (pending.isEmpty()) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.widget_empty, if (tasks.isEmpty()) "暂无安排" else "暂无其他安排")
            taskViewIds.forEachIndexed { index, viewId ->
                val task = if (index < rowCount) pending.getOrNull(index) else null
                views.setViewVisibility(viewId, if (task == null) View.GONE else View.VISIBLE)
                if (task != null) {
                    val time = if (task.isNull("timeMinutes")) "" else task.optInt("timeMinutes").let {
                        String.format(Locale.US, "%02d:%02d  ", it / 60, it % 60)
                    }
                    val title = task.optString("title").replace('\n', ' ')
                    views.setTextViewText(
                        viewId,
                        "○  $time$title",
                    )
                    views.setContentDescription(viewId, "完成$title")
                    views.setOnClickPendingIntent(
                        viewId,
                        PendingIntent.getBroadcast(
                            context,
                            task.optString("id").hashCode(),
                            Intent(context, TodayWidget::class.java)
                                .setAction(COMPLETE_TASK)
                                .putExtra(TASK_ID, task.optString("id")),
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                        ),
                    )
                }
            }
        }
    }
}

class CompactTodayWidget : TodayWidget()
class LargeTodayWidget : TodayWidget()
