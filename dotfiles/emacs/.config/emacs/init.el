;;; init.el -*- lexical-binding: t; -*-

(setq inhibit-startup-screen t
      inferior-lisp-program "sbcl"
      custom-file (expand-file-name "custom.el" user-emacs-directory))

(load-theme 'modus-operandi t)

;; Face heights are measured in tenths of a point.
(set-face-attribute 'default nil :height 130)


;; Use Hel's native cursor shapes and editing commands.
(require 'hel)
(hel-mode 1)

(require 'sly)
(require 'sly-mrepl)

(defun altaria-lisp-repl ()
  "Start SLY if necessary, otherwise switch to its REPL."
  (interactive)
  (if (sly-connected-p)
      (call-interactively #'sly-mrepl)
    (sly)))

;; Keep Lisp navigation connected to the running Lisp image.
(hel-keymap-set sly-mode-map :state 'normal
  "g d" #'sly-edit-definition
  "[ x" #'sly-pop-find-definition-stack)

;; REPL input and debugger commands use their standard Emacs bindings.
(hel-set-initial-state 'sly-mrepl-mode 'insert)
(hel-set-initial-state 'sly-db-mode 'emacs)


(require 'xref)
(defun altaria-jump-list ()
  "Choose a previous definition-jump location, newest first."
  (interactive)
  (let* ((history (funcall xref-history-storage))
         (markers (seq-filter #'marker-buffer (car history))))
    ;; Discard locations whose buffers have been closed.
    (setcar history markers)
    (unless markers
      (user-error "No definition jumps yet; use g d first"))
    (let* ((choices
            (cl-loop for marker in markers
                     for depth from 1
                     collect
                     (cons
                      (with-current-buffer (marker-buffer marker)
                        (save-excursion
                          (save-restriction
                            (widen)
                            (goto-char marker)
                            (format "%d  %s:%d  %s"
                                    depth
                                    (if buffer-file-name
                                        (abbreviate-file-name buffer-file-name)
                                      (buffer-name))
                                    (line-number-at-pos)
                                    (string-trim
                                     (buffer-substring-no-properties
                                      (line-beginning-position)
                                      (line-end-position)))))))
                      depth)))
           (choice
            (minibuffer-with-setup-hook #'minibuffer-completion-help
              (completing-read "Jump back (Enter for most recent): "
                               choices nil t nil nil (caar choices)))))
      (dotimes (_ (cdr (assoc choice choices)))
        (xref-go-back)))))

;; OCaml and Elixir use the language servers already managed by Nix.
(require 'eglot)
(require 'tuareg)
(add-to-list 'auto-mode-alist '("\\.ml[ily]?\\'" . tuareg-mode))
(require 'utop)
(require 'elixir-mode)
(require 'inf-elixir)
(setq utop-edit-command nil)
(dolist (marker '("dune-project" "mix.exs"))
  (add-to-list 'project-vc-extra-root-markers marker))
(add-to-list 'eglot-server-programs '(tuareg-mode . ("ocamllsp")))
(add-to-list 'eglot-server-programs '(elixir-mode . ("expert" "--stdio")))
(add-hook 'tuareg-mode-hook #'eglot-ensure)
(add-hook 'tuareg-mode-hook #'utop-minor-mode)
(add-hook 'elixir-mode-hook #'eglot-ensure)
(hel-set-initial-state 'utop-mode 'insert)
(hel-set-initial-state 'inf-elixir-mode 'insert)
(setq inf-elixir-prefer-umbrella nil)

(defun altaria-elixir-repl ()
  "Start or reuse IEx for the nearest Mix project or this source buffer."
  (let* ((source (current-buffer))
         (root (locate-dominating-file default-directory "mix.exs"))
         (buffer (if root (gethash root inf-elixir-project-buffers)
                   inf-elixir-repl-buffer)))
    (unless (and (buffer-live-p buffer)
                 (comint-check-proc buffer))
      (setq buffer (if root (inf-elixir-project) (inf-elixir))))
    (with-current-buffer source
      (setq-local inf-elixir-repl-buffer buffer))
    (pop-to-buffer buffer)))

(defun altaria-repl ()
  "Open the REPL for the current language."
  (interactive)
  (cond ((derived-mode-p 'tuareg-mode 'utop-mode) (utop))
        ((derived-mode-p 'elixir-mode) (altaria-elixir-repl))
        ((derived-mode-p 'inf-elixir-mode) (goto-char (point-max)))
        ((derived-mode-p 'lisp-mode 'sly-mrepl-mode) (altaria-lisp-repl))
        (t (user-error "Open a Lisp, OCaml, or Elixir source buffer first"))))

(defun altaria-evaluate ()
  "Evaluate Lisp/OCaml definitions or Elixir selections and buffers."
  (interactive)
  (cond ((derived-mode-p 'lisp-mode) (call-interactively #'sly-compile-defun))
        ((derived-mode-p 'tuareg-mode)
         (call-interactively (if (use-region-p) #'utop-eval-region
                               #'utop-eval-phrase)))
        ((derived-mode-p 'elixir-mode)
         (save-window-excursion (altaria-elixir-repl))
         (call-interactively (if (use-region-p) #'inf-elixir-send-region
                               #'inf-elixir-send-buffer)))
        (t (user-error "Open a Lisp, OCaml, or Elixir source buffer first"))))

;; Keep documentation pages in the standard Help history.
(require 'help-mode)
(require 'eww)
(setq browse-url-browser-function #'eww-browse-url)

(defun altaria-documentation-page (text)
  "Display TEXT as a documentation page with back/forward history."
  (let ((help-window-select t))
    (help-setup-xref (list #'altaria-documentation-page text) nil)
    (with-help-window (help-buffer)
      (with-current-buffer standard-output
        (insert text)))))

(defun altaria-documentation ()
  "Explore documentation for the symbol at point."
  (interactive)
  (cond
   ((derived-mode-p 'lisp-mode 'sly-mrepl-mode)
    (let ((symbol (sly-read-symbol-name "Describe symbol: ")))
      (sly-eval-async `(slynk:describe-symbol ,symbol)
        (lambda (text) (altaria-documentation-page text)))))
   ((eglot-managed-p)
    (unless (eglot-hover-eldoc-function
             (lambda (text &rest _)
               (if (and text (not (string-empty-p text)))
                   (altaria-documentation-page text)
                 (message "No documentation at point"))))
      (user-error "This language server does not provide hover documentation")))
   ((derived-mode-p 'emacs-lisp-mode 'lisp-interaction-mode)
    (call-interactively #'describe-symbol))
   (t (user-error "Open a source buffer with SLY or Eglot connected"))))

;; Browser-like keys work in both Help pages and the built-in web browser.
;; Space remains available for the leader menu in these read-only buffers.
(dolist (mode '(help-mode eww-mode))
  (hel-set-initial-state mode 'normal))
(hel-keymap-set help-mode-map :state '(normal emacs)
  "[ x" #'help-go-back "M-<left>" #'help-go-back
  "] x" #'help-go-forward "M-<right>" #'help-go-forward
  "RET" #'push-button "TAB" #'forward-button "q" #'quit-window)
(hel-keymap-set eww-mode-map :state '(normal emacs)
  "[ x" #'eww-back-url "M-<left>" #'eww-back-url
  "] x" #'eww-forward-url "M-<right>" #'eww-forward-url
  "RET" #'eww-follow-link "TAB" #'shr-next-link "q" #'quit-window)

;; Built-in which-key displays the Space menu after a short pause.
(require 'which-key)
(setq which-key-idle-delay 0.2)
(which-key-mode 1)

(defvar altaria-leader-map (make-sparse-keymap)
  "Space leader commands for Hel normal state.")
(keymap-set altaria-leader-map "q"
            '(menu-item "Quit Emacs" save-buffers-kill-terminal))
(keymap-set altaria-leader-map "w"
            '(menu-item "Save file" save-buffer))
(keymap-set altaria-leader-map "f"
            '(menu-item "Find file in current directory" find-file))
(keymap-set altaria-leader-map "c"
            '(menu-item "Evaluate code" altaria-evaluate))
(keymap-set altaria-leader-map "r"
            '(menu-item "Language REPL" altaria-repl))
(keymap-set altaria-leader-map "j"
            '(menu-item "Jump history" altaria-jump-list))
(keymap-set altaria-leader-map "SPC"
            '(menu-item "M-x commands" execute-extended-command))
(keymap-set altaria-leader-map "k"
	    '(menu-item "Documentation" altaria-documentation))
(hel-keymap-global-set :state 'normal "SPC" altaria-leader-map)
