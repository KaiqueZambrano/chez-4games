# chez-4games

Raylib bindings and an ECS with a small DSL for Chez Scheme.
Built for personal use — simple 2D games. No package system, no dependencies beyond Chez Scheme and raylib.

## Requirements

- [Chez Scheme](https://cisco.github.io/ChezScheme/)
- [raylib](https://www.raylib.com/) (tested with `libraylib.so` on Linux)

## Usage

```scheme
(load "lib/raylib.ss")
(load "lib/ecs.ss")
```

## raylib.ss

Covers the basics for 2D games:

- Window management (`init-window`, `close-window`, `window-should-close`)
- Drawing (`begin-drawing`, `end-drawing`, `clear-background`, `draw-rectangle`, `draw-circle`, `draw-text`, etc.)
- Textures (`load-texture`, `draw-texture`, `draw-texture-rec`, `draw-texture-pro`)
- Keyboard and mouse input
- Collision (`check-collision-recs`)
- Camera 2D and audio bindings are included but **untested** — they were mapped manually from raylib's internal struct layout and may not work correctly across raylib versions.

## ecs.ss

A minimal ECS with a DSL built on association lists.

```scheme
(component position [x y])
(component velocity [dx dy])
(component health [hp])
(component dead)                          ; tag — no fields

(entity player [position 0 0] [velocity 1 2] [health 100])
(entity wall   [position 5 5])

(spawn [position 10 10] [velocity 0 -1]) ; dynamic entity, returns id

(system movement [pos : position & vel : velocity] not [dead]
  (put! pos x (+ (get pos x) (get vel dx)))
  (put! pos y (+ (get pos y) (get vel dy))))

(event hit [target damage])

(on hit [target damage]
  (put! target health hp (- (get target health hp) damage)))

(emit hit [target player] [damage 30])

(run)
```

### API

| Form | Description |
|---|---|
| `(component name [field ...])` | Declares a component type with fields |
| `(component tag)` | Declares a tag component (no fields) |
| `(entity name [comp val ...] ...)` | Creates a named entity |
| `(spawn [comp val ...] ...)` | Creates a dynamic entity, returns id |
| `(despawn id)` | Removes an entity |
| `(get comp field)` | Reads a field inside a system |
| `(get id comp field)` | Reads a field outside a system |
| `(put! comp field expr)` | Writes a field inside a system |
| `(put! id comp field expr)` | Writes a field outside a system |
| `(add-component id comp [field val ...])` | Adds a component to an existing entity |
| `(remove-component id comp)` | Removes a component from an entity |
| `(has-component? id comp)` | Returns `#t` if entity has component |
| `(system name [var : comp & ...] body ...)` | Defines and registers a system |
| `(system name [var : comp & ...] not [excl ...] body ...)` | Same, with exclusions |
| `(event name [field ...])` | Declares an event type |
| `(emit name [field val] ...)` | Enqueues an event |
| `(on name [field ...] body ...)` | Registers an event handler |
| `(run)` | Runs all systems, then dispatches events |

Inside a system, `entity-id` is always bound to the current entity's id.

## Binding status

| Module | Tested |
|---|---|
| Window, drawing, input | ✅ |
| Textures (`draw-texture`, `draw-texture-rec`) | ✅ |
| `draw-texture-pro` | ⚠️ untested |
| Collision | ✅ |
| Camera2D | ⚠️ untested |
| Audio / Sound | ⚠️ untested |

## License

MIT
