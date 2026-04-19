;;; my-prog-extras.el --- Optional programming extras -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)

;; DEBUG: benchmark file-open hooks
(defun my-benchmark-open (file)
  "Open FILE and time each major hook."
  (interactive "fFile: ")
  (let* ((git-gutter-mode-on-p (bound-and-true-p global-git-gutter-mode))
         (t0 (float-time)) t1 t2 t3)
    (when git-gutter-mode-on-p
      (global-git-gutter-mode -1))
    (cl-letf (((symbol-function 'eglot-ensure) #'ignore)
              (font-lock-mode nil))
      (find-file file)
      (setq t1 (float-time))
      (font-lock-ensure)
      (setq t2 (float-time))
      (kill-buffer))
    (when git-gutter-mode-on-p
      (global-git-gutter-mode 1))
    (find-file file)
    (setq t3 (float-time))
    (message "Base open: %.3fs | font-lock: %.3fs | git-gutter+eglot+rest: %.3fs | TOTAL: %.3fs"
             (- t1 t0) (- t2 t1) (- t3 t2) (- t3 t0))))

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
    (when ts-context--timer
      (cancel-timer ts-context--timer))))

(defun my-enable-ts-context-maybe ()
  "Enable treesitter context in small local code buffers."
  (unless (my-heavy-ui-buffer-p)
    (when (treesit-parser-list)
      (ts-context-mode 1))))

(provide 'my-prog-extras)

;;; my-prog-extras.el ends here
