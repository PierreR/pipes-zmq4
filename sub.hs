{-# LANGUAGE RankNTypes #-}

module Main
where

import Pipes
import Pipes.Parse (Parser, isEndOfInput, evalStateT)
import qualified Pipes.Parse as PP
import qualified Pipes.ZMQ4 as PZ
import qualified System.ZMQ4 as Z

import Control.Concurrent(threadDelay)
import Control.Concurrent.Async
import Control.Monad (forever, unless)
import Control.Applicative((<$>), (<*>))
import Control.Lens(zoom)
import qualified Control.Foldl as L

import Data.ByteString.Char8 (pack, unpack)
import Text.Printf
import System.Random (randomRIO)

pubServerThread :: Z.Sender t => Z.Socket t -> IO r
pubServerThread s = forever $ do
    threadDelay (25) -- be gentle with the CPU
    zipcode <- randomRIO (10000::Int, 11000)
    temperature <- randomRIO (-10::Int, 35)
    humidity <- randomRIO (10::Int, 60)
    let update = pack $ unwords [show zipcode, show temperature, show humidity]
    Z.send s [] update

-- | This function will be part of foldl later on
--   @fold (premap f folder) list == fold folder (map f list)@
premap :: (a -> b) -> L.Fold b r -> L.Fold a r
premap f (L.Fold step begin done) = L.Fold step' begin done
  where
    step' x = step x . f

average :: L.Fold Int Int
average = div <$> L.sum <*> L.length

main :: IO ()
main = do
    -- create and use exactly one context in a single process
    Z.withContext $ \ctx ->
        Z.withSocket ctx Z.Pub $ \pubSocket ->
        Z.withSocket ctx Z.Sub $ \subSocket -> do

            Z.bind pubSocket "inproc://pubserver"
            putStrLn "Starting pub server"
            async $ pubServerThread pubSocket

            Z.connect subSocket "inproc://pubserver"
            Z.subscribe subSocket (pack "10001")

            evalStateT reportParser (processedData subSocket)
    where

        reportParser :: Parser (Int, Int, Int) IO ()
        reportParser = loop
            where
                loop = do
                    (avgTemp, avgHum) <- zoom (PP.splitAt 10) (L.purely PP.foldAll averages)
                    liftIO $ printf "-- Report: average temperature is %d°C, average humidity is %d%% \n" avgTemp avgHum
                    eof <- isEndOfInput
                    unless eof loop

        averages :: L.Fold (Int, Int, Int) (Int, Int)
        averages =
            let avgTemp :: L.Fold (Int, Int, Int) Int
                avgTemp = premap (\(_, t, _) -> t) average

                avgHumidity :: L.Fold (Int, Int, Int) Int
                avgHumidity = premap (\(_, _, h) -> h) average

            in  (,) <$> avgTemp <*> avgHumidity

        processedData :: Z.Socket Z.Sub -> Producer (Int, Int, Int) IO ()
        processedData subSocket = for (PZ.fromZMQ subSocket) $ \bs -> do
            let [zipcode, temperature, humidity] = map read $ words (unpack bs)
            liftIO $ printf "At NY City (%d), temperature of %d and humidity %d\n"  zipcode temperature humidity
            yield (zipcode, temperature, humidity)





