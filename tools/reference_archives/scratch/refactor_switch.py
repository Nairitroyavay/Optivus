import sys

file_path = '/Users/roy/optivus2/Optivus/lib/features/home/widgets/mind_switch_sheet.dart'
with open(file_path, 'r') as f:
    content = f.read()

if "import 'home_glass_widgets.dart';" not in content:
    content = content.replace("import 'package:optivus/app/app_navigation_controller.dart';", 
                              "import 'package:optivus/app/app_navigation_controller.dart';\nimport 'home_glass_widgets.dart';")

step1_old = """        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.brandAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: _nextStep,
          child: const Text(
            'Yes, capture it',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),"""

step1_new = """        HomeActionPill(
          label: 'Yes, capture it',
          selected: true,
          onTap: _nextStep,
        ),"""

step3_old = """        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.brandAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: _nextStep,
          child: const Text(
            'Next',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),"""

step3_new = """        HomeActionPill(
          label: 'Next',
          selected: true,
          onTap: _nextStep,
        ),"""

step4_old = """        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: OptivusColors.brandAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: () => _save(false),
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.6),
            foregroundColor: OptivusColors.brandAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: () => _save(true),
          child: const Text(
            'Send to Coach',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _save(false),
          child: const Text(
            'Return to Focus',
            style: TextStyle(color: OptivusColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Making Action Plan... (Mock)')),
            );
          },
          child: const Text(
            'Make Action Plan',
            style: TextStyle(color: OptivusColors.textSecondary),
          ),
        ),"""

step4_new = """        Row(
          children: [
            Expanded(
              child: HomeActionPill(
                label: 'Save',
                selected: true,
                onTap: () => _save(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HomeActionPill(
                label: 'Send to Coach',
                onTap: () => _save(true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HomeActionPill(
                label: 'Return to Focus',
                compact: true,
                onTap: () => _save(false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HomeActionPill(
                label: 'Make Action Plan',
                compact: true,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Making Action Plan... (Mock)')),
                  );
                },
              ),
            ),
          ],
        ),"""

content = content.replace(step1_old, step1_new)
content = content.replace(step3_old, step3_new)
content = content.replace(step4_old, step4_new)

with open(file_path, 'w') as f:
    f.write(content)
