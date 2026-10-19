// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_eppo/otel_eppo.dart';

/// Traces Eppo calls with OpenTelemetry.
///
/// `otel_eppo` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Eppo call in
/// [tracedEppo]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'eppo-example');

  // Wraps an Eppo API call in a CLIENT span.
  final eppoId = await tracedEppo<String>(
    operation: 'feedback.send',
    invoke: () async {
      // Make the Eppo call here, then report what it returned.
      const id = 'eppo_8f3a2c';
      return const EppoCallResult(
          value: id,
          result: EppoResult(
              flagKey: 'orders/2026/inv-1042.pdf',
              variation: 'treatment',
              experimentKey: 'experiment_key',
              allocationKey: 'allocation_key',
              subjectKey: 'orders/2026/inv-1042.pdf',
              holdoutKey: 'orders/2026/inv-1042.pdf',
              banditAction: 'example',
              banditScore: 1,
              usedDefault: true,
              requestId: 'request_8f3a2c',
              statusCode: 201));
    },
  );
  OTelLog.info('tracedEppo feedback.send returned $eppoId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutEppoInstrumentationAsync.
  await runWithoutEppoInstrumentationAsync(
    () => tracedEppo<String>(
      operation: 'feedback.send',
      invoke: () async {
        const id = 'eppo_8f3a2c';
        return const EppoCallResult(
            value: id,
            result: EppoResult(
                flagKey: 'orders/2026/inv-1042.pdf',
                variation: 'treatment',
                experimentKey: 'experiment_key',
                allocationKey: 'allocation_key',
                subjectKey: 'orders/2026/inv-1042.pdf',
                holdoutKey: 'orders/2026/inv-1042.pdf',
                banditAction: 'example',
                banditScore: 1,
                usedDefault: true,
                requestId: 'request_8f3a2c',
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
