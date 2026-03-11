import 'package:flutter/widgets.dart';

/// Shared route observer to notify pages when navigating back to them.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
