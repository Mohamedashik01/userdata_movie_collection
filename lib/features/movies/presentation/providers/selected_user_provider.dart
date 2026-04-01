import 'package:flutter_riverpod/flutter_riverpod.dart';

// This provider stores the internal database ID of the user currently "active" for bookmarking
final selectedUserProvider = StateProvider<int?>((ref) => null);
