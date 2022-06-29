pragma solidity >=0.8.0 <0.9.0;

//Copyright of DataX Protocol contributors
// SPDX-License-Identifier: BSU-1.1

contract Admin {
    address public admin;
    address public pendingAdmin;

    constructor() {
        admin = msg.sender;
    }

    modifier adminOnly() {
        require(msg.sender == admin, "admin only");
        _;
    }

    /*********************/
    /****    Admin   *****/
    /*********************/

    /**
     * Request a new admin to be set for the contract.
     *
     * @param newAdmin New admin address
     */
    function setPendingAdmin(address newAdmin) public adminOnly {
        pendingAdmin = newAdmin;
    }

    /**
     * Accept admin transfer from the current admin to the new.
     */
    function acceptPendingAdmin() public {
        require(
            msg.sender == pendingAdmin && pendingAdmin != address(0),
            "Caller must be the pending admin"
        );

        admin = pendingAdmin;
        pendingAdmin = address(0);
    }
}
