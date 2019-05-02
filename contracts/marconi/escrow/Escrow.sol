pragma solidity ^0.5.0;

/*
** This Smart Contract represents a Escrow service between a buyer and a seller.
** Buyer deposits fund into the Escrow contract, and the fund is paid out only if both the buyer and seller have agreed that conditons were met.
**
** Note, this is only a POC contract. What the conditions are and whether the conditions have been met are on the onus of buyer and seller here.
**
** Things we can add in the future:
**   - Allow buyer and seller to specify payment conditions upon creation of the Escrow.
**   - Accept 3rd party input data and use it to check whether payment conditions have been met.
**   - Allow payment to be made over a pre-specified time interval.
**   - Allow payment to be made in percentages upon conditions being met.
**   - Set a timeout period where funds are returned to buyer if conditions have not been met.
**
*/
contract Escrow {

    address payable public buyer;
    address payable public seller;

    bool buyerAccept = false;
    bool sellerAccept = false;
    bool buyerCancel = false;
    bool sellerCancel = false;

    event BalanceDeposited(uint256 amount);
    event BalancePaid(uint256 amount);

    /**
     * Set the initial state of the Escrow.
     *
     * @param buyerAddress address of the buyer
     * @param sellerAddress address of the seller
     */
    constructor (address payable buyerAddress, address payable sellerAddress) public {
        buyer = buyerAddress;
        seller = sellerAddress;
    }

    /**
     * Allow buyer and seller to accept. Buyer and seller should ideally accept only if the goods/services have been delivered/carried out.
     * When both buyer and seller have accepted, payment is made to the seller.
     */
    function accept() public {
        if (msg.sender == buyer) {
            buyerAccept = true;
        } else if (msg.sender == seller) {
            sellerAccept = true;
        }

        // pay out the balance if both buyer and seller accepts
        if (buyerAccept && sellerAccept) {
            payBalance();
        }
    }

    /**
     * Sends seller the balance in the Escrow account.
     */
    function payBalance() private {
        uint256 _currentBalance = address(this).balance;
        address(seller).transfer(_currentBalance);

        emit BalancePaid(_currentBalance);

        // remove contract from block-chain state.
        selfdestruct(buyer);
    }

    /**
     * Allow buyer to deposit fund into the Escrow account.
     */
    function deposit() public payable {
        require(msg.sender == buyer);
        emit BalanceDeposited(msg.value);
    }

    /**
     * Allow buyer or seller to cancel the escrow contract and issue a refund.
     */
    function cancel() public {
        if (msg.sender == buyer) {
            buyerCancel = true;
        } else if (msg.sender == seller) {
            sellerCancel = true;
        }

        // return fund to buyer if both buyer and seller cancels
        if (buyerCancel && sellerCancel) {
            // remove contract from block-chain state, remaining fund will be returned to buyer.
            selfdestruct(buyer);
        }
    }

}