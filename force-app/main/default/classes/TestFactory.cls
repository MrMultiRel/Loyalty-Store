@isTest
public class TestFactory {
    
    public static List<Loyalty_Product__c> getMainProduct(Integer numberToCreate, Boolean doInsert) {

        List<Loyalty_Product__c> mainProducts = new List<Loyalty_Product__c>();

        for (Integer i = 0; i < numberToCreate; i++) {

            mainProducts.add(new Loyalty_Product__c(
                Name = 'Main Product ' + i,
                Price_Currency__c = 100 * i
            ));
        }

        if(doInsert) {
            insert mainProducts;
        }

        return mainProducts;
    }

    public static List<Loyalty_Product__c> getPointsProduct(List<Loyalty_Product__c> mainProducts, Boolean doInsert) {

        List<Loyalty_Product__c> pointsProducts = new List<Loyalty_Product__c>();

        for (Integer i = 0; i < mainProducts.size(); i++) {

            pointsProducts.add(new Loyalty_Product__c(
                Name = 'Point Product ' + i,
                Price_Points__c = 10 * i,
                Parent_Product__c = mainProducts[i].Id
            ));

        }

        if(doInsert) {
            insert pointsProducts;
        }

        return pointsProducts;
    }

    public static List<Loyalty_Cart__c> getLoyaltyCart(List<Loyalty_Product__c> products, Contact contact, Boolean doInsert) {

        List<Loyalty_Cart__c> carts = new List<Loyalty_Cart__c>();

        for (Integer i = 0; i < products.size(); i++) {

            carts.add(new Loyalty_Cart__c(
                Contact__c = contact.Id,
                Loyalty_Product__c = products[i].Id,
                Quantity__c = 1
            ));

        }

        if(doInsert) {
            insert carts;
        }

        return carts;
    }

    public static List<Bought_Loyalty_Product__c> getBoughtLoyaltyProduct(List<Loyalty_Product__c> products, Contact contact, Boolean doInsert) {

        List<Bought_Loyalty_Product__c> boughtProducts = new List<Bought_Loyalty_Product__c>();

        for (Loyalty_Product__c product : products) {

            Bought_Loyalty_Product__c newBought = new Bought_Loyalty_Product__c(
                Contact__c = contact.Id, 
                Loyalty_Product__c = product.Id
            );

            boughtProducts.add(newBought);
        }

        if(doInsert) {
            insert boughtProducts;
        }

        return [
            SELECT Id, Loyalty_Product__c, 
                Loyalty_Product__r.Price_Currency__c, 
                Loyalty_Product__r.Price_Points__c 
            FROM Bought_Loyalty_Product__c 
            WHERE Id IN :boughtProducts
        ];
    }

    public static List<Loyalty_Order__c> getLoyaltyOrder(List<Bought_Loyalty_Product__c> boughtProducts, Datetime purchaseDate, Boolean doInsert) {

        Decimal totalCurrency = 0;
        Decimal totalPoints = 0;

        for (Bought_Loyalty_Product__c product : boughtProducts) {

            if (product.Loyalty_Product__r.Price_Currency__c != null) {
                totalCurrency += product.Loyalty_Product__r.Price_Currency__c;
            }

            if (product.Loyalty_Product__r.Price_Points__c != null) {
                totalPoints += product.Loyalty_Product__r.Price_Points__c;
            }
        }

        List<Loyalty_Order__c> boughtOrders = new List<Loyalty_Order__c>();

        Loyalty_Order__c mainOrder = new Loyalty_Order__c(
            Purchase_Date__c = purchaseDate, 
            Code_Used__c = false, 
            Description__c = 'Test Order',
            Total_Currency__c = totalCurrency,
            Total_Points__c = totalPoints
        );
        insert mainOrder;

        for (Integer i = 0; i < boughtProducts.size(); i++) {

            Loyalty_Order__c newOrder = new Loyalty_Order__c(
                Bought_Loyalty_Product__c = boughtProducts[i].Id, 
                Loyalty_Order__c = mainOrder.Id
            );

            boughtOrders.add(newOrder);
        }

        if(doInsert) {
            insert boughtOrders;
        }

        return boughtOrders;
    }

    public static Account getAccount(String name, Boolean doInsert) {
        Account a = new Account(name = name);
        if(doInsert) {
            insert a;
        }
        return a;
    }
    
    public static Contact getContact(Id accountId, String fname, String lname, Boolean doInsert) {
        Contact c = new Contact(firstName = fname, lastName = lname, accountId = accountId);

        if(doInsert) {
            insert c;
        }

        return c;
    }

    public static List<Contact> getContact(String fistName, String lastName, Integer numberToCreate, Boolean doInsert) {

        List<Contact> contacts = new List<Contact>();
        
        for(Integer i = 0; i < numberToCreate; i++){
            contacts.add(new Contact(firstName = fistName + i, lastName = lastName));
        }

        if(doInsert) {
            insert contacts;
        }

        return contacts;
    }

    public static List<Contact> getContact(String fistName, String lastName, String cardNumber, Integer numberToCreate, Boolean doInsert) {

        List<Contact> contacts = new List<Contact>();
        
        for(Integer i = 0; i < numberToCreate; i++){
            contacts.add(new Contact(firstName = fistName + i, lastName = lastName, Card_Number__c = cardNumber + i));
        }

        if(doInsert) {
            insert contacts;
        }

        return contacts;
    }

    public static List<Contact> getContact(String fistName, String lastName, String email, Decimal points, Integer numberToCreate, Boolean doInsert) {

        List<Contact> contacts = new List<Contact>();
        
        for(Integer i = 0; i < numberToCreate; i++){
            contacts.add(new Contact(firstName = fistName + i, lastName = lastName, Email = email, Points__c = points));
        }

        if(doInsert) {
            insert contacts;
        }

        return contacts;
    }

    public static List<Contact> getContact(String fistName, String lastName, String email, Decimal points, Integer numberToCreate, Id accountId, Boolean doInsert) {

        List<Contact> contacts = new List<Contact>();
        
        for(Integer i = 0; i < numberToCreate; i++){
            contacts.add(new Contact(firstName = fistName + i, lastName = lastName, Email = email, Points__c = points, AccountId = accountId));
        }

        if(doInsert) {
            insert contacts;
        }

        return contacts;
    }
    
    public static void generateAccountWithContacts(Integer numContacts) {
        
        Account a = getAccount('default account ltd', true);
        List<Contact> contacts = new List<Contact>();
        
        for(Integer i = 0; i < numContacts; i++) {
            String contactName = 'contact' + i;
            contacts.add(getContact(a.id, contactName, contactName, false));
        }
        
        insert contacts;
    }
    
    public static Opportunity[] generateOppsForAccount(
        id accountId,
        Decimal amount,
        Integer numOpps
    ) {
        List<Opportunity> opps = new List<Opportunity>();
        
        for(Integer i = 0; i < numOpps; i++) {
            Opportunity o = new Opportunity();
            o.name = 'Account ' + i;
            o.accountId = accountid;
            o.amount = amount;
            o.closeDate = Date.today().addDays(5);
            o.stageName = 'Prospecting';
            opps.add(o);
        }
        return opps;
    }
    
    public static User getUser(Id contactId) {
        
        User user = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Customer Community User'].Id,
            LastName = 'last',
            IsActive = true,
            Email = 'Cpt.Awesome@awesomesauce.com',
            Username = 'Cpt.Awesome.' + DateTime.now().getTime() + '@awesomesauce.com',
            CompanyName = 'Testing Co',
            Title = 'Captian',
            Alias = 'alias',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ContactId = contactId
        );
        
        insert user;
        
        return user;
    }

    public static User getAdminUser(String lastName, Boolean doInsert) {
        
        UserRole ownerRole = new UserRole(
            DeveloperName = 'InternalManager',
            Name = 'Internal Manager'
        );
        insert ownerRole;

        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User user = new User(
            ProfileId = adminProfile.Id,
            IsActive = true,
            UserRoleId = ownerRole.Id,
            LastName = lastName,
            Email = 'owner@testorg.com',
            Username = 'owner.' + DateTime.now().getTime() + '@testorg.com',
            Alias = 'owner',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US'
        );
        
        if (doInsert) {
            insert user;
        }
        
        return user;
    }
    
    public static List<Lead> getLead(String lastName, String company, Integer numberToCreate, Boolean doInsert) {
        
        List<Lead> leads = new List<Lead>();
        
        for(Integer i = 0; i < numberToCreate; i++){
            leads.add(new Lead(LastName = lastName + i, Company = company));
        }
        
        if(doInsert) {
            insert leads;
        }

        return leads;
    }

    public static List<Task> getTask(String status, Id whoId, Integer numberToCreate, Boolean doInsert) {
        
        List<Task> tasks = new List<Task>();
            
        for(Integer i = 0; i < numberToCreate; i++) {
            tasks.add(new Task(Status = status, WhoId = whoId));
        }
            
        if(doInsert) {
            insert tasks;
        }

        return tasks;
    }

    public static List<Case> getCase(String subject, Id contactId, Integer numberToCreate, Boolean doInsert) {
        
        List<Case> cases = new List<Case>();

        for(Integer i = 0; i < numberToCreate; i++) {
            cases.add(new Case(Subject = subject, ContactId = contactId));
        }

        if(doInsert) {
            insert cases;
        }

        return cases;
    }

    public static List<Case> getCase(String status, Boolean archived, Id ownerId, Integer numberToCreate, Boolean doInsert) {
        
        List<Case> cases = new List<Case>();

        for(Integer i = 0; i < numberToCreate; i++) {
            cases.add(new Case(Status = status, Archived__c = archived, OwnerId = ownerId));
        }

        if(doInsert) {
            insert cases;
        }

        return cases;
    }

    public static List<Group> getQueue(String name, Integer numberToCreate, Boolean doInsert) {
        
        List<Group> queues = new List<Group>();

        for(Integer i = 0; i < numberToCreate; i++) {
            queues.add(new Group(Name = name, Type = 'Queue'));
        }

        if(doInsert) {
            insert queues;
        }

        return queues;
    }

    public static List<QueueSObject> getQueueSObject(String sObjectType, Id queueId, Integer numberToCreate, Boolean doInsert) {
        
        List<QueueSObject> sObjects = new List<QueueSObject>();

        for(Integer i = 0; i < numberToCreate; i++) {
            sObjects.add(new QueueSObject(SobjectType = sObjectType, QueueId = queueId));
        }

        if(doInsert) {
            insert sObjects;
        }

        return sObjects;
    }

    public static EmailTemplate getEmailTemplate(String developerName, Boolean doInsert) {
        
        EmailTemplate template = new EmailTemplate(
            DeveloperName = developerName,
            Name = developerName + ' name',
            TemplateType = 'text',
            FolderId = UserInfo.getUserId(),
            IsActive = true
        );

        if(doInsert) {
            insert template;
        }

        return template;
    }

    public static PermissionSet getPermissionSet(String name, Boolean doInsert) {
        
        PermissionSet permissionSet = new PermissionSet(
            Name = name, 
            Label = name + ' label'
        );

        if(doInsert) {
            insert permissionSet;
        }

        return permissionSet;
    }

    public static SetupEntityAccess getSetupEntityAccess(Id permSetId, String targetClassName, Boolean doInsert) {
        
        ApexClass targetClass = [SELECT Id FROM ApexClass WHERE Name = :targetClassName LIMIT 1];

        SetupEntityAccess setupEntity = new SetupEntityAccess(
            ParentId = permSetId,
            SetupEntityId = targetClass.Id
        );

        if(doInsert) {
            insert setupEntity;
        }

        return setupEntity;
    }

    public static PermissionSetAssignment getPermissionSetAssignment(Id assigneeId, Id permSetId, Boolean doInsert) {
        
        PermissionSetAssignment permAssign = new PermissionSetAssignment(
            AssigneeId = assigneeId,
            PermissionSetId = permSetId
        );

        if(doInsert) {
            insert permAssign;
        }

        return permAssign;
    }
}