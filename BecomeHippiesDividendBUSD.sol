// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IBEP20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}


contract BecomeHippiesDividend {
    
    IBEP20 private _busd;
    
    struct Dividend {
        uint256 amount;
        bytes32 hash;
    }
    
    struct FundingRound {
        uint256 price;
        uint256 supply;
    }
    
    struct Sponsorship {
        address account;
        uint256 amount;
        bool value;
    }
    
    uint256 public totalSupply = 0;
    uint8 public constant decimals = 18;
    string public constant name = "Become Hippies Dividend";
    string public constant symbol = "BHD";
    uint8 private constant _fundingStartPrice = 100;
    uint8 private constant _fundingRoundMaxIndex = 2;
    address private constant _busdAddress = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7;
    
    uint8 public constant sponsorshipPercentage = 25;
    uint8 public constant transferPercentage = 20;
    uint8 public constant fundsPercentage = 70;
    uint8 public constant fundingAddSupplyPercentage = 30;
    
    uint256 public constant minValueDividend = 100 * 10 ** decimals;
    uint256 public constant airdropMaxSupply = 2500 * 10 ** decimals;
    uint256 public constant fundingRoundSupply = 20000 * 10 ** decimals;
    uint256 public constant fundingtarget = 60000;
    uint8 public constant dividendBasePercentage = 10;
    
    mapping (address => bool) private _addresses;
    mapping (address => uint) private _balances;
    mapping (address => uint) private _dividends;
    mapping (address => Sponsorship) private _sponsorships;
    mapping (address => address[]) private _sponsorshipsAddresses;
    mapping (address => mapping (address => uint)) private _allowances;
    
    address[] private _beneficiaries;
    
    uint256 public dividend;
    uint private _funds;
    address public owner;
    bool public isFunding = true;
    uint8 private _fundingRoundIndex = 0;
    FundingRound[] private _fundingRounds;
    uint256 public airdropSupply = 0;
    
    event Approval(address indexed owner, address indexed sender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner access");
        _;
    }
    
    constructor () {
        _busd = IBEP20(_busdAddress);
        for (uint i = _fundingRoundIndex; i <= _fundingRoundMaxIndex; i++) {
            _fundingRounds.push(FundingRound(
                _fundingStartPrice + i * 25, 
                fundingRoundSupply
            ));
        }
        owner = msg.sender;
    }
    
    receive() external onlyOwner payable {
        addDividends();
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function dividendOf(address account) public view returns (uint256) {
        return _dividends[account];
    }
    
    function dividendRateOf(address account) public view returns (uint256) {
        if (_balances[account] < minValueDividend) {
            return 0;
        }
        return _balances[account] * 10 ** decimals / beneficiariesSupply();
    }
    
    function sponsorshipOf(address account) public view returns (Sponsorship memory) {
        return _sponsorships[account];
    }
    
    function sponsorshipsOf(address account) public view returns (address[] memory) {
        return _sponsorshipsAddresses[account];
    }
    
    function dividendPercentage() public view returns (uint256) {
        return _getFunds() / fundingtarget / dividendBasePercentage;
    }
    
    function funds() public view returns (uint) {
        return _getFunds();
    }
    
    function fundingStartPrice() public pure returns (uint256) {
        return _fundingGetPrice(_fundingStartPrice);
    }
    
    function fundingMaxRound() public pure returns (uint8) {
        return _fundingRoundMaxIndex + 1;
    }
    
    function fundingSupplyOfCurrentRound() public view returns (uint256) {
        return isFunding ? _fundingRounds[_fundingRoundIndex].supply : 0;
    }
    
    function fundingPriceOfCurrentRound() public view returns (uint256) {
        return isFunding ? _fundingGetPrice(_fundingRounds[_fundingRoundIndex].price) : 0;
    }
    
    function fundingCurrentRound() public view returns (uint8) {
        return isFunding ? _fundingRoundIndex + 1 : 0;
    }
    
    function fundingValueFromBUSD(uint256 value) public view returns (uint256) {
        return isFunding ? _fundingValueFromBUSD(value, _fundingRoundIndex) : 0;
    }
    
    function fundingValue(uint256 value) public view returns (uint256) {
        return isFunding ? _fundingValue(value, _fundingRoundIndex) : 0;
    }
    
    function fundingMaxCurrentValue() public view returns (uint256) {
        if (!isFunding) {
            return 0;
        }
        uint amount = 0;
        for (uint8 i = _fundingRoundIndex; i <= _fundingRoundMaxIndex; i++) {
            amount += _fundingSupply(i) * _fundingPrice(i) / _fundingStartPrice;
        }
        return amount;
    }
    
    function fundingMaxValue() public view returns (uint256) {
        uint amount = 0;
        for (uint8 i = 0; i <= _fundingRoundMaxIndex; i++) {
            amount += fundingRoundSupply * _fundingPrice(i) / _fundingStartPrice;
        }
        return amount;
    }
    
    function fundingMaxCurrentSupply() public view returns (uint256) {
        if (!isFunding) {
            return 0;
        }
        uint supply = 0;
        for (uint8 i = _fundingRoundIndex; i <= _fundingRoundMaxIndex; i++) {
            supply += _fundingSupply(i);
        }
        return supply;
    }
    
    function fundingMaxSupply() public view returns (uint) {
        return _fundingRounds.length * fundingRoundSupply;
    }
    
    function sponsorshipMaxSupply() public view returns (uint) {
        uint value = fundingMaxSupply();
        return value * sponsorshipPercentage / 100;
    }
    
    function maxSupply() public view returns (uint) {
        uint supply = fundingMaxSupply() + sponsorshipMaxSupply();
        return supply + supply * fundingAddSupplyPercentage / 100 + airdropMaxSupply;
    }
    
    function beneficiariesSupply() public view returns (uint256) {
        return _beneficiariesSupply(minValueDividend);
    }
    
    function endOfFunding() public onlyOwner returns (bool) {
        require(isFunding, "Funding completed");
        uint256 _airdropSupply = airdropMaxSupply * totalSupply / maxSupply();
        uint supply = totalSupply * fundingAddSupplyPercentage / 100 + _airdropSupply;
        uint value = _getCurrentFunds();
        _busd.transfer(owner, value);
        isFunding = false;
        totalSupply += supply;
        _balances[owner] += supply;
        _funds = value;
        airdropSupply = _airdropSupply;
        return true;
    }
    
    function withdrawToken(address contractAddress, address to) public onlyOwner payable {
        IBEP20 token = IBEP20(contractAddress);
        token.transfer(to, token.balanceOf(address(this)));
    }
    
    function addDividends() public payable {
        require(msg.value > 0, "Value is empty");
        require(!isFunding, "Funding in progress");
        dividend += msg.value;
        uint supply = beneficiariesSupply();
        for (uint i = 0; i < _beneficiaries.length; i++) {
            address user = _beneficiaries[i];
            if (_balances[user] >= minValueDividend) {
                uint amount = msg.value * _balances[user] / supply;
                payable(user).transfer(amount);
                _dividends[user] += amount;
            }
        }
    }
    
    function addFunds(uint256 amount, address account) public payable {
        require(isFunding, "Funding completed");
        require(msg.value <= fundingMaxCurrentValue(), "Value exceeded");
        _busd.transferFrom(msg.sender, address(this), amount);
        if (!_sponsorships[msg.sender].value && msg.sender != account && _addresses[account] && !_isContract(account) && account != owner) {
            _sponsorships[msg.sender] = Sponsorship(account, 0, true);
            _sponsorshipsAddresses[account].push(msg.sender);
        }
        uint256 value = _setFunding(amount, msg.sender);
        totalSupply += value;
        _setBalance(msg.sender, value);
    }
    
    function transfer(address to, uint256 value) public returns (bool) {
        require(balanceOf(msg.sender) >= value, "Insufficient balance");
        _setBalance(to, value);
        _balances[msg.sender] -= value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    function transferFrom(address from, address to, uint value) public returns (bool) {
        require(allowance(from, msg.sender) >= value, "Insufficient allowance");
        require(balanceOf(from) >= value, "Insufficient balance");
        if (_addresses[from]) {
            uint amount = value * transferPercentage / 100;
            require(balanceOf(from) >= value + amount, "Insufficient balance");
            uint supply = _beneficiariesSupply(0) - _balances[from];
            uint added = 0;
            for (uint i = 0; i < _beneficiaries.length; i++) {
                address user = _beneficiaries[i];
                if (user != from && _balances[user] > 0) {
                    uint add = amount * _balances[user] / supply;
                    _balances[user] += add;
                    added += add;
                }
            }
            _balances[from] -= added;
        }
        _balances[from] -= value;
        _setBalance(to, value);
        emit Transfer(from, to, value);
        return true;
    }
    
    function approve(address spender, uint256 value) public returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    function withdraw() public onlyOwner returns(bool) {
        uint balance = address(this).balance;
        require(balance > 0, "Contract balance is empty");
        payable(owner).transfer(balance);
        return true;
    }
    
    function burn(uint256 value) public {
        require(balanceOf(msg.sender) >= value, "Insufficient balance");
        _balances[owner] -= value;
        totalSupply -= value;
    }
    
    function allowance(address from, address sender) public view returns (uint256) {
        return _allowances[from][sender];
    }
    
    function _getFunds() private view returns (uint256) {
        return isFunding ? _getCurrentFunds() : _funds;
    }
    
    function _getCurrentFunds() private view returns (uint256) {
        return _busd.balanceOf(address(this)) * fundsPercentage / 100;
    }
    
    function _isContract(address account) private view returns (bool) {
        uint32 size;
        assembly { size := extcodesize(account) }
        return size > 0;
    }
    
    function _isOwner() private view returns (bool) {
        return msg.sender == owner;
    }
    
    function _fundingGetPrice(uint256 value) private pure returns (uint256) {
        return value * 10 ** 18 / _fundingStartPrice;
    }
    
    function _fundingSupply(uint8 index) private view returns (uint256) {
        return _fundingRounds[index].supply;
    }
    
    function _fundingPrice(uint8 index) private view returns (uint256) {
        return _fundingRounds[index].price;
    }
    
    function _beneficiariesSupply(uint minValue) private view returns (uint256) {
        uint supply = 0;
        for (uint i = 0; i < _beneficiaries.length; i++) {
            address user = _beneficiaries[i];
            if (_balances[user] >= minValue)
                supply += _balances[user];
        }
        return supply;
    }
    
    function _fundingValueFromBUSD(uint256 value, uint8 index) private view returns (uint256) {
        uint price = _fundingPrice(index);
        uint supply = _fundingSupply(index);
        uint amount = value * _fundingStartPrice / price;
        if (amount > supply) {
            if (index == _fundingRoundMaxIndex) {
                return supply;
            }
            value -= supply * price / _fundingStartPrice;
            return supply + _fundingValueFromBUSD(value, index + 1);
        }
        return amount;
    }
    
    function _fundingValue(uint256 value, uint8 index) private view returns (uint256) {
        uint price = _fundingPrice(index);
        uint supply = _fundingSupply(index);
        if (value > supply) {
            uint amount = supply * price / _fundingStartPrice;
            if (index == _fundingRoundMaxIndex) {
                return amount;
            }
            return amount + _fundingValue(value - supply, index + 1);
        }
        return value * price / _fundingStartPrice;
    }
    
    function _setBalance(address to, uint256 value) private {
        _balances[to] += value;
         if (!_addresses[to] && to != owner && !_isContract(to)) {
            _addresses[to] = true;
            _beneficiaries.push(to);
        }
    }
    
    function _sponsorship(uint256 amount, Sponsorship storage sponsorship) private {
        amount = amount * sponsorshipPercentage / 100;
        _balances[sponsorship.account] += amount;
        totalSupply += amount;
        sponsorship.amount += amount;
    }
    
    function _setFunding(uint256 value, address sender) private returns (uint256) {
        uint price = _fundingRounds[_fundingRoundIndex].price;
        uint supply = _fundingRounds[_fundingRoundIndex].supply;
        uint amount = value * _fundingStartPrice / price;
        Sponsorship storage sponsorship = _sponsorships[sender];
        FundingRound storage round = _fundingRounds[_fundingRoundIndex];
        if (amount > supply) {
            if (sponsorship.value) {
                _sponsorship(supply, sponsorship);
            }
            round.supply -= supply;
            if (_fundingRoundIndex == _fundingRoundMaxIndex) {
                return supply;
            }
             value -= supply * price / _fundingStartPrice;
            _fundingRoundIndex++;
            return supply + _setFunding(value, sender);
        }
        if (sponsorship.value) {
            _sponsorship(amount, sponsorship);
        }
        round.supply -= amount;
        if (round.supply == 0) {
            _fundingRoundIndex++;
        }
        return amount;
    }
}
