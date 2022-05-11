// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
Deployed on Polygon Matic Network:
v0.9 0x357e00601A54e50628eABf2F70F2882eF42a5837
*/

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface PIQ {
    function _owners(uint) external view returns(address);
}


contract Charger {
    mapping (address => uint) public totalSupply; // for each Coin
    mapping (address => uint) public coinIx;
    uint public coinNum; // Number of Coins + Gaps
    
    //       NFT_Con              NFT_Id          Coin     Value
    mapping (address => mapping( uint => mapping(address => uint) ) ) public asset;
    //       NFT_Con              NFT_Id          Coin     Owner
    mapping (address => mapping( uint => mapping(address => address) ) ) public depositor;

    address public theOperator;
    address public auctor;
    
    function approve(address t, uint value) external {
        IERC20(t).approve(msg.sender, value);
    }
    
    function deposit(address nftCon, uint nftId, address coin, uint value) external {
        require(coinIx[coin] > 0);
        address d = depositor[nftCon][nftId][coin];
        require( d == address(0) || d == msg.sender);
        IERC20(coin).transferFrom( msg.sender, address(this), value );
        asset[nftCon][nftId][coin] += value;
        totalSupply[coin] += value;
        if(d == address(0))
            depositor[nftCon][nftId][coin] = msg.sender;
    }
    
    function withdraw(address nftCon, uint nftId, address coin, uint value) external {
        require(totalSupply[coin] >= value); // should always be! but just in case
        address d = depositor[nftCon][nftId][coin];
        require( msg.sender != d && PIQ(nftCon)._owners(nftId) == msg.sender );
        require( asset[nftCon][nftId][coin] >= value );
        asset[nftCon][nftId][coin] -= value;
        totalSupply[coin] -= value;
        IERC20(coin).transfer(msg.sender, value);
        if( asset[nftCon][nftId][coin] == 0 )
            depositor[nftCon][nftId][coin] = address(0);
    }
    
    constructor() {
        auctor = msg.sender;
        theOperator = 0xAA01b53B4a5ef7bb844f886DEfaeC45DC144731f;
        addCoin(0xc2132D05D31c914a87C6611C10748AEb04B58e8F); // USDT on Polygon
//         addCoin(0x55d398326f99059fF775485246999027B3197955); // USDT on BSC
    }
    
    function setOperator(address a) external {
        require(msg.sender == auctor || msg.sender == theOperator);
        theOperator = a;
    }
    
    function addCoin(address t) public {
        require(msg.sender == auctor || msg.sender == theOperator);
        if( coinIx[t] == 0 )
            coinIx[t] = ++coinNum;
    }
    
    function delCoin(address t) external {
        require(msg.sender == auctor || msg.sender == theOperator);
        require(totalSupply[t] == 0);
        delete coinIx[t];
    }
    
    function saveLost(address t, address w, uint amount) external {
        require(msg.sender == auctor);
        uint thisBalance = IERC20(t).balanceOf(address(this));
        require( totalSupply[t] + amount <= thisBalance );
        IERC20(t).transfer(w, amount);
    }
}
