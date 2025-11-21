SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  nsp_GetPickSlipOrders63                            */  
/* Creation Date: 2008-03-25                                            */  
/* Copyright: IDS                                                       */  
/* Written by: June                                                     */  
/*                                                                      */  
/* Purpose:Picking Slip Report same with  "r_dw_consolidated_pick17"    */
/*         for IDSTH (SOS375654)                                        */  
/*                                                                      */  
/* Input Parameters:  @c_loadkey  - Loadkey                             */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_print_pickorder63                  */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver. Purposes                                   */  
/* 28-Nov-2013  NJOW01  1.0  296354-Add putawayzone                     */  
/* 24-Sep-2014  NJOW02  1.1  -TH-DSG revise Pickslip to running         */  
/*                           PSNO by Location type-Zone                 */  
/* 18-Nov-2014  NJOW03  1.2  Fix - add back report cfg PGBREAKBYPAZONE  */  
/* 26-Nov-2014  NJOW04  1.3  320669 - add group by location type only   */  
/* 29-Apr-2015  CSCHONG 1.4   SOS339808  (CS01)                         */
/* 09-Jul-2015  CSCHONG 1.5   SOS346307  (CS02)                         */
/* 29-AUG-2016  CSCHONG 1.6   SOS#375654 split by orderkey (CS03)       */
/* 15-Sep-2016  CSCHONG 1.7   INVIN00146279 change zone ='3'�(CS04)     */
/************************************************************************/  
  
CREATE PROC [dbo].[nsp_GetPickSlipOrders63] (  
 @c_LoadKey NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
  DECLARE @n_err             INT,  
          @n_continue        INT,  
          @b_success         INT,  
          @c_errmsg          NVARCHAR(255),  
          @n_StartTranCnt    INT,  
          @c_Putawayzone     NVARCHAR(10),  
          @c_Locationtype    NVARCHAR(10),  
          @c_Pickslipno      NVARCHAR(10),  
          @c_PickDetailKey   NVARCHAR(10),   
          @c_Orderkey        NVARCHAR(10),   
          @c_OrderLineNumber NVARCHAR(5),  
          @c_StorerKey       NVARCHAR(15),  
          @c_GroupByPAZone   NCHAR(1),  
          @c_GroupByLocType  NCHAR(1),
          @c_GetOrderkey     NVARCHAR(10)   --(CS03)
            
 SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_err = 0, @c_errmsg = ''  
 -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  
   
  BEGIN TRAN  
  
 SELECT DISTINCT PICKDETAIL.Orderkey,        --(CS03)
        LoadPlanDetail.LoadKey,     
        RefKeyLookup.PickSlipNo,  
        ISNULL(LoadPlan.Route, '') Route,    
        LoadPlan.AddDate,     
        PICKDETAIL.Loc,     
        PICKDETAIL.Sku,     
        SUM(PICKDETAIL.Qty) Qty,         
        SKU.DESCR SKU_DESCR,     
        PACK.CaseCnt,    
        PACK.PackKey,  
        ISNULL(LoadPlan.CarrierKey, '') CarrierKey,  
        PICKDETAIL.ID AS Pallet_ID,  
        LOTATTRIBUTE.Lottable01,   
        LOTATTRIBUTE.Lottable02,   
        LOTATTRIBUTE.Lottable03,   
        LOTATTRIBUTE.Lottable04,   
        LOTATTRIBUTE.Lottable05,  
        PACK.Pallet,  
        LoadPlan.Delivery_Zone,  
        Palletcnt = CASE WHEN PACK.Pallet  > 0 THEN FLOOR(SUM(PICKDETAIL.Qty) / PACK.Pallet) ELSE 0 END,  
        Cartoncnt = CASE WHEN PACK.CaseCnt > 0 AND Pack.Pallet > 0   
             THEN FLOOR((SUM(PICKDETAIL.Qty) - (FLOOR(SUM(PICKDETAIL.Qty) / PACK.Pallet) * PACK.Pallet))/PACK.Casecnt)   
             WHEN PACK.CaseCnt > 0 AND Pack.Pallet = 0   
             THEN SUM(PICKDETAIL.Qty)/PACK.Casecnt  
             ELSE 0 END,  
         CASE WHEN ISNULL(CL.CODE,'') <> '' THEN LOC.Putawayzone  
              WHEN ISNULL(CL2.CODE,'') <> '' THEN LOC.Locationtype  --Store location type to PA Zone column will show barcode in report  
              ELSE '' END AS Putawayzone, --NJOW01,03, 04  
         CASE WHEN ISNULL(CL.CODE,'') <> '' THEN  
              LOC.Locationtype ELSE '' END AS Locationtype, --NJOW01,03  
         CASE WHEN ISNULL(CL.CODE,'') <> '' THEN 'Y' ELSE 'N' END AS GroupByPAZone,   
         CASE WHEN ISNULL(CL2.CODE,'') <> '' THEN 'Y' ELSE 'N' END AS GroupByLocType,  
        --LOC.Putawayzone,  
         --LOC.Locationtype  
         Loadplan.Route AS LRoute,                     --(CS01)
         Loadplan.Externloadkey AS LEXTLoadKey,        --(CS01)
         Loadplan.Priority AS LPriority,                --(CS01)
        -- Loadplan.UserDefine01 AS LUdef01               --(CS01)  --(CS02) 
         REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/') AS LUdef01, --(CS02)
         ORDERS.ExternOrderKey AS ExtOrdKey,                                             --(CS02)
         ORDERS.C_Company AS c_company,                                                   --(CS02)
         ORDERS.[Status] AS ORDStatus,                                                    --(CS02)
		   ORDERS.DeliveryDate AS DeliveryDate,                                             --(CS02)
		   CAST (ORDERS.Notes AS NVARCHAR(255))  as Notes,                                  --(CS02)
		   SUM((ORDERDETAIL.QtyAllocated + ORDERDETAIL.QtyPicked + ORDERDETAIL.ShippedQty) * ((SKU.Length * SKU.Width * SKU.Height) / PACK.CaseCnt)) AS Totcube	 --(CS02)
  INTO #TEMP_PICK   
  FROM LoadPlanDetail WITH (NOLOCK)  
  JOIN ORDERDETAIL WITH (NOLOCK) ON ( LoadPlanDetail.LoadKey = ORDERDETAIL.LoadKey AND   
                                  LoadPlanDetail.OrderKey = ORDERDETAIL.OrderKey)    
 JOIN ORDERS WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = ORDERS.OrderKey )  
 JOIN PICKDETAIL WITH (NOLOCK) ON ( ORDERDETAIL.OrderKey = PICKDETAIL.OrderKey ) AND     
                ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber )     
 JOIN SKU WITH (NOLOCK) ON  ( SKU.StorerKey = PICKDETAIL.Storerkey ) AND    
                       ( SKU.Sku = PICKDETAIL.Sku )  
 JOIN LoadPlan WITH (NOLOCK) ON ( LoadPlanDetail.LoadKey = LoadPlan.LoadKey )   
 JOIN PACK WITH (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey )   
 JOIN LOTATTRIBUTE WITH (NOLOCK) ON ( LOTATTRIBUTE.Lot = PICKDETAIL.Lot )  
  LEFT JOIN RefKeyLookup (NOLOCK) ON (RefKeyLookup.PickDetailKey = PICKDETAIL.PickDetailKey)  
 LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'REPORTCFG' AND CL.Code = 'PGBREAKBYPAZONE' AND CL.Long = 'r_dw_print_pickorder63'  
                                    AND CL.Storerkey = ORDERS.Storerkey AND ISNULL(CL.Short,'') <> 'N') --NJOW01,03  
 LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCFG' AND CL2.Code = 'PGBREAKBYLOCTYPE' AND CL2.Long = 'r_dw_print_pickorder63'  
                                    AND CL2.Storerkey = ORDERS.Storerkey AND ISNULL(CL2.Short,'') <> 'N') --NJOW04  
 JOIN LOC WITH (NOLOCK) ON ( PICKDETAIL.Loc = LOC.Loc ) --NJOW01  
 WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )  
 GROUP BY PICKDETAIL.Orderkey,                          --(CS03)
          LoadPlanDetail.LoadKey,     
          RefKeyLookup.PickSlipNo,  
          ISNULL(LoadPlan.Route, ''),    
          LoadPlan.AddDate,     
          PICKDETAIL.Loc,     
          PICKDETAIL.Sku,     
          SKU.DESCR,     
          PACK.CaseCnt,    
          PACK.PackKey,  
          ISNULL(LoadPlan.CarrierKey, ''),  
          PICKDETAIL.ID,  
          LOTATTRIBUTE.Lottable01,   
          LOTATTRIBUTE.Lottable02,   
          LOTATTRIBUTE.Lottable03,   
          LOTATTRIBUTE.Lottable04,   
          LOTATTRIBUTE.Lottable05,  
          PACK.Pallet,  
          LoadPlan.Delivery_Zone,  
           CASE WHEN ISNULL(CL.CODE,'') <> '' THEN LOC.Putawayzone   
              WHEN ISNULL(CL2.CODE,'') <> '' THEN LOC.Locationtype   
              ELSE '' END, --NJOW01,03, 04  
           CASE WHEN ISNULL(CL.CODE,'') <> '' THEN  
                LOC.Locationtype ELSE '' END, --NJOW01,03      
           CASE WHEN ISNULL(CL.CODE,'') <> '' THEN 'Y' ELSE 'N' END,   
           CASE WHEN ISNULL(CL2.CODE,'') <> '' THEN 'Y' ELSE 'N' END,   
           --LOC.Putawayzone,  
           --LOC.Locationtype  
           loadplan.Route,              --(CS01)
           Loadplan.ExternLoadKey,      --(CS01) 
           Loadplan.Priority,           --(CS01)
           --Loadplan.UserDefine01        --(CS01)   --(CS02)
           REPLACE(CONVERT(NVARCHAR(12),Loadplan.LPuserdefDate01,106),' ','/'),
            ORDERS.ExternOrderKey ,   
            ORDERS.C_Company  ,   
            ORDERS.[Status],   
		      ORDERS.DeliveryDate ,
		      CAST (ORDERS.Notes AS NVARCHAR(255))
      
  DECLARE C_zone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
  SELECT DISTINCT Orderkey --PutawayZone, Locationtype, GroupByPAZone, GroupByLocType    --(CS03)
  FROM   #TEMP_PICK   
  WHERE  ISNULL(PickSlipNo,'') = ''  
  ORDER BY Orderkey --Putawayzone, Locationtype     --(CS02)
  
  OPEN C_zone    
    
  FETCH NEXT FROM C_zone INTO @c_GetOrderkey --@c_PutawayZone, @c_Locationtype, @c_GroupByPAZone, @c_GroupByLocType   --(CS03)
    
  WHILE (@@Fetch_Status <> -1)    
  BEGIN -- while 1    
  
    SET @c_Pickslipno = ''  
    /*CS03 Start*/
    SET @c_PutawayZone = '' 
    SET @c_Locationtype = ''
    SET @c_GroupByPAZone = ''
    SET @c_GroupByLocType = ''
    
    
    SELECT TOP 1 @c_PutawayZone = PutawayZone
                ,@c_Locationtype = Locationtype
                ,@c_GroupByPAZone = GroupByPAZone
                ,@c_GroupByLocType = GroupByLocType
     FROM   #TEMP_PICK   
    WHERE Orderkey =   @c_GetOrderkey
    /*CS03 Start*/           
       
     SELECT TOP 1 @c_PickSlipNo = PickHeaderKey  
     FROM PICKHEADER (NOLOCK)  
     WHERE OrderKey   = @c_GetOrderkey             --(CS03)
     --WHERE ExternOrderkey = @c_Loadkey           --(CS03)
     --AND Wavekey = CASE WHEN @c_GroupByPAZone = 'Y' OR @c_GroupByLocType = 'Y' THEN @c_putawayzone ELSE Wavekey END  --NJOW03  --(Wan01) - Fixed  
     --AND ConsoOrderkey = CASE WHEN @c_GroupByPAZone = 'Y' THEN @c_locationtype ELSE ConsoOrderkey END  --NJOW03                --(Wan01) - Fixed  
     AND Wavekey = CASE WHEN @c_GroupByLocType = 'Y' THEN @c_putawayzone ELSE Wavekey END  --(Wan01) - Fixed  
     AND Zone = '3'  --(CS04)
    
     IF ISNULL(@c_PickSlipNo,'') = ''  
     BEGIN         
        SET @c_PickSlipNo = ''    
     
        EXECUTE nspg_GetKey    
           'PICKSLIP',    
           9,       
           @c_PickSlipNo   OUTPUT,    
           @b_success      OUTPUT,    
           @n_err          OUTPUT,    
           @c_errmsg       OUTPUT    
      
        IF @b_success = 1     
        BEGIN    
           SELECT @c_PickSlipNo = 'P' + @c_PickSlipNo              
  
           INSERT PICKHEADER (pickheaderkey, ExternOrderkey, zone, PickType, Wavekey, ConsoOrderkey,OrderKey)           --(CS03)
                      VALUES (@c_PickSlipNo, @c_Loadkey, '3', '0',  @c_Putawayzone, @c_Locationtype,@c_GetOrderkey)    --(CS03)
  
           IF @@ERROR <> 0     
           BEGIN    
              SET @n_Continue = 3     
              BREAK     
           END     
        END -- @b_success = 1      
        ELSE     
        BEGIN    
           SET @n_Continue = 3     
           BREAK     
        END     
          
       -- Do Auto Scan-in when only 1 storer found and configkey is setup  
       IF @n_continue = 1 or @n_continue = 2  
       BEGIN    
        IF ( SELECT COUNT(DISTINCT StorerKey) FROM ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)  
           WHERE LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND LOADPLANDETAIL.LoadKey = @c_LoadKey ) = 1  
        BEGIN   
         -- Only 1 storer found  
         SET @c_StorerKey = ''  
         SELECT @c_StorerKey = (SELECT DISTINCT StorerKey   
                 FROM   ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)  
                 WHERE  LOADPLANDETAIL.OrderKey = ORDERS.OrderKey   
                 AND   LOADPLANDETAIL.LoadKey = @c_LoadKey )  
          
         IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND  
              SValue = '1' AND StorerKey = @c_StorerKey)  
         BEGIN   
          -- Configkey is setup  
                IF NOT Exists(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)  
                BEGIN  
                   INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)  
                   VALUES (@c_PickSlipNo, GetDate(), sUser_sName(), NULL)      
                     
                   IF @@ERROR <> 0     
                    BEGIN    
                       SET @n_Continue = 3     
                    END     
              END  
         END -- Configkey is setup  
        END -- Only 1 storer found  
       END            
       
        IF @n_continue = 1 or @n_continue = 2     
        BEGIN                
        DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
        SELECT PD.PickDetailKey, O.Orderkey, PD.OrderLineNumber   
        FROM ORDERS O (NOLOCK)  
        JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
        --WHERE LOC.Putawayzone = CASE WHEN @c_GroupByPAZone = 'Y' THEN @c_putawayzone ELSE LOC.Putawayzone END  --NJOW03  
        --AND LOC.Locationtype = CASE WHEN @c_GroupByPAZone = 'Y' THEN @c_locationtype  
          --                          WHEN @c_GroupByLocType = 'Y' THEN @c_putawayzone ELSE LOC.Locationtype END  --NJOW03  
        --WHERE LOC.Putawayzone = @c_Putawayzone  
        --AND LOC.Locationtype = @c_Locationtype  
        WHERE O.Loadkey = @c_Loadkey  
        AND PD.OrderKey=@c_GetOrderkey
        ORDER BY PD.Pickdetailkey  
               
        OPEN C_PickDetailKey    
       
        FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_Orderkey, @c_OrderLineNumber     
       
        WHILE @@FETCH_STATUS <> -1    
        BEGIN    
           IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey)     
           BEGIN     
              INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)    
              VALUES (@c_PickDetailKey, @c_PickSlipNo, @c_OrderKey, @c_OrderLineNumber, @c_LoadKey)      
                
              IF @@ERROR <> 0     
              BEGIN    
                 SET @n_Continue = 3     
              END                           
           END     
       
           FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_Orderkey, @c_OrderLineNumber     
        END     
        CLOSE C_PickDetailKey     
        DEALLOCATE C_PickDetailKey             
     END  
                
     END -- pickslipno=''             
  
     UPDATE #TEMP_PICK    
     SET PickSlipNo = @c_PickSlipNo    
     WHERE LoadKey = @c_LoadKey           
  --   AND   Putawayzone = @c_Putawayzone          --(CS03)
  --   AND   Locationtype = @c_Locationtype        --(CS03)
 --    AND   GroupByPAZone = @c_GroupByPAZone     --(CS03)
  --   AND   GroupByLocType = @c_GroupByLocType   --(CS03) 
     AND   ISNULL(PickSlipNo,'') = ''  
     AND Orderkey = @c_GetOrderkey                  --(CS03)
    
     FETCH NEXT FROM C_zone INTO @c_GetOrderkey --@c_Putawayzone, @c_Locationtype, @c_GroupByPAZone, @c_GroupByLocType  --(CS03)
  END -- while 1       
  CLOSE C_zone    
  DEALLOCATE C_zone     
                                                                  
  IF @n_continue = 3                          
     DELETE FROM #TEMP_PICK       
       
     SELECT LoadKey,                                                                                                            
            PickSlipNo,                                                                                                           
            Route,                                                                                                  
            AddDate,                                                                                                                  
            Loc,                                                                                                                    
            Sku,                                                                                                                    
            Qty,                                                                                                         
            SKU_DESCR,                                                                                                               
            CaseCnt,                                                                                                                      
            PackKey,                                                                                                                      
            CarrierKey,                                                                                        
            Pallet_ID,                                                                                                        
            Lottable01,                                                                                                           
            Lottable02,                                                                                                           
            Lottable03,                                                                                                           
            Lottable04,                                                                                                           
            Lottable05,                                                                                                           
            Pallet,                                                                                                                
            Delivery_Zone,                                                                                                     
            Palletcnt,   
            Cartoncnt,           
            Putawayzone,                                                                                 
            Locationtype,
            LRoute,                --(CS01) 
            LEXTLoadKey,           --(CS01)
            LPriority,             --(CS01) 
            LUdef01,               --(CS01)       
            Orderkey,               --(CS03) 
            ExtOrdKey,              --(CS03)
            c_company,              --(CS03)
            ORDStatus,              --(CS03)
		      DeliveryDate,           --(CS03)
		      Notes,                  --(CS03)     
		      totcube                 --(CS03)             
      FROM #TEMP_PICK     
  
  DROP TABLE #TEMP_PICK      
     
  IF @n_continue=3  -- Error Occured - Process And Return      
  BEGIN      
    SELECT @b_success = 0      
    IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt       
    BEGIN      
       ROLLBACK TRAN   
    END           
    ELSE      
    BEGIN      
      WHILE @@TRANCOUNT > @n_StartTranCnt       
      BEGIN      
         COMMIT TRAN      
      END                
    END                
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_GetPickSlipOrders63'      
    RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
    RETURN      
  END      
  ELSE      
  BEGIN      
     /* Error Did Not Occur , Return Normally */      
     SELECT @b_success = 1      
     WHILE @@TRANCOUNT > @n_StartTranCnt       
     BEGIN      
        COMMIT TRAN      
     END                
     RETURN      
  END      
  /* End Return Statement */   
  
END /* main procedure */ 

GO