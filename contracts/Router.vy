# @version 0.3.7

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

MAX_WITHDRAWAL_STACK_SIZE: constant(uint256) = 10

withdrawal_stack: HashMap[address, DynArray[address, 10]]

@external
def __init__(name: String[64]):
    self.name = name
    self.governance = msg.sender


@internal
def add_strategy(vault: address, strategy: address):
    # we assume the vault has checked what needs to be
    assert IVault(vault).strategies(strategy).activation != 0, "inactive strategy"

    # make sure we have room left
    assert len(self.withdrawal_stack[vault]) < MAX_WITHDRAWAL_STACK_SIZE, "stack full"

    # append strategy to the end of the array
    self.withdrawal_stack[vault].append(strategy)

    log StrategyAdded(vault, strategy)


@internal
def remove_strategy(vault: address, strategy: address):
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
            self.withdrawal_stack[vault] = current_strategies

            log StrategyRemoved(vault, strategy)
            break
    

@internal
def replace_withdrawal_stack_index(vault: address, idx: uint256, new_strategy: address):
    assert IVault(vault).strategies(new_strategy).activation != 0, "inactive strategy"

    old_strategy: address = self.withdrawal_stack[vault][idx]
    assert old_strategy != new_strategy, "same strategy"

    self.withdrawal_stack[vault][idx] = new_strategy

    log ReplacedWithdrawalStackIndex(old_strategy, new_strategy)


@external
def addStrategy(vault: address, strategy: address):
    assert msg.sender == self.governance, "!auth"
    self.add_strategy(vault, strategy)


@external
def removeStrategy(vault: address, strategy: address):
    assert msg.sender == self.governance, "!auth"
    self.remove_strategy(vault, strategy)


@external 
def setWithdrawalStack(vault: address, stack: DynArray[address, MAX_WITHDRAWAL_STACK_SIZE]):
    assert msg.sender == self.governance, "!auth"
    self.withdrawal_stack[vault] = stack
    log NewWithdrawalStack(stack)


@external 
def replaceWithdrawalStackIndex(vault: address, idx: uint256, new_strategy: address):
    assert msg.sender == self.governance, "!auth"
    self.replace_withdrawal_stack_index(vault, idx, new_strategy)


@view
@external 
def withdrawalStackLength(vault: address) -> uint256:
    return len(self.withdrawal_stack[vault])


@view
@external
def vaultWithrawalStack(vault: address) -> DynArray[address, 10]:
    """
    Function to return the stored array of strategies for a given vault
    """
    return self.withdrawal_stack[vault]