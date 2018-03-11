(bb-package helm

  :init
  (push "\\*helm.+\\*" bb-useless-buffers-regexp)

  (setq helm-display-function 'bb-helm-display-child-frame
        helm-display-buffer-reuse-frame t
        helm-display-buffer-width 120
        helm-display-buffer-height 25)
  (add-hook 'helm-minibuffer-set-up-hook 'helm-hide-minibuffer-maybe)
  (with-eval-after-load 'helm
    (define-key helm-map (kbd "<right>") 'helm-maybe-exit-minibuffer))
  (with-eval-after-load 'helm-files
    (define-key helm-find-files-map (kbd "<right>") 'helm-ff-RET)
    (advice-add 'helm-ff-filter-candidate-one-by-one
                :around 'bb-helm-ff-filter-candidate-one-by-one)
    (advice-add 'helm-find-files-up-one-level
                :around 'bb-helm-find-files-up-one-level))
  (with-eval-after-load 'helm-imenu
    (define-key helm-imenu-map (kbd "<right>") 'helm-maybe-exit-minibuffer))
  (helm-mode)
  (diminish 'helm-mode)

  :post-init general
  (bb-leader
    "SPC" 'helm-M-x
    "bb" 'helm-mini
    "ff" 'helm-find-files
    "fl" 'helm-locate-library
    "hh" 'bb-helm-config
    "ji" 'helm-imenu))
