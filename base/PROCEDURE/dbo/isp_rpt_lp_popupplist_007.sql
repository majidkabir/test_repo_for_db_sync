SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_RPT_LP_POPUPPLIST_007                          */
/* Creation Date:03-MAY-2023                                            */
/* Copyright:LFL                                                        */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-22467-RG migrate pickslip report to logi                */
/*                                                                      */
/* Called By: RPT_LP_POPUPPLIST_007_1                                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 03-MAY-2023  CSCHONG  1.0  DevOps Combine Script                     */
/* 31-MAY-2023  CSCHONG  1.1  WMS-22467 add new field (CS01)            */
/* 31-Oct-2023  WLChooi  1.2  UWP-10213 - Global Timezone (GTZ01)       */
/************************************************************************/
CREATE   PROC [dbo].[isp_RPT_LP_POPUPPLIST_007]
(
   @c_LoadKey       NVARCHAR(10)
 , @c_PreGenRptData NVARCHAR(10) =''
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
         , @c_SpecialHandling NVARCHAR(1)
         , @c_PickDetailKey   NVARCHAR(18) 
         , @c_OrdLineNo       NVARCHAR(5)
         , @c_orderkey        NVARCHAR(10)

   SET @n_StartTranCnt=@@TRANCOUNT
   SET @n_continue = 1
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   BEGIN TRAN

   SELECT @c_PickHeaderKey = N''

   SELECT @c_PickHeaderKey = ISNULL(RTRIM(PickHeaderKey),'')
   FROM  PICKHEADER WITH (NOLOCK)
   WHERE ExternOrderKey = @c_LoadKey
   AND   Zone = '7'

   IF dbo.fnc_RTRIM(@c_PickHeaderKey) IS NOT NULL AND dbo.fnc_RTRIM(@c_PickHeaderKey) <> ''
   BEGIN
      SELECT @c_FirstTime = N'N'
      SELECT @c_PrintedFlag = N'Y'
   END
   ELSE
   BEGIN
      SELECT @c_FirstTime = N'Y'
      SELECT @c_PrintedFlag = N'N'
   END


   IF (@n_continue = 1 OR @n_continue = 2) AND @c_PreGenRptData = 'Y'
   BEGIN
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

      DECLARE C_PickDetailKey CURSOR FAST_FORWARD READ_ONLY FOR  
                     SELECT PickDetail.PickDetailKey, PickDetail.OrderLineNumber,Pickdetail.orderkey     
                     FROM LOADPLAN       WITH (NOLOCK)
                     JOIN PICKHEADER     WITH (NOLOCK) ON (LOADPLAN.Loadkey = PICKHEADER.ExternOrderKey )
                                     AND(PICKHEADER.Zone = '7' )
                    JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.Loadkey = LOADPLANDETAIL.Loadkey)
                    JOIN PICKDETAIL     WITH (NOLOCK) ON (LOADPLANDETAIL.OrderKey = PICKDETAIL.OrderKey)
                    WHERE LOADPLAN.LoadKey = @c_loadkey
                    ORDER BY PickDetail.PickDetailKey

         OPEN C_PickDetailKey  
     
         FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo ,@c_orderkey  
     
         WHILE @@FETCH_STATUS <> -1  
         BEGIN  
            IF NOT EXISTS (SELECT 1 FROM RefKeyLookup WITH (NOLOCK) WHERE PickDetailKey = @c_PickDetailKey) AND @c_PreGenRptData='Y'  
            BEGIN   
               INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)  
               VALUES (@c_PickDetailKey, @c_PickHeaderKey, @c_OrderKey, @c_OrdLineNo, @c_LoadKey)
         
               SELECT @n_err = @@ERROR  
               IF @n_err <> 0   
               BEGIN  
                  SELECT @n_continue = 3
                  SELECT @n_err = 63503
                   SELECT @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert RefKeyLookup Failed. (isp_RPT_LP_POPUPPLIST_007)'    
                  GOTO EXIT_SP
               END                          
            END   

     
            UPDATE PICKDETAIL WITH (ROWLOCK)      
            SET PickSlipNo = @c_PickHeaderKey     
              , EditWho = SUSER_NAME()    
              , EditDate= GETDATE()     
              , TrafficCop = NULL     
            FROM ORDERS     OH WITH (NOLOCK)    
            JOIN PICKDETAIL PD ON (OH.Orderkey = PD.Orderkey) 
            JOIN LOC L ON L.LOC = PD.Loc   
            WHERE PD.OrderKey = @c_OrderKey  
            AND   ISNULL(PickSlipNo,'') = ''  
            AND Pickdetailkey = @c_PickDetailKey AND OrderLineNumber=@c_OrdLineNo
     
            SET @n_err = @@ERROR      
       
            IF @n_err <> 0      
            BEGIN      
               SET @n_continue = 3      
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
               SET @n_err = 81009       
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Pickdetail Failed (isp_RPT_LP_POPUPPLIST_007)'   
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '   
               GOTO EXIT_SP     
            END  
         
         FETCH NEXT FROM C_PickDetailKey INTO @c_PickDetailKey, @c_OrdLineNo ,@c_orderkey  
         END   
         CLOSE C_PickDetailKey   
         DEALLOCATE C_PickDetailKey 
      

      -- Do Auto Scan-in when only 1 storer found and configkey is setup
      SET @c_Storerkey = ''

      SELECT @c_Storerkey = MIN(ORDERS.Storerkey),
             @c_SpecialHandling = MAX(ORDERS.SpecialHandling)
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
   END

   IF (@n_continue = 1 OR @n_continue = 2) AND ISNULL(@c_PreGenRptData,'') = ''
   BEGIN
      SELECT PickSlipNo = PICKHEADER.PickHeaderKey
          ,  PrintedFlag= @c_PrintedFlag
          ,  LOADPLAN.LoadKey
          ,  CarrierKey = ISNULL(RTRIM(LoadPlan.CarrierKey), '')
          ,  Route      = ISNULL(RTRIM(LoadPlan.Route), '')
          ,  [dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, LOADPLAN.Facility, LOADPLAN.AddDate) AS AddDate   --GTZ01
          ,  PICKDETAIL.Loc
          ,  PICKDETAIL.ID
          ,  PICKDETAIL.Sku
          ,  SKU_DESCR  = ISNULL(RTRIM(SKU.DESCR), '')
          ,  LOTATTRIBUTE.Lottable01
          ,  LOTATTRIBUTE.Lottable02
          ,  LOTATTRIBUTE.Lottable03
          ,  [dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, LOADPLAN.Facility, CASE WHEN LOTATTRIBUTE.Lottable04 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable04 END)   --GTZ01
          ,  [dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, LOADPLAN.Facility, CASE WHEN LOTATTRIBUTE.Lottable05 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable05 END)   --GTZ01
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
          ,SpecailHandling  = @c_SpecialHandling
          ,WaveID           = LOADPLAN.userdefine09    --CS01
          , [dbo].[fnc_ConvSFTimeZone](PICKDETAIL.Storerkey, LOADPLAN.Facility, GETDATE()) AS CurrentDateTime   --GTZ01
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
            ,  LOADPLAN.userdefine09    --CS01
            ,  PICKDETAIL.Storerkey   --GTZ01
            ,  LOADPLAN.Facility   --GTZ01
      ORDER BY LOADPLAN.LoadKey
            ,  LOC.LogicalLocation
            ,  PICKDETAIL.Loc
            ,  PICKDETAIL.Sku
            ,  LOTATTRIBUTE.Lottable01
            ,  LOTATTRIBUTE.Lottable02
            ,  LOTATTRIBUTE.Lottable03
            ,  CASE WHEN LOTATTRIBUTE.Lottable04 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable04 END
            ,  CASE WHEN LOTATTRIBUTE.Lottable05 = '19000101' THEN NULL ELSE LOTATTRIBUTE.Lottable05 END
   END

   EXIT_SP:

   IF @n_continue = 3
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_LP_POPUPPLIST_007'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
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
END

GO