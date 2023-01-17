from ape import chain, project, reverts
from utils.constants import ZERO_ADDRESS

def test_add_strategy(create_vault_and_strategy, create_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)
    router = gov.deploy(project.Router, "YearnV3 Router 0.0.1")

    assert router.withdrawalStackLength(vault) == 0

    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_strategy(vault)
    vault.add_strategy(second_strategy, sender=gov)

    router.addStrategy(vault, second_strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 2
    assert router.vaultWithrawalStack(vault)[0] == strategy
    assert router.vaultWithrawalStack(vault)[1] == second_strategy


def test_add_strategy__not_added_to_vault__fails(router, vault, create_strategy, gov):
    strategy = create_strategy(vault)

    with reverts("inactive strategy"):
        router.addStrategy(vault, strategy, sender=gov)


def test_add_strategy__not_gov__fails(router, create_vault_and_strategy, gov, user, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)

    with reverts("!auth"):
        router.addStrategy(vault, strategy, sender=user)


def test_add_strategy__stack_full__fails(router, vault, create_strategy, gov, amount):

    for idx in range(10):
        strategy = create_strategy(vault)
        vault.add_strategy(strategy, sender=gov)
        router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 10

    strategy = create_strategy(vault)
    vault.add_strategy(strategy, sender=gov)

    with reverts("stack full"):
        router.addStrategy(vault, strategy, sender=gov)

def test_remove_strategy(router, create_vault_and_strategy, create_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)
    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    router.removeStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 0

def test_remove_strategy__multiple_strategies(router, create_vault_and_strategy, create_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)
    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_strategy(vault)
    vault.add_strategy(second_strategy, sender=gov)
    router.addStrategy(vault, second_strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 2
    assert router.vaultWithrawalStack(vault)[1] == second_strategy

    third_strategy = create_strategy(vault)
    vault.add_strategy(third_strategy, sender=gov)
    router.addStrategy(vault, third_strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 3
    assert router.vaultWithrawalStack(vault)[2] == third_strategy

    router.removeStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 2
    assert router.vaultWithrawalStack(vault)[0] == third_strategy
    assert router.vaultWithrawalStack(vault)[1] == second_strategy

    router.removeStrategy(vault, second_strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == third_strategy

    router.removeStrategy(vault, third_strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 0


def test_remove_strategy__not_gov__fails(router, create_vault_and_strategy, create_strategy, gov, amount, user):
    vault, strategy = create_vault_and_strategy(gov, amount)
    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    with reverts("!auth"):
        router.removeStrategy(vault, strategy, sender=user)

    assert router.withdrawalStackLength(vault) == 1


def test_remove_strategy__not_added__fails(router, create_vault_and_strategy, create_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)

    with reverts():
        router.removeStrategy(vault, strategy, sender=gov)

    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_strategy(vault)
    with reverts():
        router.removeStrategy(vault, second_strategy, sender=gov)


def test_strategies_array_length(router, create_vault_and_strategy, create_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)
    second_strategy = create_strategy(vault)
    vault.add_strategy(second_strategy, sender=gov)

    strats = router.vaultWithrawalStack(vault)
    assert len(strats) == 0
    assert router.withdrawalStackLength(vault) == 0

    router.addStrategy(vault, strategy, sender=gov)

    assert len(router.vaultWithrawalStack(vault)) == 1
    assert router.withdrawalStackLength(vault) == 1

    router.addStrategy(vault, second_strategy, sender=gov)

    assert len(router.vaultWithrawalStack(vault)) == 2
    assert router.withdrawalStackLength(vault) == 2

    router.removeStrategy(vault, strategy, sender=gov)

    assert len(router.vaultWithrawalStack(vault)) == 1
    assert router.withdrawalStackLength(vault) == 1

    router.removeStrategy(vault, second_strategy, sender=gov)

    assert len(router.vaultWithrawalStack(vault)) == 0
    assert router.withdrawalStackLength(vault) == 0


def test_set_new_stack(router, create_vault_and_strategy, create_new_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0

    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_new_strategy(vault)

    router.setWithdrawalStack(vault, [second_strategy], sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == second_strategy

    third_strategy = create_new_strategy(vault)
    fourth_strategy = create_new_strategy(vault)

    router.setWithdrawalStack(
        vault,
        [strategy, second_strategy, third_strategy, fourth_strategy],
        sender=gov
    )

    assert router.withdrawalStackLength(vault) == 4
    assert router.vaultWithrawalStack(vault)[0] == strategy
    assert router.vaultWithrawalStack(vault)[1] == second_strategy
    assert router.vaultWithrawalStack(vault)[2] == third_strategy
    assert router.vaultWithrawalStack(vault)[3] == fourth_strategy

    router.setWithdrawalStack(
        vault,
        [],
        sender=gov
    )

    assert router.withdrawalStackLength(vault) == 0

def test_set_new_stack__not_gov__fails(router, create_vault_and_strategy, create_new_strategy, gov, amount, user):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0

    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_new_strategy(vault)

    with reverts("!auth"):
        router.setWithdrawalStack(vault, [second_strategy], sender=user)


def test_set_new_stack__more_than_max__fails(router, create_vault_and_strategy, create_new_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0
    
    router.addStrategy(vault, strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    bad_stack = []

    for idx in range(11):
        bad_stack.append(create_new_strategy(vault))

    with reverts():
        router.setWithdrawalStack(vault, bad_stack, sender=gov)

def test_replace_index(router, create_vault_and_strategy, add_strategy_to_router, create_new_strategy, gov, amount):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0

    add_strategy_to_router(router, vault, strategy)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_new_strategy(vault)

    router.replaceWithdrawalStackIndex(vault, 0, second_strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == second_strategy

    # fill the whole stack with new strategies
    for idx in range(9):
        add_strategy_to_router(router, vault)

    assert router.withdrawalStackLength(vault) == 10

    new_strategy = create_new_strategy(vault)

    router.replaceWithdrawalStackIndex(vault, 4, new_strategy, sender=gov)

    assert router.withdrawalStackLength(vault) == 10
    assert router.vaultWithrawalStack(vault)[4] == new_strategy


def test_replace_index__not_gov__fails(router, create_vault_and_strategy, add_strategy_to_router, create_new_strategy, gov, amount, user):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0

    add_strategy_to_router(router, vault, strategy)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_new_strategy(vault)

    with reverts("!auth"):
        router.replaceWithdrawalStackIndex(vault, 0, second_strategy, sender=user)

    # fill the whole stack with new strategies
    for idx in range(9):
        add_strategy_to_router(router, vault)

    assert router.withdrawalStackLength(vault) == 10

    new_strategy = create_new_strategy(vault)
    
    with reverts("!auth"):
        router.replaceWithdrawalStackIndex(vault, 4, new_strategy, sender=user)


def test_replace_index__same_strategy__fails(router, create_vault_and_strategy, add_strategy_to_router, gov, amount, user):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0

    add_strategy_to_router(router, vault, strategy)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    with reverts("same strategy"):
        router.replaceWithdrawalStackIndex(vault, 0, strategy, sender=gov)


def test_replace_index__inactive_strategy__fails(router, create_vault_and_strategy, add_strategy_to_router, create_strategy, gov, amount, user):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0

    add_strategy_to_router(router, vault, strategy)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_strategy(vault)

    with reverts("inactive strategy"):
        router.replaceWithdrawalStackIndex(vault, 0, second_strategy, sender=gov)


def test_replace_index__invalid_index__fails(router, create_vault_and_strategy, add_strategy_to_router, create_new_strategy, gov, amount, user):
    vault, strategy = create_vault_and_strategy(gov, amount)
    assert router.withdrawalStackLength(vault) == 0

    add_strategy_to_router(router, vault, strategy)

    assert router.withdrawalStackLength(vault) == 1
    assert router.vaultWithrawalStack(vault)[0] == strategy

    second_strategy = create_new_strategy(vault)

    with reverts():
        router.replaceWithdrawalStackIndex(vault, 4, second_strategy, sender=gov)