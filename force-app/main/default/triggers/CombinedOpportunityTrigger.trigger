  //Part 3 - OpportunityTriggerHandler Implementation
  /*
  * Create a new OpportunityTriggerHandler class that implements TriggerHandler
  * Combine the OpportunityTrigger and AnotherOpportunityTrigger into the new OpportunityTriggerHandler class
  * Methods from both trigger may have conflicting criteria and should be combined into one method
  * Only one OpportunityTrigger needs to run the OpportunityTriggerHandler class and the other can be commented out
  * All of the OpportunityTrigger and AnotherOpportunityTrigger tests should pass if you have implemented the OpportunityTriggerHandler class correctly
  * You can use the OpportunityTrigger provided or the previous one you created is last assignment
  * If you are using last lectures OpportunityTrigger you created. Copy and paste the code from the previous lecture's project into this project and deploy it to your org
  * Advanced/Optional - Utilize an OpportunityHelper class to modularize the OpportunityTriggerHandler class
  */

trigger CombinedOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {

    if (Trigger.isBefore && Trigger.isInsert) {
      /* 
       * Set default Type for new Opportunities
      */

      OpportunityHelper.setDefaultType(Trigger.new);

    }
  
    if (Trigger.isBefore && Trigger.isUpdate){
      /*
      * Opportunity Trigger
      * When an opportunity is updated validate that the amount is greater than 5000.
      * Trigger should only fire on update.
      */
        
      OpportunityHelper.validationOnAmount(Trigger.new);

      /*
      * Opportunity Trigger
      * When an opportunity is updated set the primary contact on the opportunity to the contact with the title of 'CEO'.
      * Trigger should only fire on update.
      */

      OpportunityHelper.setCEOAsPrimaryContact(Trigger.new);
      
      /*
      * Append Stage changes in Opportunity Description
      */

      OpportunityHelper.setOppDescription(Trigger.new, Trigger.oldMap);
    }


    if (Trigger.isBefore && Trigger.isDelete){
      /*
      * Opportunity Trigger
      * When an opportunity is deleted prevent the deletion of a closed won opportunity if the account industry is 'Banking'.
      * Trigger should only fire on delete.
      */
      OpportunityHelper.closedWonOppDeletionValidation(Trigger.old);  
    }


    if (Trigger.isAfter && Trigger.isInsert) {
      /*
      * Create a new Task for newly inserted Opportunities
      */
      OpportunityHelper.CreateNewTaskforNewOpp(Trigger.new);
    }


    if (Trigger.isAfter && Trigger.isDelete) {
      /*
      * Send email notifications when an Opportunity is deleted 
      */
     OpportunityHelper.notifyOwnersOpportunityDeleted(Trigger.old);
    }


    if (Trigger.isAfter && Trigger.isUndelete) {
      /* 
      * Assign the primary contact to undeleted Opportunities
      */
      OpportunityHelper.assignPrimaryContact(Trigger.newMap);
    }





}