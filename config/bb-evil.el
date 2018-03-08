(bb-package evil
  :init
  (setq-default
   evil-normal-state-cursor '("DarkGoldenrod2" box)
   evil-insert-state-cursor '("chartreuse3" (bar . 2))
   evil-emacs-state-cursor '("SkyBlue2" box)
   evil-replace-state-cursor '("chocolate" (hbar . 2))
   evil-visual-state-cursor '("gray" (hbar . 2))
   evil-motion-state-cursor '("plum3" box))
  (require 'evil)
  (evil-mode)
  (define-key evil-motion-state-map (kbd "SPC") nil))
