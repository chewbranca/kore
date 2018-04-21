(local sock (require "sock"))

(local lg love.graphics)

(local lfg (require "lfg"))


(defn run-client [host port]
  (log "STARTING CLIENT CONNECTION")
  (let [client (sock.newClient host port)]
    (: client :on "connect"
       (fn [data] (log "Successfully connected to server: (%s)" data)))
    (: client :on "welcome"
       (fn [data] (log "Uh oh... got eere hello from server: %s" data.msg)))
    (: client :on "disconnect"
       (fn [data] (log "[ERROR] DISCONNECTED: %s" data)))
    (: client :on "attack-melee"
       (fn [action]
         (log "GOT ATTACK-MELEE COMMAND: %s" (ppsl action))
         (lfg.do_attack_melee action)))
    (: client :on "attack-spell"
       (fn [action]
         (log "GOT ATTACK-SPELL COMMAND: %s" (ppsl action))
         (lfg.do_attack_spell action)))

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
          (values :attack-melee action))
        (= button 2)
        (let [atype :attack-spell
              action {:x p-x :y p-y :dx n-dx :dy n-dy :type atype}]
          (values :attack-spell action)))))


(defn send-client-action [client action]
  (assert client)
  (set action.clid client.uuid)
  (log "sending client action")
  (: client :send action.type action))

{
 :run-client run-client
 :send-client-action send-client-action
 :mousepressed mousepressed
}
