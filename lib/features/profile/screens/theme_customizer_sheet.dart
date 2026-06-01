// Legacy Profile sheet. Active appearance controls live in AppPreferencesScreen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/widgets/liquid_glass_panel.dart';

import 'package:optivus/features/profile/screens/profile_sheet_helper.dart';

void showThemeCustomizerSheet(BuildContext context, WidgetRef ref) {
  showCustomBottomSheet(
    context: context,
    title: 'Aesthetics Studio',
    subtitle: 'Glassblur & Theme Matrix',
    child: StatefulBuilder(
      builder: (context, setState) {
        double glassOpacity = 50.0; // Percentage
        String selectedGradient = 'Midnight Aqua';
        bool highContrast = false;

        final gradientThemes = [
          {
            'name': 'Midnight Aqua',
            'colors': [const Color(0xFF0F2027), const Color(0xFF203A43)],
          },
          {
            'name': 'Sunrise Gold',
            'colors': [const Color(0xFFF7971E), const Color(0xFFFFD200)],
          },
          {
            'name': 'Electric Lavender',
            'colors': [const Color(0xFF4A00E0), const Color(0xFF8E2DE2)],
          },
          {
            'name': 'Hyper Cyber',
            'colors': [const Color(0xFF1F1C2C), const Color(0xFF928DAB)],
          },
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'GLASSMORPHISM OPACITY CONFIGS',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            LiquidGlassPanel(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Panel Blur Opacity',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${glassOpacity.toInt()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: OptivusColors.brandAccent,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: glassOpacity,
                    min: 10,
                    max: 100,
                    activeColor: OptivusColors.brandAccent,
                    onChanged: (val) {
                      setState(() => glassOpacity = val);
                    },
                  ),
                  const Text(
                    'Calculates the backdrop filter blur coefficient dynamically.',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: OptivusColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'CURATED BACKGROUND MATRIX',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: OptivusColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gradientThemes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemBuilder: (context, index) {
                final t = gradientThemes[index];
                final name = t['name'] as String;
                final colors = t['colors'] as List<Color>;
                final isSel = name == selectedGradient;

                return InkWell(
                  onTap: () => setState(() => selectedGradient = name),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSel ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: colors[0].withValues(alpha: 0.5),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            LiquidGlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: SwitchListTile.adaptive(
                activeTrackColor: OptivusColors.brandAccent,
                title: const Text(
                  'High Contrast Text Overlay',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: const Text(
                  'Forces dark shadows behind white typography',
                  style: TextStyle(fontSize: 10),
                ),
                value: highContrast,
                onChanged: (val) => setState(() => highContrast = val),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OptivusColors.brandAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Theme Matrix: "$selectedGradient" applied.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Apply Aesthetics Config',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    ),
  );
}
