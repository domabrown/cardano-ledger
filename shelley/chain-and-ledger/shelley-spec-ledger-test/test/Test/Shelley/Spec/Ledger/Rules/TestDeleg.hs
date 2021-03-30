{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Test.Shelley.Spec.Ledger.Rules.TestDeleg
  ( keyRegistration,
    keyDeRegistration,
    keyDelegation,
    rewardsSumInvariant,
    checkInstantaneousRewards,
  )
where

import Cardano.Ledger.Coin (addDeltaCoin, pattern Coin)
import Control.SetAlgebra (dom, eval, rng, (∈), (∉), (◁))
import Control.State.Transition.Trace
  ( SourceSignalTarget,
    signal,
    source,
    target,
    pattern SourceSignalTarget,
  )
import Data.Foldable (fold)
import Data.List (foldl')
import qualified Data.Map.Strict as Map (difference, filter, keysSet, lookup, (\\))
import qualified Data.Set as Set (isSubsetOf, singleton, size)
import Shelley.Spec.Ledger.API (DELEG)
import Shelley.Spec.Ledger.LedgerState
  ( DState (..),
    InstantaneousRewards (..),
  )
import Shelley.Spec.Ledger.TxBody
  ( MIRPot (..),
    MIRTarget (..),
    pattern DCertDeleg,
    pattern DCertMir,
    pattern DeRegKey,
    pattern Delegate,
    pattern Delegation,
    pattern MIRCert,
    pattern RegKey,
  )
import Test.QuickCheck (Property, conjoin, counterexample, property)

-- | Check stake key registration
keyRegistration :: SourceSignalTarget (DELEG era) -> Property
keyRegistration
  SourceSignalTarget
    { signal = (DCertDeleg (RegKey hk)),
      target = targetSt
    } =
    conjoin
      [ counterexample
          "a newly registered key should have a reward account"
          ((eval (hk ∈ dom (_rewards targetSt))) :: Bool),
        counterexample
          "a newly registered key should have a reward account with 0 balance"
          (Map.lookup hk (_rewards targetSt) == Just mempty)
      ]
keyRegistration _ = property ()

-- | Check stake key de-registration
keyDeRegistration :: SourceSignalTarget (DELEG era) -> Property
keyDeRegistration
  SourceSignalTarget
    { signal = (DCertDeleg (DeRegKey hk)),
      target = targetSt
    } =
    conjoin
      [ counterexample
          "a deregistered stake key should no longer be in the rewards mapping"
          ((eval (hk ∉ dom (_rewards targetSt))) :: Bool),
        counterexample
          "a deregistered stake key should no longer be in the delegations mapping"
          ((eval (hk ∉ dom (_delegations targetSt))) :: Bool)
      ]
keyDeRegistration _ = property ()

-- | Check stake key delegation
keyDelegation :: SourceSignalTarget (DELEG era) -> Property
keyDelegation
  SourceSignalTarget
    { signal = (DCertDeleg (Delegate (Delegation from to))),
      target = targetSt
    } =
    let fromImage = eval (rng (Set.singleton from ◁ _delegations targetSt))
     in conjoin
          [ counterexample
              "a delegated key should have a reward account"
              ((eval (from ∈ dom (_rewards targetSt))) :: Bool),
            counterexample
              "a registered stake credential should be delegated"
              ((eval (to ∈ fromImage)) :: Bool),
            counterexample
              "a registered stake credential should be uniquely delegated"
              (Set.size fromImage == 1)
          ]
keyDelegation _ = property ()

-- | Check that the sum of rewards does not change and that each element
-- that is either removed or added has a zero balance.
rewardsSumInvariant :: SourceSignalTarget (DELEG era) -> Property
rewardsSumInvariant
  SourceSignalTarget {source, target} =
    let sourceRewards = _rewards source
        targetRewards = _rewards target
        rewardsSum = foldl' (<>) mempty
     in conjoin
          [ counterexample
              "sum of rewards should not change"
              (rewardsSum sourceRewards == rewardsSum targetRewards),
            counterexample
              "dropped elements have a zero reward balance"
              (null (Map.filter (/= Coin 0) $ sourceRewards `Map.difference` targetRewards)),
            counterexample
              "added elements have a zero reward balance"
              (null (Map.filter (/= Coin 0) $ targetRewards `Map.difference` sourceRewards))
          ]

checkInstantaneousRewards :: SourceSignalTarget (DELEG era) -> Property
checkInstantaneousRewards
  SourceSignalTarget {source, signal, target} =
    case signal of
      DCertMir (MIRCert ReservesMIR (StakeAddressesMIR irwd)) ->
        conjoin
          [ counterexample
              "a ReservesMIR certificate should add all entries to the `irwd` mapping"
              (Map.keysSet irwd `Set.isSubsetOf` Map.keysSet (iRReserves $ _irwd target)),
            counterexample
              "a ReservesMIR certificate should add the total value to the `irwd` map, overwriting any existing entries"
              ( (fold $ (iRReserves $ _irwd source) Map.\\ irwd)
                  `addDeltaCoin` (fold irwd)
                  == (fold $ (iRReserves $ _irwd target))
              )
          ]
      DCertMir (MIRCert TreasuryMIR (StakeAddressesMIR irwd)) ->
        conjoin
          [ counterexample
              "a TreasuryMIR certificate should add all entries to the `irwd` mapping"
              (Map.keysSet irwd `Set.isSubsetOf` Map.keysSet (iRTreasury $ _irwd target)),
            counterexample
              "a TreasuryMIR certificate should add the total value to the `irwd` map, overwriting any existing entries"
              ( (fold $ (iRTreasury $ _irwd source) Map.\\ irwd)
                  `addDeltaCoin` (fold irwd)
                  == (fold $ (iRTreasury $ _irwd target))
              )
          ]
      _ -> property ()
