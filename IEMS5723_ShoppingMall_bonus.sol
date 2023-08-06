// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;
 
contract shoppingMall {
    //define the variables,we need following: buyer,seller,product info,transaction info
    //we define a specify address for seller to simplify the process
    //it is the same to use my_seller.addr in line 48 as well, but it is a bit complicated since we use it many times for functions
    address payable selladdr;
    //this is the address of contract, we use it as middle transport to store the ether
    //if do not want others to know the address of middle transport, we can set it private,but I think this does not real make sense since you can just use 'this' to get it
    address payable mid_addr = payable(address(this));
    //the price is xx ether rather than wei, so we need a basic_price,you can change it to wei or other if you want, but ether is much more obvious in testing
    uint256 public basic_price = 1 ether;
    struct buyer{
        string name;
        string email;
        string shipping_address;
        uint [] transaction_id; //we store the transaction id from this addr, use index to visit their own transaction
    }
    struct seller{
        string name;
        address payable addr;//this is the address in blockchain,it is different from the shipping address
        bool seller_in;//the flag to show if there is already a seller
    }
    struct product_info{
        uint id;
        string name;
        uint price;
        uint quantity;
    }
    struct transaction_once{
        address buyer_address;//buyer address
        uint score;//this is for the score
        uint id;//this is product id, not transaction
        uint number;//product number
        uint256 pay_money;//how much do they pay for this transaction,we do not store price since you can infer it from the pay_money or see it in store
        bool complete;
        bool return_request;//whether buyer ask for a return
        bool return_allow;//whether seller allow the return
    }

    //buyer and transaction we use a mapping , address -> info to differ
    //so we can just use the msg.sender to directly get personal info rather than scanning all, we donot use mapping for seller since there is only one
    mapping (address => buyer) private buyer_map;
    seller public my_seller;
    //we cannot use null to see if an address is used or not, so we just use another mapping to check,we use one list for both the buyer and seller
    mapping (address=>bool) public register_list;
    //test register address array,use to show all the address including the seller
    address [] public register_arr;
    //using map because the product id may not be continuous when testing
    mapping (uint=>product_info) public product_map;
    //we use a simple array to list transaction. we do not want the buyer to see all, so we need private
    transaction_once [] private transaction_array;

    //event for the four function to give signal, they are for transactions,it is for future use
    event EventTransactionInitiation(address buyer_addr,uint transaction_id);
    event EventReturnRequest(uint transaction_id);
    event EventAllowReturnRequest(uint transaction_id);
    event EventTransactionCompleted(uint transaction_id);

    //a new buyer register, cannot be a seller or a registered buyer
    //type your string, this can be empty when I am testing, but I think it is ok if your address is valid,you are just harmimg yourself if you do not typing this, because you still need to pay ether for transactions
    function BuyerRegistration(string memory my_name, string memory my_email,string memory my_shipping_address) public payable {
        require(!register_list[msg.sender],"you have already registered, change you msg-sender address!");
        buyer memory new_buyer = buyer(my_name,my_email,my_shipping_address,new uint[](0));
        buyer_map[payable(msg.sender)] = new_buyer;
        register_list[msg.sender] = true;
        register_arr.push(msg.sender);
    }

    //we allow a register buyer to change name/email/shippingaddr, we donot allow modifying the stored id of transactions
    function BuyerProfileUpdate(string memory new_name, string memory new_email,string memory new_shipping_address) public payable{
        require(register_list[msg.sender],"you have not registered, register first!");
        require(msg.sender!=selladdr,"the seller can not change his profile");
        buyer storage temp_buyer = buyer_map[msg.sender];
        temp_buyer.name = new_name;
        temp_buyer.email = new_email;
        temp_buyer.shipping_address = new_shipping_address;
    }

    //the seller register, only the first one with 1 ether msg.value can be a seller
    //the seller_in should be empty, and the seller cannot be buyer(it is used to flag whether there is a seller)
    //you only need to specify your string name, empty is also allowed
    function SellerRegistration(string memory name) public payable{
        require(!register_list[msg.sender],"You have already registered, change you msg-sender address.");
        require(!my_seller.seller_in,"There is already a seller registered and only one seller is allowed");
        require(msg.value >= 1 ether, "You need to pay at least 1 ether to be the seller");
        my_seller.name = name;
        my_seller.addr = payable(msg.sender);
        my_seller.seller_in = true;
        register_list[msg.sender] = true;
        register_arr.push(msg.sender);
        selladdr = payable(msg.sender);
    }
    //this is for personal donation to maintain its balance, we do not refuse other address, even the unregistered one can put money in it
    //but in my view, only the seller and his zombie account has the motion the put ether in the contract to maintain this shop in real world
    function Donate()public payable{
        require(msg.value >= 1 ether, "At least donate 1 ether");
    }
    //the punish function for future use, we directly transfer the ether in contract to your specified address
    //it seems we donot need to check if punish_money > this.balance since it will just fail when this happens
    //now we have 2 senarios to punish seller:
    //[1]whenever a user set score = 0 to his transaction,to simplify we do not limit the times, each reset score 0 will punish him
    //[2]when the price of product is too high
    function PunishSeller(address payable give_punish_address,uint256 punish_money) private {
        //require(my_seller.seller_in==true,"cannot punish an empty seller");
        uint256 real_punish_money = punish_money * basic_price;
        // uint256 temp_sell_balance = selladdr.balance;
        give_punish_address.transfer(real_punish_money);
    }

    //function for seller to put on a product
    function PutOnProduct(uint id,string memory name,uint price,uint quantity) public{
        //we simpilify the model by not allowing the seller to directly add the amount, if the seller want to put on a product, all info of the original one is simply covered
        //it seems not fair to buyer, so you can add a line to require the seller only change the info when the quantity is 0, but this seems unfair to seller again
        //only the seller can put product on shopping mall
        require(msg.sender==my_seller.addr);
        product_info memory new_product = product_info(id,name,price,quantity);
        product_map[new_product.id] = new_product;
        //we punish the seller if the price is too high
        if(new_product.price > 20){
            PunishSeller(selladdr,1);
        }
    }

    //print product information, you need to specify the id of that product
    //I think it is OK to return an empty product_id, it will show all 0 and it does not affect real transaction
    function PrintProductInfomation(uint product_id) public view returns (product_info memory){
        return product_map[product_id];
    }

    //initiate a transaction, simply making an appointment for one product, just like shopping carts,but your ether will be transfered to the contract
    //seller need to have enough number of product, otherwise fail
    //buyer should be a valid buyer and have enough msg.value in ether, otherwise fail
    //after that the number of product decrease and the money is payed to the contract(rather than directly to seller)
    function TransactionInitiation(uint product_id,uint product_number) public payable{
        require(register_list[msg.sender]==true && msg.sender!=my_seller.addr,"invalid address");
        require(product_number<=product_map[product_id].quantity&&product_number>0,"buy too many or 0, can not initiate");
        require(uint256(product_map[product_id].price)*uint256(product_number)*basic_price<=uint256(msg.value),"you do not have enough money");
        //put the transaction into the mapping
        //the pay money is in ether since we use ether as our basic price, the default score of a transaction is 5
        transaction_once memory new_transaction = transaction_once(msg.sender,5,product_id,product_number,uint256(msg.value)/basic_price,false,false,false);
        uint new_id = transaction_array.length;
        buyer_map[msg.sender].transaction_id.push(new_id);
        transaction_array.push(new_transaction);
        //delete the number of product from the shopping mall
        product_map[product_id].quantity = product_map[product_id].quantity - product_number;
        emit EventTransactionInitiation(msg.sender,new_id);       
    }
    
    //buyer ask for a return, the input transaction id is according to the index of buyer_map array rather than value
    //for example, suppose the transaction_id array in buyer_map is [17,19,21]
    //you should input 0,1,2 to change you transaction rather than 17,19,21
    //we do the mapping in the function, since when you print transaction we do not tell your id, you can only see real id when print you personal information
    //it is a bit weired, but I believe it is the best way to make use convenient 
    function ReturnRequestMyId(uint my_transaction_id) public payable{
        uint real_transaction_id = buyer_map[msg.sender].transaction_id[my_transaction_id];
        transaction_once storage temp_trans = transaction_array[real_transaction_id];
        //the transaction should be valid
        require(temp_trans.number>0,"there is no such transaction to ask for return");
        require(temp_trans.complete==false,"this transaction is compplete,can not be changed");
        require(temp_trans.return_request==false,"you have already asked for a return");
        require(temp_trans.buyer_address==msg.sender,"you can not ask for a return for others");
        //send the return
        temp_trans.return_request = true;
        emit EventReturnRequest(real_transaction_id);
    }

    //only seller can allow return, the seller will see the real transaction id
    function AllowReturnRequest(uint transaction_id) public payable{
        require(msg.sender==selladdr,"only the seller can approve return");
        transaction_once storage temp_trans = transaction_array[transaction_id];
        //the transaction should be valid
        require(temp_trans.number>0,"there is no such transaction to ask for return");
        require(temp_trans.complete==false,"this transaction is compplete,can not be changed");
        require(temp_trans.return_request==true,"you can not allow return if not request");
        require(temp_trans.return_allow==false,"you can not allow return multiple times");
        //send the return and change the flag
        temp_trans.return_allow = true;
        address payable return_target_adrr = payable(temp_trans.buyer_address);
        return_target_adrr.transfer(transaction_array[transaction_id].pay_money*basic_price);
        emit EventAllowReturnRequest(transaction_id);
    }

    //this is for buyer to confirm their transactions, the input is the same as ReturnRequestMyId in line 166
    //for example, suppose the transaction_id array in buyer_map is [17,19,21]
    //you should input 0,1,2 to confirm you transaction rather than 17,19,21
    //you input transacation id rather than the real id, we do the mapping in the function
    function TransactionCompletion(uint my_transaction_id) public payable{
        //change the input id into real id in array
        uint real_transaction_id = buyer_map[msg.sender].transaction_id[my_transaction_id];
        transaction_once storage temp_trans = transaction_array[real_transaction_id];
        //the transaction should be valid
        require(temp_trans.number>0,"there is no such transaction to pay");
        require(temp_trans.complete==false,"this transaction is already paid");
        require(temp_trans.buyer_address==msg.sender,"only the buyer can complete his transaction");
        //if seller allow a return,he cannot get the pay
        if(!temp_trans.return_allow){
            selladdr.transfer(temp_trans.pay_money*basic_price);
        }
        temp_trans.complete = true;
        emit EventTransactionCompleted(real_transaction_id);
    }

    //change the score of a transaction, still using array index
    //it is weird since you can use it to punish seller endlessly using this, but I really donot want to store the times of score in transaction to make it too complex
    //In my view, the score should be changed at anytime but the punish should only be allowed to activated once, but I do not come up with a simple way to do it without adding new variables
    function ChangeScore(uint my_transaction_id,uint my_score) public payable{
        uint real_transaction_id = buyer_map[msg.sender].transaction_id[my_transaction_id];
        transaction_once storage temp_trans = transaction_array[real_transaction_id];
        //the score must be their own transaction and should not be completed, we donot want to see continous changing of a transaction when it is over
        require(temp_trans.buyer_address==msg.sender,"only the buyer can change the score");
        require(temp_trans.complete==false,"the transaction is completed");
        if(my_score <= 5){
            temp_trans.score = my_score;
        }
        else{
            //if it is larger than 5, we assmue it is 5
            temp_trans.score = 5;
        }
        if(temp_trans.score==0){
            PunishSeller(payable(msg.sender),1); //move ether from contract to the buyer as a compensation
        }
    }
    //print transaction info
    function PrintTransaction()public view returns (transaction_once[] memory){
        //for selller it is just all the array
        if(msg.sender==selladdr){
            return transaction_array;
        }
        else{
            transaction_once [] memory res = new transaction_once[](buyer_map[msg.sender].transaction_id.length);
            for(uint i = 0;i < buyer_map[msg.sender].transaction_id.length;i++){
                res[i] = transaction_array[buyer_map[msg.sender].transaction_id[i]];
            }
            return res;
            //the res index is from 0->buyer_map[msg.sender].transaction_id.length - 1, we do not tell you the real id of your transaction in a contract 
        }
    }

    //the user can see personal struct information through this function:name,email,shipping address,real transaction id list in contract
    //actually I donot want to let users see real transaction id, but returning a simple struct is easy
    function PrintPersonalInfo() public view returns(buyer memory){
        require(register_list[msg.sender]==true && msg.sender!=selladdr,"you should register first");
        return buyer_map[msg.sender];
    }
    
    // //test function
    // //you donot need to include it in real use
    // function getBalance() public view returns (uint256) {
    //     return address(msg.sender).balance;
    // }
    // function getThisBalance() public view returns(uint256){
    //     return address(this).balance;
    // }
    // function putOnProduct_test() public {
    //     require(msg.sender==my_seller.addr);
    //     product_info memory new_product = product_info(0,'a',1,30);
    //     product_map[0] = new_product;
    // }
}