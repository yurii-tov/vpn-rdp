(defvar vpn-buffer)
(defvar vpn-server)
(defvar vpn-password)


(define-derived-mode vpn-mode nil "vpn-helper"
  (setq-local vpn-buffer vpn-buffer)
  (setq-local vpn-server vpn-server)
  (setq-local vpn-password vpn-password))


(progn
  (define-key vpn-mode-map (kbd "c") 'vpn-connect)
  (define-key vpn-mode-map (kbd "d") 'vpn-disconnect)
  (define-key vpn-mode-map (kbd "r") 'vpn-reconnect)
  (define-key vpn-mode-map (kbd "s") 'vpn-status))


(setq vpn-cli-exe "c:/Program Files (x86)/Cisco/Cisco AnyConnect Secure Mobility Client/vpncli.exe")


(setq vpn-helper-force-login nil)


(defun run-vpn ()
  (interactive)
  (let* ((vpn-server (read-string "Vpn server: "))
         (vpn-password (read-passwd "Vpn Password: "))
         (vpn-buffer (format "*vpn:%s*" vpn-server)))
    (switch-to-buffer vpn-buffer)
    (vpn-mode)
    (vpn-disconnect)))


(defun vpn-helper-credentials-string (password)
  (format "%s%s\n"
          (if vpn-helper-force-login "y\n" "")
          password))


(defmacro define-vpn-command (name command)
  `(defun ,(intern (concat "vpn-" (symbol-name name))) ()
     (interactive)
     (erase-buffer)
     (make-process :name ,(concat "vpn-" (symbol-name name))
                   :buffer vpn-buffer
                   :command ,command
                   :coding '(utf-8-unix . utf-8-unix)
                   :filter (lambda (proc string)
                             (when (buffer-live-p (process-buffer proc))
                               (with-current-buffer (process-buffer proc)
                                 (let ((moving (= (point) (process-mark proc))))
                                   (save-excursion
                                     (goto-char (process-mark proc))
                                     (insert (replace-regexp-in-string "" "" string))
                                     (set-marker (process-mark proc) (point)))
                                   (if moving (goto-char (process-mark proc))))))))))


(define-vpn-command status (cons vpn-cli-exe '("status")))


(define-vpn-command connect
  (list "bash" "-c"
        (format "printf '%s\n' | '%s' -s connect %s && mstsc connect.rdp & sleep 3s ; cat connected.txt; echo 'Press [D] to disconnect, [R] to reconnect'"
                (vpn-helper-credentials-string vpn-password)
                vpn-cli-exe
                vpn-server)))


(define-vpn-command disconnect
  (list "bash" "-c"
        (format "'%s' disconnect ; cat disconnected.txt; echo 'Press [C] to connect'" vpn-cli-exe)))


(define-vpn-command reconnect
  (list "bash" "-c"
        (format "'%s' disconnect ; printf '%s\n' | '%s' -s connect %s && mstsc connect.rdp & sleep 3s ; cat connected.txt; echo 'Press [D] to disconnect, [R] to reconnect'"
                vpn-cli-exe
                (vpn-helper-credentials-string vpn-password)
                vpn-cli-exe
                vpn-server)))


(define-key global-map (kbd "C-c t") 'run-vpn)
