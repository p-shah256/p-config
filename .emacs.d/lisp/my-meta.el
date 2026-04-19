;;; my-meta.el --- Meta-specific Emacs layer -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(setq url-proxy-services
      '(("no_proxy" . "^\\(localhost\\|10.*\\)")
        ("http" . "fwdproxy:8080")
        ("https" . "fwdproxy:8080")))

;; newer emacs version may not load from "/usr/share/emacs/site-lisp"
;; so add the following to the load-path and restart emacs
(let ((default-directory "/usr/share/emacs/site-lisp"))
  (normal-top-level-add-to-load-path '(".")))

;; Configerator / Tupperware files should open as Python immediately,
;; even before fb-master finishes loading.
(dolist (pattern '("\\.cconf\\'"
                   "\\.cinc\\'"
                   "\\.ctest\\'"
                   "\\.mcconf\\'"
                   "\\.thrift-cvalidator\\'"
                   "\\.tw\\'"
                   "\\.sky\\'"
                   "\\/TARGETS\\'"
                   "\\/BUCK\\'"))
  (add-to-list 'auto-mode-alist `(,pattern . python-mode)))

(setq treesit-extra-load-path
      (append treesit-extra-load-path
              '("~/fbsource/fbcode/spidermate/repomate/repomate_agents/coverage_agents/function_call_graph/resources/")))

(my-run-with-idle 1.5 (lambda () (require 'codehub-url nil t)))

;; Load Meta's emacs packages directly from fbsource
(add-to-list 'load-path "~/fbsource/fbcode/emacs_config/emacs-packages")
(with-eval-after-load 'tramp
  (require 'tramp-utl nil t))

(defun my-myles-consult (arg)
  "Myles with file preview support."
  (interactive "p")
  (require 'myles)
  (let* ((old-default-directory default-directory)
         (default-directory
           (if (= arg 4)
               (myles--root)
             (myles--prefer-local-root-for-query)))
         (result
          (consult--read
           (consult--process-collection #'myles--arguments
             :file-handler t)
           :prompt "Files from Myles: "
           :category 'file
           :state (consult--file-state)
           :history 'myles-consult-history)))
    (let* ((default-directory old-default-directory)
           (default-directory (myles--root)))
      (find-file result))))

(global-set-key (kbd "C-c f") #'my-myles-consult)

;; BigGrep via consult (xbgr = regex, xbgs = string, xbgf = filename)
(defvar my-biggrep-history nil)

(defun my--biggrep-builder (cmd)
  "Return a builder function for BigGrep CMD."
  (lambda (input)
    (pcase-let ((`(,arg . ,opts) (consult--command-split input)))
      (when (>= (length arg) 3)
        (cons (list "bash" "-c"
                    (format "%s -s -n 50 %s -- %s | perl -pe 's/^([^:]*):([0-9]+):[0-9]+:/$1\\x00$2:/'"
                            cmd
                            (string-join opts " ")
                            (shell-quote-argument arg)))
              (apply-partially #'consult--highlight-regexps
                               (list (regexp-quote arg)) nil))))))

(defun my--biggrep-consult (cmd prompt)
  "Run a BigGrep CMD with consult async and preview."
  (let* ((default-directory (expand-file-name "~/fbsource/"))
         (builder (my--biggrep-builder cmd)))
    (consult--read
     (consult--process-collection builder
       :transform (consult--grep-format builder)
       :file-handler t)
     :prompt prompt
     :lookup #'consult--lookup-member
     :state (consult--grep-state)
     :category 'consult-grep
     :history '(:input my-biggrep-history)
     :sort nil)))

(defun my-xbgr-consult ()
  "Search fbsource with BigGrep regex via consult."
  (interactive)
  (my--biggrep-consult "xbgr" "BigGrep (regex): "))

(defun my-xbgs-consult ()
  "Search fbsource with BigGrep string match via consult."
  (interactive)
  (my--biggrep-consult "xbgs" "BigGrep (string): "))

(defun my-xbgf-consult ()
  "Search fbsource filenames with BigGrep via consult."
  (interactive)
  (let* ((default-directory (expand-file-name "~/fbsource/"))
         (builder (lambda (input)
                    (pcase-let ((`(,arg . ,opts) (consult--command-split input)))
                      (when (>= (length arg) 3)
                        (list "xbgf" "-s" "-n" "50" arg)))))
         (result
          (consult--read
           (consult--process-collection builder :file-handler t)
           :prompt "BigGrep (files): "
           :category 'file
           :state (consult--file-state)
           :history '(:input my-biggrep-history)
           :sort nil)))
    (when result
      (find-file (car (split-string result ":" t))))))

(global-set-key (kbd "C-c /") #'my-xbgr-consult)
(global-set-key (kbd "C-c .") #'my-xbgs-consult)
(global-set-key (kbd "C-c ,") #'my-xbgf-consult)

(require 'my-meta-completion)

(defvar my-fb-master-loaded nil)

(defun my-load-fb-master ()
  "Load Meta-specific development helpers once."
  (unless my-fb-master-loaded
    (setq fb-option-enable-company-commits nil
          fb-option-global-company-mode nil)
    (when (require 'fb-master nil t)
      (setq my-fb-master-loaded t)
      (setq read-process-output-max (* 1024 1024))
      (setq lsp-disabled-clients '(cppls cquery clangd))
      (require 'buck-build nil t)
      (when (fboundp 'flymake-arclint-setup)
        (add-hook 'c++-mode-hook #'flymake-arclint-setup))))
  (when (and (derived-mode-p 'c++-mode)
             (fboundp 'flymake-arclint-setup))
    (flymake-arclint-setup)))

(my-run-with-idle 2.0 #'my-load-fb-master)
(add-hook 'c-mode-common-hook #'my-load-fb-master)
(add-hook 'python-base-mode-hook #'my-load-fb-master)
(add-hook 'c++-mode-hook #'flymake-mode)

;; C++ LSP via eglot + cppls wrapper (from P1722009366 / P1687291760)
(with-eval-after-load 'eglot
  (defclass eglot-fb-cppls (eglot-lsp-server) ()
    :documentation "Custom class for Facebook's C++ language server.")
  (cl-defmethod eglot-initialization-options ((server eglot-fb-cppls))
    (let ((options (make-hash-table)))
      (puthash "buckAutoMode" "use GK vscode_cpp_build_combo" options)
      (puthash "fusionMode" "ClangD+Glean" options)
      options))
  (defvar cppls-wrapper
    (expand-file-name "~/.emacs.d/bin/cppls-wrapper"))
  (my-eglot-set-server my-eglot-cpp-modes
                       `(eglot-fb-cppls ,cppls-wrapper))
  (defvar pyls-wrapper
    (expand-file-name "~/.emacs.d/bin/pyls-wrapper"))
  (my-eglot-set-server my-eglot-python-modes
                       `(,pyls-wrapper))
  (require 'org-macs)
  (defun strip-activityKey (args)
    (cl-callf org-plist-delete (cl-second args) :activityKey)
    args)
  (advice-add #'jsonrpc-connection-receive :filter-args #'strip-activityKey))

;; Version control (Sapling/Mercurial)
(autoload 'hg-sl "hg-sl" nil t)
(autoload 'hg-blame-mode "hg-blame" nil t)
(global-set-key (kbd "C-c s") #'hg-sl)
(global-set-key (kbd "C-c b") #'hg-blame-mode)

(use-package monky
  :ensure t
  :bind ("C-c m" . monky-status))

;; Maple — Magit-like UI for Sapling (internal)
(autoload 'maple-status "maple" nil t)
(global-set-key (kbd "C-c g") #'maple-status)

;; Diffview — side-by-side vdiff for Sapling
(load "sl-diff")

;; Ediff: side-by-side, no separate control frame
(setq ediff-split-window-function 'split-window-horizontally)
(setq ediff-window-setup-function 'ediff-setup-windows-plain)

(with-eval-after-load 'git-gutter
  (setq git-gutter:handled-backends '(hg)))

(provide 'my-meta)

;;; my-meta.el ends here
