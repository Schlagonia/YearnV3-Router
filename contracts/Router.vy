# @version 0.3.7

from vyper.interfaces import ERC20

interface IVault:
    def asset() -> address: view
    def balanceOf(owner: address) -> uint256: view
    def maxDeposit(receiver: address) -> uint256: view
    def maxWithdraw(owner: address) -> uint256: view
    def withdraw(amount: uint256, receiver: address, owner: address, strategies: DynArray[address, 10]) -> uint256: nonpayable
    def redeem(shares: uint256, receiver: address, owner: address, strategies: DynArray[address, 10]) -> uint256: nonpayable
    def deposit(assets: uint256, receiver: address) -> uint256: nonpayable
    def mint(shares: uint256, receiver: address) -> uint256: nonpayable
    def totalAssets() -> (uint256): view
    def convertToAssets(shares: uint256) -> (uint256): view
    def convertToShares(assets: uint256) -> (uint256): view
    def strategies(strategy: address) -> StrategyParams: view

event UpdateGovernance:
    governance: address

event NewPendingGovernance:
    pending_governance: indexed(address)

event StrategyAdded:
    vault: indexed(address)
    strategy: indexed(address)

event StrategyRemoved:
    vault: indexed(address)
    strategy: indexed(address)

event NewWithdrawalStack:
    stack: DynArray[address, 10]

event ReplacedWithdrawalStackIndex:
    old_strategy: indexed(address)
    new_strategy: indexed(address)

struct StrategyParams:
    activation: uint256
    last_report: uint256
    current_debt: uint256
    max_debt: uint256

name: public(String[64])
governance: public(address)
pending_governance: public(address)

MAX_WITHDRAWAL_STACK_SIZE: constant(uint256) = 10

withdrawal_stack: HashMap[address, DynArray[address, 10]]

@external
def __init__(name: String[64]):
    self.name = name
    self.governance = msg.sender


@internal
def _mint(vault: IVault, to: address, shares: uint256, max_amount_in: uint256) -> uint256:
    self._check_allowance(vault.asset(), vault.address, max_amount_in)
    amount_in: uint256 = vault.mint(shares, to)
    assert amount_in <= max_amount_in, "!max amount"
    return amount_in


@internal
def _deposit(vault: IVault, to: address, amount: uint256, min_shares_out: uint256) -> uint256:
    self._check_allowance(vault.asset(), vault.address, amount)
    shares_out: uint256 = vault.deposit(amount, to)
    assert shares_out >= min_shares_out, "!min shares"
    return shares_out


@internal
def _withdraw(vault: IVault, to: address, amount: uint256, max_shares_in: uint256) -> uint256:
    shares_in: uint256 = vault.withdraw(amount, to, msg.sender, self.withdrawal_stack[vault.address])
    assert shares_in <= max_shares_in, "!max shares"
    return shares_in


@internal 
def _redeem(vault: IVault, to: address, shares: uint256, min_amount_out: uint256) -> uint256:
    amount_out: uint256 = vault.redeem(shares, to, msg.sender, self.withdrawal_stack[vault.address])
    assert amount_out >= min_amount_out, "!min out"
    return amount_out


@external
def deposit(
    vault: IVault,
    amount: uint256 = max_value(uint256),
    to: address = msg.sender,
    min_shares_out: uint256 = 0
) -> uint256:
    """
    External deposit function for any 4626 compliant vault.
    Will pull the funds from sender and deposit into the vault with "to" as the recepient
    """
    asset: address = vault.asset()
    to_deposit: uint256 = amount
    if to_deposit == max_value(uint256):
        to_deposit = ERC20(asset).balanceOf(msg.sender)

    self._erc20_safe_transfer_from(asset, msg.sender, self, to_deposit)
    return self._deposit(vault, to, to_deposit, min_shares_out)


@external
def mint(
    vault: IVault,
    shares: uint256 = max_value(uint256),
    to: address = msg.sender,
    max_amount_in: uint256 = 0
) -> uint256:
    """
    External mint function for any 4626 compliant vault.
    Will pull the funds from sender and deposit into the vault with "to" as the recepient
    any excess funds pulled that were not needed should be swept back to sender 
    """
    asset: address = vault.asset()
    to_mint: uint256 = shares
    to_transfer: uint256 = max_amount_in
    if to_mint == max_value(uint256):
        to_transfer = ERC20(asset).balanceOf(msg.sender)
        to_mint = vault.convertToShares(to_transfer)

    if to_transfer == 0:
        to_transfer = vault.convertToAssets(to_mint)

    self._erc20_safe_transfer_from(asset, msg.sender, self, to_transfer)
    # todo need to allow for sweeps or refund
    return self._mint(vault, to, to_mint, to_transfer)


@external
def withdraw(
    vault: IVault,
    amount: uint256 = max_value(uint256),
    to: address = msg.sender,
    max_shares_in: uint256 = 0
) -> uint256:
    to_withdraw: uint256 = amount
    to_burn: uint256 = max_shares_in
    if to_withdraw == max_value(uint256):
        to_burn =  vault.balanceOf(msg.sender)
        to_withdraw = vault.convertToAssets(to_burn)

    return self._withdraw(vault, to, to_withdraw, to_burn)


@external
def redeem(
    vault: IVault,
    shares: uint256 = max_value(uint256),
    to: address = msg.sender,
    min_amount_out: uint256 = 0
) -> uint256:
    to_redeem: uint256 = shares
    if to_redeem == max_value(uint256):
        to_redeem = vault.balanceOf(msg.sender)

    return self._redeem(vault, to, to_redeem, min_amount_out)


@internal
def _check_allowance(token: address, contract: address, amount: uint256):
    """
    To be called before depositing into a vault to assure there is enough allowance for the deposit.
    This should only have to be called once for each vault.
    """
    if ERC20(token).allowance(self, contract) < amount:
        self._erc20_safe_approve(token, contract, 0)
        self._erc20_safe_approve(token, contract, max_value(uint256))


@internal
def _erc20_safe_approve(token: address, spender: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # HACK: Used to handle non-compliant tokens like USDT
    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("approve(address,uint256)"),
            convert(spender, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) > 0:
        assert convert(response, bool), "Transfer failed!"


@internal
def _erc20_safe_transfer_from(token: address, sender: address, receiver: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # HACK: Used to handle non-compliant tokens like USDT
    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transferFrom(address,address,uint256)"),
            convert(sender, bytes32),
            convert(receiver, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) > 0:
        assert convert(response, bool), "Transfer failed!"


@internal
def _erc20_safe_transfer(token: address, receiver: address, amount: uint256):
    # Used only to send tokens that are not the type managed by this Vault.
    # HACK: Used to handle non-compliant tokens like USDT
    response: Bytes[32] = raw_call(
        token,
        concat(
            method_id("transfer(address,uint256)"),
            convert(receiver, bytes32),
            convert(amount, bytes32),
        ),
        max_outsize=32,
    )
    if len(response) > 0:
        assert convert(response, bool), "Transfer failed!"


@internal
def _add_strategy(vault: address, strategy: address):
    # we assume the vault has checked what needs to be
    assert IVault(vault).strategies(strategy).activation != 0, "inactive strategy"
    
    # make sure we have room left
    assert len(self.withdrawal_stack[vault]) < MAX_WITHDRAWAL_STACK_SIZE, "stack full"

    # append strategy to the end of the array
    self.withdrawal_stack[vault].append(strategy)

    log StrategyAdded(vault, strategy)


@internal
def _remove_strategy(vault: address, strategy: address):
    """
    Internal function used to remove a strategy from the withdrawal stack for a specific vault.
    Iterates throuhg the withdrawal stack until it finds the strategy, then replaces it with the last strategy
    in the stack and then pops the last strategy off the stack. This will revert if the strategy is not in the stack.
    """
    current_strategies: DynArray[address, MAX_WITHDRAWAL_STACK_SIZE] = self.withdrawal_stack[vault]

    for idx in range(MAX_WITHDRAWAL_STACK_SIZE):
        _strategy: address = current_strategies[idx]
        if _strategy == strategy:
            if idx != len(current_strategies) - 1:
                # if it isn't already the last strategy, swap the last stategy with the one to remove
                strategy_to_swap: address = current_strategies[len(current_strategies) - 1]
                current_strategies[idx] = strategy_to_swap
            
            # remove the last one off the stack
            current_strategies.pop()
            # store the updated stack
            self.withdrawal_stack[vault] = current_strategies

            log StrategyRemoved(vault, strategy)
            break
    

@internal
def _replace_withdrawal_stack_index(vault: address, idx: uint256, new_strategy: address):
    assert IVault(vault).strategies(new_strategy).activation != 0, "inactive strategy"

    old_strategy: address = self.withdrawal_stack[vault][idx]
    assert old_strategy != new_strategy, "same strategy"

    self.withdrawal_stack[vault][idx] = new_strategy

    log ReplacedWithdrawalStackIndex(old_strategy, new_strategy)


@external
def set_governance(new_governance: address):
    assert msg.sender == self.governance, "!auth"
    log NewPendingGovernance(new_governance)
    self.pending_governance = new_governance


@external
def accept_governance():
    assert msg.sender == self.pending_governance, "!auth"
    self.governance = msg.sender
    log UpdateGovernance(msg.sender)
    self.pending_governance = ZERO_ADDRESS


@external
def addStrategy(vault: address, strategy: address):
    assert msg.sender == self.governance, "!auth"
    self._add_strategy(vault, strategy)


@external
def removeStrategy(vault: address, strategy: address):
    assert msg.sender == self.governance, "!auth"
    self._remove_strategy(vault, strategy)


@external 
def setWithdrawalStack(vault: address, stack: DynArray[address, MAX_WITHDRAWAL_STACK_SIZE]):
    assert msg.sender == self.governance, "!auth"
    self.withdrawal_stack[vault] = stack
    log NewWithdrawalStack(stack)


@external 
def replaceWithdrawalStackIndex(vault: address, idx: uint256, new_strategy: address):
    assert msg.sender == self.governance, "!auth"
    self._replace_withdrawal_stack_index(vault, idx, new_strategy)


@view
@external 
def withdrawalStackLength(vault: address) -> uint256:
    return len(self.withdrawal_stack[vault])


@view
@external
def vaultWithrawalStack(vault: address) -> DynArray[address, 10]:
    """
    Function to return the current withdrawal stack of strategies for a given vault
    """
    return self.withdrawal_stack[vault]