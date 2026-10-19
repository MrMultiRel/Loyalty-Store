public with sharing class PDFReceiptController {

    public List<Loyalty_Order__c> childOrders { get; private set; }
    public Decimal total { get; private set; }
    public Decimal pointsGained { get; private set; }

    public PDFReceiptController() {

        String orderId = ApexPages.currentPage().getParameters().get('orderId');
        this.total = 0.0;
        this.pointsGained = 0.0;
        Boolean isCode = false;
        
        if (orderId != null) {

            List<Loyalty_Order__c> mainOrder = [SELECT Code_Used__c FROM Loyalty_Order__c WHERE Id = :orderId];

            if(mainOrder.size() > 0){
                isCode = mainOrder[0].Code_Used__c;
            }
            
            this.childOrders = [
                SELECT Id, Bought_Loyalty_Product__r.Loyalty_Product__r.Name, Bought_Loyalty_Product__r.Loyalty_Product__r.Price_Currency__c
                FROM Loyalty_Order__c 
                WHERE Loyalty_Order__c = :orderId 
                AND Bought_Loyalty_Product__r.Loyalty_Product__r.Price_Currency__c != null
            ];

            for (Loyalty_Order__c order : this.childOrders) {
                this.total += order.Bought_Loyalty_Product__r.Loyalty_Product__r.Price_Currency__c;
            }

            if (isCode) {
                this.pointsGained = total * 0.5;
            }
            else{
                this.pointsGained = total * 0.1;
            }

        } 
        else {
            this.childOrders = new List<Loyalty_Order__c>();
        }
    }
}