package com.qi7bali.landchallengeonline;

import com.google.firebase.database.DataSnapshot;
import com.google.firebase.database.DatabaseError;

public interface OnReadFirebaseListener {
    void onStart();
    void onSuccess(DataSnapshot snapshot);
    void onFailed(DatabaseError error);
}
