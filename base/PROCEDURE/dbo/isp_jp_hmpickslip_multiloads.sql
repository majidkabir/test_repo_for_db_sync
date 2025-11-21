SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure: isp_jp_hmpickslip_multiLoads                              */
/* Creation Date: 25-DEC-2018                                                 */
/* Copyright:                                                                 */
/* Written by: CHEN                                                           */
/*                                                                            */
/* Purpose: For JP LIT datawindow: r_jp_hmpickslip_loadkeys                   */
/*                                                                            */
/*                                                                            */
/* Called By:                                                                 */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/*                                                                            */
/******************************************************************************/

CREATE PROC [dbo].[isp_jp_hmpickslip_multiLoads] (
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

;WITH OrderList AS
(
   SELECT RANK() OVER (PARTITION BY LoadKey ORDER BY OrderKey) OrderNo ,
          LoadKey , OrderKey
   FROM  Orders WITH (NOLOCK)
   WHERE Storerkey = @storerkey
     AND Loadkey BETWEEN @LoadKeyFrom AND @LoadKeyTo
     AND (Route = @route or @route = 0)
) ,
PickData AS
(
   SELECT a.LoadKey ,
          a.OrderKey AS orderkey, b.SKU AS sku, c.LogicalLocation AS LogicalLocation ,b.Loc AS loc , a.Route AS [Route], SUM(b.Qty) AS qty,
          d.ExternLineNo AS ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) AS SKUDESCR
       , C.Score
     FROM Orders a WITH (NOLOCK)
     JOIN PickDetail b WITH (NOLOCK) on a.OrderKey = b.OrderKey
     JOIN Loc c WITH (NOLOCK) on b.Loc = c.Loc
     JOIN OrderDetail d WITH (NOLOCK) on b.OrderKey = d.OrderKey AND b.OrderLineNumber = d.OrderLineNumber
    WHERE a.Storerkey = @storerkey AND a.LoadKey BETWEEN @LoadKeyFrom AND @LoadKeyTo
    GROUP BY a.LoadKey ,  a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,
             d.ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))
           , C.Score
) ,
LoadLineCount AS
(
   SELECT LoadKey , COUNT(1) AS TotalLineCount
    FROM PickData
   GROUP BY LoadKey
) ,
OrderQtyCount AS
(
   SELECT OrderKey  , SUM(qty) AS TotalQty
    FROM PickData
   GROUP BY OrderKey
) ,
LabelDetail
   (
    OrderNo,            OrderKey,           LogicalLocation,            SKU,
     Route,              Qty,                Loc,                        Loadkey,
     ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR)
AS
(
   SELECT  t1.OrderNo,         t1.OrderKey,        t2.LogicalLocation,
         SUBSTRING(t2.SKU,1,7) + ' '+SUBSTRING(t2.SKU,8,3) + ' ' + SUBSTRING(t2.SKU,12,2) AS SKU,
            t2.Route,
         T4.TotalQty,
         t2.Loc,                     t1.LoadKey,
            t2.ExternLineNo,
         RANK() OVER (PARTITION BY T1.LoadKey ORDER BY t1.Loadkey, t2.Score,t2.LogicalLocation,t2.Loc,t1.OrderKey , t2.ExternLineNo)  ,
         T3.TotalLineCount,
         t2.SKUDESCR
      FROM OrderList AS t1
     JOIN PickData AS t2
       ON t1.orderkey = t2.orderkey
     JOIN LoadLineCount AS T3
       ON T1.LoadKey =  T3.LoadKey
     JOIN OrderQtyCount AS T4
       ON T1.OrderKey = T4.orderkey
)
SELECT * FROM LabelDetail ORDER BY Loadkey , LineNumber
END

GO