///|
/// RFC 6330 GF(256), polynomial x^8+x^4+x^3+x^2+1 (0x11d).
fn field_mul_slow(left : Int32, right : Int32) -> Int32 {
  let mut a = left
  let mut b = right
  let mut result = 0
  while b != 0 {
    if (b & 1) != 0 {
      result = result ^ a
    }
    b = b >> 1
    a = a << 1
    if a >= 256 {
      a = a ^ 0x11d
    }
  }
  result
}

///|
let field_products : Array[Array[Int32]] = {
  let table : Array[Array[Int32]] = []
  for a in 0..<256 {
    let row : Array[Int32] = []
    for b in 0..<256 {
      row.push(field_mul_slow(a, b))
    }
    table.push(row)
  }
  table
}

///|
fn field_mul(a : Int32, b : Int32) -> Int32 {
  field_products[a][b]
}

///|
fn field_power(value : Int32, exponent : Int32) -> Int32 {
  let mut result = 1
  let mut base = value
  let mut power = exponent
  while power > 0 {
    if (power & 1) != 0 {
      result = field_mul(result, base)
    }
    base = field_mul(base, base)
    power = power >> 1
  }
  result
}

///|
fn field_inverse(value : Int32) -> Int32 {
  field_power(value, 254)
}

///|
fn add_scaled(
  target : Array[Int32],
  source : Array[Int32],
  scalar : Int32,
  start : Int32,
) -> Unit {
  if scalar == 0 {
    return
  }
  for i in start..<target.length() {
    target[i] = target[i] ^ field_mul(source[i], scalar)
  }
}
