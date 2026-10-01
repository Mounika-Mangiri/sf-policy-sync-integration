/**
 * Calls the policy-administration REST API through the PolicyAdminAPI
 * named credential, so no URL, user name or secret lives in code.
 *
 * Returns a result object instead of throwing, so the caller can decide
 * whether to retry (timeouts, HTTP 429 and 5xx) or give up (4xx, bad JSON).
 */
public with sharing class PolicyAdminClient {
  public static final String NAMED_CREDENTIAL = 'callout:PolicyAdminAPI';
  private static final Integer TIMEOUT_MS = 10000;
  private static final Integer MAX_LOGGED_BODY = 500;

  public class Result {
    public Integer statusCode = 0;
    public PolicyDto policy;
    public String error;
    public Boolean retryable = false;
    public String endpoint;

    public Boolean isSuccess() {
      return policy != null;
    }
  }

  public Result fetchPolicy(String policyNumber) {
    Result result = new Result();
    result.endpoint =
      NAMED_CREDENTIAL +
      '/policies/' +
      EncodingUtil.urlEncode(policyNumber, 'UTF-8');

    HttpRequest req = new HttpRequest();
    req.setEndpoint(result.endpoint);
    req.setMethod('GET');
    req.setHeader('Accept', 'application/json');
    req.setTimeout(TIMEOUT_MS);

    try {
      HttpResponse res = new Http().send(req);
      result.statusCode = res.getStatusCode();
      if (result.statusCode == 200) {
        result.policy = (PolicyDto) JSON.deserialize(
          res.getBody(),
          PolicyDto.class
        );
      } else {
        result.retryable = result.statusCode == 429 || result.statusCode >= 500;
        String body = res.getBody() == null ? '' : res.getBody();
        result.error =
          'HTTP ' +
          result.statusCode +
          ': ' +
          body.left(MAX_LOGGED_BODY);
      }
    } catch (CalloutException e) {
      // Timeouts and connection failures are worth another try.
      result.retryable = true;
      result.error = 'Callout failed: ' + e.getMessage();
    } catch (JSONException e) {
      result.error = 'Unreadable response: ' + e.getMessage();
    }
    return result;
  }
}
