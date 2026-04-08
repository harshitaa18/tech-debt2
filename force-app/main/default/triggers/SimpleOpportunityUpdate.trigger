trigger SimpleOpportunityUpdate on Opportunity (before insert, before update) {
    // Bad Architecture: This simple field update should clearly be a Fast Field Update Flow!
    for(Opportunity opp : Trigger.new) {
        if(opp.StageName == 'Closed Won') {
            opp.Description = 'This Opportunity has been won!';
        }
    }
}
