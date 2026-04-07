public class LegacyOpportunityHelper {
    
    // Helper class written 8 years ago by junior developer
    // Poor variable names and no error handling
    
    public static void calculateOldInvoices(Id oppId) {
        
        // SOQL query without checking if oppId is null
        Opportunity opp = [SELECT Id, Name, Amount, AccountId, Client_Total_Invoice_Value__c 
                         FROM Opportunity WHERE Id = :oppId LIMIT 1];
        
        // Poor variable names
        decimal a = 0;
        decimal b = 0;
        decimal c = 0;
        decimal d = 0;
        
        // Hardcoded business logic
        if(opp.Amount != null){
            a = opp.Amount * 0.15;
            b = opp.Amount * 0.25;
            c = opp.Amount * 0.10;
            d = a + b + c;
        }
        
        // More hardcoded values
        if(opp.AccountId != null){
            // Another SOQL query - inefficient
            Account acc = [SELECT Id, AnnualRevenue, Industry FROM Account WHERE Id = :opp.AccountId LIMIT 1];
            
            if(acc.AnnualRevenue != null){
                if(acc.AnnualRevenue > 1000000){
                    d = d + (opp.Amount * 0.20);
                } else if(acc.AnnualRevenue > 500000){
                    d = d + (opp.Amount * 0.15);
                } else {
                    d = d + (opp.Amount * 0.10);
                }
            }
            
            // More nested IFs with hardcoded industry logic
            if(acc.Industry != null){
                if(acc.Industry == 'Technology'){
                    d = d + 5000;
                } else if(acc.Industry == 'Healthcare'){
                    d = d + 7500;
                } else if(acc.Industry == 'Finance'){
                    d = d + 10000;
                } else if(acc.Industry == 'Manufacturing'){
                    d = d + 3000;
                } else {
                    d = d + 1000;
                }
            }
        }
        
        // CRITICAL: Update the Client_Total_Invoice_Value__c field explicitly
        opp.Client_Total_Invoice_Value__c = d;
        
        // DML operation without checking if update is needed
        update opp;
        
        // More SOQL in loop pattern - very bad practice
        List<Contact> contacts = [SELECT Id, Name, Email FROM Contact WHERE AccountId = :opp.AccountId];
        
        if(contacts.size() > 0){
            for(Contact con : contacts){
                // Update contacts with hardcoded values
                con.Legacy_Processed__c = 'Yes';
                con.Old_System_Update__c = System.now();
            }
            
            // DML operation that might not be necessary
            update contacts;
        }
        
        // Log some messy data
        System.debug('Legacy helper processed opportunity: ' + opp.Name);
        System.debug('Calculated invoice value: ' + d);
        System.debug('Account contacts updated: ' + contacts.size());
    }
    
    // Another messy method with poor naming
    public static void doOldCalculations(List<Id> oppIds) {
        
        // Inefficient SOQL query with IN clause
        List<Opportunity> opps = [SELECT Id, Name, Amount, Client_Total_Invoice_Value__c 
                                FROM Opportunity WHERE Id IN :oppIds];
        
        // Poor variable names and magic numbers
        for(Opportunity o : opps){
            decimal val1 = 0;
            decimal val2 = 0;
            decimal val3 = 0;
            
            if(o.Amount != null){
                val1 = o.Amount * 0.123456;
                val2 = o.Amount * 0.789012;
                val3 = o.Amount * 0.345678;
            }
            
            // Update the field again - redundant
            o.Client_Total_Invoice_Value__c = val1 + val2 + val3;
        }
        
        // Bulk update - at least this is better than individual updates
        update opps;
    }
}
