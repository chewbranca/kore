(local sock (require "sock"))

(local lg love.graphics)

(local lfg (require "lfg"))
(local entity (require "entity"))
(local projectile (require "projectile"))


(defn run-client [host port bootstrap]
  (log "STARTING CLIENT CONNECTION")
  (let [client (sock.newClient host port)
        players {}
        projectiles {}]
    (: client :on "connect"
       (fn [data] (log "Successfully connected to server: (%s)" data)))

    (: client :on "welcome"
       (fn [data]
         (log "Uh oh... got eere hello from server: %s" data.msg)
         (set client.luuid data.uuid)
         (bootstrap)))

    (: client :on "disconnect"
       (fn [data] (log "[ERROR] DISCONNECTED: %s" data)))

    (: client :on "attack-melee"
       (fn [action]
         (lfg.do_attack_melee action)))

    (: client :on "attack-spell"
       (fn [action]
         (lfg.do_attack_spell action)))

    (: client :on "announce-player"
       (fn [data]
         (log "GOT PLAYER ANNOUNCE: %s" (ppsl data))
         (let [ent (entity.create-player-entity data)
               layer (. lfg.map.layers "KoreEntities")]
           (tset players data.clid ent)
           (entity.add-entity layer ent))))

    (: client :on "player-update"
       (fn [data]
         (let [player (. players data.clid)]
           ;; TODO better handle case of local player
           ;; issue being the local player isn't in players
           (when player
             (set player.x data.x)
             (set player.y data.y)))))

    (: client :on "new-projectile"
       (fn [data]
         (let [pjt (projectile.new data)
               layer (. lfg.map.layers "KoreProjectiles")]
           (tset projectiles pjt.uuid pjt)
           (projectile.add-projectile layer pjt true))))

    (: client :on "update-projectiles"
       (fn [data]
         ;;(log "UPDATING PROJECTILES WITH: %s\nEXISTING PROJECTILES: %s" (ppsl data) (ppsl projectiles))
         (each [i spjt (ipairs data)]
           (let [pjt (. projectiles spjt.uuid)]
             (when pjt
                (set pjt.x spjt.x)
                (set pjt.y spjt.y))))))

    (: client :connect)
    {:client client :players players}))


(defn mousepressed [p-x p-y m-x m-y button player]
  ;; w-{x,y} = window-{x,y} middle of screen
  ;; p-{x,y} = player-{x,y} actual player location
  ;; m-{x,y} = mouse-{x,y}  mouse location
  ;;
  ;; need window location to measure angle to mouse
  ;; but we need player location for initial pjt x,y
  (let [w-x (math.floor (/ (lg.getWidth) 2))
        w-y (math.floor (/ (lg.getHeight) 2))
        angle (lume.angle w-x w-y m-x m-y)
        distance (lume.distance w-x w-y m-x m-y)
        (e-dx e-dy) (lume.vector angle distance)
        n-dx (/ e-dx distance)
        n-dy (/ e-dy distance)]
    (if (= button 1)
        (let [atype :attack-melee
              action {:x p-x :y p-y :dx n-dx :dy n-dy :type atype}]
          (values atype action))
        (= button 2)
        (let [atype :attack-spell
              spell-name player.spell.name
              dir (. lfg.ndirs player.cdir)
              action {:x p-x :y p-y :dx n-dx :dy n-dy :dir dir
                      :type atype :spell-name spell-name}]
          (values atype action)))))


(defn send-client-action [client action]
  (assert client.client)
  (set action.clid client.client.luuid)
  (: client.client :send action.type action))


(defn send-projectile [client pjt]
  (let [spjt (projectile.serialize pjt)]
    (set pjt.last  spjt)
    (: client.client :send :new-projectile spjt)))


(defn announce-self [client player]
  (let [action {:x player.x
                :y player.y
                :ox player.ox
                :oy player.oy
                :name player.name
                :char_name player.char.name
                :spell_name player.obj.spell.name ;; TODO: should be able to get player.spell
                :type :announce-self
                :clid client.client.luuid
               }]
    (send-client-action client action)))


(defn send-player-state [client player]
  (assert client.client)
  (: client.client :send :send-player-state (entity.serialize player)))


(defn update [client dt]
  (: client.client :update))


{
 :run-client run-client
 :send-client-action send-client-action
 :send-projectile send-projectile
 :mousepressed mousepressed
 :announce-self announce-self
 :send-player-state send-player-state
 :update update
}
