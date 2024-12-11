public class AccountsContactsOppsTasksDataGenerator {
    public static void createStateAccountsWithData() {
        List<Account> accounts = new List<Account>();
        List<Contact> contacts = new List<Contact>();
        List<Opportunity> opportunities = new List<Opportunity>();
        List<OpportunityContactRole> contactRoles = new List<OpportunityContactRole>();
        List<Task> tasks = new List<Task>();

        // List of US states
        List<String> states = new List<String>{
            'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia',
            'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland',
            'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire',
            'New Jersey', 'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio', 'Oklahoma', 'Oregon', 'Pennsylvania',
            'Rhode Island', 'South Carolina', 'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia', 'Washington',
            'West Virginia', 'Wisconsin', 'Wyoming'
        };

        for (String state : states) {
            // Create Account
            Account account = new Account(Name = state);
            accounts.add(account);
        }

        // Insert Accounts
        insert accounts;

        // Create Contacts for each Account
        Map<Id, List<Contact>> accountContactsMap = new Map<Id, List<Contact>>();
        for (Account acc : accounts) {
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

        // Insert Contacts
        insert contacts;

        // Create Opportunities for each Account
        for (Account acc : accounts) {
            for (Integer i = 0; i < 5; i++) {
                String stageName = (Math.mod(i, 2) == 0) ? 'Prospecting' : 'Closed Won';
                Integer closeDays = (Math.mod(i, 2) == 0) ? 30 : -30;
                Opportunity opp = new Opportunity(
                    Name = acc.Name + ' Opportunity ' + i,
                    StageName = stageName,
                    CloseDate = Date.today().addDays(closeDays),
                    AccountId = acc.Id
                );
                opportunities.add(opp);
            }
        }

        // Insert Opportunities
        insert opportunities;

        // Create Opportunity Contact Roles and Tasks
        for (Opportunity opp : opportunities) {
            List<Contact> relatedContacts = accountContactsMap.get(opp.AccountId);

            Integer roleCount = Math.min(relatedContacts.size(), 1 + (Integer)Math.floor(Math.random() * 3)); // 1-3 random roles
            for (Integer j = 0; j < roleCount; j++) {
                Contact relatedContact = relatedContacts[j];
                OpportunityContactRole ocr = new OpportunityContactRole(
                    OpportunityId = opp.Id,
                    ContactId = relatedContact.Id,
                    Role = 'Influencer'
                );
                contactRoles.add(ocr);

                Task task = new Task(
                    Subject = 'Follow up with ' + relatedContact.FirstName,
                    WhatId = opp.Id,
                    OwnerId = UserInfo.getUserId(),
                    ActivityDate = Date.today().addDays(-15 + (Integer)(Math.random() * 45)) // -15 to +30 days
                );
                tasks.add(task);
            }
        }

        // Insert Opportunity Contact Roles
        insert contactRoles;

        // Insert Tasks
        insert tasks;
    }

    // Execute Method for Testing in Anonymous Apex
    public static void executeForTest() {
        createStateAccountsWithData();
        System.debug('Data generation complete!');
    }
}