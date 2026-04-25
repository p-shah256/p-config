(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))

;; I really like the idea of "integrated computing envrionment for
;; emacs". It is definetly powerful than the do one thing well setup
;; (neovim + tmux + navi + and whole lot of tuis)
;;
;; in my experience I can work really faster with sapling in emacs compared to
;; {cli + neovim} some big positives, I can say goodbye to all the TUIs
;; integrate them inside emacs -- and do all your work here skip learning all
;; the hot new TUIs
;;
;; I think that was something I was missing in neovim. but for me it
;; boils down to this:
;;     1. lisp: don't have a strong opinion on lisp, but I don't necessarily
;;     have the time and space to learn it. ATM I know lua and is more faster.
;;     (for my current usecase emacs is fast as neovim. no speed differences
;;     that I can see)
;;     2. keybinds and RSI: If I move to emacs I would like to use the default
;;     emacs keybinds for native emacs experience plus evil mode does not
;;     work everywhere.
;;     3. org mode - doesn't really attract me as I don't have a strong usecase
;;     for it
;;
;; With all of this in mind, if I can do all the "integrations" in
;; neovim, then I don't have to deal with:
;;     a. learning lsip lisp,
;;     b. deal with RSI issues
;;
;; Is this the best decision? probably not but the core idea is I should be
;; learning computer fundamentals more than trying to learn a editor; with my
;; daytime job I can only afford one hobby and that should be learning
;; fundamentals and side projects instead of ricing emacs or worrying about
;; "integrations". atleast in the current phase of my life. 
;; I can afford some extra seconds in my workflow instead of spending couple
;; months setting up the editor to shave off extra 15 seconds
;; https://xkcd.com/1205/
;;
;; or if you want to keep using emacs, just time box it.
(require 'bootstrap)
(require 'base)


(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages nil))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
(put 'upcase-region 'disabled nil)
