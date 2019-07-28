#|
 This file is a part of Alloy
 (c) 2019 Shirakumo http://tymoon.eu (shinmera@tymoon.eu)
 Author: Nicolas Hafner <shinmera@tymoon.eu>
|#

(in-package #:org.shirakumo.alloy)

(defgeneric handle (event handler context))

(defclass event ()
  ())

(defun decline ()
  (invoke-restart 'decline))

(defmethod handle :around ((event event) handler context)
  (restart-case
      (prog1 T
        (call-next-method))
    (decline ()
      :report (lambda (s) (format s "Decline handling ~a" event))
      NIL)))

(defclass pointer-event (event)
  ((point :initarg :point :initform (error "POINT required") :reader point)))

(defclass pointer-move (pointer-event)
  ((old-point :initarg :old-point :initform (error "OLD-POINT required") :reader old-point)))

(defclass pointer-down (pointer-event)
  ((kind :initarg :kind :initform :left :reader kind)))

(defclass pointer-up (pointer-event)
  ((kind :initarg :kind :initform :left :reader kind)))

(defclass scroll (pointer-event)
  ())

(defclass direct-event (event)
  ())

(defclass text-event (direct-event)
  ((text :initarg :text :initform (error "TEXT required.") :reader text)))

(defclass key-event (direct-event)
  ((key :initarg :key :initform (error "KEY required.") :reader key)
   (code :initarg :code :initform (error "CODE required.") :reader code)))

(defclass key-down (key-event)
  ())

(defclass key-up (key-event)
  ())

(defclass focus-event (direct-event)
  ())

(defclass focus-next (focus-event)
  ())

(defclass focus-prev (focus-event)
  ())

(defclass focus-up (focus-event)
  ())

(defclass focus-down (focus-event)
  ())

(defclass activate (focus-event)
  ())

(defclass exit (focus-event)
  ())
