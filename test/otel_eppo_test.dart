// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_eppo/otel_eppo.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_eppo-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('assignment records experiment + allocation + variation', () async {
    await tracedEppo<String>(
      operation: 'get_string_assignment',
      invoke: () async => const EppoCallResult(
        value: 'ok',
        result: EppoResult(
          flagKey: 'pricing_test',
          variation: 'treatment_a',
          experimentKey: 'exp-2026-q2',
          allocationKey: 'us-paid-users',
          subjectKey: 'u-1',
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('eppo get_string_assignment')!);
    expect(a['eppo.flag.key'], 'pricing_test');
    expect(a['eppo.variation'], 'treatment_a');
    expect(a['eppo.experiment.key'], 'exp-2026-q2');
    expect(a['eppo.allocation.key'], 'us-paid-users');
  });

  test('holdout recorded so exposure is excluded', () async {
    await tracedEppo<String>(
      operation: 'get_boolean_assignment',
      invoke: () async => const EppoCallResult(
        value: 'ok',
        result: EppoResult(
          flagKey: 'feature_x',
          holdoutKey: 'q2-holdout',
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('eppo get_boolean_assignment')!);
    expect(a['eppo.holdout.key'], 'q2-holdout');
  });

  test('bandit chooses action with score', () async {
    await tracedEppo<String>(
      operation: 'bandit.get_action',
      invoke: () async => const EppoCallResult(
        value: 'ok',
        result: EppoResult(
          banditAction: 'rec_item_42',
          banditScore: 873,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('eppo bandit.get_action')!);
    expect(a['eppo.bandit.action'], 'rec_item_42');
    expect(a['eppo.bandit.score.thousandths'], 873);
  });

  test('suppression skips spans', () async {
    await runWithoutEppoInstrumentationAsync(() async {
      await tracedEppo<String>(
        operation: 'flags.list',
        invoke: () async => const EppoCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('eppo '), isEmpty);
  });
}
