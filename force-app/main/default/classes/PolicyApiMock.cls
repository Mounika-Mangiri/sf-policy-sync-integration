/**
 * Test double for the policy-administration API.
 * Routes by policy number in the URL:
 *   DEMO-OK-*    200 with a synthetic policy
 *   DEMO-DOWN-*  503
 *   DEMO-SLOW-*  throws CalloutException (timeout)
 *   DEMO-BAD-*   200 with malformed JSON
 *   anything else 404
 */
@IsTest
public class PolicyApiMock implements HttpCalloutMock {
  public Integer calls = 0;

  public HttpResponse respond(HttpRequest req) {
    calls++;
    String endpoint = req.getEndpoint();
    String policyNumber = endpoint.substringAfterLast('/');
    HttpResponse res = new HttpResponse();
    res.setHeader('Content-Type', 'application/json');

    if (policyNumber.startsWith('DEMO-SLOW-')) {
      throw new CalloutException('Read timed out');
    } else if (policyNumber.startsWith('DEMO-OK-')) {
      res.setStatusCode(200);
      res.setBody(
        JSON.serialize(
          new Map<String, Object>{
            'policyNumber' => policyNumber,
            'status' => 'Active',
            'premiumAmount' => 125.50,
            'paidToDate' => '2026-09-30'
          }
        )
      );
    } else if (policyNumber.startsWith('DEMO-DOWN-')) {
      res.setStatusCode(503);
      res.setBody('{"error":"Service unavailable"}');
    } else if (policyNumber.startsWith('DEMO-BAD-')) {
      res.setStatusCode(200);
      res.setBody('{not json');
    } else {
      res.setStatusCode(404);
      res.setBody('{"error":"Policy not found"}');
    }
    return res;
  }
}
