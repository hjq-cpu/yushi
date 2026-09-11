import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'data/local_repository.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AppController(LocalRepository());
  await controller.initialize();
  runApp(YushiApp(controller: controller));
}
