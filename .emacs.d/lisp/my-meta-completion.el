;;; my-meta-completion.el --- Meta completion extensions -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'json)
(require 'subr-x)

(defgroup my-commit-completion nil
  "Commit-message completion for reviewer and task fields."
  :group 'completion)

(defcustom my-commit-added-reviewers nil
  "Extra users or projects to include in reviewer completion."
  :type '(repeat string)
  :group 'my-commit-completion)

(defcustom my-commit-username nil
  "Username to use for task completion.
When nil, use the current login name."
  :type '(choice (const :tag "Current user" nil) string)
  :group 'my-commit-completion)

(defconst my-commit-buffer-pattern
  "^\\(COMMIT_EDITMSG\\|new-commit\\|hg-editor.*txt\\)$"
  "Patterns matching hg, git, and arc commit templates.")

(defvar my-commit-reviewers--cache nil
  "Cached reviewer candidates.")

(defvar-local my-commit-tasks--cache nil
  "Buffer-local task candidates for the current commit message.")

(defun my-commit--buffer-p ()
  "Return non-nil when the current buffer is a commit message."
  (string-match-p my-commit-buffer-pattern (buffer-name)))

(defun my-commit--match-current-field (regexp)
  "Return bounds for REGEXP against the current line up to point.
REGEXP must capture the in-progress field value as submatch 1."
  (save-excursion
    (let ((line-start (line-beginning-position))
          (line (buffer-substring-no-properties (line-beginning-position) (point))))
      (when (string-match regexp line)
        (cons (+ line-start (match-beginning 1))
              (+ line-start (match-end 1)))))))

(defun my-commit-reviewers--make-candidate (candidate)
  "Convert list_engineers output line CANDIDATE into a completion string."
  (let* ((tokens (split-string candidate))
         (unixname (car tokens))
         (fullname (string-join (cdr tokens) " ")))
    (propertize unixname 'my-commit-fullname fullname)))

(defun my-commit-reviewers--load ()
  "Load and cache reviewer candidates."
  (or my-commit-reviewers--cache
      (setq my-commit-reviewers--cache
            (append
             my-commit-added-reviewers
             (mapcar
              #'my-commit-reviewers--make-candidate
              (delete
               ""
               (split-string
                (shell-command-to-string "list_engineers --pretty")
                "\n")))))))

(defun my-commit-reviewers--match-p (input candidate)
  "Return non-nil when CANDIDATE matches INPUT."
  (let* ((fullname (get-text-property 0 'my-commit-fullname candidate))
         (tokens (and fullname (split-string fullname " "))))
    (or (string-prefix-p input candidate t)
        (and fullname (string-match-p (regexp-quote input) fullname))
        (cl-some (lambda (token) (string-prefix-p input token t)) tokens))))

(defun my-commit-reviewers--candidates (input)
  "Return reviewer candidates matching INPUT."
  (cl-remove-if-not
   (lambda (candidate)
     (my-commit-reviewers--match-p input candidate))
   (my-commit-reviewers--load)))

(defun my-commit-reviewers--annotation (candidate)
  "Return annotation text for reviewer CANDIDATE."
  (when-let ((fullname (get-text-property 0 'my-commit-fullname candidate)))
    (concat " " fullname)))

(defun my-commit-reviewers-capf ()
  "Provide completion-at-point for Reviewers and Subscribers fields."
  (when-let ((bounds (and (my-commit--buffer-p)
                          (my-commit--match-current-field
                           "^\\(?:Reviewers\\|Subscribers\\): *.*?\\([^,]*\\)$"))))
    (list (car bounds)
          (cdr bounds)
          (completion-table-dynamic #'my-commit-reviewers--candidates)
          :annotation-function #'my-commit-reviewers--annotation
          :exclusive 'no)))

(defun my-commit-tasks--make-candidate (candidate)
  "Convert a task search result CANDIDATE into a completion string."
  (let ((task-number (alist-get 'task_number candidate))
        (title (alist-get 'title candidate)))
    (propertize task-number 'my-commit-title title)))

(defun my-commit-tasks--load ()
  "Load task candidates for the current user into a buffer-local cache."
  (or my-commit-tasks--cache
      (setq-local
       my-commit-tasks--cache
       (mapcar
        #'my-commit-tasks--make-candidate
        (json-read-from-string
         (shell-command-to-string
          (concat "/usr/local/bin/tasks search --json --name "
                  (or my-commit-username (user-login-name)))))))))

(defun my-commit-tasks--match-p (input candidate)
  "Return non-nil when CANDIDATE matches INPUT."
  (let ((title (get-text-property 0 'my-commit-title candidate)))
    (or (string-match-p (regexp-quote input) candidate)
        (and title (string-match-p (regexp-quote input) title)))))

(defun my-commit-tasks--candidates (input)
  "Return task candidates matching INPUT."
  (cl-remove-if-not
   (lambda (candidate)
     (my-commit-tasks--match-p input candidate))
   (my-commit-tasks--load)))

(defun my-commit-tasks--annotation (candidate)
  "Return annotation text for task CANDIDATE."
  (when-let ((title (get-text-property 0 'my-commit-title candidate)))
    (concat " " title)))

(defun my-commit-tasks-capf ()
  "Provide completion-at-point for Tasks fields."
  (when-let ((bounds (and (my-commit--buffer-p)
                          (my-commit--match-current-field
                           "^Tasks: *.*?\\([^,]*\\)$"))))
    (list (car bounds)
          (cdr bounds)
          (completion-table-dynamic #'my-commit-tasks--candidates)
          :annotation-function #'my-commit-tasks--annotation
          :exclusive 'no)))

(defun my-commit-completion-setup ()
  "Enable completion helpers for commit buffers."
  (when (my-commit--buffer-p)
    (when (featurep 'corfu)
      (corfu-mode 1))
    (add-hook 'completion-at-point-functions #'my-commit-reviewers-capf t t)
    (add-hook 'completion-at-point-functions #'my-commit-tasks-capf t t)))

(add-hook 'text-mode-hook #'my-commit-completion-setup)

(provide 'my-meta-completion)

;;; my-meta-completion.el ends here
