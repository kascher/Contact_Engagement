/**
 * @description This class generates sample data for Accounts, Contacts, Opportunities, and Tasks.
 * @sharingModel with sharing
 */
public with sharing class AccountsContactsOppsTasksDataGenerator {

    /**
     * @description Creates state accounts with associated data.
     */
    public static void createStateAccountsWithData() {
        if (!Schema.sObjectType.Account.isCreateable()) {
            // Log insufficient permissions to create Account records
            // Custom logging logic can be added here if needed
            return;
        }

        List<Account> accounts = createAccounts();
        Map<Id, List<Contact>> accountContactsMap = createContacts(accounts);
        List<Opportunity> opportunities = createOpportunities(accounts);
        List<OpportunityContactRole> contactRoles = new List<OpportunityContactRole>();
        List<Task> tasks = new List<Task>();

        DataWrapper dataWrapper = new DataWrapper();
        dataWrapper.opportunities = opportunities;
        dataWrapper.accountContactsMap = accountContactsMap;
        dataWrapper.contactRoles = contactRoles;
        dataWrapper.tasks = tasks;
        createOpportunityContactRolesAndTasks(dataWrapper);

        // Insert Opportunity Contact Roles
        if (Schema.sObjectType.OpportunityContactRole.isCreateable()) {
            insert contactRoles;
            // Log insufficient permissions to create OpportunityContactRole records
            // Custom logging logic can be added here if needed
            // Log insufficient permissions to create OpportunityContactRole records
            // Custom logging logic can be added here if needed
        }

    }

    private static List<Account> createAccounts() {
        List<Account> accounts = new List<Account>();
        List<String> states = new List<String>{
            'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia',
            'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland',
            'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire',
            'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania',
            'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington',
            'West Virginia', 'Wisconsin', 'Wyoming'
        };

        for (String state : states) {
            Account account = new Account(Name = state);
            accounts.add(account);
        }

        insert accounts;
        return accounts;
    }

    private static Map<Id, List<Contact>> createContacts(List<Account> accounts) {
        List<Contact> contacts = new List<Contact>();
        Map<Id, List<Contact>> accountContactsMap = new Map<Id, List<Contact>>();
                // Log insufficient permissions to create Contact records
                // Custom logging logic can be added here if needed
        for (Account acc : accounts) {
            if (!Schema.sObjectType.Contact.isCreateable()) {
                // Handle insufficient permissions to create Contact records
                continue;
            }

            List<Contact> accountContacts = new List<Contact>();
            for (Integer i = 0; i < 5; i++) {
                String firstName = 'Funny' + i;
                String lastName = 'Mc' + acc.Name.replaceAll(' ', '');
                Contact contact = new Contact(
                    FirstName = firstName,
                    LastName = lastName,
                    Email = firstName.toLowerCase() + '@' + lastName.toLowerCase() + '.com',
                    AccountId = acc.Id
                );
                accountContacts.add(contact);
                contacts.add(contact);
            }
            accountContactsMap.put(acc.Id, accountContacts);
        }

        insert contacts;
        return accountContactsMap;
    }

    private static List<Opportunity> createOpportunities(List<Account> accounts) {
                List<Opportunity> opportunities = new List<Opportunity>();
                // Log insufficient permissions to create Opportunity records
                // Custom logging logic can be added here if needed

        for (Account acc : accounts) {
            if (!Schema.sObjectType.Opportunity.isCreateable()) {
                // Handle insufficient permissions to create Opportunity records
                continue;
            }

            for (Integer i = 0; i < 5; i++) {
                String stageName;
                if (Math.mod(i, 3) == 0) {
                    stageName = 'Prospecting';
                } else if (Math.mod(i, 3) == 1) {
                    stageName = 'Closed Won';
                } else {
                    stageName = 'Closed Lost';
                }
                Integer closeDays = (stageName == 'Prospecting') ? 30 : -30;
                Opportunity opp = new Opportunity(
                    Name = acc.Name + ' Opportunity ' + i,
                    StageName = stageName,
                    CloseDate = Date.today().addDays(closeDays),
                    Amount = 10000,
                    AccountId = acc.Id
                );
                opportunities.add(opp);
            }
        }

        insert opportunities;
        return opportunities;
    }
    private static void createOpportunityContactRolesAndTasks(DataWrapper dataWrapper) {
        for (Opportunity opp : dataWrapper.opportunities) {
            List<Contact> relatedContacts = dataWrapper.accountContactsMap.get(opp.AccountId);

            Integer roleCount = Math.min(relatedContacts.size(), 1 + (Integer)Math.floor(Math.random() * 3)); // 1-3 random roles
            for (Integer j = 0; j < roleCount; j++) {
                Contact relatedContact = relatedContacts[j];
                if (Schema.sObjectType.OpportunityContactRole.isCreateable()) {
                    OpportunityContactRole ocr = new OpportunityContactRole(
                        OpportunityId = opp.Id,
                        ContactId = relatedContact.Id,
                        Role = 'Influencer'
                    );
                    dataWrapper.contactRoles.add(ocr);
                }

                if (Schema.sObjectType.Task.isCreateable()) {
                    Task task = new Task(
                        Subject = 'Follow up with ' + relatedContact.FirstName,
                        WhatId = opp.Id,
                        OwnerId = UserInfo.getUserId(),
                        ActivityDate = Date.today().addDays(-15 + (Integer)(Math.random() * 45)) // -15 to +30 days
                    );
                    dataWrapper.tasks.add(task);
                }
            }
        }
    }

    private class DataWrapper {
        List<Opportunity> opportunities;
        Map<Id, List<Contact>> accountContactsMap;
        List<OpportunityContactRole> contactRoles;
        List<Task> tasks;

        DataWrapper() {
            this.accountContactsMap = new Map<Id, List<Contact>>();
            this.contactRoles = new List<OpportunityContactRole>();
            this.tasks = new List<Task>();
        }
    }
    /**
     * @description Execute Method for Testing in Anonymous Apex
     */
    public static void executeForTest() {
        createStateAccountsWithData();
    }
}