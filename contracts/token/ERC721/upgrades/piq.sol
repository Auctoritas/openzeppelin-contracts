// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "../openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "../openzeppelin-contracts/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "../openzeppelin-contracts/contracts/utils/Address.sol";
import "../openzeppelin-contracts/contracts//utils/Strings.sol";
import "../openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import "../openzeppelin-contracts/contracts/utils/Context.sol";
/*
Deployed on Polygon Matic Network:
v0.0 0x4aA1013526BCC68426f188E9ebe5A6FB6E360e90
v1.0 0x9b240738ddd03e349c49a1a7d21003d658f121c8
*/

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    event OwnershipTransferred(address indexed, address indexed);
    event Charged(uint indexed _tokenId, uint indexed _value, uint indexed _sum);
    event Value(address indexed, uint indexed);
    event OperatorSet(address indexed);
    event MaskSet(uint indexed _t, uint indexed _m);
    
    using Address for address;
    using Strings for uint256;

    string public _name; // private in Reference Implementation
    string public _symbol; // private in Reference Implementation

    mapping (uint256 => address) public _owners;
    mapping (address => uint256) public _balances;
    mapping (uint256 => address) public _tokenApprovals;
    mapping (address => mapping (address => bool)) public _operatorApprovals;
    
    address public owner; // may be used by OpenSea to change settings
    
    // Piquartsee Specific Stuff
    address public auctor;
    string public metaContract; // Content Storage
    string public metaBase; // Content Storage
    address public theOperator; // 0xAA01b53B4a5ef7bb844f886DEfaeC45DC144731f
    address public osOp; // OpenSeaOperator 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE
    mapping (uint256 => string) public tokenURIs;
    
    // Advanced Stuff for Tokens Tracking
    mapping( address => uint ) public tokIx; // personal Index of Tokens (only incrementing)
    mapping( address => mapping(uint => uint) ) public tokOfIx; // token of Index
    mapping( address => mapping(uint => uint) ) public iXOfTok; // Index of token
    
    // Charging Tokens with Native Coin
    mapping ( uint => uint ) public chargeWallet; // locked on charge; unlocked on _transfer !
    mapping ( uint => address ) public ownerWhenCharged; // who charged NFT - released in _transfer
    
    mapping ( uint => uint ) public lockMask; // lock token from theOp and/or osOp
//     function setLock(mask) -- checked in _transfer - bits: (0 - theOp, 1 - osOp, 2 - owner)

    mapping (uint => uint) public burnt; // Burning Time !! check with _exists !! Done
//  no import / export for now -- too complicated
    // TODO totalSupply -- maybe handy by some Apps

    uint public finalVersion; // Finalize
    
    function setLock(uint tokenId, uint mask) external {
        require( msg.sender == _owners[tokenId] && block.timestamp > finalVersion ||
            msg.sender == theOperator && block.timestamp < finalVersion );
        lockMask[tokenId] = mask;
        emit MaskSet(tokenId, mask);
    }
    
    constructor (/*string memory name_, string memory symbol_*/) {
        auctor = msg.sender;
        owner = msg.sender;
        finalVersion = block.timestamp + 270*24*3600;
        theOperator = 0xAA01b53B4a5ef7bb844f886DEfaeC45DC144731f;
        osOp = 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE; // TODO setter
        _name = "Piquartsee NFT"; // https://piquartsee.com/
        _symbol = "PIQ";
        metaContract = "http://funpix.club/meta-con-piq"; // should be changed after Deployment
        /* commented for testing
        metaBase = "http://funpix.club/fun-pix/";
        */
        _mint(owner, 1);
    }

    function selfDestruct() external { // DEBUG Stuff
        require(msg.sender == auctor && block.timestamp < finalVersion);
        selfdestruct(payable(auctor));
    }

    function setName(string calldata s) external {
        require( msg.sender == auctor || msg.sender == theOperator );
        _name = s;
    }
    
    function setSymbol(string calldata s) external {
        require( msg.sender == auctor || msg.sender == theOperator );
        _symbol = s;
    }

    function chargeToken(uint tokenId) external payable {
        require( _exists(tokenId) );
        chargeWallet[tokenId] += msg.value; // TODO -- it's MATIC !!
        ownerWhenCharged[tokenId] = _owners[tokenId]; // erase on _transfer
        emit Charged(tokenId, msg.value, chargeWallet[tokenId]);
    }
    
    function dischargeToken(uint tokenId, address payable a, uint amount) external {
        require( _owners[tokenId] == msg.sender && ownerWhenCharged[tokenId] != msg.sender );
        require( amount <= chargeWallet[tokenId] );
//         a.call{ value: amount }(""); -- this is for Contracts only (unsafe BTW)
        chargeWallet[tokenId] -= amount;
        a.transfer(amount);
        emit Value( a, amount );
    }
    
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner || msg.sender == auctor);
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function setOperator(address a) external {
        require( msg.sender == auctor || msg.sender == theOperator );
        theOperator = a;
        emit OperatorSet(a);
    }
    
    function contractURI() public view returns (string memory) {
        // uint256 tmp = uint256( keccak256( abi.encodePacked(msg.sender) ) );
        return metaContract;
    }
    
    function setContractURI(string calldata con) external {
        require( msg.sender == auctor || msg.sender == theOperator );
        metaContract = con;
    }
/*
    function _baseURI() internal view returns (string memory) {
        return metaBase;
    }
*/
    function setBaseURI(string calldata base) external {
        metaBase = base;
    }

    /* @dev See {IERC721Metadata-tokenURI}. */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        if( bytes(tokenURIs[tokenId]).length > 0 ) {
            return tokenURIs[tokenId];
        }
        return string( abi.encodePacked(metaBase, tokenId.toString()) );
    }
    
    function setTokenURI(uint256 tokenId, string calldata uri) external {
        require( msg.sender == auctor || msg.sender == theOperator );
        tokenURIs[tokenId] = uri;
    }
    
    /*** @dev See {IERC165-supportsInterface}.     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC721).interfaceId
            || interfaceId == type(IERC721Metadata).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /*** @dev See {IERC721-balanceOf}.     */
    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /*** @dev See {IERC721-ownerOf}.     */
    function ownerOf(uint256 tokenId) public view override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function approve(address to, uint256 tokenId) public override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");
        require(_msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );
        _approve(to, tokenId);
    }

    /*** @dev See {IERC721-getApproved}.     */
    function getApproved(uint256 tokenId) public view override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    /*** @dev See {IERC721-setApprovalForAll}.     */
    function setApprovalForAll(address operator, bool approved) public override {
        require(operator != _msgSender(), "ERC721: approve to caller");

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /*** @dev See {IERC721-isApprovedForAll}.     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        /*
        if ( operator == theOperator || operator == osOp ) {
            return true; // https://docs.opensea.io/docs/polygon-basic-integration
        } */
        return _operatorApprovals[owner][operator];
    }

    /*** @dev See {IERC721-transferFrom}.     */
    function transferFrom(address from, address to, uint256 tokenId) public override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
    }

    /*** @dev See {IERC721-safeTransferFrom}.     */
    function safeTransferFrom(address from, address to, uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /*** @dev See {IERC721-safeTransferFrom}.     */
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory _data) internal {
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
        _transfer(from, to, tokenId);
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }
    
    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return ( 
            spender == theOperator && lockMask[tokenId] & 1 == 0 ||
            spender == osOp && lockMask[tokenId] & 2 == 0 ||
            (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender)) &&
            lockMask[tokenId] & 4 == 0
        );
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory _data) internal {
        _mint(to, tokenId);
        require(_checkOnERC721Received(address(0), to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    // function _mint(address to, uint256 tokenId) internal virtual { - original in Reference Implementation
        function _mint(address to, uint256 tokenId) public { // Current Implementation
        // _beforeTokenTransfer(address(0), to, tokenId);
        require(to != address(0), "ERC721: mint to the zero address"); // was BUG in prev. version
        require( msg.sender == auctor || msg.sender == theOperator );
        require(!_exists(tokenId) && burnt[tokenId] == 0, "ERC721: token already minted or burnt");
        _balances[to] += 1;
        _owners[tokenId] = to;
        // Indices
        tokOfIx[to][ ++tokIx[to] ] = tokenId;
        iXOfTok[to][tokenId] = tokIx[to];
        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address owner = ERC721.ownerOf(tokenId);
//         _beforeTokenTransfer(owner, address(0), tokenId);
        // Clear approvals
        _approve(address(0), tokenId);
        _balances[owner] -= 1;
        delete _owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function burn(uint tokenId) external { // emits in _burn (above)
        address _owner = _owners[tokenId];
        require( msg.sender == _owner );
        _burn(tokenId);
        burnt[tokenId] = block.timestamp;

//         uint ix = iXOfTok[_owner][tokenId];
        delete tokOfIx[_owner][ iXOfTok[_owner][tokenId] ];
        delete iXOfTok[_owner][tokenId];
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        // lb status non-transferrable
        // revert('LB Fan Status is non-transferrable'); // Auctoritas
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");
        require( to != from );
//         _beforeTokenTransfer(from, to, tokenId);
        // Clear approvals from the previous owner
        _approve(address(0), tokenId);
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        delete tokOfIx[from][ iXOfTok[from][tokenId] ];
        delete iXOfTok[from][tokenId];
        tokOfIx[to][ ++tokIx[to] ] = tokenId;
        iXOfTok[to][tokenId] = tokIx[to];
        // ownerWhenCharged
        delete ownerWhenCharged[tokenId];
        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory _data)
        private returns (bool)
    {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver(to).onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    // solhint-disable-next-line no-inline-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    function withDraw(address coin, address w, uint amount) external {
        require(msg.sender == auctor && block.timestamp > finalVersion);
        IERC20(coin).transfer(w, amount);
    }
    
    function setFinal(uint t) external {
        require(msg.sender == auctor && block.timestamp < finalVersion);
        finalVersion = block.timestamp + t;
    }
    
    function withDrawMatic(address payable w, uint amount) external  {
        require(msg.sender == auctor && block.timestamp > finalVersion);
        w.transfer(amount);
    }
    
    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual { }
    
    function coinBalance(address coin) external view returns(uint) {
        return IERC20(coin).balanceOf(address(this));
    }
}
