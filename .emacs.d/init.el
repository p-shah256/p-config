;;;; init.el --- Emacs config -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

(require 'my-bootstrap)
(require 'my-base)
(when (file-directory-p (expand-file-name "~/fbsource/fbcode"))
  (require 'my-meta nil t))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   '("f1e8339b04aef8f145dd4782d03499d9d716fdc0361319411ac2efc603249326"
     "4b88b7ca61eb48bb22e2a4b589be66ba31ba805860db9ed51b4c484f3ef612a7"
     "e1df746a4fa8ab920aafb96c39cd0ab0f1bac558eff34532f453bd32c687b9d6"
     default))
 '(package-selected-packages
   '(ace-window cape company consult corfu corfu-terminal deferred
                doom-themes flycheck git git-gutter god-mode graphql
                hack-mode highlight-indent-guides let-alist lsp-ui
                magit magit-section marginalia modern-cpp-font-lock monky
                orderless pabbrev thrift transient tuareg vdiff
                vertico with-editor)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
