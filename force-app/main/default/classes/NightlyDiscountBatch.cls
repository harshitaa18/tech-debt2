public class NightlyDiscountBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    // Batch class written by junior developer 8 years ago
    // Poor variable names and hardcoded values
    
    // Global variables with poor naming
    private Integer processedCount = 0;
    private Integer errorCount = 0;
    private decimal totalDiscount = 0;
    
    // Hardcoded ID values - very bad practice
    private static final String USER_ID = '005000000000001AAA';
    private static final String PROFILE_ID = '00e000000000001AAA';
    private static final String ROLE_ID = '00E000000000001AAA';
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        
        // Messy SOQL query with hardcoded conditions
        String query = 'SELECT Id, Name, Amount, StageName, CloseDate, AccountId, ' +
                      'Legacy_Discount__c, Old_Tax_Rate__c, Retired_Fee__c, ' +
                      'Client_Total_Invoice_Value__c, Type, Probability ' +
                      'FROM Opportunity ' +
                      'WHERE IsClosed = false ' +
                      'AND Amount > 0 ' +
                      'AND CreatedDate = YESTERDAY ' +
                      'AND (StageName = \'Prospecting\' OR StageName = \'Qualification\') ' +
                      'ORDER BY Amount DESC';
        
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        
        // Poor variable names
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        decimal discountAmount = 0;
        decimal taxAmount = 0;
        decimal feeAmount = 0;
        
        for(Opportunity opp : scope){
            
            // Nested IF statements with hardcoded business logic
            if(opp.Amount != null){
                
                if(opp.Amount > 100000){
                    discountAmount = opp.Amount * 0.20;
                    taxAmount = opp.Amount * 0.15;
                    feeAmount = opp.Amount * 0.10;
                    
                    if(opp.Type == 'New Customer'){
                        discountAmount = discountAmount + 5000;
                    } else if(opp.Type == 'Existing Customer'){
                        taxAmount = taxAmount + 2500;
                    } else {
                        feeAmount = feeAmount + 1000;
                    }
                    
                } else if(opp.Amount > 50000){
                    discountAmount = opp.Amount * 0.15;
                    taxAmount = opp.Amount * 0.12;
                    feeAmount = opp.Amount * 0.08;
                    
                    if(opp.Probability > 75){
                        discountAmount = discountAmount + 2000;
                    } else if(opp.Probability > 50){
                        taxAmount = taxAmount + 1500;
                    } else {
                        feeAmount = feeAmount + 500;
                    }
                    
                } else {
                    discountAmount = opp.Amount * 0.10;
                    taxAmount = opp.Amount * 0.08;
                    feeAmount = opp.Amount * 0.05;
                }
                
                // More hardcoded logic based on close date
                if(opp.CloseDate != null){
                    Date today = Date.today();
                    Integer daysUntilClose = opp.CloseDate.daysBetween(today);
                    
                    if(daysUntilClose > 90){
                        discountAmount = discountAmount * 1.5;
                    } else if(daysUntilClose > 60){
                        taxAmount = taxAmount * 1.3;
                    } else if(daysUntilClose > 30){
                        feeAmount = feeAmount * 1.2;
                    }
                }
                
                // Update fields with messy calculations
                opp.Legacy_Discount__c = discountAmount;
                opp.Old_Tax_Rate__c = taxAmount;
                opp.Retired_Fee__c = feeAmount;
                
                // Update the critical field
                opp.Client_Total_Invoice_Value__c = discountAmount + taxAmount + feeAmount;
                
                // More hardcoded field updates
                opp.Nightly_Processed__c = 'Yes';
                opp.Batch_Update_Date__c = System.now();
                opp.Discount_Calculated_By__c = UserInfo.getName();
                
                // Add to update list
                oppsToUpdate.add(opp);
                
                // Update counters
                processedCount++;
                totalDiscount = totalDiscount + discountAmount;
                
            } else {
                // Poor error handling
                opp.Amount_Error__c = 'No Amount Found';
                errorCount++;
            }
        }
        
        // DML operation with no error handling
        try{
            update oppsToUpdate;
        } catch(Exception e){
            // Poor error logging
            System.debug('Error updating opportunities: ' + e.getMessage());
            errorCount = errorCount + oppsToUpdate.size();
        }
        
        // More SOQL queries inside execute - bad practice
        if(!oppsToUpdate.isEmpty()){
            for(Opportunity opp : oppsToUpdate){
                if(opp.AccountId != null){
                    // SOQL inside loop - very bad
                    Account acc = [SELECT Id, Name, Industry FROM Account WHERE Id = :opp.AccountId LIMIT 1];
                    
                    // Update account with hardcoded values
                    acc.Last_Discount_Update__c = System.now();
                    acc.Total_Opportunities_Processed__c = processedCount;
                    
                    // Another DML inside loop
                    update acc;
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        
        // Messy finish method with hardcoded email sending
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        
        // Hardcoded email addresses
        List<String> toAddresses = new List<String>{'admin@company.com', 'manager@company.com'};
        mail.setToAddresses(toAddresses);
        
        // Poor email subject and body
        mail.setSubject('Nightly Discount Batch Completed');
        
        String body = 'Batch processing completed.\n\n';
        body = body + 'Processed: ' + processedCount + ' opportunities\n';
        body = body + 'Errors: ' + errorCount + '\n';
        body = body + 'Total Discount: $' + totalDiscount + '\n';
        body = body + 'Processed by: ' + UserInfo.getName() + '\n';
        body = body + 'Completion time: ' + System.now() + '\n';
        
        mail.setPlainTextBody(body);
        
        // Send email without checking limits
        try{
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
        } catch(Exception e){
            System.debug('Error sending email: ' + e.getMessage());
        }
        
        // Poor debug logging
        System.debug('=== BATCH COMPLETED ===');
        System.debug('Processed Count: ' + processedCount);
        System.debug('Error Count: ' + errorCount);
        System.debug('Total Discount: ' + totalDiscount);
        System.debug('User: ' + UserInfo.getName());
        System.debug('Time: ' + System.now());
    }
}
