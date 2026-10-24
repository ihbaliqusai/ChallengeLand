package com.qi7bali.landchallengeonline;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Random;
import java.util.Set;

/** Pure selection policy: exhaustion never resets a player's lifetime history. */
final class QuestionSelection {
    private QuestionSelection() {}

    static ArrayList<Question> unseen(List<Question> pool, Set<String> excluded, Random random) {
        ArrayList<Question> result = new ArrayList<>();
        Set<String> keys = new HashSet<>(excluded);
        for (Question q : pool) if (q != null && keys.add(QuestionIdentity.key(q))) result.add(q);
        Collections.shuffle(result, random);
        return result;
    }

    static Question pick(List<Question> pool, Set<String> excluded, Set<Question> used, Random random) {
        if (pool == null || pool.isEmpty()) return null;
        Set<String> keys = new HashSet<>(excluded);
        for (Question q : used) keys.add(QuestionIdentity.key(q));
        // Reservoir sampling avoids the bias toward entries following a seen run.
        Question chosen = null;
        int count = 0;
        for (Question q : pool) if (q != null && keys.add(QuestionIdentity.key(q))) {
            if (random.nextInt(++count) == 0) chosen = q;
        }
        if (chosen != null) used.add(chosen);
        return chosen;
    }
}
