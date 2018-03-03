{-# LANGUAGE AllowAmbiguousTypes       #-}
{-# LANGUAGE DeriveGeneric             #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE OverloadedStrings         #-}
{-# LANGUAGE RankNTypes                #-}
{-# LANGUAGE TypeFamilies              #-}

module Types where

import           Data.Aeson
import           Data.Aeson.Types
import           Data.Hashable
import           Data.Maybe
import           Data.Text.Lazy
import qualified Data.Text.Lazy                    as TL
import           GHC.Generics
import           Network.HTTP.Conduit
import           Network.OAuth.OAuth2
import qualified Network.OAuth.OAuth2.TokenRequest as TR
import           Text.Mustache
import qualified Text.Mustache                     as M
import           URI.ByteString
import           Data.ByteString      (ByteString)
import qualified Data.Text.Encoding   as TE
import qualified Data.HashMap.Strict     as Map
import           Control.Concurrent.MVar

type IDPLabel = Text

-- TODO: how to make following type work??
-- type CacheStore = forall a. IDP a => MVar (Map.HashMap a IDPData)
type CacheStore = MVar (Map.HashMap IDPLabel IDPData)

-- * type class for defining a IDP
--
class (Hashable a, Show a) => IDP a

class (IDP a) => HasLabel a where
  idpLabel :: a -> IDPLabel
  idpLabel = TL.pack . show

class (IDP a) => HasAuthUri a where
  authUri :: a -> Text
    
class (IDP a) => HasTokenReq a where
  tokenReq :: a -> Manager -> ExchangeToken -> IO (OAuth2Result TR.Errors OAuth2Token)

class (IDP a) => HasUserReq a where
  userReq :: FromJSON b => a -> Manager -> AccessToken -> IO (OAuth2Result b LoginUser)

createCodeUri :: OAuth2
  -> [(ByteString, ByteString)]
  -> Text
createCodeUri key params = TL.fromStrict $ TE.decodeUtf8 $ serializeURIRef'
  $ appendQueryParams params
  $ authorizationUrl key


-- dummy oauth2 request error
--
data Errors =
  SomeRandomError
  deriving (Show, Eq, Generic)

instance FromJSON Errors where
  parseJSON = genericParseJSON defaultOptions { constructorTagModifier = camelTo2 '_', allNullaryToStringTag = True }

newtype LoginUser =
  LoginUser { loginUserName :: Text
            } deriving (Eq, Show)

data IDPData =
  IDPData { codeFlowUri :: Text
          , loginUser   :: Maybe LoginUser
          , idpDisplayLabel     :: IDPLabel
          }

-- simplify use case to only allow one idp instance for now.
instance Eq IDPData where
  a == b = idpDisplayLabel a == idpDisplayLabel b

newtype TemplateData = TemplateData { idpData :: [IDPData]
                                    } deriving (Eq)

-- * Mustache instances
instance ToMustache IDPData where
  toMustache t' = M.object
    [ "codeFlowUri" ~> codeFlowUri t'
    , "isLogin" ~> isJust (loginUser t')
    , "user" ~> loginUser t'
    , "name" ~> TL.unpack (idpDisplayLabel t')
    ]

instance ToMustache LoginUser where
  toMustache t' = M.object
    [ "name" ~> loginUserName t' ]

instance ToMustache TemplateData where
  toMustache td' = M.object
    [ "idps" ~> idpData td'
    ]
