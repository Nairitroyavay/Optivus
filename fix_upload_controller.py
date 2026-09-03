import re

with open('lib/state/upload_state.dart', 'r') as f:
    content = f.read()

# In startUpload finally
content = re.sub(
    r'if \(_isCurrentOperation\(uid, operationGeneration\) && state\.isBusy\) \{',
    r'if (_operationGeneration == operationGeneration && state.isBusy) {',
    content
)

with open('lib/state/upload_state.dart', 'w') as f:
    f.write(content)
