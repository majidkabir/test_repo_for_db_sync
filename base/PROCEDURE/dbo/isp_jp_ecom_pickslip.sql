SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/                        
/* Store Procedure: isp_jp_ECOM_PickSlip                                      */                        
/* Creation Date: 08-SEP-2015                                                 */                        
/* Copyright: IDS                                                             */                        
/* Written by: CSCHONG                                                        */                        
/*                                                                            */                        
/* Purpose: For CN LIT datawindow                                             */            
/*                                                                            */                        
/*                                                                            */                        
/* Called By:  r_jp_ecom_pickslip                                             */                        
/*                                                                            */                        
/* PVCS Version: 1.6                                                          */                        
/*                                                                            */                        
/* Version: 1.1                                                               */                        
/*                                                                            */                        
/* Data Modifications:                                                        */                        
/*                                                                            */                        
/* Updates:                                                                   */                        
/* Date         Author    Ver.  Purposes                                      */      
/* 2016/11/18   Chen      1.1   Update Sorting Rule -> Loc.Score              */      
/* 2017/11/15   Marc      1.2   Update Sorting Rule -> LogicalLocation, remove SKU */      
/* 2018/08/10   Chen      1.3   Change the SKU display logic -> Show full SKU */    
/* 2018/08/10   Cloud     1.4   Make 1 unit per line                          */   
/* 2019/12/30   WLChooi   1.5   WMS-11631 - Add ExternOrderkey (WL01)         */ 
/* 06-Jan-2022  WLChooi   1.6   DevOps Combine Script                         */
/* 06-Jan-2022  WLChooi   1.6   WMS-18697 - Add LoadkeyFrom & LoadkeyTo as    */
/*                              input parameter (WL02)                        */
/******************************************************************************/            
          
CREATE PROC [dbo].[isp_jp_ECOM_PickSlip] 
   @c_Storerkey   NVARCHAR(15),   --WL02  
   @c_LoadkeyFrom NVARCHAR(10),   --WL02    
   @c_LoadkeyTo   NVARCHAR(10),   --WL02    
   @c_Route       NVARCHAR(10)    --WL02                     
AS           
           
BEGIN                      
   SET NOCOUNT ON                      
   SET ANSI_WARNINGS OFF        
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF                      
   SET CONCAT_NULL_YIELDS_NULL OFF            
            
   --DECLARE @storerkey NVARCHAR(10),   --WL02
   DECLARE @c_Loadkey    NVARCHAR(10), @n_TotalLines INT   --WL02           
   DECLARE @c_Orderkey   NVARCHAR(10), @n_TTLQty INT        
   
   --WL02 S       
   --SELECT TOP 1 @storerkey =  Storerkey          
   --FROM ORDERS (NOLOCK)          
   --WHERE LOADKEY =  @c_loadkey    
   --WL02 E       
            
   CREATE TABLE #HM_Label1            
   (OrderNo             INT,            
    OrderKey            NVARCHAR(10),            
    LogicalLocation     NVARCHAR(20),            
    SKU                 NVARCHAR(20),            
    [Route]               NVARCHAR(20),            
    Qty                 INT,            
    Loc                 NVARCHAR(10),            
    Loadkey             NVARCHAR(10),            
    ExternLineNo        NVARCHAR(20),            
    LineNumber          INT,            
    TotalLines          INT,            
    SKUDESCR            NVARCHAR(90),
    Externorderkey      NVARCHAR(50) )   --WL01            

   --WL02 S   
   CREATE TABLE #HM_Orderkey
   (Orderkey            NVARCHAR(10),
    Loadkey             NVARCHAR(10) )
    
   INSERT INTO #HM_Orderkey
   SELECT DISTINCT OH.Orderkey, OH.LoadKey
   FROM ORDERS OH (NOLOCK)
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
   WHERE LPD.Loadkey BETWEEN @c_Loadkeyfrom AND @c_Loadkeyto 
   AND OH.Storerkey = @c_Storerkey
   AND (OH.[Route] = @c_Route OR @c_Route = 0)

   CREATE TABLE #Temp1 (
      OrderNo           INT
    , Orderkey          NVARCHAR(10)
    , Loadkey           NVARCHAR(10)
    , ExternOrderkey    NVARCHAR(50)
   )

   CREATE TABLE #Temp2 (
      Orderkey          NVARCHAR(10)
    , SKU               NVARCHAR(20)
    , LogicalLocation   NVARCHAR(20)
    , LOC               NVARCHAR(10)
    , [Route]           NVARCHAR(10)
    , Qty               INT
    , ExternLineNo      NVARCHAR(50)
    , SKUDESCR          NVARCHAR(100)
    , Score             INT )
   
   CREATE TABLE #Temp3 (
      Orderkey          NVARCHAR(10)
    , SKU               NVARCHAR(20)
    , LogicalLocation   NVARCHAR(20)
    , LOC               NVARCHAR(10)
    , [Route]           NVARCHAR(10)
    , Qty               INT
    , ExternLineNo      NVARCHAR(50)
    , SKUDESCR          NVARCHAR(100)
    , Score             INT )

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT T.Loadkey
   FROM #HM_Orderkey T
   ORDER BY T.Loadkey

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN          
      INSERT INTO #Temp1(OrderNo, Orderkey, Loadkey, ExternOrderkey)   --WL02
      SELECT ROW_NUMBER() OVER (ORDER BY Orders.OrderKey), Orders.Orderkey   --WL02
           , Orders.LoadKey   --WL02
           , Orders.Externorderkey   --WL01   --WL02           
      --INTO #Temp1   --WL02           
      FROM  Orders WITH (NOLOCK) 
      JOIN #HM_Orderkey t on Orders.OrderKey = t.Orderkey   --WL02               
      --WHERE Storerkey = @c_Storerkey and Loadkey = @c_loadkey AND (Route = @c_Route or @c_Route = 0)   --WL02  
      WHERE Storerkey = @c_Storerkey   --WL02 
      AND T.Loadkey = @c_Loadkey       --WL02
      AND ([Route] = @c_Route OR @c_Route = 0) --WL02          
      
      INSERT INTO #Temp2(Orderkey, SKU, LogicalLocation, LOC, [Route], Qty, ExternLineNo, SKUDESCR, Score)   --WL02
      SELECT a.OrderKey as orderkey, b.SKU as sku, c.LogicalLocation as LogicalLocation ,b.Loc as loc , a.[Route] as [Route], SUM(b.Qty) as qty,   
             d.ExternLineNo as ExternLineNo,    
             /*RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) as SKUDESCR*/--V1.4      
             S.DESCR as SKUDESCR    
             /* 2016/11/28 --> Start */      
             , C.Score      
             /* 2016/11/28 <-- End */      
      --INTO #TEMP2   --WL02          
      FROM Orders a WITH (NOLOCK)          
      JOIN PickDetail b(NOLOCK) on a.OrderKey = b.OrderKey            
      JOIN Loc c (NOLOCK) on b.Loc = c.Loc            
      JOIN OrderDetail d (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber    
      /* 2018/08/10 --> Start */      
      JOIN SKU S(NOLOCk) on S.sku = b.SKU and S.storerkey = b.storerkey    
      /* 2018/08/10 --> End */           
      WHERE a.Storerkey = @c_Storerkey AND a.LoadKey = @c_loadkey   --WL02          
      GROUP BY a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.[Route],            
             d.ExternLineNo,    
             /* 2018/08/10 --> Start */     
             S.DESCR    
             /* 2018/08/10 --> End */     
             /*RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))*/ --V1.4           
             /* 2016/11/28 --> Start */      
             , C.Score      
             /* 2016/11/28 <-- End */      
       
      INSERT INTO #Temp3(Orderkey, SKU, LogicalLocation, LOC, [Route], Qty, ExternLineNo, SKUDESCR, Score)   --WL02
      /* 2018/08/10 --> Start */    
      SELECT     
      a.orderkey,a.sku,a.logicallocation,a.loc,a.[Route],[qty]=1,a.externlineno,a.skudescr,a.score    
      --INTO #TEMP3   --WL02      
      FROM #TEMP2 as a(nolock)     
      INNER JOIN [master].dbo.spt_values as m(nolock) on a.qty > m.number    
      WHERE m.[type]='p'    
      /* 2018/08/10 --> End */            
       
      INSERT INTO #HM_Label1            
      (OrderNo,            OrderKey,           LogicalLocation,            SKU,            
       [Route],            Qty,                Loc,                        Loadkey,            
       ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
       Externorderkey )   --WL01            
      SELECT  t1.OrderNo,         t1.OrderKey,        t2.LogicalLocation,         t2.SKU,            
              t2.[Route],         t2.Qty,             t2.Loc,                     t1.LoadKey,            
              t2.ExternLineNo,          
      /* 2017/11/15 --> Start */       
      /* 2016/11/28 --> Start */       
      -- ROW_NUMBER() OVER (ORDER BY t2.LogicalLocation,t2.Loc,t2.SKU,t1.OrderKey),      
      --  ROW_NUMBER() OVER (ORDER BY t2.Score,t2.Loc,t2.SKU,t1.OrderKey),      
      ROW_NUMBER() OVER (ORDER BY t2.LogicalLocation,t2.Loc,t1.OrderKey),      
      /* 2016/11/28 <-- End */      
      /* 2017/11/15 <-- End */      
      0,   t2.SKUDESCR,  t1.Externorderkey           
      /*from #TEMP1 AS t1 JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey*/ --V1.4    
      /* 2018/08/10 --> Start */    
      FROM #TEMP1 AS t1 JOIN #TEMP3 AS t2 ON t1.orderkey = t2.orderkey    
      /* 2018/08/10 --> End */          
      /* 2016/11/28 --> Start */       
      -- order by t2.LogicalLocation,t2.Loc,t2.SKU,t1.OrderKey            
      --  order by t2.Score ,t2.Loc,t2.SKU,t1.OrderKey      
      /* 2016/11/28 <-- End */      
               
      SELECT @n_TotalLines = COUNT(*)            
      FROM #HM_Label1(nolock) 
      WHERE Loadkey = @c_Loadkey   --WL02           
               
      UPDATE #HM_Label1            
      SET TotalLines = @n_TotalLines
      WHERE Loadkey = @c_Loadkey   --WL02               
           
      DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR          
      SELECT DISTINCT Orderkey        
      FROM #HM_Label1
      WHERE Loadkey = @c_Loadkey   --WL02            
      ORDER BY Orderkey        
              
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
         WHERE Orderkey = @c_Orderkey        
               
         FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey         
      END        
              
      CLOSE CUR_Orderkey        
      DEALLOCATE  CUR_Orderkey 
        
      TRUNCATE TABLE #Temp1   --WL02
      TRUNCATE TABLE #Temp2   --WL02
      TRUNCATE TABLE #Temp3   --WL02

      FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey
   END    
   CLOSE CUR_LOOP    
   DEALLOCATE CUR_LOOP
   --WL02 E   
            
   --update #HM_Label1             
   --set Qty = b.Qty            
   --from #HM_Label1 a join (select OrderKey, sum(Qty) as Qty from #HM_Label1  group by OrderKey) as b on a.OrderKey = b.OrderKey             
            
   SELECT             
      OrderNo,            OrderKey,           LogicalLocation,                
      /* substring(SKU,1,7) + ' '+substring(SKU,8,3) + ' ' + substring(SKU,12,2) as SKU,        */ -- V1.3    
      SKU , -- V1.3    
      [Route],            Qty,                Loc,                        Loadkey,            
      ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
      Externorderkey     --WL01            
   FROM #HM_Label1(nolock)            
   ORDER BY Loadkey, LogicalLocation, LineNumber   --WL02        
          
   --WL02 START
   IF OBJECT_ID('tempdb..#TEMP1') IS NOT NULL
      DROP TABLE #TEMP1

   IF OBJECT_ID('tempdb..#TEMP2') IS NOT NULL
      DROP TABLE #TEMP2

   IF OBJECT_ID('tempdb..#TEMP3') IS NOT NULL
      DROP TABLE #TEMP3

   IF OBJECT_ID('tempdb..#HM_Label1') IS NOT NULL
      DROP TABLE #HM_Label1

   IF OBJECT_ID('tempdb..#HM_Orderkey') IS NOT NULL
      DROP TABLE #HM_Orderkey
   --WL02 END      
END          


SET QUOTED_IDENTIFIER OFF 

GO