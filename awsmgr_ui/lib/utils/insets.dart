import 'package:flutter/widgets.dart';

/// [padding] plus the bottom system inset (the gesture bar or navigation
/// bar). A ListView or SingleChildScrollView adds that inset by itself only
/// when it has no padding of its own; scroll views that set one use this so
/// their last item can be scrolled clear of the bar.
EdgeInsets withBottomInset(BuildContext context, EdgeInsets padding) =>
    padding + EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom);
