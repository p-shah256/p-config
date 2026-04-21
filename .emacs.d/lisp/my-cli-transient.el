;;; my-cli-transient.el --- Native Lisp transient wrapper -*- lexical-binding: t; -*-

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'transient)
(defvar my-cli-transient-specs nil
  "Alist mapping CLI spec names to native Lisp specs.")

(require 'my-cli-specs)

(defvar my-cli-transient-current-spec nil
  "Currently loaded CLI spec.")

(defvar my-cli-transient-current-argument nil
  "Current positional argument string.")

(defvar my-cli-transient-current-options nil
  "Current option alist of (SWITCH . VALUE).")

(defvar my-cli-transient-current-subcommand nil
  "Current subcommand string.")

(defun my-cli-transient--get (key &optional spec)
  "Return KEY from SPEC or the current spec."
  (plist-get (or spec my-cli-transient-current-spec) key))

(defun my-cli-transient--option-get (option key)
  "Return KEY from OPTION."
  (plist-get option key))

(defun my-cli-transient--resolve-spec (name-or-spec)
  "Resolve NAME-OR-SPEC to a native Lisp CLI spec."
  (cond
   ((and (listp name-or-spec)
         (keywordp (car name-or-spec)))
    name-or-spec)
   ((stringp name-or-spec)
    (or (alist-get name-or-spec my-cli-transient-specs nil nil #'equal)
        (error "Unknown CLI spec: %s" name-or-spec)))
   ((symbolp name-or-spec)
    (if (boundp name-or-spec)
        (symbol-value name-or-spec)
      (error "Unknown CLI spec symbol: %s" name-or-spec)))
   (t
    (error "Unsupported CLI spec type: %S" name-or-spec))))

(defun my-cli-transient-load-spec (name-or-spec)
  "Load NAME-OR-SPEC and reset transient state."
  (let ((spec (my-cli-transient--resolve-spec name-or-spec)))
    (unless (my-cli-transient--get :command spec)
      (error "CLI spec is missing :command"))
    (setq my-cli-transient-current-spec spec
          my-cli-transient-current-argument nil
          my-cli-transient-current-options nil
          my-cli-transient-current-subcommand nil)
    spec))

(defun my-cli-transient-make-command (name-or-file)
  "Return an interactive command for NAME-OR-FILE."
  (lambda ()
    (interactive)
    (my-cli-transient-load-spec name-or-file)
    (my-cli-transient-dispatch)))

(defun my-cli-transient--option-switch (option)
  "Return the canonical switch name for OPTION."
  (or (my-cli-transient--option-get option :long)
      (my-cli-transient--option-get option :short)))

(defun my-cli-transient--option-excludes (option)
  "Return switches excluded by OPTION."
  (or (my-cli-transient--option-get option :excludes) '()))

(defun my-cli-transient--option-label (option)
  "Return a completion label for OPTION."
  (let* ((names (string-join
                 (delq nil
                       (list (my-cli-transient--option-get option :short)
                             (my-cli-transient--option-get option :long)))
                 ", "))
         (arg (my-cli-transient--option-get option :arg))
         (desc (my-cli-transient--option-get option :description)))
    (string-join
     (delq nil
           (list (if arg
                     (format "%s %s" names arg)
                   names)
                 desc))
     "  ")))

(defun my-cli-transient--active-label (entry)
  "Return a display label for active ENTRY."
  (if (eq (cdr entry) t)
      (car entry)
    (format "%s=%s" (car entry) (cdr entry))))

(defun my-cli-transient--command (&optional allow-missing-argument)
  "Build the current command string.
When ALLOW-MISSING-ARGUMENT is non-nil, omit the argument check."
  (let ((command (my-cli-transient--get :command))
        (argument-name (my-cli-transient--get :argument-name)))
    (unless (or allow-missing-argument
                (not argument-name)
                (not (string-empty-p (or my-cli-transient-current-argument ""))))
      (user-error "Set %s first" argument-name))
    (string-join
     (append
      (list command)
      (when (not (string-empty-p (or my-cli-transient-current-subcommand "")))
        (list my-cli-transient-current-subcommand))
      (cl-mapcan
       (lambda (entry)
         (if (eq (cdr entry) t)
             (list (car entry))
           (list (car entry) (shell-quote-argument (cdr entry)))))
       my-cli-transient-current-options)
      (when (not (string-empty-p (or my-cli-transient-current-argument "")))
        (list "--" (shell-quote-argument my-cli-transient-current-argument))))
     " ")))

(defun my-cli-transient-set-argument ()
  "Set the current positional argument string."
  (interactive)
  (let ((name (or (my-cli-transient--get :argument-name) "argument")))
    (setq my-cli-transient-current-argument
          (read-string (format "%s: " name)
                       my-cli-transient-current-argument))
    (message "%s" (my-cli-transient--command t))))

(defun my-cli-transient-set-subcommand ()
  "Set the current subcommand."
  (interactive)
  (let ((subcommands (my-cli-transient--get :subcommands)))
    (unless subcommands
      (user-error "This CLI spec does not define subcommands"))
    (setq my-cli-transient-current-subcommand
          (completing-read "Subcommand: " subcommands nil t
                           my-cli-transient-current-subcommand))
    (message "%s" (my-cli-transient--command t))))

(defun my-cli-transient-set-option ()
  "Add or update one option from the current spec."
  (interactive)
  (let* ((options (my-cli-transient--get :options))
         (labels (mapcar (lambda (opt)
                           (cons (my-cli-transient--option-label opt) opt))
                         options))
         (choice (completing-read "Option: " labels nil t))
         (option (cdr (assoc choice labels)))
         (switch (my-cli-transient--option-switch option))
         (arg-name (my-cli-transient--option-get option :arg))
         (value (and arg-name
                     (read-string (format "%s value: " switch)
                                  (cdr (assoc switch my-cli-transient-current-options)))))
         (excludes (my-cli-transient--option-excludes option)))
    (setq my-cli-transient-current-options
          (cl-remove-if
           (lambda (entry)
             (or (equal (car entry) switch)
                 (member (car entry) excludes)))
           my-cli-transient-current-options))
    (setq my-cli-transient-current-options
          (append my-cli-transient-current-options
                  (list (cons switch (or value t)))))
    (message "%s" (my-cli-transient--command t))))

(defun my-cli-transient-remove-option ()
  "Remove one active option."
  (interactive)
  (unless my-cli-transient-current-options
    (user-error "No active options"))
  (let* ((labels (mapcar (lambda (entry)
                           (cons (my-cli-transient--active-label entry) entry))
                         my-cli-transient-current-options))
         (choice (completing-read "Remove option: " labels nil t)))
    (setq my-cli-transient-current-options
          (delete (cdr (assoc choice labels)) my-cli-transient-current-options))
    (message "%s" (my-cli-transient--command t))))

(defun my-cli-transient-clear ()
  "Clear the current argument, subcommand, and active options."
  (interactive)
  (setq my-cli-transient-current-argument nil
        my-cli-transient-current-options nil
        my-cli-transient-current-subcommand nil)
  (message "Cleared CLI transient state"))

(defun my-cli-transient-show-command ()
  "Show the current command string."
  (interactive)
  (message "%s" (my-cli-transient--command t)))

(defun my-cli-transient-run ()
  "Run the current command using the spec's configured compilation mode."
  (interactive)
  (let* ((mode (or (my-cli-transient--get :mode) 'compilation-mode))
         (default-directory
          (file-name-as-directory
           (expand-file-name (or (my-cli-transient--get :default-directory)
                                 "~"))))
         (command (my-cli-transient--command))
         (buffer-name (format "*%s*" (my-cli-transient--get :command))))
    (compilation-start command mode (lambda (_) buffer-name))))

(transient-define-prefix my-cli-transient-dispatch ()
  "Generic transient for a JSON-backed CLI spec."
  [["CLI"
    ("a" "set argument" my-cli-transient-set-argument :transient t)
    ("s" "set subcommand" my-cli-transient-set-subcommand :transient t)
    ("o" "set option" my-cli-transient-set-option :transient t)
    ("d" "remove option" my-cli-transient-remove-option :transient t)
    ("c" "clear" my-cli-transient-clear :transient t)]
   ["Run"
    ("v" "show command" my-cli-transient-show-command :transient t)
    ("r" "run" my-cli-transient-run)]])

(defun my-cli-transient-open (name-or-spec)
  "Open a native Lisp CLI transient for NAME-OR-SPEC."
  (interactive
   (list
    (completing-read "CLI spec: "
                     (mapcar #'car my-cli-transient-specs)
                     nil t)))
  (my-cli-transient-load-spec name-or-spec)
  (my-cli-transient-dispatch))

(provide 'my-cli-transient)

;;; my-cli-transient.el ends here
