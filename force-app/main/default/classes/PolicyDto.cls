/**
 * Shape of a policy returned by the policy-administration API.
 * See mock-server/openapi.yaml for the contract.
 */
public class PolicyDto {
  public String policyNumber;
  public String status;
  public Decimal premiumAmount;
  public String paidToDate; // ISO date, e.g. 2026-09-30

  public Insurance_Policy__c toRecord() {
    return new Insurance_Policy__c(
      Name = policyNumber,
      External_Id__c = policyNumber,
      Status__c = status,
      Premium_Amount__c = premiumAmount,
      Paid_To_Date__c = String.isBlank(paidToDate)
        ? null
        : Date.valueOf(paidToDate),
      Last_Synced__c = System.now()
    );
  }
}
