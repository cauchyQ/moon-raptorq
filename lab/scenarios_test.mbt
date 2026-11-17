///|
test "channel replay is deterministic bounded and includes configured burst" {
  for scenario in @lab.scenarios() {
    for receiver in 0..<scenario.receivers {
      let entries = @lab.trace(scenario, 20261117U, receiver)
      assert_eq(entries, @lab.trace(scenario, 20261117U, receiver))
      for sequence in entries {
        assert_true(sequence >= 0 && sequence < scenario.budget)
        assert_false(
          sequence >= scenario.burst_start &&
          sequence < scenario.burst_start + scenario.burst_length,
        )
      }
      let unique = @lab.unique_entries(entries, scenario.budget)
      assert_true(unique <= scenario.budget)
      assert_true(unique <= entries.length())
      if scenario.duplicate_every == 0 {
        assert_eq(unique, entries.length())
      }
    }
  }
}

///|
test "different receivers see independent deterministic traces" {
  let scenario = @lab.scenarios()[0]
  assert_false(@lab.trace(scenario, 17U, 0) == @lab.trace(scenario, 17U, 1))
  assert_false(@lab.trace(scenario, 17U, 0) == @lab.trace(scenario, 18U, 0))
}

///|
test "symbol splitting and concatenation preserve padded tails" {
  let data = @lab.source(127, 17U)
  let symbols = @lab.padded_symbols(data, 16, 8)
  assert_eq(symbols.length(), 16)
  assert_eq(symbols[15][7], 0)
  assert_eq(@lab.join_symbols(symbols, 127), data)
  assert_eq(@lab.unique_entries([0, 0, 1, 2, 1], 3), 3)
}
