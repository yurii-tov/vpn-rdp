(defvar vpn-buffer)
(defvar vpn-server)
(defvar vpn-password)


(define-derived-mode vpn-mode nil "vpn-helper"
  (setq-local vpn-buffer vpn-buffer)
  (setq-local vpn-server vpn-server)
  (setq-local vpn-password vpn-password)
  (setq-local connected nil))


(progn
  (define-key vpn-mode-map (kbd "c") 'vpn-connect)
  (define-key vpn-mode-map (kbd "d") 'vpn-disconnect)
  (define-key vpn-mode-map (kbd "r") 'vpn-reconnect))


(setq vpn-cli-exe "c:/Program Files (x86)/Cisco/Cisco AnyConnect Secure Mobility Client/vpncli.exe")


(setq vpn-rdp-force-login nil)


(setq vpn-rdp-wd nil)


(defun run-vpn ()
  (interactive)
  (let* ((vpn-server (completing-read "Vpn server: "
                                      (and (boundp 'vpn-servers-history)
                                           vpn-servers-history)
                                      nil
                                      nil
                                      nil
                                      'vpn-servers-history))
         (vpn-password (read-passwd "Vpn Password: "))
         (vpn-buffer (format "*vpn:%s*" vpn-server)))
    (switch-to-buffer vpn-buffer)
    (when vpn-rdp-wd
      (cd vpn-rdp-wd))
    (vpn-mode)
    (vpn-disconnect)))


(defun vpn-helper-credentials-string (password)
  (format "%s%s\n"
          (if vpn-rdp-force-login "y\n" "")
          password))


(defun run-vpn-command (command)
  (erase-buffer)
  (make-process :name "vpn-command"
                :buffer vpn-buffer
                :command command
                :coding '(utf-8-unix . utf-8-unix)
                :filter (lambda (proc string)
                          (when (buffer-live-p (process-buffer proc))
                            (with-current-buffer (process-buffer proc)
                              (let ((moving (= (point) (process-mark proc))))
                                (save-excursion
                                  (goto-char (process-mark proc))
                                  (insert (replace-regexp-in-string "" "" string))
                                  (set-marker (process-mark proc) (point)))
                                (if moving (goto-char (process-mark proc)))))))))


(defun vpn-connect ()
  (interactive)
  (if connected
      (run-vpn-command
       (list "bash" "-c"
             "mstsc connect.rdp & cat connected.txt ; echo 'Press [D] to disconnect, [R] to reconnect'"))
    (run-vpn-command
     (list "bash" "-c"
           (format "printf '%s\n' | '%s' -s connect %s && mstsc connect.rdp & sleep 3s ; cat connected.txt; echo 'Press [D] to disconnect, [R] to reconnect'"
                   (vpn-helper-credentials-string vpn-password)
                   vpn-cli-exe
                   vpn-server))))
  (setq-local connected t))


(defun vpn-disconnect ()
  (interactive)
  (run-vpn-command
   (list "bash" "-c"
         (format "'%s' disconnect ; cat disconnected.txt; echo 'Press [C] to connect'" vpn-cli-exe)))
  (setq-local connected nil))


(defun vpn-reconnect ()
  (interactive)
  (run-vpn-command
   (list "bash" "-c"
         (format "'%s' disconnect ; printf '%s\n' | '%s' -s connect %s && mstsc connect.rdp & sleep 3s ; cat connected.txt; echo 'Press [D] to disconnect, [R] to reconnect'"
                 vpn-cli-exe
                 (vpn-helper-credentials-string vpn-password)
                 vpn-cli-exe
                 vpn-server)))
  (setq-local connected t))


(define-key global-map (kbd "C-c t") 'run-vpn)
