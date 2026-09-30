;;; init.el -*- lexical-binding: t; -*-

(setq inhibit-startup-screen t
      inferior-lisp-program "sbcl"
      custom-file (expand-file-name "custom.el" user-emacs-directory))

;; Indent with spaces by default.
(setq-default indent-tabs-mode nil)

(load-theme 'modus-operandi t)

;; Face heights are measured in tenths of a point.
(set-face-attribute 'default nil :height 140)


;; Clicks, selection, and the scroll wheel also work in terminal Emacs.
(xterm-mouse-mode 1)

;; Minibuffer prompts list candidates vertically with fuzzy matching,
;; like Helix's pickers: type part of a name, then C-n/C-p and Enter.
(fido-vertical-mode 1)

;; Use Hel's native cursor shapes and editing commands.
(require 'hel)
(hel-mode 1)

;; Terminal Emacs can't draw Hel's cursor shapes itself (a bar between
;; characters in normal state, a block while typing), so tell the terminal
;; with the standard cursor-shape escape codes whenever the shape changes.
(defvar altaria--terminal-cursor nil
  "Cursor-shape escape sequence last sent to the terminal.")

(defun altaria-terminal-cursor-update ()
  "Match the terminal cursor to `cursor-type' in the selected window."
  (unless (or noninteractive (display-graphic-p))
    (let* ((type (buffer-local-value 'cursor-type (window-buffer)))
           (sequence (pcase (if (consp type) (car type) type)
                       ('bar "\e[6 q")
                       ('hbar "\e[4 q")
                       (_ "\e[2 q"))))
      (unless (equal sequence altaria--terminal-cursor)
        (send-string-to-terminal sequence)
        (setq altaria--terminal-cursor sequence)))))

(defun altaria-terminal-cursor-reset ()
  "Give the terminal back its own cursor shape."
  (unless (or noninteractive (display-graphic-p))
    (send-string-to-terminal "\e[0 q")
    (setq altaria--terminal-cursor nil)))

(add-hook 'post-command-hook #'altaria-terminal-cursor-update)
(add-hook 'emacs-startup-hook #'altaria-terminal-cursor-update)
(add-hook 'suspend-resume-hook #'altaria-terminal-cursor-update)
(add-hook 'suspend-hook #'altaria-terminal-cursor-reset)
(add-hook 'kill-emacs-hook #'altaria-terminal-cursor-reset)

(require 'sly)
(require 'sly-mrepl)

;; Opt in per source buffer while trying Parinfer; the native module comes from Nix.
(setq parinfer-rust-library (locate-library "parinfer-rust-darwin.so")
      parinfer-rust-auto-download nil
      parinfer-rust-preferred-mode "smart")
(require 'parinfer-rust-mode)

(defun altaria-toggle-parinfer ()
  "Toggle Parinfer in a Lisp source buffer."
  (interactive)
  (unless (derived-mode-p 'lisp-mode 'emacs-lisp-mode 'lisp-interaction-mode 'scheme-mode)
    (user-error "Open a Lisp source buffer to try Parinfer"))
  (unless parinfer-rust-mode
    (setq-local indent-tabs-mode nil))
  (parinfer-rust-mode 'toggle)
  (message "Parinfer %s" (if parinfer-rust-mode "enabled" "disabled")))

;; Format Common Lisp on save the way Lispers do: re-indent with SLY's
;; Common Lisp rules and drop trailing whitespace.
(defun altaria-format-lisp ()
  "Re-indent the whole buffer and delete trailing whitespace."
  (let ((inhibit-message t))
    (save-excursion (indent-region (point-min) (point-max))))
  (delete-trailing-whitespace))

(add-hook 'lisp-mode-hook
          (lambda () (add-hook 'before-save-hook #'altaria-format-lisp nil t)))

(defun altaria-lisp-repl ()
  "Start SLY if necessary, otherwise switch to its REPL."
  (interactive)
  (if (sly-connected-p)
      (call-interactively #'sly-mrepl)
    (sly)))

;; Cross-references from the running Lisp, for the symbol under the cursor
;; (SLY's own commands always prompt; these only ask when there's none).
(defun altaria-sly-xref (type prompt)
  "Show SLY cross-references of TYPE for the symbol at point."
  (sly-xref type (or (sly-symbol-at-point) (sly-read-symbol-name prompt t))))

(defun altaria-sly-who-calls ()
  "List the functions that call the function at point."
  (interactive)
  (altaria-sly-xref :calls "Who calls: "))

(defun altaria-sly-calls-who ()
  "List the functions that the function at point calls."
  (interactive)
  ;; :callees works on SBCL; SLY's :calls-who isn't implemented there.
  (altaria-sly-xref :callees "Calls who: "))

(defun altaria-sly-who-references ()
  "List the code that reads the global variable at point."
  (interactive)
  (altaria-sly-xref :references "Who references: "))

;; Keep Lisp navigation connected to the running Lisp image.  g c replaces
;; Hel's comment toggle in Lisp buffers; M-; still comments.
(hel-keymap-set sly-mode-map :state 'normal
  "g d" #'sly-edit-definition
  "g r" #'altaria-sly-who-references
  "g c" #'altaria-sly-who-calls
  "g C" #'altaria-sly-calls-who
  "[ x" #'sly-pop-find-definition-stack)

;; The cross-reference list: Enter jumps to an entry, q closes the list.
(hel-keymap-set sly-xref-mode-map :state 'normal
  "RET" #'sly-xref-goto "q" #'quit-window)

;; REPL input and debugger commands use their standard Emacs bindings.
(hel-set-initial-state 'sly-mrepl-mode 'insert)
(hel-set-initial-state 'sly-db-mode 'emacs)
;; j/k step through backtrace frames, as in Emacs's own debugger under Hel.
(hel-keymap-set sly-db-mode-map :state 'emacs
  "j" #'sly-db-down "k" #'sly-db-up)


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

;; Nix files get syntax highlighting and indentation.
(require 'nix-mode)

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
;; Helix's goto keys that ocamllsp supports.  g r (references, built into
;; Hel) also finds a function's callers; ocamllsp has no call hierarchy.
(defun altaria-goto-type-definition ()
  "Jump to the definition of the type at point (list it if there are several)."
  (interactive)
  (let ((xref-show-xrefs-function #'xref-show-definitions-buffer))
    (call-interactively #'eglot-find-typeDefinition)))

(defun altaria-goto-declaration ()
  "Jump to the declaration at point (list it if there are several)."
  (interactive)
  (let ((xref-show-xrefs-function #'xref-show-definitions-buffer))
    (call-interactively #'eglot-find-declaration)))

(hel-keymap-set tuareg-mode-map :state 'normal
  "g y" #'altaria-goto-type-definition
  "g D" #'altaria-goto-declaration)

;; Format OCaml on save with ocamlformat.  A project's .ocamlformat still
;; applies; the flag also formats single files outside any project.  On a
;; syntax error the file saves unformatted and the error is shown.
(defun altaria-format-ocaml ()
  "Replace the buffer with ocamlformat's output, keeping point in place."
  (when (and buffer-file-name (string-match-p "\\.mli?\\'" buffer-file-name))
    (let ((output (generate-new-buffer " *ocamlformat*"))
          (errors (make-temp-file "ocamlformat")))
      (unwind-protect
          (if (zerop (call-process-region nil nil "ocamlformat" nil (list output errors) nil
                                          "-" "--name" buffer-file-name
                                          "--enable-outside-detected-project"))
              (replace-buffer-contents output 1)
            (with-temp-buffer
              (insert-file-contents errors)
              (let ((line (and (re-search-forward "line \\([0-9]+\\)" nil t)
                               (match-string 1)))
                    (error (car (last (split-string (buffer-string) "\n" t)))))
                (message "ocamlformat skipped (saved unformatted): %s%s"
                         (if line (format "line %s: " line) "")
                         (string-remove-prefix "Error: " error)))))
        (kill-buffer output)
        (delete-file errors)))))

(add-hook 'tuareg-mode-hook
          (lambda () (add-hook 'before-save-hook #'altaria-format-ocaml nil t)))
(add-hook 'elixir-mode-hook #'eglot-ensure)
;; Nix uses nil, the language server Helix also uses.
(add-hook 'nix-mode-hook #'eglot-ensure)
(hel-set-initial-state 'utop-mode 'insert)
(hel-set-initial-state 'inf-elixir-mode 'insert)
(setq inf-elixir-prefer-umbrella nil)

;; Up/Down recall earlier input at every REPL prompt, like a terminal.
;; They apply in insert state; normal state keeps them for moving the cursor.
(hel-keymap-set sly-mrepl-mode-map :state 'insert
  "<up>" #'sly-mrepl-previous-input-or-button
  "<down>" #'sly-mrepl-next-input-or-button)
(hel-keymap-set utop-mode-map :state 'insert
  "<up>" #'utop-history-goto-prev
  "<down>" #'utop-history-goto-next)
(hel-keymap-set inf-elixir-mode-map :state 'insert
  "<up>" #'comint-previous-input
  "<down>" #'comint-next-input)

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
        ((or (equal (buffer-name) "*scratch*")
             (derived-mode-p 'lisp-mode 'sly-mrepl-mode))
         (altaria-lisp-repl))
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

;; Diagnostics (the underlined warnings/errors) show their message when the
;; cursor is on them; ] d / [ d jump between them, as in Helix.
(require 'flymake)
;; Emacs 31 hides diagnostics in files outside `trusted-content'. Eglot's
;; backend only displays what the already-running language server reports,
;; so it is safe everywhere; code-evaluating backends stay gated.
(put 'eglot-flymake-backend 'flymake-always-safe t)
(hel-keymap-global-set :state 'normal
  "] d" #'flymake-goto-next-error
  "[ d" #'flymake-goto-prev-error)

;; Documentation opens beside the current window (right half), as it does
;; in a wide graphical frame, even when the terminal is too narrow for
;; Emacs to split side by side on its own.
(add-to-list 'display-buffer-alist
             '("\\`\\*Help\\*\\'"
               (display-buffer-reuse-window display-buffer-in-direction)
               (direction . right)
               (window-width . 0.5)))

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

;; Info manuals: Hel already gives them j/k; h/l move the cursor too, and
;; history moves to the same back/forward keys as Help and EWW.  Info's own
;; [ and ] (previous/next node in reading order) move to [ n and ] n.
(require 'info)
(hel-keymap-set Info-mode-map
  "h" #'left-char "l" #'right-char
  "[" nil "]" nil
  "[ n" #'Info-backward-node "] n" #'Info-forward-node
  "[ x" #'Info-history-back "M-<left>" #'Info-history-back
  "] x" #'Info-history-forward "M-<right>" #'Info-history-forward)

;; Dired moves like other read-only buffers and like vifm: j/k move,
;; h goes to the parent directory, l opens.  The dired commands these
;; keys replace move to J (go to file) and K (hide lines); g r refreshes.
(require 'dired)

(defun altaria-dired-first-file ()
  "Move to the first entry in the listing."
  (interactive)
  (goto-char (point-min))
  (dired-next-line 1))

(defun altaria-dired-last-file ()
  "Move to the last entry in the listing."
  (interactive)
  (goto-char (point-max))
  (dired-previous-line 1))

(hel-keymap-set dired-mode-map
  "j" #'dired-next-line "k" #'dired-previous-line
  "h" #'dired-up-directory "l" #'dired-find-file
  "J" #'dired-goto-file "K" #'dired-do-kill-lines
  "g" nil
  "g g" #'altaria-dired-first-file "G" #'altaria-dired-last-file
  "g r" #'revert-buffer)

(defun altaria-quit ()
  "Quit like Vim's :q: refuse while any file has unsaved edits."
  (interactive)
  (let ((unsaved (seq-filter (lambda (buffer)
                               (and (buffer-file-name buffer)
                                    (buffer-modified-p buffer)))
                             (buffer-list))))
    (if unsaved
        (user-error "No write since last change: %s (save with Space w)"
                    (mapconcat #'buffer-name unsaved ", "))
      (kill-emacs))))

;; A navigable buffer list, using Emacs's built-in Ibuffer.
(require 'ibuffer)
(hel-set-initial-state 'ibuffer-mode 'normal)

(defun altaria-delete-buffer ()
  "Close the buffer on the current Ibuffer row and refresh the list."
  (interactive)
  (when (kill-buffer (ibuffer-current-buffer t))
    (ibuffer-update nil)))

(hel-keymap-set ibuffer-mode-map :state '(normal emacs)
  "h" #'backward-char "j" #'ibuffer-forward-line
  "k" #'ibuffer-backward-line "l" #'forward-char
  "d" #'altaria-delete-buffer "RET" #'ibuffer-visit-buffer
  "q" #'quit-window)

(defun altaria-reload-config ()
  "Reload the saved Emacs configuration."
  (interactive)
  (load-file (expand-file-name "~/.config/emacs/init.el"))
  (message "Emacs configuration reloaded"))

;; Helix-style file picker: every file below the project root (Git-aware,
;; so ignored files stay hidden), or below the current directory elsewhere.
(require 'project)
(defun altaria-file-picker ()
  "Pick a file in the current project, like Helix's Space f."
  (interactive)
  (let ((project (or (project-current)
                     (cons 'transient default-directory))))
    (project-find-file-in nil (list (project-root project)) project)))

;; Like `hx .': a directory on the command line opens the file picker
;; over *scratch* instead of a directory listing, so C-g leaves *scratch*.
(defun altaria-pick-startup-directory ()
  "Open the file picker when Emacs was started on a directory."
  (let ((listing (window-buffer (selected-window))))
    (when (and (not noninteractive)
               (with-current-buffer listing (derived-mode-p 'dired-mode))
               (cdr command-line-args))
      (let ((default-directory (buffer-local-value 'default-directory listing)))
        (switch-to-buffer (get-scratch-buffer-create))
        (kill-buffer listing)
        (altaria-file-picker)))))
(add-hook 'emacs-startup-hook #'altaria-pick-startup-directory)

;; The macOS clipboard, as in Helix: Space y copies the selection, Space p/P
;; paste after/before it.  pbcopy/pbpaste work in terminal Emacs too, where
;; Emacs has no clipboard access of its own.
(defun altaria-clipboard-copy ()
  "Copy the selection to the system clipboard."
  (interactive)
  (unless (use-region-p)
    (user-error "Select some text first"))
  (let ((text (filter-buffer-substring (region-beginning) (region-end)))
        (coding-system-for-write 'utf-8))
    (with-temp-buffer
      (insert text)
      (call-process-region nil nil "pbcopy"))
    (message "Copied to clipboard")))

(defun altaria-clipboard-paste (paste-command)
  "Put the system clipboard in the kill ring and run Hel's PASTE-COMMAND."
  (let ((text (with-temp-buffer
                (let ((coding-system-for-read 'utf-8))
                  (call-process "pbpaste" nil t))
                (buffer-string))))
    (when (string-empty-p text)
      (user-error "The clipboard is empty"))
    (kill-new text)
    (call-interactively paste-command)))

(defun altaria-clipboard-paste-after ()
  "Paste the system clipboard after the selection."
  (interactive "*")
  (altaria-clipboard-paste #'hel-paste-after))

(defun altaria-clipboard-paste-before ()
  "Paste the system clipboard before the selection."
  (interactive "*")
  (altaria-clipboard-paste #'hel-paste-before))

;; Cmd+C in terminal Emacs.  The kitty keyboard protocol lets the terminal
;; report Cmd (super); Ghostty passes Cmd+C through when it has no selection
;; of its own (see its config), so it arrives here as s-c.
(require 'kkp)
(global-kkp-mode 1)
(keymap-global-set "s-c" #'altaria-clipboard-copy)

;; Built-in which-key displays the Space menu after a short pause.
(require 'which-key)
(setq which-key-idle-delay 0.2)
(which-key-mode 1)

(defvar altaria-leader-map (make-sparse-keymap)
  "Space leader commands for Hel normal state.")
(keymap-set altaria-leader-map "q"
            '(menu-item "Quit Emacs" altaria-quit))
(keymap-set altaria-leader-map "w"
            '(menu-item "Save file" save-buffer))
(keymap-set altaria-leader-map "b"
            '(menu-item "Buffer list" ibuffer))
(keymap-set altaria-leader-map "f"
            '(menu-item "File picker" altaria-file-picker))
(keymap-set altaria-leader-map "F"
            '(menu-item "Find file in current directory" find-file))
(keymap-set altaria-leader-map "c"
            '(menu-item "Evaluate code" altaria-evaluate))
(keymap-set altaria-leader-map "r"
            '(menu-item "Language REPL" altaria-repl))
(keymap-set altaria-leader-map "y"
            '(menu-item "Copy to clipboard" altaria-clipboard-copy))
(keymap-set altaria-leader-map "p"
            '(menu-item "Paste clipboard after" altaria-clipboard-paste-after))
(keymap-set altaria-leader-map "P"
            '(menu-item "Paste clipboard before" altaria-clipboard-paste-before))
(keymap-set altaria-leader-map "t"
            '(menu-item "Toggle Parinfer" altaria-toggle-parinfer))
(keymap-set altaria-leader-map "R"
            '(menu-item "Reload config" altaria-reload-config))
(keymap-set altaria-leader-map "j"
            '(menu-item "Jump history" altaria-jump-list))
(keymap-set altaria-leader-map "SPC"
            '(menu-item "M-x commands" execute-extended-command))
(keymap-set altaria-leader-map "k"
	    '(menu-item "Documentation" altaria-documentation))
(hel-keymap-global-set :state 'normal "SPC" altaria-leader-map)
