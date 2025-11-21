SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
CREATE PROC [dbo].[nspConsoPickList08] (
@a_s_LoadKey NVARCHAR(10)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @d_date_start	datetime,
             @d_date_end	datetime,
             @c_sku	 NVARCHAR(20),
             @c_storerkey NVARCHAR(15),
             @c_lot	 NVARCHAR(10),
             @c_uom	 NVARCHAR(10),
             @c_Route        NVARCHAR(10),
             @c_Exe_String   NVARCHAR(60),
             @n_Qty          int,
             @c_Pack         NVARCHAR(10),
             @n_CaseCnt      int

   DECLARE @c_CurrOrderKey  NVARCHAR(10),
          	@c_MBOLKey	 NVARCHAR(10),
            @c_FirstTime	 NVARCHAR(1),
            @c_PrintedFlag   NVARCHAR(1),
            @n_err           int,
            @n_continue      int,
            @c_PickHeaderKey NVARCHAR(10),
            @b_success       int,
            @c_errmsg        NVARCHAR(255),
            @n_StartTranCnt  int 

   SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

   /* Start Modification */
   -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

   SELECT @c_PickHeaderKey = ''
   SELECT @c_PickHeaderKey = PickHeaderKey 
   FROM PickHeader (NOLOCK) 
   WHERE ExternOrderKey = @a_s_LoadKey
   AND   Zone = '7'
   
   IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NOT NULL AND dbo.fnc_RTrim(@c_PickHeaderKey) <> '' 
   BEGIN
      SELECT @c_FirstTime = 'N'
      SELECT @c_PrintedFlag = 'Y'
   END
   ELSE
   BEGIN
      SELECT @c_FirstTime = 'Y'
      SELECT @c_PrintedFlag = 'N'
   END -- Record Not Exists

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      IF @c_FirstTime = 'Y'
      BEGIN
         SELECT @c_PickHeaderKey = SPACE(10)
         SELECT @b_success = 0
         EXECUTE nspg_GetKey
                'PICKSLIP',
                9,   
                @c_PickHeaderKey    OUTPUT,
                @b_success   	 OUTPUT,
                @n_err       	 OUTPUT,
                @c_errmsg    	 OUTPUT
         
         IF @b_success <> 1
         BEGIN
          SELECT @n_continue = 3
         END
         
         IF @n_continue = 1 or @n_continue = 2
         BEGIN
            SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

            BEGIN TRAN 
            INSERT INTO PICKHEADER
               (PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)
            VALUES
               (@c_PickHeaderKey, @a_s_LoadKey,     '0',      '7',  '')

            SELECT @n_err = @@ERROR
            IF @n_err <> 0 
            BEGIN
               SELECT @n_continue = 3
               SELECT @n_err = 63501
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList08)'
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
      END
   END -- IF @n_continue = 1 or @n_continue = 2

   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT LoadPlanDetail.LoadKey,   
          PICKHEADER.PickHeaderKey,   
          LoadPlan.Route,   
          LoadPlan.AddDate,   
          PICKDETAIL.Loc,   
          PICKDETAIL.Sku,   
          PICKDETAIL.Qty,   
          SKU.DESCR,   
          PACK.CaseCnt,  
          PACK.PackKey,
          LA.Lottable02,  
          LA.Lottable04,
          LoadPlan.CarrierKey,    -- Driver ID 
          LoadPlan.Driver,        -- Driver Name
          CAST(LoadPlan.Load_Userdef1 as NVARCHAR(60)), -- Driver Mobile Phone#
          LoadPlan.TruckSize, 
          Loadplan.Truck_Type, 
          Loadplan.TrfRoom, 
          Loadplan.lpuserdefdate01  -- ETA 
      FROM LoadPlanDetail (NOLOCK)
          JOIN ORDERS (NOLOCK) ON (( LoadPlanDetail.OrderKey = ORDERS.OrderKey ))
          JOIN ORDERDETAIL (NOLOCK) ON (( ORDERS.OrderKey = ORDERDETAIL.OrderKey AND ORDERDETAIL.LoadKey = LoadPlanDetail.LoadKey ))
          JOIN PICKDETAIL (NOLOCK) ON (( ORDERS.OrderKey = PICKDETAIL.OrderKey ) and  
            ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber ))
          JOIN LoadPlan (NOLOCK) ON (LoadPlanDetail.LoadKey = LoadPlan.LoadKey )
          JOIN SKU  (NOLOCK) ON (( SKU.StorerKey = PICKDETAIL.Storerkey ) and  
                                 ( SKU.Sku = PICKDETAIL.Sku ))
          JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PACKKey)
          JOIN PICKHEADER (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LoadPlan.LoadKey )
          JOIN LOTAttribute LA (NOLOCK) ON (LA.LOT = PickDetail.LOT) 
          LEFT OUTER JOIN (SELECT DISTINCT ORDERKEY FROM ORDERDETAIL (NOLOCK) WHERE LoadKey = @a_s_LoadKey AND
                (Lottable04 > '19000101' AND Lottable04 IS NOT NULL))  as NonCodeDate 
               ON (NonCodeDate.OrderKey = ORDERS.OrderKey)
      WHERE ( LoadPlan.LoadKey = @a_s_LoadKey ) 
      AND   ( PICKHEADER.Zone = '7' ) 
      AND   NonCodeDate.OrderKey IS NULL

   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      execute nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList08'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END /* main procedure */


GO