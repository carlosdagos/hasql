module Hasql.Core.ParseMessage where

import Hasql.Prelude
import Hasql.Core.Model hiding (Error(..))
import qualified Hasql.Core.ChooseMessage as B
import qualified Hasql.Core.MessageTypePredicates as G
import qualified Hasql.Core.ParseDataRow as F
import qualified Hasql.Protocol.Decoding as E
import qualified Hasql.Protocol.Model as A
import qualified BinaryParser as D


{-|
Interpreter of a single message.
-}
newtype ParseMessage result =
  ParseMessage (Compose B.ChooseMessage (Either Error) result)
  deriving (Functor, Applicative, Alternative)

data Error =
  ParsingError !Text !Text

{-# INLINE chooseMessage #-}
chooseMessage :: B.ChooseMessage (Either Error result) -> ParseMessage result
chooseMessage =
  ParseMessage . Compose

{-# INLINE payloadFn #-}
payloadFn :: (Word8 -> Bool) -> (ByteString -> Either Error result) -> ParseMessage result
payloadFn predicate payloadFn =
  chooseMessage (B.payloadFn predicate payloadFn)

{-# INLINE payloadParser #-}
payloadParser :: (Word8 -> Bool) -> Text -> D.BinaryParser parsed -> ParseMessage parsed
payloadParser predicate context parser =
  payloadFn predicate (either (Left . ParsingError context) Right . D.run parser)

{-# INLINE withoutPayload #-}
withoutPayload :: (Word8 -> Bool) -> ParseMessage ()
withoutPayload predicate =
  payloadFn predicate (const (Right ()))

{-# INLINE error #-}
error :: ParseMessage ErrorMessage
error =
  payloadParser G.error "ErrorResponse" (E.errorMessage ErrorMessage)

{-# INLINE errorCont #-}
errorCont :: (ByteString -> ByteString -> result) -> ParseMessage result
errorCont message =
  payloadParser G.error "ErrorResponse" (E.errorMessage message)

{-# INLINE notification #-}
notification :: ParseMessage Notification
notification =
  payloadParser G.notification "NotificationResponse" (E.notificationMessage Notification)

{-# INLINE dataRow #-}
dataRow :: F.ParseDataRow row -> ParseMessage row
dataRow =
  payloadParser G.dataRow "DataRow" . E.parseDataRow

{-# INLINE dataRowWithoutData #-}
dataRowWithoutData :: ParseMessage ()
dataRowWithoutData =
  withoutPayload G.dataRow

{-# INLINE commandComplete #-}
commandComplete :: ParseMessage Int
commandComplete =
  payloadParser G.commandComplete "CommandComplete" E.commandCompleteMessageAffectedRows

{-# INLINE commandCompleteWithoutAmount #-}
commandCompleteWithoutAmount :: ParseMessage ()
commandCompleteWithoutAmount =
  withoutPayload G.commandComplete

{-# INLINE bindComplete #-}
bindComplete :: ParseMessage ()
bindComplete =
  withoutPayload G.bindComplete

{-# INLINE parseComplete #-}
parseComplete :: ParseMessage ()
parseComplete =
  withoutPayload G.parseComplete

{-# INLINE readyForQuery #-}
readyForQuery :: ParseMessage ()
readyForQuery =
  withoutPayload G.readyForQuery

{-# INLINE emptyQuery #-}
emptyQuery :: ParseMessage ()
emptyQuery =
  withoutPayload G.emptyQuery

{-# INLINE portalSuspended #-}
portalSuspended :: ParseMessage ()
portalSuspended =
  withoutPayload G.portalSuspended

{-# INLINE authentication #-}
authentication :: ParseMessage A.AuthenticationMessage
authentication =
  payloadParser G.authentication "AuthenticationMessage" E.authenticationMessage

{-# INLINE parameterStatus #-}
parameterStatus :: ParseMessage (ByteString, ByteString)
parameterStatus =
  payloadParser G.parameterStatus "ParameterStatus" (E.parameterStatusMessagePayloadKeyValue (,))
