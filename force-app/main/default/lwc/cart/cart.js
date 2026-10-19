import { LightningElement, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import Toast from 'lightning/toast';
import LightningConfirm from "lightning/confirm";
import LightningPrompt from 'lightning/prompt';
import updatePoints from '@salesforce/apex/ProductService.updatePoints';
import insertBought from '@salesforce/apex/ProductService.insertBought';
import insertOrder from '@salesforce/apex/ProductService.insertOrder';
import sendMail from '@salesforce/apex/ProductService.sendMail';
import getCart from '@salesforce/apex/ProductService.getCart';
import deleteCart from '@salesforce/apex/ProductService.deleteCart';
import updateCart from '@salesforce/apex/ProductService.updateCart';

import USER_ID from '@salesforce/user/Id';
import POINTS_FIELD from '@salesforce/schema/User.Contact.Points__c';
import CONTACT_ID from '@salesforce/schema/User.ContactId';

import IMAGES from '@salesforce/resourceUrl/images';

import { LABEL } from 'c/labelsComponent'; 

export default class Cart extends LightningElement {

    @track
    cartItems = [];
    totalCurrency;
    totalPoints;
    userId = USER_ID;
    contact;
    isCode = false;

    label = LABEL;

    @wire(getRecord, {
        recordId: '$userId',
        fields: [POINTS_FIELD, CONTACT_ID]
    })
    wiredContact(result) {
        this.contact = result;
        this.loadCart();
    }

    async loadCart() {

        const data = await getCart({ contactId: this.contactId });

        this.cartItems = data.map(item => {

            const product = item.Loyalty_Product__r;
            let isMain = false;
            let price = 0;
            const quantity = Number(item.Quantity__c);

            if(product.Price_Currency__c !== undefined && product.Price_Currency__c !== null){
                isMain = true;
                price = product.Price_Currency__c;
            }
            else{
                isMain = false;
                price = product.Price_Points__c;
            }

            return {
                id: item.Id,
                productId: product.Id,
                productName: product.Name,
                imageURL: `${IMAGES}/${product.Name}.jpg`,
                isMain: isMain,
                price: price,
                quantity: quantity,
                totalPrice: Number(price) * Number(quantity)
            }
        });

        this.calculateTotals();
    }

    async handleClear(event) {

        const isConfirmed = await LightningConfirm.open({
            message: this.label.clearCart,
            label: this.label.cart,
            theme: "error"
        });

        if (isConfirmed) {
            this.clearCart();

            Toast.show(
                {
                    label: this.label.success,
                    message: this.label.clearedCart,
                    variant: 'success'
                },
                this,
            );
        }

        this.calculateTotals();
    }

    get isCartNotEmpty() {
        return this.cartItems.length > 0;
    }

    async clearCart() {
        this.cartItems = [];
        await deleteCart({contactId: this.contactId});
    }

    async handleChange(event) {

        let changedItem = this.cartItems.find(item => item.productName === event.target.dataset.name);
        let operation = event.target.dataset.operation;

        if (operation === 'decrease') {

            if (changedItem.quantity === 1) {
                this.cartItems.splice(this.cartItems.indexOf(changedItem), 1);
            }
            else {
                changedItem.totalPrice = Number(changedItem.totalPrice) - Number(changedItem.price);
            }

            changedItem.quantity--;
        }
        else {
            changedItem.quantity++;
            changedItem.totalPrice = Number(changedItem.totalPrice) + Number(changedItem.price);
        }

        Toast.show(
            {
                label: this.label.cart,
                message: `${this.label.changedQuantity} ${changedItem.productName}`,
                variant: 'info',
                mode: 'dismissible'
            },
            this,
        );

        await updateCart({id: changedItem.id, quantity: changedItem.quantity});
        this.calculateTotals();
    }

    calculateTotals() {

        this.totalCurrency = 0;
        this.totalPoints = 0;

        this.cartItems.forEach(item => {

            if (item.isMain) {
                this.totalCurrency = Number(this.totalCurrency) + Number(item.totalPrice);
            }
            else {
                this.totalPoints = Number(this.totalPoints) + Number(item.totalPrice);
            }

        })
    }

    get contactPoints() {
        const value = getFieldValue(this.contact.data, POINTS_FIELD);
        return this.label.pointsAmount.replace('{0}', value);
    }

    get contactId() {
        return getFieldValue(this.contact.data, CONTACT_ID);
    }

    async handlePurchase() {

        let contactPoints = getFieldValue(this.contact.data, POINTS_FIELD);
        let pointNames = [];
        let currencyPurchase = false;

        const productIds = [];
        this.cartItems.forEach(item => {

            for (let i = 0; i < item.quantity; i++) {
                productIds.push(item.productId);

                if (!item.isMain) {
                    pointNames.push(item.productName);
                }
            }

        });

        if (this.totalPoints > contactPoints) {
            Toast.show(
                {
                    label: this.label.failure,
                    message: this.label.notPoints,
                    variant: 'error'
                },
                this,
            );
            return;
        }

        if (this.totalCurrency > 0) {

            let code = "";
            currencyPurchase = true;

            const isConfirmed = await LightningConfirm.open({
                message: this.label.codeInput,
                label: this.label.purchase,
                variant: "headerless"
            });

            if (isConfirmed) {

                code = await LightningPrompt.open({
                    message: this.label.codeEnter,
                    label: this.label.code,
                    variant: "headerless"
                });

            }

            contactPoints = this.purchaseCurrency(contactPoints, code);
        }

        if (this.totalPoints > 0) {
            contactPoints = Number(contactPoints) - Number(this.totalPoints);
        }

        localStorage.setItem('historyRefresh', 'true');
        await updatePoints({ contactId: this.contactId, points: contactPoints });
        const boughtProducts = await insertBought({ contactId: this.contactId, productIds: productIds });
        const orderId = await insertOrder({boughtProducts:boughtProducts, isCode: this.isCode});

        if(pointNames){
            await sendMail({contactId: this.contactId, pointNames: pointNames});
        }

        await this.clearCart();
        await refreshApex(this.contact);

        Toast.show(
            {
                label: this.label.success,
                message: this.label.thankYou,
                variant: 'success'
            },
            this,
        );

        if (currencyPurchase) {
            const currentHost = window.location.hostname;
            const orgName = currentHost.split('.')[0];
            const pdfUrl = `https://${orgName}--c.develop.vf.force.com/apex/purchaseReceipt?orderId=${orderId}`;
            window.open(pdfUrl, '_blank');
        }
    }

    purchaseCurrency(contactPoints, code) {

        if (code === "MORE") {
            contactPoints = Number(contactPoints) + Number(this.totalCurrency * 0.5);
            this.isCode = true;
        }
        else {
            contactPoints = Number(contactPoints) + Number(this.totalCurrency * 0.1);
        }

        return contactPoints;
    }
}