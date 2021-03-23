{-# language DataKinds #-}
{-# language FlexibleContexts #-}
{-# language ScopedTypeVariables #-}
{-# language TypeApplications #-}
{-# language TypeFamilies #-}

{-# options_ghc -fno-warn-redundant-constraints #-}

module Rel8.Expr.Aggregate
  ( count, countDistinct, countStar, countWhere
  , and, or
  , min, max
  , sum, sumWhere
  , stringAgg
  , groupByExpr
  , listAggExpr, nonEmptyAggExpr
  , sgroupByExpr
  )
where

-- base
import Data.Int ( Int64 )
import Data.List.NonEmpty ( NonEmpty )
import Prelude hiding ( and, max, min, null, or, sum )

-- opaleye
import qualified Opaleye.Internal.HaskellDB.PrimQuery as Opaleye

-- rel8
import Rel8.Aggregate ( Aggregate, Aggregator(..), unsafeMakeAggregate )
import Rel8.Expr ( Expr )
import Rel8.Expr.Bool ( caseExpr )
import Rel8.Expr.Opaleye
  ( castExpr
  , fromPrimExpr
  , fromPrimExpr
  , toPrimExpr
  )
import Rel8.Expr.Null ( null )
import Rel8.Expr.Serialize ( litExpr )
import Rel8.Schema.Nullability ( Nullability, Sql, nullabilization )
import Rel8.Type.Array ( fromPrimArray )
import Rel8.Type.Eq ( DBEq )
import Rel8.Type.Num ( DBNum )
import Rel8.Type.Ord ( DBMax, DBMin )
import Rel8.Type.String ( DBString )
import Rel8.Type.Sum ( DBSum )


-- | Count the occurances of a single column. Corresponds to @COUNT(a)@
count :: Expr a -> Aggregate (Expr Int64)
count = unsafeMakeAggregate toPrimExpr fromPrimExpr $
  Just Aggregator
    { operation = Opaleye.AggrCount
    , ordering = []
    , distinction = Opaleye.AggrAll
    }


-- | Count the number of distinct occurances of a single column. Corresponds to
-- @COUNT(DISTINCT a)@
countDistinct :: DBEq a => Expr a -> Aggregate (Expr Int64)
countDistinct = unsafeMakeAggregate toPrimExpr fromPrimExpr $
  Just Aggregator
    { operation = Opaleye.AggrCount
    , ordering = []
    , distinction = Opaleye.AggrDistinct
    }


-- | Corresponds to @COUNT(*)@.
countStar :: Aggregate (Expr Int64)
countStar = count (litExpr True)


countWhere :: Expr Bool -> Aggregate (Expr Int64)
countWhere condition = count (caseExpr [(condition, litExpr (Just True))] null)


-- | Corresponds to @bool_and@.
and :: Expr Bool -> Aggregate (Expr Bool)
and = unsafeMakeAggregate toPrimExpr fromPrimExpr $
  Just Aggregator
    { operation = Opaleye.AggrBoolAnd
    , ordering = []
    , distinction = Opaleye.AggrAll
    }


-- | Corresponds to @bool_or@.
or :: Expr Bool -> Aggregate (Expr Bool)
or = unsafeMakeAggregate toPrimExpr fromPrimExpr $
  Just Aggregator
    { operation = Opaleye.AggrBoolOr
    , ordering = []
    , distinction = Opaleye.AggrAll
    }


-- | Produce an aggregation for @Expr a@ using the @max@ function.
max :: Sql DBMax a => Expr a -> Aggregate (Expr a)
max = unsafeMakeAggregate toPrimExpr fromPrimExpr $
  Just Aggregator
    { operation = Opaleye.AggrSum
    , ordering = []
    , distinction = Opaleye.AggrAll
    }


-- | Produce an aggregation for @Expr a@ using the @max@ function.
min :: Sql DBMin a => Expr a -> Aggregate (Expr a)
min = unsafeMakeAggregate toPrimExpr fromPrimExpr $
  Just Aggregator
    { operation = Opaleye.AggrSum
    , ordering = []
    , distinction = Opaleye.AggrAll
    }

-- | Corresponds to @sum@.
sum :: Sql DBSum a => Expr a -> Aggregate (Expr a)
sum = unsafeMakeAggregate toPrimExpr (castExpr . fromPrimExpr) $
  Just Aggregator
    { operation = Opaleye.AggrSum
    , ordering = []
    , distinction = Opaleye.AggrAll
    }


sumWhere :: (Sql DBNum a, Sql DBSum a)
  => Expr Bool -> Expr a -> Aggregate (Expr a)
sumWhere condition a = sum (caseExpr [(condition, a)] 0)


stringAgg :: Sql DBString a
  => Expr db -> Expr a -> Aggregate (Expr a)
stringAgg delimiter =
  unsafeMakeAggregate toPrimExpr (castExpr . fromPrimExpr) $
    Just Aggregator
      { operation = Opaleye.AggrStringAggr (toPrimExpr delimiter)
      , ordering = []
      , distinction = Opaleye.AggrAll
      }


-- | Aggregate a value by grouping by it.
groupByExpr :: Sql DBEq a => Expr a -> Aggregate (Expr a)
groupByExpr = sgroupByExpr nullabilization


listAggExpr :: Expr a -> Aggregate (Expr [a])
listAggExpr = unsafeMakeAggregate toPrimExpr from $ Just
  Aggregator
    { operation = Opaleye.AggrArr
    , ordering = []
    , distinction = Opaleye.AggrAll
    }
  where
    from = fromPrimExpr . fromPrimArray


nonEmptyAggExpr :: Expr a -> Aggregate (Expr (NonEmpty a))
nonEmptyAggExpr = unsafeMakeAggregate toPrimExpr from $ Just
  Aggregator
    { operation = Opaleye.AggrArr
    , ordering = []
    , distinction = Opaleye.AggrAll
    }
  where
    from = fromPrimExpr . fromPrimArray


sgroupByExpr :: DBEq db => Nullability db a -> Expr a -> Aggregate (Expr a)
sgroupByExpr _ = unsafeMakeAggregate toPrimExpr fromPrimExpr Nothing
