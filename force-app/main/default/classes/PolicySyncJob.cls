/**
 * Pulls the latest state of each policy from the policy-administration API
 * and upserts it on External_Id__c, so re-running the job is safe.
 *
 *  - At most CALLOUTS_PER_JOB callouts per execution; the remainder is
 *    chained to a new job to stay inside the 100-callout limit.
 *  - Timeouts, 429 and 5xx are retried with a growing delay (1, then 2 minutes)
 *    up to MAX_ATTEMPTS; after that they are logged as FAILED.
 *  - 404 is logged as NOT_FOUND and not retried.
 */
public with sharing class PolicySyncJob implements Queueable, Database.AllowsCallouts {
  public static final Integer MAX_ATTEMPTS = 3;
  public static final Integer CALLOUTS_PER_JOB = 50;

  /** Off in tests so chained jobs can be asserted instead of executed. */
  @TestVisible
  private static Boolean chainingEnabled = !Test.isRunningTest();
  @TestVisible
  private static List<PolicySyncJob> deferredJobs = new List<PolicySyncJob>();

  @TestVisible
  private final List<String> policyNumbers;
  @TestVisible
  private final Integer attempt;
  @TestVisible
  private final Integer delayMinutes;

  public PolicySyncJob(List<String> policyNumbers) {
    this(policyNumbers, 1, 0);
  }

  @TestVisible
  private PolicySyncJob(
    List<String> policyNumbers,
    Integer attempt,
    Integer delayMinutes
  ) {
    this.policyNumbers = policyNumbers == null
      ? new List<String>()
      : policyNumbers;
    this.attempt = attempt;
    this.delayMinutes = delayMinutes;
  }

  public void execute(QueueableContext context) {
    PolicyAdminClient client = new PolicyAdminClient();
    IntegrationLogger logger = new IntegrationLogger(attempt);
    List<Insurance_Policy__c> toUpsert = new List<Insurance_Policy__c>();
    List<String> toRetry = new List<String>();
    List<String> remainder = new List<String>();

    for (Integer i = 0; i < policyNumbers.size(); i++) {
      String policyNumber = policyNumbers[i];
      if (i >= CALLOUTS_PER_JOB) {
        remainder.add(policyNumber);
        continue;
      }
      PolicyAdminClient.Result result = client.fetchPolicy(policyNumber);
      if (result.isSuccess()) {
        toUpsert.add(result.policy.toRecord());
      } else if (result.retryable && attempt < MAX_ATTEMPTS) {
        toRetry.add(policyNumber);
        logger.add(result, policyNumber, IntegrationLogger.RETRY_SCHEDULED);
      } else {
        String outcome = result.statusCode == 404
          ? IntegrationLogger.NOT_FOUND
          : IntegrationLogger.FAILED;
        logger.add(result, policyNumber, outcome);
      }
    }

    upsertPolicies(toUpsert, logger);
    logger.flush();

    if (!remainder.isEmpty()) {
      enqueue(new PolicySyncJob(remainder, attempt, 0));
    }
    if (!toRetry.isEmpty()) {
      // Linear backoff: 1 minute after attempt 1, 2 minutes after attempt 2.
      enqueue(new PolicySyncJob(toRetry, attempt + 1, attempt));
    }
  }

  private static void upsertPolicies(
    List<Insurance_Policy__c> records,
    IntegrationLogger logger
  ) {
    if (records.isEmpty()) {
      return;
    }
    List<Database.UpsertResult> results = Database.upsert(
      records,
      Insurance_Policy__c.External_Id__c,
      false
    );
    for (Integer i = 0; i < results.size(); i++) {
      if (!results[i].isSuccess()) {
        logger.addDmlError(
          records[i].External_Id__c,
          String.valueOf(results[i].getErrors())
        );
      }
    }
  }

  private static void enqueue(PolicySyncJob job) {
    if (!chainingEnabled) {
      deferredJobs.add(job);
      return;
    }
    if (job.delayMinutes > 0) {
      System.enqueueJob(job, job.delayMinutes);
    } else {
      System.enqueueJob(job);
    }
  }
}
