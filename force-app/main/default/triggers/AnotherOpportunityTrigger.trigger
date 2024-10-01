/*
AnotherOpportunityTrigger Overview

This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

IMPORTANT:
- This trigger does not adhere to Salesforce best practices.
- It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

ISSUES:
Avoid nested for loop - 1 instance - Done!
Avoid DML inside for loop - 1 instance - Done!
Bulkify Your Code - 1 instance - Done!
Avoid SOQL Query inside for loop - 2 instances
Stop recursion - 1 instance - Done!

RESOURCES: 
https://www.salesforceben.com/12-salesforce-apex-best-practices/
https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/
trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    if (Trigger.isBefore){
        if (Trigger.isInsert){
            // Set default Type for new Opportunities
            
            // Issue:  Bulkify Your Code 1 of 1 instance
            /*
            Opportunity opp = Trigger.new[0];
            if (opp.Type == null){
                opp.Type = 'New Customer';
            } 
            */

            // Fix: Bulkify Your Code 1 of 1 instance
            for (Opportunity opp : Trigger.new) {
                if (opp.Type == null) {
                    opp.Type = 'New Customer';
                }
            }
           
        } else if (Trigger.isUpdate){
            // Fix 1:  Avoid DML inside for loop - 1 of 1 instance
            // Fix 2:  Stop recursion - 1 of 1 instance
            // Append Stage changes in Opportunity Description
            for (Opportunity opp : Trigger.new) {
                if (opp.StageName != null && opp.StageName != trigger.oldMap.get(opp.Id).StageName) {
                    if (opp.Description == null) {
                        opp.Description = '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                    }else{
                        opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                    }
                }
            }    
        } else if (Trigger.isDelete){
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : Trigger.old){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
    }

    if (Trigger.isAfter){
        if (Trigger.isInsert){
            // Create a new Task for newly inserted Opportunities

            //Issue: Avoid DML inside for loop - 1 of 1 instance
            /*
            for (Opportunity opp : Trigger.new){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                insert tsk;
            }
            */

            //Fix: Avoid DML inside for loop - 1 of 1 instance
            List<Task> taskToBeCreated = new List<Task>();
            for (Opportunity opp : Trigger.new) {
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);
                taskToBeCreated.add(tsk);
            }
            insert taskToBeCreated;

        } else if (Trigger.isUpdate){
            // Append Stage changes in Opportunity Description
            
            /* - Issue 1: Avoid DML inside for loop - 1 of 1 instance
               - Issue 2: Stop recursion - 1 of 1 instance
            for (Opportunity opp : Trigger.new){
                for (Opportunity oldOpp : Trigger.old){
                    if (opp.StageName != null){
                        opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                    }
                }
            }
            update Trigger.new;
            */


        }
        // Send email notifications when an Opportunity is deleted 
        else if (Trigger.isDelete){
            notifyOwnersOpportunityDeleted(Trigger.old);
        } 
        // Assign the primary contact to undeleted Opportunities
        else if (Trigger.isUndelete){
            assignPrimaryContact(Trigger.newMap);
        }
    }

    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        /*  Issue: Avoid SOQL Query inside for loop - 1 of 2 instances
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] {[SELECT Id, Email FROM User WHERE Id = :opp.OwnerId].Email};
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        */

        // Fix: Avoid SOQL Query inside for loop - 1 of 2 instances
        Set<Id> oppOwnwerIds = new Set<Id>();
        for (Opportunity opp : opps) {
            oppOwnwerIds.add(opp.OwnerId);
        }
        List<User> oppOwners = [SELECT Id, Email FROM User WHERE Id IN :oppOwnwerIds];
        Map<Id,String> ownerIdToEmail = new Map<Id,String>();
        for (User oppOwner : oppOwners) {
            ownerIdToEmail.put(oppOwner.Id, oppOwner.Email);
        }
        for (Opportunity opp : opps) {
            if (ownerIdToEmail.get(opp.OwnerId) != Null) {
                List<String> toAddresses = new List<String>{ ownerIdToEmail.get(opp.OwnerId)};
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
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {    
        /*  Issue: Avoid SOQL Query inside for loop - 2 of 2 instances
        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : oppNewMap.values()){            
            Contact primaryContact = [SELECT Id, AccountId FROM Contact WHERE Title = 'VP Sales' AND AccountId = :opp.AccountId LIMIT 1];
            if (opp.Primary_Contact__c == null){
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = primaryContact.Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
        */

        //  Fix: Avoid SOQL Query inside for loop - 2 of 2 instances
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