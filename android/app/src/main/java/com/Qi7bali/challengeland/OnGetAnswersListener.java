package com.qi7bali.landchallengeonline;

import com.google.firebase.database.DatabaseError;

public interface OnGetAnswersListener {
    void onStart();
    void onSuccess(Long answer);
    void onFailed(DatabaseError error);
}
