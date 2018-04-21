(local sock (require "sock"))

(local debug true)

(local PORT 34227)


(defn log-client-connected [uuid data client]
  (if debug
      (log "\n***CLIENT CONNECTED[%s]:\n\tDATA: %s\n\tCLIENT: %s\n\t"
           uuid (ppsl data) (ppsl client))))


(defn broadcast-event [clients etype data]
  (each [uuid client (pairs clients)]
    (: client :send etype data)))


(defn run-server [port]
  (log "STARTING SERVER TO DOOM")
  (let [clients {}
        server (sock.newServer "*" port)]
    (: server :on "connect"
       (fn [data client]
         (let [uuid (lume.uuid)
               msg "welcome to your doom"]
           (tset client :luuid uuid)
           (tset clients uuid client)
           (log-client-connected uuid data client)

           (: client :send "welcome" {:msg msg :uuid uuid}))))

    (: server :on :attack-melee
       (fn [data client]
         (log "MELEE ATTACK FROM CLIENT[%s]: %s" client.luuid (ppsl data))
         (broadcast-event clients :attack-melee data)))

    (: server :on :attack-spell
       (fn [data client]
         (log "SPELL ATTACK FROM CLIENT[%s]: %s" client.luuid (ppsl data))
         (broadcast-event clients :attack-spell data)))

    server))


{:run-server run-server :port PORT}
