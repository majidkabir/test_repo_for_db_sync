SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store Procedure: isp_kr_hmpickslip                                         */
/* Creation Date: 04-JAN-2018                                                 */
/* Copyright: IDS                                                             */
/* Written by: WAN                                                            */
/*                                                                            */
/* Purpose: For KR LIT datawindow                                             */
/*        : reports_kr.pbl                                                    */
/*        : SP copy & modifies from isp_cn_hmpickslip                         */
/*                                                                            */
/* Called By:  r_kr_hmpickslip                                                */
/*                                                                            */
/* PVCS Version: 1.0                                                          */
/*                                                                            */
/* Version: 1.0                                                               */
/*                                                                            */
/* Data Modifications:                                                        */
/*                                                                            */
/* Updates:                                                                   */
/* Date         Author    Ver.  Purposes                                      */
/******************************************************************************/
CREATE PROC [dbo].[isp_kr_hmpickslip]
     @c_route     NVARCHAR(10) 
   , @c_loadkey   NVARCHAR(10)
AS

BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @c_storerkey   NVARCHAR(10)
         ,  @n_TotalLines  INT
   DECLARE  @c_Orderkey    NVARCHAR(10)
         ,  @n_TTLQty      INT

   DECLARE  @c_notes       NVARCHAR(4000)
        
   DECLARE  @n_RowNum      INT
         ,  @n_LineNumber  INT
         ,  @n_Qty         INT
         ,  @CUR_SPLITQTY  CURSOR

   SET @c_storerkey = ''
   SELECT TOP 1 @c_storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE LOADKEY =  @c_loadkey

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
   )

   SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) AS OrderNo
         ,Orderkey AS orderkey
         ,LoadKey as loadkey
   INTO #Temp1
   FROM  ORDERS WITH (NOLOCK)
   WHERE Storerkey = @c_storerkey
   AND   Loadkey   = @c_loadkey 
   AND (Route = @c_route or @c_route = '0')

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
   INTO #TEMP2
   FROM ORDERS      a WITH (NOLOCK)
   JOIN PICKDETAIL  b WITH (NOLOCK) on a.OrderKey = b.OrderKey
   JOIN LOC         c WITH (NOLOCK) on b.Loc = c.Loc
   JOIN ORDERDETAIL d WITH (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber
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
   ORDER BY a.Orderkey, b.Sku

   SET @n_LineNumber = 0
   SET @CUR_SPLITQTY = CURSOR FAST_FORWARD READ_ONLY FOR 
   SELECT t2.RowNum 
         ,t2.Qty 
   FROM #TEMP1 AS t1 
   JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey
   ORDER BY t2.LogicalLocation
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

         FROM #TEMP1 AS t1 
         JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey
         WHERE RowNum = @n_RowNum

         SET @n_Qty = @n_Qty - 1
      END
            
      FETCH NEXT FROM @CUR_SPLITQTY INTO @n_RowNum, @n_Qty
   END 
   CLOSE @CUR_SPLITQTY
   DEALLOCATE @CUR_SPLITQTY

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
   DEALLOCATE  CUR_Orderkey



   SELECT
         OrderNo
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
   FROM #HM_Label1(nolock)
   ORDER BY LineNumber


   IF CURSOR_STATUS( 'VARIABLE', '@CUR_SPLITQTY') in (0 , 1)  
   BEGIN
      CLOSE @CUR_SPLITQTY
      DEALLOCATE @CUR_SPLITQTY
   END

END

GO