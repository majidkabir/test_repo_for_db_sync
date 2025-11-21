SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/****************************************************************************/
/* Store Procedure: BI.isp_jp_hmpickslip_multiLoads_Multi                   */
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
/* 2021-02-16   JohnChuah 1.0   Added SKU color                             */
/* 2023-06-21   Wye Chun  1.1   JSM-158257 (WC01)                           */
/****************************************************************************/
-- Test: EXEC BI.isp_in_hmpickslip_multiLoads_Multi 'HM', '0000630239','0000630242','1'
CREATE   PROC [BI].[isp_in_hmpickslip_multiLoads_Multi] (
   @StorerKey NVARCHAR(10),
   @LoadKeyFrom NVARCHAR(10),
   @LoadKeyTo   NVARCHAR(10),
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

   SET @Route = '0'

 CREATE TABLE #LOADSPLIT (
   ORDERNO   INT,
   ORDERKEY   NVARCHAR(20),
   LOGICALLOCATION NVARCHAR(36),
   SKU    NVARCHAR(40),
   ROUTE    NVARCHAR(20),
   QTY    INT,
   LOC    NVARCHAR(20),
   LOADKEY   NVARCHAR(20),
   EXTERNLINENO  NVARCHAR(40),
   LINENUMBER   INT, --NVARCHAR(10),
   TOTALLINES   INT,
   SKUDESCR   NVARCHAR(100),
   COLOR   NVARCHAR(100) --JC_V1.0
 )

 CREATE TABLE #LOADSPLIT2 (
   ORDERSORT   NVARCHAR(10),
   ORDERKEY   NVARCHAR(20),
   LOGICALLOCATION NVARCHAR(36),
   SKU    NVARCHAR(40),
   ROUTE    NVARCHAR(20),
   QTY    INT,
   LOC    NVARCHAR(20),
   LOADKEY   NVARCHAR(20),
   EXTERNLINENO  NVARCHAR(40),
   LINENUMBER   INT,--NVARCHAR(10),
   TOTALLINES   INT,
   SKUDESCR   NVARCHAR(100),
   COLOR   NVARCHAR(100) --JC_V1.0
 )

  DECLARE @OPENQTY INT, @RDS NVARCHAR(5), @TS nvarchar(20),@ECOM_SINGLE_FLAG nvarchar(5)
  SELECT TOP 1 @ECOM_SINGLE_FLAG =ECOM_SINGLE_FLAG, @RDS=o.RDS, @TS= o.UserDefine03 FROM BI.V_ORDERS O (NOLOCK) JOIN BI.V_LOADPLANDETAIL LP(NOLOCK)
  ON (O.ORDERKEY=LP.ORDERKEY)
  WHERE LP.LOADKEY = @LOADKEYFROM

  SELECT @OPENQTY=COUNT(DISTINCT ECOM_SINGLE_FLAG) FROM BI.V_ORDERS O (NOLOCK) JOIN BI.V_LOADPLANDETAIL LP(NOLOCK)
  ON  (O.ORDERKEY = LP.ORDERKEY)
  WHERE LP.LOADKEY= @LOADKEYFROM

 IF @RDS<>'O' OR ISNULL(@TS,'') =''
  BEGIN
     IF @OPENQTY <2 and @ECOM_SINGLE_FLAG='S'
  BEGIN
   RETURN
  END
  END


;WITH OrderList AS
(
   SELECT RANK() OVER (PARTITION BY LoadKey ORDER BY OrderKey) OrderNo,
          LoadKey, OrderKey
   FROM  BI.V_Orders WITH (NOLOCK)
   WHERE Storerkey = @storerkey
     AND Loadkey BETWEEN @LoadKeyFrom AND @LoadKeyTo
     AND (Route = @route or @route = 0)
) ,
PickData AS
(
   SELECT a.LoadKey ,
          a.OrderKey AS orderkey, b.SKU AS sku, c.LogicalLocation AS LogicalLocation ,b.Loc AS loc , a.Route AS [Route], SUM(b.Qty) AS qty,
          d.ExternLineNo AS ExternLineNo --,SUBSTRING(RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')),1,24) AS SKUDESCR      --(WC01)
          , e.descr AS SKUDESCR     --(WC01)
          , C.Score,
          e.BUSR6 as 'color' --JC_V1.0
     FROM BI.V_Orders a WITH (NOLOCK)
     JOIN BI.V_PickDetail b WITH (NOLOCK) on a.OrderKey = b.OrderKey
     JOIN BI.V_Loc c WITH (NOLOCK) on b.Loc = c.Loc
     JOIN BI.V_OrderDetail d WITH (NOLOCK) on b.OrderKey = d.OrderKey AND b.OrderLineNumber = d.OrderLineNumber
     JOIN BI.V_sku e (nolock) on b.storerkey = e.storerkey AND b.sku = e.sku   --(WC01)
    WHERE a.Storerkey = @storerkey AND a.LoadKey BETWEEN @LoadKeyFrom AND @LoadKeyTo
    GROUP BY a.LoadKey ,  a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,
             d.ExternLineNo --,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))         --(WC01)
             , e.descr    --(WC01)
             , C.Score , e.BUSR6 --JC_V1.0
),
OrderQtyCount AS
(
   SELECT OrderKey, SUM(qty) AS TotalQty
    FROM PickData
   GROUP BY OrderKey
)  ,
LabelDetail1
   (
    OrderNo,     OrderKey,           LogicalLocation,            SKU,
     Route,              Qty,               Loc,                        Loadkey,
     ExternLineNo,       LineNumber,         --TotalLines,
  SKUDESCR, color) --JC_V1.0
AS
(
   SELECT  t1.OrderNo, t1.OrderKey, t2.LogicalLocation,
         SUBSTRING(t2.SKU,1,7) + '-'+SUBSTRING(t2.SKU,8,3) + '-' + SUBSTRING(t2.SKU,11,3) AS SKU,
            t2.Route,
         T4.TotalQty,
         t2.Loc,                     t1.LoadKey,
            t2.ExternLineNo,
    RANK() OVER (PARTITION BY T1.LoadKey ORDER BY t1.Loadkey, t2.Score,t2.LogicalLocation,t2.Loc,t1.OrderKey , t2.ExternLineNo),
         --T3.TotalLineCount,
         t2.SKUDESCR,
         t2.color --JC_V1.0
      FROM OrderList AS t1
     JOIN PickData AS t2
       ON t1.orderkey = t2.orderkey
     --JOIN LoadLineCount AS T3
       --ON T1.LoadKey =  T3.LoadKey
     JOIN OrderQtyCount AS T4
       ON T1.OrderKey = T4.orderkey
) ,
LoadLineCount AS
(
   SELECT LoadKey, COUNT(1) AS TotalLineCount
    FROM LabelDetail1
   GROUP BY LoadKey
) ,
LabelDetail
   (
    OrderNo,     OrderKey,           LogicalLocation,            SKU,
     Route,              Qty,               Loc,                        Loadkey,
     ExternLineNo,       LineNumber,         TotalLines,
  SKUDESCR, color) --JC_V1.0
AS
(
   SELECT  t1.OrderNo,         t1.OrderKey,        t2.LogicalLocation,
         SUBSTRING(t2.SKU,1,7) + '-'+SUBSTRING(t2.SKU,8,3) + '-' + SUBSTRING(t2.SKU,11,3) AS SKU,
            t2.Route,
         T4.TotalQty,
         t2.Loc,                     t1.LoadKey,
            t2.ExternLineNo,
    RANK() OVER (PARTITION BY T1.LoadKey ORDER BY t1.Loadkey, t2.Score,t2.LogicalLocation,t2.Loc,t1.OrderKey , t2.ExternLineNo),
         T3.TotalLineCount,
         t2.SKUDESCR,
         t2.color --JC_V1.0
      FROM OrderList AS t1
     JOIN PickData AS t2
       ON t1.orderkey = t2.orderkey
     JOIN LoadLineCount AS T3
       ON T1.LoadKey =  T3.LoadKey
     JOIN OrderQtyCount AS T4
       ON T1.OrderKey = T4.orderkey
)
INSERT INTO #LOADSPLIT (
  ORDERNO
 ,ORDERKEY
 ,LOGICALLOCATION
 ,SKU
 ,ROUTE
 ,QTY
 ,LOC
 ,LOADKEY
 ,EXTERNLINENO
 ,LINENUMBER
 ,TOTALLINES
 ,SKUDESCR
 ,color --JC_V1.0
)
SELECT
  ORDERNO
 ,ORDERKEY
 ,LOGICALLOCATION
 ,SKU
 ,ROUTE
 ,QTY
 ,LOC
 ,LOADKEY
 ,EXTERNLINENO
 ,LINENUMBER
 ,TOTALLINES
 ,SKUDESCR
 ,color --JC_V1.0
FROM LABELDETAIL-- ORDER BY LOADKEY , LINENUMBER

INSERT INTO #LOADSPLIT2 (
  ORDERSORT
 ,ORDERKEY
 ,LOGICALLOCATION
 ,SKU
 ,ROUTE
 ,QTY
 ,LOC
 ,LOADKEY
 ,EXTERNLINENO
 ,LINENUMBER
 ,TOTALLINES
 ,SKUDESCR
 ,color --JC_V1.0
)

SELECT
  CASE WHEN ORDERNO <10                THEN 'O A 0'+ CAST(ORDERNO AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '10' AND  '20' THEN 'O A ' + CAST(ORDERNO AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '21' AND  '29' THEN 'O B 0'+ CAST(ORDERNO - 20 AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '30' AND  '40' THEN 'O B ' + CAST(ORDERNO - 20 AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '41' AND  '49' THEN 'O C 0'+ CAST(ORDERNO - 40 AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '50' AND '60' THEN 'O C ' + CAST(ORDERNO - 40  AS NVARCHAR)
  WHEN ORDERNO BETWEEN '61' AND '69' THEN 'O D 0'+ CAST(ORDERNO - 60 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '70' AND '80' THEN 'O D ' + CAST(ORDERNO - 60 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '81' AND '89' THEN 'O E 0'+ CAST(ORDERNO - 80 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '90' AND '100' THEN 'O E ' + CAST(ORDERNO - 80 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '101' AND '109' THEN 'O F 0'+ CAST(ORDERNO - 100 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '110' AND '120' THEN 'O F ' + CAST(ORDERNO - 100 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '121' AND '129' THEN 'O G 0'+ CAST(ORDERNO - 120 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '130' AND '140' THEN 'O G ' + CAST(ORDERNO - 120 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '141' AND '149' THEN 'O H 0'+ CAST(ORDERNO - 140 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '150' AND '160' THEN 'O H ' + CAST(ORDERNO - 140 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '161' AND '169' THEN 'X A 0'+ CAST(ORDERNO - 160 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '170' AND '180' THEN 'X A ' + CAST(ORDERNO - 160 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '181' AND '189' THEN 'X B 0'+ CAST(ORDERNO - 180 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '190' AND '200' THEN 'X B ' + CAST(ORDERNO - 180 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '201' AND '209' THEN 'X C 0'+ CAST(ORDERNO - 200 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '210' AND '220' THEN 'X C ' + CAST(ORDERNO - 200 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '221' AND '229' THEN 'X D 0'+ CAST(ORDERNO - 220 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '230' AND '240' THEN 'X D ' + CAST(ORDERNO - 220 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '241' AND '249' THEN 'X E 0'+ CAST(ORDERNO - 240 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '250' AND '260' THEN 'X E ' + CAST(ORDERNO - 240 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '261' AND '269' THEN 'X F 0'+ CAST(ORDERNO - 260 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '270' AND '280' THEN 'X F ' + CAST(ORDERNO - 260 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '281' AND '289' THEN 'X G 0'+ CAST(ORDERNO - 280 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '290' AND '300' THEN 'X G ' + CAST(ORDERNO - 280 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '301' AND '309' THEN 'X H 0'+ CAST(ORDERNO - 300 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '310' AND '320' THEN 'X H ' + CAST(ORDERNO - 300 AS NVARCHAR)
  END AS ORDERSORT
 /*SELECT
  CASE WHEN ORDERNO <10                THEN 'A 0'+ CAST(ORDERNO AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '10' AND  '20' THEN 'A ' + CAST(ORDERNO AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '21' AND  '29' THEN 'B 0'+ CAST(ORDERNO - 20 AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '30' AND  '40' THEN 'B ' + CAST(ORDERNO - 20 AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '41' AND  '49' THEN 'C 0'+ CAST(ORDERNO - 40 AS NVARCHAR)
  WHEN ORDERNO BETWEEN  '50' AND '60' THEN 'C ' + CAST(ORDERNO - 40  AS NVARCHAR)
  WHEN ORDERNO BETWEEN '61' AND '69' THEN 'D 0'+ CAST(ORDERNO - 60 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '70' AND '80' THEN 'D ' + CAST(ORDERNO - 60 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '81' AND '89' THEN 'E 0'+ CAST(ORDERNO - 80 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '90' AND '100' THEN 'E ' + CAST(ORDERNO - 80 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '101' AND '109' THEN 'F 0'+ CAST(ORDERNO - 100 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '110' AND '120' THEN 'F ' + CAST(ORDERNO - 100 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '121' AND '129' THEN 'G 0'+ CAST(ORDERNO - 120 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '130' AND '140' THEN 'G ' + CAST(ORDERNO - 120 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '141' AND '149' THEN 'H 0'+ CAST(ORDERNO - 140 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '150' AND '160' THEN 'H ' + CAST(ORDERNO - 140 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '161' AND '169' THEN 'I 0'+ CAST(ORDERNO - 160 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '170' AND '180' THEN 'I ' + CAST(ORDERNO - 160 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '181' AND '189' THEN 'J 0'+ CAST(ORDERNO - 180 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '190' AND '200' THEN 'J ' + CAST(ORDERNO - 180 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '201' AND '209' THEN 'K 0'+ CAST(ORDERNO - 200 AS NVARCHAR)
  WHEN ORDERNO BETWEEN '210' AND '220' THEN 'K ' + CAST(ORDERNO - 200 AS NVARCHAR)
  END AS ORDERSORT */
 ,ORDERKEY
 ,LOGICALLOCATION
 ,SKU
 ,ROUTE
 ,QTY
 ,LOC
 ,LOADKEY
 ,EXTERNLINENO
 ,LINENUMBER
 ,TOTALLINES
 ,SKUDESCR
 ,color --JC_V1.0
 FROM #LOADSPLIT WITH (NOLOCK)

SELECT * FROM #LOADSPLIT2 (NOLOCK) ORDER BY LOADKEY, LINENUMBER

DROP TABLE #LOADSPLIT
DROP TABLE #LOADSPLIT2

   EXEC BI.dspExecStmt @Stmt = @Stmt
   , @LogId = @LogId
   , @Debug = @Debug;

END

GO