SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/          
/* Store Procedure: isp_kr_hmpickslip02                                       */          
/* Creation Date: 30-SEP-2021                                                 */          
/* Copyright: IDS                                                             */          
/* Written by: Jeffrey Shin                                                   */          
/*                                                                            */          
/* Purpose: For KR LIT datawindow                                             */          
/*        : reports_kr.pbl                                                    */          
/*        : SP copy & modifies from isp_kr_hmpickslip02                       */          
/*                                                                            */          
/* Called By:  r_kr_hmpickslip02                                              */          
/*                                                                            */          
/* PVCS Version: 1.0                                                          */          
/*                                                                            */          
/* Version: 1.3                                                               */          
/*                                                                            */          
/* Data Modifications:                                                        */          
/*                                                                            */          
/* Updates:                                                                   */          
/* Date         Author    Ver.  Purposes                                      */         
/* 30-Sep-2021  Jeffrey   1.0   Copied from isp_kr_hmpickslip01 and add color */
/* 25-Nov-2022  Young     1.1   Add Notes2 from SKU                           */
/* 29-Mar-2023	WLCHOOI	  1.2	Performance Tune & Merge KRLocal ver. (WL03)  */
/* 29-Mar-2023  Min       1.3   Changed to BI Schema to use in Logireport     */
/*                              Updated SP name to kr_hmpickslip2023          */
/******************************************************************************/          
         
CREATE   PROC [BI].[isp_kr_hmpickslip2023]     
     @c_storerkey     NVARCHAR(15) --WL01    
   , @c_route         NVARCHAR(10)           
   , @c_loadkeyFrom   NVARCHAR(10)         
   , @c_loadkeyTo     NVARCHAR(10)        
AS          
          
BEGIN          
   SET NOCOUNT ON          
   SET ANSI_WARNINGS OFF       
   SET ANSI_NULLS OFF     
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

	DECLARE @alphabet varchar(26) = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'	
          
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
   FROM BI.V_ORDERS (NOLOCK)    
   WHERE STORERKEY = @c_storerkey AND Route = @c_route    
   AND Loadkey BETWEEN @c_loadkeyFrom AND @c_loadkeyTo    
  
   AND isnull(trackingno, '') <> ''  
   --AND status in ('1', '2')  
        
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
   ,  TotalAllocQty       INT
   ,  Notes2			  NVARCHAR(20)
  
   ,  Color               NVARCHAR(20) --Jeffrey Shin 210930  
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
   ,  TotalAllocQty       INT
   ,  Notes2			  NVARCHAR(20)
   ,  Color               NVARCHAR(20) --Jeffrey Shin 210930  
   )         

   --WL03 S
   CREATE NONCLUSTERED INDEX IDX_HM_Label1 ON #HM_Label1 (OrderKey)
   CREATE NONCLUSTERED INDEX IDX_Temp1 ON #Temp1 (OrderKey)
   CREATE NONCLUSTERED INDEX IDX_Temp2 ON #Temp2 (OrderKey)
   --WL03 E
       
   --WL01 Start         
   DECLARE cur_Loadkey2 CURSOR FAST_FORWARD READ_ONLY FOR --Jeffrey Shin 210930 (cur_Loadkey -> cur_Loadkey2)  
   SELECT DISTINCT Loadkey    
   FROM #HM_Loadkey    
       
   OPEN cur_Loadkey2    
       
   FETCH NEXT FROM cur_Loadkey2 INTO @c_Loadkey    
       
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      --Temp1  20210504 YC: Creating Table for PTL  
      IF @n_Continue = 1 OR @n_Continue =2     
      BEGIN    
         INSERT INTO #TEMP1    
         SELECT ROW_NUMBER() OVER (ORDER BY OrderKey) AS OrderNo     -- PTL Room Number     
               ,Orderkey AS orderkey          
               ,LoadKey as loadkey        
               ,route           
         FROM  BI.V_ORDERS WITH (NOLOCK)          
         WHERE Storerkey = @c_storerkey        
         AND   Loadkey   = @c_loadkey         
         AND (Route = @c_route or @c_route = '0')  
  
   AND isnull(trackingno, '') <> ''  
   --AND status in ('1', '2')  
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
               ,(SELECT SUM(QtyAllocated) FROM BI.V_ORDERDETAIL OD (NOLOCK) JOIN BI.V_ORDERS ORD (NOLOCK) ON ORD.OrderKey = OD.OrderKey WHERE ORD.LOADKEY = @c_loadkey) AS TotalAllocQty
			   ,e.Notes2
				,e.BUSR6 as Color --Jeffrey Shin 210930  
         FROM BI.V_ORDERS      a WITH (NOLOCK)          
         JOIN BI.V_PICKDETAIL  b WITH (NOLOCK) on a.OrderKey = b.OrderKey          
         JOIN BI.V_LOC         c WITH (NOLOCK) on b.Loc = c.Loc          
         JOIN BI.V_ORDERDETAIL d WITH (NOLOCK) on b.OrderKey = d.OrderKey and b.OrderLineNumber = d.OrderLineNumber          
  
   JOIN BI.V_SKU   e WITH (NOLOCK) on e.Sku = b.Sku --Jeffrey Shin 210930  
         WHERE a.Storerkey = @c_storerkey           
         AND a.LoadKey = @c_loadkey  
  
   AND isnull(a.trackingno, '') <> ''  
   --AND a.status in ('1', '2')  
  
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
			   ,  e.Notes2
        
      ,e.BUSR6 --Jeffrey Shin 210930  
         ORDER BY a.Orderkey, b.Sku          
      END    
    
      IF @n_Continue = 1 OR @n_Continue =2     
      BEGIN     
         SET @n_LineNumber = 0    -- YC: Generating line Number      
         SET @CUR_SPLITQTY = CURSOR FAST_FORWARD READ_ONLY FOR           
         SELECT t2.RowNum           
               ,t2.Qty           
         FROM #TEMP1 AS t1           
         JOIN #TEMP2 AS t2 ON t1.orderkey = t2.orderkey          
         ORDER BY --t2.Putawayzone   
   /*20210521 YC: Removing Putawayzone to Make LineNumber in a Proper Row   
   <<ORIGINAL>> : ORDER BY t2.PutawayZone, t2.LogicalLocation, t1.Loc, t2.SKU, t1.OrderKey ASC*/  
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
                  ,  TotalAllocQty
				  ,  Notes2
  
                  ,  Color --Jeffrey Shin 210930  
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
                  ,  t2.TotalAllocQty
				  ,  t2.Notes2
  
      ,  t2.Color --Jeffrey Shin 210930  
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
    
      FETCH NEXT FROM cur_Loadkey2 INTO @c_Loadkey     
   END     
   CLOSE cur_Loadkey2          
   DEALLOCATE cur_Loadkey2     
    --WL01 End    
    
   SELECT          
         --일단 롤백했고 적용 시 위 주석 풀면 됨  
  
   --20220126 Jeffrey Multi 40 Change -ver2  
   --cast((OrderNo - 1) / 40 + 1 + cast((dense_rank() over(order by loadkey) - 1) * 2 as int)  
   --as varchar) + '-' + CAST((OrderNo - 1) % 40 + 1 as varchar) as OrderNo2  
  
   --20220520 Jeffrey Multi 40 Change -ver3  
   --cast((OrderNo - 1) / 20 + 1 as varchar) + '-' + cast((OrderNo - 1) % 20 + 1 as varchar) as OrderNo  

   --220610
   CAST(SUBSTRING(@alphabet, (OrderNo - 1) / 20 + 1, 1) AS VARCHAR) + '-' + CAST((OrderNo - 1) % 20 + 1 AS VARCHAR) AS OrderNo
  
   --~일단 롤백했고 적용 시 위 주석 풀면 됨  
  
   --,OrderNo--위에 것 풀 경우 이건 주석하세요  
     
      ,  OrderKey  
      ,  LogicalLocation  
      ,  SUBSTRING(SKU,1,7) + ' '+SUBSTRING(SKU,8,3) + ' ' + SUBSTRING(SKU,12,2) AS SKU  
      ,  Route          
      ,  Qty                           
      ,  Loc                                  
      ,  Loadkey          
      ,  ExternLineNo          
      ,  LineNumber          
      ,  TotalLines          
      ,  SKUDESCR           
      ,  PutawayZone    
      ,  TotalAllocQty
	  ,  Notes2
      ,  ('*'+OrderKey+'*') AS Barcode --MS 230404 1.4
  
   --,  Color --Jeffrey Shin 210930  
  
   ,CASE Color  
   WHEN 'Red' THEN   N'빨강'  
   WHEN 'Beige' THEN   N'살색'  
   WHEN 'Bronze' THEN  N'갈색'  
   WHEN 'Gold' THEN   N'금색'  
   WHEN 'Khaki' THEN   N'카키'  
   WHEN 'White' THEN   N'흰색'  
   WHEN 'Green' THEN   N'초록'  
   WHEN 'Pink' THEN   N'핑크'  
   WHEN 'Transparent' THEN N'투명'  
   WHEN 'Turquoise' THEN  N'청록'  
   WHEN 'Grey' THEN   N'회색'  
   WHEN 'Brown' THEN   N'갈색'  
   WHEN 'Black' THEN   N'검정'  
   WHEN 'Purple' THEN  N'보라'  
   WHEN 'Silver' THEN  N'은색'  
   WHEN 'Blue' THEN   N'파랑'  
   WHEN 'Yellow' THEN  N'노랑'  
   WHEN 'Light Brown' THEN N'갈색'  
   WHEN 'Orange' THEN  N'주황'  
  
   ELSE ISNULL(Color, '') END AS Color  
  
FROM #HM_Label1(NOLOCK)          
   --ORDER BY LineNumber        
   ORDER BY Loadkey, LogicalLocation, Loc, SKU, OrderKey ASC   
   /*20210503 MS : replace orderkey with linenumber for order by ; remove logicallocation for order by  
    <<ORIGINAL>> : ORDER BY Loadkey, LogicalLocation, Loc, SKU, OrderKey ASC  */  
  
   IF CURSOR_STATUS( 'VARIABLE', '@CUR_SPLITQTY') IN (0 , 1)            
   BEGIN          
      CLOSE @CUR_SPLITQTY          
      DEALLOCATE @CUR_SPLITQTY          
   END          
          
END       

GO