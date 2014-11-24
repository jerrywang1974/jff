;;; lisp.el --- My little configuration for Common Lisp IDE on Emacs

;;; Commentary:

;; Set PATH in ~/.bashrc or update exec-path in ~/.emacs to include
;; sbcl + ccl64 + w3m in search path of executable.
;;
;; If you use Homebrew on Mac OS X to install hyperspec, execute this after installation:
;;   $ sudo ln -s `brew --prefix`/share/doc/hyperspec/HyperSpec/ /usr/share/doc/hyperspec

;;; Code:

(defvar my-packages
  '(paredit rainbow-delimiters redshank w3m
            undo-tree evil
            magit
            helm
            auto-complete ac-slime
            flycheck))

(require 'package)
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/") t)
(package-initialize)
(unless (loop for pkg in my-packages
              when (not (package-installed-p pkg)) do (return nil)
              finally (return t))
  (message "%s" "Emacs is now refreshing its package database...")
  (package-refresh-contents))
(dolist (pkg my-packages)
  (unless (package-installed-p pkg)
    (package-install pkg)))


;;; Customize rainbow-delimiters color scheme with "M-x customize-group<RET>rainbow-delimiters<RET>"
;;; Customize speedbar with "M-x customize-group<RET>speedbar<RET>"
(custom-set-variables
  '(imenu-auto-rescan t)
  '(imenu-sort-function (quote imenu--sort-by-name))
  '(speedbar-show-unknown-files t)
  '(speedbar-supported-extension-expressions
     (quote
       (".[ch]\\(\\+\\+\\|pp\\|c\\|h\\|xx\\)?" ".tex\\(i\\(nfo\\)?\\)?" ".el" ".emacs" ".l" ".lsp" ".lisp" ".asd" ".p" ".java" ".js" ".f\\(90\\|77\\|or\\)?" ".ad[abs]" ".p[lm]" ".tcl" ".m" ".scm" ".pm" ".py" ".g" ".s?html" ".ma?k" "[Mm]akefile\\(\\.in\\)?"))))
(custom-set-faces
  '(rainbow-delimiters-depth-1-face ((t (:foreground "Black"))))
  '(rainbow-delimiters-depth-2-face ((t (:foreground "Blue"))))
  '(rainbow-delimiters-depth-3-face ((t (:foreground "Magenta"))))
  '(rainbow-delimiters-depth-4-face ((t (:foreground "Green"))))
  '(rainbow-delimiters-depth-5-face ((t (:foreground "Orange"))))
  '(rainbow-delimiters-depth-6-face ((t (:foreground "Cyan"))))
  '(rainbow-delimiters-depth-7-face ((t (:foreground "Purple"))))
  '(rainbow-delimiters-unmatched-face ((t (:foreground "Red")))))


;;; Setup SLIME
(setq inferior-lisp-program "sbcl")
(setq slime-lisp-implementations
      '((sbcl ("sbcl" "--noinform") :coding-system utf-8-unix)
        (ccl ("ccl64"))
        (cmucl ("cmucl" "-quiet"))
        (clisp ("clisp" "-q"))))

;(if (eq system-type 'darwin)
;    (setq slime-default-lisp 'ccl)
;  (setq slime-default-lisp 'sbcl))

(load "~/quicklisp/slime-helper.el")

(require 'slime-autoloads)
(slime-setup '(slime-fancy slime-asdf slime-banner slime-xref-browser))
(eval-after-load "slime"
  '(progn
     (setq slime-complete-symbol-function 'slime-fuzzy-complete-symbol
           slime-complete-symbol*-fancy t
           slime-fuzzy-completion-in-place t
           slime-enable-evaluate-in-emacs t
           slime-autodoc-use-multiline-p t
           slime-net-coding-system 'utf-8-unix) ; or emacs-mule-unix, may have nicer font to render in Emacs

     (define-key slime-mode-map (kbd "TAB") 'slime-indent-and-complete-symbol)
     (define-key slime-mode-map (kbd "C-c i") 'slime-inspect)
     (define-key slime-mode-map (kbd "C-c s") 'slime-selector)
     (define-key slime-repl-mode-map (kbd "C-c s") 'slime-selector)))


;;; Setup ParEdit: http://www.emacswiki.org/emacs/ParEdit
;;;      (smartparens is another choice: https://github.com/Fuco1/smartparens)
(autoload 'paredit-mode "paredit"
  "Minor mode for pseudo-structurally editing Lisp code." t)

(defvar electrify-return-match
  "[\]}\)\"]"
  "If this regexp matches the text after the cursor, do an \"electric\" return.")

(defun electrify-return-if-match (arg)
  "If the text after the cursor matches `electrify-return-match' then
open and indent an empty line between the cursor and the text.  Move the
cursor to the new line."
  (interactive "P")
  (let ((case-fold-search nil))
    (if (looking-at electrify-return-match)
        (save-excursion (newline-and-indent)))
    (newline arg)
    (indent-according-to-mode)))

(defun my-lisp-coding-defaults ()
  (paredit-mode 1)
  (local-set-key (kbd "RET") 'electrify-return-if-match)
  (setq indent-tabs-mode nil)
  ;;(setq tab-width 4)
  (rainbow-delimiters-mode 1)
  (setq show-paren-style 'expression) ; highlight entire bracket expression
  (show-paren-mode 1))

;; Stop SLIME's REPL from grabbing DEL, which is annoying when backspacing over a '('
(defun override-slime-repl-bindings-with-paredit ()
  (define-key slime-repl-mode-map
    (read-kbd-macro paredit-backward-delete-key) nil))

(add-hook 'slime-repl-mode-hook 'override-slime-repl-bindings-with-paredit)
(mapc (lambda (hook)
        (add-hook hook 'my-lisp-coding-defaults))
      '(emacs-lisp-mode-hook lisp-mode-hook lisp-interaction-mode-hook slime-repl-mode-hook))


;;; Setup Redshank
(autoload 'redshank-mode "redshank"
  "Minor mode for editing and refactoring (Common) Lisp code."
  t)
(autoload 'turn-on-redshank-mode "redshank"
  "Turn on Redshank mode.  Please see function `redshank-mode'."
  t)
(add-hook 'lisp-mode-hook 'turn-on-redshank-mode)
(autoload 'asdf-mode "redshank"
  "Minor mode for editing ASDF files."
  t)
(autoload 'turn-on-asdf-mode "redshank"
  "Turn on ASDF mode.  Please see function `asdf-mode'."
  t)


;;; Use w3m to browse CLHS
(require 'w3m)
(setq browse-url-browser-function '(("hyperspec" . w3m-browse-url)
                                    ("." . browse-url-default-browser)))
(eval-after-load "slime"
  '(progn
     (setq common-lisp-hyperspec-root
           "/usr/share/doc/hyperspec/")
     (setq common-lisp-hyperspec-symbol-table
           (concat common-lisp-hyperspec-root "Data/Map_Sym.txt"))
     (setq common-lisp-hyperspec-issuex-table
           (concat common-lisp-hyperspec-root "Data/Map_IssX.txt"))))


;;; Setup cldoc
;(autoload 'turn-on-cldoc-mode "cldoc" nil t)
;(dolist (hook '(lisp-mode-hook
;                slime-repl-mode-hook))
;  (add-hook hook 'turn-on-cldoc-mode))


;;; Setup helm
(require 'helm-config)
(global-set-key (kbd "C-c h") 'helm-mini)
(global-set-key (kbd "M-x") 'helm-M-x)
(helm-mode 1)


;;; Setup undo-tree
(require 'undo-tree)
(global-undo-tree-mode)
(setq undo-tree-auto-save-history t)
(setq undo-tree-history-directory-alist `(("." . ,(concat user-emacs-directory "undo"))))
(defadvice undo-tree-make-history-save-file-name
    (after undo-tree activate)
  (setq ad-return-value (concat ad-return-value ".gz")))


;;; Setup auto-complete and ac-slime
(require 'auto-complete-config)
(add-to-list 'ac-dictionary-directories (concat user-emacs-directory "ac-dict"))
(ac-config-default)

(require 'ac-slime)
(add-hook 'slime-mode-hook 'set-up-slime-ac)
(add-hook 'slime-repl-mode-hook 'set-up-slime-ac)
(eval-after-load "auto-complete"
  '(add-to-list 'ac-modes 'slime-repl-mode))


;;; Setup flycheck
(add-hook 'after-init-hook #'global-flycheck-mode)


;;; Misc
;; https://github.com/technomancy/better-defaults/blob/master/better-defaults.el
(require 'uniquify)
(setq uniquify-buffer-name-style 'forward)
(require 'saveplace)
(setq-default save-place t)
(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "C-x C-b") 'ibuffer)
(global-set-key (kbd "C-s") 'isearch-forward-regexp)
(global-set-key (kbd "C-r") 'isearch-backward-regexp)
(global-set-key (kbd "C-M-s") 'isearch-forward)
(global-set-key (kbd "C-M-r") 'isearch-backward)
(show-paren-mode 1)
(setq-default indent-tabs-mode nil)
(setq x-select-enable-clipboard t
      x-select-enable-primary t
      save-interprogram-paste-before-kill t
      apropos-do-all t
      mouse-yank-at-point t
      backup-directory-aliast `(("." . ,(concat user-emacs-directory "backup"))))

