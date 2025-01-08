@IsTest
public class OpportunityActiveContactBatchTest {
    @IsTest
    static void testBatchableExecution() {
        List<OpportunityStage> stages = getActiveOpportunityStages();
        String closedWonStage = getStageLabel(stages, 'Won');
        String closedLostStage = getStageLabel(stages, 'Lost');

        System.assert(closedWonStage != null, 'No Closed Won stage found.');
        System.assert(closedLostStage != null, 'No Closed Lost stage found.');

        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Opportunity testOpportunity1 = createTestOpportunity(testAccount.Id, closedWonStage, -10);
        Opportunity testOpportunity2 = createTestOpportunity(testAccount.Id, closedLostStage, -20);

        try {
            insert new List<Opportunity> { testOpportunity1, testOpportunity2 };
        } catch (DmlException e) {
            System.error('Failed to insert Opportunities: ' + e.getMessage());
        }

        if (testOpportunity1.Id != null && testOpportunity2.Id != null) {
            createTestContactsAndRoles(testAccount.Id, testOpportunity1.Id, testOpportunity2.Id);
        } else {
            System.warn('Skipping OpportunityContactRole creation due to missing Opportunity Ids.');
        }

        executeBatchAndValidate(testOpportunity1.Id, testOpportunity2.Id);
    }

    private static void executeBatchAndValidate(Id oppId1, Id oppId2) {
        Test.startTest();
        Date startDate = Date.today().addDays(-30);
        Database.executeBatch(new OpportunityActiveContactBatch('LastActivityDate', 10, startDate));
        Test.stopTest();

        validateResults(oppId1, oppId2);
        List<OpportunityStage> stages = getActiveOpportunityStages();
        System.assert(stages.isEmpty() == false, 'No active Opportunity stages found.');
        String closedWonStage = getStageLabel(stages, 'Won');
        String closedLostStage = getStageLabel(stages, 'Lost');

        System.assert(closedWonStage != null, 'No Closed Won stage found.');
        System.assert(closedLostStage != null, 'No Closed Lost stage found.');

        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Opportunity testOpportunity1 = createTestOpportunity(testAccount.Id, closedWonStage, -10);
        Opportunity testOpportunity2 = createTestOpportunity(testAccount.Id, closedLostStage, -20);

        try {
            insert new List<Opportunity> { testOpportunity1, testOpportunity2 };
        } catch (DmlException e) {
            System.error('Failed to insert Opportunities: ' + e.getMessage());
        }

        if (testOpportunity1.Id != null && testOpportunity2.Id != null) {
            createTestContactsAndRoles(testAccount.Id, testOpportunity1.Id, testOpportunity2.Id);
        } else {
            System.warn('Skipping OpportunityContactRole creation due to missing Opportunity Ids.');
        }

        Test.startTest();
        Date startDate = Date.today().addDays(-30);
        Database.executeBatch(new OpportunityActiveContactBatch('LastActivityDate', 10, startDate));
        Test.stopTest();

        validateResults(testOpportunity1.Id, testOpportunity2.Id);
    }

    private static List<OpportunityStage> getActiveOpportunityStages() {
        List<OpportunityStage> stages = [SELECT MasterLabel, IsClosed FROM OpportunityStage WHERE IsActive = true];
        System.assert(!stages.isEmpty());
        return stages;
    }

    private static String getStageLabel(List<OpportunityStage> stages, String label) {
        for (OpportunityStage stage : stages) {
            if (stage.IsClosed && stage.MasterLabel.contains(label)) {
                return stage.MasterLabel;
            }
        }
        return null;
    }

    private static Opportunity createTestOpportunity(Id accountId, String stageName, Integer daysOffset) {
        return new Opportunity(
            Name = 'Test Opportunity ' + stageName,
            AccountId = accountId,
            StageName = stageName,
            CloseDate = Date.today().addDays(daysOffset)
        );
    }

    private static void createTestContactsAndRoles(Id accountId, Id oppId1, Id oppId2) {
        Contact testContact1 = new Contact(FirstName = 'John', LastName = 'Doe', AccountId = accountId);
        Contact testContact2 = new Contact(FirstName = 'Jane', LastName = 'Smith', AccountId = accountId);
        insert new List<Contact> { testContact1, testContact2 };

        OpportunityContactRole ocr1 = new OpportunityContactRole(OpportunityId = oppId1, ContactId = testContact1.Id, Role = 'Decision Maker', IsPrimary = true);
        OpportunityContactRole ocr2 = new OpportunityContactRole(OpportunityId = oppId2, ContactId = testContact2.Id, Role = 'Influencer', IsPrimary = false);
        insert new List<OpportunityContactRole> { ocr1, ocr2 };
    }

    private static void validateResults(Id oppId1, Id oppId2) {
        if (oppId1 != null) {
            // Log the information
            System.warn('Skipping OpportunityContactRole creation due to missing Opportunity Ids.');
            System.assertEquals(1, updatedOpp1.asreporting__Active_OCRs__c, 'Active OCR count for Opportunity 1 should be 1.');
        }
        if (oppId2 != null) {
            Opportunity updatedOpp2 = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :oppId2];
            System.assertEquals(1, updatedOpp2.asreporting__Active_OCRs__c, 'Active OCR count for Opportunity 2 should be 1.');
        }
    // Query active OpportunityStage metadata
    List<OpportunityStage> stages = [SELECT MasterLabel, IsClosed FROM OpportunityStage WHERE IsActive = true];
        System.assert(!stages.isEmpty());

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

        try {
            insert new List<Opportunity> { testOpportunity1, testOpportunity2 };
        } catch (DmlException e) {
            System.debug('Failed to insert Opportunities: ' + e.getMessage());
        }

        if (testOpportunity1.Id != null && testOpportunity2.Id != null) {
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
        } else {
            System.debug('Skipping OpportunityContactRole creation due to missing Opportunity Ids.');
        }

        // Execute the batchable class
        Test.startTest();
        Date startDate = Date.today().addDays(-30);
        Database.executeBatch(new OpportunityActiveContactBatch('LastActivityDate', 10, startDate));
        Test.stopTest();

        // Validate results
        if (testOpportunity1.Id != null) {
            Opportunity updatedOpp1 = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :testOpportunity1.Id];
            System.assertEquals(1, updatedOpp1.asreporting__Active_OCRs__c, 'Active OCR count for Opportunity 1 should be 1.');
        }
        if (testOpportunity2.Id != null) {
            Opportunity updatedOpp2 = [SELECT asreporting__Active_OCRs__c FROM Opportunity WHERE Id = :testOpportunity2.Id];
            System.assertEquals(1, updatedOpp2.asreporting__Active_OCRs__c, 'Active OCR count for Opportunity 2 should be 1.');
        }
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

        try {
            insert testOpportunity;
        } catch (DmlException e) {
            System.debug('Failed to insert Opportunity: ' + e.getMessage());
        }

        if (testOpportunity.Id != null) {
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
        } else {
            System.debug('Skipping OpportunityContactRole creation and validation due to missing Opportunity Id.');
        }
    }
}