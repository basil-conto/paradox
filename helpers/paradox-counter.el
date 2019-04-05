;;; paradox-counter.el --- Functions for counting the number of stars on each github emacs package.

;; Copyright (C) 2014 Artur Malabarba <bruce.connor.am@gmail.com>

;; Author: Artur Malabarba <bruce.connor.am@gmail.com>
;; URL: http://github.com/Bruce-Connor/paradox
;; Version: 0.1
;; Prefix: paradox
;; Separator: -
;; Requires: paradox

;;; License:
;;
;; This file is NOT part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;

;;; Code:


(require 'paradox-github)
(require 'json)
(eval-when-compile (require 'cl))

(defcustom paradox-download-count-url
  "http://melpa.org/download_counts.json"
  ""
  :type 'string
  :group 'paradox)

(defvar paradox--output-data-file-old
  (expand-file-name "../data")
  "File where lists will be saved.")

(defcustom paradox--output-data-file
  (expand-file-name "../data-hashtables")
  "File where hashtables will be saved."
  :type 'file
  :group 'paradox-counter
  :package-version '(paradox-counter . "0.1"))

(defun paradox-log (&rest s)
  (princ (concat (apply #'format s) "\n") t))

(defun paradox--alist-to-table (list)
  (let ((table (make-hash-table)))
    (dolist (it list)
      (if (consp it)
          (puthash (car it) (cdr it) table)
        (puthash it t table)))
    table))

(defun paradox-list-to-file ()
  "Save lists in \"data\" file."
  (with-temp-file paradox--output-data-file
    (pp paradox--star-count (current-buffer))
    (pp paradox--package-repo-list (current-buffer))
    (pp paradox--download-count (current-buffer))
    (pp paradox--wiki-packages (current-buffer))))

(defun paradox-fetch-star-count (repo)
  (cdr (assq 'stargazers_count
             (paradox--github-action (format "repos/%s" repo)
               :reader #'json-read))))


;;;###autoload
(defun paradox-generate-star-count (&optional _recipes-dir)
  "Get the number of stars for each github repo and return.
Also saves result to `package-star-count'"
  (interactive)
  (setq paradox-github-token
        (or (getenv "GHTOKEN") paradox-github-token))
  (require 'json)
  (let ((json-key-type 'symbol)
        (json-object-type 'hash-table))
    (setq paradox--download-count
          (paradox--github-action paradox-download-count-url :reader #'json-read)))
  (let ((table-size (hash-table-count paradox--download-count)))
    (setq paradox--wiki-packages (make-hash-table :size table-size))
    (setq paradox--package-repo-list (make-hash-table :size table-size))
    (setq paradox--star-count (make-hash-table :size table-size)))
  (with-current-buffer (let ((inhibit-message t))
                         (url-retrieve-synchronously "http://melpa.org/recipes.json"))
    (search-forward "\n\n")
    (let ((i 0)
          (paradox--github-errors-to-ignore '(403 404)))
      (dolist (it (json-read))
        (redisplay)
        (ignore-errors
          (let ((name (car it)))
            (let-alist (cdr it)
              (paradox-log "%s / %s" (incf i) name)
              (pcase .fetcher
                (`"github"
                 (let ((count (paradox-fetch-star-count .repo)))
                   (if (numberp count)
                       (progn
                         (puthash name count paradox--star-count)
                         (puthash name .repo paradox--package-repo-list))
                     (paradox-log "FAILED: %s / %s" i name))))
                (`"wiki"
                 (puthash name t paradox--wiki-packages)))))))))
  (paradox-list-to-file))

(provide 'paradox-counter)
;;; paradox-counter.el ends here.
