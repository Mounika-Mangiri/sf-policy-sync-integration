/**
 * Subscriber logic for Policy_Change__e.
 *
 * Pattern: event notification + pull. The event carries only the policy
 * number; the full record is pulled from the source system by PolicySyncJob.
 * This keeps the event small and makes duplicate or out-of-order events
 * harmless, because the job always fetches current state.
 */
public with sharing class PolicyChangeHandler {
  @TestVisible
  private static List<String> lastEnqueued = new List<String>();

  public static void handle(List<Policy_Change__e> events) {
    Set<String> unique = new Set<String>();
    for (Policy_Change__e evt : events) {
      if (String.isNotBlank(evt.Policy_Number__c)) {
        unique.add(evt.Policy_Number__c.trim());
      }
    }
    if (unique.isEmpty()) {
      return;
    }
    lastEnqueued = new List<String>(unique);
    System.enqueueJob(new PolicySyncJob(lastEnqueued));
  }
}
