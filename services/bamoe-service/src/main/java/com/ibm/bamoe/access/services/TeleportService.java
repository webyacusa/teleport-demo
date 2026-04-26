package com.ibm.bamoe.access.services;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import jakarta.annotation.PostConstruct;
import jakarta.enterprise.context.ApplicationScoped;

@ApplicationScoped
public class TeleportService {

    private static final Logger LOG = Logger.getLogger(TeleportService.class);

    @ConfigProperty(name = "teleport.adapter.url", defaultValue = "http://teleport-adapter:3500")
    String adapterUrl;

    private HttpClient http;

    @PostConstruct
    void init() {
        this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(5)).build();
        LOG.infof("TeleportService initialized: adapter=%s", adapterUrl);
    }

    public void createUser(String username, String firstName, String lastName, String email) {
        String body = String.format(
            "{\"username\":\"%s\",\"firstName\":\"%s\",\"lastName\":\"%s\",\"email\":\"%s\"}",
            username,
            firstName != null ? firstName : "",
            lastName != null ? lastName : "",
            email != null ? email : "");
        post(adapterUrl + "/api/users", body, "createUser");
    }

    public void addToAccessList(String username, String role, String requestId, String notes) {
        String body = String.format(
            "{\"username\":\"%s\",\"role\":\"%s\",\"requestId\":\"%s\",\"notes\":\"%s\"}",
            username, role,
            requestId != null ? requestId : "",
            notes != null ? notes.replace("\"", "'") : "");
        post(adapterUrl + "/api/access-lists/members", body, "addToAccessList");
    }

    private void post(String url, String body, String op) {
        HttpRequest req = HttpRequest.newBuilder()
                .uri(URI.create(url))
                .timeout(Duration.ofSeconds(15))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body)).build();
        try {
            HttpResponse<String> resp = http.send(req, HttpResponse.BodyHandlers.ofString());
            if (resp.statusCode() / 100 != 2) {
                throw new RuntimeException("Teleport " + op + " failed: HTTP "
                        + resp.statusCode() + " — " + resp.body());
            }
            LOG.infof("Teleport %s OK — %s", op, resp.body());
        } catch (Exception e) {
            throw new RuntimeException("Teleport " + op + " exception: " + e.getMessage(), e);
        }
    }
}
