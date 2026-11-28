package ca.b_ark.amphitere;

import android.app.Activity;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.TextView;
import com.tbd.forkfront.companion.OfflineInference;
import com.tbd.forkfront.companion.OfflineModelStore;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Debug APK only. Launched explicitly via ADB; never sends gameplay input or
 * questions over the network. Timings use Android's monotonic elapsed clock.
 */
public final class OfflineBenchmarkActivity extends Activity {
  private static final String[] QUESTIONS = {
      "What should I do if I'm low on health and have no healing potions?",
      "How does Elbereth protect me?",
      "What food should I carry to avoid starvation?"
  };
  private static final int REPEATS = 3;
  private final OfflineInference inference = new OfflineInference();
  private final JSONArray samples = new JSONArray();
  private TextView label;
  private int index;
  private long started;
  private boolean finished;

  @Override
  public void onCreate(Bundle state) {
    super.onCreate(state);
    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    label = new TextView(this);
    label.setTextSize(20);
    label.setPadding(36, 36, 36, 36);
    label.setGravity(Gravity.CENTER);
    setContentView(label);
    if (!OfflineModelStore.installed(this) || !OfflineInference.nativeReady()) {
      finishBenchmark("error", "GGUF model or native runtime is unavailable");
      return;
    }
    started = SystemClock.elapsedRealtimeNanos();
    writeReport("running", null);
    next();
  }

  private void next() {
    if (finished) return;
    if (index >= QUESTIONS.length * REPEATS) {
      finishBenchmark("complete", null);
      return;
    }
    final int sampleIndex = index++;
    final int questionIndex = sampleIndex / REPEATS;
    final int repeat = sampleIndex % REPEATS + 1;
    final String question = QUESTIONS[questionIndex];
    label.setText("Offline AI benchmark\nQuestion " + (questionIndex + 1)
        + "/3, repeat " + repeat + "/3\n\n" + question
        + "\n\nKeep the tablet awake; do not switch apps.");
    final long startNs = SystemClock.elapsedRealtimeNanos();
    inference.ask(this, question, "Adventurer", true, null, (reply, error) -> {
      if (finished) return;
      long elapsedNs = SystemClock.elapsedRealtimeNanos() - startNs;
      try {
        JSONObject sample = new JSONObject();
        sample.put("question_number", questionIndex + 1);
        sample.put("repeat", repeat);
        sample.put("question", question);
        sample.put("elapsed_ms", Math.round(elapsedNs / 1000000.0));
        sample.put("generated", reply != null && reply.generated);
        sample.put("answer", reply == null ? "" : reply.answer);
        sample.put("error", error == null ? JSONObject.NULL : error);
        samples.put(sample);
      } catch (Exception e) {
        finishBenchmark("error", "Could not record benchmark: " + e.getMessage());
        return;
      }
      writeReport("running", null);
      // Yield to Android's main loop; inference itself runs off the UI thread.
      label.postDelayed(this::next, 250);
    });
  }

  private void finishBenchmark(String status, String error) {
    finished = true;
    writeReport(status, error);
    label.setText("Offline benchmark " + status + "\n"
        + samples.length() + " of " + (QUESTIONS.length * REPEATS)
        + " samples recorded.\n\nReturn to PowerShell for results."
        + (error == null ? "" : "\n" + error));
    inference.close();
  }

  private void writeReport(String status, String error) {
    try {
      JSONObject report = new JSONObject();
      report.put("schema_version", 1);
      report.put("status", status);
      report.put("model", "locally imported GGUF");
      report.put("mode", "factual");
      report.put("repeat_count", REPEATS);
      report.put("elapsed_total_ms",
          started == 0 ? 0 : Math.round(
              (SystemClock.elapsedRealtimeNanos() - started) / 1000000.0));
      report.put("samples", samples);
      if (error != null) report.put("error", error);
      File dir = getFilesDir();
      File tmp = new File(dir, "offline-benchmark.json.tmp");
      File dest = new File(dir, "offline-benchmark.json");
      try (FileOutputStream out = new FileOutputStream(tmp)) {
        out.write(report.toString(2).getBytes(StandardCharsets.UTF_8));
        out.getFD().sync();
      }
      if (!tmp.renameTo(dest)) {
        if (dest.exists() && !dest.delete()) throw new IllegalStateException("cannot replace report");
        if (!tmp.renameTo(dest)) throw new IllegalStateException("cannot finalize report");
      }
    } catch (Exception ex) {
      android.util.Log.e("NetHackOfflineBenchmark", "Writing report failed", ex);
      if (label != null) label.setText("Benchmark report could not be saved: " + ex.getMessage());
    }
  }

  @Override
  protected void onDestroy() {
    inference.close();
    super.onDestroy();
  }
}
