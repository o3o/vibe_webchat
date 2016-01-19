import vibe.d;
final class WebChat {

   private Room[string] m_rooms;

   // GET /
   void get() {
      render!"index.dt";
   }

   // GET
   // usa id e name del form
   void getRoom(string id, string name) {
      string[] messages = getOrCreateRoom(id).messages;
      render!("room.dt", id, name, messages);
   }

   void postRoom(string id, string name, string message) {
      //e' eq. a message.length > 0
      if (message.length) {
			getOrCreateRoom(id).addMessage(name, message);
      }

      redirect("room?id="~id.urlEncode~"&name="~name.urlEncode);
   }

   // GET /ws?room=...&name=...
   void getWS(string room, string name, scope WebSocket socket) {
      logInfo("WebChat.getWS \t\tstart getWS");
      auto r = getOrCreateRoom(room);

      runTask({
         logInfo("WebChat.task \t\tstart task");
         auto nextMessage = r.messages.length;
         while (socket.connected) {
            while (nextMessage < r.messages.length) {
               string msg = r.messages[nextMessage++];
               logInfo("WebChat.task \t\tsocket send %s", msg);
               socket.send(msg);
            }
            r.waitForMessage(nextMessage);
         }
      });

      while (socket.waitForData) {
         auto message = socket.receiveText();
         if (message.length) {
            logInfo("WebChat.waitForData \t\tdata!");
            r.addMessage(name, message);
         } else {
            logInfo("no data");
         }
      }
      logInfo("WebChat.getWS \t\tend getWS");
   }

   private Room getOrCreateRoom(string id) {
      // se key e' un valore di tipo K e map e' un AA di tipo V[K], allora
      // l'espressione `key in map` ritorna un valore di tipo V* (cioe' un
      // puntatore a V). Se AA contiene la coppia <key, val>, `in` ritorna un
      // puntatore a val, altrimenti un puntatore a null
      // Nel nostro caso id e' di tipo string e m_rooms
      if (auto pr = id in m_rooms) {
         return *pr;
      } else {
         return m_rooms[id] = new Room;
      }
   }
}

final class Room {
   string[] messages;
   ManualEvent messageEvent;
   this() {
      messageEvent = createManualEvent();
   }

   void addMessage(string name, string message) {
      messages ~= name ~ ": " ~ message;
      messageEvent.emit();
      logInfo("Room.addMEssage \t\tadd %s from %s", message, name);
   }

   void waitForMessage(size_t nextMessage) {
      while (messages.length <= nextMessage) {
         logInfo("Room.waitForMessage \t\twait for %s msg", nextMessage);
         messageEvent.wait();
         logInfo("Room.waitForMessage \t\treceived  %s msg", nextMessage);
      }
   }
}

shared static this() {
   // the router will match incoming HTTP requests to the proper routes
   auto router = new URLRouter;
   // registers each method of WebChat in the router
   router.registerWebInterface(new WebChat);
   // match incoming requests to files in the public/ folder
   router.get("*", serveStaticFiles("public/"));

   auto settings = new HTTPServerSettings;
   settings.port = 8080;
   settings.bindAddresses = ["::1", "127.0.0.1"];
   listenHTTP(settings, router);
   logInfo("Please open http://127.0.0.1:8080/ in your browser.");
}
