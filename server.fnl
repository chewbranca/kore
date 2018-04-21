(local sock (require "sock"))

(local debug true)

(local PORT 34227)


(defn log-client-connected [uuid data client]
  (if debug
      (log "\n***CLIENT CONNECTED[%s]:\n\tDATA: %s\n\tCLIENT: %s\n\t"
           uuid (ppsl data) (ppsl client))))


(defn run-server [port]
  (log "STARTING SERVER TO DOOM")
  (let [clients {}
        server (sock.newServer "*" port)]
    (: server :on "connect"
       (fn [data client]
         (let [uuid (lume.uuid)]
           (tset client :luuid uuid)
           (tset clients uuid client)
           (log-client-connected uuid data client)

           (: client :send "welcome" "welcome to your doom"))))

    server))


{:run-server run-server :port PORT}
