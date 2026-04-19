;;; my-completion.el --- Local in-buffer completion setup -*- lexical-binding: t; -*-

;;; Code:

(use-package corfu
  :ensure t
  :init
  (setq corfu-auto t
        corfu-auto-delay 0.2
        corfu-auto-prefix 1
        corfu-cycle t
        corfu-preview-current nil
        tab-always-indent 'complete)
  :config
  (global-corfu-mode 1)
  (define-key corfu-map (kbd "C-n") #'corfu-next)
  (define-key corfu-map (kbd "C-p") #'corfu-previous)
  (when (and (not (display-graphic-p))
             (require 'corfu-terminal nil t))
    (corfu-terminal-mode 1)))

(use-package cape
  :ensure t
  :defer t)

(defun my-prog-completion-setup ()
  "Append generic CAPFs behind language-server completion."
  (when (featurep 'corfu)
    (corfu-mode 1))
  (local-set-key (kbd "M-/") #'completion-at-point)
  (add-hook 'completion-at-point-functions #'cape-file t t)
  (add-hook 'completion-at-point-functions #'cape-dabbrev t t))

(add-hook 'prog-mode-hook #'my-prog-completion-setup)

(provide 'my-completion)

;;; my-completion.el ends here
