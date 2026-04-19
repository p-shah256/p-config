;;; my-base.el --- Base Emacs layer -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'subr-x)

(defun my-run-with-idle (delay fn)
  "Run FN once after DELAY seconds of idle time after startup."
  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-idle-timer delay nil fn))))

;;; Sane Defaults for Vanilla Emacs
;; 1. User Interface Tweaks
(set-face-attribute 'default nil :family "Menlo" :height 160)
(setq inhibit-startup-message t)
(setq vc-handled-backends nil)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(setq display-line-numbers-type 'relative)
(auto-save-mode -1)
(setq make-backup-files nil)
(setq auto-save-default nil)

(defun my-heavy-ui-buffer-p ()
  "Return non-nil when expensive UI helpers should stay off in this buffer."
  (or (minibufferp)
      (not buffer-file-name)
      (file-remote-p default-directory)
      (> (buffer-size) (* 512 1024))))

(defun my-enable-line-numbers-maybe ()
  "Enable line numbers only in small local editing buffers."
  (unless (or (my-heavy-ui-buffer-p)
              (derived-mode-p 'special-mode 'comint-mode 'term-mode
                              'eshell-mode 'shell-mode 'vterm-mode))
    (display-line-numbers-mode 1)))

;; 2. Display & Formatting Settings
(column-number-mode 1)
(show-paren-mode 1)
(global-font-lock-mode 1)
(global-so-long-mode 1)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq-default c-basic-offset 2)
(setq require-final-newline t)
(setq sentence-end-double-space nil)

;; 3. Editor Behavior
(defalias 'yes-or-no-p 'y-or-n-p)
(setq ring-bell-function 'ignore)
(setq redisplay-skip-fontification-on-input t)
(setq fast-but-imprecise-scrolling t)
(setq auto-window-vscroll nil)
(setq scroll-conservatively 100)
(setq scroll-margin 2)

;; 4. File and Backup Management
(setq global-auto-revert-non-file-buffers t)
(setq backup-directory-alist '(("." . "~/.emacs.d/backups")))
(setq auto-save-file-name-transforms '((".*" "~/.emacs.d/auto-save-list/" t)))
(setq create-lockfiles nil)

;; 5. Recent Files Tracking
(autoload 'savehist-mode "savehist" nil t)
(autoload 'recentf-cleanup "recentf" nil t)
(autoload 'recentf-mode "recentf" nil t)
(autoload 'winner-mode "winner" nil t)
(autoload 'whitespace-mode "whitespace" nil t)

(defvar recentf-exclude nil)
(setq recentf-max-saved-items 200)
(setq recentf-auto-cleanup 'never)

(with-eval-after-load 'recentf
  (add-to-list 'recentf-exclude "\\.emacs\\.d/.*")
  (add-to-list 'recentf-exclude "/elpa/.*")
  (add-to-list 'recentf-exclude "/auto-save-list/.*"))

(defconst my-eldoc-kind-prefixes
  '("class " "concept " "enum " "field " "function " "interface "
    "macro " "method " "module " "namespace " "property " "struct "
    "type " "union " "variable ")
  "Low-signal one-line prefixes commonly returned by LSP hover.")

(defun my-eldoc--kind-summary-line-p (line)
  "Return non-nil when LINE is a generic kind/name summary."
  (and line
       (cl-some (lambda (prefix) (string-prefix-p prefix line))
                my-eldoc-kind-prefixes)))

(defun my-eldoc--best-eglot-hover-echo (doc)
  "Choose a compact but informative echo string from Eglot hover DOC."
  (let* ((lines (seq-filter
                 (lambda (line) (not (string-empty-p line)))
                 (mapcar #'string-trim (split-string doc "\n"))))
         (summary (car lines))
         (signature (seq-find (lambda (line) (string-match-p "(" line)) lines))
         (type-line (seq-find (lambda (line) (string-prefix-p "→" line)) lines))
         (detail (seq-find (lambda (line)
                             (not (or (equal line summary)
                                      (my-eldoc--kind-summary-line-p line)
                                      (string-prefix-p "→" line))))
                           lines))
         (name (and summary
                    (not (string-empty-p summary))
                    (string-join (cdr (split-string summary " " t)) " "))))
    (cond
     (signature signature)
     (detail detail)
     ((and type-line name (my-eldoc--kind-summary-line-p summary))
      (format "%s %s" (string-trim (string-remove-prefix "→" type-line)) name))
     (type-line (string-trim (string-remove-prefix "→" type-line)))
     (summary summary)
     (t doc))))

(defun my-eldoc--rewrite-eglot-echo-doc (doc)
  "Prefer richer echo text for DOC when it came from Eglot hover."
  (pcase-let ((`(,text . ,plist) doc))
    (if (and (eq (plist-get plist :origin) 'eglot-hover-eldoc-function)
             (stringp text))
        (let ((new-plist (copy-sequence plist)))
          (plist-put new-plist :echo (my-eldoc--best-eglot-hover-echo text))
          (cons text new-plist))
      doc)))

(defun my-eldoc-display-in-echo-area (docs interactive)
  "Display DOCS in the echo area with richer Eglot hover summaries."
  (eldoc-display-in-echo-area
   (mapcar #'my-eldoc--rewrite-eglot-echo-doc docs)
   interactive))

(setq-default eldoc-display-functions
              '(my-eldoc-display-in-echo-area eldoc-display-in-buffer))

(defun my-find-recent-file ()
  "Fuzzy-find a recently opened file."
  (interactive)
  (require 'recentf)
  (let ((file (completing-read "Recent files: " recentf-list nil t)))
    (when file
      (find-file file))))

(global-set-key (kbd "C-c r") #'my-find-recent-file)

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
(require 'whitespace)
(my-run-with-idle 0.1 (lambda () (load-theme 'doom-feather-light t)))

(setq treesit-extra-load-path
      '("~/.emacs.d/tree-sitter/"))
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
    (when git-gutter-mode-on-p (global-git-gutter-mode -1))
    (let ((eglot-ensure-fn (symbol-function 'eglot-ensure)))
      (cl-letf (((symbol-function 'eglot-ensure) #'ignore)
                (font-lock-mode nil))
        (find-file file)
        (setq t1 (float-time))
        (font-lock-ensure)
        (setq t2 (float-time))
        (kill-buffer)))
    (when git-gutter-mode-on-p (global-git-gutter-mode 1))
    (find-file file)
    (setq t3 (float-time))
    (message "Base open: %.3fs | font-lock: %.3fs | git-gutter+eglot+rest: %.3fs | TOTAL: %.3fs"
             (- t1 t0) (- t2 t1) (- t3 t2) (- t3 t0))))

(setq my-treesit-mode-remap
  '(((c cpp) . (c-mode . c-ts-mode))
    ((cpp) . (c++-mode . c++-ts-mode))
    ((python) . (python-mode . python-ts-mode))
    ((bash) . (sh-mode . bash-ts-mode))
    ((go) . (go-mode . go-ts-mode))
    ((rust) . (rust-mode . rust-ts-mode))
    ((java) . (java-mode . java-ts-mode))
    ((javascript) . (javascript-mode . js-ts-mode))
    ((json) . (json-mode . json-ts-mode))
    ((yaml) . (yaml-mode . yaml-ts-mode))
    ((toml) . (conf-toml-mode . toml-ts-mode))))

(defun my-treesit-languages-ready-p (languages)
  "Return non-nil when every language in LANGUAGES is available for tree-sitter."
  (seq-every-p #'treesit-language-available-p languages))

(dolist (entry my-treesit-mode-remap)
  (setq major-mode-remap-alist
        (assq-delete-all (car (cdr entry)) major-mode-remap-alist))
  (when (my-treesit-languages-ready-p (car entry))
    (add-to-list 'major-mode-remap-alist (cdr entry))))

;;; Treesitter Context
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

;; Terminal key remaps: ESC and C-Backspace are ambiguous over terminal/SSH.
(unless (display-graphic-p)
  (define-key input-decode-map "\e[27;5;127~" [C-backspace])
  (define-key input-decode-map "\e[27;6;127~" [C-S-backspace])
  (define-key input-decode-map "\e[27;5;45~" [C--]))
(global-set-key [C-backspace] #'backward-kill-word)
(global-set-key [C-S-backspace] #'kill-whole-line)
(global-set-key [C--] #'undo)

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

(global-set-key (kbd "C-c l") #'copy-file-location)

(setq whitespace-style '(face indentation))
(autoload 'highlight-indent-guides-mode "highlight-indent-guides" nil t)
(setq highlight-indent-guides-auto-enabled nil)

(defun my-set-face-attrs-if-available (face &rest args)
  "Apply ARGS to FACE when it is available."
  (when (memq face (face-list))
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

(with-eval-after-load 'whitespace
  (my-apply-indent-faces))
(with-eval-after-load 'highlight-indent-guides
  (my-apply-indent-faces))
(advice-add 'load-theme :after #'my-apply-indent-faces)

(defun my-enable-whitespace-maybe ()
  "Enable indentation highlighting only in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (whitespace-mode 1)))

(defun my-enable-indent-guides-maybe ()
  "Enable visible indent guides in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (when (require 'highlight-indent-guides nil 'noerror)
      (my-apply-indent-faces)
      (setq-local highlight-indent-guides-responsive 'top)
      (if (display-graphic-p)
          (setq-local highlight-indent-guides-method 'bitmap)
        (setq-local highlight-indent-guides-method 'character)
        (setq-local highlight-indent-guides-character ?|))
      (highlight-indent-guides-mode 1))))

(defun my-enable-git-gutter-maybe ()
  "Enable change markers only in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (git-gutter-mode 1)))

(add-hook 'prog-mode-hook #'my-enable-whitespace-maybe)
(add-hook 'conf-mode-hook #'my-enable-whitespace-maybe)
(add-hook 'prog-mode-hook #'my-enable-indent-guides-maybe)
(add-hook 'conf-mode-hook #'my-enable-indent-guides-maybe)

(add-hook 'prog-mode-hook #'hs-minor-mode)
(setq hs-hide-comments-when-hiding-all nil)

(use-package highlight-indent-guides
  :ensure t
  :commands (highlight-indent-guides-mode))

(use-package f :ensure t :defer t)
(use-package vertico :ensure t :init (vertico-mode))
(use-package consult
  :ensure t
  :bind ("C-x b" . consult-buffer)
  :config
  (setq consult-preview-key '(:debounce 0.2 any)))

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

(use-package eglot
  :ensure t
  :commands (eglot eglot-ensure))

(defconst my-eglot-cpp-modes '(c++-mode c++-ts-mode c-mode c-ts-mode)
  "C-family major modes managed through Eglot.")

(defconst my-eglot-python-modes '(python-mode python-ts-mode)
  "Python major modes managed through Eglot.")

(defun my-eglot-enable-modes (&rest modes)
  "Attach `eglot-ensure' to each mode hook in MODES."
  (dolist (mode modes)
    (add-hook (intern (format "%s-hook" mode)) #'eglot-ensure)))

(defun my-eglot-set-server (modes program)
  "Replace any Eglot server registration for MODES with PROGRAM."
  (with-eval-after-load 'eglot
    (setq eglot-server-programs
          (cl-remove-if
           (lambda (entry)
             (equal (car entry) modes))
           eglot-server-programs))
    (push `(,modes . ,program) eglot-server-programs)))

(defalias 'my-eglot-register-server #'my-eglot-set-server)

(apply #'my-eglot-enable-modes
       (append my-eglot-cpp-modes my-eglot-python-modes))

(when (executable-find "clangd")
  (my-eglot-set-server my-eglot-cpp-modes '("clangd" "--background-index")))

(global-set-key (kbd "C-c x d") #'flymake-show-buffer-diagnostics)
(global-set-key (kbd "C-c e n") #'flymake-goto-next-error)
(global-set-key (kbd "C-c e p") #'flymake-goto-prev-error)

(require 'my-completion)

(use-package magit
  :ensure t
  :bind ("C-c g" . magit-status))

(use-package git-gutter
  :ensure t
  :bind (("C-c n" . git-gutter:next-hunk)
         ("C-c p" . git-gutter:previous-hunk))
  :hook (prog-mode . my-enable-git-gutter-maybe))

;; Register this late so line numbers come up before optional UI hooks.
(add-hook 'prog-mode-hook #'my-enable-line-numbers-maybe)
(add-hook 'conf-mode-hook #'my-enable-line-numbers-maybe)

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

(provide 'my-base)

;;; my-base.el ends here
