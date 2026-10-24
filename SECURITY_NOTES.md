# Security Notes

This MVP is playable in mock/dev mode and has Firebase-shaped services, but production security needs server authority.

- MVP scoring is partially client-side.
- Client-side scoring is not fully cheat-proof.
- Production should move answer validation to Cloud Functions.
- Production should move scoring to Cloud Functions.
- Production should move matchmaking validation to Cloud Functions.
- Production should move leaderboard updates to Cloud Functions.
- Add anti-cheat checks for repeated answers, impossible scores, and abnormal response timing.
- Validate response times server-side with trusted timestamps.
- Prevent direct client leaderboard writes in production.
- Keep questions readable only to authenticated users and avoid exposing future hidden answers in active sessions.
- Use App Check before public launch.
