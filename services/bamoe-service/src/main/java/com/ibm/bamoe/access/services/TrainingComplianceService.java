package com.ibm.bamoe.access.services;

import java.util.List;
import java.util.Map;
import java.util.Set;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * Training compliance rules. Replaces what was previously a DMN decision table.
 *
 * Same business logic, plain Java. Editing this file is the equivalent of
 * editing a DMN cell — for a real demo you'd put this in a config file, but
 * keeping it inline is fine for the panel.
 */
@ApplicationScoped
public class TrainingComplianceService {

    private static final Map<String, Set<String>> REQUIRED = Map.of(
        "MAXIMO_ENGINEER",   Set.of("SAFETY-101", "ASSET-201"),
        "MAXIMO_PLANNER",    Set.of("SAFETY-101", "PLANNER-301"),
        "MAXIMO_SUPERVISOR", Set.of("SAFETY-101", "SAFETY-201", "SUPERVISOR-401"),
        "MAXIMO_VIEWER",     Set.of("SAFETY-101")
    );

    public boolean isQualified(String role, List<String> completedModules) {
        if (role == null || completedModules == null) return false;
        Set<String> required = REQUIRED.get(role);
        if (required == null) return false;
        return completedModules.containsAll(required);
    }
}
