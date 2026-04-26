package com.ibm.bamoe.access.services;

import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.eclipse.microprofile.rest.client.inject.RestClient;
import org.jboss.logging.Logger;

import com.ibm.bamoe.access.clients.NotificationClient;
import com.ibm.bamoe.access.clients.TrainingLmsClient;
import com.ibm.bamoe.access.model.AccessRequest;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Orchestrates the access provisioning workflow.
 *
 * The same flow that previously lived in BPMN — fetch training, validate
 * compliance, create a manager task on success, on approval call Teleport
 * to provision the user and add them to the right access list, then notify.
 *
 * State is held in-memory (good enough for the demo). Pending manager
 * tasks are exposed via REST for the operator UI.
 */
@ApplicationScoped
public class WorkflowOrchestrator {

    private static final Logger LOG = Logger.getLogger(WorkflowOrchestrator.class);

    @Inject @RestClient TrainingLmsClient trainingClient;
    @Inject @RestClient NotificationClient notificationClient;
    @Inject TrainingComplianceService complianceService;
    @Inject TeleportService teleportService;

    private final Map<String, AccessRequest> requestsByRequestId = new ConcurrentHashMap<>();
    private final Map<String, String> taskIdToRequestId = new ConcurrentHashMap<>();

    public AccessRequest startRequest(Map<String, Object> payload) {
        AccessRequest r = new AccessRequest();
        r.requestId    = (String) payload.getOrDefault("requestId", "REQ-" + UUID.randomUUID().toString().substring(0, 6));
        r.userId       = (String) payload.get("userId");
        r.firstName    = (String) payload.get("firstName");
        r.lastName     = (String) payload.get("lastName");
        r.email        = (String) payload.get("email");
        r.role         = (String) payload.get("role");
        r.managerEmail = (String) payload.get("managerEmail");
        requestsByRequestId.put(r.requestId, r);

        LOG.infof("[AUDIT] requestId=%s userId=%s role=%s started", r.requestId, r.userId, r.role);

        // Step 1: fetch training
        try {
            TrainingLmsClient.TrainingResponse resp = trainingClient.getCompletedModules(r.userId);
            r.completedModules = (resp != null && resp.completedModules != null) ? resp.completedModules : List.of();
        } catch (Exception e) {
            LOG.warnf("Training fetch failed for %s: %s", r.userId, e.getMessage());
            r.completedModules = List.of();
        }
        r.stepStatus.put("training", "DONE");

        // Step 2: compliance check
        r.qualified = complianceService.isQualified(r.role, r.completedModules);
        if (!r.qualified) {
            r.stepStatus.put("training", "FAILED");
            r.stepStatus.put("manager", "SKIPPED");
            r.stepStatus.put("teleport-user", "SKIPPED");
            r.stepStatus.put("access-list", "SKIPPED");
            r.status = "TRAINING_GAP";
            r.failureReason = "Training requirements not met for role " + r.role;
            notifyFailure(r);
            return r;
        }

        // Step 3: create manager task — workflow pauses here
        r.pendingTaskId = "TASK-" + UUID.randomUUID().toString().substring(0, 8);
        r.stepStatus.put("manager", "PENDING");
        taskIdToRequestId.put(r.pendingTaskId, r.requestId);
        return r;
    }

    public AccessRequest completeManagerTask(String taskId, boolean approved, String notes) {
        String requestId = taskIdToRequestId.remove(taskId);
        if (requestId == null) throw new IllegalArgumentException("Unknown task: " + taskId);
        AccessRequest r = requestsByRequestId.get(requestId);
        if (r == null) throw new IllegalStateException("Request gone: " + requestId);

        r.approved = approved;
        r.managerNotes = notes;
        r.pendingTaskId = null;

        if (!approved) {
            r.stepStatus.put("manager", "DONE");
            r.stepStatus.put("teleport-user", "SKIPPED");
            r.stepStatus.put("access-list", "SKIPPED");
            r.status = "REJECTED";
            r.failureReason = "Manager declined: " + (notes != null ? notes : "no reason given");
            notifyFailure(r);
            return r;
        }

        r.stepStatus.put("manager", "DONE");

        // Step 4: create user in Teleport
        try {
            teleportService.createUser(r.userId, r.firstName, r.lastName, r.email);
            r.stepStatus.put("teleport-user", "DONE");
        } catch (Exception e) {
            LOG.errorf("Teleport createUser failed: %s", e.getMessage());
            r.stepStatus.put("teleport-user", "FAILED");
            r.stepStatus.put("access-list", "SKIPPED");
            r.status = "ERROR";
            r.failureReason = "Teleport user creation failed: " + e.getMessage();
            return r;
        }

        // Step 5: add to access list
        try {
            teleportService.addToAccessList(r.userId, r.role, r.requestId, r.managerNotes);
            r.stepStatus.put("access-list", "DONE");
        } catch (Exception e) {
            LOG.errorf("Teleport addToAccessList failed: %s", e.getMessage());
            r.stepStatus.put("access-list", "FAILED");
            r.status = "ERROR";
            r.failureReason = "Access list assignment failed: " + e.getMessage();
            return r;
        }

        r.status = "COMPLETED";
        notifySuccess(r);
        return r;
    }

    public List<AccessRequest> pendingTasks() {
        return requestsByRequestId.values().stream()
                .filter(r -> r.pendingTaskId != null)
                .toList();
    }

    public AccessRequest getByTaskId(String taskId) {
        String reqId = taskIdToRequestId.get(taskId);
        return reqId != null ? requestsByRequestId.get(reqId) : null;
    }

    public List<AccessRequest> all() { return List.copyOf(requestsByRequestId.values()); }

    private void notifySuccess(AccessRequest r) {
        NotificationClient.NotificationEvent ev = new NotificationClient.NotificationEvent();
        ev.requestId = r.requestId; ev.to = r.email;
        ev.subject = "Your Maximo access is ready";
        ev.body = "Request " + r.requestId + " for role " + r.role + " has been provisioned in Teleport. "
                + "Run 'tsh login --proxy=teleport.localtest.me' to receive your short-lived credentials.";
        ev.severity = "INFO";
        try { notificationClient.send(ev); } catch (Exception e) { LOG.warn("Notify failed: " + e.getMessage()); }
    }

    private void notifyFailure(AccessRequest r) {
        NotificationClient.NotificationEvent ev = new NotificationClient.NotificationEvent();
        ev.requestId = r.requestId; ev.to = r.email;
        ev.subject = "Access request could not be completed";
        ev.body = "Request " + r.requestId + " did not proceed. Reason: " + r.failureReason;
        ev.severity = "WARN";
        try { notificationClient.send(ev); } catch (Exception e) { LOG.warn("Notify failed: " + e.getMessage()); }
    }
}
