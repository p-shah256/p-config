;;;; early-init.el --- Early startup tweaks -*- lexical-binding: t; -*-

(setq package-enable-at-startup nil)
(setq package-quickstart t)
(setq frame-inhibit-implied-resize t)
(setq inhibit-compacting-font-caches t)
(setq-default bidi-display-reordering 'left-to-right)
(setq-default bidi-paragraph-direction 'left-to-right)
(setq bidi-inhibit-bpa t)

(defvar my-startup-file-name-handler-alist file-name-handler-alist)

(setq file-name-handler-alist nil)
(setq gc-cons-threshold most-positive-fixnum)
(setq gc-cons-percentage 0.6)

(defun my-restore-startup-settings ()
  "Restore startup settings after init completes."
  (setq file-name-handler-alist
        (delete-dups
         (append file-name-handler-alist my-startup-file-name-handler-alist)))
  (setq gc-cons-threshold (* 32 1024 1024))
  (setq gc-cons-percentage 0.1))

(add-hook 'emacs-startup-hook #'my-restore-startup-settings)
