// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

contract BecomeHippiesDividend {
    
    struct Dividend {
        uint amount;
        bytes32 hash;
    }
    
    struct Funding {
        uint usd;
        bytes32 hash;
    }
    
    struct FundingRound {
        uint price;
        uint supply;
    }
    
    struct Sponsorship {
        address user;
        bool value;
    }
    
    mapping (address => bool) private _addresses;
    mapping (address => uint) private _balances;
    mapping (address => uint) private _dividends;
    mapping (address => Sponsorship) private _sponsorships;
    mapping (address => mapping (address => uint)) private _allowances;
    
    address[] private _beneficiaries;
    uint public dividend;
    Funding public funding;
    
    uint public totalSupply = 0;
    uint public decimals = 18;
    uint private _supplyDecimals = 10 ** decimals;
    
    address public owner;
    string public name = "Become Hippies Dividend";
    string public symbol = "BHD";
    
    bool public isFunding = true;
    uint8 private _fundingStartPrice = 3;
    uint8 private _fundingMaxRound = 4;
    uint8 private _fundingIndex = 0;
    FundingRound[] private _fundingRounds;
    
    uint public minAmountDividend = 100 * _supplyDecimals;
    uint public airdropAmount = 3000 * _supplyDecimals;
    
    uint32 public sponsorshipPercentage = 25;
    uint32 public transferPercentage = 20;
    
    event Approval(address indexed owner, address indexed sender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    
    constructor () {
        for (uint i = _fundingIndex; i <= _fundingMaxRound; i++) {
            _fundingRounds.push(FundingRound(
                _fundingGetPrice(_fundingStartPrice + i), 
                12000 * _supplyDecimals
            ));
        }
        owner = msg.sender;
    }
    
    receive() external payable {
        if (isFunding) {
            addFunding(msg.value, msg.sender);
        } else {
            addDividend(msg.value);
        }
    }
    
    function balanceOf(address user) public view returns (uint) {
        return _balances[user];
    }
    
    function dividendOf(address user) public view returns (uint) {
        return _dividends[user];
    }
    
    function dividendPercentage() public view returns (uint) {
        return funding.usd / 6000;
    }
    
    function fundingStartPrice() public view returns (uint) {
        return _fundingGetPrice(_fundingStartPrice);
    }
    
    function fundingMaxRound() public view returns (uint) {
        return _fundingMaxRound + 1;
    }
    
    function fundingSupply() public view returns (uint) {
        return isFunding ? _fundingRounds[_fundingIndex].supply : 0;
    }
    
    function fundingPrice() public view returns (uint) {
        return isFunding ? _fundingRounds[_fundingIndex].price : 0;
    }
    
    function fundingRound() public view returns (uint) {
        return isFunding ? _fundingIndex + 1 : 0;
    }
    
    function fundingAmout(uint value) public view returns (uint) {
        return isFunding ? _fundingAmount(value, _fundingIndex) : 0;
    }
    
    function maxFundingAmount() public view returns (uint) {
        if (!isFunding) {
            return 0;
        }
        uint amount = 0;
        for (uint8 i = _fundingIndex; i <= _fundingMaxRound; i++) {
            amount += _fundingSupply(i) * _fundingPrice(i) / _supplyDecimals;
        }
        return amount;
    }
    
    function hasSponsorship(address user) public view returns (bool) {
        return _sponsorships[user].value;
    }
    
    function beneficiariesSupply(uint minAmount) public view returns (uint) {
        uint supply = 0;
        for (uint i = 0; i < _beneficiaries.length; i++) {
            address user = _beneficiaries[i];
            if (_balances[user] > minAmount)
                supply += _balances[user];
        }
        return supply;
    }
    
    function closeFunding(uint usd, bytes32 hash) public returns(bool) {
        require(_isOwner(), "Owner access");
        require(isFunding, "Funding completed");
        isFunding = false;
        uint supply = totalSupply * 3 / 10 + airdropAmount;
        _balances[owner] += supply;
        totalSupply += supply;
        funding = Funding(usd * _supplyDecimals, hash);
        return true;
    }
    
    function withdrawFunding() public returns(bool) {
        require(_isOwner(), "Owner access");
        uint amount = address(this).balance * 7 / 10;
        payable(owner).transfer(amount);
        return true;
    }
    
    function withdraw() public returns(bool) {
        require(_isOwner(), "Owner access");
        uint balance = address(this).balance;
        require(balance > 0, "Contract balance is empty");
        payable(owner).transfer(balance);
        return true;
    }
    
    function addSponsorship(address sender, address sponsorship) public {
        require(isFunding, "Funding completed");
        _sponsorships[sponsorship] = Sponsorship(sender, true);
    }
    
    function addDividend(uint value) public payable {
        require(value > 0, "Value is empty");
        require(!isFunding, "Funding in progress");
        dividend += value;
        uint supply = beneficiariesSupply(minAmountDividend);
        for (uint i = 0; i < _beneficiaries.length; i++) {
            address user = _beneficiaries[i];
            if (_balances[user] >= minAmountDividend) {
                uint amount = value * _balances[user] / supply;
                //payable(user).transfer(amount);
                _dividends[user] += amount;
            }
        }
    }
    
    function addFunding(uint value, address sender) public payable {
        require(value <= maxFundingAmount(), "Amount exceeded");
        uint amount = _setFunding(value, sender);
        totalSupply += amount;
        _setBalance(sender, amount);
    }
    
    function transfer(address to, uint value) public returns (bool) {
        require(balanceOf(msg.sender) >= value, "Insufficient balance");
        _setBalance(to, value);
        _balances[msg.sender] -= value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) public returns (bool) {
        //require(allowance(from, msg.sender) >= value, "Insufficient allowance");
        require(balanceOf(from) >= value, "Insufficient balance");
        _balances[from] -= value;
        if (from != owner) {
            uint supply = beneficiariesSupply(0) - _balances[from];
            uint amount = value * transferPercentage / 100;
            uint added = 0;
            for (uint i = 0; i < _beneficiaries.length; i++) {
                address user = _beneficiaries[i];
                if (user != from) {
                    uint add = amount * _balances[user] / supply;
                    _balances[user] += add;
                    added += add;
                }
            }
            value -= amount;
            totalSupply -= amount - added;
        }
        _balances[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    function approve(address sender, uint value) public returns (bool) {
        _allowances[msg.sender][sender] = value;
        emit Approval(msg.sender, sender, value);
        return true;
    }
    
    function allowance(address from, address sender) public view returns (uint256) {
        return _allowances[from][sender];
    }
    
    function burn(uint value) public {
        require(_isOwner(), "Owner access");
        require(balanceOf(owner) >= value, "Insufficient balance");
        _balances[owner] -= value;
        totalSupply -= value;
    }
    
    function _isContract(address value) private view returns (bool){
        uint32 size;
        assembly { size := extcodesize(value) }
        return size > 0;
    }
    
    function _isOwner() private view returns (bool) {
        return msg.sender == owner;
    }
    
    function _fundingGetPrice(uint value) private pure returns (uint) {
        return value * 10 ** 15;
    }
    
    function _fundingSupply(uint8 index) private view returns (uint) {
        return _fundingRounds[index].supply;
    }
    
    function _fundingPrice(uint8 index) private view returns (uint) {
        return _fundingRounds[index].price;
    }
    
    function _fundingAmount(uint value, uint8 index) private view returns (uint) {
        uint price = _fundingPrice(index);
        uint supply = _fundingSupply(index);
        uint amount = value / price;
        if (amount <= supply) {
            return amount;
        }
        if (index > 1) {
            return supply;
        }
        value = (amount - supply) * price;
        return supply + _fundingAmount(value, index + 1);
    }
    
    function _setBalance(address to, uint value) private {
        _balances[to] += value;
         if (!_addresses[to] && to != owner && !_isContract(to)) {
            _addresses[to] = true;
            _beneficiaries.push(to);
        }
    }
    
    function _sponsorship(uint amount, address user) private {
        amount = amount * sponsorshipPercentage / 100;
        _balances[user] += amount;
        totalSupply += amount;
    }
    
    function _setFunding(uint value, address sender) private returns (uint) {
        uint price = fundingPrice();
        uint supply = fundingSupply();
        uint amount = value * _supplyDecimals / price;
        Sponsorship memory sponsorship = _sponsorships[sender];
        FundingRound storage round = _fundingRounds[_fundingIndex];
        if (amount > supply) {
            if (sponsorship.value) {
                _sponsorship(supply, sponsorship.user);
            }
            round.supply -= supply;
            if (_fundingIndex == _fundingMaxRound) {
                return supply;
            }
             value = (amount - supply) / _supplyDecimals * price ;
            _fundingIndex++;
            return supply + _setFunding(value, sender);
        }
        if (sponsorship.value) {
            _sponsorship(amount, sponsorship.user);
        }
        round.supply -= amount;
        return amount;
    }
}
