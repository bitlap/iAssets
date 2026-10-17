import 'package:assets/config/app_config.dart';
import 'package:assets/services/circuit_breaker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final breaker = CircuitBreaker();
  setUp(breaker.onSuccess);
  tearDown(breaker.onSuccess);
  test('only consecutive failures at threshold trigger cooldown', () {
    expect(breaker.isInCooldown, isFalse);
    expect(breaker.cooldownRemainingSeconds, 0);
    for (var i = 1; i < AppConfig.failureThreshold; i++) {
      breaker.onFailure();
      expect(breaker.isInCooldown, isFalse);
    }
    breaker.onFailure();
    expect(breaker.isInCooldown, isTrue);
    expect(
      breaker.cooldownRemainingSeconds,
      inInclusiveRange(
        AppConfig.cooldownDurationMin * 60 - 2,
        AppConfig.cooldownDurationMin * 60,
      ),
    );
  });
  test('success resets failure streak before the threshold', () {
    breaker.onFailure();
    breaker.onFailure();
    breaker.onSuccess();
    breaker.onFailure();
    expect(breaker.isInCooldown, isFalse);
    expect(breaker.cooldownRemainingSeconds, 0);
  });
  test('success clears active cooldown and permits a fresh failure streak', () {
    for (var i = 0; i < AppConfig.failureThreshold; i++) {
      breaker.onFailure();
    }
    expect(breaker.isInCooldown, isTrue);
    breaker.onSuccess();
    expect(breaker.isInCooldown, isFalse);
    expect(breaker.cooldownRemainingSeconds, 0);
    breaker.onFailure();
    expect(breaker.isInCooldown, isFalse);
  });
}
