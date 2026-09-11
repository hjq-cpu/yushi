package com.yushi.yushi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.Executors

class TodayWidget : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action in listOf(REFRESH, Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            val pending = goAsync()
            executor.execute { try { update(context) } finally { pending.finish() } }
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        executor.execute { try { update(context) } finally { pending.finish() } }
    }

    companion object {
        private const val REFRESH = "com.yushi.yushi.REFRESH_WIDGET"
        private val executor = Executors.newSingleThreadExecutor()
        fun refresh(context: Context) {
            context.sendBroadcast(Intent(context, TodayWidget::class.java).setAction(REFRESH))
        }

        private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }

        private fun update(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, TodayWidget::class.java))
            if (ids.isEmpty()) return
            val views = RemoteViews(context.packageName, R.layout.today_widget)
            val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, open)
            views.setOnClickPendingIntent(R.id.widget_refresh, PendingIntent.getBroadcast(context, 1,
                Intent(context, TodayWidget::class.java).setAction(REFRESH),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
            try {
                val file = context.getDatabasePath("yushi.sqlite")
                val data = if (file.exists()) SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    db.rawQuery("SELECT snapshot FROM app_state WHERE id = 1", null).use { cursor ->
                        if (cursor.moveToFirst()) JSONObject(cursor.getString(0)) else JSONObject()
                    }
                } else JSONObject()
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
                val completed: (JSONObject) -> Boolean = { task -> records.any {
                    it.optString("taskId") == task.optString("id") && it.optString("status") == "completed" &&
                        if (task.getJSONObject("recurrence").optString("type") == "none") it.optString("date") <= today
                        else it.optString("date") == today
                } }
                val tasks = (data.optJSONArray("tasks") ?: JSONArray()).objects().filter { task ->
                    val project = if (task.isNull("projectId")) null else task.optString("projectId")
                    val planned = if (task.isNull("plannedDate")) "" else task.optString("plannedDate")
                    val rule = task.getJSONObject("recurrence")
                    val entries = records.filter { it.optString("taskId") == task.optString("id") }
                    task.optString("status") in listOf("active", "planned") &&
                        (project == null || projects.any { it.optString("id") == project && it.optString("status") == "active" }) &&
                        planned <= today && task.optString("createdAt").take(10) <= today &&
                        (entries.any { it.optString("date") == today } || when (rule.optString("type")) {
                            "none" -> planned == today && !completed(task)
                            "daily" -> true
                            "weekdays" -> weekday <= 5
                            "selectedWeekdays" -> rule.getJSONArray("weekdays").let { days -> (0 until days.length()).any { days.getInt(it) == weekday } }
                            "weeklyTarget" -> entries.count { it.optString("status") == "completed" && it.optString("date") >= weekStart && it.optString("date") < weekEnd } < rule.optInt("weeklyTarget", 1)
                            else -> false
                        })
                }.sortedWith(compareByDescending<JSONObject> { it.optBoolean("isFocus") }
                    .thenBy { if (it.isNull("timeMinutes")) 1440 else it.optInt("timeMinutes") }
                    .thenBy { it.optString("createdAt") }.thenBy { it.optString("id") })
                val pending = tasks.filter { task -> !completed(task) && !records.any {
                    it.optString("taskId") == task.optString("id") && it.optString("date") == today && it.optString("status") == "skipped"
                } }
                views.setTextViewText(R.id.widget_progress, "$today · ${pending.size} 件待办 · ${tasks.count(completed)} 件已完成")
                views.setTextViewText(R.id.widget_tasks, if (pending.isEmpty()) "今天的待办已清空\n给自己一点从容的空间。" else pending.take(4).joinToString("\n") { task ->
                    val time = if (task.isNull("timeMinutes")) "" else task.optInt("timeMinutes").let { String.format(Locale.US, "%02d:%02d  ", it / 60, it % 60) }
                    "${if (task.optBoolean("isFocus")) "★" else "○"}  $time${task.optString("title").replace('\n', ' ')}"
                })
                views.setTextViewText(R.id.widget_more, if (pending.size > 4) "查看全部 ${pending.size} 件待办 →" else "打开余时查看完整计划 →")
            } catch (_: Exception) {
                views.setTextViewText(R.id.widget_tasks, "暂时无法读取计划，请点击打开余时")
                views.setTextViewText(R.id.widget_progress, "点击刷新重试")
            }
            manager.updateAppWidget(ids, views)
        }
    }
}
