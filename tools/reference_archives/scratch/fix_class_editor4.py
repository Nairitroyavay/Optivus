filepath = 'lib/features/onboarding/steps/base_timeline_editors/class_timeline_editor.dart'
with open(filepath, 'r') as f:
    content = f.read()

content = content.replace("ref.read(appFeatureFlagsProvider).classTimetableImageImportReady", "false")
content = content.replace("ref.watch(appFeatureFlagsProvider).classTimetableImageImportReady", "false")
content = content.replace("ref.read(appFeatureFlagsProvider).textParseImportReady", "false")
content = content.replace("ref.watch(appFeatureFlagsProvider).textParseImportReady", "false")

content = content.replace("ref.read(routineRepositoryProvider).previewRoutineImport(", "throw UnimplementedError(")
content = content.replace("ref.read(eventServiceProvider).emit(", "print(")
content = content.replace("ref.read(firestoreServiceProvider).saveSuggestion(", "print(")

content = content.replace("ImageSource.gallery", "null")
content = content.replace("ImageSource.camera", "null")
content = content.replace("_imageUploadService", "null")
content = content.replace("runRoutineAcceptWithTimeout", "null")
content = content.replace("RoutineAcceptTimeoutException", "Exception")

with open(filepath, 'w') as f:
    f.write(content)
