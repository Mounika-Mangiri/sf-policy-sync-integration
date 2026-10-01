/**
 * Buffers integration log rows and writes them in one DML statement.
 * Logging must never break the sync, so insert failures are swallowed
 * after being written to the debug log.
 */
public without sharing class IntegrationLogger {
  public static final String RETRY_SCHEDULED = 'RETRY_SCHEDULED';
  public static final String FAILED = 'FAILED';
  public static final String NOT_FOUND = 'NOT_FOUND';

  private final Integer attempt;
  private List<Integration_Log__c> buffer = new List<Integration_Log__c>();

  /** @param attempt the sync attempt number written on every row */
  public IntegrationLogger(Integer attempt) {
    this.attempt = attempt;
  }

  public void add(
    PolicyAdminClient.Result result,
    String recordKey,
    String outcome
  ) {
    buffer.add(
      new Integration_Log__c(
        Endpoint__c = result.endpoint == null
          ? null
          : result.endpoint.left(255),
        Status_Code__c = result.statusCode,
        Message__c = result.error,
        Record_Key__c = recordKey,
        Attempt__c = attempt,
        Outcome__c = outcome
      )
    );
  }

  public void addDmlError(String recordKey, String message) {
    buffer.add(
      new Integration_Log__c(
        Record_Key__c = recordKey,
        Message__c = message,
        Attempt__c = attempt,
        Outcome__c = FAILED
      )
    );
  }

  public Integer size() {
    return buffer.size();
  }

  @SuppressWarnings('PMD.AvoidDebugStatements')
  public void flush() {
    if (buffer.isEmpty()) {
      return;
    }
    List<Database.SaveResult> results = Database.insert(buffer, false);
    for (Database.SaveResult sr : results) {
      if (!sr.isSuccess()) {
        System.debug(
          LoggingLevel.ERROR,
          'Integration log insert failed: ' + sr.getErrors()
        );
      }
    }
    buffer.clear();
  }
}
