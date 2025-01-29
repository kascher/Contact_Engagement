@IsTest
public class HistoricalAOCRBatchTest {

    /**
     * @description Test method for HistoricalAOCRBatch to validate active OCR counts.
     */
    @IsTest
    static void testHistoricalAOCRBatch() {
        // Setup test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(), // Opportunity close date
            StageName = 'Closed Won',
            AccountId = acc.Id
        );
        insert opp;

        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id);
        Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith', AccountId = acc.Id);
        insert new List<Contact>{contact1, contact2};

        OpportunityContactRole ocr1 = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact1.Id, Role = 'Decision Maker');
        OpportunityContactRole ocr2 = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact2.Id, Role = 'Influencer');
        insert new List<OpportunityContactRole>{ocr1, ocr2};

        // Derived date range
        Date closeDate = opp.CloseDate;
        Date activityStartDate = closeDate.addDays(-10); // NOD = 10

        // Create a Task within the range
        Task task = new Task(
            WhoId = contact1.Id,
            Subject = 'Follow up',
            Status = 'Completed',
            ActivityDate = activityStartDate.addDays(1) // Set ActivityDate instead of CompletedDateTime
        );
        insert task;

   // Create an Event within the range
Date eventDate = activityStartDate.addDays(2);
DateTime eventStartTime = DateTime.newInstance(eventDate, Time.newInstance(11, 0, 0, 0));

Event evt = new Event(
    WhoId = contact2.Id,
    Subject = 'Meeting',
    DurationInMinutes = 60,
    ActivityDateTime = eventStartTime,
    EndDateTime = eventStartTime.addMinutes(60), // End time matches duration
    IsAllDayEvent = false
);
insert evt;

        // Run the batch
        HistoricalAOCRBatch batch = new HistoricalAOCRBatch(10, Date.today().addDays(-30));
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

        // Refresh the opportunity to get the updated field value
        Opportunity updatedOpp = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :opp.Id];

        // Assert the active OCR count
        if (Schema.sObjectType.Opportunity.fields.asreporting__Active_OCRs__c.isUpdateable()) {              
        System.assertEquals(2, updatedOpp.asreporting__Active_OCRs__c, 'The active OCR count should be correct.');
    } else {
    System.debug('The asreporting__Active_OCRs__c field is not updateable.');
    }
}

    /**
     * @description Test method for HistoricalAOCRBatch with no matching tasks/events or LastActivityDate.
     */
    @IsTest
    static void testHistoricalAOCRBatchNoActivity() {
        // Setup test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(),
            StageName = 'Closed Won',
            AccountId = acc.Id
        );
        insert opp;

        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id);
        insert contact1;

        OpportunityContactRole ocr1 = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact1.Id, Role = 'Decision Maker');
        insert ocr1;

        // Run the batch
        HistoricalAOCRBatch batch = new HistoricalAOCRBatch(10, Date.today().addDays(-30));
        Test.startTest();
        Database.executeBatch(batch);
        Test.stopTest();

         // Refresh the opportunity to get the updated field value
        Opportunity updatedOpp = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :opp.Id];

         // Assert the active OCR count
         if (Schema.sObjectType.Opportunity.fields.asreporting__Active_OCRs__c.isUpdateable()) {                
        System.assertEquals(0, updatedOpp.asreporting__Active_OCRs__c, 'The active OCR count should be zero when there is no activity.');
    } else {
        System.debug('The asreporting__Active_OCRs__c field is not updateable.');       
    }
}
    @IsTest
    static void testHistoricalAOCRBatchWithOutdatedTask() {
        // Setup test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(), // Opportunity close date
            StageName = 'Closed Won',
            AccountId = acc.Id
        );
        insert opp;

        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id);
        Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith', AccountId = acc.Id);
        insert new List<Contact>{contact1, contact2};

        Task outdatedTask = new Task(
            Subject = 'Outdated Task',
            Status = 'Completed',
            ActivityDate = Date.today().addDays(-30), // Task date outside of the accepted range
            WhoId = contact1.Id,
            WhatId = opp.Id
        );
        insert outdatedTask;

        Event outdatedEvent = new Event(
            Subject = 'Outdated Event',
            DurationInMinutes = 60,
            ActivityDateTime = Date.today().addDays(-45), // Event date outside of the accepted range
            WhoId = contact2.Id,
            WhatId = opp.Id
        );
        insert outdatedEvent;

        // Call the batch method
        Test.startTest();
        HistoricalAOCRBatch batch = new HistoricalAOCRBatch(1, Date.today().addDays(-30));
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify the results
        List<AggregateResult> results = [
            SELECT COUNT(Id) cnt
            FROM OpportunityContactRole
            WHERE OpportunityId = :opp.Id
        ];

        System.assertEquals(0, results[0].get('cnt'), 'No OpportunityContactRole records should be created for the outdated task and event.');
    }
    /**
     * @description Test method for HistoricalAOCRBatch to validate the finish method and email sending.
     */
    @IsTest
    static void testHistoricalAOCRBatchFinish() {
        // Setup test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(), // Opportunity close date
            StageName = 'Closed Won',
            AccountId = acc.Id
        );
        insert opp;

        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id);
        Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith', AccountId = acc.Id);
        insert new List<Contact>{contact1, contact2};

        OpportunityContactRole ocr1 = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact1.Id, Role = 'Decision Maker');
        OpportunityContactRole ocr2 = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact2.Id, Role = 'Influencer');
        insert new List<OpportunityContactRole>{ocr1, ocr2};

        // Run the batch
        Test.startTest();
        HistoricalAOCRBatch batch = new HistoricalAOCRBatch(30, Date.today().addDays(-30));
        Database.executeBatch(batch);
        Test.stopTest();

        // Verify that the email was sent
        List<EmailMessage> sentEmails = [SELECT Id, Subject, ToAddress FROM EmailMessage];
        System.assertEquals(1, sentEmails.size(), 'One email should have been sent.');
        System.assertEquals('Batch Job Completion Notification', sentEmails[0].Subject, 'The email subject should be correct.');
        System.assertEquals(UserInfo.getUserEmail(), sentEmails[0].ToAddress, 'The email should be sent to the running user.');
    }
     /**
     * @description Test method for HistoricalAOCRBatch to validate the invocable method.
     */
    @IsTest
    static void testRunBatchInvocable() {
        // Setup test data
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(), // Opportunity close date
            StageName = 'Closed Won',
            AccountId = acc.Id
        );
        insert opp;

        Contact contact1 = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = acc.Id);
        Contact contact2 = new Contact(FirstName = 'Jane', LastName = 'Smith', AccountId = acc.Id);
        insert new List<Contact>{contact1, contact2};

        OpportunityContactRole ocr1 = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact1.Id, Role = 'Decision Maker');
        OpportunityContactRole ocr2 = new OpportunityContactRole(OpportunityId = opp.Id, ContactId = contact2.Id, Role = 'Influencer');
        insert new List<OpportunityContactRole>{ocr1, ocr2};

        // Run the batch using the invocable method
        HistoricalAOCRBatch.BatchInput input = new HistoricalAOCRBatch.BatchInput();
        input.nod = 30;
        input.soqlDate = Date.today().addDays(-30);
        List<HistoricalAOCRBatch.BatchInput> inputs = new List<HistoricalAOCRBatch.BatchInput>{input};

        Test.startTest();
        List<HistoricalAOCRBatch.BatchOutput> outputs = HistoricalAOCRBatch.runBatch(inputs);
        Test.stopTest();

        // Verify the output
        System.assertEquals(1, outputs.size(), 'There should be one output.');
        System.assertEquals(0, outputs[0].recordsProcessed, 'The number of records processed should be correct.');
        System.assertEquals(0, outputs[0].errorCount, 'The error count should be zero.');
        System.assertEquals(0, outputs[0].totalJobItems, 'The total job items should be correct.');
    }   
}