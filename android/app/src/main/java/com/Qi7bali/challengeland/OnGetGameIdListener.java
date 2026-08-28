package com.qi7bali.landchallengeonline;

import com.google.firebase.database.DatabaseError;

public interface OnGetGameIdListener {
    void onSuccess(String gameID);
    void onFailed(DatabaseError error);
}
