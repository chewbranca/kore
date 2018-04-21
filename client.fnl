(local sock (require "sock"))

(local lg love.graphics)


(defn run-client [host port]
  (log "STARTING CLIENT CONNECTION")
  (let [client (sock.newClient host port)]
    (: client :on "connect"
       (fn [data] (log "Successfully connected to server: (%s)" data)))
    (: client :on "welcome"
       (fn [msg] (log "Uh oh... got eere hello from server: %s" msg)))
    (: client :on "disconnect"
       (fn [data] (log "[ERROR] DISCONNECTED: %s" data)))

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
        (let [action {:x p-x :y p-y :dx n-dx :dy n-dy :type :melee}]
          (values :attack-melee action))
        (= button 2)
        (let [action {:x p-x :y p-y :dx n-dx :dy n-dy :type :spell}]
          (values :attack-spell action)))))


{:run-client run-client :mousepressed mousepressed}
