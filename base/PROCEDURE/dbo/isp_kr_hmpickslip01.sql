SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/      
/* Store Procedure: isp_kr_hmpickslip01                                       */      
/* Creation Date: 08-NOV-2018                                                 */      
/* Copyright: IDS                                                             */      
/* Written by: WLCHOOI                                                        */      
/*                                                                            */      
/* Purpose: For KR LIT datawindow                                             */      
/*        : reports_kr.pbl                                                    */      
/*        : SP copy & modifies from isp_kr_hmpickslip01                       */      
/*                                                                            */      
/* Called By:  r_kr_hmpickslip01                                              */      
/*                                                                            */      
/* PVCS Version: 1.2                                                          */      
/*                                                                            */      
/* Version: 1.0                                                               */      
/*                                                                            */      
/* Data Modifications:                                                        */      
/*                                                                            */      
/* Updates:                                                                   */      
/* Date         Author    Ver. Purposes                                       */  
/* 22-05-2019   WLCHOOI   1.0  WMS-9065 - Add storerkey, loadkeyfrom and      */ 
/*                                       loadkeyto as input parameters(WL01)  */   
/* 10-06-2019   WLCHOOI   1.1  WMS-9314 - Add Total allocated qty column(WL02)*/
/* 29-Mar-2023  WLCHOOI   1.2  Performance Tune & Merge KRLocal ver. (WL03)   */ 
/******************************************************************************/      
     
CREATE   PROC [dbo].[isp_kr_hmpickslip01]    
     @c_storerkey     NVARCHAR(15) --WL01
   , @c_route         NVARCHAR(10)       
   , @c_loadkeyFrom   NVARCHAR(10)     
   , @c_loadkeyTo     NVARCHAR(10) = ''    
AS      
      
BEGIN      
   SET NOCOUNT ON      
   SET ANSI_WARNINGS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF      
      
   DECLARE  @n_TotalLines  INT  
         ,  @n_Continue    INT = 1
       
   DECLARE  @c_Orderkey    NVARCHAR(10)      
         ,  @n_TTLQty      INT      
      
   DECLARE  @c_notes       NVARCHAR(4000)      
              
   DECLARE  @n_RowNum      INT      
         ,  @n_LineNumber  INT      
         ,  @n_Qty         INT      
         ,  @CUR_SPLITQTY  CURSOR   
         ,  @c_Loadkey     NVARCHAR(10)
      
   --WL01 Start  
   IF ISNULL(@c_loadkeyTo,'')   = ''
      SET @c_loadkeyTo   = @c_loadkeyFrom
      
   --SET @c_storerkey = ''      
   --SELECT TOP 1 @c_storerkey = Storerkey      
   --FROM ORDERS (NOLOCK)      
   --WHERE LOADKEY = @c_loadkeyFrom      
   
   CREATE TABLE #HM_Loadkey
   ( Loadkey NVARCHAR(10)
   )

   INSERT INTO #HM_Loadkey
   SELECT DISTINCT Loadkey
   FROM ORDERS (NOLOCK)
   WHERE STORERKEY = @c_storerkey AND Route = @c_route
   AND Loadkey BETWEEN @c_loadkeyFrom AND @c_loadkeyTo
   --WL01 End
    
   CREATE TABLE #HM_Label1      
   (  OrderNo             INT      
   ,  OrderKey            NVARCHAR(10)      
   ,  LogicalLocation     NVARCHAR(20)      
   ,  SKU                 NVARCHAR(20)      
   ,  Route               NVARCHAR(20)      
   ,  Qty                 INT      
   ,  Loc                 NVARCHAR(10)      
   ,  Loadkey             NVARCHAR(10)      
   ,  ExternLineNo        NVARCHAR(20)      
   ,  LineNumber          INT      
   ,  TotalLines          INT      
   ,  SKUDESCR            NVARCHAR(90)      
   ,  PutawayZone         NVARCHAR(20)    
   ,  TotalAllocQty       INT  --WL02
   ,  Notes2              NVARCHAR(250)   --WL03
   )

   CREATE TABLE #Temp1      
   (  OrderNo             INT 
   ,  OrderKey            NVARCHAR(10)           
   ,  Loadkey             NVARCHAR(10)      
   ,  Route               NVARCHAR(20)
   )

   CREATE TABLE #Temp2      
   (  RowNum             INT      
   ,  OrderKey            NVARCHAR(10)      
   ,  SKU                 NVARCHAR(20)  
   ,  LogicalLocation     NVARCHAR(20)    
   ,  Loc                 NVARCHAR(10)   
   ,  Route               NVARCHAR(20)      
   ,  Qty                 INT      
   ,  ExternLineNo        NVARCHAR(20) 
   ,  SKUDESCR            NVARCHAR(90)  
   ,  Notes               NVARCHAR(50)
   ,  PutawayZone         NVARCHAR(20)   
   ,  TotalAllocQty       INT --WL02
   ,  Notes2              NVARCHAR(250)   --WL03
   )  
   
   --WL03 S
   CREATE NONCLUSTERED INDEX IDX_HM_Label1 ON #HM_Label1 (OrderKey)
   CREATE NONCLUSTERED INDEX IDX_Temp1 ON #Temp1 (OrderKey)
   CREATE NONCLUSTERED INDEX IDX_Temp2 ON #Temp2 (OrderKey)
   --WL03 E
   
   --WL01 Start     
   DECLARE cur_Loadkey CURSOR FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Loadkey
   FROM #HM_Loadkey
   
   OPEN cur_Loadkey
   
   FETCH NEXT FROM cur_Loadkey INTO @c_Loadkey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      --Temp1
      IF @n_Continue = 1 OR @n_Continue =2 
      BEGIN
         INSERT INTO #TEMP1
         SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) AS OrderNo      
               ,Orderkey AS orderkey      
               ,LoadKey as loadkey    
               ,route       
         FROM  ORDERS WITH (NOLOCK)      
         WHERE Storerkey = @c_storerkey    
         AND   Loadkey   = @c_loadkey     
         AND (Route = @c_route or @c_route = '0')      
      END
      
      --Temp2
      IF @n_Continue = 1 OR @n_Continue =2 
      BEGIN
         INSERT INTO #TEMP2
         SELECT ROW_NUMBER() OVER (ORDER BY a.Orderkey, b.Sku)  AS RowNum      
               ,a.OrderKey as orderkey      
               ,b.SKU as sku      
               ,c.LogicalLocation as LogicalLocation       
               ,b.Loc as loc       
               ,a.Route as [Route]      
               ,SUM(b.Qty) as qty      
               ,d.ExternLineNo as ExternLineNo      
               ,RTRIM(ISNULL(d.UserDefine01,'')) + RTRIM(ISNULL(d.UserDefine02,'')) as SKUDESCR       
               ,RTRIM(ISNULL(b.Notes,'')) as Notes      
               ,c.PutawayZone as PutawayZone     
               --,(SELECT SUM(Qty) FROM PICKDETAIL PD (NOLOCK) JOIN ORDERS ORD (NOLOCK) ON ORD.OrderKey = PD.OrderKey WHERE ORD.LOADKEY = @c_loadkey) AS TotalQty
               ,(SELECT SUM(QtyAllocated) FROM ORDERDETAIL OD (NOLOCK) JOIN ORDERS ORD (NOLOCK) ON ORD.OrderKey = OD.OrderKey WHERE ORD.LOADKEY = @c_loadkey) AS TotalAllocQty--WL02
               ,e.Notes2   --WL03
         FROM ORDERS      a WITH (NOLOCK)      
         JOIN PICKDETAIL  b WITH (NOLOCK) on a.OrderKey = b.OrderKey      
         JOIN LOC         c WITH (NOLOCK) on b.Loc = c.Loc      
         JOIN ORDERDETAIL d WITH (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber     
         JOIN KRWMS..SKU         e WITH (NOLOCK) on e.Sku = b.Sku AND e.StorerKey = b.Storerkey   --WL03
         WHERE a.Storerkey = @c_storerkey       
         AND a.LoadKey = @c_loadkey      
         GROUP BY a.OrderKey      
               ,  b.SKU      
               ,  c.LogicalLocation      
               ,  b.Loc      
               ,  a.Route      
               ,  d.ExternLineNo      
               ,  RTRIM(ISNULL(d.UserDefine01,''))       
               ,  RTRIM(ISNULL(d.UserDefine02,''))      
               ,  RTRIM(ISNULL(b.Notes,''))      
               ,  c.PutawayZone    
               ,  e.Notes2   --WL03
         ORDER BY a.Orderkey, b.Sku      
      END

      IF @n_Continue = 1 OR @n_Continue =2 
      BEGIN 
         SET @n_LineNumber = 0      
         SET @CUR_SPLITQTY = CURSOR FAST_FORWARD READ_ONLY FOR       
         SELECT t2.RowNum       
               ,t2.Qty       
         FROM #TEMP1 AS t1       
         JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey      
         ORDER BY --t2.Putawayzone   --WL03  
                  t2.LogicalLocation      
               ,  t2.Loc      
               ,  t2.SKU      
               ,  t1.OrderKey      
            
         OPEN @CUR_SPLITQTY      
         
         FETCH NEXT FROM @CUR_SPLITQTY INTO @n_RowNum, @n_Qty      
         
         WHILE @@FETCH_STATUS = 0      
         BEGIN      
            WHILE @n_Qty > 0      
            BEGIN      
               SET @n_LineNumber = @n_LineNumber + 1      
               INSERT INTO #HM_Label1        
                  (        
                     OrderNo      
                  ,  OrderKey      
                  ,  LogicalLocation                   
                  ,  SKU       
                  ,  Route                    
                  ,  Qty                      
                  ,  Loc                              
                  ,  Loadkey      
                  ,  ExternLineNo             
                  ,  LineNumber               
                  ,  TotalLines                       
                  ,  SKUDESCR      
                  ,  PutawayZone
                  ,  TotalAllocQty    --WL02
                  ,  Notes2   --WL03
                  )       
           
               SELECT       
                     t1.OrderNo               
                  ,  t1.OrderKey              
                  ,  t2.LogicalLocation               
                  ,  t2.SKU      
                  ,  t2.Route                 
                  ,  t2.Qty                   
                  ,  t2.Loc                           
                  ,  t1.LoadKey      
                  ,  t2.ExternLineNo          
                  ,  @n_LineNumber       
                  ,  0         
                  ,  t2.SKUDESCR        
                  ,  t2.PutawayZone   
                  ,  t2.TotalAllocQty --WL02
                  ,  t2.Notes2   --WL03
               FROM #TEMP1 AS t1       
               JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey      
               WHERE RowNum = @n_RowNum      
         
               SET @n_Qty = @n_Qty - 1      
            END      
                     
            FETCH NEXT FROM @CUR_SPLITQTY INTO @n_RowNum, @n_Qty      
         END       
         CLOSE @CUR_SPLITQTY      
         DEALLOCATE @CUR_SPLITQTY 
      END     
      
      IF @n_Continue = 1 OR @n_Continue =2 
      BEGIN
         SET @n_TotalLines = 0      
         SELECT @n_TotalLines = count(1)      
         FROM #HM_Label1(nolock)      
         
         UPDATE #HM_Label1      
         set TotalLines = @n_TotalLines      
         
         DECLARE CUR_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
         SELECT DISTINCT Orderkey      
         FROM #HM_Label1   
         ORDER BY Orderkey      
         
         OPEN CUR_Orderkey      
         FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey      
         
         WHILE @@FETCH_STATUS <> -1      
         BEGIN      
         
            SET @n_TTLQty = 0      
         
            SELECT @n_TTLQty = COUNT(1)      
            FROM #HM_Label1      
            WHERE OrderKey = @c_Orderkey        
          
            UPDATE #HM_Label1      
            SET   Qty = @n_TTLQty      
            WHERE Orderkey=@c_Orderkey       
         
            FETCH NEXT FROM CUR_Orderkey INTO @c_Orderkey      
         END      
         
         CLOSE CUR_Orderkey      
         DEALLOCATE CUR_Orderkey
      END    
      
      TRUNCATE TABLE #TEMP1
      TRUNCATE TABLE #TEMP2

      FETCH NEXT FROM cur_Loadkey INTO @c_Loadkey 
   END 
   CLOSE cur_Loadkey      
   DEALLOCATE cur_Loadkey 
    --WL01 End

   SELECT      
         CAST((OrderNo - 1) / 20 + 1 AS NVARCHAR) + '-' + CAST((OrderNo - 1) % 20 + 1 AS NVARCHAR) AS OrderNo   --WL03      
      ,  OrderKey      
      ,  LogicalLocation      
      ,  SUBSTRING(SKU,1,7) + ' '+SUBSTRING(SKU,8,3) + ' ' + SUBSTRING(SKU,12,2) as SKU       
      ,  Route      
      ,  Qty                       
      ,  Loc                              
      ,  Loadkey      
      ,  ExternLineNo      
      ,  LineNumber      
      ,  TotalLines      
      ,  SKUDESCR       
      ,  PutawayZone
      ,  TotalAllocQty  --WL02
      ,  Notes2   --WL03
   FROM #HM_Label1(nolock)      
   --ORDER BY LineNumber    
   ORDER BY Loadkey, LogicalLocation, Loc, SKU, OrderKey ASC
       
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_SPLITQTY') in (0 , 1)        
   BEGIN      
      CLOSE @CUR_SPLITQTY      
      DEALLOCATE @CUR_SPLITQTY      
   END      
      
END   

GO