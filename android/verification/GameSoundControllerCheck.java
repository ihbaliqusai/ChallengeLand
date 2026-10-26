package com.qi7bali.landchallengeonline;

import android.content.Context;
import android.media.MediaPlayer;
import android.os.Handler;

/** Executes production fade/channel logic against strict players and a virtual clock. */
public final class GameSoundControllerCheck {
    private static int checks;
    private static void check(boolean condition, String message) {
        checks++;
        if (!condition) throw new AssertionError(message);
    }
    private static void close(float actual, float expected, String message) {
        check(Math.abs(actual - expected) < 0.0001f, message + ": " + actual);
    }
    private static GameSoundController controller() {
        Handler.reset();
        MediaPlayer.reset();
        AppPrefs.musicEnabled = true;
        AppPrefs.soundEnabled = true;
        return new GameSoundController(new Context());
    }
    private static void clean(GameSoundController controller) {
        controller.releaseCurrent();
        Handler.advanceBy(1000);
        check(MediaPlayer.liveCount() == 0, "Every player must be released");
        check(Handler.pendingCount() == 0, "No fade may survive release");
        check(MediaPlayer.illegalAccesses == 0, "No access after release or duplicate release");
    }

    public static void main(String[] args) {
        repeatedQuestionDoesNotRestart();
        musicFadeStartsAtConfiguredLevel();
        pauseCancelsCurrentAndFadingPlayers();
        muteCancelsOutgoingEffectAndRetainsGain();
        effectFadeRespectsCurrentChannelLevel();
        musicPreferenceDoesNotCutEffects();
        openingTransitionSharesMusicChannel();
        completionAndErrorsCancelFadeSafely();
        rapidTransitionsDoNotAccumulate();
        blockedPlaybackAndCreateFailureAreSafe();
        System.out.println("Game sound controller: " + checks + " checks passed.");
    }

    private static void repeatedQuestionDoesNotRestart() {
        GameSoundController controller = controller();
        controller.play(R.raw.main_theme_0, true, true, false);
        MediaPlayer original = MediaPlayer.latest();
        controller.play(R.raw.main_theme_0, true, true, false);
        check(MediaPlayer.CREATED.size() == 1, "Consecutive questions keep their looping bed");
        check(original.playing && !original.released, "The original bed keeps playing");
        clean(controller);
    }

    private static void musicFadeStartsAtConfiguredLevel() {
        GameSoundController controller = controller();
        controller.play(R.raw.main_theme_320bit_chosic, false, true, false);
        MediaPlayer outgoing = MediaPlayer.latest();
        float base = GameAudioProfile.musicVolume(R.raw.main_theme_320bit_chosic);
        close(outgoing.volume(), base, "Initial music level follows source profile");
        controller.play(R.raw.main_theme_1, true, true, false);
        for (int i = 0; i < 14; i++) Handler.advanceBy(25);
        float previous = base;
        for (float volume : outgoing.volumes) {
            check(volume <= previous, "Fading must never jump above the prior gain");
            previous = volume;
        }
        check(outgoing.released && outgoing.releases == 1, "Outgoing fade releases once");
        close(MediaPlayer.latest().volume(), 0.50f, "Incoming music uses its own gain");
        clean(controller);
    }

    private static void pauseCancelsCurrentAndFadingPlayers() {
        GameSoundController controller = controller();
        controller.play(R.raw.main_theme_0, false, true, false);
        controller.play(R.raw.main_theme_1, true, true, false);
        controller.play(R.raw.drum1, false, false, false);
        controller.play(R.raw.correct_answer, true, false, false);
        check(MediaPlayer.liveCount() == 4, "Both channels have an outgoing/current pair");
        Handler.advanceBy(50);
        clean(controller);
    }

    private static void muteCancelsOutgoingEffectAndRetainsGain() {
        GameSoundController controller = controller();
        controller.play(R.raw.correct_answer, false, false, false);
        MediaPlayer outgoing = MediaPlayer.latest();
        controller.play(R.raw.drum1, true, false, false);
        MediaPlayer drum = MediaPlayer.latest();
        controller.setCurrentEffectVolume(0f);
        check(outgoing.released, "Muting releases an outgoing effect immediately");
        close(drum.volume(), 0f, "Current effect is muted");
        controller.setCurrentEffectVolume(1f);
        close(drum.volume(), 0.60f, "Unmuting retains the restored drum's balanced gain");
        Handler.advanceBy(1000);
        check(!drum.released, "Canceled old fade cannot release the current effect");
        clean(controller);
    }

    private static void musicPreferenceDoesNotCutEffects() {
        GameSoundController controller = controller();
        controller.play(R.raw.main_theme_0, false, true, false);
        MediaPlayer firstMusic = MediaPlayer.latest();
        controller.play(R.raw.main_theme_1, true, true, false);
        MediaPlayer nextMusic = MediaPlayer.latest();
        controller.play(R.raw.drum1, false, false, false);
        MediaPlayer effect = MediaPlayer.latest();
        AppPrefs.musicEnabled = false;
        controller.play(R.raw.main_theme_0, true, true, false);
        check(firstMusic.released && nextMusic.released, "Disabled music cancels all beds and fades");
        check(!effect.released && effect.playing, "Music preference must leave effects playing");
        controller.stopCurrentMusicIfDisabled(false);
        check(!effect.released, "Applying music preference also preserves effects");
        clean(controller);
    }

    private static void effectFadeRespectsCurrentChannelLevel() {
        GameSoundController controller = controller();
        controller.setCurrentEffectVolume(0.4f);
        controller.play(R.raw.drum1, false, false, false);
        MediaPlayer outgoing = MediaPlayer.latest();
        close(outgoing.volume(), 0.24f, "Channel gain multiplies the recording's balanced gain");
        controller.play(R.raw.correct_answer, true, false, false);
        Handler.advanceBy(175);
        close(outgoing.volume(), 0.12f, "Half-fade starts from the audible channel level");
        close(MediaPlayer.latest().volume(), 0.4f, "Incoming feedback inherits the current channel level");
        clean(controller);
    }

    private static void completionAndErrorsCancelFadeSafely() {
        GameSoundController controller = controller();
        controller.play(R.raw.correct_answer, false, false, false);
        MediaPlayer outgoing = MediaPlayer.latest();
        controller.play(R.raw.drum1, true, false, false);
        MediaPlayer current = MediaPlayer.latest();
        outgoing.complete();
        Handler.advanceBy(1000);
        check(outgoing.releases == 1, "Natural completion cancels its delayed fade");
        check(!current.released, "Old completion cannot release a newer player");
        current.fail();
        check(current.releases == 1, "Player errors release resources");
        clean(controller);
    }

    private static void openingTransitionSharesMusicChannel() {
        GameSoundController controller = controller();
        controller.play(R.raw.lets_play, false, false, false);
        MediaPlayer opening = MediaPlayer.latest();
        controller.play(R.raw.main_theme_0, true, true, false);
        controller.play(R.raw.correct_answer, false, false, false);
        MediaPlayer effect = MediaPlayer.latest();
        Handler.advanceBy(350);
        check(opening.released, "Question music fades the opening orchestral transition");
        check(!effect.released, "Answer feedback remains on the effects channel");
        AppPrefs.musicEnabled = false;
        int created = MediaPlayer.CREATED.size();
        controller.play(R.raw.lets_play, true, false, false);
        check(MediaPlayer.CREATED.size() == created, "Music preference covers the opening transition");
        check(effect.playing, "Disabling an opening cue must preserve answer feedback");
        clean(controller);
    }

    private static void rapidTransitionsDoNotAccumulate() {
        GameSoundController controller = controller();
        for (int i = 0; i < 20; i++) {
            controller.play(i % 2 == 0 ? R.raw.main_theme_0 : R.raw.main_theme_1, true, true, false);
            check(MediaPlayer.liveCount() <= 2, "Rapid music transitions cannot accumulate old players");
            Handler.advanceBy(5);
        }
        controller.stopCurrentEffect();
        check(MediaPlayer.latest().playing, "Stopping effects does not stop music");
        clean(controller);
    }

    private static void blockedPlaybackAndCreateFailureAreSafe() {
        GameSoundController controller = controller();
        controller.play(R.raw.main_theme_0, true, true, true);
        check(MediaPlayer.CREATED.isEmpty(), "Exiting/paused activities cannot create audio");
        AppPrefs.soundEnabled = false;
        controller.play(R.raw.drum1, false, false, false);
        check(MediaPlayer.CREATED.isEmpty(), "Disabled effects cannot create audio");
        AppPrefs.soundEnabled = true;
        MediaPlayer.failNextCreation = true;
        controller.play(R.raw.drum1, false, false, false);
        check(MediaPlayer.CREATED.isEmpty(), "Missing/failed media creation remains safe");
        controller.play(R.raw.drum1, false, false, false);
        check(MediaPlayer.latest().playing, "A creation failure cannot break later playback");
        clean(controller);
    }
}
