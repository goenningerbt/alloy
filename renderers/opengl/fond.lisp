#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(defpackage #:org.shirakumo.alloy.renderers.opengl.fond
  (:use #:cl)
  (:local-nicknames
   (#:alloy #:org.shirakumo.alloy)
   (#:simple #:org.shirakumo.alloy.renderers.simple)
   (#:opengl #:org.shirakumo.alloy.renderers.opengl)
   (#:font-discovery #:org.shirakumo.font-discovery))
  (:export
   #:*default-charset*
   #:renderer
   #:font
   #:charset
   #:base-size))
(in-package #:org.shirakumo.alloy.renderers.opengl.fond)

(defparameter *default-charset*
  " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~
¡¢£¤¥¦§¨©ª«¬­®¯°±²³´µ¶·¸¹º»¼½¾¿ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖ×ØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõö÷øùúûüýþÿ")

(defclass renderer (opengl:renderer)
  ((font-cache :initform () :accessor font-cache)))

(defmethod alloy:allocate :before ((renderer renderer))
  (setf (opengl:resource 'text-vbo renderer)
        (opengl:make-vertex-buffer renderer (make-array 0 :element-type 'single-float)
                                   :data-usage :dynamic-draw))
  (setf (opengl:resource 'text-ebo renderer)
        (opengl:make-vertex-buffer renderer (make-array 0 :element-type 'single-float)
                                   :buffer-type :element-array-buffer
                                   :data-usage :dynamic-draw))
  (setf (opengl:resource 'text-vao renderer)
        (opengl:make-vertex-array renderer `((,(opengl:resource 'text-vbo renderer) :size 2 :stride 16 :offset 0)
                                             (,(opengl:resource 'text-vbo renderer) :size 2 :stride 16 :offset 8)
                                             ,(opengl:resource 'text-ebo renderer))))
  (setf (opengl:resource 'text-shader renderer)
        (opengl:make-shader renderer
                            :vertex-shader "#version 330 core
layout (location=0) in vec2 pos;
layout (location=1) in vec2 in_uv;
uniform mat3 transform;
out vec2 uv;

void main(){
  gl_Position = vec4(transform*vec3(pos, 1), 1);
  uv = in_uv;
}"
                            :fragment-shader "#version 330 core
uniform sampler2D image;
uniform vec4 color;
in vec2 uv;
out vec4 out_color;

void main(){
  out_color = color * texture(image, uv, -0.65).r;
}")))

(defmethod alloy:deallocate :after ((renderer renderer))
  (setf (font-cache renderer) ()))

(defclass font (simple:font)
  ((atlas :accessor atlas)
   (charset :initarg :charset :initform *default-charset* :reader charset)
   (base-size :initarg :base-size :initform 24 :reader base-size)))

(defmethod ensure-font ((font simple:font) (renderer renderer))
  (loop for f in (font-cache renderer)
        do (when (or (eq font f)
                     (font= font f))
             (return f))
        finally (push (etypecase font
                        (font font)
                        (simple:font (change-class font 'font)))
                      (font-cache renderer))
                (return font)))

(defmethod font= ((a simple:font) (b simple:font))
  (and (equal (simple:family a) (simple:family b))
       (eql (simple:slant a) (simple:slant b))
       (eql (simple:spacing a) (simple:spacing b))
       (eql (simple:weight a) (simple:weight b))
       (eql (simple:stretch a) (simple:stretch b))))

(defmethod font= ((a font) (b font))
  (and (call-next-method)
       (string= (charset a) (charset b))
       (= (base-size a) (base-size b))))

(defmethod alloy:allocate ((font font))
  (unless (slot-boundp font 'atlas)
    (setf (atlas font) (cl-fond:make-font (simple:family font) (charset font)
                                          :size (base-size font)
                                          :oversample 2))))

(defmethod alloy:deallocate ((font font))
  (when (slot-boundp font 'atlas)
    (cl-fond:free (atlas font))
    (slot-makunbound font 'atlas)))

(defmethod simple:request-font ((renderer renderer) (fontspec string))
  (simple:request-font renderer (make-instance 'font :family fontspec)))

(defmethod simple:request-font ((renderer renderer) (fontspec pathname))
  (simple:request-font renderer (make-instance 'font :family fontspec)))

(defmethod simple:request-font ((renderer renderer) (font simple:font))
  (cond ((equal "" (simple:family font))
         (ensure-font (simple:request-font renderer :default) renderer))
        ((stringp (simple:family font))
         (let ((font (font-discovery:find-font
                      :family (family font)
                      :weight (weight font)
                      :stretch (stretch font)
                      :spacing (spacing font)
                      :slant (style font))))
           (make-instance 'font :family (font-discovery:file font)
                                :weight (font-discovery:weight font)
                                :stretch (font-discovery:stretch font)
                                :spacing (font-discovery:spacing font)
                                :slant (font-discovery:slant font))))
        (T
         (ensure-font font renderer))))

(defun text-point (point atlas text align direction vertical-align scale)
  (destructuring-bind (&key l r ((:t u)) b gap) (cl-fond:compute-extent atlas text)
    (declare (ignore gap))
    (ecase direction
      (:right
       (alloy:point
        (ecase align
          (:start
           (alloy:x point))
          (:middle
           (- (alloy:x point) (/ (* scale (- r l)) 2)))
          (:end
           (- (alloy:x point) (* scale (- r l)))))
        (ecase vertical-align
          (:bottom
           (alloy:y point))
          (:middle
           (- (alloy:y point) (/ (* scale (- u b)) 2)))
          (:top
           (- (alloy:y point) (* scale (- u b))))))))))

(defmethod simple:text ((renderer renderer) point string &key (font (simple:font renderer))
                                                              (size (simple:font-size renderer))
                                                              (align :start)
                                                              (direction :right)
                                                              (vertical-align :bottom))
  (let ((atlas (atlas font))
        (shader (opengl:resource 'text-shader renderer)))
    (opengl:bind shader)
    (gl:active-texture :texture0)
    (gl:bind-texture :texture-2d (cl-fond:texture atlas))
    (simple:with-pushed-transforms (renderer)
      (let ((s (* 2 (/ size (cl-fond:size atlas)))))
        (simple:translate renderer (text-point point atlas string align direction vertical-align s))
        (simple:scale renderer (alloy:size s s)))
      (setf (opengl:uniform shader "transform") (simple:transform-matrix (simple:transform renderer))))
    (setf (opengl:uniform shader "color") (simple:fill-color renderer))
    (let ((count (cl-fond:update-text atlas string
                                      (opengl:gl-name (opengl:resource 'text-vbo renderer))
                                      (opengl:gl-name (opengl:resource 'text-ebo renderer)))))
      (opengl:draw-vertex-array (opengl:resource 'text-vao renderer) :triangles count))))

;; KLUDGE: it's real stanky that we have to do this here.
(defmethod simple:render-presentation-content :before ((renderer renderer)
                                                       (presentation simple:presentation)
                                                       (component alloy:input-line)
                                                       extent)
  (when (eq :strong (alloy:focus-for component renderer))
    (let* ((font (simple:request-font
                  renderer
                  (make-instance 'font :family (simple:font-family presentation)
                                       :slant (simple:font-slant presentation)
                                       :spacing (simple:font-spacing presentation)
                                       :weight (simple:font-weight presentation)
                                       :stretch (simple:font-stretch presentation))))
           (text (subseq (alloy:text component) 0 (alloy:cursor component)))
           ;; FIXME: proper alignment in presence of image
           (s (* 2 (/ (simple:text-size presentation) (cl-fond:size (atlas font)))))
           (point (simple::align-point (simple:text-direction presentation)
                                       (simple:text-alignment presentation)
                                       (simple:text-vertical-alignment presentation)
                                       extent)))
      (destructuring-bind (&key l r ((:t u)) b gap) (cl-fond:compute-extent (atlas font) text)
        (declare (ignore gap))
        (let ((cursor (alloy:extent (+ (alloy:point-x point) (* s (- r l)))
                                    (- (alloy:point-y point) (/ (* s (- u b)) 2))
                                    (if (eq :down (simple:text-direction presentation))
                                        (* s (- u b))
                                        1)
                                    (if (eq :down (simple:text-direction presentation))
                                        1
                                        (* s (- u b))))))
          (simple:with-pushed-styles (renderer)
            (setf (simple:composite-mode renderer) :difference)
            (setf (simple:fill-color renderer) (simple:color 1 1 1))
            (setf (simple:fill-mode renderer) :fill)
            (when (< (+ (alloy:extent-x extent) (alloy:extent-w extent)) (+ (alloy:extent-x cursor) 2))
              (simple:translate renderer (alloy:point (- (+ (alloy:extent-x extent) (alloy:extent-w extent)) (alloy:extent-x cursor) 2) 0)))
            
            (simple:rectangle renderer cursor)))))))