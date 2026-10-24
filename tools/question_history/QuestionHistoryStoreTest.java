package com.qi7bali.landchallengeonline;

import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.functions.FirebaseFunctions;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;

public final class QuestionHistoryStoreTest {
    private static int checks;
    private static void check(boolean value, String message) { checks++; if (!value) throw new AssertionError(message); }
    private static Question q(String text) { Question q = new Question(); q.setQ(text); return q; }
    private static Set<String> prepare(VerificationContext c) {
        Set<String> result = new HashSet<>();
        QuestionHistory.prepare(c, "", "", result::addAll, error -> { throw new AssertionError(error); });
        return result;
    }
    private static void reserve(VerificationContext c, Question question) {
        AtomicInteger ready = new AtomicInteger();
        QuestionHistory.reserve(c, "", "", List.of(question), ready::incrementAndGet, error -> { throw new AssertionError(error); });
        check(ready.get() == 1, "Reservation did not finish");
    }

    @SuppressWarnings("unchecked")
    public static void main(String[] args) throws Exception {
        VerificationContext c = new VerificationContext(); c.switchAccount("guest_local");
        FirebaseAuth.setUid(null); Data.connected = false;
        Question first = q("Guest question"); reserve(c, first);
        check(QuestionHistory.snapshot(c).contains(QuestionIdentity.key(first)), "Guest history was not durable");
        VerificationContext restarted = new VerificationContext(); restarted.restorePreferencesFrom(c);
        check(QuestionHistory.snapshot(restarted).contains(QuestionIdentity.key(first)), "Restart lost history");
        AtomicInteger failures = new AtomicInteger();
        QuestionHistory.reserve(c, "", "", List.of(first), () -> { throw new AssertionError("Repeated offline reservation"); }, error -> failures.incrementAndGet());
        check(failures.get() == 1, "Repeated local allocation must fail");

        c.switchAccount("alice"); FirebaseAuth.setUid("alice");
        check(QuestionHistory.snapshot(c).contains(QuestionIdentity.key(first)), "Guest history did not migrate");
        c.switchAccount("bob"); FirebaseAuth.setUid("bob");
        check(QuestionHistory.snapshot(c).isEmpty(), "Guest history leaked to a second account");
        c.switchAccount("alice"); FirebaseAuth.setUid("alice");
        QuestionHistory.prepare(c, "", "", ignored -> { throw new AssertionError("Unhydrated account started offline"); }, error -> failures.incrementAndGet());
        check(failures.get() == 2, "First offline use must require the cloud history");

        Set<String> cloud = new HashSet<>(Set.of(QuestionIdentity.key(q("Already on another device"))));
        FirebaseFunctions.handler = data -> {
            String action = (String) data.get("action");
            Collection<String> keys = (Collection<String>) data.getOrDefault("keys", List.of());
            if ("prepare".equals(action)) { cloud.addAll(keys); return Map.of("keys", new ArrayList<>(cloud), "ownKeys", new ArrayList<>(cloud)); }
            if (keys.stream().anyMatch(cloud::contains)) throw new IllegalStateException("Conflict");
            cloud.addAll(keys); return Map.of("reserved", true);
        };
        Data.connected = true;
        check(prepare(c).equals(cloud), "Cloud merge lost the guest or remote history");
        check(c.namespace("QuestionHistory_v1_alice").getStringSet("pending", Set.of()).isEmpty(), "Acknowledged uploads stayed pending");
        Data.connected = false; reserve(c, q("Offline after sync"));
        Set<String> pending = c.namespace("QuestionHistory_v1_alice").getStringSet("pending", Set.of());
        check(pending.size() == 1, "Offline reservation was not queued");
        Data.connected = true;
        FirebaseFunctions.handler = data -> { throw new IllegalStateException("NETWORK_ERROR"); };
        QuestionHistory.prepare(c, "", "", ignored -> { throw new AssertionError("Network error was ignored"); }, error -> failures.incrementAndGet());
        check(c.namespace("QuestionHistory_v1_alice").getStringSet("pending", Set.of()).equals(pending), "Failed upload discarded pending history");

        Data.connected = false;
        Set<String> before = QuestionHistory.snapshot(c);
        c.namespace("QuestionHistory_v1_alice").failNextCommit = true;
        QuestionHistory.reserve(c, "", "", List.of(q("Disk failure")), () -> { throw new AssertionError("Disk failure allowed gameplay"); }, error -> failures.incrementAndGet());
        check(QuestionHistory.snapshot(c).equals(before), "Disk failure did not roll back preference memory");

        VerificationContext legacy = new VerificationContext(); legacy.switchAccount("guest_local"); FirebaseAuth.setUid(null);
        Question saved = q("Old saved question"); saved.setClubPath(new ArrayList<>(List.of("روما", "ميلان")));
        legacy.namespace("CampaignActiveProgress").edit().putString("active_stage_record",
                "{\"state\":{\"cells\":[[{\"question\":{\"Q\":\"Old saved question\",\"ClubPath\":[\"روما\",\"ميلان\"]}}]]}}").commit();
        check(QuestionHistory.snapshot(legacy).contains(QuestionIdentity.key(saved)), "Saved board migration missed its nested question");

        VerificationContext parallel = new VerificationContext(); parallel.switchAccount("guest_local");
        Question shared = q("Concurrent offline allocation"); AtomicInteger accepted = new AtomicInteger(), rejected = new AtomicInteger();
        Runnable select = () -> QuestionHistory.reserve(parallel, "", "", List.of(shared), accepted::incrementAndGet, error -> rejected.incrementAndGet());
        Thread a = new Thread(select), b = new Thread(select); a.start(); b.start(); a.join(); b.join();
        check(accepted.get() == 1 && rejected.get() == 1, "Concurrent offline selections both committed");
        System.out.println("Passed " + checks + " production history storage, guest/account, migration, offline queue, failure and concurrency checks.");
    }
}
