package com.ibm.bamoe.access.model;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class AccessRequest {
    public String requestId;
    public String userId;
    public String firstName;
    public String lastName;
    public String email;
    public String role;
    public String managerEmail;
    public String startedAt;
    public String status; // ACTIVE | COMPLETED | REJECTED | TRAINING_GAP | ERROR
    public List<String> completedModules;
    public Boolean qualified;
    public Boolean approved;
    public String managerNotes;
    public String failureReason;
    public Map<String, String> stepStatus = new LinkedHashMap<>();
    public String pendingTaskId;

    public AccessRequest() {
        startedAt = Instant.now().toString();
        status = "ACTIVE";
        stepStatus.put("sailpoint",     "DONE");
        stepStatus.put("training",      "WAITING");
        stepStatus.put("manager",       "WAITING");
        stepStatus.put("teleport-user", "WAITING");
        stepStatus.put("access-list",   "WAITING");
    }

    public String employeeName() { return firstName + " " + lastName; }
}
