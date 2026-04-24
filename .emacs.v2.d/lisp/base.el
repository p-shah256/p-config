;; my-base.el --- Base Emacs configuration -*- lexical-binding: t; -*-
;;
;; lexical-binding makes closures work correctly and is faster.
;; Always have this on the first line of every elisp file.

;; ---------------------------------------------------------------------------
;; IDLE LOADER
;; ---------------------------------------------------------------------------
;; Defers a function call until Emacs has been idle for DELAY seconds.
;; Used below to avoid slowing down startup with things that don't need
;; to be ready on frame 1. 
(defun my-run-with-idle (delay fn)
  "Run FN once after DELAY seconds of idle time, starting after startup."
  (add-hook 'emacs-startup-hook
            (lambda ()
              (run-with-idle-timer delay nil fn))))


;; ---------------------------------------------------------------------------
;; UI — FRAME & FONT
;; ---------------------------------------------------------------------------

(set-face-attribute 'default nil :family "Menlo" :height 180)

;; No splash screen on launch.
(setq inhibit-startup-message t)

;; Strip the GUI chrome we don't need.
(when (fboundp 'tool-bar-mode)   (tool-bar-mode   -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))
(when (fboundp 'menu-bar-mode)   (menu-bar-mode   -1))

;; Disable vc.el — we use Magit for everything git-related.
;; Leaving vc on causes slow tramp/remote operations.
(setq vc-handled-backends nil)


;; ---------------------------------------------------------------------------
;; UI — LINE NUMBERS
;; ---------------------------------------------------------------------------
;; Relative numbers everywhere except buffers that aren't real files,
;; are remote (tramp), are huge (>512 KB), or are terminal/shell modes.

(setq display-line-numbers-type 'relative)

(defun my-heavy-ui-buffer-p ()
  "Return non-nil when expensive UI helpers should be skipped for this buffer."
  (or (minibufferp)
      (not buffer-file-name)
      (file-remote-p default-directory)
      (> (buffer-size) (* 512 1024))))

(defun my-enable-line-numbers-maybe ()
  "Enable relative line numbers only in small, local editing buffers."
  (unless (or (my-heavy-ui-buffer-p)
              (derived-mode-p 'special-mode 'comint-mode 'term-mode
                              'eshell-mode 'shell-mode 'vterm-mode))
    (display-line-numbers-mode 1)))

;; hook it to find-file-hook so it fires on every file that is opened
(add-hook 'find-file-hook #'my-enable-line-numbers-maybe)


;; ---------------------------------------------------------------------------
;; EDITING DEFAULTS
;; ---------------------------------------------------------------------------

(column-number-mode 1)       ; show column in the modeline
(show-paren-mode 1)          ; highlight matching brackets
(global-so-long-mode 1)      ; gracefully handle minified/huge single-line files
(electric-pair-mode 1)       ; auto pairs

;; (setq-default indent-tabs-mode nil)  ; spaces not tabs
;; (setq-default tab-width 4)
;; (setq-default c-basic-offset 2)      ; C/C++ indent width

(setq require-final-newline nil)       ; always end files with a newline
(setq sentence-end-double-space nil)   ; single space after period

;; Replace the annoying yes/no prompt with y/n.
(defalias 'yes-or-no-p 'y-or-n-p)

;; Silence the bell entirely.
(setq ring-bell-function 'ignore)
;; color output in compile command buffer
(add-hook 'compilation-filter-hook 'ansi-color-compilation-filter)

;; ---------------------------------------------------------------------------
;; SCROLLING PERFORMANCE
;; ---------------------------------------------------------------------------
;; These make scrolling feel snappy and avoid recentering jumps.

(setq scroll-conservatively 100)     ; don't recenter unless cursor goes off screen
(setq scroll-margin 2)               ; keep 2 lines of context at top/bottom
(setq auto-window-vscroll nil)       ; don't auto-adjust window height
(setq fast-but-imprecise-scrolling t) ;; fontify only displayed regions
(setq redisplay-skip-fontification-on-input t)


;; ---------------------------------------------------------------------------
;; BACKUPS & LOCK FILES
;; ---------------------------------------------------------------------------
;; Disabled entirely — cleaner than redirecting to a folder.
;; If you want backups back, replace these two lines with:
;;   (setq backup-directory-alist '(("." . "~/.emacs.d/backups")))
;;   (setq auto-save-file-name-transforms '((".*" "~/.emacs.d/auto-save-list/" t)))

(setq make-backup-files nil)
(setq auto-save-default nil)

;; Lock files (.#filename) confuse file watchers and language servers.
(setq create-lockfiles nil)


;; ---------------------------------------------------------------------------
;; AUTO-REVERT
;; ---------------------------------------------------------------------------
;; Automatically reload buffers when the file changes on disk (e.g. after
;; a git checkout). The non-file-buffers flag also refreshes dired listings.

;; technically this is just a toggle, so not very helpful in doing it once
;; but if we have a 100s of these calls it can help
(my-run-with-idle 0.8
		  (lambda ()
		    (setq global-auto-revert-non-file-buffers t)
		    (global-auto-revert-mode 1)))


;; ---------------------------------------------------------------------------
;; MISX
;; ---------------------------------------------------------------------------
;; recentf tracks files you've visited so consult-recent-file can list them.
;; Turned on after 1 second of idle — no reason to block startup for this.

(setq recentf-max-saved-items 200)
(setq recentf-auto-cleanup 'never) ; don't stall on missing/remote files at startup

(with-eval-after-load 'recentf
  ;; Keep Emacs internals out of the recent files list.
  (dolist (pattern '("\\.emacs\\.d/elpa/.*"
                     "\\.emacs\\.d/auto-save-list/.*"
                     "\\.emacs\\.d/.*\\.el\\'"))
    (add-to-list 'recentf-exclude pattern)))

(my-run-with-idle 1.0
		  (lambda ()
		    (recentf-mode 1)
		    (recentf-cleanup)))  ; prune any stale entries from a previous

;; savehist persists minibuffer history (M-x commands, searches, etc.)
;; across Emacs sessions. Very p, worth having on early. 
(my-run-with-idle 0.3 #'savehist-mode)

;; Lets you undo/redo window layout changes.
;; C-c <left>  → undo window change
;; C-c <right> → redo window change
(my-run-with-idle 1.2 #'winner-mode)

;; Starts the Emacs serve rso `emacsclient` can open files in this session
;; instead of launching a new Emacs instance each time.
(my-run-with-idle 2.0 #'server-start)

;; Loaded early (0.1s idle) so the frame doesn't flash unstyled.
;; Requires doom-themes to be installed via use-package below.
(my-run-with-idle 0.1 (lambda () (load-theme 'wombat t)))

;; Over SSH/terminal, some key sequences are ambiguous or missing.
;; These teach Emacs what the terminal is actually sending
(unless (display-graphic-p)
  (define-key input-decode-map "\e[27;5;127~" [C-backspace])
  (define-key input-decode-map "\e[27;6;127~" [C-S-backspace])
  (define-key input-decode-map "\e[27;5;45~"  [C--]))
(global-set-key [C-backspace]   #'backward-kill-word)
(global-set-key [C-S-backspace] #'kill-whole-line)
(global-set-key [C--]           #'undo)

;; When consult shows a preview in the background window, these let you
;; scroll that preview without leaving the 
(defun my-scroll-preview-up ()
  (interactive)
  (with-selected-window (minibuffer-selected-window) (scroll-down 5)))
(defun my-scroll-preview-down ()
  (interactive)
  (with-selected-window (minibuffer-selected-window) (scroll-up 5)))
(define-key minibuffer-local-map (kbd "M-{") #'my-scroll-preview-up)
(define-key minibuffer-local-map (kbd "M-}") #'my-scroll-preview-down)

;; C-c l copies the current file path to the clipboard.
;; If a region is active it copies  file:startline-endline  instead.
;; Useful for pasting locations into Slack, GitHub comments, etc.
(defun my-copy-file-location ()
  "Copy the file path, or file:linestart-lineend when a region is active."
  (interactive)
  (let ((loc (if (use-region-p)
                 (format "%s:%d-%d"
                         (buffer-file-name)
                         (line-number-at-pos (region-beginning))
                         (line-number-at-pos (region-end)))
               (buffer-file-name))))
    (kill-new loc)
    (message "%s" loc)))
(global-set-key (kbd "C-c l") #'my-copy-file-location)

;; hs-minor-mode lets you fold/unfold functions and blocks.
;; C-c @ C-h  hide block
;; C-c @ C-s  show block
;; C-c @ C-M-h  hide all
(add-hook 'prog-mode-hook #'hs-minor-mode)
(setq hs-hide-comments-when-hiding-all nil)



;; ;; ---------------------------------------------------------------------------
;; ;; PACKAGES
;; ;; ---------------------------------------------------------------------------
;; ;; Everything below uses use-package (built-in since Emacs 29).
;; ;; :ensure t  — install from ELPA/MELPA if not present
;; ;; :defer t   — don't load until first use
;; ;; :commands  — list of commands that trigger loading    (also defers loading)
;; ;; :hook      — attach to a mode hook
;; ;; :bind      — register a keybinding                    (also defers loading)

;; if deferral:
;; ;; :init      - always runs at startup
;; ;; :config    - runs when the package loads.
;; if no defer, then both are at the same time so doesn't matter

;; ;; Needs to be active from frame 1 →
;; ;;      no defer, or :hook (after-init . vertico-mode). Things like vertico, theme, savehist.
;; ;; Triggered by user action →
;; ;;      :bind or :commands, which auto-defer and load on first use. Things like magit, esup.
;; ;; Triggered by a mode →
;; ;;      :hook, which auto-defers and loads when that mode fires. Things like highlight-indent-guides, lsp.
;; ;; Truly optional/rarely used →
;; ;;      :defer t is fine, you'll just manually trigger it somehow.

;; ;; use m-x esup to see where time is spent during startup so based on this
;; ;; you can decide if a package needs to get :defer t or not
;; (use-package esup :ensure t :defer t)

(use-package highlight-indent-guides
  :defer t
  :ensure t
  :config
  (setq highlight-indent-guides-method 'character)
  (setq highlight-indent-guides-character ?\│)
  (setq highlight-indent-guides-responsive 'top)
  (setq highlight-indent-guides-auto-enabled t))
;; these are just setqs so basically free enabling modes is expensive as it walks
;; entire buffers
;; mode is loaded on demand here:
(defun my-enable-indent-guides-maybe ()
  (unless (my-heavy-ui-buffer-p)
    (highlight-indent-guides-mode 1)))
(add-hook 'prog-mode-hook #'my-enable-indent-guides-maybe)


;; ;; --- Completion UI stack ---
;; ;; vertico  : vertical minibuffer completion list (replaces the default horizontal one)
;; ;; orderless: fuzzy/space-separated filtering for completions
;; ;; marginalia: adds annotations (doc strings, file sizes, etc.) next to candidates
;; ;; consult  : enhanced commands that use the completion system (buffer switcher, grep, recent files, etc.)

(use-package vertico
  :ensure t
  :init (vertico-mode))

(use-package orderless
  :ensure t
  :config
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        ;; Files still use partial-completion so ~/... and ./ work as expected.
        completion-category-overrides '((file (styles partial-completion basic)))))

(use-package consult
  :ensure t
  :bind (("C-x b"   . consult-buffer)       ; replaces switch-to-buffer
         ("C-c r"   . consult-recent-file)   ; recent files picker
         ("C-c s"   . consult-ripgrep)       ; project-wide grep
         ("C-c f"   . consult-find))         ; find file by name
  :config
  ;; Only show a preview after the cursor has been still for 0.2s.
  (setq consult-preview-key '(:debounce 0.2 any)))

;; ;; --- Window management ---
;; ;; ace-window: M-o then a letter to jump to any visible window.
;; ;; Much faster than repeated C-x o when you have 3+ windows open.

(use-package ace-window
  :ensure t
  :bind ("M-o" . ace-window))


(use-package vterm
  :ensure t
  :defer t
  :custom
  (vterm-max-scrollback 10000))

(use-package multi-vterm
  :ensure t
  :defer t
  :after vterm
  :bind
  ("C-c t t" . multi-vterm)          ;; new terminal
  ("C-c t n" . multi-vterm-next)     ;; next terminal
  ("C-c t p" . multi-vterm-prev))    ;; prev terminal

;; ;; --- LSP ---
;; ;; eglot is built-in since Emacs 29 but we :ensure it to get the latest version.
;; ;; It connects to language servers (clangd, gopls, pyright, etc.) automatically.
;; ;; :commands means it only loads when you actually call eglot or eglot-ensure.

;; eglot-server-programs is just one global alist (association list — basically a
;; list of key/value pairs) that lives in Emacs. It looks roughly like:
;; ((python-mode . ("pylsp"))
;; (rust-mode . ("rust-analyzer"))
;; ((c-mode c++-mode) . ("clangd"))

(use-package eglot
  :ensure t
  :commands (eglot eglot-ensure) ;; defers load until you call eglot-ensure 
  :config
  (when (executable-find "clangd")
    ;; is an alist that maps major modes to the LSP server command to launch for them.
    (add-to-list 'eglot-server-programs
                 '((c-mode c-ts-mode c++-mode c++-ts-mode)
                   . ("clangd" "--background-index")))))

(defun eglot-ensure-maybe ()
  (unless (my-heavy-ui-buffer-p)  ; already checks remote + large buffers
    (eglot-ensure)))

;; Attach eglot-ensure to these language modes so the LSP starts automatically.
;; is exactly the same as writing this manually:
;; (add-hook 'c-mode-hook #'eglot-ensure)
;; (add-hook 'c-ts-mode-hook #'eglot-ensure)
;; (add-hook 'c++-mode-hook #'eglot-ensure)
;; ... and so on
(dolist (hook '(c-mode-hook c-ts-mode-hook
                c++-mode-hook c++-ts-mode-hook
                go-mode-hook go-ts-mode-hook
                python-mode-hook python-ts-mode-hook))
  (add-hook hook #'eglot-ensure-maybe))

;; eglot automatically enables flymake when it starts
;; LSP server → eglot → eldoc (displays docs)
;;                    → flymake (displays diagnostics)
;;                    → corfu (displays completions)
;; ;; Flymake (built-in) shows LSP diagnostics inline. These bindings mirror
;; ;; the nvim ]d / [d diagnostic navigation.
;; (global-set-key (kbd "C-c e n") #'flymake-goto-next-error)
;; (global-set-key (kbd "C-c e p") #'flymake-goto-prev-error)
;; (global-set-key (kbd "C-c e l") #'flymake-show-buffer-diagnostics)

;; ;; --- Git ---
;; ;; magit   : full git UI — C-c g opens status buffer
;; ;; git-gutter: shows added/changed/deleted lines in the fringe

(use-package magit
  :ensure t
  :defer t
  :bind ("C-c g" . magit-status))

(use-package git-gutter
  :ensure t
  :defer t
  :bind (("C-c n" . git-gutter:next-hunk)
         ("C-c p" . git-gutter:previous-hunk))
  :hook (prog-mode . git-gutter-mode))

;; ;; --- Completion-at-point ---
;; ;; Loaded 0.2s after startup, then hooked into prog-mode.
;; ;; Lives in a separate file (my-completion.el) — kept separate to stay readable.

;; (my-run-with-idle 0.2 (lambda () (require 'my-completion)))
;; (add-hook 'prog-mode-hook #'my-prog-completion-setup)

(use-package corfu
  :ensure t
  :commands (global-corfu-mode)
  :custom
  (corfu-auto t)               ;; show popup automatically, don't wait for keypress
  (corfu-auto-delay 0.2)       ;; seconds before popup appears                     
  (corfu-auto-prefix 2)	       ;; min characters before triggering                 
  (corfu-preselect 'prompt)    ;; don't preselect the candidate                    
  :config 
  (require 'corfu-popupinfo)
  (corfu-popupinfo-mode)
  (keymap-set corfu-map "M-d" #'corfu-popupinfo-toggle))
(my-run-with-idle 0.2 #'global-corfu-mode)

(use-package corfu-terminal
  :ensure t
  :after corfu
  :init
  (unless (display-graphic-p)
    (corfu-terminal-mode +1)))

(use-package breadcrumb
  :ensure t
  :commands (breadcrumb-jump breadcrumb-mode)
  :bind ("C-c b" . breadcrumb-jump))
(my-run-with-idle 1.5 #'breadcrumb-mode)

;; had to create this as c-h . opens it but does not close it.
;; need to manually close it with q
(defun my/toggle-eldoc-buffer ()
  (interactive)
  (if-let ((win (cl-find-if
                 (lambda (w)
                   (string-prefix-p "*eldoc" (buffer-name (window-buffer w))))
                 (window-list))))
      (delete-window win)
    ;; must be call-interactively, plain funcall doesn't open the buffer
    (call-interactively #'eldoc-doc-buffer)))
(global-set-key (kbd "C-h .") #'my/toggle-eldoc-buffer)

;; pinning is possible so ABI mismatches are not a problem
;; (go     . ("https://github.com/tree-sitter/tree-sitter-go" nil "abc123def456"))   ;; or a full commit hash
(use-package treesit
  :ensure nil  ;; built-in, don't try to download
  :custom
  (treesit-font-lock-level 3)  ;; maximum syntax highlighting detail
  :config
  (setq treesit-language-source-alist
        '((c        . ("https://github.com/tree-sitter/tree-sitter-c"))
          (cpp      . ("https://github.com/tree-sitter/tree-sitter-cpp"))
          (go       . ("https://github.com/tree-sitter/tree-sitter-go"))
          (python   . ("https://github.com/tree-sitter/tree-sitter-python"))))
  ;; incremental selection
  (setq treesit-simple-indent-rules nil)
  (keymap-set prog-mode-map "M-=" #'treesit-beginning-of-defun)
  (keymap-set prog-mode-map "M-i" #'treesit-node-at-point))

;; remap modes to ts modes
(setq major-mode-remap-alist
      '((c-mode        . c-ts-mode)
        (c++-mode      . c++-ts-mode)
        (python-mode   . python-ts-mode)
        (go-mode       . go-ts-mode)))

;; there is no go mode built in so just use go-ts-mode
(add-to-list 'auto-mode-alist '("\\.go\\'" . go-ts-mode))

;; TODO: not sure why
;; Required for doom-themes
(use-package f :ensure t :defer t)

(provide 'base)
