SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: ispConsoPickList32_1                                             */
/* Creation Date: 21_DEC-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Consolidated Pickslip                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By: r_dw_consolidated_pick32_1                                */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[ispConsoPickList32_1] (
@a_s_LoadKey   NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_date_start   DATETIME 
          ,@d_date_end     DATETIME 
          ,@c_sku          NVARCHAR(20) 
          ,@c_storerkey    NVARCHAR(15) 
          ,@c_lot          NVARCHAR(10) 
          ,@c_uom          NVARCHAR(10) 
          ,@c_Route        NVARCHAR(10) 
          ,@c_Exe_String   NVARCHAR(60) 
          ,@n_Qty          INT 
          ,@c_Pack         NVARCHAR(10) 
          ,@n_CaseCnt      INT

   DECLARE @c_CurrOrderKey    NVARCHAR(10)
          ,@c_MBOLKey         NVARCHAR(10)
          ,@c_FirstTime       NVARCHAR(1)
          ,@c_PrintedFlag     NVARCHAR(1)
          ,@n_err             INT
          ,@n_continue        INT
          ,@c_PickHeaderKey   NVARCHAR(10)
          ,@b_success         INT
          ,@c_errmsg          NVARCHAR(255)
          ,@n_StartTranCnt    INT 

   SET @n_StartTranCnt=@@TRANCOUNT
   SET @n_continue = 1

   /* Start Modification */
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

   SELECT @c_PickHeaderKey = ''
   SELECT @c_PickHeaderKey = PickHeaderKey 
   FROM PickHeader (NOLOCK) 
   WHERE ExternOrderKey = @a_s_LoadKey
   AND   Zone = '7'
   
   IF RTRIM(@c_PickHeaderKey) IS NOT NULL AND RTRIM(@c_PickHeaderKey) <> '' 
   BEGIN
      SET @c_FirstTime = 'N'
      SET @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SET @c_FirstTime = 'Y'
      SET @c_PrintedFlag = 'N'
   END -- Record Not Exists

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_FirstTime = 'Y'
      BEGIN
         SET @c_PickHeaderKey = SPACE(10)
         SET @b_success = 0
         EXECUTE nspg_GetKey
                'PICKSLIP',
                9,   
                @c_PickHeaderKey    OUTPUT,
                @b_success     OUTPUT,
                @n_err         OUTPUT,
                @c_errmsg      OUTPUT
         
         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3
         END
         
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey

            BEGIN TRAN 
            INSERT INTO PICKHEADER
               (PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES
               (@c_PickHeaderKey, @a_s_LoadKey,     '0',      '7',  '')

            SET @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SET @n_continue = 3
               SET @n_err = 63501
               SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (ispConsoPickList32_1)'
               ROLLBACK TRAN 
            END
            ELSE
            BEGIN
               COMMIT TRAN  
            END 
         END
      END
      ELSE
      BEGIN
         SELECT @c_PickHeaderKey = PickHeaderKey 
         FROM PickHeader (NOLOCK) 
         WHERE ExternOrderKey = @a_s_LoadKey
         AND   Zone = '7'

         BEGIN TRAN 

         UPDATE PickHeader
            SET PickType = 'Y'
         WHERE ExternOrderKey = @a_s_LoadKey
         AND   Zone = '7'
 
         SET @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SET @n_continue = 3
            SET @n_err = 63501
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PICKHEADER Failed. (ispConsoPickList32_1)'
            ROLLBACK TRAN 
         END
         ELSE
         BEGIN
            COMMIT TRAN  
         END 

      END
   END -- IF @n_continue = 1 or @n_continue = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT LoadKey        = ISNULL(RTRIM(LOADPLANDETAIL.LoadKey),'') 
          , PickHeaderKey   = ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')    
          , AddDate         = LOADPLAN.AddDate       
          , Loc             = ISNULL(RTRIM(PICKDETAIL.Loc),'')    
          , LogicalLocation = ISNULL(RTRIM(LOC.LogicalLocation),'')  
          , PutawayZone     = ISNULL(RTRIM(LOC.PutawayZone),'')  
          , Sku             = ISNULL(RTRIM(PICKDETAIL.Sku),'')    
          , DESCR           = ISNULL(RTRIM(SKU.DESCR),'')   
          , QtyPick         = SUM(PICKDETAIL.Qty)   
          , CaseCnt         = ISNULL(PACK.CaseCnt,0)   
          , InnerPack       = ISNULL(PACK.InnerPack,0)  
          , PackUOM3        = ISNULL(RTRIM(PACK.PackUOM3),'')  
          , PackKey         = ISNULL(RTRIM(PACK.PackKey),'')  
          , Lottable02      = ISNULL(RTRIM(LA.Lottable02),'')  
          , Lottable04      = CASE WHEN CONVERT(VARCHAR(8),LA.LOTTABLE04,112) = '19000101' THEN NULL ELSE LA.LOTTABLE04 END
          , PrintFlag       = @c_PrintedFlag 
          , ExternLoadKey   = ISNULL(RTRIM(LOADPLAN.ExternLoadKey),'') 
      FROM LOADPLAN        WITH (NOLOCK)
      JOIN LOADPLANDETAIL  WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey)
      JOIN ORDERS          WITH (NOLOCK) ON (LOADPLANDETAIL.OrderKey = ORDERS.OrderKey)
      JOIN PICKDETAIL      WITH (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey) 
      JOIN SKU             WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.Storerkey)   
                                         AND(PICKDETAIL.Sku = SKU.Sku ) 
      JOIN PACK            WITH (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
      JOIN PICKHEADER      WITH (NOLOCK) ON (PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey )
      JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON (PICKDETAIL.LOT = LA.LOT) 
      JOIN LOC             WITH (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
      WHERE ( LOADPLAN.LoadKey = @a_s_LoadKey ) 
      AND   ( PICKHEADER.Zone = '7' ) 
      GROUP BY ISNULL(RTRIM(LOADPLANDETAIL.LoadKey),'') 
             , ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')    
             , LOADPLAN.AddDate       
             , ISNULL(RTRIM(PICKDETAIL.Loc),'')    
             , ISNULL(RTRIM(LOC.LogicalLocation),'')  
             , ISNULL(RTRIM(LOC.PutawayZone),'')  
             , ISNULL(RTRIM(PICKDETAIL.Sku),'')    
             , ISNULL(RTRIM(SKU.DESCR),'')   
             , ISNULL(PACK.CaseCnt,0)   
             , ISNULL(PACK.InnerPack,0)  
             , ISNULL(RTRIM(PACK.PackUOM3),'')  
             , ISNULL(RTRIM(PACK.PackKey),'')  
             , ISNULL(RTRIM(LA.Lottable02),'')  
             , CASE WHEN CONVERT(VARCHAR(8),LA.LOTTABLE04,112) = '19000101' THEN NULL ELSE LA.LOTTABLE04 END
             , ISNULL(RTRIM(LOADPLAN.ExternLoadKey),'') 
      ORDER BY ISNULL(RTRIM(PICKHEADER.PickHeaderKey),'')    
             , ISNULL(RTRIM(LoadPlanDetail.LoadKey),'')
             , ISNULL(RTRIM(LOC.PutawayZone),'') 
             , ISNULL(RTRIM(LOC.LogicalLocation),'') 
             , ISNULL(RTRIM(PICKDETAIL.Loc),'') 
             , ISNULL(RTRIM(PICKDETAIL.Sku),'') 
             , ISNULL(RTRIM(LA.Lottable02),'')  
             , CASE WHEN CONVERT(VARCHAR(8),LA.LOTTABLE04,112) = '19000101' THEN NULL ELSE LA.LOTTABLE04 END  
      
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      execute nsp_logerror @n_err, @c_errmsg, 'ispConsoPickList32_1'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END /* main procedure */


GO