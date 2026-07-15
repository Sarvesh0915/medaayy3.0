// Target path once android/ exists (adjust the package line to match!):
//   android/app/src/main/kotlin/medaayu/com/SosWidgetProvider.kt
//
// A single tap opens the app straight into the SOS screen — it does NOT
// silently place a call from the widget itself. That's a deliberate choice:
// running the full SOS flow (geolocation, dialer, ambulance app, Supabase
// write) from a background widget click without the app ever opening is
// unreliable on most Android versions and hard to guarantee works when it
// matters most. Opening the app to a pre-loaded SOS screen is one tap and
// far more dependable.

package medaayu.com // TODO: change this if you used a different applicationId in Step 0

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class SosWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.sos_widget)

            // "medaayu://sos" is read on the Dart side in widget_service.dart
            // via HomeWidget.initiallyLaunchedFromHomeWidget() /
            // HomeWidget.widgetClicked, to navigate straight to SosScreen.
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                android.net.Uri.parse("medaayu://sos")
            )
            views.setOnClickPendingIntent(R.id.sos_widget_label, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
