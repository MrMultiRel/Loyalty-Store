import { api, LightningElement, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { refreshApex } from '@salesforce/apex';
import Toast from 'lightning/toast';
import getProducts from '@salesforce/apex/ProductService.getProducts';
import insertCart from '@salesforce/apex/ProductService.insertCart';

import USER_ID from '@salesforce/user/Id';
import POINTS_FIELD from '@salesforce/schema/User.Contact.Points__c';
import CONTACT_ID from '@salesforce/schema/User.ContactId';

import IMAGES from '@salesforce/resourceUrl/images';

import { LABEL } from 'c/labelsComponent'; 

export default class ProductCard extends LightningElement {

    @api
    isMainProduct;
    cartItems = [];
    searchInput = '';
    isSortAsc = false;
    userId = USER_ID;
    error;

    products =[];
    contact;

    currentPage = 1;
    pageSize = 9;

    label = LABEL;

    connectedCallback() {

        let isSort;

        if (this.isMainProduct) {
            isSort = localStorage.getItem('mainSort');
        }
        else {
            isSort = localStorage.getItem('pointSort');
        }

        if (isSort) {
            this.isSortAsc = JSON.parse(isSort);
        }

        refreshApex(this.contact);
    }

    @wire(getRecord, {
        recordId: '$userId',
        fields: [POINTS_FIELD, CONTACT_ID]
    })
    wiredContact(result) {
        this.contact = result;
        this.loadProducts();
    };

    async loadProducts() {
        const data = await getProducts({ isMain: this.isMainProduct, contactId: this.contactId });

        if(data){
            this.products = data.map(product => {
                return {
                    ...product,
                    imageURL: `${IMAGES}/${product.Name}.jpg`
                }
            });

            this.handleSort();
        }
    }

    async handleAdd(event) {
        const productId = event.target.dataset.id;
        const productName = event.target.dataset.name;

        await insertCart({ productId: productId, contactId: this.contactId });

        Toast.show(
            {
                label: this.label.success,
                message: `${productName} ${this.label.addedCart}`,
                variant: 'success'
            },
            this,
        );
    }

    get isProductsEmpty() {
        return this.products && this.products.length === 0;
    }

    get contactPoints() {
        const value = getFieldValue(this.contact.data, POINTS_FIELD);
        return this.label.pointsAmount.replace('{0}', value);
    }

    get contactId() {
        return getFieldValue(this.contact.data, CONTACT_ID);
    }

    get filteredProducts() {

        this.searchInput = this.searchInput.trim();

        if (this.searchInput === '') {
            return this.products;
        }

        return this.products.filter(item => item.Name.toLowerCase().includes(this.searchInput.toLowerCase()));
    }

    get pagedProducts() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = this.currentPage * this.pageSize;
        return this.filteredProducts.slice(start, end);
    }

    get totalPages() {
        return Math.ceil(this.filteredProducts.length / this.pageSize) || 1;
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get isPaginated() {
        return this.products && this.totalPages > 1;
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

    handleChange(event) {
        this.searchInput = event.target.value;
        this.currentPage = 1;
    }

    handleSort() {

        if (this.isMainProduct) {

            if (this.isSortAsc) {
                this.products = [...this.products].sort((a, b) => b.Price_Currency__c - a.Price_Currency__c);
                this.isSortAsc = false;
            }
            else {
                this.products = [...this.products].sort((a, b) => a.Price_Currency__c - b.Price_Currency__c);
                this.isSortAsc = true;
            }

            localStorage.setItem('mainSort', JSON.stringify(!this.isSortAsc));
        }
        else {

            if (this.isSortAsc) {
                this.products = [...this.products].sort((a, b) => b.Price_Points__c - a.Price_Points__c);
                this.isSortAsc = false;
            }
            else {
                this.products = [...this.products].sort((a, b) => a.Price_Points__c - b.Price_Points__c);
                this.isSortAsc = true;
            }

            localStorage.setItem('pointSort', JSON.stringify(!this.isSortAsc));
        }
    }
}