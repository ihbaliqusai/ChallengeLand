package com.qi7bali.landchallengeonline;

import com.google.firebase.database.DatabaseError;

public interface OnRandomRequestListener {
    void onStart();
    void onSuccess(String idOpponent);
    void onFailed(DatabaseError error);
}
