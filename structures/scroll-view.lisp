#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy)

(defclass scroll-view (structure)
  ())

(defmethod initialize-instance :after ((structure scroll-view) &key layout focus layout-parent focus-parent (scroll T))
  (let ((border-layout (make-instance 'border-layout :layout-parent layout-parent))
        (focus-list (make-instance 'focus-list :focus-parent focus-parent))
        (clipper (make-instance 'clip-view :limit (ecase scroll
                                                    ((T) NIL)
                                                    (:x :y)
                                                    (:y :x)))))
    (enter clipper border-layout :place :center)
    (enter layout clipper)
    (when focus
      (enter focus focus-list))
    (when (or (eql scroll T) (eql scroll :y))
      (let ((scrollbar (represent-with 'y-scrollbar clipper)))
        (enter scrollbar border-layout :place :east :size (un 20))
        (enter scrollbar focus-list)))
    (when (or (eql scroll T) (eql scroll :x))
      (let ((scrollbar (represent-with 'x-scrollbar clipper)))
        (enter scrollbar border-layout :place :south :size (un 20))
        (enter scrollbar focus-list)))
    (finish-structure structure border-layout focus-list)))
