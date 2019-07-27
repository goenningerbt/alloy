#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy)

(defclass element ()
  ())

(defclass container ()
  ())

(defgeneric enter (element container &key &allow-other-keys))
(defgeneric leave (element container))
(defgeneric update (element container &key &allow-other-keys))
(defgeneric elements (container))
(defgeneric call-with-elements (function container))

(defmacro do-elements ((element container &optional result) &body body)
  (let ((thunk (gensym "THUNK")))
    `(flet ((,thunk (,element)
              ,@body))
       (block NIL
         (call-with-elements #',thunk ,container))
       ,result)))

(defmethod describe-object :after ((container container) stream)
  (format stream "~&~%Container Tree:~%")
  (let ((*level* 0))
    (declare (special *level*))
    (labels ((traverse (thing)
               (format stream "~v{ ~}~a~%" (* *level* 2) '(0) thing)
               (when (typep thing 'container)
                 (let ((*level* (1+ *level*)))
                   (declare (special *level*))
                   (do-elements (element thing)
                     (traverse element))))))
      (traverse container))))

(defclass vector-container (container)
  ((elements :initform (make-array 0 :adjustable T :fill-pointer T) :reader elements)))

(defmethod enter ((element element) (container vector-container) &key index)
  (if index
      (array-utils:vector-push-extend-position element (elements container) index)
      (vector-push-extend element (elements container)))
  element)

(defmethod leave ((element element) (container vector-container))
  (array-utils:vector-pop-position (elements container) (position element (elements container)))
  element)

(defmethod update ((element element) (container vector-container) &key index)
  (when index
    (let ((pos (position element (elements container))))
      (array-utils:vector-pop-position (elements container) pos)
      (array-utils:vector-push-extend-position element (elements container) index)))
  element)

(defmethod call-with-elements (function (container vector-container))
  (loop for element across (elements container)
        do (funcall function element)))

(defclass element-table ()
  ((component-map :initform (make-hash-table :test 'eq) :reader component-map)))

(defgeneric associate (element component element-table))
(defgeneric disassociate (element component element-table))
(defgeneric associated-element (component element-table))

(defmethod associate ((element element) (component component) (table element-table))
  (let ((pelm (gethash component (component-map table)))
        (pcomp (gethash element (component-map table))))
    (unless (or (not pelm) (eq pelm element))
      (error "The component~%  ~a~%is already associated with the element~%  ~a~%in~%  ~a"
             component pelm table))
    (unless (or (not pcomp) (eq pcomp component))
      (error "The element~%  ~a~%is already associated with the component~%  ~a~%in~%  ~a"
             element pcomp table))
    (setf (gethash component (component-map table)) element)
    (setf (gethash element (component-map table)) component)
    element))

(defmethod disassociate ((element element) (component component) (table element-table))
  (unless (eq element (gethash component (component-map table)))
    (error "The element~%  ~a~%is not associated with the component~%  ~a~%in~%  ~a"
           element component table))
  (remhash component (component-map table))
  (remhash element (component-map table))
  element)

(defmethod associated-element ((component component) (table element-table))
  (or (gethash component (component-map table))
      (error "The component~%  ~a~%is not associated with any element in~%  ~a"
             component table)))
