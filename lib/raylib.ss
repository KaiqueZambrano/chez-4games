;;; raylib.ss

(load-shared-object "libraylib.so")

;;;; ============================================================
;;;; FTYPES (C Struct Definitions)
;;;; ============================================================

(define-ftype color
  (struct
    [r unsigned-8]
    [g unsigned-8]
    [b unsigned-8]
    [a unsigned-8]))

(define-ftype vector2
  (struct
    [x float]
    [y float]))

(define-ftype rectangle
  (struct
    [x      float]
    [y      float]
    [width  float]
    [height float]))

(define-ftype texture2d
  (struct
    [id      unsigned-32]
    [width   int]
    [height  int]
    [mipmaps int]
    [format  int]))

(define-ftype image
  (struct
    [data    void*]
    [width   int]
    [height  int]
    [mipmaps int]
    [format  int]))

(define-ftype camera2d
  (struct
    [offset-x float]
    [offset-y float]
    [target-x float]
    [target-y float]
    [rotation float]
    [zoom     float]))

(define-ftype sound
  (struct
    [stream-buffer void*]
    [stream-format void*]
    [frame-count   unsigned-32]
    [looping       boolean]))

(define-ftype music
  (struct
    [stream-buffer void*]
    [stream-format void*]
    [frame-count   unsigned-32]
    [looping       boolean]
    [ctx-type      int]
    [ctx-data      void*]))

;;;; ============================================================
;;;; MEMORY MANAGEMENT
;;;; ============================================================

(define ftype-guardian (make-guardian))

(define (register-ftype-ptr! ptr)
  (ftype-guardian (cons ptr (ftype-pointer-address ptr)))
  ptr)

(define (drain-ftype-guardian!)
  (let loop ()
    (let ([entry (ftype-guardian)])
      (when entry
        (foreign-free (cdr entry))
        (loop)))))

(define (free-ptr ptr)
  (foreign-free (ftype-pointer-address ptr)))

;;;; ============================================================
;;;; CONSTRUCTORS
;;;; ============================================================

(define (make-color r g b a)
  (let ([c (make-ftype-pointer color (foreign-alloc (ftype-sizeof color)))])
    (ftype-set! color (r) c r)
    (ftype-set! color (g) c g)
    (ftype-set! color (b) c b)
    (ftype-set! color (a) c a)
    c))

(define (make-vec2 x y)
  (let ([v (make-ftype-pointer vector2 (foreign-alloc (ftype-sizeof vector2)))])
    (ftype-set! vector2 (x) v (exact->inexact x))
    (ftype-set! vector2 (y) v (exact->inexact y))
    (register-ftype-ptr! v)))

(define (make-rect x y w h)
  (let ([r (make-ftype-pointer rectangle (foreign-alloc (ftype-sizeof rectangle)))])
    (ftype-set! rectangle (x)      r (exact->inexact x))
    (ftype-set! rectangle (y)      r (exact->inexact y))
    (ftype-set! rectangle (width)  r (exact->inexact w))
    (ftype-set! rectangle (height) r (exact->inexact h))
    (register-ftype-ptr! r)))

(define (make-camera2d target-x target-y offset-x offset-y zoom)
  (let ([c (make-ftype-pointer camera2d (foreign-alloc (ftype-sizeof camera2d)))])
    (ftype-set! camera2d (target-x) c (exact->inexact target-x))
    (ftype-set! camera2d (target-y) c (exact->inexact target-y))
    (ftype-set! camera2d (offset-x) c (exact->inexact offset-x))
    (ftype-set! camera2d (offset-y) c (exact->inexact offset-y))
    (ftype-set! camera2d (rotation) c 0.0)
    (ftype-set! camera2d (zoom)     c (exact->inexact zoom))
    c))

;;;; ============================================================
;;;; PREDEFINED COLORS
;;;; ============================================================

(define lightgray  (make-color 200 200 200 255))
(define gray       (make-color 130 130 130 255))
(define darkgray   (make-color  80  80  80 255))
(define yellow     (make-color 253 249   0 255))
(define gold       (make-color 255 203   0 255))
(define orange     (make-color 255 161   0 255))
(define pink       (make-color 255 109 194 255))
(define red        (make-color 230  41  55 255))
(define maroon     (make-color 190  33  45 255))
(define green      (make-color   0 228  48 255))
(define lime       (make-color   0 158  47 255))
(define darkgreen  (make-color   0 117  44 255))
(define skyblue    (make-color 102 191 255 255))
(define blue       (make-color   0 121 241 255))
(define darkblue   (make-color   0  82 172 255))
(define purple     (make-color 200 122 255 255))
(define violet     (make-color 135  60 190 255))
(define darkpurple (make-color 112  31 126 255))
(define beige      (make-color 211 176 131 255))
(define brown      (make-color 127 106  79 255))
(define darkbrown  (make-color  76  63  47 255))
(define white      (make-color 255 255 255 255))
(define black      (make-color   0   0   0 255))
(define blank      (make-color   0   0   0   0))
(define magenta    (make-color 255   0 255 255))
(define raywhite   (make-color 245 245 245 255))

;;;; ============================================================
;;;; CORE
;;;; ============================================================

(define init-window           (foreign-procedure "InitWindow"          (int int string) void))
(define close-window          (foreign-procedure "CloseWindow"         () void))
(define window-should-close   (foreign-procedure "WindowShouldClose"   () boolean))
(define is-window-ready       (foreign-procedure "IsWindowReady"       () boolean))
(define is-window-fullscreen  (foreign-procedure "IsWindowFullscreen"  () boolean))
(define is-window-hidden      (foreign-procedure "IsWindowHidden"      () boolean))
(define is-window-minimized   (foreign-procedure "IsWindowMinimized"   () boolean))
(define is-window-maximized   (foreign-procedure "IsWindowMaximized"   () boolean))
(define is-window-focused     (foreign-procedure "IsWindowFocused"     () boolean))
(define is-window-resized     (foreign-procedure "IsWindowResized"     () boolean))
(define set-window-title      (foreign-procedure "SetWindowTitle"      (string) void))
(define set-window-position   (foreign-procedure "SetWindowPosition"   (int int) void))
(define set-window-monitor    (foreign-procedure "SetWindowMonitor"    (int) void))
(define set-window-min-size   (foreign-procedure "SetWindowMinSize"    (int int) void))
(define set-window-size       (foreign-procedure "SetWindowSize"       (int int) void))
(define get-screen-width      (foreign-procedure "GetScreenWidth"      () int))
(define get-screen-height     (foreign-procedure "GetScreenHeight"     () int))

(define set-target-fps  (foreign-procedure "SetTargetFPS"  (int) void))
(define get-fps         (foreign-procedure "GetFPS"        () int))
(define get-frame-time  (foreign-procedure "GetFrameTime"  () float))
(define get-time        (foreign-procedure "GetTime"       () double))

;;;; ============================================================
;;;; DRAWING
;;;; ============================================================

(define clear-background    (foreign-procedure "ClearBackground"    ((& color)) void))
(define begin-drawing       (foreign-procedure "BeginDrawing"       () void))
(define end-drawing         (foreign-procedure "EndDrawing"         () void))

(define begin-mode-2d  (foreign-procedure "BeginMode2D"  ((& camera2d)) void))
(define end-mode-2d    (foreign-procedure "EndMode2D"    () void))

(define draw-pixel           (foreign-procedure "DrawPixel"          (int int (& color)) void))
(define draw-line            (foreign-procedure "DrawLine"            (int int int int (& color)) void))
(define draw-circle          (foreign-procedure "DrawCircle"          (int int float (& color)) void))
(define draw-rectangle       (foreign-procedure "DrawRectangle"       (int int int int (& color)) void))
(define draw-rectangle-rec   (foreign-procedure "DrawRectangleRec"    ((& rectangle) (& color)) void))
(define draw-rectangle-lines (foreign-procedure "DrawRectangleLines"  (int int int int (& color)) void))

(define draw-fps     (foreign-procedure "DrawFPS"    (int int) void))
(define draw-text    (foreign-procedure "DrawText"   (string int int int (& color)) void))
(define measure-text (foreign-procedure "MeasureText" (string int) int))

;;;; ============================================================
;;;; TEXTURES
;;;; ============================================================

(define load-texture-ffi (foreign-procedure "LoadTexture" (string) (& texture2d)))
(define (load-texture path)
  (let ([tex (make-ftype-pointer texture2d (foreign-alloc (ftype-sizeof texture2d)))])
    (load-texture-ffi tex path)
    tex))

(define unload-texture   (foreign-procedure "UnloadTexture"   ((& texture2d)) void))
(define draw-texture     (foreign-procedure "DrawTexture"     ((& texture2d) int int (& color)) void))
(define draw-texture-rec (foreign-procedure "DrawTextureRec"  ((& texture2d) (& rectangle) (& vector2) (& color)) void))
(define draw-texture-pro (foreign-procedure "DrawTexturePro"  ((& texture2d) (& rectangle) (& rectangle) (& vector2) float (& color)) void))

;;;; ============================================================
;;;; INPUT — RAW
;;;; ============================================================

(define is-key-pressed   (foreign-procedure "IsKeyPressed"   (int) boolean))
(define is-key-down      (foreign-procedure "IsKeyDown"      (int) boolean))
(define is-key-released  (foreign-procedure "IsKeyReleased"  (int) boolean))
(define is-key-up        (foreign-procedure "IsKeyUp"        (int) boolean))
(define set-exit-key     (foreign-procedure "SetExitKey"     (int) void))
(define get-key-pressed  (foreign-procedure "GetKeyPressed"  () int))
(define get-char-pressed (foreign-procedure "GetCharPressed" () int))

(define is-mouse-button-pressed  (foreign-procedure "IsMouseButtonPressed"  (int) boolean))
(define is-mouse-button-down     (foreign-procedure "IsMouseButtonDown"     (int) boolean))
(define is-mouse-button-released (foreign-procedure "IsMouseButtonReleased" (int) boolean))
(define is-mouse-button-up       (foreign-procedure "IsMouseButtonUp"       (int) boolean))
(define get-mouse-x              (foreign-procedure "GetMouseX"             () int))
(define get-mouse-y              (foreign-procedure "GetMouseY"             () int))
(define get-mouse-position-ffi   (foreign-procedure "GetMousePosition"      () (& vector2)))
(define (get-mouse-position)
  (let ([v (make-ftype-pointer vector2 (foreign-alloc (ftype-sizeof vector2)))])
    (get-mouse-position-ffi v)
    v))

;;;; ============================================================
;;;; AUDIO
;;;; ============================================================

(define init-audio-device     (foreign-procedure "InitAudioDevice"     () void))
(define close-audio-device    (foreign-procedure "CloseAudioDevice"    () void))
(define is-audio-device-ready (foreign-procedure "IsAudioDeviceReady"  () boolean))
(define set-master-volume     (foreign-procedure "SetMasterVolume"     (float) void))

(define load-sound-ffi (foreign-procedure "LoadSound" (string) (& sound)))
(define (load-sound path)
  (let ([s (make-ftype-pointer sound (foreign-alloc (ftype-sizeof sound)))])
    (load-sound-ffi s path)
    s))

(define unload-sound     (foreign-procedure "UnloadSound"     ((& sound)) void))
(define play-sound       (foreign-procedure "PlaySound"       ((& sound)) void))
(define stop-sound       (foreign-procedure "StopSound"       ((& sound)) void))
(define pause-sound      (foreign-procedure "PauseSound"      ((& sound)) void))
(define resume-sound     (foreign-procedure "ResumeSound"     ((& sound)) void))
(define is-sound-playing (foreign-procedure "IsSoundPlaying"  ((& sound)) boolean))

;;;; ============================================================
;;;; KEY CONSTANTS
;;;; ============================================================

(define key-space         32)
(define key-escape       256)
(define key-enter        257)
(define key-tab          258)
(define key-backspace    259)
(define key-insert       260)
(define key-delete       261)
(define key-right        262)
(define key-left         263)
(define key-down         264)
(define key-up           265)
(define key-f1           290)
(define key-f2           291)
(define key-f3           292)
(define key-f4           293)
(define key-f5           294)
(define key-f6           295)
(define key-f7           296)
(define key-f8           297)
(define key-f9           298)
(define key-f10          299)
(define key-f11          300)
(define key-f12          301)
(define key-left-shift   340)
(define key-left-control 341)
(define key-left-alt     342)
(define key-right-shift  344)
(define key-right-control 345)
(define key-right-alt    346)

(define key-zero  48) (define key-one   49) (define key-two   50)
(define key-three 51) (define key-four  52) (define key-five  53)
(define key-six   54) (define key-seven 55) (define key-eight 56)
(define key-nine  57)

(define key-a 65) (define key-b 66) (define key-c 67) (define key-d 68)
(define key-e 69) (define key-f 70) (define key-g 71) (define key-h 72)
(define key-i 73) (define key-j 74) (define key-k 75) (define key-l 76)
(define key-m 77) (define key-n 78) (define key-o 79) (define key-p 80)
(define key-q 81) (define key-r 82) (define key-s 83) (define key-t 84)
(define key-u 85) (define key-v 86) (define key-w 87) (define key-x 88)
(define key-y 89) (define key-z 90)

(define mouse-button-left   0)
(define mouse-button-right  1)
(define mouse-button-middle 2)
