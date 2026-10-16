// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_eppo_suppression.dart';

const _tracerName = 'dartastic_otel_libs_eppo';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class EppoResult {
  const EppoResult({
    this.flagKey,
    this.variation,
    this.experimentKey,
    this.allocationKey,
    this.subjectKey,
    this.holdoutKey,
    this.banditAction,
    this.banditScore,
    this.usedDefault,
    this.requestId,
    this.statusCode,
  });

  /// Flag key evaluated.
  final String? flagKey;

  /// Variation assigned (`treatment` / `control` / custom variation).
  final String? variation;

  /// `experiment_key` when the flag is part of a randomized experiment.
  final String? experimentKey;

  /// `allocation_key` matched (Eppo's targeting bucket).
  final String? allocationKey;

  /// Subject identifier (user/account id) — keep cardinality bounded.
  final String? subjectKey;

  /// Holdout group key if subject is in a holdout (no exposure
  /// counted toward experiment metrics).
  final String? holdoutKey;

  /// Action chosen by a contextual bandit (e.g. recommendation).
  final String? banditAction;

  /// Bandit probability score for the chosen action (0-1 scaled to
  /// thousandths to keep int).
  final int? banditScore;

  /// True if SDK fell back to the supplied default.
  final bool? usedDefault;

  /// `X-Request-Id`.
  final String? requestId;

  final int? statusCode;
}

class EppoCallResult<T> {
  const EppoCallResult({required this.value, this.result});
  final T value;
  final EppoResult? result;
}

/// Wraps an Eppo API call in a CLIENT span. [operation] is one of
/// `get_string_assignment`, `get_boolean_assignment`,
/// `get_numeric_assignment`, `get_integer_assignment`,
/// `get_json_assignment`, `bandit.get_action`, `assignments.log`,
/// `flags.list`, `flags.update`, `experiments.list`,
/// `experiments.get_results`, `metrics.list`, `holdouts.list`,
/// `feedback.send`.
Future<T> tracedEppo<T>({
  required String operation,
  required Future<EppoCallResult<T>> Function() invoke,
}) async {
  if (eppoInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'eppo',
    'rpc.method': operation,
    'eppo.operation': operation,
  };

  final span = _tracer().startSpan(
    'eppo $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.flagKey != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.flag.key',
          r.result!.flagKey!,
        ));
      }
      if (r.result!.variation != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.variation',
          r.result!.variation!,
        ));
      }
      if (r.result!.experimentKey != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.experiment.key',
          r.result!.experimentKey!,
        ));
      }
      if (r.result!.allocationKey != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.allocation.key',
          r.result!.allocationKey!,
        ));
      }
      if (r.result!.subjectKey != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.subject.key',
          r.result!.subjectKey!,
        ));
      }
      if (r.result!.holdoutKey != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.holdout.key',
          r.result!.holdoutKey!,
        ));
      }
      if (r.result!.banditAction != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.bandit.action',
          r.result!.banditAction!,
        ));
      }
      if (r.result!.banditScore != null) {
        extras.add(OTelAPI.attributeInt(
          'eppo.bandit.score.thousandths',
          r.result!.banditScore!,
        ));
      }
      if (r.result!.usedDefault != null) {
        extras.add(OTelAPI.attributeBool(
          'eppo.used_default',
          r.result!.usedDefault!,
        ));
        if (r.result!.usedDefault == true) {
          span.setStatus(
            SpanStatusCode.Error,
            'Eppo returned default value',
          );
        }
      }
      if (r.result!.requestId != null) {
        extras.add(OTelAPI.attributeString(
          'eppo.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Eppo HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
