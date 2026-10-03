# AdMob support draft: HTTP 403 for ChallengeLand

> Historical, unsent draft for the original units. After this investigation, the user supplied third-party partner-bidding implementation instructions for the old interstitial unit. The app uses direct AdMob requests. The user then supplied replacement units: rewarded `ca-app-pub-2427194500639575/9695234568` and interstitial `ca-app-pub-2427194500639575/4367895424`. Both are now in Flutter and native Android resources. Both replacement units successfully loaded in Flutter on the registered test phone, and the native Android rewarded loader also reported successful AdMob Network responses for the new rewarded ID. This confirms test-mode loading, not live serving in a Play-installed build. Do not submit the old failure below as a failure of the replacement units. See `ADS_TROUBLESHOOTING_AR.md` for current results.

My Android app is verified and its ad serving status is Ready in AdMob. Both its rewarded and interstitial ad requests fail with the following SDK error:

```text
Code: 3
Domain: com.google.android.gms.ads
Message: Received error HTTP response code: 403
Response ID: null
Mediation Adapter Class Name: ""
Adapter Responses: []
```

App details:

- AdMob app ID: `ca-app-pub-2427194500639575~2139217713`
- Android package: `com.qi7bali.landchallengeonline`
- Play listing: https://play.google.com/store/apps/details?id=com.qi7bali.landchallengeonline
- Rewarded unit: `ca-app-pub-2427194500639575/8907631037`
- Interstitial unit: `ca-app-pub-2427194500639575/5886891033`
- Google Mobile Ads SDK: `23.6.0`
- Flutter plugin: `google_mobile_ads 5.3.1`
- Tested app version: `3.6.4` / version code `32`, local debug build on Pixel Fold
- Reproduction date: October 3, 2026

The error was reproduced for both formats using our own ad units after registering the phone as a test device programmatically. The SDK confirmed that the requests were sent from a test device. Ad Inspector opened successfully and displayed the correct app ID; both requested units appeared as Unknown and No Fill.

Control test: on the same phone and using the same Flutter ad loading service and AdMob app ID, both Google's demo rewarded unit (`ca-app-pub-3940256099942544/5224354917`) and demo interstitial unit (`ca-app-pub-3940256099942544/1033173712`) loaded successfully. No ads were shown during this control test. Our production units still returned HTTP 403 when the phone was registered as a test device.

The app's AdMob app ID, package and both unit IDs were checked against the dashboard screenshots and the local code. The developer website's app-ads.txt returned HTTP 200 with the matching publisher record. The Policy Center screenshot did not list this app among the affected apps. Another app in the same publisher account has recent ad requests, impressions and revenue.

Separately, UMP reported that no forms are configured for this app ID. Ad requests were still made in the observed test session. We are reviewing that configuration independently and have not established it as the cause of HTTP 403.

Could you identify why these requests are rejected with HTTP 403 and any app-specific serving or configuration issue that needs to be resolved?

The failed rewarded request was exported locally from Ad Inspector to `.dart_tool/ad_diagnostics/rewarded-request.txt`. Its URL targets `googleads.g.doubleclick.net/mads/gma`, and the decoded request includes the expected publisher (`client`), package (`msid`), rewarded unit suffix (`slotname=8907631037`), app suffix (`app_code=2139217713`), and `adtest=on`.

Before submitting: attach that exported request file and `.dart_tool/ad_diagnostics/production-unit-test-log.txt`. These local diagnostic artifacts are outside version control. The debug results above have not independently been reproduced on a Play-installed build. This is an unsent draft.
