;;; init.el --- minimal, clean config (WSL + macOS) -*- lexical-binding: t; -*-

;; ----------------------------
;; Basics / UI / files
;; ----------------------------
(setq inhibit-startup-message t
      initial-scratch-message nil
      make-backup-files nil
      auto-save-default nil)
;; Keep async native-comp warnings out of startup UI.
(setq native-comp-async-report-warnings-errors 'silent)

;; Auto-revert buffers when files change on disk
(global-auto-revert-mode 1)
(setq global-auto-revert-non-file-buffers t)

;; Move between windows with Alt+arrow (Meta+arrow)
(windmove-default-keybindings 'meta)

;; Keep Customize out of init.el
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

;; ----------------------------
;; Packages
;; ----------------------------
(setq package-enable-at-startup nil)
(require 'package)

(setq package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
        ("nongnu". "https://elpa.nongnu.org/nongnu/")
        ("melpa" . "https://melpa.org/packages/")))

(package-initialize)

;; Bootstrap use-package if needed
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(require 'use-package)
;; Be explicit per package to avoid surprise installs during startup.
(setq use-package-always-ensure nil)

;; ----------------------------
;; Rust: prefer classic rust-mode (no Tree-sitter grammar maintenance)
;; ----------------------------
(use-package rust-mode
  :ensure t
  :mode ("\\.rs\\'" . rust-mode))

;; Never remap Rust buffers to `rust-ts-mode`.
(setq major-mode-remap-alist
      (assq-delete-all 'rust-mode major-mode-remap-alist))
(add-to-list 'major-mode-remap-alist '(rust-ts-mode . rust-mode))

;; Vterm
(defun my/vterm-new-named (name)
  "Create a new named vterm buffer."
  (interactive "sName for terminal: ")
  (vterm (concat "vterm-" name)))

(defun my/vterm-agent (name dir)
  "Create a named vterm in DIR and run 'agent'."
  (interactive
   (list
    (read-string "Name for terminal: ")
    (read-directory-name "Directory: ")))
  (let ((default-directory dir))
    (vterm (concat "vterm-" name))
    (vterm-send-string "agent")
    (vterm-send-return)))

(use-package vterm
  :ensure t
  :commands (vterm vterm-send-string vterm-send-return)
  :bind (("C-c t t" . my/vterm-new-named)
         ("C-c t a" . my/vterm-agent)))

;; ----------------------------
;; Theme (choose ONE)
;; ----------------------------
(use-package doom-themes
  :ensure t
  :config
  ;; Pick one theme
  (load-theme 'doom-dracula t))

;; ----------------------------
;; Mouse support
;; ----------------------------
;; Only enable xterm mouse in terminal Emacs
(unless (display-graphic-p)
  (xterm-mouse-mode 1))

;; ----------------------------
;; Scrolling / redraw artifacts (black lines)
;; ----------------------------
(when (fboundp 'pixel-scroll-precision-mode)
  (pixel-scroll-precision-mode -1))
(add-to-list 'default-frame-alist '(inhibit-double-buffering . t))

(setq scroll-conservatively 101
      scroll-step 1
      scroll-margin 0)

;; ----------------------------
;; Completion (fuzzy-ish)
;; ----------------------------
(use-package vertico
  :ensure t
  :init (vertico-mode 1))
;; Use GNU ls on macOS for better sorting features

(when (executable-find "gls")
  (setq insert-directory-program "gls")
  (setq dired-listing-switches "-al --group-directories-first"))

(use-package orderless
  :ensure t
  :init
  (setq completion-styles '(orderless basic)
        completion-category-defaults nil
        completion-category-overrides '((file (styles basic partial-completion)))))

(setq completion-ignore-case t
      read-buffer-completion-ignore-case t
      read-file-name-completion-ignore-case t)

;; ----------------------------
;; Consult (buffer switching, project buffers)
;; ----------------------------
(use-package consult
  :ensure t
  :bind (("C-x b" . consult-buffer)
         ("C-c b" . consult-project-buffer)
         ("C-x <down>" . consult-buffer)
         ("C-x <up>" . consult-find)
         ("C-x C-<up>" . consult-ripgrep))
  :custom
  (consult-buffer-filter
   '("\\` "                              ; hidden/internal buffers
     "\\`\\*Messages\\*\\'"              ; Hides *Messages*
     "\\`\\*Completions\\*\\'"
     "\\`\\*Help\\*\\'"
     "\\`\\*Apropos\\*\\'"
     "\\`\\*Warnings\\*\\'"
     "\\`\\*Backtrace\\*\\'"
     "\\`\\*Async-native-compile-log\\*\\'"))
  :config
  (setq consult-buffer-sources
        '(consult-source-hidden-buffer       ; Enable access to hidden buffers (narrow with Space)
          consult-source-buffer              ; Open buffers
          consult-source-recent-file         ; Recent files
          consult-source-bookmark            ; Bookmarks
          consult-source-project-buffer      ; Project-specific buffers
          consult-source-project-recent-file ; Project-specific recent files
          )))
;; ----------------------------
;; Tabs (contexts as layouts)
;; ----------------------------
(tab-bar-mode 1)
(tab-bar-history-mode 1)

;; Your custom tab keys (fixed so they don't overwrite each other)
(global-set-key (kbd "C-c t n") #'tab-bar-new-tab)
(global-set-key (kbd "C-c t c") #'tab-bar-close-tab)
(global-set-key (kbd "C-c t s") #'tab-bar-switch-to-tab)
(global-set-key (kbd "C-c t p") #'tab-bar-switch-to-prev-tab)
(global-set-key (kbd "C-c t N") #'tab-bar-switch-to-next-tab) ; capital N

;; ----------------------------
;; Buffer cycling: skip buffers already visible in another window
;; ----------------------------
(require 'seq)
(with-eval-after-load 'window
  (add-to-list 'switch-to-prev-buffer-skip
               (lambda (win buf _bury-or-kill)
                 (let ((wins (get-buffer-window-list buf nil t))) ; all frames
                   (seq-some (lambda (w) (not (eq w win))) wins)))))


(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status)
  :config
  (setq magit-refresh-status-buffer nil)
  ;; Open magit status in the current window; diffs still get their own window
  (setq magit-display-buffer-function
        #'magit-display-buffer-same-window-except-diff-v1)
  ;; Restore the pre-magit window layout when quitting
  (setq magit-bury-buffer-function #'magit-restore-window-configuration))

;; Kill stale buffers automatically every 5 minutes
(use-package midnight
  :ensure nil
  :hook (after-init . midnight-mode)
  :config
  (setq clean-buffer-list-delay-general 300)
  (setq clean-buffer-list-kill-never-buffer-regexps
        '("vterm" "magit-status"))
  (run-with-timer 0 300 #'clean-buffer-list))

(use-package nerd-icons :ensure t)

(use-package dirvish
  :ensure t
  :init
  ;; Enable dirvish globally (replaces standard Dired)
  (dirvish-override-dired-mode)
  :config
  ;; 1. Terminal Visuals
  ;; Use Nerd Font icons (ensure your terminal font supports them!)
  ;; If icons look like boxes, change this to nil
  (setq dirvish-attributes
        '(nerd-icons file-time file-size collapse subtree-state vc-state git-msg))
  ;; 2. (Optional) Make the expansion arrows look nicer
  (setq dirvish-subtree-state-style 'nerd)
  ;; 2. Sidebar Settings ("The Treemacs replacement")
  (setq dirvish-side-width 30)
  (setq dirvish-side-auto-expand t) ;; Auto-expand folder when opening a file
  
  :bind
  ;; Bind the sidebar toggle
  (("C-x C-n" . dirvish-side)
   :map dirvish-mode-map
   ("TAB" . dirvish-subtree-toggle) ;; Tab to expand/collapse folders
   ("SPC" . dirvish-show-history)   ;; Space to see history
   ("f"   . dirvish-fd)))           ;; 'f' to fuzzy find using 'fd' (if installed)
;; ----------------------------
;; Display rules for temporary buffers
;; ----------------------------
(setq display-buffer-alist
      '(("\\*Help\\*\\|\\*Apropos\\*\\|\\*Completions\\*\\|\\*Warnings\\*\\|\\*Messages\\*\\|\\*Backtrace\\*"
         (display-buffer-reuse-window display-buffer-at-bottom)
         (window-height . 0.30))
        ("magit:.*"
         (display-buffer-same-window))))

;; ----------------------------
;; Built-in QoL
;; ----------------------------
(winner-mode 1)
(save-place-mode 1)
(savehist-mode 1)
(recentf-mode 1)

;; Clipboard (GUI)
(setq select-enable-clipboard t
      select-enable-primary t)

;; Clipboard integration for terminal on WSL + macOS
(cond
 ;; WSL -> Windows clipboard
 ((and (eq system-type 'gnu/linux) (getenv "WSLENV"))
  (defun my/wsl-copy-to-clipboard (text &optional _push)
    (let ((process-connection-type nil))
      (let ((proc (start-process "clip.exe" nil "clip.exe")))
        (process-send-string proc text)
        (process-send-eof proc))))
  (defun my/wsl-paste-from-clipboard ()
    (string-trim-right
     (shell-command-to-string "powershell.exe -Command Get-Clipboard")))
  (setq interprogram-cut-function #'my/wsl-copy-to-clipboard
        interprogram-paste-function #'my/wsl-paste-from-clipboard))

 ;; macOS terminal Emacs -> pbcopy/pbpaste
 ((eq system-type 'darwin)
  (defun my/macos-copy-to-clipboard (text &optional _push)
    (let ((process-connection-type nil))
      (let ((proc (start-process "pbcopy" nil "pbcopy")))
        (process-send-string proc text)
        (process-send-eof proc))))
  (defun my/macos-paste-from-clipboard ()
    (string-trim-right (shell-command-to-string "pbpaste")))
  (setq interprogram-cut-function #'my/macos-copy-to-clipboard
        interprogram-paste-function #'my/macos-paste-from-clipboard)))

(setq ring-bell-function 'ignore)

;; Org-mode

;; 1. Core Org Configuration (Sensible Defaults)
(use-package org
  :ensure nil ;; Built-in, no need to install
  :hook ((org-mode . visual-line-mode)  ;; Wrap lines at window edge
         (org-mode . org-indent-mode))  ;; Indent text visibly (virtual indentation)
  :config
  (require 'org-tempo)                ;; Enables <q, <s, <e expansions
  (setq org-ellipsis " ▾")           ;; Symbol for collapsed headings
  (setq org-hide-emphasis-markers t) ;; Hide the *bold* /italics/ markers
  (setq org-src-fontify-natively t)  ;; Syntax highlighting in code blocks
  (setq org-log-done 'time)          ;; Log the time when a task is done
  
  ;; Set your specific agenda files or directory here
  ;; (setq org-agenda-files '("~/org/")) 
  )

;; 2. Make it look good (Terminal Bullets)
(use-package org-superstar
  :ensure t
  :after org
  :hook (org-mode . org-superstar-mode)
  :config
  ;; Hide the leading bullets for cleaner look
  (setq org-superstar-remove-leading-stars t)
  ;; Set specific bullets that work well in terminals
  (setq org-superstar-headline-bullets-list '("◉" "○" "●" "○" "●" "○" "●")))

(setq org-return-follows-link t)

;; 3. Make editing natural (Toggle emphasis markers)
(use-package org-appear
  :ensure t
  :hook (org-mode . org-appear-mode)
  :config
  ;; Toggle markers for bold, italics, links, sub/superscripts
  (setq org-appear-autolinks t)
  (setq org-appear-autosubmarkers t)
  (setq org-appear-autoentities t))

;; 4. Center the view (Zen Mode)
(use-package olivetti
  :ensure t
  :bind ("C-c o" . olivetti-mode) ;; Manual toggle
  :config
  (setq olivetti-body-width 100)) ;; Adjust width (chars) for your monitor

;; 5. Utilities (Links & TOC)
(use-package org-cliplink
  :ensure t
  :bind ("C-c p l" . org-cliplink)) ;; Bind to 'Control-c p l' (Paste Link)

(use-package org-sidebar
  :ensure t
  :bind ("C-c s" . org-sidebar-tree)) ;; Bind to 'Control-c s'

;; Yascroll
;; --- 1. Line Numbers Strategy: Blacklist ---

;; A. Turn on line numbers for EVERYTHING by default
(global-display-line-numbers-mode 1)

;; B. The "Blacklist": Turn them OFF for these specific modes
(dolist (mode '(org-mode-hook          ;; Org Mode (cleaner without)
                dired-mode-hook        ;; File browser (Dirvish/Dired)
                dirvish-mode-hook      ;; Dirvish specific
                term-mode-hook         ;; Terminal emulator
                vterm-mode-hook        ;; Better terminal emulator
                shell-mode-hook        ;; Shell
                eshell-mode-hook       ;; Eshell
                treemacs-mode-hook     ;; Treemacs (if you use it)
                pdf-view-mode-hook))   ;; PDF Viewer
  (add-hook mode (lambda () (display-line-numbers-mode 0))))

(use-package magit-delta
  :ensure t
  :hook (magit-mode . magit-delta-mode))

(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" . gfm-mode)  ; Use GitHub Flavored Markdown for .md files
  :init (setq markdown-command "multimarkdown"))

(defun my-gh-renderer (begin end buffer)
  "Render region using the GitHub CLI API."
  (let ((gh-executable (executable-find "gh")))
    (if (not gh-executable)
        (error "GitHub CLI 'gh' not found. Please install it first.")
      (call-process-region begin end gh-executable nil buffer nil
                           "api" "/markdown" "-f" "text=@-"))))

;; Set the renderer
(setq markdown-command 'my-gh-renderer)

(require 'eglot)

;; Tell eglot to use 'mpls' for markdown and GFM modes
(add-to-list 'eglot-server-programs
             '((markdown-mode gfm-mode) . ("mpls")))

;; Automatically start the server when you open a markdown file
(add-hook 'markdown-mode-hook 'eglot-ensure)

;; Keep track of the server so we don't accidentally start multiple
(defvar my-grip-process nil)

(defun md-preview ()
  "Start a Grip server for the current file and open it in the browser."
  (interactive)
  (let ((input-file (buffer-file-name))
        (grip-cmd (executable-find "grip")))

    ;; Sanity checks
    (unless grip-cmd
      (error "Grip executable not found! Please run 'pip install grip'"))
    (unless input-file
      (error "This buffer is not visiting a file! Save it first."))

    ;; Kill the old Grip server if one is already running
    (when (processp my-grip-process)
      (delete-process my-grip-process)
      (message "Killed previous Grip server."))

    (message "Starting new Grip server...")

    ;; Start Grip as a background process tied to this Emacs session
    (setq my-grip-process
          (start-process "grip-server" "*grip-output*" grip-cmd input-file))

    ;; Give the Python server a second to initialize
    (sleep-for 1)

    ;; Open your browser to Grip's default port
    (browse-url "http://localhost:6419")
    (message "Grip server running! Just save your file in Emacs and refresh your browser.")))

;; Enable Sixel or Kitty support specifically
(setq display-images-in-terminals t)

(use-package ibuffer
  :ensure nil
  :bind ("C-x C-b" . ibuffer)
  :config
  (setq ibuffer-expert t) ;; Don't ask for confirmation to delete
  (setq ibuffer-show-empty-filter-groups nil) ;; Don't show groups with no buffers

  ;; specific groups to organize your buffers
  (setq ibuffer-saved-filter-groups
        '(("default"
           ("Dired" (mode . dired-mode))
           ("Org" (mode . org-mode))
           ("Magit" (name . "^magit"))
           ("Shell" (or (mode . eshell-mode) (mode . shell-mode)))
           ("Emacs" (or
                     (name . "^\\*scratch\\*$")
                     (name . "^\\*Messages\\*$"))))))

  ;; Hook to automatically load these groups when ibuffer opens
  (add-hook 'ibuffer-mode-hook
            (lambda ()
              (ibuffer-switch-to-saved-filter-groups "default"))))

(use-package org-roam
  :if (locate-library "org-roam")
  :ensure nil
  :commands (org-roam-buffer-toggle org-roam-node-find org-roam-node-insert)
  :custom
  (org-roam-directory (file-truename "~/notes")) ; Create this folder!
  :bind (("C-c n l" . org-roam-buffer-toggle)
         ("C-c n f" . org-roam-node-find)
         ("C-c n i" . org-roam-node-insert))
  :config
  (org-roam-setup))

(setq windmove-ignore-window-parameters t)
(provide 'init)
;;; init.el ends here
