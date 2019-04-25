# LinkedSets

Experimental. Do not use. 

[https://github.com/rob-Hitchens/LinkedSets](https://github.com/rob-Hitchens/LinkedSets)
Uses: [https://github.com/rob-Hitchens/UnorderedKeySet](https://github.com/rob-Hitchens/UnorderedKeySet)

Solidity Library that implements the [Solidity CRUD pattern](https://medium.com/@robhitchens/solidity-crud-part-1-824ffa69509a) with relational integrity.

## Design Philosophy

The library concentrates on primary and foreign keys only in keeping with a minimalist approach to on-chain storage. Additional properties of each set are beyond the scope of the library, by design. Dapps can use any combination of on-chain and off-chain storage to store such properties.

The library attends to key-related concerns only and reverts on referential integrity violations. Doing so relieves implementation contracts of routine concerns. 

## Three Entities Example

The `ThreeLinkedSets.sol` example binds a master set to transactions with line items - three related sets in total. Properties of each type and random access are set up using familiar mapped structs. 

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

Primary keys and foreign keys are not included in the structs, by design. They should be handled by the library.

Sets the contract will use are described in the constructor.  

    constructor() public {
        
        // Create three sets
        keys.createSet(CUSTOMER);
        keys.createSet(INVOICE);
        keys.createSet(LINEITEM);
    }

The above named variables are a matter of style. Nothing special is going on and any unique `bytes32` identifier will suffice:

    bytes32 constant public CUSTOMER = keccak256(abi.encodePacked("Customers"));
    bytes32 constant public INVOICE = keccak256(abi.encodePacked("Invoices"));
    bytes32 constant public LINEITEM = keccak256(abi.encodePacked("Line Items"));
    
In the simplest function, a new customer is added to the `CUSTOMER` set with the library ensuring primary key uniqueness. Since the library deals exclusively with `bytes32` keys (because they are the most flexible of the fixed-sized types) a simple conversion from `address` to `bytes32` is performed. `name` is not a key (out of library scope), so it is stored in the mapped struct. 

    function createCustomer(address customer, string memory name) public {
        keys.insertKey(CUSTOMER, addressToBytes32(customer)); // table, key. Uniqueness is enforced.
        customers[customer].name = name; // struct properties
    }

Removal is straight-forward:

    function removeCustomer(address customer) public {
        keys.removeKey(CUSTOMER, addressToBytes32(customer)); // table, key.
        delete customers[customer];
    } 
    
The library ensures:

1. The key to remove actually exists in the set. Reverts if it doesn't. 
2. Removing the key will not create an orphan foreign key in another set, e.g. an Invoice. If any record in any joined set refers to the key to delete then the library reverts to safeguard referential integrity. 

Similar referential integrity checks are enforced during inserts. 

## Create a Join

Join a set to another set. This also goes in the constructor or initialization function. 

        // Invoices have a foreign key to customers
        keys.joinSets(INVOICE, CUSTOMER);
        
        // Line items have a foreign key to invoices
        keys.joinSets(LINEITEM, INVOICE);

## Join Records (Set a foreign key)

Foreign keys are in scope. The library stores their values. To set the value of a foreign key, indicate the table, the record, the other set and the record in the other set (which must exist). 

        keys.insertForeignKey(LINEITEM, lineItemId, INVOICE, invoiceId);
        
In practice a typical insert operation consists of gathering all the fields of an instance of a set, and:

1. Insert the primary key.
2. Insert foreign keys.
3. Store the remaining fields, if any, by any practical method. 

For example, the example `createInvoice` function:

1. Generates a primary key (invoice number).
2. Inserts the primary key into the INVOICES set.
3. Inserts the customer address as a foreign key (with type conversion to `bytes32`).
4. Stores the arbitrary `comments` that are outside of the `LinkedSets` scope in a mapped struct. 

    function createInvoice(address customer, string memory comments) public returns(bytes32 invoiceID) {
        INVOICE_COUNTER++;
        invoiceID = bytes32(INVOICE_COUNTER);  
        keys.insertKey(INVOICE, invoiceID);
        keys.insertForeignKey(CUSTOMER, addressToBytes32(customer), INVOICE, invoiceID);
        invoices[invoiceID].comments = comments;
    }

It will be possible to delete the invoice provided no line items have been attached. 

## 0-to-Many 

The enforced referential integrity is always zero to many. Other cardinality rules should be enforced by implementing contracts. An example would be a rule that an invoice should always have a minimum of one line item. This would be easily done with an insert process than ensures it is always so. Similarly, it may not be sensible to allow an Invoice delete function under any circumstances. It is included merely to demonstrate that deletes are easily coded and referential integrity will not be violated be deletes. 

## Logical Deletes

While it is true that blockchain data is immutable, there are frequently cases when a logical delete from a set is required. For example, a set of subscribers where the subscribers are transient. 

## Scale Invariant

The operations in this pattern produce consistent gas cost *at any scale*. 

## Methods from HitchensUnorderedKeySetLib

This library makes extensive use of `HitchensUnorderedKeySetsLib`. These unordered key sets are used for storing the sets that exist, the keys in the sets, the joins between the sets, the foreign keys and the referencing records (incoming links) for each key in each set. 

Each such set presents methods to count members, enumerate members and check existence. Although it is technically feasible to directly insert and remove members, doing so directly risks breaking referential integrity. Indeed, this wrapper exists to ensure that all necessary checks and maintenance are performed so that doing so will not break referential integrity. 

It is perfectly safe to read such properties:
```
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
function invoiceLineItemAtIndex(bytes32 invoiceId, uint index) public view returns(bytes32) {
    return keys.linkedSets[INVOICE].referencingRecords[invoiceId][LINEITEM].keyAtIndex(index);
}
```    

## Example Implementation

There are two minimal examples to show how to use the library. 

`HitchensLinkedKeySets.sol` contains a minimal contract that exposes the library functions. 
`ThreeLinkedSets.sol` implements the customer => invoice => line items example. 

Both contracts can be loaded in Remix for quick experimentation. 

## Tests

NO TESTING OF ANY KIND HAS BEEN PERFORMED AND YOU USE THIS LIBRARY AT YOUR OWN EXCLUSIVE RISK.

## Contributors

Optimization and clean-up is ongoing.

The author welcomes pull requests, feature requests, testing assistance and feedback. Contact the author if you would like assistance with customization or calibrating the code for a specific application or gathering of different statistics.
License

## License

Copyright (c), 2019 Rob Hitchens. The MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Hope it helps.
