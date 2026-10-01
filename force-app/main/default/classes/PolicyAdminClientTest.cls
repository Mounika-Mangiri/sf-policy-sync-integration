@IsTest
private class PolicyAdminClientTest {
  @IsTest
  static void successParsesPolicy() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    PolicyAdminClient.Result r = new PolicyAdminClient()
      .fetchPolicy('DEMO-OK-1');
    Assert.isTrue(r.isSuccess());
    Assert.areEqual(200, r.statusCode);
    Assert.areEqual('Active', r.policy.status);
    Assert.areEqual(125.50, r.policy.premiumAmount);
    Assert.isTrue(r.endpoint.startsWith('callout:PolicyAdminAPI/policies/'));
  }

  @IsTest
  static void serverErrorIsRetryable() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    PolicyAdminClient.Result r = new PolicyAdminClient()
      .fetchPolicy('DEMO-DOWN-1');
    Assert.isFalse(r.isSuccess());
    Assert.isTrue(r.retryable);
    Assert.areEqual(503, r.statusCode);
  }

  @IsTest
  static void notFoundIsNotRetryable() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    PolicyAdminClient.Result r = new PolicyAdminClient()
      .fetchPolicy('UNKNOWN-1');
    Assert.isFalse(r.retryable);
    Assert.areEqual(404, r.statusCode);
  }

  @IsTest
  static void timeoutIsRetryable() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    PolicyAdminClient.Result r = new PolicyAdminClient()
      .fetchPolicy('DEMO-SLOW-1');
    Assert.isTrue(r.retryable);
    Assert.isTrue(r.error.contains('timed out'));
  }

  @IsTest
  static void malformedJsonIsNotRetryable() {
    Test.setMock(HttpCalloutMock.class, new PolicyApiMock());
    PolicyAdminClient.Result r = new PolicyAdminClient()
      .fetchPolicy('DEMO-BAD-1');
    Assert.isFalse(r.isSuccess());
    Assert.isFalse(r.retryable);
    Assert.isTrue(r.error.startsWith('Unreadable response'));
  }
}
