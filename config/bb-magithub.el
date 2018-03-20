(bb-package magithub
  :init
  (setq magithub-clone-default-directory "~/repos"
        magithub-dir (bb-dir "magithub"))

  :post-init magit
  (with-eval-after-load 'magit
    (require 'magithub)
    (magithub-feature-autoinject 'all)))