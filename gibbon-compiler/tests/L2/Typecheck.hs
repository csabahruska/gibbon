{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# OPTIONS_GHC -fno-warn-name-shadowing #-}

-- | Tests for L2.Typecheck
--
module L2.Typecheck where

import Test.Tasty.HUnit
import Test.Tasty.TH
import Test.Tasty

import Control.Monad.Except
import Data.Loc
import Data.Map as M
import Data.Set as S

import Packed.FirstOrder.Common hiding (FunDef)
import Packed.FirstOrder.L2.Syntax as L2
import Packed.FirstOrder.L2.Typecheck
import Packed.FirstOrder.L2.Examples
import qualified Packed.FirstOrder.L1.Syntax as L1

--

type Exp = L Exp2

-- | Run the typechecker for (Prog {ddefs = Tree, fundefs = [add1], mainExp = exp})
--
tester :: Exp -> Either TCError (Ty2, LocationTypeState)
tester = runExcept . (tcExp ddfs env funs constrs regs tstate)
  where
    ddfs    = ddtree
    env     = Env2 M.empty M.empty
    funs    = M.empty
    constrs = ConstraintSet S.empty
    regs    = RegionSet S.empty
    tstate  = LocationTypeState M.empty


-- |
assertValue :: Exp -> (Ty2, LocationTypeState) -> Assertion
assertValue exp expected =
  case tester exp of
    Left err -> assertFailure $ show err
    Right actual -> expected @=? actual


-- |
assertError :: Exp -> TCError -> Assertion
assertError exp expected =
  case tester exp of
    Left actual -> expected @=? actual
    Right err -> assertFailure $ show err


-- Tests

case_test1 :: Assertion
case_test1 = assertValue exp (IntTy,LocationTypeState {tsmap = M.fromList []})
  where exp = l$ LitE 1


case_test2 :: Assertion
case_test2 =  assertValue exp (IntTy,LocationTypeState {tsmap = M.fromList []})
  where exp = l$ LetE ("a",[],IntTy, l$ LitE 1)
                        (l$ PrimAppE L1.AddP [l$ VarE "a",
                                                     l$ VarE "a"])


case_test3 :: Assertion
case_test3 =  assertValue exp (IntTy,LocationTypeState {tsmap = M.fromList []})
  where exp = l$ Ext $ LetRegionE (VarR "r") $
                              l$ Ext $ LetLocE "l" (StartOfLE (VarR "r")) $
                              l$ LitE 1


case_test4 :: Assertion
case_test4 =  assertValue exp (IntTy,LocationTypeState {tsmap = M.fromList []})
  where exp = l$ Ext $ LetRegionE (VarR "r") $
                              l$ Ext $ LetLocE "l" (StartOfLE (VarR "r")) $
                              l$ LetE ("throwaway", [],
                                              PackedTy "Tree" "l",
                                              l$ DataConE "l" "Leaf" [l$ LitE 1]) $
                              l$ LitE 2


case_test4_error1 :: Assertion
case_test4_error1 =  assertError exp expected
  where exp = l$ Ext $ LetRegionE (VarR "r") $
              l$ Ext $ LetLocE "l" (StartOfLE (VarR "r1")) $
              l$ LetE ("throwaway", [], PackedTy "Tree" "l",
                              l$ DataConE "l" "Leaf" [l$ LitE 1]) $
              l$  LitE 2

        expected = GenericTC "Region VarR (Var \"r1\") not in scope" (l$ Ext (LetLocE (Var "l") (StartOfLE (VarR (Var "r1"))) (l$ LetE (Var "throwaway",[],PackedTy "Tree" (Var "l"), l$ DataConE (Var "l") "Leaf" [l$ LitE 1]) (l$ LitE 2))))


case_test4_error2 :: Assertion
case_test4_error2 =  assertError exp expected
  where exp = l$ Ext $ LetRegionE (VarR "r") $
              l$ Ext $ LetLocE "l" (StartOfLE (VarR "r")) $
              l$ LetE ("throwaway", [], PackedTy "Tree" "l1",
                              l$ DataConE "l1" "Leaf" [l$ LitE 1]) $
              l$ LitE 2

        expected = GenericTC "Unknown location Var \"l1\"" (l$ DataConE (Var "l1") "Leaf" [l$ LitE 1])


case_test5 :: Assertion
case_test5 =  assertValue exp (IntTy,LocationTypeState {tsmap = M.fromList []})
  where exp = l$ Ext $ LetRegionE (VarR "r") $
              l$ Ext $ LetLocE "l" (StartOfLE (VarR "r")) $
              l$ Ext $ LetLocE "l1" (AfterConstantLE 1 "l") $
              l$ LetE ("x", [], PackedTy "Tree" "l1", l$ DataConE "l1" "Leaf" [l$ LitE 1]) $
              l$ Ext $ LetLocE "l2" (AfterVariableLE "x" "l1") $
              l$ LetE ("y", [], PackedTy "Tree" "l2", l$ DataConE "l2" "Leaf" [l$ LitE 2]) $
              l$ LetE ("z", [], PackedTy "Tree" "l", l$ DataConE "l" "Node" [l$ VarE "x", l$ VarE "y"]) $
              l$ LitE 1

case_test5_error1 :: Assertion
case_test5_error1 =  assertError exp expected
  where exp = l$ Ext $ LetRegionE (VarR "r") $
              l$ Ext $ LetLocE "l" (StartOfLE (VarR "r")) $
              l$ Ext $ LetLocE "l1" (AfterConstantLE 1 "l") $
              l$ LetE ("x", [], PackedTy "Tree" "l1",
                              l$ DataConE "l1" "Leaf" [l$ LitE 1]) $
              l$ Ext $ LetLocE "l2" (AfterVariableLE "x" "l1") $
              l$ LetE ("y", [], PackedTy "Tree" "l2",
                              l$ DataConE "l2" "Leaf" [l$ LitE 2]) $
              l$ LetE ("z", [], PackedTy "Tree" "l",
                              l$ DataConE "l" "Node"
                              [l$ VarE "y", l$ VarE "x"]) $
              l$ LitE 1

        expected = LocationTC "Expected after relationship" (l$ DataConE (Var "l") "Node" [l$ VarE (Var "y"),l$ VarE (Var "x")]) (Var "l") (Var "l2")

case_test6 :: Assertion
case_test6 =  assertValue exp (IntTy,LocationTypeState {tsmap = M.fromList []})
  where exp = l$ Ext $ LetRegionE (VarR "r") $
              l$ Ext $ LetLocE "l" (StartOfLE (VarR "r")) $
              l$ Ext $ LetLocE "l1" (AfterConstantLE 1 "l") $
              l$ LetE ("x", [], PackedTy "Tree" "l1",
                              l$ DataConE "l1" "Leaf" [l$ LitE 1]) $
              l$ Ext $ LetLocE "l2" (AfterVariableLE "x" "l1") $
              l$ LetE ("y", [], PackedTy "Tree" "l2",
                              l$ DataConE "l2" "Leaf" [l$ LitE 2]) $
              l$ LetE ("z", [], PackedTy "Tree" "l",
                              l$ DataConE "l" "Node" [l$ VarE "x",
                                                             l$ VarE "y"]) $
              l$ CaseE (l$ VarE "z")
              [ ("Leaf",[("num","lnum")], l$ VarE "num")
              , ("Node",[("x","lnodex"),("y","lnodey")],
                 l$ LitE 0)]

-- | Return type of a function is updated with locVars at the call-site
case_copy_on_add1 :: Assertion
case_copy_on_add1 = PackedTy "Tree" (Var "lout21") @=? (arrOut funty)
  where Prog{fundefs} = fst $ runSyM 0 $ tcProg copyOnId1Prog
        FunDef{funty} = fundefs ! "id1WithCopy"


-- case_test7 :: Assertion
-- case_test7 = actualTest7 @=? expextedTest7
--   where
--     test7Prog :: L2.Prog
--     test7Prog = Prog ddtree (M.singleton "add1" add1Fun) (Just (test7main,IntTy))

--     actualTest7 :: L2.Prog
--     actualTest7 = fst $ runSyM 0 $ tcProg test7Prog

--     expextedTest7 :: L2.Prog
--     expextedTest7 = L2.Prog {ddefs = M.fromList [(Var "Tree",DDef {tyName = Var "Tree", dataCons = [("Leaf",[(False,IntTy)]),("Node",[(False,PackedTy "Tree" (Var "l")),(False,PackedTy "Tree" (Var "l"))])]})], fundefs = M.fromList [(Var "add1",L2.FunDef {funname = Var "add1", funty = ArrowTy {locVars = [LRM (Var "lin") (VarR (Var "r1")) Input,LRM (Var "lout") (VarR (Var "r1")) Output], arrIn = PackedTy "Tree" (Var "lin"), arrEffs = S.fromList [Traverse (Var "lin")], arrOut = PackedTy "Tree" (Var "lout"), locRets = [EndOf (LRM (Var "lin") (VarR (Var "r1")) Input)]}, funarg = Var "tr", funbod = CaseE (VarE (Var "tr")) [("Leaf",[(Var "n",Var "l0")],LetE (Var "v",[],IntTy,PrimAppE L1.AddP [VarE (Var "n"),LitE 1]) (LetE (Var "lf",[],PackedTy "Tree" (Var "lout"),DataConE (Var "lout") "Leaf" [VarE (Var "v")]) (VarE (Var "lf")))),("Node",[(Var "x",Var "l1"),(Var "y",Var "l2")],Ext (LetLocE (Var "lout1") (AfterConstantLE 1 (Var "lout")) (LetE (Var "x1",[],PackedTy "Tree" (Var "lout1"),AppE (Var "add1") [Var "l1",Var "lout1"] (VarE (Var "x"))) (Ext (LetLocE (Var "lout2") (AfterVariableLE (Var "x1") (Var "lout1")) (LetE (Var "y1",[],PackedTy "Tree" (Var "lout2"),AppE (Var "add1") [Var "l2",Var "lout2"] (VarE (Var "y"))) (LetE (Var "z",[],PackedTy "Tree" (Var "lout"),DataConE (Var "lout") "Node" [VarE (Var "x1"),VarE (Var "y1")]) (VarE (Var "z")))))))))]})], mainExp = Just (Ext (LetRegionE (VarR (Var "r")) (Ext (LetLocE (Var "l") (StartOfLE (VarR (Var "r"))) (Ext (LetLocE (Var "l1") (AfterConstantLE 1 (Var "l")) (LetE (Var "x",[],PackedTy "Tree" (Var "l1"),DataConE (Var "l1") "Leaf" [LitE 1]) (Ext (LetLocE (Var "l2") (AfterVariableLE (Var "x") (Var "l1")) (LetE (Var "y",[],PackedTy "Tree" (Var "l2"),DataConE (Var "l2") "Leaf" [LitE 1]) (LetE (Var "z",[],PackedTy "Tree" (Var "l"),DataConE (Var "l") "Node" [VarE (Var "x"),VarE (Var "y")]) (Ext (LetRegionE (VarR (Var "rtest")) (Ext (LetLocE (Var "testout") (StartOfLE (VarR (Var "rtest"))) (LetE (Var "a",[],PackedTy "Tree" (Var "testout"),AppE (Var "add1") [Var "l",Var "testout"] (VarE (Var "z"))) (CaseE (VarE (Var "a")) [("Leaf",[(Var "num",Var "lnum")],VarE (Var "num")),("Node",[(Var "x",Var "lnodex"),(Var "y",Var "lnodey")],LitE 0)])))))))))))))))),IntTy)}

--     test7main :: Exp
--     test7main = Ext $ LetRegionE (VarR "r") $ Ext $ LetLocE "l" (StartOfLE (VarR "r")) $
--                 Ext $ LetLocE "l1" (AfterConstantLE 1 "l") $
--                 LetE ("x", [], PackedTy "Tree" "l1", DataConE "l1" "Leaf" [LitE 1]) $
--                 Ext $ LetLocE "l2" (AfterVariableLE "x" "l1") $
--                 LetE ("y", [], PackedTy "Tree" "l2", DataConE "l2" "Leaf" [LitE 1]) $
--                 LetE ("z", [], PackedTy "Tree" "l", DataConE "l" "Node" [VarE "x", VarE "y"]) $
--                 Ext $ LetRegionE (VarR "rtest") $
--                 Ext $ LetLocE "testout" (StartOfLE (VarR "rtest")) $
--                 LetE ("a", [], PackedTy "Tree" "testout", AppE "add1" ["l","testout"] (VarE "z")) $
--                 CaseE (VarE "a") [ ("Leaf",[("num","lnum")], VarE "num")
--                                  , ("Node",[("x","lnodex"),("y","lnodey")], LitE 0)]

l2TypecheckerTests :: TestTree
l2TypecheckerTests = $(testGroupGenerator)