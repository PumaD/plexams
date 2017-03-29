module Main where

import qualified ImportSpec (spec)
import           Test.Hspec
import qualified PlanManipSpec  (spec)

main = do
    hspec ImportSpec.spec
    hspec PlanManipSpec.spec
