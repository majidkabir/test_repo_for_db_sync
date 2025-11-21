SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                    
/* Store Procedure: isp_jp_hmpickslip                                         */                    
/* Creation Date: 08-SEP-2015                                                 */                    
/* Copyright: IDS                                                             */                    
/* Written by: CSCHONG                                                        */                    
/*                                                                            */                    
/* Purpose: For CN LIT datawindow                                             */        
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
/* 2017/11/15   Marc      1.2   Update Sorting Rule -> LogicalLocation, remove SKU*/  
/******************************************************************************/        
      
CREATE proc [dbo].[isp_jp_hmpickslip]      
@route nvarchar(1),        
@loadkey nvarchar(10)       
AS       
       
BEGIN                  
   SET NOCOUNT ON                  
   SET ANSI_WARNINGS OFF                  
   SET QUOTED_IDENTIFIER OFF                  
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
DECLARE @storerkey nvarchar(10),@TotalLines int        
DECLARE @c_Orderkey nvarchar(10),@n_TTLQty INT    
      
SELECT TOP 1 @storerkey =  Storerkey      
FROM ORDERS (NOLOCK)      
WHERE LOADKEY =  @loadkey       
        
create table #HM_Label1        
(OrderNo             int,        
 OrderKey            nvarchar(10),        
 LogicalLocation     nvarchar(20),        
 SKU                 nvarchar(20),        
 Route               nvarchar(20),        
 Qty                 int,        
 Loc                 nvarchar(10),        
 Loadkey             nvarchar(10),        
 ExternLineNo        nvarchar(20),        
 LineNumber          int,        
 TotalLines          int,        
 SKUDESCR            nvarchar(90))        
      
      
SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) AS OrderNo,Orderkey as orderkey,LoadKey as loadkey       
INTO #Temp1       
FROM  Orders WITH (NOLOCK)            
WHERE Storerkey = @storerkey and Loadkey = @loadkey AND (Route = @route or @route = 0)      
      
SELECT a.OrderKey as orderkey, b.SKU as sku, c.LogicalLocation as LogicalLocation ,b.Loc as loc , a.Route as [Route], SUM(b.Qty) as qty,       
       d.ExternLineNo as ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) as SKUDESCR  
    /* 2016/11/28 --> Start */  
    , C.Score  
    /* 2016/11/28 <-- End */  
  INTO #TEMP2      
  FROM Orders a WITH (NOLOCK)      
  JOIN PickDetail b(NOLOCK) on a.OrderKey = b.OrderKey        
  JOIN Loc c (NOLOCK) on b.Loc = c.Loc        
  JOIN OrderDetail d (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber        
 WHERE a.Storerkey = @storerkey and a.LoadKey = @loadkey      
 GROUP BY a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,        
       d.ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))       
       /* 2016/11/28 --> Start */  
    , C.Score  
    /* 2016/11/28 <-- End */  
         
insert into #HM_Label1        
       (OrderNo,            OrderKey,           LogicalLocation,            SKU,        
        Route,              Qty,                Loc,                        Loadkey,        
        ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR)        
select  t1.OrderNo,         t1.OrderKey,        t2.LogicalLocation,         t2.SKU,        
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
  from #TEMP1 AS t1 JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey       
/* 2016/11/28 --> Start */   
-- order by t2.LogicalLocation,t2.Loc,t2.SKU,t1.OrderKey        
--  order by t2.Score ,t2.Loc,t2.SKU,t1.OrderKey  
/* 2016/11/28 <-- End */  
        
select @TotalLines = count(*)        
from #HM_Label1(nolock)        
        
update #HM_Label1        
set TotalLines = @TotalLines        
    
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
--from #HM_Label1 a join (select OrderKey, sum(Qty) as Qty from #HM_Label1  group by OrderKey) as b on a.OrderKey = b.OrderKey         
        
SELECT         
 OrderNo,            OrderKey,           LogicalLocation,            substring(SKU,1,7) + ' '+substring(SKU,8,3) + ' ' + substring(SKU,12,2) as SKU,        
 Route,              Qty,                Loc,                        Loadkey,        
 ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR        
FROM #HM_Label1(nolock)        
ORDER BY LineNumber        
      
      
END      

GO