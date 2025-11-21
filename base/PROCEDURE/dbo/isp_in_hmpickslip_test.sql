SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                    
/* Store Procedure: isp_in_hmpickslip_test                                         */                    
/* Creation Date: 18-SEP-2019                                                 */                    
/* Copyright: LFL                                                             */                    
/* Written by: WLChooi                                                        */                    
/*                                                                            */                    
/* Purpose: WMS-10663 - For IN LIT datawindow                                 */        
/*          Copy from isp_jp_hmpickslip                                       */                    
/*                                                                            */                    
/* Called By:  r_in_hmpickslip                                                */                    
/*                                                                            */                    
/* PVCS Version: 1.0                                                          */                    
/*                                                                            */                    
/* Version: 1.1                                                               */                    
/*                                                                            */                    
/* Data Modifications:                                                        */                    
/*                                                                            */                    
/* Updates:                                                                   */                    
/* Date         Author    Ver.  Purposes                                      */ 
/* 17-Dec-2019  WLChooi   1.1   WMS-11366 - Add more column (WL01)            */
/******************************************************************************/        
      
CREATE PROC [dbo].[isp_in_hmpickslip_test]      
@route nvarchar(10),        
@loadkey nvarchar(10)   
AS       
       
BEGIN                  
   SET NOCOUNT ON                  
   SET ANSI_WARNINGS OFF                  
   SET QUOTED_IDENTIFIER OFF                  
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @storerkey nvarchar(10),@TotalLines int        
   DECLARE @c_Orderkey nvarchar(10),@n_TTLQty INT
   
   DECLARE @n_StartTCnt     INT
          ,@n_Continue      INT = 1
          ,@b_Success       INT = 0
          ,@n_Err           INT = 0 
          ,@c_ErrMsg        NVARCHAR(255) = ''
          ,@n_CurrentUser   NVARCHAR(255) = ''
          ,@b_Superuser     INT = 0

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_CurrentUser      = SUSER_NAME()

   SELECT TOP 1 @storerkey =  Storerkey      
   FROM ORDERS (NOLOCK)      
   WHERE LOADKEY =  @loadkey    
   
   CREATE TABLE #HM_Orderkey
   (Orderkey            NVARCHAR(10),
    Notes               NVARCHAR(255))
    
   INSERT INTO #HM_Orderkey
   SELECT OH.Orderkey, ISNULL(PD.Notes,'')
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
   WHERE LPD.Loadkey = @loadkey
   AND (OH.Route = @route or @route = 0)  
   GROUP BY OH.Orderkey, ISNULL(PD.Notes,'')    

   IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) 
              WHERE LISTNAME = 'HMSUPER'
              AND Long = 'r_in_hmpickslip'
              AND Code = @n_CurrentUser
              AND Storerkey = @storerkey)
   BEGIN
      SET @b_Superuser = 1
   END
   ELSE
   BEGIN
      SET @b_Superuser = 0
   END

   --IF EXISTS (SELECT 1 FROM #HM_Orderkey WHERE Notes = 'PRINTED')
   --BEGIN      
   --   IF @b_Superuser = 0
   --   BEGIN
   --      DELETE FROM #HM_Orderkey
   --      WHERE Notes = 'PRINTED'
   --   END
   --END
   
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
    SKUDESCR            NVARCHAR(90),
    [Floor]             NVARCHAR(3),   --WL01
    Pickzone            NVARCHAR(10),  --WL01
    LocAisle            NVARCHAR(10)   --WL01 
    )        
         
         
   SELECT ROW_NUMBER() OVER (ORDER BY Orders.OrderKey) AS OrderNo,Orders.Orderkey as orderkey,Orders.LoadKey as loadkey       
   INTO #Temp1       
   FROM  Orders WITH (NOLOCK)
   JOIN #HM_Orderkey t on Orders.OrderKey = t.Orderkey            
   WHERE Storerkey = @storerkey 
   --and Loadkey = @loadkey 
   AND (Route = @route or @route = 0)      
         
   SELECT a.OrderKey as orderkey, b.SKU as sku, c.LogicalLocation as LogicalLocation ,b.Loc as loc , a.Route as [Route], SUM(b.Qty) as qty,       
          d.ExternLineNo as ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) as SKUDESCR  
       /* 2016/11/28 --> Start */  
       , C.Score  
       /* 2016/11/28 <-- End */  
       , c.[Floor], c.PickZone, c.LocAisle   --WL01
   INTO #TEMP2      
   FROM Orders a WITH (NOLOCK)      
   JOIN PickDetail b(NOLOCK) on a.OrderKey = b.OrderKey        
   JOIN Loc c (NOLOCK) on b.Loc = c.Loc        
   JOIN OrderDetail d (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber     
   JOIN #HM_Orderkey t on a.OrderKey = t.Orderkey   
   WHERE a.Storerkey = @storerkey 
    --and a.LoadKey = @loadkey      
   GROUP BY a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,        
          d.ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))       
          /* 2016/11/28 --> Start */  
       , C.Score  
       /* 2016/11/28 <-- End */  
       , c.[Floor], c.PickZone, c.LocAisle   --WL01
            
   insert into #HM_Label1        
          (OrderNo,            OrderKey,           LogicalLocation,            SKU,        
           Route,              Qty,                Loc,                        Loadkey,        
           ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
           [Floor],            Pickzone,           LocAisle)     --WL01        
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
   0,   t2.SKUDESCR,
   t2.[Floor], t2.Pickzone, t2.LocAisle     --WL01          
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
      
      --Update Pickdetail.Notes to PRINTED
      UPDATE Pickdetail
      SET Notes = 'PRINTED'
      WHERE Orderkey = @c_Orderkey AND Storerkey = @storerkey
          
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
   ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
   [Floor],            Pickzone,           LocAisle                --WL01        
   FROM #HM_Label1(nolock)        
  -- ORDER BY LineNumber 
   ORDER BY [Floor], Pickzone, LocAisle, LogicalLocation DESC      --WL01

   --WL01 START
   IF OBJECT_ID('tempdb..#TEMP1') IS NOT NULL
      DROP TABLE #TEMP1

   IF OBJECT_ID('tempdb..#TEMP2') IS NOT NULL
      DROP TABLE #TEMP2

   IF OBJECT_ID('tempdb..#HM_Label1') IS NOT NULL
      DROP TABLE #HM_Label1
   --WL01 END
      
END      

GO