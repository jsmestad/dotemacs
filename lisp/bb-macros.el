;;; bb-macros.el --- Macro definitions. -*- lexical-binding: t -*-

;; Copyright (C) 2018 Eivind Fonn

;; This file is not part of GNU Emacs.

;;; License:

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this file.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Miscellaneous macros needed in my Emacs init.

;;; Code:

(require 'hierarchy)
(require 'seq)


;;; Postpone code until after display is initialized

(defvar bb--after-display-functions nil
  "List of functions to be run (in reverse order) after the
display system is initialized.")

(defun bb--server-create-window-system-frame (&rest _)
  (dolist (func (reverse bb--after-display-functions))
    (funcall func))
  (advice-remove 'server-create-window-system-frame 'bb--server-create-window-system-frame))
(advice-add 'server-create-window-system-frame :after 'bb--server-create-window-system-frame)

(defmacro bb-after-display (&rest body)
  "Run BODY after the display system is initialized."
  (declare (indent 0))
  `(let ((initializedp (cond ((boundp 'ns-initialized) ns-initialized)
                             ((boundp 'w32-initialized) (font-family-list))
                             ((boundp 'x-initialized) x-initialized)
                             (t (display-graphic-p)))))
     (if initializedp
         (progn ,@body)
       (push (lambda () ,@body) bb--after-display-functions))))


;;; Convenience macro for hooks

(defmacro bb-add-hook (hook &rest body)
  "Run BODY in HOOK."
  (declare (indent 1))
  (let ((funcname (intern (format "bb-hook--%s" hook))))
    `(progn
       (defun ,funcname () ,@body)
       (add-hook ',hook ',funcname))))


;;; Convenience macro for advice

(defmacro bb-advise (type func arglist &rest body)
  (declare (indent 3))
  (unless arglist
    (setq arglist '(&rest _args)))
  (when (eq 'around type)
    (push 'orig-fn arglist))
  (let ((funcname (intern (format "bb-advise--%s--%s" func type)))
        (type (intern (format ":%s" type))))
    `(progn
       (defun ,funcname ,arglist
         ,@body)
       (advice-add ',func ,type ',funcname))))

(defmacro bb-advise-only-in-modes (func &rest modes)
  "Advice FUNC only to run when `major-mode' is exactly any of MODES."
  (declare (indent 1))
  (let ((funcname
         (intern (format "bb--only-in-modes-%s" (mapconcat 'symbol-name modes "-or-")))))
    `(progn
       (defun ,funcname (orig-fn &rest args)
         (when (or ,@(cl-loop for mode in modes collect `(eq major-mode ',mode)))
           (apply orig-fn args)))
       (advice-add ',func :around ',funcname))))

(defmacro bb-advise-except-derived-modes (func &rest modes)
  "Advice FUNC only to run when `major-mode' is derived from any of MODES."
  (declare (indent 1))
  (let ((funcname
         (intern (format "bb--except-derived-modes-%s" (mapconcat 'symbol-name modes "-or-")))))
    `(progn
       (defun ,funcname (orig-fn &rest args)
         (unless (derived-mode-p ,@(cl-loop for mode in modes collect `(quote ,mode)))
           (apply orig-fn args)))
       (advice-add ',func :around ',funcname))))


;;; Convenience functions for leader bindings

(declare-function 'general-define-key "general")

(defvar bb-leader-hierarchy
  (hierarchy-new)
  "Hierarchy of leader bindings.")

(defvar bb-leader-data
  (make-hash-table :test 'equal)
  "Data associated to leader bindings.")

(defun bb--normalize-keys (keys)
  "Normalize a key string to a vector."
  `[,@(seq-map 'identity (kbd keys))])

(defun bb--leader-parentfn (keys)
  "Parent function of key binding hieararchy."
  (when (< 0 (seq-length keys))
    (seq-subseq keys 0 -1)))

(defun bb-assign-leader (keys &optional func doc)
  "Associates data with a leader keybinding."
  (let* ((keys (bb--normalize-keys keys))
         (doc (or doc (cadr (gethash keys bb-leader-data))))
         (func (or func (car (gethash keys bb-leader-data)))))
    (hierarchy-add-tree bb-leader-hierarchy keys 'bb--leader-parentfn)
    (puthash keys `(,func ,doc) bb-leader-data)))

(defun bb-display-leaders (&optional arg)
  "Show a list of available leader bindings.
With one prefix argument: show only major mode bindings.
With two prefix arguments: show only global bindings."
  (interactive "p")
  (let ((mode major-mode)
        (show-global (or (not arg) (= 1 arg) (= 16 arg)))
        (show-dispatch (or (not arg) (= 1 arg) (= 4 arg))))
    (switch-to-buffer
     (hierarchy-tabulated-display
      bb-leader-hierarchy
      (lambda (item _indent)
        (when-let ((data (gethash item bb-leader-data)))
          (let* ((binding (car data))
                 (dispatchp (and (not (functionp binding)) (boundp binding)))
                 (binding (if dispatchp (bb--get-dispatch (symbol-value binding) mode) binding)))
            (when (and binding (if dispatchp show-dispatch show-global))
              (insert (propertize (key-description item) 'face
                                  (if dispatchp 'font-lock-type-face 'font-lock-keyword-face)))
              (insert (make-string (- 15 (current-column)) ? )
                      (or (cadr data) "??"))
              (insert (make-string (- 65 (current-column)) ? )
                      (propertize (format "%S" binding) 'face 'font-lock-comment-face))))))
      (get-buffer-create "leaders"))))
  (let ((inhibit-read-only t))
    (flush-lines "^$")
    (sort-lines nil (point-min) (point-max))))

(defmacro bb-leader (&rest args)
  "Bind ARGS as leader bindings."
  (declare (indent 0))
  `(progn
     (require 'general)
     ,@(cl-loop for (key func doc) in args
                collect
                `(progn
                   (when ,doc (bb-assign-leader ,key ,func ,doc))
                   (general-define-key :prefix "SPC" :states '(normal motion) :keymaps 'override ,key ,func)))))

(defun bb--get-dispatch (table mode)
  "Find a dispatch function in TABLE according to MODE."
  (cl-loop for entry in table
           if (provided-mode-derived-p mode (car entry))
           return (cdr entry)))

(defmacro bb-create-dispatch (keys)
  "Generate a major mode dispatch system for KEYS."
  (let ((funcname (intern (format "bb-dispatch-%s" keys)))
        (varname (intern (format "bb-dispatch-table-%s" keys))))
    `(progn
       (unless (boundp ',varname)
         (defvar ,varname nil)
         (defun ,funcname ()
           (interactive)
           (if-let ((dispatch (bb--get-dispatch ,varname major-mode)))
               (call-interactively dispatch)
             (user-error "No dispatch found for \"%s\" in %s" ,keys major-mode)))
         (bb-assign-leader ,keys ',varname nil)
         (bb-leader (,keys ',funcname))))))

(defmacro bb-mm-leader (mode &rest args)
  "Bind ARGS in MODE as leader bindings."
  (declare (indent 1))
  (let (bindings)
    (while args
      (push (cons (car args) (cadr args)) bindings)
      (setq args (cddr args)))
    `(progn
       ,@(cl-loop for binding in bindings
                  collect `(bb-create-dispatch ,(car binding)))
       ,@(cl-loop for binding in bindings
                  collect `(push (cons ',mode ,(cdr binding))
                                 ,(intern (format "bb-dispatch-table-%s" (car binding))))))))


;;; Company

(defvar bb-company-global-backends nil
  "List of backends to enable everywhere.")

(defmacro bb-company (mode &rest backends)
  "Run `company-mode' in MODE with BACKENDS."
  (declare (indent 1))
  (let ((funcname (intern (format "bb-company-%s" mode)))
        (hookname (intern (format "%s-hook" mode))))
    `(progn
       (defun ,funcname ()
         (company-mode)
         (setq-local company-backends
                     (list (append ',backends bb-company-global-backends))))
       (add-hook ',hookname ',funcname))))


;;; Miscellaneous

(defmacro bb-popwin (mode &rest args)
  "Push (MODE ARGS...) to `popwin:special-display-config'."
  `(push '(,mode ,@args) popwin:special-display-config))


(provide 'bb-macros)

;;; bb-macros.el ends here
