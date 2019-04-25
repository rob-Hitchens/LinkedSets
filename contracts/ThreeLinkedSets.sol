pragma solidity 0.5.1;

/**
 * This is a contrived example for testing purposes only. 
 * Three sets are joined with 0,n cardinality and full CRUD capability. 
 * Access control and events are set aside for brevity. 
 * Business logic concerns pertaining to invoices are set aside to
 * syntax patterns, readability and the utility of the library itself.
 */

import "./HitchensLinkedKeySets.sol";
import "./ConvertUtils.sol";

contract ThreeLinkedSets is ConvertUtils {
    
    using HitchensLinkedKeySetsLib for HitchensLinkedKeySetsLib.LinkedSets;
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
    HitchensLinkedKeySetsLib.LinkedSets keys;
    
    bytes32 constant public CUSTOMER = keccak256(abi.encodePacked("Customers"));
    bytes32 constant public INVOICE = keccak256(abi.encodePacked("Invoices"));
    bytes32 constant public LINEITEM = keccak256(abi.encodePacked("Line Items"));
    uint public INVOICE_COUNTER;
    
    struct Customer {
        // customer ID is is key
        string name;
        uint orderHistoryTotal;
    }
    mapping(address => Customer) public customers;
    
    struct Invoice {
        // Invoice ID is a key
        // Customer ID is a foreign key
        string comments;
    }
    mapping(bytes32 => Invoice) public invoices;
    
    struct LineItem {
        // Line item ID is a key
        // Invoice ID is a foreign key
        string description;
        uint extendedPrice;
    }
    mapping(bytes32 => LineItem) public lineItems;
    
    /**
     * @dev Constructor lays out a schema with key sets and joins. Joins enforce 0,n referential integrity.
     */
    constructor() public {
        
        // Create three sets
        keys.createSet(CUSTOMER);
        keys.createSet(INVOICE);
        keys.createSet(LINEITEM);
        
        // Invoices have a foreign key to customers
        keys.joinSets(INVOICE, CUSTOMER);
        
        // Line items have a foreign key to invoices
        keys.joinSets(LINEITEM, INVOICE);
    }
    
    function createCustomer(address customer, string memory name) public {
        keys.insertKey(CUSTOMER, addressToBytes32(customer));
        customers[customer].name = name;
    }
    function createInvoice(address customer, string memory comments) public returns(bytes32 invoiceID) {
        INVOICE_COUNTER++;
        invoiceID = bytes32(INVOICE_COUNTER);  
        keys.insertKey(INVOICE, invoiceID);
        keys.insertForeignKey(CUSTOMER, addressToBytes32(customer), INVOICE, invoiceID);
        invoices[invoiceID].comments = comments;
    }
    function createInvoiceLineItem(bytes32 invoiceId, string memory description, uint extendedPrice) public returns(bytes32 _lineItemId) {
        uint lineItemCount = keys.linkedSets[INVOICE].referencingRecords[LINEITEM][invoiceId].count();
        bytes32 lineItemId = bytes32(lineItemCount+1);
        keys.insertKey(LINEITEM, lineItemId);
        keys.insertForeignKey(LINEITEM, lineItemId, INVOICE, invoiceId);
        lineItems[lineItemId].description = description;
        lineItems[lineItemId].extendedPrice = extendedPrice;
        return lineItemId;
    }
    function removeCustomer(address customer) public {
        keys.removeKey(CUSTOMER, addressToBytes32(customer));
        delete customers[customer];
    } 
    function removeInvoice(bytes32 invoiceId) public {
        keys.removeKey(INVOICE, invoiceId);
        delete invoices[invoiceId];
    }
    function removeLineItem(bytes32 lineItemId) public {
        keys.removeKey(LINEITEM, lineItemId);
        delete lineItems[lineItemId];
    }
    function customerCount() public view returns(uint) { return keys.linkedSets[CUSTOMER].set.count(); }
    function invoiceCount() public view returns(uint) { return keys.linkedSets[INVOICE].set.count(); }
    function lineItemCount() public view returns(uint) { return keys.linkedSets[LINEITEM].set.count(); }
    function customerInvoiceCount(address customer) public view returns(uint) { return keys.linkedSets[CUSTOMER].referencingRecords[addressToBytes32(customer)][INVOICE].count(); }
    function invoiceLineItemCount(bytes32 invoiceId) public view returns(uint) { return keys.linkedSets[INVOICE].referencingRecords[invoiceId][LINEITEM].count(); }
    
    function customerAtIndex(uint index) public view returns(address) { return bytes32ToAddress(keys.linkedSets[CUSTOMER].set.keyAtIndex(index)); }
    function invoiceAtIndex(uint index) public view returns(bytes32) { return keys.linkedSets[INVOICE].set.keyAtIndex(index); }
    function lineItemAtIndex(uint index) public view returns(bytes32) { return keys.linkedSets[LINEITEM].set.keyAtIndex(index); }
    function customerInvoiceAtIndex(address customer, uint index) public view returns(bytes32) {
        return keys.linkedSets[CUSTOMER].referencingRecords[addressToBytes32(customer)][INVOICE].keyAtIndex(index);
    }
    function lineItemAtIndex(bytes32 invoiceId, uint index) public view returns(bytes32) {
        return keys.linkedSets[INVOICE].referencingRecords[invoiceId][LINEITEM].keyAtIndex(index);
    }
}
