(local sock (require "sock"))

(local lg love.graphics)

(local lfg (require "lfg"))
(local entity (require "entity"))


(defn run-client [host port bootstrap]
  (log "STARTING CLIENT CONNECTION")
  (let [client (sock.newClient host port)
        client-players {}
        players {}]
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
         (let [ent (entity.create-player-entity data)
               layer (. lfg.map.layers "KoreEntities")]
           (tset client-players data.clid ent)
           (entity.add-entity layer ent))))

    (: client :on "player-update"
       (fn [data]
         (let [player (. client-players data.clid)]
           ;; TODO better handle case of local player
           ;; issue being the local player isn't in client-players
           (when player
             (set player.x data.x)
             (set player.y data.y)))))

    (: client :connect)
    client))


(defn mousepressed [p-x p-y m-x m-y button]
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
              action {:x p-x :y p-y :dx n-dx :dy n-dy :type atype}]
          (values atype action)))))


(defn send-client-action [client action]
  (assert client)
  (set action.clid client.luuid)
  (: client :send action.type action))


(defn announce-self [client player]
  (let [action {:x player.x
                :y player.y
                :ox player.ox
                :oy player.oy
                :name player.name
                :char_name player.char.name
                :spell_name player.obj.spell.name ;; TODO: should be able to get player.spell
                :type :announce-self
                :clid client.luuid
               }]
    (send-client-action client action)))


(defn send-player-state [client player]
  (assert client)
  (: client :send :send-player-state (entity.serializable-player player)))


{
 :run-client run-client
 :send-client-action send-client-action
 :mousepressed mousepressed
 :announce-self announce-self
 :send-player-state send-player-state
}
