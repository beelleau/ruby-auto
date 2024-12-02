;;; ruby-auto.el --- Ruby-environment auto-configuration tool for Emacs -*- lexical-binding: t -*-

;; Copyright (C) 2024 Kyle Belleau

;; Author: Kyle Belleau <kylejbelleau@gmail.com>
;; URL: https://github.com/beelleau/ruby-auto
;; Keywords: ruby environment configuration

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:
;; ruby-auto is an automatic environment configuration tool which inspects a
;; '.ruby-version' file in the buffer's directory tree to configure
;; necessary environment variables in Emacs.

;;; Code:
(defvar ruby-auto-rubies-dir (expand-file-name "~/.rubies")
  "Define directory to search for rubies on your system.
By default, $HOME/.rubies is searched.")

(defvar ruby-auto-gem-dir (expand-file-name "~/.gem")
  "Define the directory to search for gems on your system.
By default, $HOME/.gem is searched.")

;; internal functions
(defun ruby-auto--find-ruby-version-and-read ()
  "Search for the .ruby-version file and return its contents.
If the file is not found, return nil and display an error message."
  ;; assign local var 'dir' to the directory containing the .ruby-version file
  (let ((ruby-version-file
         (let ((dir (locate-dominating-file default-directory ".ruby-version")))
           ;; if found, grab the full path of .ruby-version
           (if dir
               (concat dir ".ruby-version")
             ;; if not found, print error message and return 'nil',
             ;; and we can exit in the main function
             (progn
               (message "[ruby-auto] error: '.ruby-version' file not found")
               nil)))))

    ;; if we have the path to .ruby-version, we grab the contents
    (when ruby-version-file
      (with-temp-buffer
        (insert-file-contents ruby-version-file)
        (let ((version (string-trim (buffer-string))))
          (if (string-match-p "\\`[0-9]+\\.[0-9]+\\.[0-9]+\\'" version)
              (concat "ruby-" version)
            version))))))

(defun ruby-auto--validate-ruby (ruby-version)
  "Finds the Ruby version specified in the .ruby-version file."
  (let ((ruby-dir (concat (file-name-as-directory ruby-auto-rubies-dir)
                          ruby-version)))

    (if (file-directory-p ruby-dir)
        (let ((ruby-interpreter (concat (file-name-as-directory ruby-dir)
                                        "bin/ruby")))
          (if (file-executable-p ruby-interpreter)
              ;; when both if statements succeed, return ruby-dir
              ruby-dir
            ;; if no executable ruby interpreter found in dir,
            ;; error and return nil
            (message "[ruby-auto] error: ruby not found in %s"
                     (concat (file-name-as-directory ruby-dir) "bin"))
            nil))

      ;; if ruby-version directory not found in rubies, error and return nil
      (message "[ruby-auto] error: could not find %s in %s"
               ruby-version ruby-auto-rubies-dir)
      nil)))

(defun ruby-auto--gather-environment (ruby-dir)
  "Gathers Ruby environment variables to set in our Emacs environment."
  (let* ((ruby-interpreter
          (concat (file-name-as-directory ruby-dir) "bin/ruby"))
         (rcmd (format "%s -e \"puts [RUBY_ENGINE, RUBY_VERSION].join(' ')\""
                      ruby-interpreter))
         ;; run the above ruby command and gather the output
         (routput (string-trim (shell-command-to-string rcmd)))
         (elements (split-string routput " " t)))

    (if (= (length elements) 2)
        (let ((ruby-engine (nth 0 elements))
              (ruby-version (nth 1 elements)))
          ;; call --set-environment here
          (ruby-auto--set-environment ruby-dir ruby-engine ruby-version))
      ;; don't like this message output; placeholder
      (message "[ruby-auto] error: unexpected command output: %s" routput)
      nil)))

(defun ruby-auto--set-environment (ruby-root ruby-engine ruby-version)
  "Sets Ruby environment variables in our Emacs environment."
  (let* ((current-ruby-root (getenv "RUBY_ROOT"))
         (current-gem-home (getenv "GEM_HOME"))
         (gem-home (concat (file-name-as-directory ruby-auto-gem-dir)
                               (file-name-as-directory ruby-engine)
                               ruby-version)))

    ;; setting a lambda for this since we may run it in two different conds
    (let ((set-vars (lambda ()
                      (setenv "RUBY_ROOT" ruby-root)
                      (setenv "GEM_HOME" gem-home))))
      (if current-ruby-root
          (if (and (string-equal current-ruby-root ruby-root)
                   (string-equal current-gem-home gem-home))
              ;; if above versions match, do nothing (same ruby versions used)
              nil

            ;; if RUBY_ROOT vars exist, but do not match
            ;; unset exec-path and set all variables and path
            (progn
              (funcall set-vars)
              (ruby-auto--unset-exec-path current-ruby-root
                                          current-gem-home)
              (ruby-auto--set-exec-path ruby-root gem-home)
              (message "[ruby-auto]: using %s" ruby-root)))

        ;; if RUBY_ROOT is not set, we'll set all of our vars
        (progn
          (funcall set-vars)
          (ruby-auto--set-exec-path ruby-root gem-home)
          (message "[ruby-auto]: using %s" ruby-root))))))

(defun ruby-auto--set-exec-path (ruby-root gem-home)
  "Sets `exec-path' in our Emacs' environment."
  (let ((ruby-root-bin (concat (file-name-as-directory ruby-root) "bin"))
        (gem-home-bin (concat (file-name-as-directory gem-home) "bin")))

    (add-to-list 'exec-path ruby-root-bin)
    (add-to-list 'exec-path gem-home-bin)))

(defun ruby-auto--unset-exec-path (ruby-root gem-home)
  "Removes old paths from `exec-path' in our Emacs' environment."
  (let ((ruby-root-bin (concat (file-name-as-directory ruby-root) "bin"))
        (gem-home-bin (concat (file-name-as-directory gem-home) "bin")))

    (setq exec-path (remove ruby-root-bin (remove gem-home-bin exec-path)))))

;; interactive function
(defun ruby-auto ()
  "Configures environment for Ruby."
  (interactive)
  ;; Check if the buffer is a TRAMP buffer
  (unless (file-remote-p default-directory)
    (let ((ruby-version (ruby-auto--find-ruby-version-and-read)))
      (if ruby-version
          (let ((ruby-dir (ruby-auto--validate-ruby ruby-version)))
            (if ruby-dir
                (ruby-auto--gather-environment ruby-dir)))))))

(provide 'ruby-auto)
;;; ruby-auto.el ends here
