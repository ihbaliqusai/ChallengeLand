# Firestore Schema

Collections:

- `users/{uid}`: private user profile and stats.
- `public_profiles/{uid}`: searchable public username, avatar, level, rating.
- `rooms/{roomId}`: room settings, status, host, code.
- `rooms/{roomId}/players/{uid}`: future normalized player records.
- `game_sessions/{sessionId}`: active or finished game session.
- `game_sessions/{sessionId}/answers/{answerId}`: player answer submissions.
- `categories/{categoryId}`: quiz categories.
- `questions/{questionId}`: quiz questions.
- `matchmaking_queue/{uid}`: online queue entries.
- `daily_challenges/{dateKey}`: daily question set.
- `daily_scores/{uid-dateKey}`: user daily score.
- `leaderboards/{period}/entries/{uid}`: today/week/all leaderboard entries.
- `friend_requests/{requestId}`: pending/accepted/rejected friend requests.
- `friends/{uid}/items/{friendUid}`: friend list items.
- `match_history/{historyId}`: player match summary.

Use `lib/core/constants/firestore_collections.dart` for collection names to avoid string duplication.

Recommended indexes:

- `public_profiles.usernameLower`
- `game_sessions.playerIds + status`
- `leaderboards/{period}/entries.score desc`
- `daily_scores.dateKey + score desc`
- `friend_requests.toUid + status`
