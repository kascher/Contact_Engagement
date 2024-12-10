@IsTest
public class OpportunityActiveContactBatchTest {
    @IsTest
    static void testBatchableExecution() {
        // Query active OpportunityStage metadata
        List<OpportunityStage> stages = [SELECT MasterLabel, IsClosed FROM OpportunityStage WHERE IsActive = true];
        System.assert(!stages.isEmpty(), 'No active Opportunity stages found.');

        String closedWonStage = null;
        String closedLostStage = null;

        // Find stages for Closed Won and Closed Lost
        for (OpportunityStage stage : stages) {
            if (stage.IsClosed && stage.MasterLabel.contains('Won')) {
                closedWonStage = stage.MasterLabel;
            } else if (stage.IsClosed && stage.MasterLabel.contains('Lost')) {
                closedLostStage = stage.MasterLabel;
            }
        }

        // Ensure required stages are found
        System.assert(closedWonStage != null, 'No Closed Won stage found.');
        System.assert(closedLostStage != null, 'No Closed Lost stage found.');

        // Create test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Opportunity testOpportunity1 = new Opportunity(
            Name = 'Test Opportunity 1',
            AccountId = testAccount.Id,
            StageName = closedWonStage,
            CloseDate = Date.today().addDays(-10)
        );
        Opportunity testOpportunity2 = new Opportunity(
            Name = 'Test Opportunity 2',
            AccountId = testAccount.Id,
            StageName = closedLostStage,
            CloseDate = Date.today().addDays(-20)
        );
        insert new List<Opportunity> { testOpportunity1, testOpportunity2 };

        Contact testContact1 = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = testAccount.Id
        );
        Contact testContact2 = new Contact(
            FirstName = 'Jane',
            LastName = 'Smith',
            AccountId = testAccount.Id
        );
        insert new List<Contact> { testContact1, testContact2 };

        OpportunityContactRole ocr1 = new OpportunityContactRole(
            OpportunityId = testOpportunity1.Id,
            ContactId = testContact1.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );
        OpportunityContactRole ocr2 = new OpportunityContactRole(
            OpportunityId = testOpportunity2.Id,
            ContactId = testContact2.Id,
            Role = 'Influencer',
            IsPrimary = false
        );
        insert new List<OpportunityContactRole> { ocr1, ocr2 };

        // Execute the batchable class
        Test.startTest();
        Date startDate = Date.today().addDays(-30);
        Database.executeBatch(new OpportunityActiveContactBatch('LastActivityDate', 10, startDate));
        Test.stopTest();

        // Validate results
        Opportunity updatedOpp1 = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :testOpportunity1.Id];
        Opportunity updatedOpp2 = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :testOpportunity2.Id];

        System.assertEquals(1, updatedOpp1.asreporting__Active_OCRs__c, 'Active OCR count for Opportunity 1 should be 1.');
        System.assertEquals(1, updatedOpp2.asreporting__Active_OCRs__c, 'Active OCR count for Opportunity 2 should be 1.');
    }

    @IsTest
    static void testInvocableMethod() {
        // Query active OpportunityStage metadata
        List<OpportunityStage> stages = [SELECT MasterLabel, IsClosed FROM OpportunityStage WHERE IsActive = true];
        System.assert(!stages.isEmpty(), 'No active Opportunity stages found.');

        String closedWonStage = null;

        // Find stage for Closed Won
        for (OpportunityStage stage : stages) {
            if (stage.IsClosed && stage.MasterLabel.contains('Won')) {
                closedWonStage = stage.MasterLabel;
                break;
            }
        }

        // Ensure required stage is found
        System.assert(closedWonStage != null, 'No Closed Won stage found.');

        // Create test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Opportunity testOpportunity = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            StageName = closedWonStage,
            CloseDate = Date.today().addDays(-15)
        );
        insert testOpportunity;

        Contact testContact = new Contact(
            FirstName = 'John',
            LastName = 'Doe',
            AccountId = testAccount.Id
        );
        insert testContact;

        OpportunityContactRole ocr = new OpportunityContactRole(
            OpportunityId = testOpportunity.Id,
            ContactId = testContact.Id,
            Role = 'Decision Maker',
            IsPrimary = true
        );
        insert ocr;

        // Execute the invocable method
        Test.startTest();
        OpportunityActiveContactBatch.BatchInput input = new OpportunityActiveContactBatch.BatchInput();
        input.lastActivityDateAPIName = 'LastActivityDate';
        input.nod = 10;
        input.SOQLDate = Date.today().addDays(-30);

        OpportunityActiveContactBatch.runBatch(new List<OpportunityActiveContactBatch.BatchInput> { input });
        Test.stopTest();

        // Validate results
        Opportunity updatedOpp = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :testOpportunity.Id];
        System.assertEquals(1, updatedOpp.asreporting__Active_OCRs__c, 'Active OCR count for the Opportunity should be 1.');
    }
}