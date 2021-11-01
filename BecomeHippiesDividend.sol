// SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

contract BecomeHippiesDividend {
    
    AggregatorV3Interface private _feedBNBUSD;
    
    struct Dividend {
        uint amount;
        bytes32 hash;
    }
    
    struct FundingRound {
        uint price;
        uint supply;
    }
    
    struct Sponsorship {
        address account;
        uint amount;
        bool value;
    }
    
    uint public constant decimals = 18;
    string public constant name = "Become Hippies Dividend";
    string public constant symbol = "BHD";
    uint8 private constant _fundingStartPrice = 3;
    uint8 private constant _fundingMaxIndex = 4;
    uint32 public constant sponsorshipPercentage = 25;
    uint32 public constant transferPercentage = 20;
    uint72 public constant fundingPercentage = 70;
    uint32 public constant fundingAddedPercentage = 30;
    uint public constant minValueDividend = 100 * 10 ** 18;
    uint public constant airdropMaxSupply = 2500 * 10 ** 18;
    uint public constant fundingRoundSupply = 12000 * 10 ** 18;
    
    mapping (address => bool) private _addresses;
    mapping (address => uint) private _balances;
    mapping (address => uint) private _dividends;
    mapping (address => Sponsorship) private _sponsorships;
    mapping (address => address[]) private _sponsorshipsAddresses;
    mapping (address => mapping (address => uint)) private _allowances;
    
    address[] private _beneficiaries;
    
    uint public dividend;
    uint private _fundingUSD;
    uint public totalSupply = 0;
    address public owner;
    bool public isFunding = true;
    uint8 private _fundingIndex = 0;
    FundingRound[] private _fundingRounds;
    uint public airdropSupply = 0;
    
    event Approval(address indexed owner, address indexed sender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);
    
    constructor () {
        //0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE
        _feedBNBUSD = AggregatorV3Interface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);
        for (uint i = _fundingIndex; i <= _fundingMaxIndex; i++) {
            _fundingRounds.push(FundingRound(
                _fundingStartPrice + i, 
                fundingRoundSupply
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
    
    function balanceOf(address account) public view returns (uint) {
        return _balances[account];
    }
    
    function dividendOf(address account) public view returns (uint) {
        return _dividends[account];
    }
    
    function dividendPercentageOf(address account) public view returns (uint) {
        if (_balances[account] < minValueDividend) {
            return 0;
        }
        return _balances[account] * 10 / _beneficiariesSupply(minValueDividend);
    }
    
    function sponsorshipOf(address account) public view returns (Sponsorship memory) {
        return _sponsorships[account];
    }
    
    function sponsorshipsOf(address account) public view returns (address[] memory) {
        return _sponsorshipsAddresses[account];
    }
    
    function hasSponsorship(address account) public view returns (bool) {
        return _sponsorships[account].value;
    }
    
    function dividendPercentage() public view returns (uint) {
        // BNB 18 decimals + USD 8 decimals = 10e26
        return isFunding ? _toUSD(address(this).balance) : _fundingUSD / (60000 * 10 ** 26); // USD 8 decimals
    }
    
    function fundingUSD() public view returns (uint) {
        return _fundingUSD / 10 ** 26;
    }
    
    function fundingStartPrice() public pure returns (uint) {
        return _fundingGetPrice(_fundingStartPrice);
    }
    
    function fundingMaxRound() public pure returns (uint) {
        return _fundingMaxIndex + 1;
    }
    
    function fundingSupplyOfCurrentRound() public view returns (uint) {
        return isFunding ? _fundingRounds[_fundingIndex].supply : 0;
    }
    
    function fundingPriceOfCurrentRound() public view returns (uint) {
        return isFunding ? _fundingGetPrice(_fundingRounds[_fundingIndex].price) : 0;
    }
    
    function fundingCurrentRound() public view returns (uint) {
        return isFunding ? _fundingIndex + 1 : 0;
    }
    
    function fundingValueFromBNB(uint value) public view returns (uint) {
        return isFunding ? _fundingValueFromBNB(value, _fundingIndex) : 0;
    }
    
    function fundingValue(uint value) public view returns (uint) {
        return isFunding ? _fundingValue(value, _fundingIndex) : 0;
    }
    
    function fundingMaxCurrentValue() public view returns (uint) {
        if (!isFunding) {
            return 0;
        }
        uint amount = 0;
        for (uint8 i = _fundingIndex; i <= _fundingMaxIndex; i++) {
            amount += _fundingSupply(i) * _fundingPrice(i) / 1000;
        }
        return amount;
    }
    
    function fundingMaxValue() public view returns (uint) {
        uint amount = 0;
        for (uint8 i = 0; i <= _fundingMaxIndex; i++) {
            amount += _fundingSupply(i) * _fundingPrice(i) / 1000;
        }
        return amount;
    }
    
    function fundingMaxSupply() public view returns (uint) {
        uint value;
        for (uint8 i = 0; i < _fundingRounds.length; i++) {
            value += _fundingSupply(i);
        }
        return value;
    }
    
    function sponsorshipMaxSupply() public view returns (uint) {
        uint value = fundingMaxSupply();
        return value * sponsorshipPercentage / 100;
    }
    
    function maxSupply() public view returns (uint) {
        uint supply = fundingMaxSupply() + sponsorshipMaxSupply();
        return supply + supply * fundingAddedPercentage / 100 + airdropMaxSupply;
    }
    
    function endOfFunding() public returns (bool) {
        require(isFunding, "Funding completed");
        require(_isOwner(), "Owner access");
        isFunding = false;
        airdropSupply = airdropMaxSupply * totalSupply / maxSupply();
        uint supply = totalSupply * fundingAddedPercentage / 100 + airdropSupply;
        _balances[owner] += supply;
        totalSupply += supply;
        uint balance = address(this).balance;
        uint value = balance * fundingPercentage / 100;
        _fundingUSD = _toUSD(value);
        payable(owner).transfer(value);
        withdraw();
        return true;
    }
    
    function addSponsorship(address sender, address account) public {
        require(isFunding, "Funding completed");
        require(!hasSponsorship(account), "Account has sponsorship");
        _sponsorships[account] = Sponsorship(sender, 0, true);
        _sponsorshipsAddresses[sender].push(account);
    }
    
    function addDividend(uint value) public payable {
        require(value > 0, "Value is empty");
        require(!isFunding, "Funding in progress");
        dividend += value;
        uint supply = _beneficiariesSupply(minValueDividend);
        for (uint i = 0; i < _beneficiaries.length; i++) {
            address user = _beneficiaries[i];
            if (_balances[user] >= minValueDividend) {
                uint amount = value * _balances[user] / supply;
                payable(user).transfer(amount);
                _dividends[user] += amount;
            }
        }
    }
    
    function addFunding(uint value, address sender) public payable {
        require(value <= fundingMaxCurrentValue(), "Value exceeded");
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
        require(allowance(from, msg.sender) >= value, "Insufficient allowance");
        require(balanceOf(from) >= value, "Insufficient balance");
        _balances[from] -= value;
        if (from != owner) {
            uint supply = _beneficiariesSupply(0) - _balances[from];
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
    
    function withdraw() public returns(bool) {
        require(_isOwner(), "Owner access");
        uint balance = address(this).balance;
        require(balance > 0, "Contract balance is empty");
        payable(owner).transfer(balance);
        return true;
    }
    
    function burn(uint value) public {
        require(_isOwner(), "Owner access");
        require(balanceOf(owner) >= value, "Insufficient balance");
        _balances[owner] -= value;
        totalSupply -= value;
    }
    
    function allowance(address from, address sender) public view returns (uint256) {
        return _allowances[from][sender];
    }
    
    function _toUSD(uint value) private view returns (uint) {
        (,int price,,,) = _feedBNBUSD.latestRoundData();
        return value * uint(price);
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
    
    function _beneficiariesSupply(uint minValue) private view returns (uint) {
        uint supply = 0;
        for (uint i = 0; i < _beneficiaries.length; i++) {
            address user = _beneficiaries[i];
            if (_balances[user] > minValue)
                supply += _balances[user];
        }
        return supply;
    }
    
    function _fundingValueFromBNB(uint value, uint8 index) private view returns (uint) {
        uint price = _fundingPrice(index);
        uint supply = _fundingSupply(index);
        uint amount = value * 1000 / price;
        if (amount > supply) {
            if (index == _fundingMaxIndex) {
                return supply;
            }
            value -= supply * price / 1000;
            return supply + _fundingValueFromBNB(value, index + 1);
        }
        return amount;
    }
    
    function _fundingValue(uint value, uint8 index) private view returns (uint) {
        uint price = _fundingPrice(index);
        uint supply = _fundingSupply(index);
        if (value > supply) {
            uint amount = supply * price / 1000;
            if (index == _fundingMaxIndex) {
                return amount;
            }
            return amount + _fundingValue(value - supply, index + 1);
        }
        return value * price / 1000;
    }
    
    function _setBalance(address to, uint value) private {
        _balances[to] += value;
         if (!_addresses[to] && to != owner && !_isContract(to)) {
            _addresses[to] = true;
            _beneficiaries.push(to);
        }
    }
    
    function _sponsorship(uint amount, Sponsorship memory sponsorship) private {
        amount = amount * sponsorshipPercentage / 100;
        _balances[sponsorship.account] += amount;
        totalSupply += amount;
        sponsorship.amount += amount;
    }
    
    function _setFunding(uint value, address sender) private returns (uint) {
        uint price = _fundingRounds[_fundingIndex].price;
        uint supply = _fundingRounds[_fundingIndex].supply;
        uint amount = value * 1000 / price;
        Sponsorship memory sponsorship = _sponsorships[sender];
        FundingRound storage round = _fundingRounds[_fundingIndex];
        if (amount > supply) {
            if (sponsorship.value) {
                _sponsorship(supply, sponsorship);
            }
            round.supply -= supply;
            if (_fundingIndex == _fundingMaxIndex) {
                return supply;
            }
             value -= supply * price / 1000;
            _fundingIndex++;
            return supply + _setFunding(value, sender);
        }
        if (sponsorship.value) {
            _sponsorship(amount, sponsorship);
        }
        round.supply -= amount;
        return amount;
    }
}
