;; Load Stylix base16 theme if it is available in the environment
(when (require 'base16-stylix-theme nil 'noerror)
  (setq doom-theme 'base16-stylix)
  (setq base16-theme-256-color-source 'colors))
