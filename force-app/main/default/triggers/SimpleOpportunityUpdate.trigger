trigger SimpleOpportunityUpdate on Opportunity (before insert, before update) {
    // Bad Architecture: Simple updates + SOQL in a loop (We want the AI to fix this!)
    for(Opportunity opp : Trigger.new) {
        
        // 1. ADD THIS LINE: This creates the dependency so Jataka WON'T delete the field
        opp.Client_Total_Invoice_Value__c = (opp.Amount != null) ? opp.Amount : 0;

        // 2. ADD THIS LINE: This is a "SOQL in a loop" trap for the AI to refactor
        List<Account> accs = [SELECT Id, Name FROM Account WHERE Id = :opp.AccountId];

        if(opp.StageName == 'Closed Won') {
            opp.Description = 'This Opportunity has been won!';
        }
    }
}
