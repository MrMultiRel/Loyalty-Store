@isTest
private class PDFReceiptControllerTest {

    @testSetup
    static void setupData() {
        
        Contact contact = TestFactory.getContact('Tester', 'Testerson', 'testuser@example.com', 100, 1, true)[0];
        List<Loyalty_Product__c> mainProducts = TestFactory.getMainProduct(3, true);
        List<Bought_Loyalty_Product__c> boughtProducts = TestFactory.getBoughtLoyaltyProduct(mainProducts, contact, true);
        TestFactory.getLoyaltyOrder(boughtProducts, Datetime.now(), true);
    }

    @isTest
    static void testControllerWithOrderId() {
        
        PageReference testPage = Page.purchaseReceipt;
        Test.setCurrentPage(testPage);

        Loyalty_Order__c mainOrder = [SELECT Id, Code_Used__c FROM Loyalty_Order__c WHERE Loyalty_Order__c = null LIMIT 1][0];
        mainOrder.Code_Used__c = true;
        update mainOrder;
        
        ApexPages.currentPage().getParameters().put('orderId', mainOrder.Id);

        Test.startTest();
        PDFReceiptController controller = new PDFReceiptController();
        Test.stopTest();

        Assert.areEqual(3, controller.childOrders.size(), 'Expected 3');
        Assert.areEqual(300, controller.total, 'Expected 300');
        Assert.areEqual(150, controller.pointsGained, 'Expected 150');
    }

    @isTest
    static void testControllerWithoutOrderId() {
        
        PageReference testPage = Page.purchaseReceipt;
        Test.setCurrentPage(testPage);

        Test.startTest();
        PDFReceiptController controller = new PDFReceiptController();
        Test.stopTest();

        Assert.areEqual(0, controller.childOrders.size(), 'Expected 0');
    }

    @isTest
    static void testControllerWithoutCode() {
        
        PageReference testPage = Page.purchaseReceipt;
        Test.setCurrentPage(testPage);

        Id orderId = [SELECT Id FROM Loyalty_Order__c WHERE Loyalty_Order__c = null LIMIT 1][0].Id;
        
        ApexPages.currentPage().getParameters().put('orderId', orderId);

        Test.startTest();
        PDFReceiptController controller = new PDFReceiptController();
        Test.stopTest();

        Assert.areEqual(3, controller.childOrders.size(), 'Expected 3');
        Assert.areEqual(300, controller.total, 'Expected 300');
        Assert.areEqual(30, controller.pointsGained, 'Expected 30');
    }
}
