import 'package:assets/services/circuit_breaker.dart';

void resetSourceBreakers() {
  for (final breaker in [
    CircuitBreaker.stockSearch,
    CircuitBreaker.tencent,
    CircuitBreaker.eastMoney,
    CircuitBreaker.yahoo,
  ]) {
    breaker.onSuccess();
  }
}
