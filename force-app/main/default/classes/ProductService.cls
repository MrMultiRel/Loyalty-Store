public without sharing class ProductService {
    
    @AuraEnabled
    public static List<Loyalty_Product__c> getProducts(Boolean isMain, Id contactId) {
        
        try {
            if(isMain){
                return [SELECT Id, Name, Price_Currency__c, Price_Points__c, Parent_Product__c 
                    FROM Loyalty_Product__c 
                    WHERE Parent_Product__c = NULL ];
            }
            else{
                return [SELECT Id, Name, Price_Currency__c, Price_Points__c, Parent_Product__c 
                    FROM Loyalty_Product__c 
                    WHERE Parent_Product__c IN 
                    (
                        SELECT Loyalty_Product__c
                        FROM Loyalty_Cart__c
                        WHERE Contact__c = :contactId
                    ) 
                ];
            }
        }
        catch (Exception e){
            throw new AuraHandledException('Unable to get products: ' + e.getMessage());
        }

    }

    @AuraEnabled
    public static void updatePoints(Id contactId, Decimal points) {

        if (contactId == null || points == null) {
            throw new AuraHandledException('Contact ID or points was not provided');
        }

        try{
            Contact newContact = new Contact(Id = contactId, Points__c = points);
            update newContact;
        }
        catch (Exception e){
            throw new AuraHandledException('Unable to update points: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Bought_Loyalty_Product__c> insertBought(Id contactId, List<Id> productIds) {

        if (contactId == null || productIds == null) {
            throw new AuraHandledException('Contact Id or list of Product Ids was not provided');
        }

        try{
            List<Bought_Loyalty_Product__c> boughtProducts = new List<Bought_Loyalty_Product__c>();

            for (Id prodId : productIds) {

                Bought_Loyalty_Product__c newBought = new Bought_Loyalty_Product__c(
                    Contact__c = contactId, 
                    Loyalty_Product__c = prodId
                );

                boughtProducts.add(newBought);
            }

            insert boughtProducts;

            return [
                SELECT Id, Loyalty_Product__c, 
                    Loyalty_Product__r.Price_Currency__c, 
                    Loyalty_Product__r.Price_Points__c 
                FROM Bought_Loyalty_Product__c 
                WHERE Id IN :boughtProducts
            ];
        }
        catch(Exception e){
            throw new AuraHandledException('Unable to insert bought products: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id insertOrder(List<Bought_Loyalty_Product__c> boughtProducts, Boolean isCode) {

        if (boughtProducts == null) {
            throw new AuraHandledException('List of bought products was not provided');
        }

        Decimal totalCurrency = 0;
        Decimal totalPoints = 0;

        try{
            
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
                Purchase_Date__c = Datetime.now(), 
                Code_Used__c = isCode, 
                Description__c = System.Label.BoughtLoyalty,
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

            insert boughtOrders;

            return mainOrder.Id;

        }
        catch(Exception e){
            throw new AuraHandledException('Unable to order: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void sendMail(Id contactId, List<String> pointNames) {

        if (contactId == null || pointNames == null) {
            throw new AuraHandledException('Contact Id or list of names of products was not provided');
        }

        try{

            Contact targetContact = [SELECT Email FROM Contact WHERE Id = :contactId];
            List<Loyalty_Product__c> products = [SELECT Name, Price_Points__c FROM Loyalty_Product__c WHERE Name IN :pointNames];
            Decimal total = 0;
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { targetContact.Email });
            mail.setSubject(System.Label.PointsPurchase);

            String emailBody = System.Label.ShoppingThank + '\n\n';
            emailBody += System.Label.BoughtProducts + ':\n';
            
            for (Loyalty_Product__c product : products) {
                emailBody += '- ' + product.Name + '\n';
                emailBody += ' - ' + System.Label.Price + ' ' + product.Price_Points__c + ' ' + System.Label.Points + '\n\n';
                total += product.Price_Points__c;
            }
            
            emailBody +=  System.Label.TotalPoints + ': ' + total + '\n';

            mail.setPlainTextBody(emailBody);

            List<OrgWideEmailAddress> orgEmail = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'mrmultirel@gmail.com' LIMIT 1];
            if (!orgEmail.isEmpty()) {
                mail.setOrgWideEmailAddressId(orgEmail[0].Id);
            }

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });

        }
        catch(Exception e){
            throw new AuraHandledException('Unable to send e-mail: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String sendOrdersMail() {
        try {
            
            Id currentUserId = UserInfo.getUserId();
            User currentUser = [SELECT ContactId, Email FROM User WHERE Id = :currentUserId LIMIT 1];
            
            EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Monthly_Loyalty_Purchase_Template' LIMIT 1];
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(template.Id);
            mail.setTargetObjectId(currentUser.ContactId);
            mail.setWhatId(currentUser.ContactId);
            mail.setSaveAsActivity(false);
            List<OrgWideEmailAddress> orgEmail = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'mrmultirel@gmail.com' LIMIT 1];

            if (!orgEmail.isEmpty()) {
                mail.setOrgWideEmailAddressId(orgEmail[0].Id);
            }

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
            return currentUser.Email;
        } catch(Exception e) {
            throw new AuraHandledException('Unable to send e-mail: ' + e.getMessage());
        }
    }


    @AuraEnabled(cacheable=true)
    public static List<Loyalty_Order__c> getOrders(Id contactId) {

        try{

            List<Loyalty_Order__c> childOrders = [
                SELECT Loyalty_Order__c 
                FROM Loyalty_Order__c 
                WHERE Bought_Loyalty_Product__r.Contact__c = :contactId 
                AND Loyalty_Order__c != null
            ];

            Set<Id> mainIds = new Set<Id>();
            for (Loyalty_Order__c child : childOrders) {
                mainIds.add(child.Loyalty_Order__c);
            }

            return [
                SELECT Id, Name, Purchase_Date__c, Total_Currency__c, Total_Points__c, Description__c,
                (
                    SELECT Id, Bought_Loyalty_Product__r.Loyalty_Product__r.Name 
                    FROM Loyalty_Orders__r
                )
                FROM Loyalty_Order__c
                WHERE Id IN :mainIds
                ORDER BY Purchase_Date__c DESC
            ];

        }
        catch(Exception e){
            throw new AuraHandledException('Unable to get orders: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void insertCart(Id productId, Id contactId) {

        if (productId == null || contactId == null) {
            throw new AuraHandledException('Product ID or Contact ID was not provided');
        }

        try{

            List<Loyalty_Cart__c> existingItems = [
                SELECT Id, Quantity__c 
                FROM Loyalty_Cart__c 
                WHERE Contact__c = :contactId AND Loyalty_Product__c = :productId
                LIMIT 1
            ];

            if (!existingItems.isEmpty()) {

                Loyalty_Cart__c existingItem = existingItems[0];
                existingItem.Quantity__c = ++existingItem.Quantity__c;
                update existingItem;

            } else {
                
                Loyalty_Cart__c newCart = new Loyalty_Cart__c(
                    Contact__c = contactId,
                    Loyalty_Product__c = productId,
                    Quantity__c = 1
                );

                insert newCart;
            }

        }
        catch(Exception e){
            throw new AuraHandledException('Unable to insert cart: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static List<Loyalty_Cart__c> getCart(Id contactId) {

        try{

            return [SELECT Loyalty_Product__c, Quantity__c, Loyalty_Product__r.Name,
                           Loyalty_Product__r.Price_Currency__c,
                           Loyalty_Product__r.Price_Points__c
                    FROM   Loyalty_Cart__c 
                    WHERE  Contact__c = :contactId
            ];

        }
        catch(Exception e){
            throw new AuraHandledException('Unable to get cart: ' + e.getMessage());
        }

    }

    @AuraEnabled
    public static void deleteCart(Id contactId) {

        try {
        
            List<Loyalty_Cart__c> cartItems = [
                SELECT Id 
                FROM Loyalty_Cart__c 
                WHERE Contact__c = :contactId
            ];

            delete(cartItems);

        }
        catch (Exception E) {
            throw new AuraHandledException('Unable to delete cart: ' + e.getMessage());
        }

    }

     @AuraEnabled
    public static void updateCart(Id id, Integer quantity) {

        if (id == null || quantity == null) {
            throw new AuraHandledException('Cart Item ID or quantity was not provided');
        }

        try {

            Loyalty_Cart__c cartItem = new Loyalty_Cart__c(Id = id, Quantity__c = quantity);

            if(quantity <= 0){
                delete(cartItem);
            }
            else{
                update(cartItem);
            }

        }
        catch (Exception e) {
            throw new AuraHandledException('Unable to update cart: ' + e.getMessage());
        }

    }

}