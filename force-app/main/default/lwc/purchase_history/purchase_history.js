import { LightningElement, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import Toast from 'lightning/toast';

import getOrders from '@salesforce/apex/ProductService.getOrders';
import sendOrdersMail from '@salesforce/apex/ProductService.sendOrdersMail'; 

import USER_ID from '@salesforce/user/Id';
import CONTACT_ID from '@salesforce/schema/User.ContactId';

import { LABEL } from 'c/labelsComponent'; 

export default class Purchase_history extends LightningElement {

    userId = USER_ID;
    orders;
    wiredOrderResult;
    contactId;
    error;

    currentPage = 1;
    pageSize = 8;

    isSending = false;

    label = LABEL;

    @wire(getRecord, {
        recordId: '$userId',
        fields: [CONTACT_ID]
    })
    wiredUser({ error, data }) {
        if (data) {
            this.contactId = getFieldValue(data, CONTACT_ID);
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.contactId = undefined;
        }
    }

    @wire(getOrders, { contactId: '$contactId' })
    wiredOrder(result) {
        this.wiredOrderResult = result;

        if (result.data) {
            this.error = undefined;

            const historyRefresh = localStorage.getItem('historyRefresh');

            if (historyRefresh === 'true') {
                localStorage.removeItem('historyRefresh');
                refreshApex(this.wiredBoughtResult);
            }

            this.orders = result.data.map(order => {
                const dateOptions = {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                };
                return {
                    id: order.Id,
                    purchaseDate: new Date(order.Purchase_Date__c).toLocaleString('en-US', dateOptions),
                    totalCurrency: order.Total_Currency__c,
                    totalPoints: order.Total_Points__c,
                    items: order.Loyalty_Orders__r.map(item => ({
                        id: item.Id,
                        productName: item.Bought_Loyalty_Product__r.Loyalty_Product__r.Name
                    }))
                };
            });

        } else if (result.error) {
            this.error = result.error;
            this.orders = undefined;
        }
    }

    async handleSendOrder() {

        this.isSending = true;

        const userEmail = await sendOrdersMail();

        Toast.show(
            {
                label: this.label.success,
                message: `${this.label.sentTo} ${userEmail}`,
                variant: 'success'
            },
            this,
        );

        this.isSending = false;
    }

    get isHistoryEmpty() {
        return this.orders && this.orders.length === 0;
    }

    get pagedOrders() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = this.currentPage * this.pageSize;
        return this.orders.slice(start, end);
    }

    get totalPages() {
        return Math.ceil(this.orders.length / this.pageSize) || 1;
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get isPaginated() {
        return this.orders && this.totalPages > 1;
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }
}