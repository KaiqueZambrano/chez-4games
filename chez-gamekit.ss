;;; chez-gamekit.ss

(define gamekit-base (path-parent (car (command-line))))

(define (gamekit-load file)
  (load (string-append gamekit-base "lib/" file)))

(gamekit-load "raylib.ss")
(gamekit-load "json.ss")
(gamekit-load "ecs.ss")
(gamekit-load "assets.ss")
(gamekit-load "camera.ss")
(gamekit-load "input.ss")
(gamekit-load "animation.ss")
(gamekit-load "game-loop.ss")
(gamekit-load "tilemap.ss")

(component position (x y))
