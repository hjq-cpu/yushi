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
                        val task = (data.optJSONArray("tasks") ?: JSONArray()).objects().firstOrNull { it.optString("id") == taskId }
                        if (task == null || task.optString("status") == "archived" || task.optString("phase") == "completed") return
                        task.put("phase", "completed").put("updatedAt", timestamp)

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
            views.setTextViewText(R.id.widget_heading, "余时 · 待办")
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
                views.setTextViewText(R.id.widget_empty, "暂时无法读取事项")
            }
            manager.updateAppWidget(id, views)
            }
        }

        private fun showTasks(context: Context, views: RemoteViews, data: JSONObject, rowCount: Int, compact: Boolean) {
            val projects = (data.optJSONArray("projects") ?: JSONArray()).objects()
            val records = (data.optJSONArray("completions") ?: JSONArray()).objects()
            fun phase(task: JSONObject): String = if (task.has("phase")) task.optString("phase") else
                if (task.optJSONObject("recurrence")?.optString("type") == "none" && records.any {
                    it.optString("taskId") == task.optString("id") && it.optString("status") == "completed"
                }) "completed" else "pending"
            val tasks = (data.optJSONArray("tasks") ?: JSONArray()).objects().filter { task ->
                task.optString("status") != "archived" && phase(task) != "completed" &&
                !projects.any { it.optString("id") == task.optString("projectId") && it.optString("status") == "archived" }
            }.sortedWith(compareBy<JSONObject> { if (phase(it) == "doing") 0 else 1 }.thenBy { it.optString("createdAt") })
            val pending = tasks
            views.setTextViewText(
                R.id.widget_progress,
                "在做与待办",
            )
            views.setViewVisibility(R.id.widget_task_list, if (pending.isEmpty()) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_progress, if (tasks.isEmpty()) View.GONE else View.VISIBLE)
            views.setViewVisibility(R.id.widget_empty, if (pending.isEmpty()) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.widget_empty, if (tasks.isEmpty()) "暂时没有待办" else "暂时没有待办")
            taskViewIds.forEachIndexed { index, viewId ->
                val task = if (index < rowCount) pending.getOrNull(index) else null
                views.setViewVisibility(viewId, if (task == null) View.GONE else View.VISIBLE)
                if (task != null) {
                    val title = task.optString("title").replace('\n', ' ')
                    views.setTextViewText(
                        viewId,
                        "○  ${if (phase(task) == "doing") "在做 · " else ""}$title",
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
