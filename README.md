# chez-gamekit

Raylib bindings, an ECS with a small DSL, and a game engine layer for Chez Scheme.
Built for personal use — simple 2D games. No package system, no dependencies beyond Chez Scheme and raylib.

## Requirements

- [Chez Scheme](https://cisco.github.io/ChezScheme/)
- [raylib](https://www.raylib.com/) (tested with `libraylib.so` on Linux)

## Usage

```scheme
(load "lib/raylib.ss")
(load "lib/ecs.ss")
(load "lib/engine.ss")  ; optional — assets, animation, game loop
```

## raylib.ss

Covers the basics for 2D games:

- Window management (`init-window`, `close-window`, `window-should-close`, `get-screen-width`, `get-screen-height`, etc.)
- Drawing (`begin-drawing`, `end-drawing`, `clear-background`, `draw-rectangle`, `draw-circle`, `draw-text`, `draw-fps`, etc.)
- Textures (`load-texture`, `draw-texture`, `draw-texture-rec`, `draw-texture-pro`)
- Camera 2D (`begin-mode-2d`, `end-mode-2d`, `make-camera2d`)
- Keyboard and mouse input — full key constants (`key-a` through `key-z`, `key-up/down/left/right`, F-keys, etc.)
- Audio (`load-sound`, `play-sound`, `pause-sound`, `resume-sound`, `is-sound-playing`)
- Timing (`get-frame-time`, `get-time`, `get-fps`)

Camera 2D, audio, and `draw-texture-pro` are included but **untested** — they were mapped manually from raylib's internal struct layout and may not work correctly across raylib versions.

## ecs.ss

A minimal ECS with a DSL. Entities and components are stored in hashtables.

```scheme
(component position (x y))
(component velocity (dx dy))
(component health (hp))
(component dead)                    ; tag — no fields

(entity player (position 0 0) (velocity 1 2) (health 100))
(entity wall   (position 5 5))

(define bullet (spawn (position 10 10) (velocity 0 -1)))  ; dynamic entity

(system movement ((pos : position) (vel : velocity)) not (dead)
  (put! pos x (+ (get pos x) (get vel dx)))
  (put! pos y (+ (get pos y) (get vel dy))))

(event hit (target damage))

(on-global hit (target damage)
  (put! target health hp (- (get target health hp) damage)))

(emit hit (target player) (damage 30))

(scene gameplay
  (on-enter
    (set! player (spawn (position 0 0) (velocity 1 2) (health 100)))
    (system movement ((pos : position) (vel : velocity)) not (dead)
      (put! pos x (+ (get pos x) (get vel dx)))
      (put! pos y (+ (get pos y) (get vel dy)))))
  (on-exit
    (display "leaving gameplay")))

(go-to 'gameplay)
(run)
```

### ECS API

| Form | Description |
|---|---|
| `(component name (field ...))` | Declares a component type with fields |
| `(component tag)` | Declares a tag component (no fields) |
| `(entity name (comp val ...) ...)` | Creates a named entity at top level |
| `(spawn (comp val ...) ...)` | Creates a dynamic entity, returns id |
| `(despawn id)` | Removes an entity |
| `(get comp field)` | Reads a field inside a system |
| `(get id comp field)` | Reads a field outside a system |
| `(put! comp field expr)` | Writes a field inside a system |
| `(put! id comp field expr)` | Writes a field outside a system |
| `(add-component id comp)` | Adds a tag component to an entity |
| `(add-component id comp (field val) ...)` | Adds a component with fields |
| `(remove-component id comp)` | Removes a component from an entity |
| `(has-component? id comp)` | Returns `#t` if entity has component |
| `(system name ((var : comp) ...) body ...)` | Defines and registers a system |
| `(system name ((var : comp) ...) not (excl ...) body ...)` | Same, with exclusions |
| `(event name (field ...))` | Declares an event type |
| `(emit name (field val) ...)` | Enqueues an event |
| `(on name (field ...) body ...)` | Registers a scene-local event handler |
| `(on-global name (field ...) body ...)` | Registers a persistent event handler |
| `(scene name (on-enter body ...) (on-exit body ...))` | Declares a scene |
| `(go-to name)` | Switches to a scene |
| `(run)` | Runs all systems, then dispatches events |

Inside a system, `entity-id` is always bound to the current entity's id.

Entities tagged with `(add-component id persistent)` survive scene transitions.
`entity` only works at the top level — use `spawn` + `set!` inside `on-enter`.

## engine.ss

Adds asset management, sprite animation, and a structured game loop on top of `ecs.ss` and `raylib.ss`.

```scheme
(load "lib/raylib.ss")
(load "lib/ecs.ss")
(load "lib/engine.ss")

(component position (x y))

;;; assets
(load-asset 'player "assets/player.png")

;;; animation component is pre-defined in engine.ss:
;;;   (component animation (asset frame-w frame-h frames fps frame elapsed))

(define player #f)

(scene gameplay
  (on-enter
    (set! player (spawn
      (position 100 100)
      (animation player 32 32 4 8 0 0.0)))

    (system input ((pos : position))
      (when (is-key-down key-right) (put! pos x (+ (get pos x) 2)))
      (when (is-key-down key-left)  (put! pos x (- (get pos x) 2)))
      (when (is-key-down key-down)  (put! pos y (+ (get pos y) 2)))
      (when (is-key-down key-up)    (put! pos y (- (get pos y) 2)))))
  (on-exit #f))

;;; animation-system and render-animation-system are
;;; pre-registered by engine.ss — no need to define them.

(go-to 'gameplay)
(game-loop "my game" 800 600 60)
```

### engine.ss API

| Form | Description |
|---|---|
| `(load-asset name path)` | Loads a texture and caches it by name |
| `(load-asset name path loader)` | Same, with a custom loader function |
| `(get-asset name)` | Returns a cached asset |
| `(unload-asset name)` | Removes an asset from the cache |
| `*dt*` | Delta time for the current frame (set by `game-loop`) |
| `(game-loop title w h fps)` | Opens window and runs the main loop |
| `(game-loop title w h fps init)` | Same, calls `init` once before the loop |

The `animation` component and its systems (`animation-system`, `render-animation-system`) are automatically available when `engine.ss` is loaded. The render system expects a `position` component on the same entity.

## License

MIT
