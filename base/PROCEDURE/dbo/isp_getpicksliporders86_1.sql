SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Stored Procedure: isp_GetPickSlipOrders86_1                          */    
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
/* PVCS Version:                                                       */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author   Ver  Purposes                                  */    
/*26-02-2019  WLCHOOI   1.0  INC0589288 - Add logic to check if the     */    
/*                                   itemclass is not found in codelkup */    
/*26-02-2019  WLCHOOI   1.1  WMS-8070 - Add Pack.Casecnt to report and  */      
/*                                        sorting sequence (WL01)       */      
/************************************************************************/    
    
CREATE PROC [dbo].[isp_GetPickSlipOrders86_1]  (@c_loadkey NVARCHAR(10))    
 AS    
BEGIN    
    SET CONCAT_NULL_YIELDS_NULL OFF    
    SET QUOTED_IDENTIFIER OFF    
    SET ANSI_NULLS OFF    
    SET NOCOUNT ON    
    
    DECLARE @c_pickheaderkey        NVARCHAR(10),    
    @n_continue             int,    
    @n_starttcnt      int,    
    @c_errmsg     NVARCHAR(255),    
    @b_success     int,    
    @n_err      int,    
    @c_LogicalLoc    NVARCHAR(18),    
    @c_LocType     NVARCHAR(10),    
    @c_ID       NVARCHAR(18),     -- tlting01    
    @c_orderkey     NVARCHAR(10),    
    @c_PrintedFlag    NVARCHAR(1),    
    @c_PrevPickslipNo   NVARCHAR(10),    
    @c_PickUOM     NVARCHAR(5),    
    @c_PickZone     NVARCHAR(10),    
    @c_C_Company    NVARCHAR(45),    --(Wan01)    
    --@c_Prev_C_Company       NVARCHAR(45), --NJOW03    
    @c_PickType     NVARCHAR(30),    
    @c_PickDetailkey   NVARCHAR(10),    
    @c_OrderLineNumber  NVARCHAR(5),    
    @d_Lottable04    datetime,    
    @n_PageNo     int,    
    @c_TotalPage    int,    
    @b_debug      int  ,    
    @c_WaveKey     NVARCHAR(10),    -- (tlting01)    
    @c_Lottable02label  NVARCHAR(30),    
    @c_Lottable04Label  NVARCHAR(30),    
    @c_Storerkey    NVARCHAR(15),    
    @c_Consigneekey   NVARCHAR(15), --NJOW04    
    @c_OrderGrp     NVARCHAR(20),  --CS01    
    @n_CntOrderGrp    INT,           --CS01     
    @c_OrdGrpFlag    NVARCHAR(1),   --CS01    
    @c_RLoadkey     NVARCHAR(20),  --CS01    
    @c_TrfRoom     NVARCHAR(10), --NJOW05    
    @c_LEXTLoadKey    NVARCHAR(20),   --(CS01)    
    @c_LPriority    NVARCHAR(10),   --(CS01)    
    @c_LPuserdefDate01  datetime        --(CS01)    
    ,@n_showField           INT             --(CS03)    
    ,@C_CODE    NVARCHAR(20)    
    ,@c_result    NVARCHAR(100)    
    ,@c_sort    NVARCHAR(100)     
    ,@c_sql     NVARCHAR(MAX)     
    ,@c_ExecArguments  NVARCHAR(MAX)     
    
    ,@c_Pickslipno      NVARCHAR(10)    
    ,@c_Route   NVARCHAR(50)    
    ,@d_LoadingDate     Datetime    
    ,@c_Loc             NVARCHAR(10)    
    ,@c_SKU             NVARCHAR(20)    
    ,@c_SkuDescr        NVARCHAR(60)    
    ,@c_Style    NVARCHAR(60)    
    ,@n_QTY    INT    
    ,@n_Case   INT    
    ,@n_Casecnt   INT    
    ,@n_InnerPack  INT    
    ,@n_Innercnt  INT    
    ,@n_EA    INT    
    ,@c_Lott2   NVARCHAR(36)     
    ,@c_Short   NVARCHAR(1)    
    ,@c_Dock   NVARCHAR(2)    
    ,@c_Itemclass     NVARCHAR(50)    
    ,@c_Scode           NVARCHAR(20)    
    ,@c_Slong           NVARCHAR(20)    
    ,@c_Sshort           NVARCHAR(20)    
    ,@c_runningno       INT = 1    
    ,@c_NoSort          INT = 0    
    ,@C_SQLEXEC         NVARCHAR(MAX) = ''    
    ,@c_sortNotInCodelkup  NVARCHAR(MAX) = ''     
    ,@c_SItemclass           NVARCHAR(20)    
    
    
 CREATE TABLE #Consolidate  (    
    Pickslipno      NVARCHAR(10),    
    Route           NVARCHAR(50),    
    LoadingDate     Datetime,    
    Loadkey         NVARCHAR(10),    
    Loc             NVARCHAR(10),    
    SKU             NVARCHAR(20),    
    Descr           NVARCHAR(60),    
    Style    NVARCHAR(60),    
    QTY    INT,    
    Casecnt   FLOAT,    
    Innercnt  FLOAT,    
   -- EA    INT,    
    Lott2   NVARCHAR(36),      
    Short   NVARCHAR(1),    
    Dock   NVARCHAR(2),    
    Orderkey  NVARCHAR(10),    
    ItemClass       NVARCHAR(50))    
    
  CREATE TABLE #Consolidate_1  (    
    Route           NVARCHAR(50),    
    LoadingDate     Datetime,    
    Loadkey         NVARCHAR(10),    
    Loc             NVARCHAR(10),    
    SKU             NVARCHAR(20),    
    Descr           NVARCHAR(60),    
    Style   NVARCHAR(60),    
    QTY    INT,    
    Casecnt   FLOAT,    
    Innercnt  FLOAT,    
    EA    INT,    
    Lott2   NVARCHAR(36),      
    Short   NVARCHAR(1),    
    Dock   NVARCHAR(2),    
    ItemClass   NVARCHAR(50),    
            PCasecnt    FLOAT) --WL01    
    
 CREATE TABLE #SORTING(    
 CODE       NVARCHAR(20)    
 ,LONG      INT    
 ,SHORT     INT )    
     
 CREATE TABLE #SortNotInCodelkup(      
 ITEMCLASS       NVARCHAR(20)   )      
    
    SELECT @n_continue = 1, @n_starttcnt=@@TRANCOUNT    
    SELECT @b_Debug = 0    
    
   --BEGIN TRAN    
   -- Uses PickType as a Printed Flag    
   UPDATE PickHeader    
   SET   PickType = '1',    
      TrafficCop = NULL    
   WHERE externorderkey = @c_loadkey    
   --AND Orderkey = ''    
   AND   Zone = '3'    
   AND   PickType = '0'    
   IF @@ERROR <> 0    
   BEGIN    
     SELECT @n_continue = 3    
     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73000    
     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed On Table Pickheader Table. (isp_GetPickSlipOrders86_1)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '    
   END    
     
    
    SELECT @c_Storerkey = STORERKEY FROM ORDERS (NOLOCK)     
    WHERE ORDERS.LOADKEY = @C_LOADKEY    
    
    SELECT @C_CODE = CODE FROM CODELKUP (NOLOCK)    
    WHERE LISTNAME = 'PNDPICWAY' AND STORERKEY = @c_Storerkey AND SHORT = 'C'    
    
    --Find sorting sequence based on Sku.Itemclass = Codelkup.Code    
    IF @n_continue = 1 OR @n_continue = 2    
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
    WHERE Orders.Loadkey = @c_loadkey AND ORDERDETAIL.UserDefine05 = @c_code    
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
    ORDER BY LONG    
    
    OPEN cur_sort    
    
    FETCH NEXT FROM cur_sort INTO @c_Scode,@c_Slong,@c_Sshort    
    WHILE(@@FETCH_STATUS<>-1)    
    BEGIN    
       IF(@c_runningno = 1)    
       BEGIN    
          SET @c_sortNotInCodelkup = '''' + @c_Scode + ''''    
       END    
       ELSE    
       BEGIN    
          SET @c_sortNotInCodelkup = @c_sortNotInCodelkup + ','    
          SET @c_sortNotInCodelkup = @c_sortNotInCodelkup + '''' + @c_Scode + ''''    
       END    
        
       SET @C_SQL = @C_SQL + ' WHEN '''+ @c_Scode +''' THEN '+ CAST (@c_runningno AS NVARCHAR)    
       SET @c_runningno = @c_runningno + 1    
    
    FETCH NEXT FROM cur_sort INTO @c_Scode,@c_Slong,@c_Sshort    
    END    
    CLOSE cur_sort    
    DEALLOCATE cur_sort    
    
    END    
     
    IF(@b_debug = 1)    
    SELECT @c_sortNotInCodelkup    
        
    --INC0589288 start    
    SET @C_SQLEXEC = ' INSERT INTO #SortNotInCodelkup    
          SELECT DISTINCT LTRIM(RTRIM(SKU.ITEMCLASS))    
          FROM ORDERS (NOLOCK)      
          JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.orderkey = ORDERS.Orderkey       
          JOIN SKU  WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)            
                                          AND(ORDERDETAIL.Sku       = SKU.Sku)      
          WHERE Orders.Loadkey = ' + ''''+ @c_loadkey + ''''+ 'AND SKU.ITEMCLASS NOT IN ( ' + @c_sortNotInCodelkup + ' )    
          AND ORDERDETAIL.UserDefine05 = ' + '''' + @c_code + '''' +    
         ' ORDER BY LTRIM(RTRIM(SKU.ITEMCLASS)) ASC'    
    
    EXEC sp_ExecuteSql     @C_SQLEXEC    
    
        
    IF EXISTS(SELECT 1 FROM #SortNotInCodelkup)    
    BEGIN    
       --Itemclass Not In Codelkup    
       DECLARE cur_sort_NotInCodelkup CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
       SELECT ITEMCLASS    
       FROM #SortNotInCodelkup       
      
       OPEN cur_sort_NotInCodelkup      
      
       FETCH NEXT FROM cur_sort_NotInCodelkup INTO @c_SItemclass    
       WHILE(@@FETCH_STATUS <> -1)      
       BEGIN     
           SET @C_SQL = @C_SQL + ' WHEN '''+ @c_SItemclass +''' THEN '+ CAST (@c_runningno AS NVARCHAR)      
           SET @c_runningno = @c_runningno + 1      
       FETCH NEXT FROM cur_sort_NotInCodelkup INTO @c_SItemclass        
       END    
       CLOSE cur_sort_NotInCodelkup      
       DEALLOCATE cur_sort_NotInCodelkup     
    END     
    
   --INC0589288 end    
 IF(@b_debug = 1)    
 SELECT @C_SQLEXEC    
    
 IF(@b_debug = 1)    
 SELECT * FROM #SortNotInCodelkup    
    
 SET @C_SQL = @C_SQL + ' ELSE ' + CAST  (@c_runningno AS NVARCHAR) + ' END'      
    
 --Set some used variables to ''    
 SET @C_SQLEXEC = ''    
     
    --Filtered by @C_CODE and insert to temp table    
    IF @n_continue = 1 OR @n_continue = 2    
    BEGIN    
    --INSERT INTO #Consolidate    
    INSERT INTO #Consolidate (Pickslipno,Route,LoadingDate,Loadkey,Loc,SKU,Descr,Style,QTY,Casecnt,Innercnt--,EA    
    ,Lott2,Short,Dock,Orderkey,Itemclass)     
    SELECT     
     RefKeyLookup.Pickslipno,    
     LTRIM(RTRIM(ISNULL(Orders.Ordergroup,''))) + '/' + ISNULL(CLK.SHORT,''),            
     LoadPlan.AddDate,    
     LoadPlan.LoadKey,           
     PICKDETAIL.Loc,           
     RTRIM(SKU.SKU),           
     LTRIM(SKU.DESCR),    
     RTRIM(SKU.STYLE),           
        sum(Pickdetail.QTY),     
        PACK.CaseCnt,    
        Pack.InnerPack,    
     LOTATTRIBUTE.Lottable02,    
        ISNULL(CLK3.SHORT,''),    
     SUBSTRING(ORDERS.OrderGroup,2,2),    
     ORDERS.Orderkey,    
     RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(SKU.Itemclass ,CHAR(9),' '),CHAR(10),' '),CHAR(13),' ')))    
      FROM ORDERS (NOLOCK)          
      JOIN ORDERDETAIL WITH (NOLOCK) ON ORDERDETAIL.orderkey = ORDERS.Orderkey      
      JOIN LOADPLAN WITH (NOLOCK) ON (LOADPLAN.LOADKEY = ORDERS.LOADKEY)         
      JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERDETAIL.Orderkey    = PICKDETAIL.Orderkey          
                                        AND PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)      
      JOIN SKU        WITH (NOLOCK) ON (ORDERDETAIL.Storerkey = SKU.Storerkey)          
                   AND(ORDERDETAIL.Sku       = SKU.Sku)    
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTATTRIBUTE.LOT = PICKDETAIL.LOT)     
     -- JOIN PICKHEADER WITH (NOLOCK) ON (PICKHEADER.ORDERKEY = ORDERS.ORDERKEY)      
     -- JOIN UPC WITH (NOLOCK) ON SKU.SKU = UPC.SKU AND SKU.STORERKEY = UPC.STORERKEY    
      JOIN PACK WITH (NOLOCK) ON SKU.PACKKEY = PACK.PACKKEY    
      LEFT JOIN RefKeyLookup WITH (NOLOCK)      ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)           
      LEFT JOIN CODELKUP CLK (NOLOCK) ON CLK.LISTNAME = 'PNDSHPZON' AND CLK.STORERKEY = ORDERS.STORERKEY    
     AND CLK.CODE = SUBSTRING(ORDERS.ORDERGROUP,1,1)     
      LEFT JOIN CODELKUP CLK2 (NOLOCK) ON CLK2.LISTNAME = 'PNDPICK' AND CLK2.STORERKEY = ORDERS.STORERKEY    
     AND CLK2.CODE = SKU.ITEMCLASS    
      LEFT JOIN CODELKUP CLK3 (NOLOCK) ON  CLK3.LISTNAME = 'PNDPICWAY' AND CLK3.STORERKEY = ORDERS.STORERKEY    
     AND CLK3.CODE = ORDERDETAIL.USERDEFINE05    
      WHERE ( LoadPlan.LoadKey = @c_loadkey ) AND ORDERDETAIL.UserDefine05 = @c_code    
      GROUP BY    
      RefKeyLookup.Pickslipno,    
     LTRIM(RTRIM(ISNULL(Orders.Ordergroup,''))),    
     ISNULL(CLK.SHORT,''),            
     LoadPlan.AddDate,    
     LoadPlan.LoadKey,           
     PICKDETAIL.Loc,           
     RTRIM(SKU.SKU),           
     LTRIM(SKU.DESCR),    
     RTRIM(SKU.Style),     
        PACK.CaseCnt,    
        Pack.InnerPack,    
     LOTATTRIBUTE.Lottable02,    
        ISNULL(CLK3.SHORT,''),    
     SUBSTRING(ORDERS.OrderGroup,2,2),    
     Orders.Orderkey,    
     RTRIM(LTRIM(REPLACE(REPLACE(REPLACE(SKU.Itemclass ,CHAR(9),' '),CHAR(10),' '),CHAR(13),' ')))    
    END    
    
    -- process PickSlipNo     
    IF @n_continue = 1 OR @n_continue = 2    
    BEGIN     
      DECLARE CUR_GENPSLIP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR         
      SELECT DISTINCT LoadKey,Orderkey      
      FROM   #Consolidate         
      WHERE  PickSlipNo IS NULL OR PickSlipNo = ''        
      ORDER BY LoadKey,Orderkey          
        
      OPEN CUR_GENPSLIP        
        
      FETCH NEXT FROM CUR_GENPSLIP INTO @c_LoadKey,  @c_OrderKey      
        
      WHILE (@@Fetch_Status <> -1)        
      BEGIN         
     SELECT @c_pickheaderkey = PickHeaderKey    
           FROM  PickHeader (NOLOCK)    
           WHERE externorderkey = @c_loadkey AND  orderkey = @c_OrderKey    
       AND Zone = '3'    
    
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
       (PickHeaderKey,Orderkey,Externorderkey,Zone,PickType)    
       VALUES    
       (@c_pickheaderkey,@c_OrderKey, @c_LoadKey,'3','0')     
    
       SELECT @n_err = @@ERROR    
         IF @n_err <> 0    
         BEGIN    
        SELECT @n_continue = 3    
          SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err=73001    
        SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed On Table PICKHEADER. (isp_GetPickSlipOrders86_1)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '    
         END    
    
        UPDATE #Consolidate    
        SET PICKSLIPNO = @C_PICKHEADERKEY    
        WHERE Loadkey = @c_Loadkey and orderkey = @c_orderkey     
    
         set @c_pickheaderkey = ''    
    
      
     END    
     FETCH NEXT FROM CUR_GENPSLIP INTO @c_LoadKey,@c_OrderKey      
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
    UPDATE #Consolidate    
    SET PICKSLIPNO = @C_PICKHEADERKEY    
    WHERE ORDERKEY = @c_Orderkey         
      FETCH NEXT FROM update_ps INTO @c_Pickheaderkey, @c_Orderkey    
      END    
      CLOSE update_ps    
      DEALLOCATE update_ps    
    END    
    
    --Calculate Qty, Case, Innerpack    
    IF (@n_continue = 1 OR @n_continue = 2)      
    BEGIN     
      DECLARE pickslip_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
      SELECT Route    
     ,LoadingDate    
     ,Loc    
     ,SKU    
     ,Descr    
     ,Style    
     ,sum(QTY)    
     ,Casecnt    
     ,Innercnt    
     ,Lott2    
     ,Short    
     ,Dock    
     ,Itemclass    
     FROM #Consolidate    
     GROUP BY Route    
     ,LoadingDate    
     ,Loc    
     ,SKU    
     ,Descr    
     ,Style    
     ,Casecnt    
     ,Innercnt    
     ,Lott2    
     ,Short    
     ,Dock    
     ,Itemclass    
            
     OPEN pickslip_cur    
     FETCH NEXT FROM pickslip_cur INTO @c_Route,@d_LoadingDate,@c_Loc,@c_SKU,@c_SkuDescr    
             ,@c_Style,@n_QTY,@n_Case,@n_InnerPack,@c_Lott2,@c_Short,@c_Dock,@c_itemclass    
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
    
      INSERT INTO #Consolidate_1 (Route,LoadingDate,Loadkey,Loc,SKU,Descr,Style,QTY,Casecnt,Innercnt,EA,Lott2,Short,Dock,Itemclass,PCasecnt)--WL01    
      VALUES(@c_Route,@d_LoadingDate,@c_loadkey,@c_Loc,@c_SKU,@c_SkuDescr    
        ,@c_Style,@n_QTY,@n_Casecnt,@n_Innercnt,@n_EA,@c_Lott2,@c_Short,@c_Dock, @c_itemclass,@n_Case) --WL01    
       
     FETCH NEXT FROM pickslip_cur INTO @c_Route,@d_LoadingDate,@c_Loc,@c_SKU,@c_SkuDescr    
             ,@c_Style,@n_QTY,@n_Case,@n_InnerPack,@c_Lott2,@c_Short,@c_Dock,@c_itemclass    
     END    
     CLOSE pickslip_cur    
     DEALLOCATE pickslip_cur      
    END    
    
      IF(@b_debug = 1)    
      SELECT @C_SQL    
    
    --Sort according to sorting condition and output result    
    IF (@n_continue = 1 OR @n_continue = 2)      
    BEGIN      
    IF EXISTS(SELECT 1 FROM #Consolidate_1)    
    BEGIN    
     IF(@c_NoSort <> 1)    
      BEGIN    
       SET @C_SQLEXEC = 'SELECT Route,LoadingDate,Loadkey,Loc,SKU,Descr,Style,QTY,    
                         Casecnt,Innercnt,EA,Lott2,Short,Dock,ItemClass,PCasecnt    
                                  FROM #Consolidate_1 ORDER BY CASE Itemclass ' + @C_SQL + ', Route'      --WL01    
      -- SELECT  @C_SQLEXEC     
         END    
      ELSE    
      BEGIN    
          SET @C_SQLEXEC = 'SELECT Route,LoadingDate,Loadkey,Loc,SKU,Descr,Style,QTY,    
                         Casecnt,Innercnt,EA,Lott2,Short,Dock,ItemClass,PCasecnt        
                                  FROM #Consolidate_1 ORDER BY Route'       --WL01    
      -- SELECT  @C_SQLEXEC     
      END    
      EXEC sp_ExecuteSql     @C_SQLEXEC    
    END    
    ELSE    
    BEGIN    
     INSERT INTO #Consolidate_1 (Route,LoadingDate,Loadkey,Loc,SKU,Descr,Style,QTY,Casecnt,Innercnt,EA,Lott2,Short,Dock,ItemClass,PCasecnt) --WL01    
     VALUES('',GETDATE(),'','','','','','','','','','','','','','')    
     SELECT Route,LoadingDate,Loadkey,Loc,SKU,Descr,Style,QTY,Casecnt,Innercnt,EA,Lott2,Short,Dock,ItemClass,PCasecnt FROM #Consolidate_1 --WL01    
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