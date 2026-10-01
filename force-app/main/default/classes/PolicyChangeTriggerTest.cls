@IsTest
private class PolicyChangeTriggerTest {
  @IsTest
  static void eventsAreDedupedAndSynced() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    Test.startTest();
    List<Database.SaveResult> results = EventBus.publish(
      new List<Policy_Change__e>{
        new Policy_Change__e(
          Policy_Number__c = 'DEMO-OK-7',
          Change_Type__c = 'PREMIUM_PAID'
        ),
        new Policy_Change__e(
          Policy_Number__c = 'DEMO-OK-7 ',
          Change_Type__c = 'ADDRESS_CHANGE'
        ),
        new Policy_Change__e(
          Policy_Number__c = 'DEMO-OK-8',
          Change_Type__c = 'STATUS_CHANGE'
        )
      }
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    for (Database.SaveResult sr : results) {
      Assert.isTrue(sr.isSuccess());
    }
    Assert.areEqual(2, PolicyChangeHandler.lastEnqueued.size());
    Assert.isTrue(
      new Set<String>(PolicyChangeHandler.lastEnqueued).contains('DEMO-OK-7')
    );
  }

  @IsTest
  static void blankPolicyNumbersAreIgnored() {
    PolicyChangeHandler.handle(
      new List<Policy_Change__e>{ new Policy_Change__e(Policy_Number__c = ' ') }
    );
    Assert.areEqual(0, PolicyChangeHandler.lastEnqueued.size());
  }
}
