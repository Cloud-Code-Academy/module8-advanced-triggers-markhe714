public with sharing class OpportunityHelper {
    /*
    * When an opportunity is updated validate that the amount is greater than 5000.
    */
    public static void validationOnAmount(List<Opportunity> oppList){
        for(Opportunity opp : oppList){
            if(opp.Amount < 5000){
                opp.addError('Opportunity amount must be greater than 5000');
            }
        }
    }



    /*
    * When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
    * Prevent deletion of closed Opportunities
    */
    public static void closedWonOppDeletionValidation(List<Opportunity> oppList){
        //Account related to the opportunities 
        Map<Id, Account> accounts = new Map<Id, Account>([SELECT Id, Industry FROM Account WHERE Id IN (SELECT AccountId FROM Opportunity WHERE Id IN :oppList)]);
        for(Opportunity opp : oppList){
            if(opp.StageName == 'Closed Won'){
                if(accounts.get(opp.AccountId).Industry == 'Banking'){
                    opp.addError('Cannot delete a closed won opportunity for a banking account');
                }
            }

            if(opp.IsClosed) {
                opp.addError('Cannot delete closed opportunity');
            }
            
        }
    }



    /*
    * When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
    */
    public static void setCEOAsPrimaryContact(List<Opportunity> oppList){
        //Get contacts related to the opportunity account
        Set<Id> accountIds = new Set<Id>();
        for(Opportunity opp : oppList){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'CEO' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for(Opportunity opp : oppList){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }
    }



    /* 
    * Set default Type for new Opportunities
    */
    public static void setDefaultType(List<Opportunity> oppList){
        for (Opportunity opp : oppList) {
            if (opp.Type == null) {
                opp.Type = 'New Customer';
            }
        }
    }    



    /* 
    * Append Stage changes in Opportunity Description
    */
    public static void setOppDescription(List<Opportunity> oppList, Map<Id,Opportunity> oldOppMap){
        for (Opportunity opp : oppList) {
            if (opp.StageName != null && opp.StageName != oldOppMap.get(opp.Id).StageName) {
                if (opp.Description == null) {
                    opp.Description = '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                }else{
                    opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                }
            }
        }    
    }



    /* 
    * Create a new Task for newly inserted Opportunities
    */
    public static void CreateNewTaskforNewOpp(List<Opportunity> oppList){
        List<Task> taskToBeCreated = new List<Task>();
        for (Opportunity opp : oppList) {
            Task tsk = new Task();
            tsk.Subject = 'Call Primary Contact';
            tsk.WhatId = opp.Id;
            tsk.WhoId = opp.Primary_Contact__c;
            tsk.OwnerId = opp.OwnerId;
            tsk.ActivityDate = Date.today().addDays(3);
            taskToBeCreated.add(tsk);
        }
        insert taskToBeCreated;
    }


    /* 
    * Send email notifications when an Opportunity is deleted 
    */
    public static void notifyOwnersOpportunityDeleted(List<Opportunity> oppList){
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Set<Id> oppOwnwerIds = new Set<Id>();
        for (Opportunity opp : oppList) {
            oppOwnwerIds.add(opp.OwnerId);
        }
        List<User> oppOwners = [SELECT Id, Email FROM User WHERE Id IN :oppOwnwerIds];
        Map<Id,String> ownerIdToEmail = new Map<Id,String>();
        for (User oppOwner : oppOwners) {
            ownerIdToEmail.put(oppOwner.Id, oppOwner.Email);
        }
        for (Opportunity opp : oppList) {
            if (ownerIdToEmail.get(opp.OwnerId) != Null) {
                List<String> toAddresses = new List<String>{ownerIdToEmail.get(opp.OwnerId)};
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(toAddresses);
                mail.setSubject('Opportunity Deleted : ' + opp.Name);
                mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
                mails.add(mail);
            }
        }

        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }


    /* 
    * Assign the primary contact to undeleted Opportunities
    */
    public static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {  
        List<Opportunity> undeletedOpps = [SELECT Id, AccountId, Primary_Contact__c FROM Opportunity WHERE Id IN :oppNewMap.keySet()];
        Set<Id> accountIds = new Set<Id>();

        for(Opportunity opp : undeletedOpps){
            accountIds.add(opp.AccountId);
        }
        
        Map<Id, Contact> contacts = new Map<Id, Contact>([SELECT Id, FirstName, AccountId FROM Contact WHERE AccountId IN :accountIds AND Title = 'VP Sales' ORDER BY FirstName ASC]);
        Map<Id, Contact> accountIdToContact = new Map<Id, Contact>();

        for (Contact cont : contacts.values()) {
            if (!accountIdToContact.containsKey(cont.AccountId)) {
                accountIdToContact.put(cont.AccountId, cont);
            }
        }

        for(Opportunity opp : undeletedOpps){
            if(opp.Primary_Contact__c == null){
                if (accountIdToContact.containsKey(opp.AccountId)){
                    opp.Primary_Contact__c = accountIdToContact.get(opp.AccountId).Id;
                }
            }
        }

        update undeletedOpps;
    }








}
