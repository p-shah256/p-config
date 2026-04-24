(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'bootstrap)
(require 'base)


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(ace-window breadcrumb cond-let consult corfu-terminal f git-gutter
		highlight-indent-guides magit multi-vterm orderless
		vertico with-editor)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
