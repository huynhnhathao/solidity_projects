// SPDX-License-Identifier: MIT
import "@openzepplin/contracts/token/ERC20/ERC20.sol";
import "@openzepplin/contracts/access/Ownable.sol";

pragma solidity 0.8.13;

contract Token is ERC20, Ownable {
    uint224 public maxSupply = 1_000_000_000 ether;

    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}

    function mint(uint256 _amount) external onlyOwner returns (bool) {
        _mint(msg.sender, _amount);
        require(totalSupply() <= maxSupply, "Mint exceed maxSupply");
        return true;
    }

    function mintTo(address _recipient, uint256 _amount)
        external
        onlyOwner
        returns (bool)
    {
        _mint(_recipient, _amount);
        require(totalSupply() <= maxSupply, "Mint exceed maxSupply");

        return true;
    }

    function burn(uint256 _amount) external returns (bool) {
        _burn(msg.sender, _amount);
        return true;
    }
}
