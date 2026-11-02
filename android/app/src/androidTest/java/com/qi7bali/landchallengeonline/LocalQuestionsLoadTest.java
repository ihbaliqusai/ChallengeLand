package com.qi7bali.landchallengeonline;

import android.os.Looper;
import android.test.InstrumentationTestCase;

import org.json.JSONArray;
import org.json.JSONObject;
import io.flutter.FlutterInjector;

import java.io.InputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;

/** Checks the actual packaged bank without starting a match or changing history. */
@SuppressWarnings("deprecation")
public final class LocalQuestionsLoadTest extends InstrumentationTestCase {
    public void testStreamingBankMatchesEveryVisibleOriginalRecordAndBoardTier() throws Exception {
        // Production calls originate from FlutterActivity after its loader is
        // initialized. Reproduce that prerequisite without opening account UI.
        getInstrumentation().runOnMainSync(() -> {
            var loader = FlutterInjector.instance().flutterLoader();
            loader.startInitialization(getInstrumentation().getTargetContext());
            loader.ensureInitializationComplete(getInstrumentation().getTargetContext(), null);
        });
        JSONArray source;
        try (InputStream input = getInstrumentation().getTargetContext().getAssets()
                .open("flutter_assets/assets/questions.json");
             ByteArrayOutputStream bytes = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[8192];
            int count;
            while ((count = input.read(buffer)) != -1) bytes.write(buffer, 0, count);
            source = new JSONArray(bytes.toString(StandardCharsets.UTF_8.name()));
        }
        ArrayList<Question> actual = LocalQuestions.loadAll(getInstrumentation().getTargetContext());
        int visible = 0;
        int[] expectedTiers = new int[3];
        for (int i = 0; i < source.length(); i++) {
            JSONObject row = source.getJSONObject(i);
            String category = row.optString("Category", LocalQuestions.FALLBACK_CATEGORY).trim();
            if (category.isEmpty()) category = LocalQuestions.FALLBACK_CATEGORY;
            if (LocalQuestions.isCategoryHidden(category)) continue;
            assertTrue("The stream must not stop before source row " + i, visible < actual.size());
            Question question = actual.get(visible++);
            assertEquals(row.optString("Q"), question.getQ());
            assertEquals(row.optString("R"), question.getR());
            assertEquals(row.optString("W1"), question.getW1());
            assertEquals(row.optString("W2"), question.getW2());
            assertEquals(row.optString("W3"), question.getW3());
            assertEquals(row.optString("Level"), question.getLevel());
            assertEquals(row.optString("Img", ""), question.getImg());
            assertEquals(category, question.getCategory());
            JSONArray clubs = row.optJSONArray("ClubPath");
            ArrayList<String> expectedClubs = new ArrayList<>();
            if (clubs != null) for (int j = 0; j < clubs.length(); j++) {
                String club = clubs.optString(j, "").trim();
                if (!club.isEmpty()) expectedClubs.add(club);
            }
            assertEquals(expectedClubs, question.getClubPath());
            expectedTiers[LocalQuestions.tierForLevel(question.getLevel())]++;
        }
        assertEquals("Every visible source record must survive streaming", visible, actual.size());
        int[] actualTiers = new int[3];
        for (var category : LocalQuestions.loadBoardPool(getInstrumentation().getTargetContext()).entrySet()) {
            assertEquals(3, category.getValue().size());
            for (int tier = 0; tier < 3; tier++) for (Question question : category.getValue().get(tier)) {
                assertEquals(category.getKey(), question.getCategory());
                assertEquals(tier, LocalQuestions.tierForLevel(question.getLevel()));
                actualTiers[tier]++;
            }
        }
        for (int tier = 0; tier < 3; tier++) assertEquals(expectedTiers[tier], actualTiers[tier]);
        assertTrue(LocalQuestions.isPrepared());
        CountDownLatch ready = new CountDownLatch(1);
        AtomicBoolean mainThread = new AtomicBoolean();
        LocalQuestions.preload(getInstrumentation().getTargetContext(), () -> {
            mainThread.set(Looper.myLooper() == Looper.getMainLooper());
            ready.countDown();
        });
        assertTrue("Ready callback must finish", ready.await(5, TimeUnit.SECONDS));
        assertTrue("Native launch callback must return to Android's UI thread", mainThread.get());
    }
}
