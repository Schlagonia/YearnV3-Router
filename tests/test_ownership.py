from ape import chain, project, reverts
from utils.constants import ZERO_ADDRESS


def test_gov_transfers_ownership(router, gov, strategist):
    assert router.governance() == gov
    assert router.pending_governance() == ZERO_ADDRESS

    router.set_governance(strategist, sender=gov)

    assert router.governance() == gov
    assert router.pending_governance() == strategist

    router.accept_governance(sender=strategist)

    assert router.governance() == strategist
    assert router.pending_governance() == ZERO_ADDRESS


def test_gov_transfers_ownership__gov_cant_accept(router, gov, strategist):
    assert router.governance() == gov
    assert router.pending_governance() == ZERO_ADDRESS

    router.set_governance(strategist, sender=gov)

    assert router.governance() == gov
    assert router.pending_governance() == strategist

    with reverts("!auth"):
        router.accept_governance(sender=gov)

    assert router.governance() == gov
    assert router.pending_governance() == strategist


def test_random_transfers_ownership__fails(router, gov, strategist):
    assert router.governance() == gov
    assert router.pending_governance() == ZERO_ADDRESS

    with reverts("!auth"):
        router.set_governance(strategist, sender=strategist)

    assert router.governance() == gov
    assert router.pending_governance() == ZERO_ADDRESS


def test_gov_transfers_ownership__can_change_pending(router, gov, user, strategist):
    assert router.governance() == gov
    assert router.pending_governance() == ZERO_ADDRESS

    router.set_governance(strategist, sender=gov)

    assert router.governance() == gov
    assert router.pending_governance() == strategist

    router.set_governance(user, sender=gov)

    assert router.governance() == gov
    assert router.pending_governance() == user

    with reverts("!auth"):
        router.accept_governance(sender=strategist)

    router.accept_governance(sender=user)

    assert router.governance() == user
    assert router.pending_governance() == ZERO_ADDRESS
