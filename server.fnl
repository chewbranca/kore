(local sock (require "sock"))

(local entity (require "entity"))

(local debug true)

(local PORT 34227)


(defn log-client-connected [uuid data client]
  (if debug
      (log "\n***CLIENT CONNECTED[%s]:\n\tDATA: %s\n\tCLIENT: %s\n\t"
           uuid (ppsl data) (ppsl client))))


(defn broadcast-event [clients etype data]
  (each [uuid client (pairs clients)]
    (: client :send etype data)))


(defn announce-player [client clients data]
  (let [atype :announce-player]
    (set data.type atype)
    (each [uuid client (pairs clients)]
      (when (~= uuid data.clid)
        (: client :send atype data)))))


(defn announce-players [client client-players]
  (each [uuid client-player (pairs client-players)]
    (when (~= uuid client.luuid)
      (: client :send :announce-player
         (entity.serializable-player client-player)))))



(defn run-server [port]
  (log "STARTING SERVER TO DOOM")
  (let [clients {}
        client-players {}
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

    (: server :on :announce-self
       (fn [data client]
         (let [ent (entity.create-player-entity data)
               layer (. lfg.map.layers "KoreEntities")]
           (tset client-players client.luuid ent)
           (announce-player client clients data)
           (announce-players client client-players))))

    (: server :on :send-player-state
       (fn [data client]
         (let [player (. client-players client.luuid)]
           (set player.x data.x)
           (set player.y data.y)
           (broadcast-event
            clients :player-update (entity.serializable-player player)))))

    server))


{:run-server run-server :port PORT}
