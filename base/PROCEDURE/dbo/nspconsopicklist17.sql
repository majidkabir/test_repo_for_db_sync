SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store Procedure:  nspConsoPickList17                                 */  
/* Creation Date: 2008-03-25                                            */  
/* Copyright: IDS                                                       */  
/* Written by: June                                                     */  
/*                                                                      */  
/* Purpose:  Consolidated Pickslip for IDSTH (SOS101777)                */  
/*                                                                      */  
/* Input Parameters:  @c_loadkey  - Loadkey                             */  
/*                                                                      */  
/* Output Parameters:  None                                             */  
/*                                                                      */  
/* Return Status:  None                                                 */  
/*                                                                      */  
/* Usage:  Used for report dw = r_dw_consolidated_pick17_1              */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By:                                                           */  
/*                                                                      */  
/* PVCS Version: 1.7                                                    */  
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
/* 18-Nov-2020  WLChooi 1.6  WMS-15667 Add Innerpack calculation (WL01) */
/* 15-Dec-2021  WLChooi 1.7  DevOps Combine Script                      */
/* 15-Dec-2021  WLChooi 1.7  WMS-18587 - Add Lottable06 (WL02)          */
/* 09-Dec-2022  Mingle  1.8  WMS-21293 - Add reportcfg (ML01)           */
/************************************************************************/  
  
CREATE PROC [dbo].[nspConsoPickList17] (  
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
          @c_GroupByLocType  NCHAR(1)  
            
   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1, @n_err = 0, @c_errmsg = ''  
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order  
   
   BEGIN TRAN  
  
   SELECT LoadPlanDetail.LoadKey,     
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
           --WL01 START
           InnerCnt = CASE WHEN PACK.InnerPack > 0  
                           THEN FLOOR( (SUM(PICKDETAIL.Qty) - (PACK.Pallet * CASE WHEN PACK.Pallet  > 0 THEN FLOOR(SUM(PICKDETAIL.Qty) / PACK.Pallet) ELSE 0 END ) - 
                                (PACK.CaseCnt * CASE WHEN PACK.CaseCnt > 0 AND Pack.Pallet > 0   
                                                THEN FLOOR((SUM(PICKDETAIL.Qty) - (FLOOR(SUM(PICKDETAIL.Qty) / PACK.Pallet) * PACK.Pallet))/PACK.Casecnt)   
                                                WHEN PACK.CaseCnt > 0 AND Pack.Pallet = 0   
                                                THEN SUM(PICKDETAIL.Qty) / PACK.Casecnt  
                                                ELSE 0 END) ) /Pack.InnerPack)
                           ELSE 0 END,
           ISNULL(CL3.Short,'N') AS ShowInner,
           PACK.InnerPack,
           --WL01 END
           LOTATTRIBUTE.Lottable06,   --WL02
           ISNULL(CL4.Short,'N') AS ShowLott06,   --WL02
			  ISNULL(CL5.Short,'N') AS ShowPalletBarcode   --ML01
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
   LEFT JOIN CODELKUP CL WITH (NOLOCK) ON (CL.ListName = 'REPORTCFG' AND CL.Code = 'PGBREAKBYPAZONE' AND CL.Long = 'r_dw_consolidated_pick17'  
                                       AND CL.Storerkey = ORDERS.Storerkey AND ISNULL(CL.Short,'') <> 'N') --NJOW01,03  
   LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON (CL2.ListName = 'REPORTCFG' AND CL2.Code = 'PGBREAKBYLOCTYPE' AND CL2.Long = 'r_dw_consolidated_pick17'  
                                       AND CL2.Storerkey = ORDERS.Storerkey AND ISNULL(CL2.Short,'') <> 'N') --NJOW04  
   LEFT JOIN CODELKUP CL3 WITH (NOLOCK) ON (CL3.ListName = 'REPORTCFG' AND CL3.Code = 'ShowInner' AND CL3.Long = 'r_dw_consolidated_pick17'  
                                       AND CL3.Storerkey = ORDERS.Storerkey AND ISNULL(CL3.Short,'') <> 'N')   --WL01
   LEFT JOIN CODELKUP CL4 WITH (NOLOCK) ON (CL4.ListName = 'REPORTCFG' AND CL4.Code = 'ShowLott06' AND CL4.Long = 'r_dw_consolidated_pick17'  
                                       AND CL4.Storerkey = ORDERS.Storerkey AND ISNULL(CL4.Short,'') <> 'N')   --WL02
	LEFT JOIN CODELKUP CL5 WITH (NOLOCK) ON (CL5.ListName = 'REPORTCFG' AND CL5.Code = 'ShowPalletBarcode' AND CL5.Long = 'r_dw_consolidated_pick17'  
                                       AND CL5.Storerkey = ORDERS.Storerkey AND ISNULL(CL5.Short,'') <> 'N')   --ML01
   JOIN LOC WITH (NOLOCK) ON ( PICKDETAIL.Loc = LOC.Loc ) --NJOW01  
   WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )  
   GROUP BY LoadPlanDetail.LoadKey,     
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
            PACK.InnerPack,         --WL01
            ISNULL(CL3.Short,'N'),  --WL01
            LOTATTRIBUTE.Lottable06,   --WL02
            ISNULL(CL4.Short,'N'),   --WL02
				ISNULL(CL5.Short,'N')	--ML01
      
  DECLARE C_zone CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
  SELECT DISTINCT PutawayZone, Locationtype, GroupByPAZone, GroupByLocType  
  FROM   #TEMP_PICK     
  WHERE  ISNULL(PickSlipNo,'') = ''  
  ORDER BY Putawayzone, Locationtype  
  
  OPEN C_zone    
    
  FETCH NEXT FROM C_zone INTO @c_PutawayZone, @c_Locationtype, @c_GroupByPAZone, @c_GroupByLocType  
    
  WHILE (@@Fetch_Status <> -1)    
  BEGIN -- while 1    
    SET @c_Pickslipno = ''  
       
     SELECT TOP 1 @c_PickSlipNo = PickHeaderKey  
     FROM PICKHEADER (NOLOCK)  
     WHERE ExternOrderkey = @c_Loadkey  
     --AND Wavekey = CASE WHEN @c_GroupByPAZone = 'Y' OR @c_GroupByLocType = 'Y' THEN @c_putawayzone ELSE Wavekey END  --NJOW03  --(Wan01) - Fixed  
     --AND ConsoOrderkey = CASE WHEN @c_GroupByPAZone = 'Y' THEN @c_locationtype ELSE ConsoOrderkey END  --NJOW03                --(Wan01) - Fixed  
     AND Wavekey = CASE WHEN @c_GroupByLocType = 'Y' THEN @c_putawayzone ELSE Wavekey END  --(Wan01) - Fixed  
     AND Zone = 'LP'  
    
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
  
           INSERT PICKHEADER (pickheaderkey, ExternOrderkey, zone, PickType, Wavekey, ConsoOrderkey)    
                      VALUES (@c_PickSlipNo, @c_Loadkey, 'LP', '0',  @c_Putawayzone, @c_Locationtype)   
  
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
       IF @n_continue = 1 OR @n_continue = 2  
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
                IF NOT EXISTS(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickSlipNo)  
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
     END -- pickslipno=''  
    
     IF @n_continue = 1 or @n_continue = 2     
     BEGIN                
        DECLARE C_PickDetailKey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
        SELECT PD.PickDetailKey, O.Orderkey, PD.OrderLineNumber   
        FROM ORDERS O (NOLOCK)  
        JOIN PICKDETAIL PD (NOLOCK) ON O.Orderkey = PD.Orderkey  
        JOIN LOC (NOLOCK) ON PD.Loc = LOC.Loc  
        WHERE LOC.Putawayzone = CASE WHEN @c_GroupByPAZone = 'Y' THEN @c_putawayzone ELSE LOC.Putawayzone END  --NJOW03  
        AND LOC.Locationtype = CASE WHEN @c_GroupByPAZone = 'Y' THEN @c_locationtype  
                                    WHEN @c_GroupByLocType = 'Y' THEN @c_putawayzone ELSE LOC.Locationtype END  --NJOW03  
        --WHERE LOC.Putawayzone = @c_Putawayzone  
        --AND LOC.Locationtype = @c_Locationtype  
        AND O.Loadkey = @c_Loadkey  
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
  
     UPDATE #TEMP_PICK    
     SET PickSlipNo = @c_PickSlipNo    
     WHERE LoadKey = @c_LoadKey           
     AND   Putawayzone = @c_Putawayzone  
     AND   Locationtype = @c_Locationtype  
     AND   GroupByPAZone = @c_GroupByPAZone  
     AND   GroupByLocType = @c_GroupByLocType  
     AND   ISNULL(PickSlipNo,'') = ''  
    
     FETCH NEXT FROM C_zone INTO @c_Putawayzone, @c_Locationtype, @c_GroupByPAZone, @c_GroupByLocType  
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
            InnerCnt,              --(WL01)         
            ShowInner,             --(WL01)   
            InnerPack,             --(WL01)  
            Lottable06,            --WL02
            ShowLott06,            --WL02         
				ShowPalletBarcode      --ML01  
      FROM #TEMP_PICK     
      
   IF OBJECT_ID('tempdb..#TEMP_PICK') IS NOT NULL   --WL01
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
    EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList17'      
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