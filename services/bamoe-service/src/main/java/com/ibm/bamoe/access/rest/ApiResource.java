package com.ibm.bamoe.access.rest;

import java.util.*;

import com.ibm.bamoe.access.model.AccessRequest;
import com.ibm.bamoe.access.services.WorkflowOrchestrator;

import jakarta.inject.Inject;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

@Path("/api")
public class ApiResource {

    @Inject WorkflowOrchestrator orchestrator;

    /**
     * Webhook endpoint that SailPoint calls when a request is approved.
     */
    @POST
    @Path("/access-requests")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response startRequest(Map<String, Object> payload) {
        AccessRequest r = orchestrator.startRequest(payload);
        Map<String, Object> resp = new HashMap<>();
        resp.put("requestId", r.requestId);
        resp.put("status", r.status);
        resp.put("pendingTaskId", r.pendingTaskId);
        return Response.accepted(resp).build();
    }

    /**
     * Dashboard data — KPIs + per-request step status.
     */
    @GET
    @Path("/access-requests/dashboard")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> dashboard() {
        List<AccessRequest> all = orchestrator.all();
        int completed = 0, pending = 0, failed = 0;
        List<Map<String, Object>> rows = new ArrayList<>();

        for (AccessRequest r : all) {
            Map<String, Object> row = new HashMap<>();
            row.put("requestId",    r.requestId);
            row.put("employeeName", r.employeeName());
            row.put("role",         r.role);
            row.put("status",       r.status);
            row.put("startedAt",    r.startedAt);
            row.put("steps",        r.stepStatus);
            rows.add(row);
            switch (r.status) {
                case "COMPLETED" -> completed++;
                case "ACTIVE"    -> pending++;
                case "REJECTED", "TRAINING_GAP", "ERROR" -> failed++;
            }
        }

        Map<String, Object> kpis = new HashMap<>();
        kpis.put("total", all.size());
        kpis.put("completed", completed);
        kpis.put("pending", pending);
        kpis.put("failed", failed);

        Map<String, Object> out = new HashMap<>();
        out.put("kpis", kpis);
        out.put("requests", rows);
        return out;
    }

    /**
     * List all pending manager tasks.
     */
    @GET
    @Path("/tasks")
    @Produces(MediaType.APPLICATION_JSON)
    public List<Map<String, Object>> tasks() {
        List<Map<String, Object>> tasks = new ArrayList<>();
        for (AccessRequest r : orchestrator.pendingTasks()) {
            Map<String, Object> t = new HashMap<>();
            t.put("taskId",         r.pendingTaskId);
            t.put("requestId",      r.requestId);
            t.put("userId",         r.userId);
            t.put("firstName",      r.firstName);
            t.put("lastName",       r.lastName);
            t.put("email",          r.email);
            t.put("role",           r.role);
            t.put("qualified",      r.qualified);
            t.put("completedModules", r.completedModules);
            tasks.add(t);
        }
        return tasks;
    }

    /**
     * Get a single task by id.
     */
    @GET
    @Path("/tasks/{taskId}")
    @Produces(MediaType.APPLICATION_JSON)
    public Response getTask(@PathParam("taskId") String taskId) {
        AccessRequest r = orchestrator.getByTaskId(taskId);
        if (r == null) return Response.status(404).build();
        Map<String, Object> t = new HashMap<>();
        t.put("taskId", taskId);
        t.put("requestId", r.requestId);
        t.put("userId", r.userId);
        t.put("firstName", r.firstName);
        t.put("lastName", r.lastName);
        t.put("email", r.email);
        t.put("role", r.role);
        t.put("qualified", r.qualified);
        t.put("completedModules", r.completedModules);
        return Response.ok(t).build();
    }

    /**
     * Manager approves or rejects.
     */
    @POST
    @Path("/tasks/{taskId}/complete")
    @Consumes(MediaType.APPLICATION_JSON)
    @Produces(MediaType.APPLICATION_JSON)
    public Response complete(@PathParam("taskId") String taskId, Map<String, Object> body) {
        Boolean approved = (Boolean) body.getOrDefault("approved", false);
        String notes = (String) body.getOrDefault("managerNotes", "");
        AccessRequest r = orchestrator.completeManagerTask(taskId, approved, notes);
        Map<String, Object> resp = new HashMap<>();
        resp.put("requestId", r.requestId);
        resp.put("status", r.status);
        resp.put("steps", r.stepStatus);
        return Response.ok(resp).build();
    }
}
