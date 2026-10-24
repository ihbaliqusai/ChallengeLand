package com.qi7bali.landchallengeonline;

public class EliminationGameActivity extends BaseGameActivity {
    @Override
    protected int getLayoutResId() {
        return R.layout.activity_game_elimination;
    }

    @Override
    protected String getMatchModeId() {
        return "elimination";
    }

    @Override
    protected boolean usesEliminationRoundFlow() {
        return true;
    }
}
