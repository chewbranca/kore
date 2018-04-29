(local bump (require "bump"))
(local sock (require "sock"))

(log "loading entity")
(local entity (require "entity"))
(log "loading projectile")
(local projectile (require "projectile"))
(log "loading rest of server")

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


(defn announce-players [client players]
  (each [uuid client-player (pairs players)]
    (when (~= uuid client.luuid)
      (: client :send :announce-player
         (entity.serialize client-player)))))


(defn broadcast-projectiles [clients projectiles]
  (let [serialized (projectile.serialize-all projectiles)]
    (when (> (# serialized) 0)
      (each [uuid client (pairs clients)]
        (: client :send :update-projectiles serialized)))))


(defn skip-collisions [item other]
  (if (= item.type other.type "projectile")
      false
      :else
      "slide"))


(defn update-projectile [world pjt dt]
  (let [x (+ pjt.x (* pjt.dx pjt.speed dt))
        y (+ pjt.y (* pjt.dy pjt.speed dt))
        (tl_x tl_y) (lfg.pixelToTile x y)]
    (: world :move pjt.uuid x y skip_collisions)))


(defn update-projectiles [world projectiles dt]
  (let [expired {}
        collisions {}]
    (each [uuid pjt (pairs projectiles)]
      ;;(set pjt.age (+ pjt.age dt))
      (if (> pjt.age pjt.max_age) (table.insert expired pjt.uuid pjt)
          :else
          (let [(actual_x actual_y cols len) (update-projectile world pjt dt)
                (tl_x tl_y) (lfg.pixelToTile actual_x actual_y)]
            (set pjt.x actual_x)
            (set pjt.y actual_y)
            (set pjt.tl_x tl_x)
            (set pjt.tl_y tl_y)
            (log "CHECKING COLLISIONS ON (%s)" len)
            (when (> len 0)
              (log "GOT %s COLLISIONS" len)
              ;;(set pjt.speed 0)
              (log "UPDATING AGE (%s) (%s)" pjt.age pjt.max_age)
              ;;(set pjt.age (+ pjt.age pjt.max_age))
              )
            )))
    (each [uuid pjt (pairs expired)]
      (table.remove projectiles uuid))))


(defn update [server dt]
  (let [sock_server server.server
        projectiles server.projectiles
        world server.world]
    (: sock_server :update)
    (update-projectiles world projectiles dt)
    (broadcast-projectiles server.clients projectiles)))


(defn run-server [port]
  (log "STARTING SERVER TO DOOM")
  (let [clients {}
        players {}
        projectiles {}
        server (sock.newServer "*" port)
        world (bump.newWorld 1)]
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
           (tset players client.luuid ent)
           (: world :add ent.clid ent.x ent.y ent.w ent.h)
           (announce-player client clients data)
           (announce-players client players))))

    (: server :on :send-player-state
       (fn [data client]
         (let [player (. players client.luuid)]
           (set player.x data.x)
           (set player.y data.y)
           (broadcast-event
            clients :player-update (entity.serialize player)))))

    (: server :on :new-projectile
       (fn [data client]
         (let [pjt (projectile.new data)]
           (tset projectiles pjt.uuid pjt)
           (log "CREATING NEW PROJECTILE WITH: %s" (ppsl data))
           (: world :add pjt.uuid pjt.x pjt.y pjt.w pjt.h)
           (broadcast-event
            clients :new-projectile (projectile.serialize pjt)))))

    {
     :server server
     :clients clients
     :players players
     :projectiles projectiles
     :world world}))


{:run-server run-server :port PORT :update update}
