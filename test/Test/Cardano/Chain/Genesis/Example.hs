{-# LANGUAGE DataKinds                 #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE TypeApplications          #-}

module Test.Cardano.Chain.Genesis.Example
  ( exampleGenesisAvvmBalances
  , exampleStaticConfig_GCSpec
  , exampleStaticConfig_GCSrc
  , exampleGenesisDelegation
  , exampleGenesisInitializer
  , exampleProtocolConstants
  )
where

import Cardano.Prelude

import qualified Data.ByteString.Base16 as B16
import Data.Either (fromRight)
import qualified Data.Map.Strict as M
import Data.Maybe (fromJust)

import Cardano.Binary.Class (Raw(..))
import Cardano.Chain.Common
  ( LovelacePortion(..)
  , SharedSeed(..)
  , StakeholderId(..)
  , addressHash
  , mkKnownLovelace
  )
import Cardano.Chain.Delegation (HeavyDlgIndex(..))
import Cardano.Chain.Genesis
  ( FakeAvvmOptions(..)
  , GenesisAvvmBalances(..)
  , GenesisDelegation(..)
  , GenesisInitializer(..)
  , GenesisProtocolConstants(..)
  , GenesisSpec(..)
  , StaticConfig(..)
  , TestnetBalanceOptions(..)
  )
import Cardano.Chain.ProtocolConstants (VssMaxTTL(..), VssMinTTL(..))
import Cardano.Chain.Slotting (EpochIndex(..))
import Cardano.Crypto
  ( ProtocolMagic(..)
  , ProxyCert(..)
  , ProxySecretKey(..)
  , RedeemPublicKey
  , abstractHash
  , redeemDeterministicKeyGen
  )
import Cardano.Crypto.Signing (PublicKey(..))
import qualified Cardano.Crypto.Wallet as CC

import Test.Cardano.Chain.Update.Example (exampleBlockVersionData)
import Test.Cardano.Crypto.Bi (getBytes)

exampleSharedSeed :: SharedSeed
exampleSharedSeed = SharedSeed (getBytes 8 32)

exampleStaticConfig_GCSrc :: StaticConfig
exampleStaticConfig_GCSrc =
  GCSrc "dRaMwdYsH3QA3dChe" (abstractHash (Raw "Test"))

exampleStaticConfig_GCSpec :: StaticConfig
exampleStaticConfig_GCSpec = GCSpec $ UnsafeGenesisSpec
  exampleGenesisAvvmBalances
  exampleSharedSeed
  exampleGenesisDelegation
  exampleBlockVersionData
  exampleProtocolConstants
  exampleGenesisInitializer

exampleGenesisAvvmBalances :: GenesisAvvmBalances
exampleGenesisAvvmBalances = GenesisAvvmBalances
  { getGenesisAvvmBalances = M.fromList
    [ (exampleRedeemPublicKey' (0, 32) , mkKnownLovelace @36524597913081152)
    , (exampleRedeemPublicKey' (32, 32), mkKnownLovelace @37343863242999412)
    ]
  }
 where
  exampleRedeemPublicKey' :: (Int, Int) -> RedeemPublicKey
  exampleRedeemPublicKey' (m, n) =
    fromJust (fst <$> redeemDeterministicKeyGen (getBytes m n))

exampleGenesisDelegation :: GenesisDelegation
exampleGenesisDelegation = UnsafeGenesisDelegation
  (M.fromList
    [ ( StakeholderId $ addressHash issuePubKey
      , UnsafeProxySecretKey
        { pskOmega      = HeavyDlgIndex $ EpochIndex 68300481033
        , pskIssuerPk   = issuePubKey
        , pskDelegatePk = PublicKey
          (CC.XPub
            { CC.xpubPublicKey = pskDelPubKey
            , CC.xpubChaincode = pskDelChainCode
            }
          )
        , pskCert = ProxyCert (fromRight (panic "Something went wrong") $ sig)
        }
      )
    ]
  )
 where
  issuePubKey = PublicKey
    (CC.XPub {CC.xpubPublicKey = pskPubKey, CC.xpubChaincode = pskChainCode})
  sig = CC.xsignature
    (hexToBS
      "bae5422af5405e3803154a4ad986da5d14cf624d670\
                                 \1c5c78a79ec73777f74e13973af83752114d9f18166\
                                 \085997fc81e432cab7fee99a275d8bf138ad04e103"
    )
  pskPubKey =
    hexToBS
      "e2a1773a2a82d10c30890cbf84eccbdc1aaaee920496424d36e8\
                        \68039d9cb519"
  pskChainCode = CC.ChainCode
    (hexToBS
      "21b25efe033d9b00d4f02ccd9cdabcec332\
                                         \abbc6fdf883ca5bf3a8aff4aac27e"
    )
  pskDelPubKey =
    hexToBS
      "ddca69bfeac14c013304da88ac032ee63281ab036c1b1b918\
                           \8e4b174b303f43e"
  pskDelChainCode = CC.ChainCode
    (hexToBS
      "55163b178e999b9fd50637b2edab8c85\
                                            \8a879ac3c4bd3e610095419a19696573"
    )

exampleProtocolConstants :: GenesisProtocolConstants
exampleProtocolConstants = GenesisProtocolConstants
  { gpcK             = 37
  , gpcProtocolMagic = ProtocolMagic {getProtocolMagic = 1783847074}
  , gpcVssMaxTTL     = VssMaxTTL {getVssMaxTTL = 1477558317}
  , gpcVssMinTTL     = VssMinTTL {getVssMinTTL = 744040476}
  }

exampleGenesisInitializer :: GenesisInitializer
exampleGenesisInitializer = GenesisInitializer
  { giTestBalance       = TestnetBalanceOptions
    { tboPoors          = 2448641325904532856
    , tboRichmen        = 14071205313513960321
    , tboTotalBalance   = 10953275486128625216
    , tboRichmenShare   = 4.2098713311249885
    , tboUseHDAddresses = True
    }
  , giFakeAvvmBalance   = FakeAvvmOptions
    { faoCount      = 17853231730478779264
    , faoOneBalance = 15087947214890024355
    }
  , giAvvmBalanceFactor = LovelacePortion {getLovelacePortion = 366832547637728}
  , giUseHeavyDlg       = False
  , giSeed              = 0
  }

hexToBS :: ByteString -> ByteString
hexToBS ts = case B16.decode ts of
  (fullyDecoded, "") -> fullyDecoded
  (partiallyDecoded, invalid) ->
    panic
      $  "successfully decoded: "
      <> show partiallyDecoded
      <> " decode failed: "
      <> show invalid

