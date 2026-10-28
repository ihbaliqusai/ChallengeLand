import 'package:flutter/material.dart';

import '../../core/third_party_licenses.dart';

void showOpenSourceLicenses(BuildContext context) {
  ThirdPartyLicenses.register();
  showLicensePage(
    context: context,
    applicationName: 'أرض التحدي · ChallengeLand',
  );
}
