@IsTest
private class PolicySyncJobTest {
  private static List<Integration_Log__c> logs(String outcome) {
    return [
      SELECT Record_Key__c, Attempt__c, Status_Code__c
      FROM Integration_Log__c
      WHERE Outcome__c = :outcome
    ];
  }

  @IsTest
  static void successfulPoliciesAreUpserted() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    Test.startTest();
    System.enqueueJob(
      new PolicySyncJob(new List<String>{ 'DEMO-OK-1', 'DEMO-OK-2' })
    );
    Test.stopTest();

    List<Insurance_Policy__c> rows = [
      SELECT External_Id__c, Status__c, Premium_Amount__c, Paid_To_Date__c
      FROM Insurance_Policy__c
      ORDER BY External_Id__c
    ];
    Assert.areEqual(2, rows.size());
    Assert.areEqual('Active', rows[0].Status__c);
    Assert.areEqual(Date.newInstance(2026, 9, 30), rows[0].Paid_To_Date__c);
  }

  @IsTest
  static void upsertIsIdempotent() {
    insert new Insurance_Policy__c(
      Name = 'DEMO-OK-1',
      External_Id__c = 'DEMO-OK-1',
      Status__c = 'Lapsed'
    );
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    Test.startTest();
    System.enqueueJob(new PolicySyncJob(new List<String>{ 'DEMO-OK-1' }));
    Test.stopTest();

    List<Insurance_Policy__c> rows = [
      SELECT Status__c
      FROM Insurance_Policy__c
      WHERE External_Id__c = 'DEMO-OK-1'
    ];
    Assert.areEqual(1, rows.size());
    Assert.areEqual('Active', rows[0].Status__c);
  }

  @IsTest
  static void transientFailureSchedulesRetryWithBackoff() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    Test.startTest();
    System.enqueueJob(
      new PolicySyncJob(new List<String>{ 'DEMO-DOWN-1', 'DEMO-SLOW-1' })
    );
    Test.stopTest();

    Assert.areEqual(2, logs(IntegrationLogger.RETRY_SCHEDULED).size());
    Assert.areEqual(1, PolicySyncJob.deferredJobs.size());
    PolicySyncJob retry = PolicySyncJob.deferredJobs[0];
    Assert.areEqual(2, retry.attempt);
    Assert.areEqual(1, retry.delayMinutes);
    Assert.areEqual(2, retry.policyNumbers.size());
  }

  @IsTest
  static void lastAttemptIsLoggedAsFailed() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    Test.startTest();
    System.enqueueJob(
      new PolicySyncJob(
        new List<String>{ 'DEMO-DOWN-1' },
        PolicySyncJob.MAX_ATTEMPTS,
        0
      )
    );
    Test.stopTest();

    Assert.areEqual(1, logs(IntegrationLogger.FAILED).size());
    Assert.areEqual(0, PolicySyncJob.deferredJobs.size());
  }

  @IsTest
  static void notFoundIsLoggedNotRetried() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    Test.startTest();
    System.enqueueJob(new PolicySyncJob(new List<String>{ 'UNKNOWN-9' }));
    Test.stopTest();

    List<Integration_Log__c> notFound = logs(IntegrationLogger.NOT_FOUND);
    Assert.areEqual(1, notFound.size());
    Assert.areEqual(404, notFound[0].Status_Code__c);
    Assert.areEqual(0, PolicySyncJob.deferredJobs.size());
  }

  @IsTest
  static void largeBatchIsChained() {
    List<String> numbers = new List<String>();
    for (Integer i = 0; i < PolicySyncJob.CALLOUTS_PER_JOB + 5; i++) {
      numbers.add('DEMO-OK-' + i);
    }
    PolicyApiMock mock = new PolicyApiMock();
    Test.setMock(HttpCalloutMock.class, mock);
    Test.startTest();
    System.enqueueJob(new PolicySyncJob(numbers));
    Test.stopTest();

    Assert.areEqual(
      PolicySyncJob.CALLOUTS_PER_JOB,
      [SELECT COUNT() FROM Insurance_Policy__c]
    );
    Assert.areEqual(1, PolicySyncJob.deferredJobs.size());
    Assert.areEqual(5, PolicySyncJob.deferredJobs[0].policyNumbers.size());
    Assert.areEqual(1, PolicySyncJob.deferredJobs[0].attempt);
  }
}
