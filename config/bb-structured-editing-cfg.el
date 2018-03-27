(defun bb-wrap-paren ()
  (interactive)
  (sp-wrap-with-pair "("))

(defhydra hydra-structured-editing-lisp ()
  ("u" undo-tree-undo)

  ("b" sp-forward-barf-sexp)
  ("B" sp-backward-barf-sexp)
  ("s" sp-forward-slurp-sexp)
  ("S" sp-backward-slurp-sexp)

  ("dd" sp-kill-sexp)
  ("ds" sp-kill-symbol)
  ("dw" sp-kill-word)

  ("w" bb-wrap-paren)

  ("h" sp-backward-symbol)
  ("<left>" sp-backward-sexp)
  ("l" sp-forward-symbol)
  ("<right>" sp-forward-sexp))
