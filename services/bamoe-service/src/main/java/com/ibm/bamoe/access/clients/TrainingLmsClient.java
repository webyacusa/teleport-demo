package com.ibm.bamoe.access.clients;

import java.util.List;
import org.eclipse.microprofile.rest.client.inject.RegisterRestClient;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.PathParam;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

@RegisterRestClient(configKey = "training-lms")
@Path("/api/training")
public interface TrainingLmsClient {

    @GET
    @Path("/{userId}/completed")
    @Produces(MediaType.APPLICATION_JSON)
    TrainingResponse getCompletedModules(@PathParam("userId") String userId);

    class TrainingResponse {
        public String userId;
        public List<String> completedModules;
        public String lastUpdated;
    }
}
