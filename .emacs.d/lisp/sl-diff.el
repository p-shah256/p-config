(use-package vdiff
  :ensure t
  :commands (vdiff-buffers vdiff-files))

(defvar sl-vdiff--tmp nil)
(defvar sl-vdiff--committed nil)
(defvar sl-vdiff--last-root nil)

(defun sl-vdiff--cleanup-tmp (&rest _)
  "Clean up sl-vdiff temp file after any vdiff-quit."
  (when sl-vdiff--tmp
    (let ((tmp sl-vdiff--tmp))
      (setq sl-vdiff--tmp nil)
      (when-let ((buf (find-buffer-visiting tmp)))
        (kill-buffer buf))
      (when (file-exists-p tmp)
        (delete-file tmp))
      (message "sl-vdiff: cleaned up %s" tmp))))

(defun sl-vdiff--guess-root ()
  "Return the repo root, checking claude-session-directory first."
  (let ((default-directory (or (bound-and-true-p claude-session-directory)
                               default-directory)))
    (condition-case nil
        (string-trim (shell-command-to-string "sl root"))
      (error sl-vdiff--last-root))))

(defun sl-vdiff--open (file root)
  "Open vdiff for FILE relative to ROOT.
Diffs against `.` (current commit) for uncommitted, `.^` (parent) for all."
  (let* ((abs-file (expand-file-name file root))
         (base-rev (if sl-vdiff--committed ".^" "."))
         (tmp (make-temp-file "sl-base-" nil
                (file-name-extension file t))))
    (setq sl-vdiff--tmp tmp)
    (message "sl-vdiff: tmp=%s abs=%s base-rev=%s" tmp abs-file base-rev)
    (let ((default-directory root))
      (write-region
       (shell-command-to-string
        (format "sl cat -r %s %s" base-rev (shell-quote-argument file)))
       nil tmp))
    (vdiff-files tmp abs-file)
    (message "sl-vdiff: vdiff-mode=%s" (bound-and-true-p vdiff-mode))))

(defun sl-vdiff--pick-internal (status-cmd)
  "List files from STATUS-CMD and open vdiff for the selected one."
  (let* ((root (sl-vdiff--guess-root))
         (default-directory root)
         (files (split-string (shell-command-to-string status-cmd) "\n" t))
         (file (completing-read "Diff file: " files nil t)))
    (setq sl-vdiff--last-root root)
    (sl-vdiff--open file root)))

(defun sl-vdiff-pick ()
  "Pick an uncommitted changed file to vdiff."
  (interactive)
  (setq sl-vdiff--committed nil)
  (sl-vdiff--pick-internal "sl status -mn"))

(defun sl-vdiff-pick-all ()
  "Pick a changed file (committed + uncommitted) to vdiff against parent."
  (interactive)
  (setq sl-vdiff--committed t)
  (sl-vdiff--pick-internal "sl status -mn --rev .^"))

(setq vdiff-disable-folding t)

(with-eval-after-load 'vdiff
  (define-key vdiff-mode-map (kbd "C-c") vdiff-mode-prefix-map)
  (advice-mapc (lambda (fn _props) (advice-remove 'vdiff-quit fn)) 'vdiff-quit)
  (advice-add 'vdiff-quit :after #'sl-vdiff--cleanup-tmp)
  (add-hook 'vdiff-mode-hook
            (lambda () (when vdiff-mode
                         (run-at-time 0 nil #'vdiff-hydra/body)))))

(defun sl-diff-summary ()
  "Show full unified diff in a buffer with diff-mode highlighting.
Prompts for (l)ocal (uncommitted) or (g)lobal (all changes vs parent)."
  (interactive)
  (let* ((scope (read-char-choice "Diff scope: (l)ocal or (g)lobal? " '(?l ?g)))
         (rev-arg (if (eq scope ?l) "" "--rev .^"))
         (default-directory (or (bound-and-true-p claude-session-directory)
                                default-directory))
         (default-directory (condition-case nil
                                (string-trim (shell-command-to-string "sl root"))
                              (error default-directory))))
    (let ((buf (get-buffer-create "*sl-diff*")))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (call-process-shell-command (format "sl diff %s" rev-arg) nil t)
          (goto-char (point-min))
          (diff-mode)
          (read-only-mode 1)))
      (switch-to-buffer buf))))

(global-set-key (kbd "C-c d d") #'sl-vdiff-pick)
(global-set-key (kbd "C-c d a") #'sl-vdiff-pick-all)
(global-set-key (kbd "C-c d s") #'sl-diff-summary)

;; Ediff: side-by-side and no separate control frame
(setq ediff-split-window-function 'split-window-horizontally)
(setq ediff-window-setup-function 'ediff-setup-windows-plain)

;; Use Sapling (sl) instead of hg for vc-mode
(setq vc-hg-program
      (expand-file-name "~/.emacs.d/bin/sl-vc-wrapper.sh"))
