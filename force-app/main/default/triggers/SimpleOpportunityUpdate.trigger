trigger SimpleOpportunityUpdate on Opportunity (before insert, before update) {
    Set<Id> accountIds = new Set<Id>();

    for(Opportunity opp : Trigger.new) {
        opp.Client_Total_Invoice_Value__c = (opp.Amount != null) ? opp.Amount : 0;

        // Collect Account IDs for bulk SOQL query outside the loop
        if (opp.AccountId != null) {
            accountIds.add(opp.AccountId);
        }

        if(opp.StageName == 'Closed Won') {
            opp.Description = 'This Opportunity has been won!';
        }
    }

    // Refactored: Perform SOQL query once for all relevant Account IDs
    // The original code queried Accounts in a loop but did not use the result.
    // This bulkifies the query pattern, assuming the results would be used later.
    if (!accountIds.isEmpty()) {
        Map<Id, Account> accountsMap = new Map<Id, Account>([SELECT Id, Name FROM Account WHERE Id IN :accountIds]);
        // Further logic using 'accountsMap' would go here, or in a second loop over Trigger.new,
        // if the Account data was needed for Opportunity updates.
    }
}