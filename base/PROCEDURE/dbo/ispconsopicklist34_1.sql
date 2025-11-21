SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  ispConsoPickList34_1                               */
/* Creation Date: 2013-07-23                                            */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose:  SOS#284378 - LFA Consolidated Pickslip                     */
/*           Duplicate from nspConsoPickList27                          */
/* Input Parameters:  @c_loadkey  - Loadkey                             */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_consolidated_pick34_1              */
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
/* Date         Author        Purposes                                  */
/************************************************************************/

CREATE PROC [dbo].[ispConsoPickList34_1] (
@c_LoadKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue        INT 
         , @n_StartTranCnt    INT
         , @b_success         INT
         , @n_err             INT 
         , @c_errmsg          NVARCHAR(255)
         , @c_FirstTime       NVARCHAR(1)
         , @c_PrintedFlag     NVARCHAR(1) 
         , @c_PickHeaderKey   NVARCHAR(10)
         , @c_StorerKey       NVARCHAR(15)

   SET @n_StartTranCnt=@@TRANCOUNT
   SET @n_continue = 1
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order
   
   WHILE @@TRANCOUNT > 0 
   BEGIN
      COMMIT TRAN
   END
   
   SET @c_PickHeaderKey = ''
   SELECT @c_PickHeaderKey = ISNULL(RTRIM(PickHeaderKey),'') 
   FROM  PICKHEADER WITH (NOLOCK) 
   WHERE ExternOrderKey = @c_LoadKey
   AND   Zone = '7'

   IF @c_PickHeaderKey = ''
   BEGIN
      SET @c_FirstTime = 'Y'
      SET @c_PrintedFlag = 'N'
   END
   ELSE
   BEGIN
      SET @c_FirstTime = 'N'
      SET @c_PrintedFlag = 'Y'
   END -- Record Not Exists

   -- Uses PickType as a Printed Flag

   IF @c_FirstTime = 'Y'
   BEGIN
      SET @b_success = 0
     
      EXECUTE nspg_GetKey
         'PICKSLIP'
        ,9   
        ,@c_PickHeaderKey  OUTPUT 
        ,@b_success        OUTPUT 
        ,@n_err            OUTPUT 
        ,@c_errmsg         OUTPUT

      IF @b_success <> 1
      BEGIN
         SET @n_continue = 3
         GOTO EXIT_SP 
      END

      SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey
      INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
                      VALUES (@c_PickHeaderKey, @c_LoadKey, '0',  '7')
   
      -- Do Auto Scan-in when only 1 storer found and configkey is setup
      SET @c_Storerkey = ''

      SELECT @c_Storerkey = MIN(ORDERS.Storerkey)
      FROM  LOADPLANDETAIL WITH (NOLOCK)
      JOIN  ORDERS WITH (NOLOCK) ON (LOADPLANDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
      GROUP BY LOADPLANDETAIL.LoadKey
      HAVING COUNT(DISTINCT StorerKey) = 1      

      -- Only 1 storer found
      IF @c_Storerkey <> ''
      BEGIN 
         IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND
                    SValue = '1' AND StorerKey = @c_StorerKey)
         BEGIN 
            -- Configkey is setup
            INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
            VALUES (@c_PickHeaderKey, GetDate(), sUser_sName(), NULL)    
         END -- Configkey is setup
      END -- Only 1 storer found
   END  -- @c_FirstTime = 'Y'

   SELECT PickSlipNo = PICKHEADER.PickHeaderKey  
      ,  PrintedFlag= @c_PrintedFlag
      ,  LOADPLAN.LoadKey 
      ,  CarrierKey = ISNULL(RTRIM(LoadPlan.CarrierKey), '')  
      ,  Route      = ISNULL(RTRIM(LoadPlan.Route), '')  
      ,  LOADPLAN.AddDate   
      ,  PICKDETAIL.Loc
      ,  PICKDETAIL.ID     
      ,  PICKDETAIL.Sku    
      ,  SKU_DESCR  = ISNULL(RTRIM(SKU.DESCR), '')  
      ,  LOTATTRIBUTE.Lottable01  
      ,  LOTATTRIBUTE.Lottable02  
      ,  LOTATTRIBUTE.Lottable03  
      ,  CASE WHEN LOTATTRIBUTE.Lottable04 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable04 END
      ,  CASE WHEN LOTATTRIBUTE.Lottable05 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable05 END 
      ,  LOC.LogicalLocation 
      ,  Qty = SUM(PICKDETAIL.Qty)   
      ,  QtyCS      = FLOOR (CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty)/(PACK.CaseCnt * 1.00) ELSE 0 END)
      ,  QtyIN      = FLOOR (CASE WHEN PACK.InnerPack > 0 THEN (SUM(PICKDETAIL.Qty)-
                                       (FLOOR (CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty)/(PACK.CaseCnt * 1.00) ELSE 0 END) * PACK.CaseCnt))
                                       /(PACK.InnerPack * 1.00)
                                  ELSE 0 END) 
      ,  QtyEA      = SUM(PICKDETAIL.Qty)
                    - (FLOOR (CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty)/(PACK.CaseCnt * 1.00) ELSE 0 END)*PACK.CaseCnt)
                    - (FLOOR (CASE WHEN PACK.InnerPack > 0 THEN (SUM(PICKDETAIL.Qty)-
                                       (FLOOR (CASE WHEN PACK.CaseCnt > 0 THEN SUM(PICKDETAIL.Qty)/(PACK.CaseCnt * 1.00) ELSE 0 END)* PACK.CaseCnt))
                                        /(PACK.InnerPack * 1.00)
                                   ELSE 0 END)*PACK.InnerPack)      
   FROM LOADPLAN       WITH (NOLOCK)
   JOIN PICKHEADER     WITH (NOLOCK) ON (LOADPLAN.Loadkey = PICKHEADER.ExternOrderKey ) 
                                     AND(PICKHEADER.Zone = '7' )
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)
   JOIN PICKDETAIL     WITH (NOLOCK) ON (LOADPLANDETAIL.OrderKey = PICKDETAIL.OrderKey)
   JOIN LOTATTRIBUTE   WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot)
   JOIN LOC            WITH (NOLOCK) ON (PICKDETAIL.LOC = LOC.Loc)  
   JOIN SKU            WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.Storerkey)    
                                     AND(PICKDETAIL.Sku = SKU.Sku)
   JOIN PACK           WITH (NOLOCK) ON (SKU.PackKey = PACK.PACKKey ) 
   WHERE ( LOADPLAN.LoadKey = @c_LoadKey )
   GROUP BY LOADPLAN.LoadKey   
         ,  PICKHEADER.PickHeaderKey  
         ,  ISNULL(RTRIM(LoadPlan.CarrierKey), '')  
         ,  ISNULL(RTRIM(LoadPlan.Route), '')  
         ,  LOADPLAN.AddDate   
         ,  PICKDETAIL.Loc 
         ,  PICKDETAIL.ID    
         ,  PICKDETAIL.Sku    
         ,  ISNULL(RTRIM(SKU.DESCR), '')
         ,  PACK.CaseCnt   
         ,  PACK.InnerPack 
         ,  LOTATTRIBUTE.Lottable01  
         ,  LOTATTRIBUTE.Lottable02  
         ,  LOTATTRIBUTE.Lottable03  
         ,  CASE WHEN LOTATTRIBUTE.Lottable04 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable04 END
         ,  CASE WHEN LOTATTRIBUTE.Lottable05 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable05 END 
         ,  LOC.LogicalLocation  
     ORDER BY LOADPLAN.LoadKey
         ,  LOC.LogicalLocation
         ,  PICKDETAIL.Loc  
         ,  PICKDETAIL.Sku 
         ,  LOTATTRIBUTE.Lottable01  
         ,  LOTATTRIBUTE.Lottable02  
         ,  LOTATTRIBUTE.Lottable03  
         ,  CASE WHEN LOTATTRIBUTE.Lottable04 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable04 END
         ,  CASE WHEN LOTATTRIBUTE.Lottable05 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable05 END  


   EXIT_SP:


   WHILE @@TRANCOUNT < @n_StartTranCnt
   BEGIN
      BEGIN TRAN
   END

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
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispConsoPickList34_1'    
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