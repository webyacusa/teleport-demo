package com.ibm.bamoe.access.clients;

import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;
import jakarta.ws.rs.Consumes;
import jakarta.ws.rs.POST;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.core.MediaType;

@RegisterRestClient(configKey = "notification")
@Path("/api/notify")
public interface NotificationClient {
    @POST
    @Consumes(MediaType.APPLICATION_JSON)
    void send(NotificationEvent event);

    class NotificationEvent {
        public String requestId;
        public String to;
        public String subject;
        public String body;
        public String severity;
    }
}
