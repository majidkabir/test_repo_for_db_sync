SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/      
/* Stored Procedure: isp_GetPickSlipOrders86_2                          */      
/* Creation Date: 28-Jan-2019                                           */      
/* Copyright: IDS                                                       */      
/* Written by: WLCHOOI                                                  */      
/*                                                                      */      
/* Remarks:                                                             */      
/*                                                                      */      
/* Purpose: WMS-7141 [TW-PND] HornJin RCMREPORT Pickslip New            */      
/*                                                                      */      
/*                                                                      */      
/* Called By: r_dw_print_pickorder86                                    */      
/*                                                                      */      
/* PVCS Version:                                                        */      
/*                                                                      */      
/* Version: 5.4                                                         */      
/*                                                                      */      
/* Data Modifications:                                                  */      
/*                                                                      */      
/* Updates:                                                             */      
/* Date         Author   Ver  Purposes                                  */      
/*19-02-2019   WLCHOOI  1.0  WMS-7141 - Restructure & Fixed amount      */    
/*                                        of bugs                       */    
/*20-02-2019   SPChin   1.1  INC0589288 - Bug Fixed                     */    
/*26-02-2019   WLCHOOI  1.2  WMS-8070 - Add Pack.Casecnt to report and  */      
/*                                        sorting sequence (WL01)       */  
/*18-04-2019   WLCHOOI  1.3  WMS-8688 - Add sorting condtion - Logical  */
/*                                      Location (WL02)                 */      
/************************************************************************/      
      
CREATE PROC [dbo].[isp_GetPickSlipOrders86_2] (@c_loadkey NVARCHAR(10))      
 AS      
BEGIN      
    SET CONCAT_NULL_YIELDS_NULL OFF      
    SET QUOTED_IDENTIFIER OFF      
    SET ANSI_NULLS OFF      
    SET NOCOUNT ON      
      
    DECLARE @c_pickheaderkey NVARCHAR(10),      
    @n_continue              int,      
    @n_starttcnt             int,      
    @c_errmsg                NVARCHAR(255),      
    @b_success               int,      
    @n_err                   int,      
    @c_LogicalLoc            NVARCHAR(18),  --WL02    
    @c_LocType               NVARCHAR(10),      
    @c_ID                    NVARCHAR(18),      
    @c_PrintedFlag           NVARCHAR(1),      
    @c_PrevPickslipNo        NVARCHAR(10),      
    @c_PickUOM               NVARCHAR(5),      
    @c_PickZone              NVARCHAR(10),      
    --@c_Prev_C_Company        NVARCHAR(45), --NJOW03      
    @c_PickType              NVARCHAR(30),      
    @c_PickDetailkey         NVARCHAR(10),      
    @c_OrderLineNumber       NVARCHAR(5),      
    @d_Lottable04            datetime,      
    @n_PageNo                int,      
    @c_TotalPage             int,      
    @b_debug                 int  ,      
    @c_WaveKey               NVARCHAR(10),    -- (tlting01)      
    @c_Lottable02label       NVARCHAR(30),      
    @c_Lottable04Label       NVARCHAR(30),      
    @c_Storerkey             NVARCHAR(15),      
    @c_Consigneekey          NVARCHAR(15), --NJOW04      
    @c_OrderGrp              NVARCHAR(20),  --CS01      
    @n_CntOrderGrp           INT,           --CS01       
    @c_OrdGrpFlag            NVARCHAR(1),   --CS01      
    @c_RLoadkey              NVARCHAR(20),  --CS01      
    @c_LEXTLoadKey           NVARCHAR(20),   --(CS01)      
    @c_LPriority             NVARCHAR(10),   --(CS01)      
    @c_LPuserdefDate01       datetime        --(CS01)      
    ,@n_showField            INT             --(CS03)    
      
    ,@C_CODE                NVARCHAR(20)      
    ,@c_result              NVARCHAR(100)      
    ,@c_sort                NVARCHAR(100)       
    ,@c_sql                 NVARCHAR(MAX)       
    ,@c_ExecArguments       NVARCHAR(MAX)       
      
      
    ,@c_Pickslipno          NVARCHAR(10)      
    ,@c_OrderGroup          NVARCHAR(40)          
    ,@c_Orderkey            NVARCHAR(10)              
    ,@c_C_Company           NVARCHAR(90)           
    ,@c_ExternOrderkey      NVARCHAR(50)               
    ,@c_Notes               NVARCHAR(255)          
    ,@c_Facility            NVARCHAR(10)         
    ,@c_TrfRoom             NVARCHAR(20)         
    ,@d_DeliveryDate        DATETIME      
    ,@c_Loc                 NVARCHAR(20)                 
    ,@c_SKU                 NVARCHAR(20)               
    ,@c_SkuDescr            NVARCHAR(60)        
    ,@c_Style               NVARCHAR(60)         
    ,@c_Lott1               NVARCHAR(36)         
    ,@c_Lott2               NVARCHAR(36)          
    ,@d_Lott4               DATETIME      
    ,@n_QTY                 INT      
    ,@n_Case                INT      
    ,@n_Casecnt             INT      
    ,@n_InnerPack           INT      
    ,@n_Innercnt            INT      
    ,@n_EA                  INT      
    ,@c_Short               NVARCHAR(1)    
    ,@c_ConsoShort          NVARCHAR(1)      
    ,@c_Dock                NVARCHAR(2)      
    ,@c_UserDefine02        NVARCHAR(40)      
    ,@c_Itemclass           NVARCHAR(50)    
    ,@c_Scode               NVARCHAR(20)    
    ,@c_Slong               NVARCHAR(20)    
    ,@c_Sshort              NVARCHAR(20)    
    ,@c_runningno           INT = 1    
    ,@c_NoSort              INT = 0    
    ,@C_SQLEXEC             NVARCHAR(MAX) = ''    
      
 CREATE TABLE #Singleship  (      
    Pickslipno         NVARCHAR(10)      
     , OrderGroup      NVARCHAR(40)      
     , Loadkey         NVARCHAR(10)               
     , Orderkey        NVARCHAR(10)              
     , C_Company       NVARCHAR(90)           
     , ExternOrderkey  NVARCHAR(50)               
     , Notes           NVARCHAR(255)          
     , Facility        NVARCHAR(10)         
     , TrfRoom         NVARCHAR(20)         
     , DeliveryDate    DATETIME      
     , Loc             NVARCHAR(20)                 
     , SKU             NVARCHAR(20)               
     , Descr           NVARCHAR(120)        
     , Style           NVARCHAR(60)         
     , Lott1           NVARCHAR(36)         
     , Lott2           NVARCHAR(36)          
     , Lott4           DATETIME      
     , QTY             INT      
     , Casecnt         FLOAT      
     , Innercnt        FLOAT      
     , EA              INT      
     , Short           NVARCHAR(1)      
     , Dock            NVARCHAR(2)      
     , UserDefine02    NVARCHAR(40)    
     , ItemClass       NVARCHAR(50)    
     , PCasecnt        FLOAT
     , LogicalLocation NVARCHAR(18) )   --WL02     
    
  CREATE TABLE #SORTING(    
  CODE      NVARCHAR(20)    
 ,LONG      INT    
 ,SHORT     INT )    
      
 SELECT @n_continue = 1, @n_starttcnt=@@TRANCOUNT      
 SELECT @b_Debug = 0      
       
-- BEGIN TRAN      
-- Uses PickType as a Printed Flag      
      
--Will update PickType during isp_GetPickSlipOrders86_1      
      
--UPDATE PickHeader      
--SET   PickType = '1',      
--   TrafficCop = NULL      
--WHERE LoadKey = @c_loadkey      
----AND Orderkey = ''      
--AND   Zone = 'LB'      
--AND   PickType = '0'      
--IF @@ERROR <> 0      
--BEGIN      
--  SELECT @n_continue = 3      
--  SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73000      
--  SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Pickheader Table. (isp_GetPickSlipOrders86_2)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
--END   
 IF NOT EXISTS(SELECT 1 FROM ORDERS (NOLOCK) WHERE LOADKEY = @c_Loadkey)
       GOTO EXIT_SP   
     
 SELECT @c_Storerkey = STORERKEY FROM ORDERS (NOLOCK)       
 WHERE ORDERS.LOADKEY = @C_LOADKEY      
      
 --Find sorting sequence based on Sku.Itemclass = Codelkup.Code    
 IF (@n_continue = 1 OR @n_continue = 2)
 BEGIN     
 INSERT INTO #SORTING(CODE,LONG,SHORT)    
    SELECT DISTINCT CAST(RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(CLK2.CODE,CHAR(9),' '),CHAR(10),' '),CHAR(13),' '))) AS NVARCHAR(20)),    
 CAST(RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(CLK2.LONG,CHAR(9),' '),CHAR(10),' '),CHAR(13),' '))) AS INT),    
 CAST(RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(CLK2.SHORT,CHAR(9),' '),CHAR(10),' '),CHAR(13),' '))) AS INT)    
    FROM ORDERS (NOLOCK)    
 JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.orderkey = ORDERS.Orderkey     
 JOIN SKU  WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)          
                                 AND(ORDERDETAIL.Sku       = SKU.Sku)    
    JOIN CODELKUP CLK2 (NOLOCK) ON CLK2.LISTNAME = 'PNDPICK' AND CLK2.STORERKEY = ORDERS.STORERKEY    
  AND CLK2.CODE = SKU.ITEMCLASS    
 WHERE Orders.Loadkey = @C_LOADKEY    
 ORDER BY CAST(RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(CLK2.SHORT,CHAR(9),' '),CHAR(10),' '),CHAR(13),' '))) AS INT)    
    
 --If no result in codelkup, do not sort    
 IF(@@ROWCOUNT = 0)    
 SET @c_NoSort = 1    
 END    
    
 --Construct sorting statement    
 IF (@n_continue = 1 OR @n_continue = 2)      
 BEGIN       
 DECLARE cur_sort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
 SELECT CODE,LONG,SHORT    
 FROM #SORTING    
 ORDER BY SHORT    
    
 OPEN cur_sort    
    
 FETCH NEXT FROM cur_sort INTO @c_Scode,@c_Slong,@c_Sshort    
 WHILE(@@FETCH_STATUS<>-1)    
 BEGIN    
    
    SET @C_SQL = @C_SQL + ' WHEN '''+ @c_Scode +''' THEN '+ CAST (@c_runningno AS NVARCHAR)    
    SET @c_runningno = @c_runningno + 1    
    
 FETCH NEXT FROM cur_sort INTO @c_Scode,@c_Slong,@c_Sshort    
 END    
 CLOSE cur_sort    
 DEALLOCATE cur_sort    
    
 SET @C_SQL = @C_SQL + ' ELSE ' + CAST  (@c_runningno AS NVARCHAR) + ' END'    
  --SET @C_SQL = @C_SQL + ' WHEN '''' THEN ' + + CAST  (@c_runningno AS NVARCHAR) + ' ELSE ' + CAST  (@c_runningno+1 AS NVARCHAR) + ' END'    
 END    
     
 --Filtered by @C_CODE and insert to temp table    
 IF (@n_continue = 1 OR @n_continue = 2)      
 BEGIN       
 SELECT @C_CODE = CODE FROM CODELKUP (NOLOCK)      
 WHERE LISTNAME = 'PNDPICWAY' AND STORERKEY = @c_Storerkey AND SHORT = 'S'      
    
 SELECT @c_ConsoShort = CODE FROM CODELKUP (NOLOCK)      
 WHERE LISTNAME = 'PNDPICWAY' AND STORERKEY = @c_Storerkey AND SHORT = 'C'      
     
       
DECLARE pickslip_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
  SELECT  RefKeyLookup.Pickslipno      
  , orders.OrderGroup      
  --, Loadplan.Loadkey      
  , Orders.orderkey                 
  , ISNULL(orders.c_company,'')      
  , orders.externorderkey         
  , LTRIM(RTRIM(ISNULL(orders.Notes,'')))+LTRIM(RTRIM(ISNULL(orders.notes2,'')))      
  , orders.facility        
  , ISNULL(loadplan.trfroom,'')         
  , orders.deliverydate       
  , pickdetail.loc             
  , rtrim(pickdetail.sku)             
  , rtrim(sku.descr)         
  , RTRIM(SKU.Style)          
  , rtrim(lotattribute.lottable01)         
  , rtrim(lotattribute.lottable02)      
  , rtrim(lotattribute.lottable04)      
  , sum(pickdetail.qty)      
  , Pack.Casecnt       
  , Pack.InnerPack      
  , ISNULL(CLK3.SHORT,'')      
  , SUBSTRING(Orders.OrderGroup,2,2)        
  , ISNULL(Orders.UserDefine02,'')     
  , RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(SKU.Itemclass ,CHAR(9),' '),CHAR(10),' '),CHAR(13),' '))) 
  , ISNULL(LOC.LogicalLocation,'')     --WL02
   FROM Orders (nolock)                
   JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.orderkey = ORDERS.Orderkey        
   JOIN LOADPLAN WITH (NOLOCK) ON (LOADPLAN.LOADKEY = ORDERS.LOADKEY)           
   JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey    = PICKDETAIL.Orderkey            
                                     AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)        
   JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)            
                                 AND(ORDERDETAIL.Sku       = SKU.Sku)      
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTATTRIBUTE.LOT = PICKDETAIL.LOT)       
  -- JOIN PICKHEADER WITH (NOLOCK) ON (PICKHEADER.ORDERKEY = ORDERS.ORDERKEY)        
 --  JOIN UPC WITH (NOLOCK) ON SKU.SKU = UPC.SKU AND SKU.STORERKEY = UPC.STORERKEY      
   JOIN PACK WITH (NOLOCK) ON SKU.PACKKEY = PACK.PACKKEY        
   JOIN LOC WITH (NOLOCK) ON PICKDETAIL.LOC = LOC.LOC  --WL02
   LEFT JOIN RefKeyLookup WITH (NOLOCK)      ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)           
   LEFT JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'PNDSHPZON' AND CLK.STORERKEY = ORDERS.STORERKEY      
                                  AND CLK.CODE = SUBSTRING(ORDERS.ORDERGROUP,1,1)       
   LEFT JOIN CODELKUP CLK2 (NOLOCK) ON CLK2.LISTNAME = 'PNDPICK' AND CLK2.STORERKEY = ORDERS.STORERKEY      
                                  AND CLK2.CODE = SKU.ITEMCLASS      
   LEFT JOIN CODELKUP CLK3 (NOLOCK) ON  CLK3.LISTNAME = 'PNDPICWAY' AND CLK3.STORERKEY = ORDERS.STORERKEY      
                                  AND CLK3.CODE = ORDERDETAIL.USERDEFINE05        
   WHERE ( LoadPlan.LoadKey = @c_LoadKey ) AND ORDERDETAIL.UserDefine05 = @C_CODE      
   GROUP BY RefKeyLookup.Pickslipno      
  , orders.OrderGroup      
  --, Loadplan.Loadkey      
  , Orders.Orderkey                  
  , ISNULL(orders.c_company,'')      
  , orders.externorderkey         
  , LTRIM(RTRIM(ISNULL(orders.Notes,'')))+LTRIM(RTRIM(ISNULL(orders.notes2,'')))      
  , orders.facility        
  , ISNULL(loadplan.trfroom,'')         
  , orders.deliverydate       
  , pickdetail.loc             
  , pickdetail.sku             
  , sku.descr         
  , Sku.Style          
  , lotattribute.lottable01         
  , lotattribute.lottable02      
  , lotattribute.lottable04  ,pickdetail.qty, Pack.Casecnt, Pack.InnerPack,CLK3.short      
  , SUBSTRING(Orders.OrderGroup,2,2)        
  , ISNULL(Orders.UserDefine02,'')      
  , RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(SKU.Itemclass ,CHAR(9),' '),CHAR(10),' '),CHAR(13),' ')))  
  , ISNULL(LOC.LogicalLocation,'')     --WL02
  ORDER BY ORDERS.ORDERGROUP, ORDERS.EXTERNORDERKEY    
    
  OPEN pickslip_cur      
  FETCH NEXT FROM pickslip_cur INTO @c_Pickslipno, @c_OrderGroup, @c_Orderkey, @c_C_Company, @c_ExternOrderkey               
     , @c_Notes, @c_Facility, @c_TrfRoom, @d_DeliveryDate, @c_Loc, @c_SKU, @c_SKUDescr, @c_Style, @c_Lott1       
     , @c_Lott2, @d_Lott4, @n_QTY, @n_Case, @n_Innerpack      
     , @c_Short, @c_Dock, @c_UserDefine02, @c_Itemclass
     , @c_LogicalLoc --WL02     
  WHILE (@@FETCH_STATUS <> -1) AND (@n_continue = 1 OR @n_continue = 2)      
  BEGIN      
   SET @n_Casecnt = 0      
   SET @n_Innercnt= 0      
   SET @n_EA = 0      
   --PRINT @n_Qty       
   --PRINT @n_Case      
   --PRINT @n_InnerPack      
   SET @n_Casecnt = CASE WHEN @n_Case > 0 THEN CAST(FLOOR(@n_Qty / @n_Case) AS INT) ELSE 0 END      
   SET @n_Innercnt = CASE WHEN @n_InnerPack > 0 THEN CAST(FLOOR(@n_Qty%@n_Case)/@n_InnerPack AS INT) ELSE 0 END      
   SET @n_EA = @n_Qty - (@n_Case * @n_Casecnt) - (@n_Innercnt * @n_InnerPack)        
      
   INSERT INTO #Singleship (Pickslipno, OrderGroup, Loadkey, Orderkey, C_Company, ExternOrderkey               
     , Notes, Facility, TrfRoom, DeliveryDate, Loc, SKU, Descr, Style, Lott1, Lott2, Lott4, QTY, Casecnt, Innercnt      
     , EA, Short, Dock, UserDefine02,ItemClass,PCasecnt  --WL01  
     , LogicalLocation ) --WL02  
   VALUES(@c_Pickslipno, @c_OrderGroup, @c_Loadkey,@c_Orderkey, @c_C_Company, @c_ExternOrderkey               
     , @c_Notes, @c_Facility, @c_TrfRoom, @d_DeliveryDate, @c_Loc, @c_SKU, @c_SKUDescr, @c_Style, @c_Lott1       
     , @c_Lott2, @d_Lott4, @n_QTY, @n_Casecnt, @n_Innercnt      
     , @n_EA, @c_Short, @c_Dock, @c_UserDefine02,@c_Itemclass,@n_Case  --WL01    
     , @c_LogicalLoc ) --WL02
      
         
  FETCH NEXT FROM pickslip_cur INTO @c_Pickslipno, @c_OrderGroup, @c_Orderkey, @c_C_Company, @c_ExternOrderkey               
     , @c_Notes, @c_Facility, @c_TrfRoom, @d_DeliveryDate, @c_Loc, @c_SKU, @c_SKUDescr, @c_Style, @c_Lott1       
     , @c_Lott2, @d_Lott4, @n_QTY, @n_Case, @n_InnerPACK      
     , @c_Short, @c_Dock, @c_UserDefine02,@c_Itemclass
     , @c_LogicalLoc --WL02      
  END      
  CLOSE pickslip_cur      
  DEALLOCATE pickslip_cur      
  END    
    
  -- process PickSlipNo     
  IF (@n_continue = 1 OR @n_continue = 2)      
  BEGIN       
   DECLARE CUR_GENPSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR           
   SELECT DISTINCT Loadkey, Orderkey        
   FROM   #Singleship           
   WHERE  PickSlipNo IS NULL OR PickSlipNo = ''          
   ORDER BY Orderkey          
          
   OPEN CUR_GENPSLIP          
          
   FETCH NEXT FROM CUR_GENPSLIP INTO @c_loadkey,@c_orderkey         
          
   WHILE (@@Fetch_Status <> -1)          
   BEGIN          
      set @c_pickheaderkey = ''   --INC0589288    
     
   SELECT @c_pickheaderkey = PickHeaderKey    
        FROM  PickHeader (NOLOCK)    
        WHERE externorderkey = @c_loadkey AND  orderkey = @c_OrderKey    
    AND Zone = '3'    
       -- WHERE ExternOrderKey = @c_loadkey AND  Zone = 'LB'      
      --SELECT @c_loadkey,@c_OrderKey,@c_pickheaderkey     
   IF ISNULL(RTRIM(@c_pickheaderkey), '') = ''      
   BEGIN      
  EXECUTE nspg_GetKey      
     'PICKSLIP',      
     9,      
     @c_pickheaderkey  OUTPUT,      
     @b_success       OUTPUT,      
     @n_err           OUTPUT,      
     @c_errmsg        OUTPUT      
      
    SELECT @c_pickheaderkey = 'P' + @c_pickheaderkey      
      
  INSERT INTO PICKHEADER      
  (PickHeaderKey,Orderkey,Zone,PickType,Externorderkey)      
  VALUES      
  (@c_pickheaderkey,@c_orderkey,'3','0',@c_loadkey)       
        
  SELECT @n_err = @@ERROR      
    IF @n_err <> 0      
    BEGIN      
     SELECT @n_continue = 3      
     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73001      
     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On Table PICKHEADER. (isp_GetPickSlipOrders86_2)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
    END      
      
    UPDATE #Singleship      
    SET PICKSLIPNO = @C_PICKHEADERKEY      
    WHERE Loadkey = @c_Loadkey and orderkey = @c_orderkey       
      
    --set @c_pickheaderkey = ''   --INC0589288      
   END      
   FETCH NEXT FROM CUR_GENPSLIP INTO @c_loadkey,@c_orderkey          
   END      
   CLOSE CUR_GENPSLIP      
   DEALLOCATE CUR_GENPSLIP      
 END    
    
 --Update pickheaderkey back to #Singleship    
 IF (@n_continue = 1 OR @n_continue = 2)      
 BEGIN      
   DECLARE update_ps CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
   SELECT DISTINCT Pickheaderkey, Orderkey        
   FROM   Pickheader (nolock)           
   WHERE  externorderkey = @c_loadkey      
      
   open update_ps      
   FETCH NEXT FROM update_ps INTO @c_Pickheaderkey, @c_Orderkey      
   WHILE (@@Fetch_Status <> -1)          
   BEGIN       
     UPDATE #Singleship      
     SET PICKSLIPNO = @C_PICKHEADERKEY      
     WHERE ORDERKEY = @c_Orderkey           
   FETCH NEXT FROM update_ps INTO @c_Pickheaderkey, @c_Orderkey      
   END      
   CLOSE update_ps      
   DEALLOCATE update_ps      
            
 END    
    
 --Sort according to sorting condition and output result    
 IF (@n_continue = 1 OR @n_continue = 2)      
 BEGIN      
  IF EXISTS(SELECT 1 FROM #Singleship)      
  BEGIN      
      INSERT INTO #Singleship (Pickslipno,OrderGroup,Loadkey,Orderkey,C_Company,ExternOrderkey,Notes,Facility        
                              ,TrfRoom,DeliveryDate,Loc,SKU,Descr,Style,Lott1,Lott2,Lott4,QTY,Casecnt,Innercnt
                              ,EA,Short,Dock,UserDefine02,ItemClass,PCasecnt  --WL01
                              ,LogicalLocation ) --WL02    
      SELECT DISTINCT PICKHEADER.PICKHEADERKEY,'','',PICKHEADER.ORDERKEY,'','','','','',GETDATE(),'','','','','','',GETDATE(),'','','','','','','','','',''   
    FROM Pickheader (NOLOCK)    
    JOIN ORDERDETAIL (NOLOCK) ON ORDERDETAIL.ORDERKEY = PICKHEADER.ORDERKEY    
    WHERE PICKHEADER.EXTERNORDERKEY = @c_loadkey AND LTRIM(RTRIM(ORDERDETAIL.UserDefine05)) = @c_ConsoShort    
    AND PICKHEADER.ORDERKEY NOT IN (SELECT ORDERKEY FROM #Singleship)   --INC0589288    

   IF(@c_NoSort <> 1)    
   BEGIN    
    SET @C_SQLEXEC = 'SELECT Pickslipno,OrderGroup,Loadkey,Orderkey,C_Company,ExternOrderkey,Notes,Facility        
                            ,TrfRoom,DeliveryDate,Loc,SKU,Descr,Style,Lott1,Lott2,Lott4,QTY,Casecnt,Innercnt,EA,Short,Dock,UserDefine02,ItemClass,PCasecnt    
                      FROM #Singleship ORDER BY Pickslipno, Ordergroup, Externorderkey, LogicalLocation, SKU, CASE Itemclass ' + @C_SQL    --WL01(SKU)   --WL02(LogicalLocation)     
    --SELECT  @C_SQLEXEC     
      END    
   ELSE    
   BEGIN    
    SET @C_SQLEXEC = 'SELECT Pickslipno,OrderGroup,Loadkey,Orderkey,C_Company,ExternOrderkey,Notes,Facility        
                            ,TrfRoom,DeliveryDate,Loc,SKU,Descr,Style,Lott1,Lott2,Lott4,QTY,Casecnt,Innercnt,EA,Short,Dock,UserDefine02,ItemClass,PCasecnt    
                      FROM #Singleship ORDER BY Pickslipno, Ordergroup, Externorderkey, LogicalLocation, SKU' --WL01(SKU)     --WL02(LogicalLocation)   
   --SELECT  @C_SQLEXEC    
   END    
   EXEC sp_ExecuteSql     @C_SQLEXEC    
    
  END      
  ELSE      
  BEGIN      
   IF EXISTS(SELECT 1 FROM PICKHEADER (NOLOCK) WHERE externorderkey = @c_loadkey AND PICKHEADERKEY <> '')   
   BEGIN   
    INSERT INTO #Singleship (Pickslipno,OrderGroup,Loadkey,Orderkey,C_Company,ExternOrderkey,Notes,Facility        
                            ,TrfRoom,DeliveryDate,Loc,SKU,Descr,Style,Lott1,Lott2,Lott4,QTY,Casecnt,Innercnt
                            ,EA,Short,Dock,UserDefine02,ItemClass,PCasecnt,LogicalLocation)   --WL01    --WL02  
    SELECT PICKHEADERKEY,'','',ORDERKEY,'','','','','',GETDATE(),'','','','','','',GETDATE(),'','','','','','','','','',''    
    FROM PICKHEADER (NOLOCK)      
    WHERE externorderkey = @c_loadkey AND PICKHEADERKEY <> ''     

    SELECT Pickslipno,OrderGroup,Loadkey,Orderkey,C_Company,ExternOrderkey,Notes,Facility        
          ,TrfRoom,DeliveryDate,Loc,SKU,Descr,Style,Lott1,Lott2,Lott4,QTY,Casecnt,Innercnt
          ,EA,Short,Dock,UserDefine02,ItemClass,PCasecnt  --WL01  
    FROM #Singleship     
    ORDER BY Pickslipno    
    
   END      
   ELSE      
   BEGIN      
   INSERT INTO #Singleship (Pickslipno,OrderGroup,Loadkey,Orderkey,C_Company,ExternOrderkey,Notes,Facility        
                           ,TrfRoom,DeliveryDate,Loc,SKU,Descr,Style,Lott1,Lott2,Lott4,QTY,Casecnt,Innercnt
                           ,EA,Short,Dock,UserDefine02,ItemClass,PCasecnt,LogicalLocation)--WL01 --WL02   
   VALUES('','','','','','','','','',GETDATE(),'','','','','','',GETDATE(),'','','','','','','','','','')      
    
   SELECT Pickslipno,OrderGroup,Loadkey,Orderkey,C_Company,ExternOrderkey,Notes,Facility        
         ,TrfRoom,DeliveryDate,Loc,SKU,Descr,Style,Lott1,Lott2,Lott4,QTY,Casecnt,Innercnt
         ,EA,Short,Dock,UserDefine02,ItemClass,PCasecnt --WL01 
   FROM #Singleship    
    
   END      
  END      
 END      
      
    
      
EXIT_SP:      
  IF @n_continue=3  -- Error Occured - Process And Return      
  BEGIN      
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'Generation of Pick Slip'      
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
  END      
      
END  

GO