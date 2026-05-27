import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/class_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/eating_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/fixed_schedule_setup_screen.dart';
import 'package:optivus/features/routine/managers/base_timeline/screens/skin_care_setup_screen.dart';

class BaseTimelineManagerScreen extends ConsumerStatefulWidget {
  const BaseTimelineManagerScreen({super.key});

  @override
  ConsumerState<BaseTimelineManagerScreen> createState() => _BaseTimelineManagerScreenState();
}

class _BaseTimelineManagerScreenState extends ConsumerState<BaseTimelineManagerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Base Timeline Manager',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: OptivusColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: OptivusColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: OptivusColors.routineAccent,
          unselectedLabelColor: OptivusColors.textSecondary,
          indicatorColor: OptivusColors.routineAccent,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: const [
            Tab(text: 'Classes'),
            Tab(text: 'Job/Work'),
            Tab(text: 'Eating'),
            Tab(text: 'Fixed'),
            Tab(text: 'Skin Care'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Prevent swipe interference with draggable timeline blocks
        children: [
          ClassSetupScreen(onComplete: () {}),
          FixedScheduleSetupScreen(onComplete: () {}), // Reuse fixed for job/work
          EatingSetupScreen(onComplete: () {}),
          FixedScheduleSetupScreen(onComplete: () {}),
          SkinCareSetupScreen(onComplete: () {}),
        ],
      ),
    );
  }
}
