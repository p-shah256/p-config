;;; my-cli-specs.el --- CLI transient specs -*- lexical-binding: t; -*-

;;; Code:

(defvar my-cli-transient-specs nil
  "Alist mapping CLI spec names to native Lisp specs.")

(defconst my-cli-spec-zbgr
  '(:command "zbgr"
    :default-directory "~/"
    :mode grep-mode
    :argument-name "query"
    :subcommands nil
    :options
    ((:short "-A" :long "--after-context" :arg "N" :type int
      :excludes ("--context"))
     (:short "-B" :long "--before-context" :arg "N" :type int
      :excludes ("--context"))
     (:short "-C" :long "--context" :arg "N" :type int
      :excludes ("--after-context" "--before-context"))
     (:short "-f" :long "--files" :arg "PATTERN" :type string
      :description "Restrict search to file paths matching this regex"
      :excludes ("--glob"))
     (:short "-g" :long "--glob" :arg "GLOB" :type string
      :description "Restrict search to file paths matching this glob"
      :excludes ("--files"))
     (:short "-i" :long "--ignore-case" :type bool)
     (:short "-l" :long "--files-with-matches" :type bool
      :excludes ("--files-without-match"))
     (:short "-L" :long "--files-without-match" :type bool
      :excludes ("--files-with-matches"))
     (:short "-m" :long "--smartdir" :type bool
      :excludes ("--stripdir" "--forcedir"))
     (:short "-n" :long "--limit" :arg "N" :type int)
     (:short "-p" :long "--project" :arg "PROJECT" :type string)
     (:short "-r" :long "--revision" :type bool)
     (:short "-s" :long "--stripdir" :type bool
      :excludes ("--smartdir" "--forcedir"))
     (:long "--count" :type bool)
     (:long "--exclude" :arg "PATTERN" :type string)
     (:long "--fail-on-truncation" :type bool)
     (:long "--forcedir" :arg "DIR" :type string
      :excludes ("--stripdir" "--smartdir"))
     (:long "--json" :type bool)
     (:long "--max-bytes" :arg "N" :type int)
     (:long "--terse" :type bool)
     (:long "--use-ucs" :type bool)))
  "Transient spec for `zbgr'.")

(setf (alist-get "zbgr" my-cli-transient-specs nil nil #'equal)
      my-cli-spec-zbgr)

(provide 'my-cli-specs)

;;; my-cli-specs.el ends here
