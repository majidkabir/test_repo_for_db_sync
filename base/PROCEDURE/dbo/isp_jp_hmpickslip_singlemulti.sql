SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
                  
/******************************************************************************/                    
/* Store Procedure: isp_jp_hmpickslip_singlemulti                             */                    
/* Creation Date: 29-Jul-2020                                                 */                    
/* Copyright: LFL                                                             */                    
/* Written by: LIT                                                            */                    
/*                                                                            */                    
/* Purpose: For JP LIT datawindow: r_jp_hmpickslip_singlemulti                */                    
/*          WMS-14161 - JP_HM_Picking Label Report_NEW                        */                    
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
/* 2020-09-14   WLChooi   1.1   Bug Fix (WL01)                                */                 
/******************************************************************************/                    
                    
CREATE PROC [dbo].[isp_jp_hmpickslip_singlemulti] (                    
   @c_StorerKey   NVARCHAR(10),                    
   @c_LoadKeyFrom NVARCHAR(10) ,                    
   @c_LoadKeyTo   NVARCHAR(10) ,                    
   @c_Route       NVARCHAR(1) = ''               
)                    
AS                    
                    
BEGIN                    
   SET NOCOUNT ON                    
   SET ANSI_WARNINGS OFF                    
   SET QUOTED_IDENTIFIER OFF                    
   SET CONCAT_NULL_YIELDS_NULL OFF                    
        
   DECLARE @n_OPENQTY INT, @c_RDS NVARCHAR(5), @c_TS NVARCHAR(20), @c_ECOM_SINGLE_FLAG NVARCHAR(5)
         , @n_Continue INT = 1, @c_Mode NVARCHAR(10) = ''
                                 
   SELECT TOP 1 @c_ECOM_SINGLE_FLAG = O.ECOM_SINGLE_FLAG
              , @c_RDS = O.RDS
              , @c_TS = O.UserDefine03 
   FROM ORDERS O (NOLOCK)
   JOIN LOADPLANDETAIL LP (NOLOCK) ON (O.ORDERKEY = LP.ORDERKEY)                                  
   WHERE LP.LOADKEY = @C_LoadKeyFrom   

   SELECT @n_OPENQTY = COUNT(DISTINCT ECOM_SINGLE_FLAG) 
   FROM ORDERS O (NOLOCK)
   JOIN LOADPLANDETAIL LP (NOLOCK) ON  (O.ORDERKEY = LP.ORDERKEY)                  
   WHERE LP.LOADKEY= @C_LoadKeyFrom  

   IF ISNULL(@c_Route,'') = '' SET @c_Route = ''

   --SELECT @c_RDS, @c_TS, @c_ECOM_SINGLE_FLAG

   IF @c_RDS = 'O' OR ISNULL(@c_TS,'') <> '' OR @c_ECOM_SINGLE_FLAG <> 'S'    
   BEGIN          
      SET @c_Mode = 'MULTI'         
   END     
   ELSE IF @c_RDS <> 'O' OR ISNULL(@c_TS,'') = ''                        
   BEGIN                
      IF @n_OPENQTY < 2  AND @c_ECOM_SINGLE_FLAG = 'S'                
      BEGIN                     
         SET @c_Mode = 'SINGLE'                  
      END                                     
   END       

   --SELECT @c_Mode

SINGLE:  
   IF (@n_Continue = 1 OR @n_Continue = 2) AND @c_Mode = 'SINGLE'
   BEGIN   
      ;WITH OrderList AS                    
      (                    
         SELECT RANK() OVER (PARTITION BY LoadKey ORDER BY OrderKey) OrderNo ,                    
                LoadKey , OrderKey                    
         FROM  Orders WITH (NOLOCK)                    
         WHERE Storerkey = @c_storerkey                    
           AND Loadkey BETWEEN @c_LoadKeyFrom AND @c_LoadKeyTo                    
           AND (Route = @c_route or @c_route = 0)                    
      ) ,                    
      PickData AS                    
      (                    
         SELECT a.LoadKey ,                    
                a.OrderKey AS orderkey, b.SKU AS sku, c.LogicalLocation AS LogicalLocation ,b.Loc AS loc , a.Route AS [Route], SUM(b.Qty) AS qty,                    
                d.ExternLineNo AS ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) AS SKUDESCR,                     
                C.Score                    
         FROM Orders a WITH (NOLOCK)                    
         JOIN PickDetail b WITH (NOLOCK) on a.OrderKey = b.OrderKey                    
         JOIN Loc c WITH (NOLOCK) on b.Loc = c.Loc                    
         JOIN OrderDetail d WITH (NOLOCK) on b.OrderKey = d.OrderKey AND b.OrderLineNumber = d.OrderLineNumber                    
         WHERE a.Storerkey = @c_storerkey AND a.LoadKey BETWEEN @c_LoadKeyFrom AND @c_LoadKeyTo                    
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
         JOIN PickData AS t2 ON t1.orderkey = t2.orderkey                    
         JOIN LoadLineCount AS T3 ON T1.LoadKey =  T3.LoadKey                    
         JOIN OrderQtyCount AS T4 ON T1.OrderKey = T4.orderkey                    
      )

      SELECT *, @c_Mode AS Mode FROM LabelDetail ORDER BY Loadkey , LineNumber
          
      GOTO QUIT_SP
   END     

MULTI:
   IF (@n_Continue = 1 OR @n_Continue = 2) AND @c_Mode = 'MULTI'  
   BEGIN      
      DECLARE @n_OrderSort       INT,                 
              @c_Orderkey        NVARCHAR(20),        
              @c_LogicalLocation NVARCHAR(36),        
              @c_SKU             NVARCHAR(40),        
              @c_GetROUTE        NVARCHAR(20),        
              @n_Qty             INT,                 
              @c_Loc             NVARCHAR(20),        
              @c_Loadkey         NVARCHAR(20),        
              @c_ExternLineNo    NVARCHAR(40),        
              @n_LineNumber      INT,
              @n_TotalLines      INT,                 
              @c_SKUDESCR        NVARCHAR(100),
              @n_ASCII           INT = 65, --Alphabet A
              @c_Alphabet        NVARCHAR(1) = '',
              @n_Count           INT = 40,
              @n_CurrCount       INT = 1,
              @c_PrevOrderkey    NVARCHAR(10)   --WL01

      CREATE TABLE #LOADSPLIT (                              
         ORDERNO         INT,                                                          
         ORDERKEY        NVARCHAR(20),                                         
         LOGICALLOCATION NVARCHAR(36),                                          
         SKU             NVARCHAR(40),                                
         ROUTE           NVARCHAR(20),                                            
         QTY             INT,                                              
         LOC             NVARCHAR(20),                                                      
         LOADKEY         NVARCHAR(20),                                
         EXTERNLINENO    NVARCHAR(40),                                     
         LINENUMBER      INT, --NVARCHAR(10),                                       
         TOTALLINES      INT,                                               
         SKUDESCR        NVARCHAR(100),                            
      )                              
                                   
      CREATE TABLE #LOADSPLIT2 (                                              
         ORDERSORT       NVARCHAR(5),               
         ORDERKEY        NVARCHAR(20),                                         
         LOGICALLOCATION NVARCHAR(36),                                   
         SKU             NVARCHAR(40),                                
         ROUTE           NVARCHAR(20),                             
         QTY             INT,                                              
         LOC             NVARCHAR(20),                     
         LOADKEY         NVARCHAR(20),                                
         EXTERNLINENO    NVARCHAR(40),                                     
         LINENUMBER      INT,--NVARCHAR(10),                                       
         TOTALLINES      INT,                                               
         SKUDESCR        NVARCHAR(100),                              
      )  
                     
      ;WITH OrderList AS                                  
      (                                  
         SELECT RANK() OVER (PARTITION BY LoadKey ORDER BY OrderKey) OrderNo ,                                  
                LoadKey , OrderKey                                  
         FROM  Orders WITH (NOLOCK)                                  
         WHERE Storerkey = @c_storerkey                                  
           AND Loadkey BETWEEN @c_LoadKeyFrom AND @c_LoadKeyTo                                  
           AND (Route = @c_route or @c_route = 0)                                  
      ) ,                                  
      PickData AS                  
      (                                  
         SELECT a.LoadKey ,                                  
                a.OrderKey AS orderkey, b.SKU AS sku, c.LogicalLocation AS LogicalLocation ,b.Loc AS loc , a.Route AS [Route], SUM(b.Qty) AS qty,                                  
                d.ExternLineNo AS ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) AS SKUDESCR,                                  
                C.Score                                  
         FROM Orders a WITH (NOLOCK)                                  
         JOIN PickDetail b WITH (NOLOCK) on a.OrderKey = b.OrderKey                           
         JOIN Loc c WITH (NOLOCK) on b.Loc = c.Loc                                  
         JOIN OrderDetail d WITH (NOLOCK) on b.OrderKey = d.OrderKey AND b.OrderLineNumber = d.OrderLineNumber                                  
         WHERE a.Storerkey = @c_storerkey AND a.LoadKey BETWEEN @c_LoadKeyFrom AND @c_LoadKeyTo                                  
         GROUP BY a.LoadKey ,  a.OrderKey, b.SKU, c.LogicalLocation,b.Loc, a.Route,                                  
                  d.ExternLineNo,RTRIM(ISNULL(d.UserDefine01,'')) , RTRIM(ISNULL(d.UserDefine02,'')),                                  
                  C.Score                                  
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
         OrderNo,     OrderKey,           LogicalLocation,            SKU,                                  
         Route,              Qty,               Loc,                        Loadkey,                                  
         ExternLineNo,       LineNumber,         TotalLines,                 SKUDESCR)                                  
      AS                                  
      (               
         SELECT  t1.OrderNo, t1.OrderKey, t2.LogicalLocation,                                  
                 SUBSTRING(t2.SKU,1,7) + '-'+SUBSTRING(t2.SKU,8,3) + '-' + SUBSTRING(t2.SKU,11,3) AS SKU,                                  
                 t2.Route,                                  
                 T4.TotalQty,                                  
                 t2.Loc, t1.LoadKey,                                  
                 t2.ExternLineNo,                                  
                 RANK() OVER (PARTITION BY T1.LoadKey ORDER BY t1.Loadkey, t2.Score,t2.LogicalLocation,t2.Loc,t1.OrderKey , t2.ExternLineNo)  ,                                  
                 T3.TotalLineCount,                                  
                 t2.SKUDESCR                                  
         FROM OrderList AS t1                                  
         JOIN PickData AS t2 ON t1.orderkey = t2.orderkey                                  
         JOIN LoadLineCount AS T3 ON T1.LoadKey =  T3.LoadKey                                  
         JOIN OrderQtyCount AS T4 ON T1.OrderKey = T4.orderkey                                  
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
      FROM LABELDETAIL-- ORDER BY LOADKEY , LINENUMBER      
      
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT OrderNo, Orderkey, LogicalLocation, SKU, [Route], Qty, Loc, Loadkey, ExternLineNo, LineNumber, TotalLines, SKUDESCR
      FROM #LOADSPLIT
      ORDER BY OrderNo   --WL01
      
      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @n_OrderSort                   
                                  , @c_Orderkey       
                                  , @c_LogicalLocation
                                  , @c_SKU            
                                  , @c_GetROUTE          
                                  , @n_Qty            
                                  , @c_Loc            
                                  , @c_Loadkey        
                                  , @c_ExternLineNo   
                                  , @n_LineNumber     
                                  , @n_TotalLines     
                                  , @c_SKUDESCR    
                                  
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	--WL01 START
      	IF @c_PrevOrderkey = NULL
      	BEGIN
      		SET @c_PrevOrderkey = @c_Orderkey
      	END
      	ELSE IF @c_PrevOrderkey = @c_Orderkey
      	BEGIN
      		GOTO NEXT_LOOP
      	END
      	--WL01 END
      	
         SET @c_Alphabet = CHAR(@n_ASCII)

         IF @n_OrderSort % @n_Count = 0
            SET @n_OrderSort = @n_Count
         ELSE IF (@n_OrderSort > @n_Count) 
            SET @n_OrderSort = @n_OrderSort - (@n_Count * (CAST(FLOOR(@n_OrderSort / @n_Count) AS INT)) )
         
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
         )   
         SELECT @c_Alphabet + RIGHT('00' + CAST(@n_OrderSort AS NVARCHAR),2)
              , @c_Orderkey  
              , @c_LogicalLocation
              , @c_SKU       
              , @c_GetROUTE     
              , @n_Qty       
              , @c_Loc       
              , @c_Loadkey   
              , @c_ExternLineNo
              , @n_LineNumber
              , @n_TotalLines
              , @c_SKUDESCR  
         
         SET @c_PrevOrderkey = @c_Orderkey   --WL01
         SET @n_CurrCount = @n_CurrCount + 1

         IF @n_OrderSort >= @n_Count
         BEGIN
            SET @n_ASCII = @n_ASCII + 1
         END
         
NEXT_LOOP:   --WL01
         FETCH NEXT FROM CUR_LOOP INTO @n_OrderSort                   
                                  , @c_Orderkey       
                                  , @c_LogicalLocation
                                  , @c_SKU            
                                  , @c_GetROUTE          
                                  , @n_Qty            
                                  , @c_Loc            
                                  , @c_Loadkey        
                                  , @c_ExternLineNo   
                                  , @n_LineNumber     
                                  , @n_TotalLines     
                                  , @c_SKUDESCR    
      END
                        
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
      -- CASE WHEN ORDERNO < 10               THEN 'A0'+ CAST(ORDERNO AS NVARCHAR)                          
      -- WHEN ORDERNO BETWEEN  '10' AND  '40' THEN 'A' + CAST(ORDERNO AS NVARCHAR)                          
      -- WHEN ORDERNO BETWEEN  '41' AND  '49' THEN 'B0'+ CAST(ORDERNO - 40  AS NVARCHAR)         
      -- WHEN ORDERNO BETWEEN  '50' AND  '80' THEN 'B' + CAST(ORDERNO - 40  AS NVARCHAR)         
      -- WHEN ORDERNO BETWEEN  '81' AND  '89' THEN 'C0'+ CAST(ORDERNO - 80  AS NVARCHAR)         
      -- WHEN ORDERNO BETWEEN  '90' AND '120' THEN 'C' + CAST(ORDERNO - 80  AS NVARCHAR)         
      -- WHEN ORDERNO BETWEEN '121' AND '129' THEN 'D0'+ CAST(ORDERNO - 120 AS NVARCHAR)         
      -- WHEN ORDERNO BETWEEN '130' AND '160' THEN 'D' + CAST(ORDERNO - 120 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '161' AND '169' THEN 'E0'+ CAST(ORDERNO - 160 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '170' AND '200' THEN 'E' + CAST(ORDERNO - 160 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '201' AND '209' THEN 'F0'+ CAST(ORDERNO - 200 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '210' AND '240' THEN 'F' + CAST(ORDERNO - 200 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '241' AND '249' THEN 'G0'+ CAST(ORDERNO - 240 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '250' AND '280' THEN 'G' + CAST(ORDERNO - 240 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '281' AND '289' THEN 'H0'+ CAST(ORDERNO - 280 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '290' AND '320' THEN 'H' + CAST(ORDERNO - 280 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '321' AND '329' THEN 'I0'+ CAST(ORDERNO - 320 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '330' AND '360' THEN 'I' + CAST(ORDERNO - 320 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '361' AND '369' THEN 'J0'+ CAST(ORDERNO - 360 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '370' AND '400' THEN 'J' + CAST(ORDERNO - 360 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '401' AND '409' THEN 'K0'+ CAST(ORDERNO - 400 AS NVARCHAR)        
      -- WHEN ORDERNO BETWEEN '410' AND '440' THEN 'K' + CAST(ORDERNO - 400 AS NVARCHAR)        
      -- END AS ORDERSORT                            
      --,ORDERKEY                                 
      --,LOGICALLOCATION                               
      --,SKU                                  
      --,ROUTE                                  
      --,QTY                                  
      --,LOC                                  
      --,LOADKEY                                 
      --,EXTERNLINENO                                
      --,LINENUMBER                                 
      --,TOTALLINES                                 
      --,SKUDESCR FROM #LOADSPLIT WITH (NOLOCK)                                               
            
      SELECT *, @c_Mode AS Mode FROM #LOADSPLIT2 (NOLOCK)  ORDER BY LOADKEY, LINENUMBER          

      IF OBJECT_ID('tempdb..#LOADSPLIT') IS NOT NULL
         DROP TABLE #LOADSPLIT
      
      IF OBJECT_ID('tempdb..#LOADSPLIT2') IS NOT NULL
         DROP TABLE #LOADSPLIT2

      GOTO QUIT_SP
   END

QUIT_SP:           
END 

GO