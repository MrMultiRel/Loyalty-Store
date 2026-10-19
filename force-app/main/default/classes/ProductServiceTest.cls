@IsTest
public with sharing class ProductServiceTest {

    @TestSetup
    static void setupData(){

        User accountOwner = TestFactory.getAdminUser('Owner', true);
        Contact contact;

        System.runAs(accountOwner) {
            Account account = TestFactory.getAccount('Test Account', true);
            contact = TestFactory.getContact('Tester', 'Testerson', 'testuser@example.com', 100, 1, account.Id, true)[0];
            List<Loyalty_Product__c> mainProducts = TestFactory.getMainProduct(3, true);
            TestFactory.getLoyaltyCart(mainProducts, contact, true);
            TestFactory.getPointsProduct(mainProducts, true);
        }

        System.runAs(new User(Id = UserInfo.getUserId())){
            User user = TestFactory.getUser(contact.Id);
            PermissionSet permSet = TestFactory.getPermissionSet('controllerPermSet', true);
            TestFactory.getSetupEntityAccess(permSet.Id, 'MonthlyPurchaseController', true);
            TestFactory.getPermissionSetAssignment(user.Id, permSet.Id, true);
        }
    }

    @isTest
    static void testGetProductsMain() {

        Id contactId = [SELECT Id FROM Contact LIMIT 1].Id;

        Test.startTest();
        List<Loyalty_Product__c> result = ProductService.getProducts(true, contactId);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Expected 3');
    }

    @isTest
    static void testGetProductsPoint() {

        Id contactId = [SELECT Id FROM Contact LIMIT 1].Id;

        Test.startTest();
        List<Loyalty_Product__c> result = ProductService.getProducts(false, contactId);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Expected 3');
    }

    @isTest
    static void testUpdatePoints() {

        Contact contact = [SELECT Id, Points__c FROM Contact LIMIT 1];
        Decimal newPoints = 250;

        Test.startTest();
        ProductService.updatePoints(contact.Id, newPoints);
        Test.stopTest();

        Contact updatedCon = [SELECT Points__c FROM Contact WHERE Id = :contact.Id];
        Assert.areEqual(newPoints, updatedCon.Points__c, 'Expected 250');
    }

    @isTest
    static void testUpdatePointsWithNull() {

        Test.startTest();

        try {
            ProductService.updatePoints(null, null);
            Assert.fail('Expected AuraHandledException');
        } 
        catch (Exception e) {
            Assert.isNotNull(e, 'Expected AuraHandledException');
        }

        Test.stopTest();
    }

    @isTest
    static void testInsertBought() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        List<Loyalty_Product__c> products = [SELECT Id, Name FROM Loyalty_Product__c];
        
        List<Id> productIds = new List<Id>();

        for (Loyalty_Product__c product : products) {
            productIds.add(product.Id);
        }

        Test.startTest();
        ProductService.insertBought(contact.Id, productIds);
        Test.stopTest();

        List<Bought_Loyalty_Product__c> boughtList = [SELECT Id FROM Bought_Loyalty_Product__c];
        Assert.areEqual(productIds.size(), boughtList.size(), 'Expected 6');
    }

    @isTest
    static void testInsertBoughtWithNull() {

        Test.startTest();
        try {
            ProductService.insertBought(null, null);
            Assert.fail('Expected AuraHandledException');
        } 
        catch (Exception e) {
            Assert.isNotNull(e, 'Expected AuraHandledException');
        }
        Test.stopTest();

    }

    @isTest
    static void testInsertOrder() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        List<Loyalty_Product__c> products = [SELECT Id, Name FROM Loyalty_Product__c];
        
        List<Bought_Loyalty_Product__c> boughtProducts = TestFactory.getBoughtLoyaltyProduct(products, contact, true);

        Test.startTest();
        ProductService.insertOrder(boughtProducts, true);
        Test.stopTest();

        List<Loyalty_Order__c> orders = [SELECT Id FROM Loyalty_Order__c];
        Assert.areEqual(boughtProducts.size() + 1, orders.size(), 'Expected 7');   
    }

    @isTest
    static void testInsertOrderWithNull() {

        Test.startTest();
        try {
            ProductService.insertOrder(null, null);
            Assert.fail('Expected AuraHandledException');
        } 
        catch (Exception e) {
            Assert.isNotNull(e, 'Expected AuraHandledException');
        }
        Test.stopTest();

    }

    @isTest
    static void testSendMail() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        List<Loyalty_Product__c> pointProducts = [SELECT Id, Name FROM Loyalty_Product__c WHERE Parent_Product__c != null];

        List<String> pointNames = new List<String>();

        for(Loyalty_Product__c product : pointProducts){
            pointNames.add(product.Name);
        }

        Test.startTest();
        ProductService.sendMail(contact.Id, pointNames);
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, emailInvocations, 'Expected 1');
    }

    @isTest
    static void testSendMailWithNull() {

        Test.startTest();
        try {
            ProductService.sendMail(null, null);
            Assert.fail('Expected AuraHandledException');
        } 
        catch (Exception e) {
            Assert.isNotNull(e, 'Expected AuraHandledException');
        }
        Test.stopTest();

    }

    @isTest
    static void testSendOrdersMail() {

        User user = [SELECT Id FROM User WHERE LastName='last'];
        String resultEmail;
        Integer emailInvocations = 0;

        Test.startTest();

        System.runAs(user) {
            resultEmail = ProductService.sendOrdersMail();
            emailInvocations = Limits.getEmailInvocations();
        }

        Test.stopTest();

        Assert.areEqual('cpt.awesome@awesomesauce.com', resultEmail, 'Expected "cpt.awesome@awesomesauce.com"');
        Assert.areEqual(1, emailInvocations, 'Expected 1');
    }

    @isTest
    static void testSendOrdersMailWithNull() {

        Test.startTest();

        try{
            ProductService.sendOrdersMail();
            Assert.fail('Expected AuraHandledException');
        }
        catch(Exception e){
            Assert.isNotNull(e, 'Expected AuraHandledException');
        }
        Test.stopTest();

    }
    
    @isTest
    static void testGetOrders() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        List<Loyalty_Product__c> products = [SELECT Id, Name FROM Loyalty_Product__c];
        
        List<Bought_Loyalty_Product__c> boughtProducts = TestFactory.getBoughtLoyaltyProduct(products, contact, true);
        TestFactory.getLoyaltyOrder(boughtProducts, Datetime.now(), true);

        Test.startTest();
        List<Loyalty_Order__c> result = ProductService.getOrders(contact.Id);
        Test.stopTest();

        Loyalty_Order__c mainOrder = result[0];
        List<Loyalty_Order__c> childOrders = mainOrder.Loyalty_Orders__r;

        Assert.areEqual(1, result.size(), 'Expected 1');
        Assert.areEqual(boughtProducts.size(), childOrders.size(), 'Expected 6');
    }

    @isTest
    static void testInsertCartNew() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        Loyalty_Product__c product = [SELECT Id, Name FROM Loyalty_Product__c WHERE Parent_Product__c != null LIMIT 1][0];

        Test.startTest();
        ProductService.insertCart(product.Id, contact.Id);
        Test.stopTest();

        List<Loyalty_Cart__c> cart = [SELECT Id, Quantity__c FROM Loyalty_Cart__c WHERE Contact__c = :contact.Id];

        Assert.areEqual(4, cart.size(), 'Expected 4');
        Assert.areEqual(1, cart[3].Quantity__c, 'Expected 1');
    }

    @isTest
    static void testInsertCartExisting() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];
        Loyalty_Product__c product = [SELECT Id, Name FROM Loyalty_Product__c LIMIT 1][0];

        Test.startTest();
        ProductService.insertCart(product.Id, contact.Id);
        Test.stopTest();

        List<Loyalty_Cart__c> cart = [SELECT Id, Quantity__c FROM Loyalty_Cart__c WHERE Contact__c = :contact.Id];

        Assert.areEqual(3, cart.size(), 'Expected 3');
        Assert.areEqual(2, cart[0].Quantity__c, 'Expected 2');
    }

    @isTest
    static void testInsertCartWithNull() {

        Test.startTest();
        try {
            ProductService.insertCart(null, null);
            Assert.fail('Expected AuraHandledException');
        } 
        catch (Exception e) {
            Assert.isNotNull(e, 'Expected AuraHandledException');
        }
        Test.stopTest();

    }

    @isTest
    static void testGetCart() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        List<Loyalty_Cart__c> result = ProductService.getCart(contact.Id);
        Test.stopTest();

        Assert.areEqual(3, result.size(), 'Expected 3');
    }

    @isTest
    static void testDeleteCart() {

        Contact contact = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        ProductService.deleteCart(contact.Id);
        Test.stopTest();

        List<Loyalty_Cart__c> cart = [SELECT Id, Quantity__c FROM Loyalty_Cart__c WHERE Contact__c = :contact.Id];
        Assert.areEqual(0, cart.size(), 'Expected 0');
    }

    @isTest
    static void testUpdateCart() {

        Loyalty_Cart__c cart = [SELECT Id, Quantity__c FROM Loyalty_Cart__c LIMIT 1][0];

        Test.startTest();
        ProductService.updateCart(cart.Id, 5);
        Test.stopTest();

        List<Loyalty_Cart__c> result = [SELECT Id, Quantity__c FROM Loyalty_Cart__c WHERE Id = :cart.Id LIMIT 1];
        Assert.areEqual(5, result[0].Quantity__c, 'Expected 5');
    }
    
    @isTest
    static void testUpdateCartZero() {

        Loyalty_Cart__c cart = [SELECT Id, Quantity__c FROM Loyalty_Cart__c LIMIT 1][0];

        Test.startTest();
        ProductService.updateCart(cart.Id, 0);
        Test.stopTest();

        List<Loyalty_Cart__c> result = [SELECT Id, Quantity__c FROM Loyalty_Cart__c WHERE Id = :cart.Id LIMIT 1];
        Assert.areEqual(0, result.size(), 'Expected 0');
    }

    @isTest
    static void testUpdateCartWithNull() {

        Test.startTest();
        try {
            ProductService.updateCart(null, null);
            Assert.fail('Expected AuraHandledException');
        } 
        catch (Exception e) {
            Assert.isNotNull(e, 'Expected AuraHandledException');
        }
        Test.stopTest();

    }
}