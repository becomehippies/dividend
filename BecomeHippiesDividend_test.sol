pragma solidity >=0.7.0 <0.9.0;
import "remix_tests.sol"; // this import is automatically injected by Remix.
import "remix_accounts.sol";
import "../BecomeHippiesDividend.sol";

contract BecomeHippiesDividendTest {
    
    BecomeHippiesDividend instance;
    
    mapping(address => uint) public balances;
    mapping(address => uint) public dividends;
    mapping(address => bool) public accountsExist;
    
    struct Account {
        address account;
        uint index;
    }
    
    address[] accounts;
    
    uint burned;
    uint decimals;
    uint fundingSupply;
    uint sponsorshipSupply;
    
    address owner;
    
    function beforeAll() public {
        instance = new BecomeHippiesDividend();
        decimals = instance.decimals();
        fundingSupply = instance.fundingSupplyOfCurrentRound();
        owner = instance.owner();
    }
    
    function addAccount(address account) private returns (bool) {
        if (accountsExist[account]) {
            return false;
        }
        accountsExist[account] = true;
        accounts.push(account);
        return true;
    }
    
    function getAccount(uint i) private returns (address) {
        address account = TestsAccounts.getAccount(i);
        addAccount(account);
        return account;
    }
    
    function getBNB(uint amount) private returns (uint) {
        return amount * 10 ** 15;
    }
    
    function getBHD(uint amount) private returns (uint) {
        return amount * 10 ** 18;
    }
    
    function getAmountFromBHD(uint supply, uint price) private returns (uint) {
        return supply * getBNB(price) / 10 ** 18;
    }
    
    function testFunding() public {
        
        addAccount(msg.sender);
        
        instance.addFunding(getBNB(3), msg.sender); // 0.003 BNB
        balances[msg.sender] += getBHD(1);
        Assert.equal(instance.balanceOf(msg.sender), balances[msg.sender], "balance ok");
        
        instance.addFunding(getBNB(3000), msg.sender); // 2 BNB
        balances[msg.sender] += getBHD(1000);
        Assert.equal(instance.balanceOf(msg.sender), balances[msg.sender], "balance ok");
    }
    
    function testTotalSupply() public {
        Assert.equal(instance.totalSupply(), balances[msg.sender], "total supply ok");
    }
    
    function testFunding1() public {
        address account2 = getAccount(2);
        instance.addFunding(getBNB(30000), account2); // 20 BNB
        balances[account2] += getBHD(10000);
        Assert.equal(instance.balanceOf(account2), balances[account2], "balance ok");
    }
    
    function testFundingSupply() public {
        uint balance;
        for (uint i = 0; i < accounts.length; i++) {
            balance += balances[accounts[i]];
        }
        Assert.equal(instance.fundingSupplyOfCurrentRound(), fundingSupply - balance, "funding supply ok");
    }
    
    function testSponsorship() public {
        
        address account3 = getAccount(3);
        instance.addSponsorship(msg.sender, account3);
        instance.addFunding(getBNB(9), account3); // 0.01 BNB
        balances[account3] += getBHD(3);
        Assert.equal(instance.balanceOf(account3), balances[account3], "balance ok");
        
        uint sponsorship3 = balances[account3] * instance.sponsorshipPercentage() / 100;
        sponsorshipSupply += sponsorship3;
        balances[msg.sender] += sponsorship3;
        Assert.equal(instance.balanceOf(msg.sender), balances[msg.sender], "balance ok");
        
        address account4 = getAccount(4);
        instance.addSponsorship(msg.sender, account4);
        instance.addFunding(getBNB(600), account4); // 0.5 BNB
        balances[account4] += getBHD(200);
        Assert.equal(instance.balanceOf(account4), balances[account4], "balance ok");
        
        uint sponsorship4 = balances[account4] * instance.sponsorshipPercentage() / 100;
        sponsorshipSupply += sponsorship4;
        balances[msg.sender] += sponsorship4;
        Assert.equal(instance.balanceOf(msg.sender), balances[msg.sender], "balance ok");
    }
    
    function testTotalSupply2() public {
        _testTotalSupply();
    }
    
    function testNewFundingRound() public {
        
        uint supply = instance.fundingSupplyOfCurrentRound() - getBHD(1);
        uint amount = getAmountFromBHD(supply, 3);
        
        address account5 = getAccount(5);
        instance.addFunding(amount, account5);
        balances[account5] += supply;
        Assert.equal(instance.balanceOf(account5), supply, "balance ok");
        
        Assert.equal(instance.fundingSupplyOfCurrentRound(), getBHD(1), "funding supply ok");
        
        address account12 = getAccount(12);
        balances[account12] += getBHD(1000);
        instance.addFunding(getBNB(4000), account12);
        Assert.equal(instance.balanceOf(account12), getBHD(1000), "balance ok");
        
        Assert.equal(instance.fundingSupplyOfCurrentRound(), getBHD(11000) + getBHD(1), "funding supply ok");
        
        fundingSupply = instance.fundingSupplyOfCurrentRound();
    }
    
    function testInvalidAmount() public {
        try instance.addFunding(getBNB(1000000), msg.sender) {
            Assert.ok(false, 'Invalid Amount');
        } catch {
            Assert.equal(instance.balanceOf(msg.sender), balances[msg.sender], "balance ok");
        }
    }
    
    function testEndOfFundingRound2() public {
        // 12 000 supply * 0.004 BNB = 48 BNB - 4 BNB = 44 BNB + 1BHD
        instance.addFunding(getBNB(44000) + getAmountFromBHD(getBHD(1), 4), msg.sender);
        balances[msg.sender] += 11001 * 10 ** 18;
        Assert.equal(instance.balanceOf(msg.sender), balances[msg.sender], "balance ok");
        Assert.equal(instance.totalSupply(), 24000 * 10 ** 18 + sponsorshipSupply, "total supply ok");
    }
    
    function testTotalSupply3() public {
        _testTotalSupply();
    }
    
    function testTransfer() public {
        address owner = instance.owner();
        addAccount(owner);
        address account2 = getAccount(2);
        uint amount = 12 * 10 ** 18;
        instance.transfer(account2, amount);
        balances[owner] -= amount;
        balances[account2] += amount;
        Assert.equal(instance.balanceOf(owner), balances[owner], "balance ok");
        Assert.equal(instance.balanceOf(account2), balances[account2], "balance ok");
    }
    
    function testTotalSupply4() public {
        uint balance;
        for (uint i = 0; i < accounts.length; i++) {
            balance += balances[accounts[i]];
        }
        Assert.equal(instance.totalSupply(), balance, "total supply ok");
    }
    
    function testBurn() public {
        uint supply = instance.totalSupply();
        instance.burn(123 * 10 ** 18);
        Assert.equal(instance.totalSupply(), supply - (123 * 10 ** 18), "total supply ok");
        balances[owner] -= 123 * 10 ** 18;
        _testTotalSupply();
    }
    
    function _testTotalSupply() private {
        uint balance;
        for (uint i = 0; i < accounts.length; i++) {
            balance += balances[accounts[i]];
        }
        Assert.equal(instance.totalSupply(), balance, "total supply ok");
    }
}
