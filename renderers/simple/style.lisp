#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy.renderer.simple)

(defclass style ()
  ((fill-color :reader fill-color)
   (font :reader font)
   (font-size :reader font-size)
   (line-width :reader line-width)
   (fill-mode :reader fill-mode)
   (composite-mode :reader composite-mode)))

(defmethod shared-initialize :after ((style style) slots &key fill-color font font-size line-width fill-mode composite-mode)
  (macrolet ((update-slot (slot)
               `(when ,slot (setf (,slot style) ,slot))))
    (update-slot fill-color)
    (update-slot font)
    (update-slot font-size)
    (update-slot line-width)
    (update-slot fill-mode)
    (update-slot composite-mode)))

(defmethod initialize-instance :after ((style style) &key parent)
  (macrolet ((init-slot (slot)
               `(unless (slot-boundp style ',slot)
                  (unless parent (error "The style property ~s is not set!"
                                        ',slot))
                  (setf (,slot style) (,slot parent)))))
    (init-slot fill-color)
    (init-slot font)
    (init-slot font-size)
    (init-slot line-width)
    (init-slot fill-mode)
    (init-slot composite-mode)))

(defmethod (setf fill-color) ((color color) (style style))
  (setf (slot-value style 'color) color))

(defmethod (setf line-width) ((width float) (style style))
  (setf (slot-value style 'line-width) width))

(defmethod (setf fill-mode) ((mode symbol) (style style))
  (setf (slot-value style 'fill-mode) mode))

(defmethod (setf composite-mode) ((mode symbol) (style style))
  (setf (slot-value style 'composite-mode) mode))

(defmethod (setf font) ((font font) (style style))
  (setf (slot-value style 'font) font))

(defmethod (setf font-size) ((size float) (style style))
  (setf (slot-value style 'font-size) size))

(defclass simple-styled-renderer (simple-renderer)
  ((style-stack :accessor style-stack)))

(defmethod initialize-instance :after ((renderer simple-styled-renderer) &key)
  (setf (style-stack renderer) (list (make-default-style renderer))))

(defgeneric make-default-style (renderer))

(defmethod make-default-style ((renderer simple-styled-renderer))
  (make-instance 'style :fill-color (color 1 1 1)
                        :line-width 1.0f0
                        :fill-mode :lines
                        :composite-mode :source-over
                        :font (request-font renderer "sans-serif")
                        :font-size 12.0f0))

(defmethod push-styles ((renderer simple-styled-renderer))
  (let ((current (car (style-stack renderer))))
    (push (make-instance (class-of current) :parent current)
          (style-stack renderer))))

(defmethod pop-styles ((renderer simple-styled-renderer))
  (pop (style-stack renderer))
  (unless (style-stack renderer)
    (setf (style-stack renderer) (list (make-default-style renderer)))))

(defmethod fill-color ((renderer simple-styled-renderer))
  (fill-color (car (style-stack renderer))))

(defmethod (setf fill-color) (color (renderer simple-styled-renderer))
  (setf (fill-color (car (style-stack renderer))) color))

(defmethod line-width ((renderer simple-styled-renderer))
  (line (car (style-stack renderer))))

(defmethod (setf line-width) (width (renderer simple-styled-renderer))
  (setf (line-width (car (style-stack renderer))) width))

(defmethod fill-mode ((renderer simple-styled-renderer))
  (fill-mode (car (style-stack renderer))))

(defmethod (setf fill-mode) (mode (renderer simple-styled-renderer))
  (setf (fill-mode (car (style-stack renderer))) mode))

(defmethod composite-mode ((renderer simple-styled-renderer))
  (composite-mode (car (style-stack renderer))))

(defmethod (setf composite-mode) (mode (renderer simple-styled-renderer))
  (setf (composite-mode (car (style-stack renderer))) mode))

(defmethod font ((renderer simple-styled-renderer))
  (font (car (style-stack renderer))))

(defmethod (setf font) (font (renderer simple-styled-renderer))
  (setf (font (car (style-stack renderer))) font))

(defmethod font-size ((renderer simple-styled-renderer))
  (font (car (style-stack renderer))))

(defmethod (setf font-size) (size (renderer simple-styled-renderer))
  (setf (font-size (car (style-stack renderer))) size))