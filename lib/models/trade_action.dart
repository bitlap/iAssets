/// Language-independent operation identity, persisted with each new trade.
enum TradeAction {
  open,
  add,
  reduce,
  close;

  static TradeAction? fromName(Object? name) {
    for (final action in values) {
      if (action.name == name) return action;
    }
    return null;
  }
}
