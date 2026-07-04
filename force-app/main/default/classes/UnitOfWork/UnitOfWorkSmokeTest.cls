/**
 * Proves the vendored fflib Unit of Work works in this org: dependency-ordered
 * bulk inserts with lookup resolution, and single-savepoint rollback on failure.
 * Also serves as a copy-paste template for how services should use the UoW.
 */
@IsTest
private class UnitOfWorkSmokeTest {
    /**
     * Register 200 parent Accounts and 200 child Contacts whose AccountId is only
     * known AFTER the Accounts insert. commitWork must insert Accounts first, fill
     * each Contact's lookup, then insert Contacts — all in one transaction, one
     * DML statement per object type.
     */
    @IsTest
    static void commitWork_insertsParentsAndResolvesChildLookups_bulk() {
        fflib_ISObjectUnitOfWork uow = Application.UnitOfWork.newInstance();
        for (Integer i = 0; i < 200; i++) {
            Account parent = new Account(Name = 'UoW Acct ' + i);
            uow.registerNew(parent);
            // Contact.AccountId is populated by the UoW once `parent` has an Id
            uow.registerNew(new Contact(LastName = 'UoW Contact ' + i), Contact.AccountId, parent);
        }

        // Bypass this org's Account automation for the test: this targets the Unit
        // of Work, not Account behavior, and AccountTriggerHandler sets a state with
        // no country — which the org's enabled State/Country picklists reject.
        TriggerHandler.bypass('AccountTriggerHandler');
        try {
            Test.startTest();
            uow.commitWork();
            Test.stopTest();
        } finally {
            TriggerHandler.clearBypass('AccountTriggerHandler');
        }

        Map<Id, Account> insertedAccounts = new Map<Id, Account>(
            [SELECT Id FROM Account WHERE Name LIKE 'UoW Acct %']);
        Assert.areEqual(200, insertedAccounts.size(), 'All 200 accounts should be inserted');

        List<Contact> insertedContacts =
            [SELECT Id, AccountId FROM Contact WHERE LastName LIKE 'UoW Contact %'];
        Assert.areEqual(200, insertedContacts.size(), 'All 200 contacts should be inserted');
        for (Contact c : insertedContacts) {
            Assert.isTrue(
                insertedAccounts.containsKey(c.AccountId),
                'Each contact must be linked to an inserted account (UoW resolved the lookup)');
        }
    }

    /**
     * A registered Contact with no LastName fails to insert. Because commitWork
     * runs under a single savepoint, the already-inserted Account must roll back
     * and the exception must surface — the whole unit of work is atomic.
     */
    @IsTest
    static void commitWork_rollsBackEntireTransactionOnFailure() {
        fflib_ISObjectUnitOfWork uow = Application.UnitOfWork.newInstance();
        uow.registerNew(new Account(Name = 'Rollback Acct'));
        uow.registerNew(new Contact()); // no LastName -> REQUIRED_FIELD_MISSING on insert

        Boolean threw = false;
        Test.startTest();
        try {
            uow.commitWork();
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        Assert.isTrue(threw, 'commitWork should throw when a registered record fails DML');
        Assert.areEqual(
            0,
            [SELECT COUNT() FROM Account WHERE Name = 'Rollback Acct'],
            'The account must be rolled back — the UoW commits under one savepoint');
    }
}
