;;; dap-java-steps.el --- Step definitions for dap-java  -*- lexical-binding: t; -*-

;; Copyright (C) 2018  Ivan Yonchovski

;; Author: Ivan Yonchovski <ivan.yonchovski@tick42.com>

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


;;; Code:

(require 'f)
(require 's)
(require 'dap-java)

(defun dap-java-steps-async-wait (pred callback)
  "Call CALLBACK when PRED becomes true."
  (let (timer
        (retry-count 0))
    (setq timer (run-with-timer
                 1
                 1
                 (lambda (&rest rest)
                   (if (funcall pred)
                       (progn
                         (cancel-timer timer)
                         (funcall callback))
                     (setq retry-count (1+ retry-count))
                     (message "The function failed, attempt %s" retry-count)))))))

(Given "^I have maven project \"\\([^\"]+\\)\" in \"\\([^\"]+\\)\"$"
  (lambda (project-name dir-name)
    (setq default-directory dap-java-test-root)

    ;; delete old directory
    (when (file-exists-p dir-name)
      (delete-directory dir-name t))

    ;; create directory structure
    (mkdir (expand-file-name
            (f-join   dir-name project-name "src" "main" "java" "temp")) t)

    ;; add pom.xml
    (with-temp-file (expand-file-name "pom.xml" (f-join dir-name project-name))
      (insert "
<project xmlns=\"http://maven.apache.org/POM/4.0.0\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"
  xsi:schemaLocation=\"http://maven.apache.org/POM/4.0.0 http://maven.apache.org/maven-v4_0_0.xsd\">
  <modelVersion>4.0.0</modelVersion>
  <groupId>test</groupId>
  <artifactId>test-project</artifactId>
  <packaging>jar</packaging>
  <version>1</version>
  <name>test-project</name>
  <url>http://maven.apache.org</url>

  <properties>
      <maven.compiler.source>1.8</maven.compiler.source>
      <maven.compiler.target>1.8</maven.compiler.target>
  </properties>
</project>"))))

(And "^I have a java file \"\\([^\"]+\\)\"$"
  (lambda (file-name)
    (setq default-directory dap-java-test-root)
    (find-file file-name)
    (save-buffer)))

(And "^I add project \"\\([^\"]+\\)\" folder \"\\([^\"]+\\)\" to the list of workspace folders$"
  (lambda (project dir-name)
    (add-to-list 'lsp-java--workspace-folders (f-join dap-java-test-root dir-name project))))

(And "^I start lsp-java$"
  (lambda ()
    (lsp-java-enable)))

(Then "^The server status must become \"\\([^\"]+\\)\"$"
  (lambda (status callback)
    (dap-java-steps-async-wait
     (lambda ()
       (if (s-equals? (s-trim (lsp-mode-line)) status)
           t
         (progn
           (message "Server status is %s" (lsp-mode-line))
           nil)))
     callback)))

(When "^I invoke \"\\([^\"]+\\)\" I should see error message \"\\([^\"]+\\)\"$"
  (lambda (command message)
    (condition-case err
        (funcall (intern command))
      (error (cl-assert (string= message (error-message-string err)) t (error-message-string err))))))

(Then "^I should see buffer \"\\([^\"]+\\)\" with content \"\\([^\"]+\\)\"$"
  (lambda (buffer-name buffer-content callback)
    (dap-java-steps-async-wait
     (lambda ()
       (when-let (buffer (get-buffer buffer-name))
         (with-current-buffer buffer
           (string= (buffer-string) buffer-content))))
     callback)))


(And "^I attach handler \"\\([^\"]+\\)\" to hook \"\\([^\"]+\\)\"$"
  (lambda (handler-name hook-name)
    (add-hook
     (intern hook-name)
     (lambda (_)
       (puthash handler-name 'called dap-handlers-called)))))

(Then "^The hook handler \"\\([^\"]+\\)\" would be called$"
  (lambda (handler-name callback)
    (dap-java-steps-async-wait
     (lambda ()
       (let ((result (eql 'called (gethash handler-name dap-handlers-called))))
         ;; clear the hash
         (remhash handler-name dap-handlers-called)
         result))
     callback)))

(When "^I go in active window"
  (lambda () (select-window (car (window-list )))))

;; (add-hook (intern ""))

(provide 'dap-java-steps)
;;; dap-java-steps.el ends here
