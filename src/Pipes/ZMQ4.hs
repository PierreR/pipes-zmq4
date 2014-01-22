{-# LANGUAGE RankNTypes #-}

module Pipes.ZMQ4 (
	fromZMQ,
    request
    ) where

import qualified Data.ByteString as B

import Pipes
import qualified System.ZMQ4 as Z
import Control.Monad (forever, unless)


{-| Send upstream bytes into a request socket,
    wait/block and yield the reply
-}
request :: MonadIO m => Z.Socket Z.Req -> Pipe B.ByteString B.ByteString m ()
request sock = for cat $ \b -> do
    rep <- liftIO (Z.send sock [] b >> Z.receive sock)
    unless (B.null rep) $ yield rep

{-| Wait for a msg from a receiver 'Z.Socket' and yield it
-}
fromZMQ :: (MonadIO m, Z.Receiver t)  => Z.Socket t -> Producer' B.ByteString m ()
fromZMQ sock  = forever $ do
    bs <- liftIO (Z.receive sock)
    unless (B.null bs) $ yield bs