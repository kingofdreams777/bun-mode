;;; bun-mode.el --- minor mode for working with bun projects

;; Version: 0.1.0
;; Author: Ross Martin <rossmartin@sandiego.edu>
;; Url: https://github.com/kingofdreams777/bun-mode
;; Keywords: convenience, project, javascript, node, bun
;; Package-Requires: ((emacs "24.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This package allows you to easily work with bun projects.  It provides
;; a minor mode for convenient interactive use of API with a
;; mode-specific command keymap.
;;
;; | command                       | keymap       | description                         |
;; |-------------------------------|--------------|-------------------------------------|
;; | bun-mode-bun-init             | <kbd>n</kbd> | Initialize new project              |
;; | bun-mode-bun-install          | <kbd>i</kbd> | Install all project dependencies    |
;; | bun-mode-bun-install-save     | <kbd>s</kbd> | Add new project dependency          |
;; | bun-mode-bun-install-save-dev | <kbd>d</kbd> | Add new project dev dependency      |
;; | bun-mode-bun-uninstall        | <kbd>u</kbd> | Remove project dependency           |
;; | bun-mode-bun-list             | <kbd>l</kbd> | List installed project dependencies |
;; | bun-mode-bun-test             | <kbd>t</kbd> | Run project tests                   |
;; | bun-mode-bun-run              | <kbd>r</kbd> | Run project script                  |
;; | bun-mode-visit-project-file   | <kbd>v</kbd> | Visit project package.json file     |
;; |                               | <kbd>?</kbd> | Display keymap commands             |

;;; Credit:

;; Lots of Credit to MojoChao for his npm-mode project
;; https://github.com/mojochao/npm-mode
;;; Code:

(require 'json)

(defvar bun-mode--project-file-name "package.json"
  "The name of bun project files.")

(defvar bun-mode--modeline-name " bun"
  "Name of bun mode modeline name.")

(defun bun-mode--ensure-bun-module ()
  "Asserts that you're currently inside an bun module"
  (bun-mode--project-file))

(defun bun-mode--project-file ()
  "Return path to the project file, or nil.
If project file exists in the current working directory, or a
parent directory recursively, return its path.  Otherwise, return
nil."
  (let ((dir (locate-dominating-file default-directory bun-mode--project-file-name)))
    (unless dir
      (error (concat "Error: cannot find " bun-mode--project-file-name)))
    (concat dir bun-mode--project-file-name)))

(defun bun-mode--get-project-property (prop)
  "Get the given PROP from the current project file."
  (let* ((project-file (bun-mode--project-file))
         (json-object-type 'hash-table)
         (json-contents (with-temp-buffer
                          (insert-file-contents project-file)
                          (buffer-string)))
         (json-hash (json-read-from-string json-contents))
         (value (gethash prop json-hash))
         (commands (list)))
    (cond ((hash-table-p value)
           (maphash (lambda (key value)
                      (setq commands
                            (append commands
                                    (list (list key (format "%s %s" "bun" key))))
                            ))
                    value)
           commands)
          (t value))))

(defun bun-mode--get-project-scripts ()
  "Get a list of project scripts."
  (bun-mode--get-project-property "scripts"))

(defun bun-mode--get-project-dependencies ()
  "Get a list of project dependencies."
  (bun-mode--get-project-property "dependencies"))

(defun bun-mode--exec-process (cmd &optional comint)
  "Execute a process running CMD."
  (let ((compilation-buffer-name-function
         (lambda (mode)
           (format "*bun:%s - %s*"
                   (bun-mode--get-project-property "name") cmd))))
    (message (concat "Running " cmd))
    (compile cmd comint)))

(defun bun-mode-bun-clean ()
  "Clean the node_modules directory"
  (interactive)
  (let ((dir (concat (file-name-directory (bun-mode--ensure-bun-module)) "node_modules")))
    (if (file-directory-p dir)
        (when (yes-or-no-p (format "Are you sure you wish to delete %s" dir))
          (bun-mode--exec-process (format "rm -rf %s" dir)))
      (message (format "%s has already been cleaned" dir)))))

(defun bun-mode-bun-init ()
  "Run the bun init command."
  (interactive)
  (bun-mode--exec-process "bun init"))

(defun bun-mode-bun-install ()
  "Run the 'bun install' command."
  (interactive)
  (bun-mode--exec-process "bun install"))

(defun bun-mode-bun-install-save (dep)
  "Run the 'bun install %package%' command for DEP."
  (interactive "sEnter package name: ")
  (bun-mode--exec-process (format "bun install %s" dep)))

(defun bun-mode-bun-install-save-dev (dep)
  "Run the 'bun install -D %package%' command for DEP."
  (interactive "sEnter package name: ")
  (bun-mode--exec-process (format "bun install -D %s" dep)))

(defun bun-mode-bun-uninstall ()
  "Run the 'bun remove' command."
  (interactive)
  (let ((dep (completing-read "Uninstall dependency: " (bun-mode--get-project-dependencies))))
    (bun-mode--exec-process (format "bun remove %s" dep))))

(defun bun-mode-bun-list ()
  "Run the 'bun list' command."
  (interactive)
  (bun-mode--exec-process "bun pm ls"))

(defun bun-mode-bun-test ()
  "Run tests with the 'bun test' command."
  (interactive)
  (bun-mode--exec-process "bun test"))

(defun bun-run--read-command ()
  (completing-read "Run script: " (bun-mode--get-project-scripts)))

(defun bun-mode-bun-run (script &optional comint)
  "Run the 'bun run' command on a project script."
  (interactive
   (list (bun-run--read-command)
         (consp current-prefix-arg)))
  (bun-mode--exec-process (format "bun run %s" script) comint))

(defun bun-mode-visit-project-file ()
  "Visit the project file."
  (interactive)
  (find-file (bun-mode--project-file)))

(defgroup bun-mode nil
  "Customization group for bun-mode."
  :group 'convenience)

(defcustom bun-mode-command-prefix "C-c n"
  "Prefix for bun-mode."
  :group 'bun-mode)

(defvar bun-mode-command-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "n" 'bun-mode-bun-init)
    (define-key map "i" 'bun-mode-bun-install)
    (define-key map "s" 'bun-mode-bun-install-save)
    (define-key map "d" 'bun-mode-bun-install-save-dev)
    (define-key map "u" 'bun-mode-bun-uninstall)
    (define-key map "l" 'bun-mode-bun-list)
    (define-key map "r" 'bun-mode-bun-run)
    (define-key map "v" 'bun-mode-visit-project-file)
    (define-key map "t" 'bun-mode-bun-test)
    map)
  "Keymap for bun-mode commands.")

(defvar bun-mode-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd bun-mode-command-prefix) bun-mode-command-keymap)
    map)
  "Keymap for `bun-mode'.")

;;;###autoload
(define-minor-mode bun-mode
  "Minor mode for working with bun projects."
  nil
  bun-mode--modeline-name
  bun-mode-keymap
  :group 'bun-mode)

;;;###autoload
(define-globalized-minor-mode bun-global-mode
  bun-mode
  bun-mode)

(provide 'bun-mode)
;;; bun-mode.el ends here
