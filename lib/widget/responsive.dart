import 'package:flutter/material.dart';

/// Width below which layouts switch from a table to a stacked/accordion view.
const double kMobileBreakpoint = 600;

bool isMobile(double width) => width < kMobileBreakpoint;

bool isMobileContext(BuildContext context) =>
    isMobile(MediaQuery.sizeOf(context).width);
