package com.qi7bali.landchallengeonline;

import android.app.Activity;
import android.app.Dialog;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.CountDownTimer;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;

import com.squareup.picasso.Callback;
import com.squareup.picasso.Picasso;

public class ImageObservationController {

    public interface OnObservationFinishedListener {
        void onFinished();
    }

    private Dialog activeDialog;
    private CountDownTimer observationTimer;

    public void showObservationImage(final Activity activity, final String imageUrl, final OnObservationFinishedListener listener) {
        if (activity == null || activity.isFinishing() || imageUrl == null || imageUrl.trim().isEmpty()) {
            if (listener != null) listener.onFinished();
            return;
        }

        activity.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    dismiss();
                    activeDialog = new Dialog(activity);
                    activeDialog.requestWindowFeature(Window.FEATURE_NO_TITLE);
                    View view = LayoutInflater.from(activity).inflate(R.layout.dialog_image_observation, null);
                    activeDialog.setContentView(view);
                    activeDialog.setCancelable(false);
                    activeDialog.setCanceledOnTouchOutside(false);

                    if (activeDialog.getWindow() != null) {
                        activeDialog.getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
                        int width = (int) (activity.getResources().getDisplayMetrics().widthPixels * 0.94);
                        activeDialog.getWindow().setLayout(width, ViewGroup.LayoutParams.WRAP_CONTENT);
                    }

                    final TextView txtTimer = view.findViewById(R.id.txtObservationTimer);
                    final ProgressBar pbLoading = view.findViewById(R.id.pbObservationLoading);
                    final ImageView imgView = view.findViewById(R.id.imgObservation);

                    pbLoading.setVisibility(View.VISIBLE);
                    imgView.setVisibility(View.GONE);
                    txtTimer.setText("تحميل الصورة..");

                    activeDialog.show();

                    Picasso.with(activity)
                            .load(imageUrl)
                            .into(imgView, new Callback() {
                                @Override
                                public void onSuccess() {
                                    if (activity.isFinishing() || activeDialog == null || !activeDialog.isShowing()) return;
                                    pbLoading.setVisibility(View.GONE);
                                    imgView.setVisibility(View.VISIBLE);

                                    // Start 5-second countdown only after image is successfully rendered
                                    observationTimer = new CountDownTimer(5000, 1000) {
                                        @Override
                                        public void onTick(long millisUntilFinished) {
                                            int sec = (int) Math.ceil(millisUntilFinished / 1000.0);
                                            txtTimer.setText(sec + " ثوانٍ");
                                        }

                                        @Override
                                        public void onFinish() {
                                            dismiss();
                                            if (listener != null) {
                                                listener.onFinished();
                                            }
                                        }
                                    }.start();
                                }

                                @Override
                                public void onError() {
                                    dismiss();
                                    if (listener != null) {
                                        listener.onFinished();
                                    }
                                }
                            });

                } catch (Exception e) {
                    dismiss();
                    if (listener != null) listener.onFinished();
                }
            }
        });
    }

    public boolean isShowing() {
        return activeDialog != null && activeDialog.isShowing();
    }

    public void dismiss() {
        if (observationTimer != null) {
            observationTimer.cancel();
            observationTimer = null;
        }
        if (activeDialog != null && activeDialog.isShowing()) {
            try {
                activeDialog.dismiss();
            } catch (Exception ignored) {}
            activeDialog = null;
        }
    }
}
