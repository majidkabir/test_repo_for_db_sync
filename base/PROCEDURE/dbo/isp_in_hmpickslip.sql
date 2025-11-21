SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/******************************************************************************/                    
/* Store Procedure: isp_in_hmpickslip                                         */                    
/* Creation Date: 18-SEP-2019                                                 */                    
/* Copyright: LFL                                                             */                    
/* Written by: WLChooi                                                        */                    
/*                                                                            */                    
/* Purpose: WMS-10663 - For IN LIT datawindow                                 */        
/*          Copy from isp_jp_hmpickslip                                       */                    
/*                                                                            */                    
/* Called By:  r_in_hmpickslip                                                */                    
/*                                                                            */                    
/* PVCS Version: 1.5                                                          */                    
/*                                                                            */                    
/* Version: 1.1                                                               */                    
/*                                                                            */                    
/* Data Modifications:                                                        */                    
/*                                                                            */                    
/* Updates:                                                                   */                    
/* Date         Author    Ver.  Purposes                                      */ 
/* 17-Dec-2019  WLChooi   1.1   WMS-11366 - Add more column (WL01)            */  
/* 03-Feb-2020  WLChooi   1.2   Bug Fix - Sort by LineNumber (WL02)           */  
/* 06-Dec-2021  WLChooi   1.3   DevOps Combine Script                         */
/* 06-Dec-2021  WLChooi   1.3   WMS-18519 - Add Marketplace flag (WL03)       */ 
/* 29-Dec-2021  WLChooi   1.4   WMS-18621 - Change date mapping & format(WL04)*/ 
/* 28-Apr-2021  WLChooi   1.5   WMS-16923 Enable printing by range of loadkey */ 
/*                              (WL05)                                        */
/* 26-Jun-2022  Mingle    1.6   WMS-20041 - Add showadddate(ML01)             */ 
/******************************************************************************/        
      
CREATE PROC [dbo].[isp_in_hmpickslip]      
   --WL05 S 
   @c_storerkey   NVARCHAR(15),   
   @c_loadkeyfrom NVARCHAR(10),        
   @c_loadkeyto   NVARCHAR(10),  
   @c_route       NVARCHAR(10) 
   --WL05 E
   --@c_Route   NVARCHAR(10),  --WL03        
   --@c_Loadkey NVARCHAR(10)   --WL03     
AS       
       
BEGIN                  
   SET NOCOUNT ON                  
   SET ANSI_WARNINGS OFF                  
   SET QUOTED_IDENTIFIER OFF                  
   SET CONCAT_NULL_YIELDS_NULL OFF        
   
   --DECLARE @c_Storerkey NVARCHAR(10),   --WL05
   DECLARE @n_TotalLines INT   --WL03   --WL05       
   DECLARE @c_Orderkey   NVARCHAR(10),@n_TTLQty INT
   
   DECLARE @n_StartTCnt     INT
          ,@n_Continue      INT = 1
          ,@b_Success       INT = 0
          ,@n_Err           INT = 0 
          ,@c_ErrMsg        NVARCHAR(255) = ''
          ,@n_CurrentUser   NVARCHAR(255) = ''
          ,@b_Superuser     INT = 0
          ,@c_Loadkey       NVARCHAR(10)   --WL05

   SET @n_StartTCnt        = @@TRANCOUNT
   SET @n_CurrentUser      = SUSER_NAME()

   --WL03 S
   SELECT TOP 1 @c_Storerkey = Storerkey    
   FROM ORDERS OH (NOLOCK)  
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = OH.Orderkey    
   WHERE LPD.LOADKEY = @c_Loadkey
   --WL03 E  
   
   CREATE TABLE #HM_Orderkey
   (Orderkey            NVARCHAR(10),
    Notes               NVARCHAR(255),
    Loadkey             NVARCHAR(10) )   --WL05
    
   INSERT INTO #HM_Orderkey
   SELECT OH.Orderkey, ISNULL(PD.Notes,''), OH.LoadKey   --WL05
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON PD.Orderkey = OH.Orderkey
   JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = OH.Orderkey
   --WHERE LPD.Loadkey = @c_Loadkey   --WL03   --WL05  
   WHERE LPD.Loadkey BETWEEN @c_Loadkeyfrom AND @c_Loadkeyto   --WL05
   AND OH.Storerkey = @c_Storerkey   --WL05
   AND (OH.Route = @c_Route OR @c_Route = 0)   --WL03     
   GROUP BY OH.Orderkey, ISNULL(PD.Notes,''), OH.LoadKey   --WL05     

   IF EXISTS (SELECT 1 FROM CODELKUP (NOLOCK) 
              WHERE LISTNAME = 'HMSUPER'
              AND Long = 'r_in_hmpickslip'
              AND Code = @n_CurrentUser
              AND Storerkey = @c_Storerkey)   --WL03
   BEGIN
      SET @b_Superuser = 1
   END
   ELSE
   BEGIN
      SET @b_Superuser = 0
   END

   IF EXISTS (SELECT 1 FROM #HM_Orderkey WHERE Notes = 'PRINTED')
   BEGIN      
      IF @b_Superuser = 0
      BEGIN
         DELETE FROM #HM_Orderkey
         WHERE Notes = 'PRINTED'
      END
   END
   
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
    LocAisle            NVARCHAR(10),  --WL01 
    MarketPlace         NVARCHAR(50),  --WL03
    LPAddDate           NVARCHAR(10),  --WL03
	ShowAddDate         NVARCHAR(5)	   --ML01
    )        
         
   --WL05 S
   CREATE TABLE #Temp1 (
      OrderNo           INT
    , Orderkey          NVARCHAR(10)
    , Loadkey           NVARCHAR(10)
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
    , Score             INT
    , [Floor]           NVARCHAR(3)
    , Pickzone          NVARCHAR(10)
    , LocAisle          NVARCHAR(10)
    , MarketPlace       NVARCHAR(50)
    , LPAddDate         NVARCHAR(10)
	, ShowAddDate       NVARCHAR(5)
   )
   
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT T.Loadkey
   FROM #HM_Orderkey T

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN  
      INSERT INTO #Temp1(OrderNo, Orderkey, Loadkey)   --WL05
      SELECT ROW_NUMBER() OVER (ORDER BY Orders.OrderKey) AS OrderNo,Orders.Orderkey as orderkey,Orders.LoadKey as loadkey       
      --INTO #Temp1       
      FROM  Orders WITH (NOLOCK)
      JOIN #HM_Orderkey t on Orders.OrderKey = t.Orderkey            
      WHERE Storerkey = @c_Storerkey   --WL03 
      --and Loadkey = @c_Loadkey 
      AND T.Loadkey = @c_Loadkey   --WL05
      AND (Route = @c_Route or @c_Route = 0)   --WL03         
      
      INSERT INTO #Temp2(Orderkey, SKU, LogicalLocation, LOC, Route, Qty, ExternLineNo, SKUDESCR, Score, [Floor], Pickzone
                       , LocAisle, MarketPlace, LPAddDate,ShowAddDate)   --WL05	--ML01
      SELECT a.OrderKey as orderkey, b.SKU as sku, c.LogicalLocation as LogicalLocation ,b.Loc as loc , a.Route as [Route], SUM(b.Qty) as qty,       
             d.ExternLineNo as ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) as SKUDESCR  
          /* 2016/11/28 --> Start */  
          , C.Score  
          /* 2016/11/28 <-- End */  
          , c.[Floor], c.PickZone, c.LocAisle   --WL01
          , ISNULL(CL.Short,'HM') AS MarketPlace   --WL03
          , CONVERT(NVARCHAR(5), a.AddDate, 103) + RIGHT(CONVERT(NVARCHAR(10), a.AddDate, 103),5) AS LPAddDate   --WL03   --WL04
		  , ISNULL(CL2.SHORT,'') AS ShowAddDate	--ML01
      --INTO #TEMP2      
      FROM Orders a WITH (NOLOCK)      
      JOIN PickDetail b(NOLOCK) on a.OrderKey = b.OrderKey        
      JOIN Loc c (NOLOCK) on b.Loc = c.Loc        
      JOIN OrderDetail d (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber     
      JOIN #HM_Orderkey t on a.OrderKey = t.Orderkey   
      LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'MARKETPLAC' AND CL.Code = a.[Type]   --WL03
                                    AND CL.Storerkey = a.Storerkey   --WL03
      LEFT JOIN CODELKUP CL2 (NOLOCK) ON CL2.LISTNAME = 'REPORTCFG' AND CL2.Long = 'r_in_hmpickslip'   
                                    AND CL2.Storerkey = a.Storerkey AND CL2.Code = 'ShowAddDate'	--ML01
      --JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = a.OrderKey   --WL03   --WL04
   --JOIN LOADPLAN LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey   --WL03   --WL04
      WHERE a.Storerkey = @c_Storerkey   --WL03 
       --and a.LoadKey = @c_Loadkey     
      AND a.LoadKey = @c_Loadkey   --WL05 
      GROUP BY a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,        
             d.ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,''))       
             /* 2016/11/28 --> Start */  
          , C.Score  
          /* 2016/11/28 <-- End */  
          , c.[Floor], c.PickZone, c.LocAisle   --WL01
          , ISNULL(CL.Short,'HM')   --WL03
          , CONVERT(NVARCHAR(5), a.AddDate, 103) + RIGHT(CONVERT(NVARCHAR(10), a.AddDate, 103),5)   --WL03   --WL04
		  , ISNULL(CL2.SHORT,'')
               
      INSERT INTO #HM_Label1        
             (OrderNo,            OrderKey,           LogicalLocation,            SKU,        
              Route,              Qty,                Loc,                        Loadkey,        
              ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
              [Floor],            Pickzone,           LocAisle,                   MarketPlace,   --WL01   --WL03
              LPAddDate,ShowAddDate)   --WL03	--ML01        
      SELECT  t1.OrderNo,         t1.OrderKey,        t2.LogicalLocation,         t2.SKU,        
              t2.Route,           t2.Qty,             t2.Loc,                     t1.LoadKey,        
              t2.ExternLineNo,      
      /* 2017/11/15 --> Start */   
      /* 2016/11/28 --> Start */   
        -- ROW_NUMBER() OVER (ORDER BY t2.LogicalLocation,t2.Loc,t2.SKU,t1.OrderKey),  
      --  ROW_NUMBER() OVER (ORDER BY t2.Score,t2.Loc,t2.SKU,t1.OrderKey),  
      --ROW_NUMBER() OVER (ORDER BY t2.Score,t2.LogicalLocation,t2.Loc,t1.OrderKey),  --WL02
      ROW_NUMBER() OVER (ORDER BY t2.[Floor],t2.Pickzone,T2.LocAisle,t2.LogicalLocation,t1.OrderKey),  --WL02
      /* 2016/11/28 <-- End */  
      /* 2017/11/15 <-- End */  
      0,   t2.SKUDESCR,
      t2.[Floor], t2.Pickzone, t2.LocAisle, t2.MarketPlace, t2.LPAddDate,   --WL01   --WL03  
	  t2.ShowAddDate	--ML01
      from #TEMP1 AS t1 JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey       
      /* 2016/11/28 --> Start */   
      -- order by t2.LogicalLocation,t2.Loc,t2.SKU,t1.OrderKey        
      --  order by t2.Score ,t2.Loc,t2.SKU,t1.OrderKey  
      /* 2016/11/28 <-- End */  
              
      SELECT @n_TotalLines = count(*)   --WL03        
      FROM #HM_Label1(NOLOCK)   
      WHERE Loadkey = @c_Loadkey   --WL05     
              
      UPDATE #HM_Label1        
      SET TotalLines = @n_TotalLines   --WL03       
      WHERE Loadkey = @c_Loadkey   --WL05    
          
      DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
      SELECT DISTINCT Orderkey    
      FROM #HM_Label1   
      WHERE Loadkey = @c_Loadkey   --WL05  
      ORDER by Orderkey    
          
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
         WHERE Orderkey = @c_Orderkey AND Storerkey = @c_Storerkey   --WL03
             
         FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey     
      END    
          
      CLOSE CUR_Orderkey    
      DEALLOCATE  CUR_Orderkey   
      
      TRUNCATE TABLE #Temp1   --WL05
      TRUNCATE TABLE #Temp2   --WL05

      FETCH NEXT FROM CUR_LOOP INTO @c_Loadkey
   END    
   CLOSE CUR_LOOP    
   DEALLOCATE CUR_LOOP
   --WL05 E
           
   --update #HM_Label1         
   --set Qty = b.Qty        
   --from #HM_Label1 a join (SELECT OrderKey, sum(Qty) as Qty from #HM_Label1  group by OrderKey) as b on a.OrderKey = b.OrderKey                 
   SELECT         
   OrderNo,            OrderKey,           LogicalLocation,            SUBSTRING(SKU,1,7) + ' '+SUBSTRING(SKU,8,3) + ' ' + SUBSTRING(SKU,11,10) as SKU,   --WL03        
   Route,              Qty,                Loc,                        Loadkey,        
   ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR,
   [Floor],            Pickzone,           LocAisle,                   MarketPlace,   --WL01   --WL03
   LPAddDate,ShowAddDate   --WL03	--ML01
   FROM #HM_Label1(NOLOCK)        
   ORDER BY Loadkey DESC, LineNumber DESC  --WL02   --WL05
   --ORDER BY [Floor], Pickzone, LocAisle, LogicalLocation DESC      --WL02

   --WL01 START
   IF OBJECT_ID('tempdb..#TEMP1') IS NOT NULL
      DROP TABLE #TEMP1

   IF OBJECT_ID('tempdb..#TEMP2') IS NOT NULL
      DROP TABLE #TEMP2

   IF OBJECT_ID('tempdb..#HM_Label1') IS NOT NULL
      DROP TABLE #HM_Label1
   --WL01 END

   IF OBJECT_ID('tempdb..#HM_Orderkey') IS NOT NULL   --WL05
      DROP TABLE #HM_Orderkey                         --WL05
      
END      

GO