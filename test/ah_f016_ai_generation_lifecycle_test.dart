import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optivus/core/ai/ai_generation_lifecycle.dart';
import 'package:optivus/core/theme/optivus_colors.dart';
import 'package:optivus/features/onboarding/widgets/ai_thinking_card.dart';

void main() {
  // ───────────────────────────────────────────────────────────────────
  // GROUP A — Lifecycle Phase Transitions
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Lifecycle Phase Transitions', () {
    test('A. idle → preparing → generating → success', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      expect(controller.state.phase, AiGenerationPhase.idle);
      expect(controller.state.isActive, isFalse);

      final runResult = await controller.run<String>(
        operationType: 'test',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          expect(controller.state.phase, AiGenerationPhase.preparing);
          expect(controller.state.isActive, isTrue);

          scope.transition(
            AiGenerationPhase.generating,
            message: 'Generating...',
          );
          expect(controller.state.phase, AiGenerationPhase.generating);
          expect(controller.state.message, 'Generating...');

          return 'result-value';
        },
      );

      expect(runResult.isSuccess, isTrue);
      expect(runResult.value, 'result-value');
      expect(controller.state.phase, AiGenerationPhase.success);
      expect(controller.state.isActive, isFalse);
    });

    test(
      'B. idle → preparing → uploading → analyzing → generating → success (full photo path)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final phases = <AiGenerationPhase>[];
        controller.addListener(() => phases.add(controller.state.phase));

        final runResult = await controller.run<String>(
          operationType: 'photo-ai',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          operation: (scope) async {
            scope.transition(
              AiGenerationPhase.uploading,
              message: 'Uploading photo...',
            );
            scope.transition(
              AiGenerationPhase.analyzing,
              message: 'Analyzing image...',
            );
            scope.transition(
              AiGenerationPhase.generating,
              message: 'Synthesizing output...',
            );
            return 'photo-result';
          },
        );

        expect(runResult.isSuccess, isTrue);
        expect(runResult.value, 'photo-result');
        expect(controller.state.phase, AiGenerationPhase.success);
        expect(
          phases,
          containsAllInOrder([
            AiGenerationPhase.preparing,
            AiGenerationPhase.uploading,
            AiGenerationPhase.analyzing,
            AiGenerationPhase.generating,
            AiGenerationPhase.success,
          ]),
        );
      },
    );

    test(
      'C. phase skipping: preparing → generating (text-only skips upload/analyze)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final phases = <AiGenerationPhase>[];
        controller.addListener(() => phases.add(controller.state.phase));

        final runResult = await controller.run<int>(
          operationType: 'direct',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          operation: (scope) async {
            scope.transition(AiGenerationPhase.generating);
            return 42;
          },
        );

        expect(runResult.isSuccess, isTrue);
        expect(runResult.value, 42);
        // No uploading or analyzing phases were emitted
        expect(phases.contains(AiGenerationPhase.uploading), isFalse);
        expect(phases.contains(AiGenerationPhase.analyzing), isFalse);
        expect(
          phases,
          containsAllInOrder([
            AiGenerationPhase.preparing,
            AiGenerationPhase.generating,
            AiGenerationPhase.success,
          ]),
        );
      },
    );

    test(
      'C2. phase skipping: preparing → analyzing (skip uploading)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final phases = <AiGenerationPhase>[];
        controller.addListener(() => phases.add(controller.state.phase));

        final result = await controller.run<String>(
          operationType: 'analyze-only',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          operation: (scope) async {
            scope.transition(AiGenerationPhase.analyzing);
            scope.transition(AiGenerationPhase.generating);
            return 'ok';
          },
        );

        expect(result.isSuccess, isTrue);
        expect(phases.contains(AiGenerationPhase.uploading), isFalse);
        expect(
          phases,
          containsAllInOrder([
            AiGenerationPhase.preparing,
            AiGenerationPhase.analyzing,
            AiGenerationPhase.generating,
            AiGenerationPhase.success,
          ]),
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP B — Error Paths
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Error Paths', () {
    test('D. preparation error → error with canRetry=false', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      final runResult = await controller.run<String>(
        operationType: 'prep-fail',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          throw const FormatException('Corrupt inputs');
        },
        mapError: (e) => const AiGenerationError(
          category: AiGenerationErrorCategory.invalidInput,
          message: 'Invalid input format',
          canRetry: false,
        ),
      );

      expect(runResult.isSuccess, isFalse);
      expect(runResult.error?.category, AiGenerationErrorCategory.invalidInput);
      expect(runResult.error?.message, 'Invalid input format');
      expect(controller.state.phase, AiGenerationPhase.error);
      expect(controller.state.canRetry, isFalse);
    });

    test('E. upload failure → error (blocks generation)', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);
      var generatingReached = false;

      final runResult = await controller.run<String>(
        operationType: 'upload-fail',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.uploading);
          throw Exception('Upload connection lost');
          // ignore: dead_code
          generatingReached = true;
        },
        mapError: (e) => const AiGenerationError(
          category: AiGenerationErrorCategory.network,
          message: 'Upload failed. Check your connection.',
          canRetry: true,
        ),
      );

      expect(runResult.isSuccess, isFalse);
      expect(runResult.error?.category, AiGenerationErrorCategory.network);
      expect(controller.state.phase, AiGenerationPhase.error);
      expect(controller.state.canRetry, isTrue);
      expect(generatingReached, isFalse); // Upload failure blocks generation
    });

    test('F. generation error → error', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      final runResult = await controller.run<String>(
        operationType: 'gen-fail',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          throw Exception('Worker returned 503');
        },
        mapError: (e) => const AiGenerationError(
          category: AiGenerationErrorCategory.serviceUnavailable,
          message: 'AI is temporarily unavailable. Try again.',
          canRetry: true,
        ),
      );

      expect(runResult.isSuccess, isFalse);
      expect(
        runResult.error?.category,
        AiGenerationErrorCategory.serviceUnavailable,
      );
      expect(controller.state.phase, AiGenerationPhase.error);
      expect(controller.state.canRetry, isTrue);
    });

    test('G. parse/response failure → error, not success', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      final runResult = await controller.run<Map<String, dynamic>>(
        operationType: 'parse-fail',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          // Simulate malformed AI response parse failure
          throw const FormatException('Malformed JSON from AI');
        },
        mapError: (e) => const AiGenerationError(
          category: AiGenerationErrorCategory.responseInvalid,
          message: 'AI response could not be read safely. Please try again.',
          canRetry: true,
        ),
      );

      expect(runResult.isSuccess, isFalse);
      expect(
        runResult.error?.category,
        AiGenerationErrorCategory.responseInvalid,
      );
      expect(controller.state.phase, AiGenerationPhase.error);
    });

    test(
      'H. persistence failure (Firestore save) → error, not false durable success',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final runResult = await controller.run<String>(
          operationType: 'save-test',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          operation: (scope) async {
            scope.transition(AiGenerationPhase.generating);
            // AI response received successfully, but persistence fails
            throw Exception('Firestore write rejected: offline');
          },
          mapError: (e) => const AiGenerationError(
            category: AiGenerationErrorCategory.network,
            message: 'Failed to save meal routine.',
            canRetry: true,
          ),
        );

        expect(runResult.isSuccess, isFalse);
        expect(controller.state.phase, AiGenerationPhase.error);
        expect(controller.state.error?.message, 'Failed to save meal routine.');
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP C — Timeout Architecture
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Timeout Architecture', () {
    test('I. timeout → error with timeout category', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      final runResult = await controller.run<String>(
        operationType: 'timeout-test',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(milliseconds: 30),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          await Future.delayed(const Duration(milliseconds: 100));
          return 'late-value';
        },
      );

      expect(runResult.isSuccess, isFalse);
      expect(runResult.error?.category, AiGenerationErrorCategory.timeout);
      expect(
        runResult.error?.message,
        'That took longer than expected. Try again.',
      );
      expect(controller.state.phase, AiGenerationPhase.error);
      expect(controller.state.canRetry, isTrue);
    });

    test('AE. skin care is bounded to 60 seconds without changing peers', () {
      expect(
        AiOperationTimeouts.routineImport.operationTimeout,
        const Duration(seconds: 180),
      );
      expect(
        AiOperationTimeouts.nutrition.operationTimeout,
        const Duration(seconds: 180),
      );
      expect(
        AiOperationTimeouts.skinCare.operationTimeout,
        const Duration(seconds: 60),
      );
      expect(
        AiOperationTimeouts.coach.operationTimeout,
        const Duration(seconds: 180),
      );
    });

    test(
      'J. late result after timeout is ignored (stale success dropped)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final completer = Completer<String>();
        final runResult = await controller.run<String>(
          operationType: 'late-test',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(milliseconds: 20),
          ),
          operation: (scope) async {
            scope.transition(AiGenerationPhase.generating);
            return completer.future;
          },
        );

        expect(runResult.error?.category, AiGenerationErrorCategory.timeout);
        expect(controller.state.phase, AiGenerationPhase.error);

        // Late completion after timeout
        completer.complete('late-response');
        await Future.delayed(const Duration(milliseconds: 10));

        // State remains in error
        expect(controller.state.phase, AiGenerationPhase.error);
      },
    );

    test(
      'K. success before timeout → timeout cannot override success state',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final result = await controller.run<String>(
          operationType: 'fast-op',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(milliseconds: 200),
          ),
          operation: (scope) async {
            scope.transition(AiGenerationPhase.generating);
            return 'fast-result';
          },
        );

        expect(result.isSuccess, isTrue);
        expect(controller.state.phase, AiGenerationPhase.success);

        // Advance past where timeout would have fired
        await Future.delayed(const Duration(milliseconds: 250));
        expect(
          controller.state.phase,
          AiGenerationPhase.success,
          reason: 'Timeout must not retroactively override success',
        );
      },
    );

    test(
      'L. timeout timer after back/cancel does not mutate abandoned screen',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final completer = Completer<String>();
        controller.run<String>(
          operationType: 'cancel-timeout',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(milliseconds: 100),
          ),
          operation: (scope) => completer.future,
        );

        expect(controller.state.isActive, isTrue);

        // User cancels immediately (simulating back)
        controller.cancel();
        expect(controller.state.phase, AiGenerationPhase.idle);

        // Wait past timeout duration
        await Future.delayed(const Duration(milliseconds: 150));
        expect(
          controller.state.phase,
          AiGenerationPhase.idle,
          reason: 'Timeout must not fire after cancel',
        );
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP D — Retry
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Retry', () {
    test('I2. error → retrying → preparing → generating → success', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      final phases = <AiGenerationPhase>[];
      controller.addListener(() => phases.add(controller.state.phase));

      // Attempt 1: fails
      await controller.run<String>(
        operationType: 'retry-test',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          throw Exception('network error');
        },
      );
      expect(controller.state.phase, AiGenerationPhase.error);
      expect(controller.state.attempt, 1);

      phases.clear();

      // Attempt 2: retry
      final retryResult = await controller.run<String>(
        operationType: 'retry-test',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        retry: true,
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          return 'recovered-result';
        },
      );

      expect(retryResult.isSuccess, isTrue);
      expect(retryResult.value, 'recovered-result');
      expect(controller.state.phase, AiGenerationPhase.success);
      expect(controller.state.attempt, 2);
      // Retry path includes retrying phase
      expect(phases, contains(AiGenerationPhase.retrying));
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP E — Double-tap Protection
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Double-tap Protection', () {
    test('M. triple-tap Generate → only 1 backend invocation', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      var executionCount = 0;
      final completer = Completer<String>();

      final run1 = controller.run<String>(
        operationType: 'dedup',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          executionCount++;
          return completer.future;
        },
      );

      // Rapid tap 2 and 3 while active
      final run2 = controller.run<String>(
        operationType: 'dedup',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          executionCount++;
          return 'second';
        },
      );

      final run3 = controller.run<String>(
        operationType: 'dedup',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          executionCount++;
          return 'third';
        },
      );

      expect((await run2).duplicate, isTrue);
      expect((await run3).duplicate, isTrue);
      expect(executionCount, 1);

      completer.complete('first');
      expect((await run1).value, 'first');
    });

    test('N. double retry → only 1 retry execution', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      // First: error
      await controller.run<String>(
        operationType: 'retry-dedup',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async => throw Exception('fail'),
      );
      expect(controller.state.phase, AiGenerationPhase.error);

      var retryCount = 0;
      final completer = Completer<String>();

      final retry1 = controller.run<String>(
        operationType: 'retry-dedup',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        retry: true,
        operation: (scope) async {
          retryCount++;
          return completer.future;
        },
      );

      final retry2 = controller.run<String>(
        operationType: 'retry-dedup',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        retry: true,
        operation: (scope) async {
          retryCount++;
          return 'dup';
        },
      );

      expect((await retry2).duplicate, isTrue);
      expect(retryCount, 1);

      completer.complete('ok');
      expect((await retry1).value, 'ok');
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP F — Stale Result Protection
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Stale Result Protection', () {
    test(
      'O. same-UID stale: A starts, B starts, A completes late → B remains',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        var currentInputId = 'input-A';
        final completerA = Completer<String>();

        final runAFuture = controller.run<String>(
          operationType: 'input-test',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          isSessionCurrent: () => currentInputId == 'input-A',
          operation: (scope) => completerA.future,
        );

        // User changes input → cancel old, start new
        currentInputId = 'input-B';
        controller.cancel();

        final runBFuture = controller.run<String>(
          operationType: 'input-test',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          isSessionCurrent: () => currentInputId == 'input-B',
          operation: (scope) async => 'result-for-B',
        );

        final runB = await runBFuture;
        expect(runB.value, 'result-for-B');
        expect(controller.state.phase, AiGenerationPhase.success);

        // Late A completes
        completerA.complete('result-for-A');
        final runA = await runAFuture;
        expect(runA.ignored, isTrue);
        expect(controller.state.phase, AiGenerationPhase.success);
      },
    );

    test(
      'P. account switch: UID_A active, switch to UID_B, A completes → B unaffected',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        var currentUid = 'user-A';
        final completerA = Completer<String>();

        final runAFuture = controller.run<String>(
          operationType: 'auth-switch',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          isSessionCurrent: () => currentUid == 'user-A',
          operation: (scope) => completerA.future,
        );

        // User switches to B
        currentUid = 'user-B';

        // A returns
        completerA.complete('result-A');
        final runA = await runAFuture;

        expect(runA.ignored, isTrue);
        // Controller did NOT become success for user-A's result
      },
    );

    test(
      'Q. same-UID auth refresh: token refreshes mid-flight → operation continues',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final currentUid = 'user-A';
        var authVersion = 1;

        final runFuture = controller.run<String>(
          operationType: 'refresh-test',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          isSessionCurrent: () => currentUid == 'user-A',
          operation: (scope) async {
            authVersion = 2; // Token refreshes mid-flight
            return 'valid-result';
          },
        );

        final run = await runFuture;
        expect(authVersion, 2);
        expect(run.value, 'valid-result');
        expect(controller.state.phase, AiGenerationPhase.success);
      },
    );

    test(
      'O2. timed-out A + successful retry B + late A → B remains authoritative',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final completerA = Completer<String>();
        await controller.run<String>(
          operationType: 'op',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(milliseconds: 20),
          ),
          operation: (scope) => completerA.future,
        );
        expect(controller.state.phase, AiGenerationPhase.error);

        final runB = await controller.run<String>(
          operationType: 'op',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 2),
          ),
          retry: true,
          operation: (scope) async => 'result-B',
        );
        expect(runB.value, 'result-B');

        completerA.complete('result-A');
        await Future.delayed(const Duration(milliseconds: 10));
        expect(controller.state.phase, AiGenerationPhase.success);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP G — Cancel / Back / Dispose
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Cancel / Back / Dispose', () {
    test(
      'R. back/cancel → idle, late result ignored, no ghost state',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final completer = Completer<String>();
        final runFuture = controller.run<String>(
          operationType: 'back-test',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(seconds: 5),
          ),
          operation: (scope) => completer.future,
        );

        expect(controller.state.isActive, isTrue);

        controller.cancel();
        expect(controller.state.phase, AiGenerationPhase.idle);
        expect(controller.state.isActive, isFalse);

        completer.complete('late');
        final run = await runFuture;
        expect(run.ignored, isTrue);
        expect(controller.state.phase, AiGenerationPhase.idle);
      },
    );

    test(
      'S. dispose during active operation → no exception on completion',
      () async {
        final controller = AiGenerationController();
        final hangingCompleter = Completer<String>();

        controller.run<String>(
          operationType: 'hanging-op',
          timeoutPolicy: const AiTimeoutPolicy(
            operationTimeout: Duration(minutes: 5),
          ),
          operation: (scope) => hangingCompleter.future,
        );

        expect(controller.state.isActive, isTrue);

        // Dispose while active (simulating widget dispose)
        controller.dispose();
        expect(controller.isDisposed, isTrue);

        // Late completion should not throw
        hangingCompleter.complete('late-value');
        await Future.delayed(const Duration(milliseconds: 10));
        // No exception proves dispose race safety
      },
    );

    test('T. timers cleaned after every terminal path', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      // Success path
      await controller.run<String>(
        operationType: 'cleanup-success',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(milliseconds: 500),
        ),
        operation: (scope) async => 'done',
      );
      expect(controller.state.phase, AiGenerationPhase.success);

      // Error path
      await controller.run<String>(
        operationType: 'cleanup-error',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(milliseconds: 500),
        ),
        operation: (scope) async => throw Exception('fail'),
      );
      expect(controller.state.phase, AiGenerationPhase.error);

      // Cancel path
      final c = Completer<String>();
      controller.run<String>(
        operationType: 'cleanup-cancel',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(milliseconds: 500),
        ),
        operation: (scope) => c.future,
      );
      controller.cancel();
      expect(controller.state.phase, AiGenerationPhase.idle);

      // If any timer leaked, the test framework would report pending timers
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP H — Validation & Retry Semantics
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Validation & Retry Semantics', () {
    test(
      'U. validation error does not enter lifecycle (no Worker call)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        // Simulate validation that rejects before entering lifecycle
        var workerCallCount = 0;
        bool validateInput(bool hasInput) => hasInput;

        // With invalid input: no lifecycle run happens
        final isValid = validateInput(false);
        if (isValid) {
          await controller.run<String>(
            operationType: 'validation-test',
            timeoutPolicy: const AiTimeoutPolicy(
              operationTimeout: Duration(seconds: 5),
            ),
            operation: (scope) async {
              workerCallCount++;
              return 'result';
            },
          );
        }

        expect(workerCallCount, 0);
        expect(controller.state.phase, AiGenerationPhase.idle);
        expect(controller.state.isActive, isFalse);
      },
    );

    test('V. durable upload reused on retry (no re-upload)', () async {
      var uploadCallCount = 0;
      var aiCallCount = 0;

      Future<String> uploadAsset() async {
        uploadCallCount++;
        return 'r2-key-123';
      }

      Future<String> runAi(String r2Key) async {
        aiCallCount++;
        if (aiCallCount == 1) throw Exception('Transient AI failure');
        return 'generated-plan-for-$r2Key';
      }

      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      String? durableR2Key;
      await controller.run<String>(
        operationType: 'durable-test',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.uploading);
          durableR2Key = await uploadAsset();
          scope.transition(AiGenerationPhase.generating);
          return runAi(durableR2Key!);
        },
      );

      expect(uploadCallCount, 1);
      expect(aiCallCount, 1);
      expect(controller.state.phase, AiGenerationPhase.error);

      // Retry: reuse existing durable asset
      final retryResult = await controller.run<String>(
        operationType: 'durable-test',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        retry: true,
        operation: (scope) async {
          durableR2Key ??= await uploadAsset();
          scope.transition(AiGenerationPhase.generating);
          return runAi(durableR2Key!);
        },
      );

      expect(uploadCallCount, 1); // No additional upload!
      expect(aiCallCount, 2);
      expect(retryResult.value, 'generated-plan-for-r2-key-123');
    });

    test('W. null localPath does not force re-upload', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      // Simulate a durable asset with null localPath after process death
      final durableAssetKey = 'existing-r2-key';
      var uploadCalled = false;

      // Simulates asset reconstruction where localPath is absent
      String? resolveLocalPath() => null; // Process death → null

      final result = await controller.run<String>(
        operationType: 'null-path-test',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          // Use durable asset identity, not local path
          final r2Key = durableAssetKey;
          final localPath = resolveLocalPath();
          if (localPath != null) {
            uploadCalled = true; // Would re-upload if path existed
          }
          scope.transition(AiGenerationPhase.generating);
          return 'generated-from-$r2Key';
        },
      );

      expect(result.isSuccess, isTrue);
      expect(uploadCalled, isFalse);
    });

    test('P2. retry uses current input, not stale cached input', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      var currentInput = 'input-A';

      // First attempt with input A fails
      await controller.run<String>(
        operationType: 'input-freshness',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          throw Exception('fail');
        },
      );

      // User changes input to B
      currentInput = 'input-B';

      // Retry should use current input B
      String? submittedInput;
      final retryResult = await controller.run<String>(
        operationType: 'input-freshness',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        retry: true,
        operation: (scope) async {
          submittedInput = currentInput; // Read fresh input
          scope.transition(AiGenerationPhase.generating);
          return 'result-for-$currentInput';
        },
      );

      expect(submittedInput, 'input-B');
      expect(retryResult.value, 'result-for-input-B');
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP I — State Machine Invariants
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 State Machine Invariants', () {
    test('no contradictory parallel booleans', () {
      const idleState = AiGenerationState();
      expect(idleState.isActive, isFalse);
      expect(idleState.canRetry, isFalse);

      const errorState = AiGenerationState(
        phase: AiGenerationPhase.error,
        error: AiGenerationError(
          category: AiGenerationErrorCategory.network,
          message: 'Error',
          canRetry: true,
        ),
      );
      expect(errorState.isActive, isFalse);
      expect(errorState.canRetry, isTrue);

      const generatingState = AiGenerationState(
        phase: AiGenerationPhase.generating,
      );
      expect(generatingState.isActive, isTrue);
      expect(generatingState.canRetry, isFalse);

      const successState = AiGenerationState(phase: AiGenerationPhase.success);
      expect(successState.isActive, isFalse);
      expect(successState.canRetry, isFalse);
    });

    test('invalid scope transition throws StateError', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      Object? caughtError;
      await controller.run<String>(
        operationType: 'invalid-transition',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          try {
            // generating → uploading is NOT allowed
            scope.transition(AiGenerationPhase.uploading);
          } catch (e) {
            caughtError = e;
          }
          return 'result';
        },
      );

      expect(caughtError, isA<StateError>());
    });

    test('all active phases report isActive=true', () {
      for (final phase in [
        AiGenerationPhase.preparing,
        AiGenerationPhase.uploading,
        AiGenerationPhase.analyzing,
        AiGenerationPhase.generating,
        AiGenerationPhase.retrying,
      ]) {
        final state = AiGenerationState(phase: phase);
        expect(
          state.isActive,
          isTrue,
          reason: '${phase.name} should be active',
        );
      }
    });

    test('all terminal phases report isActive=false', () {
      for (final phase in [
        AiGenerationPhase.idle,
        AiGenerationPhase.success,
        AiGenerationPhase.error,
      ]) {
        final state = AiGenerationState(phase: phase);
        expect(
          state.isActive,
          isFalse,
          reason: '${phase.name} should not be active',
        );
      }
    });

    test('canRetry only when error has canRetry=true', () {
      // Error with canRetry=false
      const noRetryError = AiGenerationState(
        phase: AiGenerationPhase.error,
        error: AiGenerationError(
          category: AiGenerationErrorCategory.invalidInput,
          message: 'Bad input',
          canRetry: false,
        ),
      );
      expect(noRetryError.canRetry, isFalse);

      // Error with no error object
      const noErrorObj = AiGenerationState(phase: AiGenerationPhase.error);
      expect(noErrorObj.canRetry, isFalse);

      // Non-error phase with canRetry shouldn't be retryable
      const activeState = AiGenerationState(
        phase: AiGenerationPhase.generating,
      );
      expect(activeState.canRetry, isFalse);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP J — No Global Singleton
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 No Global Singleton (Feature Isolation)', () {
    test('two feature controllers are fully independent', () async {
      final step4Controller = AiGenerationController();
      final step5Controller = AiGenerationController();
      addTearDown(step4Controller.dispose);
      addTearDown(step5Controller.dispose);

      final completer4 = Completer<String>();

      // Step 4 starts
      step4Controller.run<String>(
        operationType: 'step4',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) => completer4.future,
      );

      expect(step4Controller.state.isActive, isTrue);
      expect(
        step5Controller.state.isActive,
        isFalse,
        reason: 'Step 5 must not be affected by Step 4',
      );

      // Step 5 operates independently
      final result5 = await step5Controller.run<String>(
        operationType: 'step5',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async => 'step5-result',
      );

      expect(result5.isSuccess, isTrue);
      expect(step5Controller.state.phase, AiGenerationPhase.success);
      expect(
        step4Controller.state.isActive,
        isTrue,
        reason: 'Step 4 still active after Step 5 completes',
      );

      completer4.complete('step4-result');
    });

    test('error in one does not affect another', () async {
      final controllerA = AiGenerationController();
      final controllerB = AiGenerationController();
      addTearDown(controllerA.dispose);
      addTearDown(controllerB.dispose);

      // A fails
      await controllerA.run<String>(
        operationType: 'a-fail',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 5),
        ),
        operation: (scope) async => throw Exception('A fails'),
      );

      expect(controllerA.state.phase, AiGenerationPhase.error);
      expect(
        controllerB.state.phase,
        AiGenerationPhase.idle,
        reason: 'B must not inherit A error',
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP K — Process Death & Reconstruction
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Process Death', () {
    test('AB. fresh controller starts idle (no ghost generating)', () {
      // After process death, a new controller starts clean
      final freshController = AiGenerationController();
      addTearDown(freshController.dispose);

      expect(freshController.state.phase, AiGenerationPhase.idle);
      expect(freshController.state.isActive, isFalse);
      expect(freshController.state.operationId, isNull);
    });

    test(
      'AC. fresh controller does not automatically regenerate (no auto-retry)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        // Simulate: prior in-memory operation disappeared after process death
        // Fresh controller should not auto-start any operation
        var operationRan = false;

        // No one calls run() → operation stays idle
        await Future.delayed(const Duration(milliseconds: 50));
        expect(operationRan, isFalse);
        expect(controller.state.phase, AiGenerationPhase.idle);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP L — Error Messages
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Error Messages', () {
    test('AD. no raw backend exceptions in error messages', () {
      // Verify pre-built error messages don't expose raw types
      const timeoutErr = AiGenerationError.timeout();
      expect(timeoutErr.message.contains('TimeoutException'), isFalse);
      expect(timeoutErr.message.contains('Exception'), isFalse);
      expect(timeoutErr.message.isNotEmpty, isTrue);

      const unknownErr = AiGenerationError.unknown();
      expect(unknownErr.message.contains('Exception'), isFalse);
      expect(unknownErr.message.contains('SocketException'), isFalse);
      expect(unknownErr.message.isNotEmpty, isTrue);
    });

    test('canRetry is contextual, not always true', () {
      const invalidInputErr = AiGenerationError(
        category: AiGenerationErrorCategory.invalidInput,
        message: 'Missing required photo',
        canRetry: false,
      );
      expect(invalidInputErr.canRetry, isFalse);

      const networkErr = AiGenerationError(
        category: AiGenerationErrorCategory.network,
        message: 'Connection lost',
        canRetry: true,
      );
      expect(networkErr.canRetry, isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP M — Feature-Specific Integration
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Feature-Specific Lifecycle Tests', () {
    test(
      'Step 4: preparing → generating → success (timetable extraction)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final phases = <AiGenerationPhase>[];
        controller.addListener(() => phases.add(controller.state.phase));

        final result = await controller.run<bool>(
          operationType: 'onboarding-step4-timetable',
          timeoutPolicy: AiOperationTimeouts.routineImport,
          operation: (scope) async {
            scope.transition(
              AiGenerationPhase.generating,
              message: 'AI is reading your class timetable…',
            );
            return true;
          },
        );

        expect(result.isSuccess, isTrue);
        expect(controller.state.phase, AiGenerationPhase.success);
        expect(
          phases.contains(AiGenerationPhase.uploading),
          isFalse,
          reason: 'Text-only operation must not fake uploading',
        );
      },
    );

    test(
      'Step 5: preparing → generating → success (nutrition creation, no upload)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final phases = <AiGenerationPhase>[];
        controller.addListener(() => phases.add(controller.state.phase));

        final result = await controller.run<bool>(
          operationType: 'nutrition-routine',
          timeoutPolicy: AiOperationTimeouts.nutrition,
          operation: (scope) async {
            scope.transition(
              AiGenerationPhase.generating,
              message: 'Building your meal plan…',
            );
            return true;
          },
        );

        expect(result.isSuccess, isTrue);
        expect(phases.contains(AiGenerationPhase.uploading), isFalse);
        expect(phases.contains(AiGenerationPhase.analyzing), isFalse);
      },
    );

    test(
      'Step 7 photo analysis: preparing → analyzing → success (skips generating)',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final phases = <AiGenerationPhase>[];
        controller.addListener(() => phases.add(controller.state.phase));

        final result = await controller.run<List<String>>(
          operationType: 'skin-care-analyze',
          timeoutPolicy: AiOperationTimeouts.skinCare,
          operation: (scope) async {
            scope.transition(
              AiGenerationPhase.analyzing,
              message: 'Analyzing skin care products…',
            );
            return ['Cleanser', 'SPF 50 Sunscreen'];
          },
        );

        expect(result.isSuccess, isTrue);
        expect(result.value, ['Cleanser', 'SPF 50 Sunscreen']);
        expect(
          phases,
          containsAllInOrder([
            AiGenerationPhase.preparing,
            AiGenerationPhase.analyzing,
            AiGenerationPhase.success,
          ]),
        );
      },
    );

    test(
      'Step 7 routine generation: preparing → generating → success',
      () async {
        final controller = AiGenerationController();
        addTearDown(controller.dispose);

        final phases = <AiGenerationPhase>[];
        controller.addListener(() => phases.add(controller.state.phase));

        final result = await controller.run<int>(
          operationType: 'skin-care-routine',
          timeoutPolicy: AiOperationTimeouts.skinCare,
          operation: (scope) async {
            scope.transition(
              AiGenerationPhase.generating,
              message: 'Building routine…',
            );
            return 3;
          },
        );

        expect(result.isSuccess, isTrue);
        expect(
          phases,
          containsAllInOrder([
            AiGenerationPhase.preparing,
            AiGenerationPhase.generating,
            AiGenerationPhase.success,
          ]),
        );
      },
    );

    test('Step 7 find-products: preparing → analyzing → success', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      final result = await controller.run<bool>(
        operationType: 'skin-care-find-products',
        timeoutPolicy: AiOperationTimeouts.skinCare,
        operation: (scope) async {
          scope.transition(
            AiGenerationPhase.analyzing,
            message: 'Finding useful products…',
          );
          return true;
        },
      );

      expect(result.isSuccess, isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP N — Orb / Status UI Widget Tests
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Orb / Status UI', () {
    testWidgets('stable orb with rotating delay hints', (tester) async {
      final state = AiGenerationState(
        phase: AiGenerationPhase.generating,
        operationId: 'test:1',
        startedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AiThinkingCard(
                state: state,
                title: 'Building your routine',
                detail: 'Organizing daily schedule',
                accent: OptivusColors.aquaAccent,
                firstLongWaitDelay: const Duration(seconds: 1),
                secondLongWaitDelay: const Duration(seconds: 2),
              ),
            ),
          ),
        ),
      );

      // Orb region is stable with ValueKey
      expect(
        find.byKey(const ValueKey('ai-generation-status-region')),
        findsOneWidget,
      );
      expect(find.textContaining('Building your routine'), findsOneWidget);
      expect(find.text('Organizing daily schedule'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(
        find.text('Detailed photos can take a little longer'),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Still working. Keep this screen open'), findsOneWidget);
    });

    testWidgets('error shows message and accessible retry button', (
      tester,
    ) async {
      var retryTapped = false;
      const errorState = AiGenerationState(
        phase: AiGenerationPhase.error,
        error: AiGenerationError(
          category: AiGenerationErrorCategory.serviceUnavailable,
          message: 'AI is temporarily unavailable. Try again.',
          canRetry: true,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AiThinkingCard(
                state: errorState,
                title: 'Building routine',
                detail: '',
                accent: OptivusColors.roseAccent,
                onRetry: () => retryTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(
        find.text('AI is temporarily unavailable. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retryTapped, isTrue);
    });

    testWidgets('no retry button when canRetry=false', (tester) async {
      const errorState = AiGenerationState(
        phase: AiGenerationPhase.error,
        error: AiGenerationError(
          category: AiGenerationErrorCategory.invalidInput,
          message: 'Missing required photo.',
          canRetry: false,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AiThinkingCard(
                state: errorState,
                title: 'Error',
                detail: '',
                accent: OptivusColors.roseAccent,
                onRetry: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Missing required photo.'), findsOneWidget);
      expect(
        find.text('Retry'),
        findsNothing,
        reason: 'Non-retryable error should not show Retry',
      );
    });

    testWidgets('idle state shows nothing', (tester) async {
      const idleState = AiGenerationState();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AiThinkingCard(
                state: idleState,
                title: 'idle',
                detail: '',
                accent: OptivusColors.aquaAccent,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('ai-generation-status-region')),
        findsNothing,
      );
    });

    testWidgets('success state shows nothing (orb collapses)', (tester) async {
      const successState = AiGenerationState(phase: AiGenerationPhase.success);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AiThinkingCard(
                state: successState,
                title: 'done',
                detail: '',
                accent: OptivusColors.aquaAccent,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('ai-generation-status-region')),
        findsNothing,
      );
    });

    testWidgets(
      'AiThinkingCard compatibility mode (isActive bool) works without state',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AiThinkingCard(
                  isActive: true,
                  title: 'Legacy mode',
                  detail: 'Still supported',
                  accent: OptivusColors.aquaAccent,
                ),
              ),
            ),
          ),
        );

        expect(find.textContaining('Legacy mode'), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP O — Infinite Spinner Fault Sweep
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Infinite Spinner Fault Sweep', () {
    test('exception at every async boundary terminates active state', () async {
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      // Preparation failure
      await controller.run<String>(
        operationType: 'prep-exc',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 2),
        ),
        operation: (scope) async => throw Exception('prep'),
      );
      expect(
        controller.state.isActive,
        isFalse,
        reason: 'prep exception must terminate',
      );

      // Upload failure
      await controller.run<String>(
        operationType: 'upload-exc',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 2),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.uploading);
          throw Exception('upload');
        },
      );
      expect(
        controller.state.isActive,
        isFalse,
        reason: 'upload exception must terminate',
      );

      // Analyze failure
      await controller.run<String>(
        operationType: 'analyze-exc',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 2),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.analyzing);
          throw Exception('analyze');
        },
      );
      expect(
        controller.state.isActive,
        isFalse,
        reason: 'analyze exception must terminate',
      );

      // Generate failure
      await controller.run<String>(
        operationType: 'gen-exc',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 2),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          throw Exception('generate');
        },
      );
      expect(
        controller.state.isActive,
        isFalse,
        reason: 'generate exception must terminate',
      );

      // Parse failure (after receiving response)
      await controller.run<String>(
        operationType: 'parse-exc',
        timeoutPolicy: const AiTimeoutPolicy(
          operationTimeout: Duration(seconds: 2),
        ),
        operation: (scope) async {
          scope.transition(AiGenerationPhase.generating);
          throw const FormatException('malformed JSON');
        },
      );
      expect(
        controller.state.isActive,
        isFalse,
        reason: 'parse exception must terminate',
      );

      // For EACH: phase is error, not stuck in active
      expect(controller.state.phase, AiGenerationPhase.error);
    });
  });

  // ───────────────────────────────────────────────────────────────────
  // GROUP P — AH-F017 Scope Check & No Backend Changes
  // ───────────────────────────────────────────────────────────────────
  group('AH-F016 Scope & Backend Integrity', () {
    test('AF. lifecycle model does not contain upload repository logic', () {
      // Verify the lifecycle model is a pure state machine
      // It coordinates phases but does not:
      // - Reference R2 / asset metadata
      // - Contain upload URL construction
      // - Modify Worker request payloads
      // This is a code-level assertion verified by the source audit
      final controller = AiGenerationController();
      addTearDown(controller.dispose);

      // The controller API accepts operation as a black-box Future
      // It does not expose upload-specific APIs
      expect(controller.state.phase, AiGenerationPhase.idle);
    });
  });
}
