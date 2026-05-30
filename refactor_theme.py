import os
import glob

def refactor_files(directory):
    replacements = {
        "import 'package:optivus/core/liquid_ui/liquid_ui.dart';\n": "",
        "kInk": "OptivusColors.ink",
        "kSub": "OptivusColors.sub",
        "kRose": "OptivusColors.roseAccent",
        "kPurple": "OptivusColors.purpleAccent",
        "kMint": "OptivusColors.mintAccent",
        "kAmber": "OptivusColors.brandAccent",
        "kBlue": "OptivusColors.blueAccent",
        "kGreen": "OptivusColors.success", # Fallback if any
        "kRed": "OptivusColors.danger", # Fallback if any
        "TrackerGlassCard": "TrackerGlassCard", # just in case
    }
    
    # Also find files importing liquid_ui and replace constants
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".dart"):
                file_path = os.path.join(root, file)
                with open(file_path, "r") as f:
                    content = f.read()
                
                new_content = content
                for old, new in replacements.items():
                    # for constants, match as word boundary if needed, but in dart they are usually followed by , or space or )
                    # a simple string replace might work but could replace part of a word.
                    # let's be safe and use regex for the constants.
                    pass
                
                import re
                
                # replace imports safely
                new_content = new_content.replace("import 'package:optivus/core/liquid_ui/liquid_ui.dart';\n", "")
                
                # word boundary replacements for constants
                consts_to_replace = {
                    "kInk": "OptivusColors.ink",
                    "kSub": "OptivusColors.sub",
                    "kRose": "OptivusColors.roseAccent",
                    "kPurple": "OptivusColors.purpleAccent",
                    "kMint": "OptivusColors.mintAccent",
                    "kAmber": "OptivusColors.brandAccent",
                    "kBlue": "OptivusColors.blueAccent",
                    "kGreen": "OptivusColors.success",
                    "kRed": "OptivusColors.danger",
                }
                
                for old, new in consts_to_replace.items():
                    new_content = re.sub(rf'\b{old}\b', new, new_content)
                
                if new_content != content:
                    with open(file_path, "w") as f:
                        f.write(new_content)
                    print(f"Updated {file_path}")

if __name__ == '__main__':
    refactor_files('lib/')
