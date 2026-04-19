;;;; init.el --- Emacs config -*- lexical-binding: t; -*-


(when (featurep 'native-compile)
  (setq native-comp-speed 2)
  (setq native-comp-async-report-warnings-errors nil))

(defun my-run-with-idle (delay fn)
  "Run FN once after DELAY seconds of idle time after startup."
  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-idle-timer delay nil fn))))

(setq url-proxy-services
   '(("no_proxy" . "^\\(localhost\\|10.*\\)")
     ("http" . "fwdproxy:8080")
     ("https" . "fwdproxy:8080")))

(require 'package)
(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/"))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;;; Sane Defaults for Vanilla Emacs
;; 1. User Interface Tweaks
(setq inhibit-startup-message t)
(setq vc-handled-backends nil)
(tool-bar-mode -1)                  ; Hide the clunky, outdated toolbar
(scroll-bar-mode -1)                ; Hide the scrollbar (use keyboard navigation!)
(menu-bar-mode -1)
(setq display-line-numbers-type 'relative) ;; Enable relative line numbers

(defun my-heavy-ui-buffer-p ()
  "Return non-nil when expensive UI helpers should stay off in this buffer."
  (or (minibufferp)
      (not buffer-file-name)
      (file-remote-p default-directory)
      (> (buffer-size) (* 512 1024))))

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

(defun my-enable-line-numbers-maybe ()
  "Enable line numbers only in small local editing buffers."
  (unless (or (my-heavy-ui-buffer-p)
              (derived-mode-p 'special-mode 'comint-mode 'term-mode
                              'eshell-mode 'shell-mode 'vterm-mode))
    (display-line-numbers-mode 1)))

;; 2. Display & Formatting Settings
(add-hook 'prog-mode-hook #'my-enable-line-numbers-maybe)
(add-hook 'conf-mode-hook #'my-enable-line-numbers-maybe)
(column-number-mode 1)               ; Show column numbers in the bottom mode line
(show-paren-mode 1)                  ; Highlight matching parentheses
(global-font-lock-mode 1)            ; Syntax highlighting in all buffers
(global-so-long-mode 1)              ; Keep huge / pathological files responsive
(setq-default indent-tabs-mode nil)  ; Use spaces instead of actual tab characters
(setq-default tab-width 4)           ; Set default tab width to 4 spaces
(setq require-final-newline t)       ; Always cleanly end files with a newline
(setq sentence-end-double-space nil) ; Use a single space after periods for sentences

;; 3. Editor Behavior
(defalias 'yes-or-no-p 'y-or-n-p)    ; Replace tedious "yes/no" prompts with simple "y/n"
(setq ring-bell-function 'ignore)    ; Disable the annoying visual/audio bell
;; Smooth scrolling (prevents screen jumping when the cursor hits the bottom)
(setq redisplay-skip-fontification-on-input t)
(setq fast-but-imprecise-scrolling t)
(setq auto-window-vscroll nil)
(setq scroll-conservatively 100)
(setq scroll-margin 2)               ; Leave a 2-line margin at the top/bottom

;; 4. File and Backup Management
(setq global-auto-revert-non-file-buffers t) ; Also auto-refresh Dired buffers

;; Stop cluttering directories with backup (~ files) and auto-save (# files)
;; Instead, save them all to a centralized directory in ~/.emacs.d
(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))
(setq auto-save-file-name-transforms '((".*" "~/.emacs.d/auto-save-list/" t)))
(setq create-lockfiles nil)          ; Stop creating .# lockfiles

;; 5. Minibuffer Completion (The "fzf" feel)
;; Enables a vertical, fuzzy-matching UI for all Emacs commands
;; (fido-vertical-mode 1)

;; 6. Recent Files Tracking
(autoload 'savehist-mode "savehist" nil t)
(autoload 'recentf-cleanup "recentf" nil t)
(autoload 'recentf-mode "recentf" nil t)
(autoload 'winner-mode "winner" nil t)
(autoload 'whitespace-mode "whitespace" nil t)

(defvar recentf-exclude nil)
(setq recentf-max-saved-items 200) ; Remember the last 200 files
(setq recentf-auto-cleanup 'never)

(with-eval-after-load 'recentf
  ;; Keep the list clean by ignoring Emacs background files.
  (add-to-list 'recentf-exclude "\\.emacs\\.d/.*")
  (add-to-list 'recentf-exclude "/elpa/.*")
  (add-to-list 'recentf-exclude "/auto-save-list/.*"))

;; Create a command that feeds the recent files into our fuzzy finder
(defun my-find-recent-file ()
  "Fuzzy-find a recently opened file."
  (interactive)
  (require 'recentf)
  (let ((file (completing-read "Recent files: " recentf-list nil t)))
    (when file
      (find-file file))))
;; Bind it to Ctrl-c r (or any key you prefer)
(global-set-key (kbd "C-c r") 'my-find-recent-file)

(my-run-with-idle 0.3 #'savehist-mode)
(my-run-with-idle 0.5 #'server-start)
(my-run-with-idle 0.8 #'global-auto-revert-mode)
(my-run-with-idle
 1.0
 (lambda ()
   (require 'recentf)
   (recentf-mode 1)
   (recentf-cleanup)))
(my-run-with-idle 1.2 #'winner-mode)
;; Some theme face specs reference whitespace faces during load.
(require 'whitespace)
(my-run-with-idle 0.1 (lambda () (load-theme 'wombat t)))

(setq treesit-extra-load-path
      '("~/.emacs.d/tree-sitter/"
        "~/fbsource/fbcode/spidermate/repomate/repomate_agents/coverage_agents/function_call_graph/resources/"))
(setq treesit-font-lock-level 3)
(setq jit-lock-defer-time 0.1)
(setq jit-lock-chunk-size 1000)
(setq jit-lock-stealth-time nil)

;; DEBUG: benchmark file-open hooks
(defun my-benchmark-open (file)
  "Open FILE and time each major hook."
  (interactive "fFile: ")
  (let* ((git-gutter-mode-on-p (bound-and-true-p global-git-gutter-mode))
         (t0 (float-time)) t1 t2 t3 t4)
    ;; Phase 1: no git-gutter, no eglot, no font-lock
    (when git-gutter-mode-on-p (global-git-gutter-mode -1))
    (let ((eglot-ensure-fn (symbol-function 'eglot-ensure)))
      (cl-letf (((symbol-function 'eglot-ensure) #'ignore)
                (font-lock-mode nil))
        (find-file file)
        (setq t1 (float-time))
        (font-lock-ensure)
        (setq t2 (float-time))
        (kill-buffer)))
    ;; Phase 2: full open
    (when git-gutter-mode-on-p (global-git-gutter-mode 1))
    (find-file file)
    (setq t3 (float-time))
    (message "Base open: %.3fs | font-lock: %.3fs | git-gutter+eglot+rest: %.3fs | TOTAL: %.3fs"
             (- t1 t0) (- t2 t1) (- t3 t2) (- t3 t0))))

(defvar my-treesit-mode-remap
  '((c . (c-mode . c-ts-mode))
    (cpp . (c++-mode . c++-ts-mode))
    (python . (python-mode . python-ts-mode))
    (bash . (sh-mode . bash-ts-mode))
    (go . (go-mode . go-ts-mode))
    (rust . (rust-mode . rust-ts-mode))
    (java . (java-mode . java-ts-mode))
    (javascript . (javascript-mode . js-ts-mode))
    (json . (json-mode . json-ts-mode))
    (yaml . (yaml-mode . yaml-ts-mode))
    (toml . (conf-toml-mode . toml-ts-mode))))

(dolist (entry my-treesit-mode-remap)
  (when (treesit-language-available-p (car entry))
    (add-to-list 'major-mode-remap-alist (cdr entry))))

;;; Treesitter Context — sticky scope lines at top of window
(defface ts-context-face
  '((t :inherit header-line :extend t))
  "Face for treesitter context overlay lines.")

(defface ts-context-separator-face
  '((t :inherit ts-context-face :underline t))
  "Face for the last treesitter context line (separator).")

(defvar ts-context--types
  (let ((ht (make-hash-table :test 'equal)))
    (dolist (ty '("function_definition" "function_declaration"
                  "method_definition" "method_declaration"
                  "class_definition" "class_declaration"
                  "if_statement" "elif_clause" "else_clause"
                  "for_statement" "for_in_statement"
                  "while_statement" "with_statement"
                  "try_statement" "except_clause"
                  "match_statement" "case_clause"
                  "struct_specifier" "namespace_definition"))
      (puthash ty t ht))
    ht))

(defvar-local ts-context--timer nil)
(defvar-local ts-context--overlays nil)
(defvar-local ts-context--last-render nil)
(defconst ts-context-idle-delay 0.25)
(defconst ts-context-max-buffer-size (* 256 1024))

(defun ts-context--get ()
  (let ((node (treesit-node-at (point)))
        parts
        seen-lines)
    (while node
      (when (gethash (treesit-node-type node) ts-context--types)
        (let* ((start (treesit-node-start node))
               (start-line (line-number-at-pos start)))
          (unless (memq start-line seen-lines)
            (push start-line seen-lines)
            (let ((line (buffer-substring-no-properties
                         (save-excursion (goto-char start) (line-beginning-position))
                         (save-excursion (goto-char start) (line-end-position)))))
              (push line parts)))))
      (setq node (treesit-node-parent node)))
    parts))

(defun ts-context--enabled-p ()
  (and (bound-and-true-p ts-context-mode)
       (treesit-parser-list)
       (< (buffer-size) ts-context-max-buffer-size)))

(defun ts-context--target-window (window)
  (cond
   ((and (window-live-p window)
         (eq (window-buffer window) (current-buffer)))
    window)
   ((eq (window-buffer (selected-window)) (current-buffer))
    (selected-window))
   (t
    (get-buffer-window (current-buffer) 0))))

(defun ts-context--clear ()
  (mapc #'delete-overlay ts-context--overlays)
  (setq ts-context--overlays nil)
  (setq ts-context--last-render nil))

(defun ts-context--render (parts window)
  (let* ((ws (window-start window))
         (lnw (if (bound-and-true-p display-line-numbers-mode)
                  (line-number-display-width 'columns)
                0))
         (render-state (list ws lnw parts)))
    (unless (equal render-state ts-context--last-render)
      (ts-context--clear)
      (setq ts-context--last-render render-state)
      (when parts
        (save-excursion
          (goto-char ws)
          (dotimes (i (length parts))
            (when (< (point) (point-max))
              (let* ((bol (line-beginning-position))
                     (eol (line-end-position))
                     (ov (make-overlay bol (min (1+ eol) (point-max)) nil t t))
                     (text (nth i parts))
                     (face (if (= i (1- (length parts)))
                               'ts-context-separator-face
                             'ts-context-face))
                     (prefix (when (> lnw 0)
                               (propertize " " 'display
                                           `(space :width ,lnw)))))
                (overlay-put ov 'display
                             (propertize (concat text "\n") 'face face))
                (when prefix
                  (overlay-put ov 'line-prefix prefix))
                (overlay-put ov 'priority 1000)
                (overlay-put ov 'window window)
                (push ov ts-context--overlays)
                (forward-line 1)))))))))

(defun ts-context--update (buffer window)
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (let ((target-window (ts-context--target-window window)))
        (if (not (and target-window (ts-context--enabled-p)))
            (ts-context--clear)
          (ts-context--render (ts-context--get) target-window))))))

(defun ts-context--schedule ()
  (when ts-context--timer
    (cancel-timer ts-context--timer))
  (setq ts-context--timer
        (run-with-idle-timer ts-context-idle-delay nil
                             #'ts-context--update
                             (current-buffer)
                             (selected-window))))

(defun ts-context--on-scroll (_win _pos)
  (ts-context--schedule))

(define-minor-mode ts-context-mode
  "Show enclosing scope context at top of window."
  :lighter " ctx"
  (if ts-context-mode
      (progn
        (add-hook 'post-command-hook #'ts-context--schedule nil t)
        (add-hook 'window-scroll-functions #'ts-context--on-scroll nil t))
    (remove-hook 'post-command-hook #'ts-context--schedule t)
    (remove-hook 'window-scroll-functions #'ts-context--on-scroll t)
    (ts-context--clear)
    (when ts-context--timer (cancel-timer ts-context--timer))))

(defun my-enable-ts-context-maybe ()
  "Enable treesitter context in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (when (treesit-parser-list)
      (ts-context-mode 1))))

(add-hook 'prog-mode-hook #'my-enable-ts-context-maybe)
(global-set-key (kbd "C-c t c") #'ts-context-mode)

;; ATM i don't really see a lot of value in god mode, as in general
;; using esc will prefix with M by default, plus its just one time
;; the overhead with godmode is i need to turn it off so not very
;; efficient for one command
;; (use-package god-mode
;;   :ensure t
;;   :config
;;   (global-set-key (kbd "<escape>") 'god-local-mode)

;;   (defun my-god-mode-update-cursor ()
;;     (setq cursor-type (if (or god-local-mode buffer-read-only) 'box 'bar)))
;;   (add-hook 'post-command-hook 'my-god-mode-update-cursor))

;; Terminal key remaps: ESC and C-Backspace are ambiguous over terminal/SSH.
;; Fix: configure your terminal emulator to send unique sequences for these
;; keys, then decode them here.
;; ESC key → send "\e[27;0;27~" → decoded as <escape> (not Alt prefix)
;; C-Backspace → send "\e[27;5;127~" → decoded as C-backspace (not C-h)
(unless (display-graphic-p)
  ;; (define-key input-decode-map "\e[27;0;27~" [escape])
  (define-key input-decode-map "\e[27;5;127~" [C-backspace])
  (define-key input-decode-map "\e[27;6;127~" [C-S-backspace])
  (define-key input-decode-map "\e[27;5;45~" [C--]))
(global-set-key [C-backspace] 'backward-kill-word)
(global-set-key [C-S-backspace] 'kill-whole-line)
(global-set-key [C--] 'undo)

(defun copy-file-location ()
  "Copy file:line or file:linestart-lineend to kill ring."
  (interactive)
  (let ((loc (if (use-region-p)
                 (format "%s:%d-%d"
                         (buffer-file-name)
                         (line-number-at-pos (region-beginning))
                         (line-number-at-pos (region-end)))
               (format "%s:%d"
                       (buffer-file-name)
                       (line-number-at-pos)))))
    (kill-new loc)
    (message "%s" loc)))
(global-set-key (kbd "C-c l") 'copy-file-location)

(setq whitespace-style '(face indentation))
(autoload 'highlight-indent-guides-mode "highlight-indent-guides" nil t)
(setq highlight-indent-guides-auto-enabled nil)

(defun my-set-face-attrs-if-available (face &rest args)
  "Apply ARGS to FACE when it is available.
Some faces are not ready during early startup on every Emacs build, so this
silently skips them instead of aborting init."
  (when (facep face)
    (condition-case nil
        (apply #'set-face-attribute face nil args)
      (error nil))))

(defun my-apply-indent-faces (&rest _)
  "Keep indentation guides visible across theme changes."
  (let* ((dark-bg (eq (frame-parameter nil 'background-mode) 'dark))
         (graphic (display-graphic-p))
         (base (if graphic
                   (if dark-bg "#5e5e5e" "#b8b8b8")
                 (if dark-bg "color-247" "color-245")))
         (top (if graphic
                  (if dark-bg "#858585" "#8a8a8a")
                (if dark-bg "color-255" "color-242")))
         (stack (if graphic
                    (if dark-bg "#b0b0b0" "#666666")
                  (if dark-bg "color-252" "color-238"))))
    (my-set-face-attrs-if-available 'whitespace-indentation
                                    :inherit nil
                                    :foreground base
                                    :background 'unspecified)
    (if (featurep 'highlight-indent-guides)
        (progn
          (my-set-face-attrs-if-available 'highlight-indent-guides-character-face
                                          :inherit nil
                                          :foreground base
                                          :background 'unspecified)
          (my-set-face-attrs-if-available 'highlight-indent-guides-top-character-face
                                          :inherit nil
                                          :foreground top
                                          :background 'unspecified
                                          :weight 'bold)
          (my-set-face-attrs-if-available 'highlight-indent-guides-stack-character-face
                                          :inherit nil
                                          :foreground stack
                                          :background 'unspecified)
          (when (and (not graphic) dark-bg)
            (my-set-face-attrs-if-available 'highlight-indent-guides-character-face
                                            :weight 'normal)
            (my-set-face-attrs-if-available 'highlight-indent-guides-stack-character-face
                                            :weight 'bold)))
      (with-eval-after-load 'highlight-indent-guides
        (my-set-face-attrs-if-available 'highlight-indent-guides-character-face
                                        :inherit nil
                                        :foreground base
                                        :background 'unspecified)
        (my-set-face-attrs-if-available 'highlight-indent-guides-top-character-face
                                        :inherit nil
                                        :foreground top
                                        :background 'unspecified
                                        :weight 'bold)
        (my-set-face-attrs-if-available 'highlight-indent-guides-stack-character-face
                                        :inherit nil
                                        :foreground stack
                                        :background 'unspecified)))))

(my-apply-indent-faces)
(advice-add 'load-theme :after #'my-apply-indent-faces)

(defun my-enable-whitespace-maybe ()
  "Enable indentation highlighting only in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (whitespace-mode 1)))

(defun my-enable-indent-guides-maybe ()
  "Enable visible indent guides in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (my-apply-indent-faces)
    (setq-local highlight-indent-guides-responsive 'top)
    (if (display-graphic-p)
        (setq-local highlight-indent-guides-method 'bitmap)
      (setq-local highlight-indent-guides-method 'character)
      (setq-local highlight-indent-guides-character ?|))
    (highlight-indent-guides-mode 1)))

(defun my-enable-git-gutter-maybe ()
  "Enable change markers only in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (git-gutter-mode 1)))

(add-hook 'prog-mode-hook #'my-enable-whitespace-maybe)
(add-hook 'conf-mode-hook #'my-enable-whitespace-maybe)
(add-hook 'prog-mode-hook #'my-enable-indent-guides-maybe)
(add-hook 'conf-mode-hook #'my-enable-indent-guides-maybe)

(add-hook 'prog-mode-hook #'hs-minor-mode)
;; Emacs bug: python-hideshow-find-next-block fails on indented comments (#)
;; because looking-at anchors at bol where spaces precede the #, killing the loop.
(setq hs-hide-comments-when-hiding-all nil)


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;                                ;;
;; ;; meta specific begins from here ;;
;; ;;                                ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; newer emacs version may not load from "/usr/share/emacs/site-lisp"
;; so add the following to the load-path and restart emacs
(let ((default-directory "/usr/share/emacs/site-lisp"))
  (normal-top-level-add-to-load-path '(".")))

(unless (package-installed-p 'use-package)
    (package-refresh-contents)
    (package-install 'use-package))

(use-package f :ensure t :defer t)
(use-package vertico :ensure t :init (vertico-mode))
(use-package consult
  :ensure t
  :bind ("C-x b" . consult-buffer)
  :config
  (setq consult-preview-key '(:debounce 0.2 any)))

(my-run-with-idle 1.5 (lambda () (require 'codehub-url nil t)))

(use-package orderless
  :ensure t
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles partial-completion basic)))))

(use-package marginalia
  :ensure t
  :init (marginalia-mode))

(use-package ace-window
  :ensure t
  :bind ("M-o" . ace-window))

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
(global-set-key (kbd "C-c f") 'my-myles-consult)

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

(global-set-key (kbd "C-c /") 'my-xbgr-consult)
(global-set-key (kbd "C-c .") 'my-xbgs-consult)
(global-set-key (kbd "C-c ,") 'my-xbgf-consult)

(defun my-scroll-preview-up ()
  (interactive)
  (with-selected-window (minibuffer-selected-window)
    (scroll-down 5)))

(defun my-scroll-preview-down ()
  (interactive)
  (with-selected-window (minibuffer-selected-window)
    (scroll-up 5)))

(define-key minibuffer-local-map (kbd "M-{") #'my-scroll-preview-up)
(define-key minibuffer-local-map (kbd "M-}") #'my-scroll-preview-down)

(load (expand-file-name "lisp/my-completion.el" user-emacs-directory) nil t)

(setq-default indent-tabs-mode nil)
(setq-default c-basic-offset 2)

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
(global-set-key (kbd "C-c x d") #'flymake-show-buffer-diagnostics)
(global-set-key (kbd "C-c e n") #'flymake-goto-next-error)
(global-set-key (kbd "C-c e p") #'flymake-goto-prev-error)

;; C++ LSP via eglot + cppls wrapper (from P1722009366 / P1687291760)
(use-package eglot
  :ensure t
  :hook ((c++-mode . eglot-ensure)
         (c++-ts-mode . eglot-ensure)
         (c-mode . eglot-ensure)
         (c-ts-mode . eglot-ensure)
         (python-mode . eglot-ensure)
         (python-ts-mode . eglot-ensure))
  :config
  (defclass eglot-fb-cppls (eglot-lsp-server) ()
    :documentation "Custom class for Facebook's C++ language server.")
  (cl-defmethod eglot-initialization-options ((server eglot-fb-cppls))
    (let ((options (make-hash-table)))
      (puthash "buckAutoMode" "use GK vscode_cpp_build_combo" options)
      (puthash "fusionMode" "ClangD+Glean" options)
      options))
  (defvar cppls-wrapper
    (expand-file-name "~/.emacs.d/bin/cppls-wrapper"))
  (add-to-list 'eglot-server-programs
               `((c++-mode c++-ts-mode c-mode c-ts-mode)
                 . (eglot-fb-cppls ,cppls-wrapper)))
  (defvar pyls-wrapper
    (expand-file-name "~/.emacs.d/bin/pyls-wrapper"))
  (add-to-list 'eglot-server-programs
               `((python-mode python-ts-mode) . (,pyls-wrapper)))
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
(add-to-list 'load-path "~/.emacs.d/lisp")
(load "sl-diff")

;; Ediff: side-by-side, no separate control frame
(setq ediff-split-window-function 'split-window-horizontally)
(setq ediff-window-setup-function 'ediff-setup-windows-plain)

;; Inline change indicators in the gutter
(use-package git-gutter
  :ensure t
  :bind (("C-c n" . git-gutter:next-hunk)
         ("C-c p" . git-gutter:previous-hunk))
  :hook (prog-mode . my-enable-git-gutter-maybe)
  :config
  (setq git-gutter:handled-backends '(hg)))

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
                magit-section marginalia modern-cpp-font-lock monky
                orderless pabbrev thrift transient tuareg vdiff
                vertico with-editor)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
