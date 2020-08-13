module MTix where

import System.FilePath

import Trace.Hpc.Tix
import Trace.Hpc.Util (HpcPos, fromHpcPos, writeFileUtf8, Hash)

------------------------------------------------------------------------------
-- a Tix variant with multiple tickers

type TicksCount = [(String,Integer)]

showTicksCount ticks =
  "Ticks per property: " <>
  concat (fmap (\(s,n) -> "&#10" <> s <> " : " <> show n <> " ticks") ticks)

data MTix = MTix [MTixModule]
  deriving (Eq, Show, Read)

data MTixModule = MTixModule String Hash Int [TicksCount]
  deriving (Eq, Show, Read)

mtixModuleName :: MTixModule -> String
mtixModuleName (MTixModule nm _ _ _) = nm

mtixModuleHash :: MTixModule -> Hash
mtixModuleHash (MTixModule _ h  _ _) = h

mtixModuleTixs :: MTixModule -> [TicksCount]
mtixModuleTixs (MTixModule  _ _ _ tixs) = tixs

readMTixs :: [FilePath] -> IO [MTix]
readMTixs = mapM readMTix

readMTix :: FilePath -> IO MTix
readMTix file = do
  mtix <- readTix file
  case mtix of
    Nothing -> error $ "error reading tix file from: " ++ file
    Just a -> return (tixToMTix (takeBaseName file) a)

tixToMTix :: String -> Tix -> MTix
tixToMTix ticker (Tix xs) =
  MTix (toMTixModule <$> xs)
  where
    toMTixModule (TixModule n h i ticks) = MTixModule n h i (addTicker <$> ticks)
    addTicker x = [(ticker, x)]

mergeMTixs :: [MTix] -> MTix
mergeMTixs [] = error "mergeMTixs: empty input"
mergeMTixs xs = foldr1 mergeMTix xs
  where
    mergeMTix (MTix ts1) (MTix ts2) =
      MTix (zipWith mergeMTixModule ts1 ts2)
    mergeMTixModule (MTixModule n1 h1 i1 tks1) (MTixModule n2 h2 i2 tks2)
      | n1 == n2 && h1 == h2 =
          MTixModule n1 h1 (i1 + i2) (zipWith (<>) tks1 tks2)
      | otherwise =
          error $ "mergeMTixs: hash " <> show (h1,h2) <>
                  " or module name " <> show (n1,n2) <> "  mismatch"
