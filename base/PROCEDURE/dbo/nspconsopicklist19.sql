SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/    
/* Store Procedure:  nspConsoPickList19                                 */    
/* Creation Date:  10-Nov-2008                                          */    
/* Copyright: IDS                                                       */    
/* Written by:  YTWAN                                                   */    
/*                                                                      */    
/* Purpose:  SOS#122464 Swire Report Enhancement                        */    
/*                                                                      */    
/* Input Parameters:  @a_s_LoadKey  - (LoadKey)                         */    
/*                                                                      */    
/* Output Parameters:  None                                             */    
/*                                                                      */    
/* Return Status:  Report                                               */    
/*                                                                      */    
/* Usage:                                                               */    
/*                                                                      */    
/* Local Variables:                                                     */    
/*                                                                      */    
/* Called By:  r_dw_consolidated_pick19_2                               */    
/*                                                                      */    
/* PVCS Version: 1.0                                                    */    
/*                                                                      */    
/* Version: 5.4                                                         */    
/*                                                                      */    
/* Data Modifications:                                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author    Ver.  Purposes                                */    
/* 16-Jan-2009 YTWan    1.1   SOS122464 - Not to display pickdetail     */    
/*                              qty = 0 in Pickslip  (YTWan01)          */    
/* 25-Jun-2009  NJOW01    1.2   SOS#134747 - Add busr6 column           */    
/* 13-Jun-2013  NJOW02    1.3   280422-Add grouping                     */    
/* 08-Apr-2014  NJOW03    1.4   307410-configurable sort by logical loc */    
/* 14-Apr-2014  TLTING    1.5   SQL2012 Fixing Bugs                     */    
/* 09-Nov-2015  SHONG01   1.6   Performance Tuning                      */     
/* 06-Dec-2017  WLCHOOI   1.6   WMS-3595 Add Codelkup to change the     */    
/*                              position of the fields (WL01)           */    
/* 06-Mar-2018  WLCHOOI   1.7   WMS-8218 - PUMA Add CartonQTY and EA on */    
/*                                         every page (WL02)            */  
/* 17-Mar-2021  ALIANG    1.8   Bug fix(AL01)                           */  
/************************************************************************/    
    
CREATE PROC [dbo].[nspConsoPickList19] (@a_s_LoadKey NVARCHAR(10) )    
 AS    
 BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
 DECLARE  @c_CurrOrderKey  NVARCHAR(10),    
    @n_err           int,    
    @n_continue      int,    
    @c_PickHeaderKey NVARCHAR(10),    
    @b_success       int,    
    @c_errmsg        NVARCHAR(255),    
    @n_StartTranCnt  int,    
            @c_ShowTotal     NVARCHAR(1),    
            @c_Storerkey     NVARCHAR(30),    
            @n_MaxLine       INT = 39,    
            @C_RECGROUP      NVARCHAR(20),    
            @n_qty           INT = 0      
    
 SET @n_StartTranCnt=@@TRANCOUNT    
   SET @n_continue = 1    
    
   --WL02 START    
   CREATE TABLE #TEMPCONSO19(    
   loadkey         NVARCHAR(10),    
   pickslipno        NVARCHAR(18),    
   route             NVARCHAR(10),    
   adddate           DATETIME,    
   loc               NVARCHAR(10),    
   sku               NVARCHAR(20),    
   QTY               INT,                   
sku_descr         NVARCHAR(60),    
   casecnt           FLOAT,    
   packkey           NVARCHAR(10),    
   totalqtyordered   INT,    
   totalqtyalloc     INT,    
   uom3              NVARCHAR(10),    
   prepackindicator  NVARCHAR(30),    
   packqtyindicator  INT,    
   size              NVARCHAR(10),    
   locationtype      NVARCHAR(10),    
   busr6             NVARCHAR(30),    
   logicallocation   NVARCHAR(18),    
   layout            NVARCHAR(1),    
   showtotal         NVARCHAR(1),    
   recgroup          NVARCHAR(20)    
   )    
    
   CREATE TABLE #TEMPCONSO19_1(    
   loadkey           NVARCHAR(10),    
   pickslipno        NVARCHAR(18),    
   route             NVARCHAR(10),    
   adddate           DATETIME,    
   loc               NVARCHAR(10),    
   sku               NVARCHAR(20),    
   QTY               INT,                   
   sku_descr         NVARCHAR(60),    
   casecnt           FLOAT,    
   packkey           NVARCHAR(10),    
   totalqtyordered   INT,    
   totalqtyalloc     INT,    
   uom3              NVARCHAR(10),    
   prepackindicator  NVARCHAR(30),    
   packqtyindicator  INT,    
   size              NVARCHAR(10),    
   locationtype      NVARCHAR(10),    
   busr6             NVARCHAR(30),    
   logicallocation   NVARCHAR(18),    
   layout            NVARCHAR(1),    
   showtotal         NVARCHAR(1),    
   recgroup          NVARCHAR(20)    
   )    
   --WL02 END    
    
 /* Start Modification */    
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order    
   SET @c_PickHeaderKey = ''    
    
   IF NOT EXISTS(SELECT PickHeaderKey     
         FROM PICKHEADER WITH (NOLOCK)     
      WHERE ExternOrderKey = @a_s_LoadKey     
        AND  Zone = '7')     
 BEGIN    
  SET @b_success = 0    
    
  EXECUTE nspg_GetKey    
   'PICKSLIP',    
   9,       
   @c_PickHeaderKey    OUTPUT,    
   @b_success     OUTPUT,    
   @n_err   OUTPUT,    
   @c_errmsg      OUTPUT    
    
  IF @b_success <> 1    
  BEGIN    
   SET @n_continue = 3    
  END    
    
  IF @n_continue = 1 or @n_continue = 2    
  BEGIN    
   SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey    
    
   INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)    
   VALUES (@c_PickHeaderKey, @a_s_LoadKey, '1', '7')    
              
   SET @n_err = @@ERROR    
     
   IF @n_err <> 0     
   BEGIN    
    SET @n_continue = 3    
    SET @n_err = 63501    
    SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList19)'    
   END    
  END -- @n_continue = 1 or @n_continue = 2    
 END    
   ELSE    
   BEGIN    
      SELECT @c_PickHeaderKey = PickHeaderKey    
        FROM PickHeader WITH (NOLOCK)      
       WHERE ExternOrderKey = @a_s_LoadKey     
         AND Zone = '7'    
   END    
    
   IF ISNULL(RTRIM(@c_PickHeaderKey),'') = ''    
   BEGIN    
  SET @n_continue = 3    
  SET @n_err = 63502    
  SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Get LoadKey Failed. (nspConsoPickList19)'    
   END    
    
   --WL02 START    
   IF @n_continue = 1 or @n_continue = 2    
 BEGIN    
      SELECT @c_Storerkey = Orders.Storerkey    
      FROM ORDERS (NOLOCK)    
      WHERE ORDERS.LOADKEY = @a_s_LoadKey    
    
      SELECT @c_ShowTotal = UPPER(SHORT)    
      FROM CODELKUP (NOLOCK)     
      WHERE STORERKEY = @c_Storerkey AND LISTNAME = 'REPORTCFG'     
      AND CODE = 'SHOWTOTAL' AND LONG = 'r_dw_consolidated_pick19'    
   END    
   --WL02 END    
    
 IF @n_continue = 1 or @n_continue = 2    
 BEGIN    
  -- SHONG01    
      DECLARE @n_TotalQtyOrdered   INT,    
              @n_TotalQtyAllocated INT    
    
      SET @n_TotalQtyOrdered = 0    
      SET @n_TotalQtyAllocated = 0     
                        
      SELECT @n_TotalQtyOrdered= SUM(OpenQty),     
             @n_TotalQtyAllocated = SUM(QtyAllocated+QtyPicked+ShippedQty)     
      FROM ORDERDETAIL WITH (NOLOCK)     
      JOIN LOADPLANDETAIL lpd (NOLOCK) ON lpd.OrderKey = ORDERDETAIL.OrderKey    
      WHERE lpd.LoadKey = @a_s_LoadKey     
      GROUP BY lpd.LoadKey    
      
      INSERT INTO #TEMPCONSO19 --WL02    
  SELECT   LoadPlanDetail.LoadKey,       
     PICKHeader.PickHeaderKey,       
     --LoadPlan.Route,  
     ISNULL(LoadPlan.Route,''),--AL01       
     LoadPlan.AddDate,       
     PICKDETAIL.Loc,       
     PICKDETAIL.Sku,       
     SUM(PICKDETAIL.Qty) AS Qty,   --NJOW02    
     SKU.DESCR,       
     PACK.CaseCnt,      
     PACK.PackKey,    
             @n_TotalQtyOrdered,     
               @n_TotalQtyAllocated,     
           Pack.PackUOM3 As UOM3,     
           ISNULL(LTRIM(RTRIM(SKU.PrePackIndicator)),'') As PrePackIndicator,     
           (SKU.PackQtyIndicator) As PackQtyIndicator,    
     SKU.Size,    
               CASE WHEN SKUxLOC.LocationType <> 'PICK'     
        THEN 'BULK'     
                    ELSE 'PICK'    
        END AS LocationType,    
      ISNULL(SKU.Busr6,''), --NJOW01    
      CASE WHEN ISNULL(CLR.CODE,'') <> '' THEN    
          LOC.LogicalLocation ELSE LOC.Loc END, --NJOW03    
    CASE WHEN CLR1.Code IS NOT NULL THEN '1' ELSE '0' END as layout --WL01    
            ,ISNULL(@c_ShowTotal,'N')  --WL02    
            ,'1'           --WL02    
    FROM LOADPLAN WITH (NOLOCK)     
      INNER JOIN LoadPlanDetail WITH (NOLOCK)     
          ON ( LOADPLAN.LoadKey = LoadPlanDetail.LoadKey )     
      INNER JOIN PICKDETAIL WITH (NOLOCK)     
      ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey)     
  INNER JOIN SKU WITH (NOLOCK)     
      ON (SKU.StorerKey = PICKDETAIL.Storerkey )     
     AND (SKU.Sku = PICKDETAIL.Sku )    
  INNER JOIN PACK WITH (NOLOCK)     
      ON ( PACK.PackKey = SKU.PACKKey )        
      INNER JOIN PICKHEADER     
      ON (PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)     
  INNER JOIN LOT WITH (NOLOCK)     
              ON (PICKDETAIL.LOT = LOT.LOT)    
  INNER JOIN SKUxLOC WITH (NOLOCK)    
              ON (SKUxLOC.Storerkey = SKU.Storerkey)    
             AND (SKUxLOC.SKU = SKU.SKU)    
     AND (SKUxLOC.Loc = PICKDETAIL.Loc)    
  INNER JOIN LOC WITH (NOLOCK)    
            ON (PICKDETAIL.Loc = LOC.Loc) --NJOW03    
    LEFT OUTER JOIN Codelkup CLR (NOLOCK) ON (PICKDETAIL.Storerkey = CLR.Storerkey AND CLR.Code = 'SORTBYLOGICALLOC'     
                                          AND CLR.Listname = 'REPORTCFG' AND CLR.Long = 'r_dw_consolidated_pick19' AND ISNULL(CLR.Short,'') <> 'N') --NJOW03    
 LEFT OUTER JOIN Codelkup CLR1 (NOLOCK) ON (PICKDETAIL.Storerkey = CLR1.Storerkey AND CLR1.Code = 'LAYOUT01'     
                                          AND CLR1.Listname = 'REPORTCFG' AND CLR1.Long = 'r_dw_consolidated_pick19' AND ISNULL(CLR1.Short,'') <> 'N') --WL01              
    WHERE  PICKHeader.PickHeaderKey = @c_PickHeaderKey     
    AND  PICKDETAIL.QTY > 0           -- (YTWan01)    
  GROUP BY LoadPlanDetail.LoadKey,   --NJOW02    
        PICKHeader.PickHeaderKey,       
        --LoadPlan.Route,       
  ISNULL(LoadPlan.Route,''),--AL01  
        LoadPlan.AddDate,       
        PICKDETAIL.Loc,       
        PICKDETAIL.Sku,       
         SKU.DESCR,       
         PACK.CaseCnt,      
        PACK.PackKey,    
           Pack.PackUOM3,     
           ISNULL(LTRIM(RTRIM(SKU.PrePackIndicator)),''),     
           SKU.PackQtyIndicator,    
        SKU.Size,    
             CASE WHEN SKUxLOC.LocationType <> 'PICK'     
         THEN 'BULK'     
                  ELSE 'PICK'    
       END,    
         ISNULL(SKU.Busr6,''),    
         CASE WHEN ISNULL(CLR.CODE,'') <> '' THEN    
             LOC.LogicalLocation ELSE LOC.Loc END, --NJOW03    
   CASE WHEN CLR1.Code IS NOT NULL THEN '1' ELSE '0' END --WL01    
             
    
   END -- @n_continue = 1 or @n_continue = 2    
    
   --WL02 START    
   --Reportcfg is OFF    
   IF(ISNULL(@c_ShowTotal,'N') = 'N' OR ISNULL(@c_ShowTotal,'N') = '')    
   BEGIN    
      SELECT * FROM #TEMPCONSO19 ORDER BY pickslipno,loadkey,LOCATIONTYPE,Logicallocation,LOC,SKU    
   END    
   ELSE IF (ISNULL(@c_ShowTotal,'N') = 'Y') --Reportcfg is ON    
   BEGIN    
   INSERT INTO #TEMPCONSO19_1    
   SELECT     
     loadkey              
     ,pickslipno           
     ,route                
     ,adddate              
     ,loc                  
     ,sku                  
     ,QTY                  
     ,sku_descr            
     ,casecnt              
     ,packkey              
     ,totalqtyordered      
     ,totalqtyalloc        
     ,uom3                 
     ,prepackindicator     
     ,packqtyindicator     
     ,size                 
     ,locationtype         
     ,busr6                
     ,Logicallocation      
     ,layout               
     ,showtotal            
     ,(Row_number() OVER (PARTITION BY pickslipno ORDER BY pickslipno,loadkey,LOCATIONTYPE,Logicallocation,LOC,SKU asc)-1)/@n_MaxLine+1 AS RECGROUP    
     FROM #TEMPCONSO19    
    
     SELECT * FROM #TEMPCONSO19_1 ORDER BY pickslipno,loadkey,LOCATIONTYPE,Logicallocation,LOC,SKU    
    
     END    
     --WL02 END    
    
 IF @n_continue=3  -- Error Occured - Process And Return    
 BEGIN    
--   SELECT @b_success = 0    
--   IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt    
--   BEGIN    
--    ROLLBACK TRAN    
--   END    
--   ELSE    
--   BEGIN    
--    WHILE @@TRANCOUNT > @n_StartTranCnt    
--    BEGIN    
--     COMMIT TRAN    
--    END    
--   END    
  execute nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList19'    
  RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
  --RAISERROR @n_err @c_errmsg    
  RETURN    
 END    
 ELSE    
 BEGIN    
  SELECT @b_success = 1    
  WHILE @@TRANCOUNT > @n_StartTranCnt    
  BEGIN    
   COMMIT TRAN    
  END    
  RETURN    
 END    
END /* main procedure */  


GO