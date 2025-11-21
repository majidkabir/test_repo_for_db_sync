SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Store Procedure: BI.isp_in_hmpickslip_multiLoads                         */
/* Creation Date: 14-DEC-2020                                               */
/* Copyright:                                                               */
/* Written by: Chuah Chong Shen                                             */
/*                                                                          */
/* Purpose: [JP] WMS_Add_SP_To_BI_Schema_For_JReport                        */
/*                                                                          */
/*                                                                          */
/* Called By: Jreport                                                       */
/*                                                                          */
/* PVCS Version: 1.0                                                        */
/*                                                                          */
/* Version: 1.0                                                             */
/*                                                                          */
/* Data Modifications:                                                      */
/*                                                                          */
/* Updates:                                                                 */
/* Date         Author    Ver.  Purposes                                    */
/* 2021-02-22   JohnChuah 1.0   Added SKU color                             */
/* 2023-06-21   Wye Chun  1.1   JSM-158250 (WC01)                           */
/****************************************************************************/
-- Test: EXEC BI.isp_in_hmpickslip_multiLoads 'HM', '0000630239','0000630242','1'
CREATE   PROC [BI].[isp_in_hmpickslip_multiLoads] (
   @StorerKey NVARCHAR(10),
   @LoadKeyFrom NVARCHAR(10) ,
   @LoadKeyTo   NVARCHAR(10) ,
   @Route NVARCHAR(1)
)
AS

BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @Debug BIT = 0
      , @LogId      INT
      , @LinkSrv      NVARCHAR(128)
      , @Schema      NVARCHAR(128) = ISNULL(OBJECT_SCHEMA_NAME(@@PROCID),'')
      , @Proc         NVARCHAR(128) = ISNULL(OBJECT_NAME(@@PROCID),'')
      , @cParamOut   NVARCHAR(4000)= ''
      , @cParamIn  NVARCHAR(4000)= '{ "StorerKey":"'    +@StorerKey+'", '
                                   + '"LoadKeyFrom":"'  +@LoadKeyFrom+'",'
                                   + '"LoadKeyTo":"'    +@LoadKeyTo+'",'
                                   + '"Route":'''       +@Route+''''

   EXEC BI.dspExecInit @ClientId = @StorerKey
      , @Proc      = @Proc
      , @ParamIn   = @cParamIn
      , @LogId   = @LogId OUTPUT
      , @Debug   = @Debug OUTPUT
      , @Schema  = @Schema;

   DECLARE @Stmt NVARCHAR(MAX) = '' -- for storing dynamic SQL Statement

--CREATE TABLE #LOADSPLIT (
-- ORDERNO   INT,
-- ORDERKEY   NVARCHAR(20),
-- LOGICALLOCATION NVARCHAR(36),
-- SKU    NVARCHAR(40),
-- ROUTE    NVARCHAR(20),
-- QTY    INT,
-- LOC    NVARCHAR(20),
-- LOADKEY   NVARCHAR(20),
-- EXTERNLINENO  NVARCHAR(40),
-- LINENUMBER   NVARCHAR(10),
-- TOTALLINES   INT,
-- SKUDESCR   NVARCHAR(100),
-- )

-- CREATE TABLE #LOADSPLIT2 (
-- ORDERSORT   NVARCHAR(5),
-- ORDERKEY   NVARCHAR(20),
-- LOGICALLOCATION NVARCHAR(36),
-- SKU    NVARCHAR(40),
-- ROUTE    NVARCHAR(20),
-- QTY    INT,                                    -- LOC    NVARCHAR(20),
-- LOADKEY   NVARCHAR(20),
-- EXTERNLINENO  NVARCHAR(40),
-- LINENUMBER   NVARCHAR(10),
-- TOTALLINES   INT,
-- SKUDESCR   NVARCHAR(100),
-- )

  DECLARE @OPENQTY NVARCHAR(5)  , @RDS NVARCHAR(5), @TS nvarchar(20)
  SELECT TOP 1  @OPENQTY=O.ECOM_SINGLE_FLAG,@RDS=o.RDS, @TS= o.UserDefine03 FROM BI.V_ORDERS O (NOLOCK) JOIN BI.V_LOADPLANDETAIL LP(NOLOCK)
  ON (O.ORDERKEY=LP.ORDERKEY)
  WHERE LP.LOADKEY = @LOADKEYFROM

  IF @RDS='O' or ISNULL(@TS,'') <>'' or @OPENQTY <>'S'
  BEGIN
   RETURN
  END

;WITH OrderList AS
(
   SELECT RANK() OVER (PARTITION BY LoadKey ORDER BY OrderKey) OrderNo ,
          LoadKey, OrderKey
   FROM  BI.V_Orders WITH (NOLOCK)
   WHERE Storerkey = @storerkey
     AND Loadkey BETWEEN @LoadKeyFrom AND @LoadKeyTo
     --AND (Route = @route or @route = 0)
  AND [Route] = '1'
) ,
PickData AS
(
   SELECT a.LoadKey,
          a.OrderKey AS orderkey, b.SKU AS sku, c.LogicalLocation AS LogicalLocation ,b.Loc AS loc , a.Route AS [Route], SUM(b.Qty) AS qty,
          d.ExternLineNo AS ExternLineNo --,SUBSTRING(RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')),1,24) AS SKUDESCR           --(WC01)
          , e.descr AS SKUDESCR  --(WC01)
          , C.Score
          , e.BUSR6 as 'color' --JC_V1.0
    FROM BI.V_Orders a WITH (NOLOCK)
    JOIN BI.V_PickDetail b WITH (NOLOCK) on a.OrderKey = b.OrderKey
    JOIN BI.V_Loc c WITH (NOLOCK) on b.Loc = c.Loc
    JOIN BI.V_OrderDetail d WITH (NOLOCK) on b.OrderKey = d.OrderKey AND b.OrderLineNumber = d.OrderLineNumber
    JOIN BI.V_sku e (nolock) on b.storerkey = e.storerkey AND b.sku = e.sku --(WC01)
    WHERE a.Storerkey = @storerkey AND a.LoadKey BETWEEN @LoadKeyFrom AND @LoadKeyTo
    GROUP BY a.LoadKey ,  a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,
             d.ExternLineNo --,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))           --(WC01)
             , e.descr   --(WC01)
             , C.Score , e.BUSR6 --JC_V1.0
) ,
LoadLineCount AS
(
   SELECT LoadKey, COUNT(1) AS TotalLineCount
    FROM PickData
   GROUP BY LoadKey
) ,
OrderQtyCount AS
(
   SELECT OrderKey, SUM(qty) AS TotalQty
    FROM PickData
   GROUP BY OrderKey
) ,
LabelDetail
   (
    OrderNo,            OrderKey,           LogicalLocation,            SKU,
     Route,              Qty,                Loc,                        Loadkey,
     ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR
  ,color --JC_V1.0
  )
AS
(
   SELECT  t1.OrderNo, t1.OrderKey, t2.LogicalLocation,
         SUBSTRING(t2.SKU,1,7) + '-'+SUBSTRING(t2.SKU,8,3) + '-' + SUBSTRING(t2.SKU,11,3) AS SKU,
            t2.Route,
         T4.TotalQty,
         t2.Loc, t1.LoadKey,
            t2.ExternLineNo,
         RANK() OVER (PARTITION BY T1.LoadKey ORDER BY t1.Loadkey, t2.Score, t2.LogicalLocation, t2.Loc, t1.OrderKey, t2.ExternLineNo ),
         T3.TotalLineCount,
         t2.SKUDESCR ,
   t2.color --JC_V1.0
      FROM OrderList AS t1
     JOIN PickData AS t2
       ON t1.orderkey = t2.orderkey
     JOIN LoadLineCount AS T3
       ON T1.LoadKey =  T3.LoadKey
     JOIN OrderQtyCount AS T4
       ON T1.OrderKey = T4.orderkey
)SELECT * FROM LabelDetail ORDER BY Loadkey , LineNumber

--INSERT INTO #LOADSPLIT (
--  ORDERNO
-- ,ORDERKEY
-- ,LOGICALLOCATION
-- ,SKU
-- ,ROUTE
-- ,QTY
-- ,LOC
-- ,LOADKEY
-- ,EXTERNLINENO
-- ,LINENUMBER
-- ,TOTALLINES
-- ,SKUDESCR
--)
--SELECT
--  ORDERNO
-- ,ORDERKEY
-- ,LOGICALLOCATION
-- ,SKU
-- ,ROUTE
-- ,QTY
-- ,LOC
-- ,LOADKEY
-- ,EXTERNLINENO
-- ,LINENUMBER
-- ,TOTALLINES
-- ,SKUDESCR
--FROM LABELDETAIL ORDER BY LOADKEY , LINENUMBER

--INSERT INTO #LOADSPLIT2 (
--  ORDERSORT
-- ,ORDERKEY
-- ,LOGICALLOCATION
-- ,SKU
-- ,ROUTE
-- ,QTY
-- ,LOC
-- ,LOADKEY
-- ,EXTERNLINENO
-- ,LINENUMBER
-- ,TOTALLINES
-- ,SKUDESCR
--)
--SELECT
--  CASE WHEN ORDERNO <10 THEN 'A0'+ CAST(ORDERNO AS NVARCHAR)
--  WHEN ORDERNO BETWEEN '10' AND '40' THEN 'A' + CAST(ORDERNO AS NVARCHAR)
--  when ORDERNO BETWEEN '41' AND '49' THEN 'B0'+ CAST(ORDERNO - 40 AS NVARCHAR)
--  ELSE 'B'+ CAST(ORDERNO -40 AS NVARCHAR)  END AS ORDERSORT
-- ,ORDERKEY
-- ,LOGICALLOCATION
-- ,SKU
-- ,ROUTE
-- ,QTY
-- ,LOC
-- ,LOADKEY
-- ,EXTERNLINENO
-- ,LINENUMBER
-- ,TOTALLINES
-- ,SKUDESCR FROM #LOADSPLIT WITH (NOLOCK)

--SELECT * FROM #LOADSPLIT2

--DROP TABLE #LOADSPLIT
--DROP TABLE #LOADSPLIT2

   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;
      
END

GO