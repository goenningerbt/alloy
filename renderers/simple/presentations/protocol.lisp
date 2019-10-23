#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy.renderers.simple.presentations)

(defclass renderer (simple:renderer)
  ())

(stealth-mixin:define-stealth-mixin shape () simple:shape
  ((name :initarg :name :initform NIL :reader name)
   (composite-mode :initarg :composite-mode :initform :source-over :accessor composite-mode)
   (z-index :initarg :z-index :initform 0 :accessor z-index)
   (offset :initarg :offset :initform (alloy:px-point 0 0) :accessor offset)
   (scale :initarg :scale :initform (alloy:px-size 1 1) :accessor scale)
   (rotation :initarg :rotation :initform 0f0 :accessor rotation)
   (pivot :initarg :pivot :initform (alloy:px-point 0 0) :accessor pivot)
   (hidden-p :initarg :hidden-p :initform NIL :accessor hidden-p)))

(stealth-mixin:define-stealth-mixin renderable () alloy:renderable
  ;; Reminder for future me: this has to be a vector for insertion order to stay correct.
  ((shapes :initform (make-array 0 :adjustable T :fill-pointer T) :accessor shapes)
   (update-overrides :initform () :accessor update-overrides)))

(defgeneric override-shapes (renderable shapes))
(defgeneric realize-renderable (renderer renderable))
(defgeneric update-shape (renderer renderable shape)
  (:method-combination progn :most-specific-last))
(defgeneric clear-shapes (renderable))
(defgeneric find-shape (id renderable &optional errorp))
(defgeneric (setf find-shape) (shape id renderable))

(defmacro define-realization ((renderer renderable) &body shapes)
  `(defmethod realize-renderable ((alloy:renderer ,renderer) (alloy:renderable ,renderable))
     (clear-shapes alloy:renderable)
     (symbol-macrolet ((alloy:focus (alloy:focus alloy:renderable))
                       (alloy:bounds (alloy:bounds alloy:renderable))
                       (alloy:value (alloy:value alloy:renderable)))
       (declare (ignorable alloy:focus alloy:bounds alloy:value))
       ,@(loop for shape in shapes
               collect (destructuring-bind ((name type) &body initargs) shape
                         `(setf (find-shape ',name alloy:renderable)
                                (make-instance ',type :name ',name ,@initargs)))))
     alloy:renderable))

(defmacro define-style ((renderer renderable) &body shapes)
  (let* ((default (find T shapes :key #'car))
         (shapes (if default (remove default shapes) shapes)))
    `(defmethod update-shape progn ((alloy:renderer ,renderer) (alloy:renderable ,renderable) (shape shape))
       (symbol-macrolet ((alloy:focus (alloy:focus alloy:renderable))
                         (alloy:bounds (alloy:bounds alloy:renderable))
                         (alloy:value (alloy:value alloy:renderable)))
         (declare (ignorable alloy:focus alloy:bounds alloy:value))
         (case (name shape)
           ,@(loop for (name . initargs) in shapes
                   collect `(,name (reinitialize-instance shape ,@initargs))))))))

(defmethod initialize-instance :around ((renderable renderable) &key style shapes)
  ;; Needs to be :AROUND to allow the subclass ALLOY:RENDERER to set the fields.
  (call-next-method)
  (when (and (not (slot-boundp renderable 'alloy:renderer)) (or style shapes))
    (arg! :renderer))
  ;; FIXME: this
  )

(defmethod alloy:register :around ((renderable renderable) (renderer renderer))
  ;; Needs to be :AROUND to allow the subclass ALLOY:RENDERER to set the fields.
  (call-next-method)
  (realize-renderable renderer renderable))

(defmethod alloy:render ((renderer renderer) (renderable renderable))
  (simple:with-pushed-transforms (renderer)
    (simple:translate renderer (alloy:bounds renderable))
    (loop for (name shape) across (shapes renderable)
          unless (hidden-p shape)
          do (simple:with-pushed-transforms (renderer)
               (setf (simple:composite-mode renderer) (composite-mode shape))
               (setf (simple:z-index renderer) (z-index shape))
               ;; TODO: Not sure this is quite right.
               (simple:translate renderer (offset shape))
               (simple:translate renderer (pivot shape))
               (simple:rotate renderer (rotation shape))
               (simple:scale renderer (scale shape))
               (simple:translate renderer (alloy:px-point (- (alloy:pxx (pivot shape)))
                                                          (- (alloy:pxy (pivot shape)))))
               (alloy:render renderer shape)))))

(defmethod realize-renderable ((renderer renderer) (renderable renderable)))

(defmethod clear-shapes ((renderable renderable))
  (setf (fill-pointer (shapes renderable)) 0))

(defmethod find-shape (id (renderable renderable) &optional errorp)
  (or (cdr (find id (shapes renderable) :key #'car))
      (when errorp (error "No such shape~%  ~s~%in~%  ~s"
                          id renderable))))

(defmethod (setf find-shape) ((shape shape) id (renderable renderable))
  (let ((record (find id (shapes renderable) :key #'car)))
    (if record
        (setf (cdr record) shape)
        (vector-push-extend (cons id shape) (shapes renderable)))
    shape))

(defmethod (setf find-shape) ((null null) id (renderable renderable))
  (let ((pos (position id (shapes renderable) :key #'car)))
    (when pos
      (setf (shapes renderable) (array-utils:vector-pop-position (shapes renderable) pos)))))

(defmethod update-shape :around ((renderer renderer) (renderable renderable) (shape shape))
  (call-next-method)
  (let ((initargs (cdr (assoc shape (update-overrides renderable)))))
    (when initargs
      (apply #'reinitialize-instance shape initargs))))

(defmethod update-shape progn ((renderer renderer) (renderable renderable) (all (eql T)))
  (loop for (name . shape) across (shapes renderable)
        do (update-shape renderer renderable shape)))

(defmethod alloy:mark-for-render :after ((renderable renderable))
  ;; FIXME: Maybe there's a better way to do this, such as
  ;;        marking and then updating on next full render.
  (update-shape (alloy:renderer renderable) renderable T))
