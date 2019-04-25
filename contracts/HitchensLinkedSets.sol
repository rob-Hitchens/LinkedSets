pragma solidity 0.5.1;

import "./HitchensUnorderedKeySet.sol";

interface LinkedSetsInterface {
    function createSet(bytes32 set) external;  
    function joinSets(bytes32 set, bytes32 foreignSet) external;
    function insertPrimaryKey(bytes32 set, bytes32 key) external;
    function removePrimaryKey(bytes32 set, bytes32 key) external;
    function insertForeignKey(bytes32 set, bytes32 key, bytes32 foreignSet, bytes32 foreignKey) external;
    function removeForeignKey(bytes32 set, bytes32 key, bytes32 foreignSet) external; 
    function foreignKey(bytes32 set, bytes32 primaryKey, bytes32 foreignSet) external view returns(bytes32);
}

library HitchensLinkedKeySetsLib {
    
    using HitchensUnorderedKeySetLib for HitchensUnorderedKeySetLib.Set;
    
    bytes32 private constant UNDEFINED = 0x0;
    
    struct LinkedSets {
        HitchensUnorderedKeySetLib.Set linkedSetIds;
        mapping(bytes32 => LinkedSet) linkedSets;
    }
    struct LinkedSet {
        // this set of keys
        HitchensUnorderedKeySetLib.Set set;
        // sets with foreign keys that refer to this set
        HitchensUnorderedKeySetLib.Set referencingSets;
        // sets to which foreign keys in this set refer
        HitchensUnorderedKeySetLib.Set foreignSets;
        // foreign keys in referencing sets that refer to primary keys in this set
        // foreignSet => (localkey => foreignSet PrimaryKeys)
        mapping(bytes32 => mapping(bytes32 => HitchensUnorderedKeySetLib.Set)) referencingRecords;
        // records in this set and their their foreign keys
        // localKey => (foreignSet => foreignKey)
        mapping(bytes32 => mapping(bytes32 => bytes32)) foreignKeys;
    }
    /**
     * @notice Create a new key set. Must not exist.
     * @param self LinkedSets struct.
     * @param set setId.
     */
    function createSet(LinkedSets storage self, bytes32 set) internal {
        self.linkedSetIds.insert(set);
    }
    /**
     * @notice join two sets. Must not exist.
     * @param self LinkedSets struct.
     * @param set setId. This set will contain a foreign key that references a key in the other set. 
     * @param foreignSet setId. This set will contain keys that are referenced by foreign keys in the other set. 
     */
    function joinSets(LinkedSets storage self, bytes32 set, bytes32 foreignSet) internal {
        LinkedSet storage s = self.linkedSets[set];
        LinkedSet storage f = self.linkedSets[foreignSet];
        require(self.linkedSetIds.exists(set), "LinkedSets(101) - Primary set does not exist.");        
        require(self.linkedSetIds.exists(foreignSet), "LinkedSets(102) - Foreign set does not exist.");
        f.referencingSets.insert(set);        
        s.foreignSets.insert(foreignSet);
    } 
    /**
     * @notice Insert a key into a set. Must not exist.
     * @param self LinkedSets struct.
     * @param set setId. The key will be inserted into this set.
     * @param primaryKey The key to insert.
     */
    function insertKey(LinkedSets storage self, bytes32 set, bytes32 primaryKey) internal {
        LinkedSet storage s = self.linkedSets[set];
        require(self.linkedSetIds.exists(set), "LinkedSets(201) - Primary set does not exist."); 
        s.set.insert(primaryKey);
    }
    /**
     * @notice Remove a key from a set. Must not be a foreign key for any other record in any other set. 
     * @param self LinkedSets struct.
     * @param set setId. The set from which remove a key.
     * @param primaryKey The key to remove.
     */
    function removeKey(LinkedSets storage self, bytes32 set, bytes32 primaryKey) internal {
        LinkedSet storage s = self.linkedSets[set];
        require(self.linkedSetIds.exists(set), "LinkedSets(301) - Primary set does not exist.");
        uint referencingSetsCount = s.referencingSets.count();
        for(uint i=0; i<referencingSetsCount; i++) {
            require(s.referencingRecords[s.referencingSets.keyAtIndex(i)][primaryKey].count() == 0, "LinkedSets(302) - Key is referenced by foreign set record.");
        }
        s.set.remove(primaryKey);
    }
    /**
     * @notice Insert a foreign key. Must not exist. 
     * @param self LinkedSets struct.
     * @param set setId. The set with a record that will receive a foreign key. 
     * @param primaryKey The primary key for the record that will receive a foreign key. 
     * @param foreignSet setId. The set that contains a primary key equal to the foreign key.
     * @param foreignKey The value of the foreign key. The foreignKey must exist in the foreign set.
     */
    function insertForeignKey(LinkedSets storage self, bytes32 set, bytes32 primaryKey, bytes32 foreignSet, bytes32 foreignKey) internal {
        LinkedSet storage s = self.linkedSets[set];
        LinkedSet storage f = self.linkedSets[foreignSet];
        require(self.linkedSetIds.exists(set), "LinkedSets(401) - Primary set does not exist.");
        require(s.foreignKeys[primaryKey][foreignSet] == UNDEFINED, "LinkedSets(402) - Foreign key already set in primary set record.");
        require(s.foreignSets.exists(foreignSet), "LinkedSets(403) - Foreign set does not exist.");
        require(f.set.exists(foreignKey), "LinkedSets(404) - Foreign key does not exist in foreign set.");
        s.foreignKeys[primaryKey][foreignSet] = foreignKey;
        f.referencingRecords[set][foreignKey].insert(primaryKey);
    }
    /**
     * @notice Remove a foreignKey. Must exist.
     * @param self LinkedSets struct.
     * @param set The set that contains the primary key. 
     * @param primaryKey The key that has the foreign key to remove. 
     * @param foreignSet The set to which the foreign key to remove refers. 
     */
    function removeForeignKey(LinkedSets storage self, bytes32 set, bytes32 primaryKey, bytes32 foreignSet) internal {
        LinkedSet storage s = self.linkedSets[set];
        LinkedSet storage f = self.linkedSets[foreignSet];
        require(self.linkedSetIds.exists(set), "LinkedSets(501) - Primary set does not exist."); 
        require(s.foreignSets.exists(foreignSet), "LinkedSets(502) - Foreign set is not joined to primary set.");
        bytes32 _foreignKey = s.foreignKeys[primaryKey][foreignSet];
        f.referencingRecords[set][_foreignKey].remove(primaryKey);
        s.foreignKeys[primaryKey][foreignSet] = UNDEFINED;
    }
    /**
     * @notice Update a foreign key. Must exist. 
     * @param self LinkedSet struct.
     * @param set The set id that contains the primary key. 
     * @param foreignSet The set to which the foreign key to change refers. 
     * @param foreignKey The new value of the foreign key.
     * @dev Referential integrity is maintained by removing the old foreign key and adding the new one. 
     */
    function updateForeignKey(LinkedSets storage self, bytes32 set, bytes32 primaryKey, bytes32 foreignSet, bytes32 foreignKey) internal {
        removeForeignKey(self, set, primaryKey, foreignSet);
        insertForeignKey(self, set, primaryKey, foreignSet, foreignKey);
    }
    /**
     * @notice Get a foreign key. If foreign key is not explicitly set, returns 0x0. Primary key and set must exist. 
     * @param self LinkedSets struct. 
     * @param set setId. The set that contains the primary key to inspect. 
     * @param primaryKey The primary key with an associated foreignKey. 
     * @param foreignSet The set to which the foreignKey refers. If not set, returns 0x0.
     * @dev Foreign set should be explicitly joined with joinSets to permit inserts. Returns 0x0 without error if this is not the case. 
     */
    function foreignKey(LinkedSets storage self, bytes32 set, bytes32 primaryKey, bytes32 foreignSet) internal view returns(bytes32) {
        LinkedSet storage s = self.linkedSets[set];
        require(self.linkedSetIds.exists(set), "LinkedSets(601) - Primary set does not exist.");
        require(s.set.exists(primaryKey), "LinkedSets(602) - Primary key does not exist.");
        return s.foreignKeys[primaryKey][foreignSet];
    }
}

contract LinkedSets is LinkedSetsInterface {
    
    using HitchensLinkedKeySetsLib for HitchensLinkedKeySetsLib.LinkedSets;
    HitchensLinkedKeySetsLib.LinkedSets linkedSets;
    
    event LogCreateSet(address sender, bytes32 set);
    event LogJoinSets(address sender, bytes32 set, bytes32 foreignSet);
    event LogInsertKey(address sender, bytes32 set, bytes32 key);
    event LogRemoveKey(address sender, bytes32 set, bytes32 key);
    event LogInsertForeignKey(address sender, bytes32 set, bytes32 key, bytes32 foreignSet, bytes32 foreignKey);
    event LogRemoveForeignKey(address sender, bytes32 set, bytes32 key, bytes32 foreignSet);
    event LogUpdateForeignKey(address sender, bytes32 set, bytes32 keym, bytes32 foreignSet, bytes32 foreignKey);
    
    function createSet(bytes32 set) public {
        linkedSets.createSet(set);
        emit LogCreateSet(msg.sender, set);
    }
    function joinSets(bytes32 set, bytes32 foreignSet) public {
        linkedSets.joinSets(set, foreignSet);
        emit LogJoinSets(msg.sender, set, foreignSet);
    }
    function insertKey(bytes32 set, bytes32 key) public {
        linkedSets.insertKey(set, key);
        emit LogInsertKey(msg.sender, set, key);
    }
    function removeKey(bytes32 set, bytes32 key) public {
        linkedSets.removeKey(set, key);
        emit LogRemoveKey(msg.sender, set, key);
    }
    function insertForeignKey(bytes32 set, bytes32 key, bytes32 foreignSet, bytes32 foreignKey) public {
        linkedSets.insertForeignKey(set, key, foreignSet, foreignKey);
        emit LogInsertForeignKey(msg.sender, set, key, foreignSet, foreignKey);
    }
    function removeForeignKey(bytes32 set, bytes32 key, bytes32 foreignSet) public {
        linkedSets.removeForeignKey(set, key, foreignSet);
        emit LogRemoveForeignKey(msg.sender, set, key, foreignSet);
    }
    function updateForeignKey(bytes32 set, bytes32 key, bytes32 foreignSet, bytes32 foreignKey) public {
        linkedSets.updateForeignKey(set, key, foreignSet, foreignKey);
        emit LogUpdateForeignKey(msg.sender, set, key, foreignSet, foreignKey);
    }
    function foreignKey(bytes32 set, bytes32 key, bytes32 foreignSet) public view returns(bytes32) {
        return linkedSets.foreignKey(set, key, foreignSet);
    }
}
