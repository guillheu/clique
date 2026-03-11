import gleam/dynamic/decode
import gleam/json

// TYPES -----------------------------------------------------------------------

///
///
pub type Position {
  Top
  TopLeft
  TopRight
  Right
  Bottom
  BottomLeft
  BottomRight
  Left
}

// CONVERSIONS -----------------------------------------------------------------

///
///
pub fn to_string(value: Position) -> String {
  case value {
    TopLeft -> "top-left"
    Top -> "top"
    TopRight -> "top-right"
    Right -> "right"
    BottomRight -> "bottom-right"
    Bottom -> "bottom"
    BottomLeft -> "bottom-left"
    Left -> "left"
  }
}

pub fn from_string(value: String) -> Result(Position, Nil) {
  case value {
    "top-left" -> Ok(TopLeft)
    "top" -> Ok(Top)
    "top-right" -> Ok(TopRight)
    "right" -> Ok(Right)
    "bottom-right" -> Ok(BottomRight)
    "bottom" -> Ok(Bottom)
    "bottom-left" -> Ok(BottomLeft)
    "left" -> Ok(Left)
    _ -> Error(Nil)
  }
}

///
///
pub fn to_side(value: Position) -> String {
  case value {
    TopLeft | Top | TopRight -> "top"
    Right -> "right"
    BottomRight | Bottom | BottomLeft -> "bottom"
    Left -> "left"
  }
}

// ENCODER/DECODER -------------------------------------------------------------
pub fn position_to_json(position: Position) -> json.Json {
  to_string(position) |> json.string
}

pub fn position_decoder() -> decode.Decoder(Position) {
  use variant <- decode.then(decode.string)
  case from_string(variant) {
    Ok(value) -> decode.success(value)
    Error(_) -> decode.failure(Right, "Position")
  }
}
