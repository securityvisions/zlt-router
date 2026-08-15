package ir.parsavisions.xirouter

import android.app.Application

class XirouterApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        CrashDiagnostics.install(this)
    }
}

object CrashDiagnostics {
    @Volatile private var installed = false

    fun install(context: android.content.Context) {
        if (installed) return
        synchronized(this) {
            if (installed) return
            val appContext = context.applicationContext
            val prior = Thread.getDefaultUncaughtExceptionHandler()
            Thread.setDefaultUncaughtExceptionHandler { thread, error ->
                val runtime = Runtime.getRuntime()
                DiagnosticStore(appContext).add(DiagnosticRecord(
                    timestamp = System.currentTimeMillis(), kind = DiagnosticKind.Crash,
                    operation = "uncaught:${thread.name.take(40)}", lifecycle = "application",
                    memoryPressure = "used_mb=${(runtime.totalMemory() - runtime.freeMemory()) / 1_048_576}",
                    stack = Diagnostics.sanitizeStack(error),
                ))
                prior?.uncaughtException(thread, error)
            }
            installed = true
        }
    }
}
