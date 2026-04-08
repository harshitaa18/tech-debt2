public class NightlyDiscountBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    // Global variables for tracking batch execution statistics
    private Integer processedOpportunityCount = 0;
    private Integer failedOpportunityCount = 0;
    private Decimal totalDiscountApplied = 0;
    
    // Hardcoded ID values removed as they were not used.
    // Ideally, configurable values like email addresses should be in Custom Metadata Types or Custom Settings.
    private static final List<String> ADMIN_EMAIL_ADDRESSES = new List<String>{'admin@company.com', 'manager@company.com'};
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        // Refactored SOQL query for readability and to include all fields that might be updated
        String query = 'SELECT Id, Name, Amount, StageName, CloseDate, AccountId, ' +
                       'Legacy_Discount__c, Old_Tax_Rate__c, Retired_Fee__c, ' +
                       'Client_Total_Invoice_Value__c, Type, Probability, ' +
                       'Nightly_Processed__c, Batch_Update_Date__c, Discount_Calculated_By__c, Amount_Error__c ' +
                       'FROM Opportunity ' +
                       'WHERE IsClosed = false ' +
                       'AND Amount > 0 ' +
                       'AND CreatedDate = YESTERDAY ' + // Using YESTERDAY literal as per original requirement
                       'AND (StageName = \'Prospecting\' OR StageName = \'Qualification\') ' +
                       'ORDER BY Amount DESC';
        
        return Database.getQueryLocator(query);
    }
    
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        Set<Id> relatedAccountIds = new Set<Id>();
        
        // Define common variables once per execute method for consistency and efficiency
        Date batchProcessingDate = System.today(); 
        DateTime batchUpdateTimestamp = System.now();
        String discountCalculatorUser = UserInfo.getName();
        
        for (Opportunity currentOpportunity : scope) {
            
            // Check for valid Amount before proceeding with calculations
            if (currentOpportunity.Amount != null && currentOpportunity.Amount > 0) {
                
                Decimal calculatedDiscount = 0;
                Decimal calculatedTax = 0;
                Decimal calculatedFee = 0;
                
                // --- Base Discount/Tax/Fee Calculation based on Opportunity Amount ---
                if (currentOpportunity.Amount > 100000) {
                    calculatedDiscount = currentOpportunity.Amount * 0.20;
                    calculatedTax = currentOpportunity.Amount * 0.15;
                    calculatedFee = currentOpportunity.Amount * 0.10;
                    
                    // --- Type-based adjustments for high value opportunities ---
                    if (currentOpportunity.Type == 'New Customer') {
                        calculatedDiscount += 5000;
                    } else if (currentOpportunity.Type == 'Existing Customer') {
                        calculatedTax += 2500;
                    } else {
                        calculatedFee += 1000;
                    }
                    
                } else if (currentOpportunity.Amount > 50000) {
                    calculatedDiscount = currentOpportunity.Amount * 0.15;
                    calculatedTax = currentOpportunity.Amount * 0.12;
                    calculatedFee = currentOpportunity.Amount * 0.08;
                    
                    // --- Probability-based adjustments for mid value opportunities ---
                    if (currentOpportunity.Probability != null) { // Add null check for Probability
                        if (currentOpportunity.Probability > 75) {
                            calculatedDiscount += 2000;
                        } else if (currentOpportunity.Probability > 50) {
                            calculatedTax += 1500;
                        } else {
                            calculatedFee += 500;
                        }
                    }
                    
                } else { // Amount <= 50000
                    calculatedDiscount = currentOpportunity.Amount * 0.10;
                    calculatedTax = currentOpportunity.Amount * 0.08;
                    calculatedFee = currentOpportunity.Amount * 0.05;
                    // No additional adjustments for low value opportunities based on original logic
                }
                
                // --- Close Date-based adjustments ---
                if (currentOpportunity.CloseDate != null) {
                    Integer daysUntilClose = currentOpportunity.CloseDate.daysBetween(batchProcessingDate);
                    
                    if (daysUntilClose > 90) {
                        calculatedDiscount *= 1.5;
                    } else if (daysUntilClose > 60) {
                        calculatedTax *= 1.3;
                    } else if (daysUntilClose > 30) {
                        calculatedFee *= 1.2;
                    }
                }
                
                // Set calculated values and other tracking fields on the Opportunity
                currentOpportunity.Legacy_Discount__c = calculatedDiscount;
                currentOpportunity.Old_Tax_Rate__c = calculatedTax;
                currentOpportunity.Retired_Fee__c = calculatedFee;
                currentOpportunity.Client_Total_Invoice_Value__c = calculatedDiscount + calculatedTax + calculatedFee;
                currentOpportunity.Nightly_Processed__c = 'Yes';
                currentOpportunity.Batch_Update_Date__c = batchUpdateTimestamp;
                currentOpportunity.Discount_Calculated_By__c = discountCalculatorUser;
                currentOpportunity.Amount_Error__c = null; // Clear any previous error message
                
                opportunitiesToUpdate.add(currentOpportunity);
                
                // Collect Account IDs for bulk processing later
                if (currentOpportunity.AccountId != null) {
                    relatedAccountIds.add(currentOpportunity.AccountId);
                }
                
            } else {
                // Handle opportunities with invalid or null Amount (error scenario)
                currentOpportunity.Amount_Error__c = 'Opportunity Amount is zero or null, cannot calculate discount.';
                opportunitiesToUpdate.add(currentOpportunity); // Add to DML list to update the error field
            }
        }
        
        // --- Bulkified DML Operation for Opportunities ---
        if (!opportunitiesToUpdate.isEmpty()) {
            // Use Database.update(records, false) for partial success and better error reporting
            Database.SaveResult[] opportunityUpdateResults = Database.update(opportunitiesToUpdate, false); 
            
            for (Integer i = 0; i < opportunityUpdateResults.size(); i++) {
                Opportunity processedOpp = opportunitiesToUpdate[i];
                if (opportunityUpdateResults[i].isSuccess()) {
                    processedOpportunityCount++;
                    // Only sum discount if the calculation was valid and DML succeeded
                    if (processedOpp.Amount_Error__c == null) {
                        totalDiscountApplied += processedOpp.Legacy_Discount__c;
                    }
                } else {
                    // This opportunity failed DML for some reason
                    Database.Error dmlError = opportunityUpdateResults[i].getErrors()[0];
                    System.debug('ERROR: DML error updating Opportunity ' + processedOpp.Id + ' - ' + dmlError.getStatusCode() + ': ' + dmlError.getMessage());
                    failedOpportunityCount++;
                }
            }
        }
        
        // --- Bulkified DML Operation for Account Updates ---
        // SOQL query moved outside the loop and accounts retrieved in a map
        if (!relatedAccountIds.isEmpty()) {
            Map<Id, Account> accountsToUpdateMap = new Map<Id, Account>(
                [SELECT Id, Last_Discount_Update__c, Total_Opportunities_Processed__c FROM Account WHERE Id IN :relatedAccountIds]
            );
            
            List<Account> accountsForDML = new List<Account>();
            for (Id accountId : relatedAccountIds) {
                Account account = accountsToUpdateMap.get(accountId);
                if (account != null) {
                    account.Last_Discount_Update__c = batchUpdateTimestamp;
                    // Note: original code used `processedCount` (now `processedOpportunityCount`),
                    // which is a running total across the entire batch. This behavior is preserved.
                    account.Total_Opportunities_Processed__c = processedOpportunityCount; 
                    accountsForDML.add(account);
                }
            }
            
            // DML operation moved outside the loop
            if (!accountsForDML.isEmpty()) {
                try {
                    update accountsForDML;
                } catch (DmlException dmlEx) {
                    // Log specific DML errors for accounts
                    for (Integer i = 0; i < dmlEx.getNumDml(); i++) {
                        System.debug('ERROR: DML error updating Account ' + accountsForDML[dmlEx.getDmlIndex(i)].Id + ' - ' + dmlEx.getDmlStatusCode(i) + ': ' + dmlEx.getDmlMessage(i));
                    }
                } catch (Exception e) {
                    System.debug('ERROR: General error updating accounts: ' + e.getMessage());
                }
            }
        }
    }
    
    public void finish(Database.BatchableContext bc) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(ADMIN_EMAIL_ADDRESSES); // Using externalized constant
        mail.setSubject('Nightly Discount Batch Completion Report - ' + System.today().format()); // More informative subject
        
        String body = 'Nightly Discount Batch processing completed.\n\n';
        body += 'Opportunities Processed Successfully: ' + processedOpportunityCount + '\n';
        body += 'Opportunities with Errors (Amount issue or DML failure): ' + failedOpportunityCount + '\n';
        body += 'Total Discount Applied Across Batch: $' + totalDiscountApplied.setScale(2) + '\n'; // Format currency
        body += 'Batch Initiated By: ' + UserInfo.getName() + '\n';
        body += 'Batch Completion Time: ' + System.now().format('MM/dd/yyyy HH:mm:ss') + '\n'; // Consistent date format
        
        mail.setPlainTextBody(body);
        
        // Send email with error handling
        try {
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
            System.debug('INFO: Batch completion email sent successfully.');
        } catch (Exception e) {
            System.debug('ERROR: Failed to send batch completion email: ' + e.getMessage());
        }
        
        // Improved and categorized debug logging
        System.debug('INFO: === NightlyDiscountBatch COMPLETED ===');
        System.debug('DEBUG: Total Opportunities Processed: ' + processedOpportunityCount);
        System.debug('DEBUG: Total Opportunities with Errors: ' + failedOpportunityCount);
        System.debug('DEBUG: Aggregate Discount Applied: ' + totalDiscountApplied);
        System.debug('DEBUG: Batch Run By User: ' + UserInfo.getName());
        System.debug('DEBUG: Batch Completion Timestamp: ' + System.now());
    }
}