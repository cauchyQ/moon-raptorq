///|
/// Element budgets for the sparse execution path. These are not RSS estimates.
pub struct ExecutionLimits {
  priv symbol_elements : Int64
  priv dense_entries : Int32
  priv sparse_entries : Int32
}

///|
pub fn ExecutionLimits::new(
  symbol_elements~ : Int64 = 16777216L,
  dense_entries~ : Int32 = 16777216,
  sparse_entries~ : Int32 = 8388608,
) -> Result[ExecutionLimits, RaptorError] {
  if symbol_elements < 1L ||
    symbol_elements > 2147483647L ||
    dense_entries < 1 ||
    sparse_entries < 1 {
    return Err(
      InvalidParameters(
        "execution budgets must be positive and fit host indexing",
      ),
    )
  }
  Ok({ symbol_elements, dense_entries, sparse_entries, })
}

///|
pub fn ExecutionLimits::defaults() -> ExecutionLimits {
  ExecutionLimits::new().unwrap()
}
