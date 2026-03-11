// IMPORTS ---------------------------------------------------------------------

import clique/handle.{type Handle, Handle}
import clique/internal/path
import clique/position
import gleam/dynamic/decode
import gleam/float
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/string
import justin
import lustre
import lustre/attribute.{type Attribute, attribute}
import lustre/component
import lustre/effect.{type Effect}
import lustre/element.{type Element, element}
import lustre/element/html
import lustre/event

// COMPONENT -------------------------------------------------------------------

pub const tag: String = "clique-edge"

///
///
pub fn register() -> Result(Nil, lustre.Error) {
  lustre.register(
    lustre.component(init:, update:, view:, options: options()),
    tag,
  )
}

// ELEMENTS --------------------------------------------------------------------

///
///
pub fn root(
  attributes: List(Attribute(msg)),
  children: List(Element(msg)),
) -> Element(msg) {
  element(tag, attributes, children)
}

// ATTRIBUTES ------------------------------------------------------------------

///
///
pub fn from(handle: Handle) -> Attribute(msg) {
  attribute("from", handle.node <> " " <> handle.name)
}

///
///
pub fn to(handle: Handle) -> Attribute(msg) {
  attribute("to", handle.node <> " " <> handle.name)
}

///
///
pub fn bezier(
  from_position: position.Position,
  to_position: position.Position,
  other_attributes: List(Attribute(msg)),
) -> List(Attribute(msg)) {
  [
    attribute("type", "bezier"),
    attribute("bezier-from-position", position.to_string(from_position)),
    attribute("bezier-to-position", position.to_string(to_position)),
    ..other_attributes
  ]
}

///
///
pub fn linear(other_attributes: List(Attribute(msg))) -> List(Attribute(msg)) {
  [attribute("type", "linear"), ..other_attributes]
}

///
///
pub fn step(
  mid_ratio: Float,
  other_attributes: List(Attribute(msg)),
) -> List(Attribute(msg)) {
  [
    attribute("type", "step"),
    attribute("step-mid-ratio", float.to_string(mid_ratio)),
    ..other_attributes
  ]
}

// EVENTS ----------------------------------------------------------------------

pub fn on_disconnect(handler: fn(Handle, Handle) -> msg) -> Attribute(msg) {
  event.on("clique:disconnect", {
    use from <- decode.subfield(["detail", "from"], handle.decoder())
    use to <- decode.subfield(["detail", "to"], handle.decoder())

    decode.success(handler(from, to))
  })
}

fn emit_disconnect(from: Handle, to: Handle) -> Effect(msg) {
  event.emit("clique:disconnect", {
    json.object([
      #("from", handle.to_json(from)),
      #("to", handle.to_json(to)),
    ])
  })
}

pub fn on_reconnect(
  handler: fn(#(Handle, Handle), #(Handle, Handle), path.PathKind) -> msg,
) -> Attribute(msg) {
  event.on("clique:reconnect", {
    use old <- decode.subfield(["detail", "old"], {
      use from <- decode.field("from", handle.decoder())
      use to <- decode.field("to", handle.decoder())

      decode.success(#(from, to))
    })

    use new <- decode.subfield(["detail", "new"], {
      use from <- decode.field("from", handle.decoder())
      use to <- decode.field("to", handle.decoder())

      decode.success(#(from, to))
    })

    use kind <- decode.subfield(["detail", "type"], path.path_kind_decoder())

    decode.success(handler(old, new, kind))
  })
}

fn emit_reconnect(
  old: #(Handle, Handle),
  new: #(Handle, Handle),
  new_kind: path.PathKind,
) -> Effect(msg) {
  event.emit("clique:reconnect", {
    json.object([
      #("old", {
        json.object([
          #("from", handle.to_json(old.0)),
          #("to", handle.to_json(old.1)),
        ])
      }),
      #("new", {
        json.object([
          #("from", handle.to_json(new.0)),
          #("to", handle.to_json(new.1)),
        ])
      }),
      #("type", path.path_kind_to_json(new_kind)),
    ])
  })
}

pub fn on_connect(
  handler: fn(Handle, Handle, path.PathKind) -> msg,
) -> Attribute(msg) {
  event.on("clique:connect", {
    use from <- decode.subfield(["detail", "from"], handle.decoder())
    use to <- decode.subfield(["detail", "to"], handle.decoder())
    use kind <- decode.subfield(["detail", "type"], path.path_kind_decoder())

    decode.success(handler(from, to, kind))
  })
}

fn emit_connect(from: Handle, to: Handle, kind: path.PathKind) -> Effect(msg) {
  event.emit("clique:connect", {
    json.object([
      #("from", handle.to_json(from)),
      #("to", handle.to_json(to)),
      #("type", path.path_kind_to_json(kind)),
    ])
  })
}

fn emit_change(
  old_from: Option(Handle),
  old_to: Option(Handle),
  new_from: Option(Handle),
  new_to: Option(Handle),
  kind: path.PathKind,
) -> Effect(msg) {
  case old_from, old_to, new_from, new_to {
    Some(old_from), Some(old_to), Some(new_from), Some(new_to) ->
      emit_reconnect(#(old_from, old_to), #(new_from, new_to), kind)

    Some(old_from), Some(old_to), _, _ -> emit_disconnect(old_from, old_to)

    _, _, Some(new_from), Some(new_to) -> emit_connect(new_from, new_to, kind)

    _, _, _, _ -> effect.none()
  }
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(
    from: Option(Handle),
    to: Option(Handle),
    kind: String,
    bezier_from_position: Option(position.Position),
    bezier_to_position: Option(position.Position),
    step_mid_ratio: Option(Float),
  )
}

fn init(_) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      from: None,
      to: None,
      kind: "bezier",
      bezier_from_position: None,
      bezier_to_position: None,
      step_mid_ratio: None,
    )
  let effect = effect.none()

  #(model, effect)
}

fn options() -> List(component.Option(Msg)) {
  [
    //
    //
    component.adopt_styles(False),

    //
    //
    component.on_attribute_change("from", fn(value) {
      case string.split(value, " ") {
        [node, name] if node != "" && name != "" ->
          Ok(ParentSetFrom(Handle(node:, name:)))
        _ -> Ok(ParentRemovedFrom)
      }
    }),

    //
    //
    component.on_attribute_change("to", fn(value) {
      case string.split(value, " ") {
        [node, name] if node != "" && name != "" ->
          Ok(ParentSetTo(value: Handle(node:, name:)))
        _ -> Ok(ParentRemovedTo)
      }
    }),

    //
    //
    component.on_attribute_change("type", fn(value) {
      case value {
        "" -> Ok(ParentSetType(value: "bezier"))
        _ -> Ok(ParentSetType(value:))
      }
    }),

    //
    //
    component.on_attribute_change("bezier-from-pos", fn(value) {
      case position.from_string(value) {
        Ok(pos) -> Ok(ParentSetBezierFromPosition(pos))
        Error(_) -> Ok(ParentSetBezierFromPosition(position.Right))
      }
    }),

    //
    //
    component.on_attribute_change("bezier-to-pos", fn(value) {
      case position.from_string(value) {
        Ok(pos) -> Ok(ParentSetBezierToPosition(pos))
        Error(_) -> Ok(ParentSetBezierToPosition(position.Left))
      }
    }),

    //
    //
    component.on_attribute_change("step-mid-ratio", fn(value) {
      case float.parse(value) {
        Ok(value) if 0.0 <=. value && value >=. 1.0 ->
          Ok(ParentSetStepMidRatio(value))
        _ -> Ok(ParentSetStepMidRatio(0.5))
      }
    }),
  ]
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  ParentRemovedFrom
  ParentRemovedTo
  ParentSetFrom(value: Handle)
  ParentSetTo(value: Handle)
  ParentSetType(value: String)
  ParentSetBezierFromPosition(value: position.Position)
  ParentSetBezierToPosition(value: position.Position)
  ParentSetStepMidRatio(value: Float)
}

fn update(prev: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let prev_path_kind =
    path.string_to_path_kind(
      prev.kind,
      prev.bezier_from_position,
      prev.bezier_to_position,
      prev.step_mid_ratio,
    )
  case msg {
    ParentRemovedFrom -> {
      let next = Model(..prev, from: None)
      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, prev_path_kind)

      #(next, effect)
    }

    ParentRemovedTo -> {
      let next = Model(..prev, to: None)
      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, prev_path_kind)

      #(next, effect)
    }

    ParentSetFrom(value) -> {
      let next = Model(..prev, from: Some(value))
      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, prev_path_kind)

      #(next, effect)
    }

    ParentSetTo(value) -> {
      let next = Model(..prev, to: Some(value))
      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, prev_path_kind)

      #(next, effect)
    }

    ParentSetType(value) -> {
      let next = Model(..prev, kind: value)
      let next_path_kind =
        path.string_to_path_kind(
          next.kind,
          next.bezier_from_position,
          next.bezier_to_position,
          next.step_mid_ratio,
        )

      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, next_path_kind)

      #(next, effect)
    }
    ParentSetBezierFromPosition(value:) -> {
      let next = Model(..prev, bezier_from_position: Some(value))
      let next_path_kind =
        path.string_to_path_kind(
          next.kind,
          next.bezier_from_position,
          next.bezier_to_position,
          next.step_mid_ratio,
        )

      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, next_path_kind)
      #(next, effect)
    }
    ParentSetBezierToPosition(value:) -> {
      let next = Model(..prev, bezier_to_position: Some(value))
      let next_path_kind =
        path.string_to_path_kind(
          next.kind,
          next.bezier_from_position,
          next.bezier_to_position,
          next.step_mid_ratio,
        )

      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, next_path_kind)
      #(next, effect)
    }
    ParentSetStepMidRatio(value:) -> {
      let next = Model(..prev, step_mid_ratio: Some(value))
      let next_path_kind =
        path.string_to_path_kind(
          next.kind,
          next.bezier_from_position,
          next.bezier_to_position,
          next.step_mid_ratio,
        )

      let effect =
        emit_change(prev.from, prev.to, next.from, next.to, next_path_kind)
      #(next, effect)
    }
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  element.fragment([
    html.style([], {
      ":host {
        display: contents;
      }

      slot {
        display: inline-block;
        position: absolute;
        transform-origin: center;
        will-change: transform;
        pointer-events: auto;
      }
      "
    }),

    case model.from, model.to {
      Some(from), Some(to) -> {
        let var =
          justin.kebab_case(
            "from-"
            <> from.node
            <> "-"
            <> from.name
            <> "-to-"
            <> to.node
            <> "-"
            <> to.name,
          )
        let translate_x = "var(--" <> var <> "-cx)"
        let translate_y = "var(--" <> var <> "-cy)"

        let transform =
          "translate("
          <> translate_x
          <> ", "
          <> translate_y
          <> ") translate(-50%, -50%)"

        component.default_slot([attribute.style("transform", transform)], [])
      }
      _, _ -> element.none()
    },
  ])
}
