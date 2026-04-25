;; sapling.el — Smartlog-first Sapling UI
;; the basic idea is simple,
;; 1. dump the output of sl ssl in the buffer
;; 2. for every operation parse the hash and use it in the command

(defgroup sapling nil
  "Sapling SCM interface." :group 'tools)

(defcustom sapling-executable "sl"
  "Path to sl." :type 'string :group 'sapling)

;; not using this as we mostly use sl ssl isntead of log
(defvar smartlog-args
  '("log"
    "--graph"
    "--template"
    "[{node|short}]\t{date|shortdate}\t{author|person}\n{desc|firstline}\n\n"
    "--limit"
    "20")
  "Argument list for sl smartlog command.")

;;; ──────────────────────────────────────────────────────────────────
;;; Core runner (call-process = no shell, no zsh brace mangling)
;;; ──────────────────────────────────────────────────────────────────
(defun sapling--run (&rest args)
  "Run sl with ARGS directly (no shell). Returns output string."
  (let* ((default-directory
           (or (locate-dominating-file default-directory ".sl")
               default-directory))
         (buf (generate-new-buffer " *sl-out*"))
         (_   (apply #'call-process sapling-executable nil buf nil args))
         (out (with-current-buffer buf (buffer-string))))
    (kill-buffer buf)
    out))

;;; ──────────────────────────────────────────────────────────────────
;;; MAIN VIEW — smartlog (sl ssl)
;;; We display it exactly as sl renders it. No parsing, no reformatting.
;;; The graph lines (│ ╷ ╭─╯), @ marker, o nodes — all come from sl.
;;; ──────────────────────────────────────────────────────────────────
(defun sapling--render-smartlog ()
  "Fetch sl ssl output and display it verbatim in *sapling* buffer."
  (with-current-buffer (get-buffer-create "*sapling*")
    (let ((inhibit-read-only t)
          ;; Save where the cursor is so we can restore it after refresh.
          ;; point is the cursor position as an integer offset.
          (saved-point (point)))
      (erase-buffer)
      (insert (propertize "Sapling Smartlog\n" 'face 'bold))
      (insert "RET: show diff   g: refresh   n/p: next/prev hash   q: quit    d: show uncommitted changes    a: amend changes to current checkout\n")
      (insert (make-string 50 ?─) "\n")
      ;; Insert the raw sl ssl output — graph art and all.
      ;; No template, no parsing. sl does all the rendering.
      ;; (insert (apply #'sapling--run smartlog-args))
      (insert (apply #'sapling--run '("ssl")))
      ;; Go back to where we were (or start of buffer on first load).
      (goto-char (min saved-point (point-max))))))

;;; ──────────────────────────────────────────────────────────────────
;;; HASH EXTRACTION — parse the hash from whichever line cursor is on
;;; 
;;; sl ssl lines look like:
;;;   @  c2089707d8  Today at 13:37  shah  origin/master
;;;   o  93b55ca2d1  Apr 20          shah
;;;   x  7ea7fe9b38  Apr 19          shah  [Amended as ...]
;;;
;;; The hash is always the first thing after the graph symbol.
;;; We use a regex to find it.
;;; ──────────────────────────────────────────────────────────────────

(defun sapling--hash-at-point ()
  "Return the commit hash on the current line, or nil if none."
  (save-excursion
    ;; Move to the beginning of the current line.
    (beginning-of-line)
    ;; looking-at tries to match a regex at point.
    ;; Regex breakdown:
    ;;   .*?         — any chars (non-greedy) — matches graph art like "│ ╷ "
    ;;   [@ox+]      — the node symbol: @ current, o normal, x obsolete, + fork
    ;;   \s-+        — one or more whitespace chars
    ;;   \([0-9a-f]+\) — capture group: the hex hash (letters a-f and digits)
    (when (looking-at ".*?[@ox+]\\s-+\\([0-9a-f]+\\)")
      ;; match-string 1 returns what the first capture group () matched.
      (match-string 1))))

;;; ──────────────────────────────────────────────────────────────────
;;; DIFF VIEW — sl show <hash>
;;; Shows the full commit: message, author, date, and diff.
;;; Displayed in a separate window so smartlog stays visible.
;;; ──────────────────────────────────────────────────────────────────

;; Extract the repeated buffer setup into one place.
;; Any time you find yourself writing the same 8 lines twice,
;; that's Lisp telling you to make a function.

(defun sapling--display-diff (output)
  (if (string-empty-p (string-trim output))
      (message "No changes to show")
    (with-current-buffer (get-buffer-create "*sapling-diff*")
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert output)
        (diff-mode)
        (goto-char (point-min))
        (local-set-key (kbd "RET") #'diff-goto-source)
        (local-set-key (kbd "n")   #'diff-hunk-next)
        (local-set-key (kbd "p")   #'diff-hunk-prev)
        (local-set-key (kbd "q")   (lambda ()
                                     (interactive)
                                     (switch-to-buffer "*sapling*")))))
    (switch-to-buffer "*sapling-diff*")))


;; Now both callers are just one line each:
(defun sapling-show-commit ()
  "Show diff for the commit hash at point."
  (interactive)
  (let ((hash (sapling--hash-at-point)))
    (if (not hash)
        (message "No commit hash found on this line")
      (sapling--display-diff (sapling--run "show" hash)))))

(defun sapling-show-diff ()
  "Show uncommitted working directory changes."
  (interactive)
  (sapling--display-diff (sapling--run "diff")))

;;; ──────────────────────────────────────────────────────────────────
;;; NAVIGATION — jump between lines that have hashes
;;; Skips pure graph lines (│ ╷ ~ etc.) that have no hash.
;;; ──────────────────────────────────────────────────────────────────

(defun sapling-next-commit ()
  "Move point to the next line containing a commit hash."
  (interactive)
  (forward-line 1)
  ;; Keep moving forward until we find a hash or hit end of buffer.
  (while (and (not (eobp))               ; eobp = end of buffer predicate
              (not (sapling--hash-at-point)))
    (forward-line 1)))

(defun sapling-prev-commit ()
  "Move point to the previous line containing a commit hash."
  (interactive)
  (forward-line -1)
  (while (and (not (bobp))               ; bobp = beginning of buffer predicate
              (not (sapling--hash-at-point)))
    (forward-line -1)))

(defun sapling-goto-commit ()
  "Run sl goto on the commit hash at point."
  (interactive)
  (let ((hash (sapling--hash-at-point)))
    (if (not hash)
        (message "No commit hash on this line")
      (message "sl goto %s..." hash)
      (sapling--run "goto" hash)
      ;; Refresh after jumping so @ moves to the new position.
      (sapling--render-smartlog)
      (message "Now at %s" hash))))

(defun sapling-refresh ()
  "Refresh the smartlog."
  (interactive)
  (sapling--render-smartlog)
  (message "Refreshed"))


;; TODO: these are really shallow functions can. not a fan.
(defun sapling-amend()
  "Amend uncommitted changes to current checkout"
  (interactive)
  (sapling--run "amend"))

(defun sapling-yank-hash()
  "Yank hash under cursor to clipboard, useful to pick commits"
  (interactive)
  (let ((hash (sapling--hash-at-point)))
    (if (not hash)
	(message "No commit found on this line")
      (kill-new hash)
      (message "copied: %s" hash))))


;;; ──────────────────────────────────────────────────────────────────
;;; MAJOR MODE
;;; ──────────────────────────────────────────────────────────────────

(define-derived-mode sapling-mode special-mode "Sapling"
  "Major mode for Sapling SCM smartlog."
  (setq buffer-read-only t)
  (hl-line-mode 1))

(let ((map sapling-mode-map))
  (define-key map (kbd "RET") #'sapling-show-commit)
  (define-key map (kbd "g")   #'sapling-refresh)
  (define-key map (kbd "d")   #'sap:ling-show-diff)
  (define-key map (kbd "n")   #'sapling-next-commit)
  (define-key map (kbd "p")   #'sapling-prev-commit)
  (define-key map (kbd "G")   #'sapling-goto-commit)
  (define-key map (kbd "y")   #'sapling-yank-hash)
  (define-key map (kbd "a")   #'sapling-amend)
  (define-key map (kbd "q")   #'quit-window))

;;; ──────────────────────────────────────────────────────────────────
;;; ENTRY POINT
;;; ──────────────────────────────────────────────────────────────────

(defun sapling ()
  "Open Sapling smartlog. Run M-x sapling inside a repo."
  (interactive)
  (sapling--render-smartlog)
  (switch-to-buffer "*sapling*")
  (sapling-mode))

(provide 'sapling)
