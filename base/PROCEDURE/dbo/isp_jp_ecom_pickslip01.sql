SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store Procedure: isp_jp_ECOM_PickSlip01                                    */
/* Creation Date: 10-AUG-2018                                                 */
/* Copyright: IDS                                                             */
/* Written by: Cloud                                                          */
/*                                                                            */
/* Purpose: For JP LIT datawindow                                             */
/*                                                                            */
/*                                                                            */
/* Called By:  r_cn_hmpickslip                                                */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.1                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/* 2016/11/18   Chen      1.1   Update Sorting Rule -> Loc.Score              */
/* 2017/11/15   Marc      1.2   Update Sorting Rule -> LogicalLocation,       */
/*                              remove SKU                                    */
/* 2018/08/10   Chen      1.3   Change the SKU display logic -> Show full SKU */
/* 2018/08/10   Cloud     1.4   Make 1 unit per line                          */
/* 2019/11/06   Grick     1.5   Change Sorting Logic                          */
/******************************************************************************/

CREATE PROC [dbo].[isp_jp_ECOM_PickSlip01]               
   @route   NVARCHAR(1),                
   @loadkey NVARCHAR(10)                
AS                
                
BEGIN                
   SET NOCOUNT ON                
   SET ANSI_WARNINGS OFF                
   SET QUOTED_IDENTIFIER OFF                
   SET CONCAT_NULL_YIELDS_NULL OFF                
                
DECLARE @storerkey NVARCHAR(10), @TotalLines INT                
DECLARE @c_Orderkey NVARCHAR(10), @n_TTLQty INT                
                
SELECT TOP 1 @storerkey =  Storerkey                
FROM ORDERS (NOLOCK)                
WHERE OrderKey =  @loadkey                
                
CREATE TABLE #HM_Label1                
(OrderNo             INT,                
 OrderKey            NVARCHAR(10),                
 LogicalLocation     NVARCHAR(20),                
 SKU                 NVARCHAR(20),                
 Route               NVARCHAR(20),                
 Qty                 INT,                
 Loc                 NVARCHAR(10),                
 Loadkey             NVARCHAR(10),                
 ExternLineNo        NVARCHAR(20),                
 LineNumber          INT,                
 TotalLines          INT,                
 SKUDESCR            NVARCHAR(90))                
                
SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) AS OrderNo,Orderkey as orderkey,LoadKey as loadkey                
INTO #Temp1                
FROM  Orders WITH (NOLOCK)                
WHERE Storerkey = @storerkey AND OrderKey = @loadkey AND (Route = @route or @route = 0)                                
SELECT a.OrderKey as orderkey, b.SKU as sku, c.LogicalLocation as LogicalLocation ,b.Loc as loc , a.Route as [Route], SUM(b.Qty) as qty,                
       d.ExternLineNo as ExternLineNo,                
       /*RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) as SKUDESCR*/--V1.4                
       S.DESCR as SKUDESCR                
       /* 2016/11/28 --> Start */                
       , C.Score                
       /* 2016/11/28 <-- End */                
INTO #TEMP2                
FROM Orders a WITH (NOLOCK)                
JOIN PickDetail b (NOLOCK) ON a.OrderKey = b.OrderKey                
JOIN Loc c (NOLOCK) ON b.Loc = c.Loc                
JOIN OrderDetail d (NOLOCK) ON b.OrderKey = d.OrderKey AND b.OrderLineNumber = d.OrderLineNumber                
/* 2018/08/10 --> Start */                
JOIN SKU S (NOLOCK) ON S.sku = b.SKU AND S.storerkey = b.storerkey                
/* 2018/08/10 --> End */                
WHERE a.Storerkey = @storerkey AND a.OrderKey = @loadkey                
GROUP BY a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,                
         d.ExternLineNo,                
         /* 2018/08/10 --> Start */                
         S.DESCR                
         /* 2018/08/10 --> End */                
         /*RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))*/ --V1.4                
         /* 2016/11/28 --> Start */                
         , C.Score                
         /* 2016/11/28 <-- End */                
                
/* 2018/08/10 --> Start */                
SELECT                
   a.orderkey,a.sku,a.logicallocation,a.loc,a.route,[qty]=1,a.externlineno,a.skudescr,a.score                
INTO #TEMP3                
FROM #TEMP2 AS A(NOLOCK)                
INNER JOIN [master].dbo.spt_values AS M(NOLOCK) ON a.qty > m.number                
WHERE m.[type] = 'p'                
/* 2018/08/10 --> End */                
                
INSERT INTO #HM_Label1                
      (OrderNo,            OrderKey,           LogicalLocation,            SKU,                
       Route,              Qty,                Loc,                        Loadkey,                
       ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR)                
SELECT  t1.OrderNo,         t1.OrderKey,        t2.LogicalLocation,         t2.SKU,                
        t2.Route,           t2.Qty,             t2.Loc,                     t1.LoadKey,                
        t2.ExternLineNo,                
        /* 2017/11/15 --> Start */                
        /* 2016/11/28 --> Start */                
        -- ROW_NUMBER() OVER (ORDER BY t2.LogicalLocation,t2.Loc,t2.SKU,t1.OrderKey),                
        --  ROW_NUMBER() OVER (ORDER BY t2.Score,t2.Loc,t2.SKU,t1.OrderKey),                
        ROW_NUMBER() OVER (ORDER BY t2.Score,t2.LogicalLocation,t2.Loc,t1.OrderKey),                
        /* 2016/11/28 <-- End */                
        /* 2017/11/15 <-- End */                
        0,   t2.SKUDESCR                
        /*from #TEMP1 AS t1 JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey*/ --V1.4                
        /* 2018/08/10 --> Start */                
FROM #TEMP1 AS t1 JOIN #TEMP3 AS t2 ON t1.orderkey = t2.orderkey                
/* 2018/08/10 --> End */                
/* 2016/11/28 --> Start */                
-- order by t2.LogicalLocation,t2.Loc,t2.SKU,t1.OrderKey                
-- order by t2.Score ,t2.Loc,t2.SKU,t1.OrderKey                
/* 2016/11/28 <-- End */                
                
SELECT @TotalLines = COUNT(*)                
FROM #HM_Label1 (NOLOCK)                
                
UPDATE #HM_Label1                
SET TotalLines = @TotalLines                
                
DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                
   SELECT DISTINCT Orderkey                
   FROM #HM_Label1                
   Order by Orderkey                
                
OPEN CUR_Orderkey                
FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey                
                
WHILE @@FETCH_STATUS <> -1                
BEGIN                
   SET @n_TTLQty = 0                
                
   SELECT @n_TTLQty = SUM(qty)                
   FROM #HM_Label1                
   WHERE OrderKey = @c_Orderkey                
                
   UPDATE #HM_Label1                
   SET Qty = @n_TTLQty                
   WHERE Orderkey=@c_Orderkey                
                
   FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey                
END                
CLOSE CUR_Orderkey                
DEALLOCATE  CUR_Orderkey                
                
--update #HM_Label1                
--set Qty = b.Qty                
--from #HM_Label1 a JOIN (select OrderKey, sum(Qty) as Qty from #HM_Label1  group by OrderKey) as b ON a.OrderKey = b.OrderKey                
                
SELECT                 
   A.OrderNo,            A.OrderKey,           A.LogicalLocation,                
   /* substring(SKU,1,7) + ' '+substring(SKU,8,3) + ' ' + substring(SKU,12,2) as SKU,        */ -- V1.3                
   A.SKU , -- V1.3                
   A.Route,              A.Qty,                A.Loc,                        A.Loadkey,                
   A.ExternLineNo,       ROW_NUMBER() OVER (Partition By A.OrderKey Order By A.Sku ) as 'A.LineNumber',                     
   A.TotalLines,                 A.SKUDESCR,                
   B.pickheaderkey                
FROM #HM_Label1 AS A(NOLOCK)                
JOIN  PICKHEADER AS B (NOLOCK) ON A.ORDERKEY = B.ORDERKEY                
ORDER BY A.sku,A.loc      

END

GO