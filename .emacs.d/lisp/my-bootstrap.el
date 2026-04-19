;;; my-bootstrap.el --- Startup and package bootstrap -*- lexical-binding: t; -*-

;;; Code:

(require 'package)

(when (featurep 'native-compile)
  (setq native-comp-speed 2)
  (setq native-comp-async-report-warnings-errors nil))

(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/"))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(provide 'my-bootstrap)

;;; my-bootstrap.el ends here
