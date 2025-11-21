SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* SP: nspConsoPickList09                                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Consolidated Pickslip                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 22-Feb-2010  KC            SOS#161698 - Change Pickslip info (KC01)  */
/*                                                                      */
/************************************************************************/
CREATE PROC [dbo].[nspConsoPickList09] (
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
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList09)'
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
         SELECT @n_err = @@ERROR
         IF @n_err <> 0 
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 63501
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update PICKHEADER Failed. (nspConsoPickList09)'
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
		SELECT LoadPlanDetail.LoadKey,   
          PICKHEADER.PickHeaderKey,
			 PICKDETAIL.LOC,
          PICKDETAIL.SKU,
			 LA.Lottable02,  
          LA.Lottable04,
			 SUM(PICKDETAIL.Qty) Qty
      INTO #GRP
	   FROM LoadPlanDetail (NOLOCK)
          JOIN ORDERS (NOLOCK) ON (( LoadPlanDetail.OrderKey = ORDERS.OrderKey ))
          JOIN ORDERDETAIL (NOLOCK) ON (( ORDERS.OrderKey = ORDERDETAIL.OrderKey AND ORDERDETAIL.LoadKey = LoadPlanDetail.LoadKey ))
          JOIN PICKDETAIL (NOLOCK) ON (( ORDERS.OrderKey = PICKDETAIL.OrderKey ) and  
      									      ( ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber ))
          JOIN LoadPlan (NOLOCK) ON (LoadPlanDetail.LoadKey = LoadPlan.LoadKey )
          JOIN SKU  (NOLOCK) ON (( SKU.StorerKey = PICKDETAIL.Storerkey ) and  
                                 ( SKU.Sku = PICKDETAIL.Sku ))
          JOIN PICKHEADER (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LoadPlan.LoadKey )
          JOIN LOTAttribute LA (NOLOCK) ON (LA.LOT = PickDetail.LOT) 
			 JOIN SKUxLOC (NOLOCK) ON ((SKUxLOC.Storerkey = PICKDETAIL.Storerkey) AND
												(SKUxLOC.Sku = PICKDETAIL.Sku) AND
												(SKUxLOC.Loc = PICKDETAIL.Loc) )
      WHERE ( LoadPlan.LoadKey = @a_s_LoadKey ) 
      AND   ( PICKHEADER.Zone = '7' ) 
      --AND   (ORDERDETAIL.Lottable04 = '19000101' OR ORDERDETAIL.Lottable04 IS NULL) --(KC01)
		GROUP BY LoadPlanDetail.LoadKey, PICKHEADER.PickHeaderKey, PICKDETAIL.LOC, PICKDETAIL.SKU, LA.Lottable02, LA.Lottable04


      SELECT LoadPlanDetail.LoadKey,   
          PICKHEADER.PickHeaderKey,   
          LoadPlan.AddDate,   
          PICKDETAIL.Loc,   
          Loc.LogicalLocation,
          Loc.PutawayZone,
          PICKDETAIL.Sku,   
          PICKDETAIL.Qty,   
          SKU.DESCR,   
          PACK.CaseCnt,  
          PACK.PackUOM3,
          PACK.PackKey,
 			 LA.Lottable02, 
          CONVERT(VARCHAR(10),LA.Lottable04, 120) as lottable04, -- (KC01)
          @c_PrintedFlag as PrintFlag, 
          Loadplan.ExternLoadKey
/*
			 CASE WHEN ( SKU.SUSR3 = 'UTL' AND (SKUxLOC.LocationType <> 'CASE' AND  SKUxLOC.LocationType <> 'PICK') AND
							 LLI.Qty = #GRP.Qty )
					THEN  PICKDETAIL.SKU 
               ELSE  LOC.LogicalLocation
					END RecSort,
*/ -- (KC01)
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
			 JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
			 JOIN SKUxLOC (NOLOCK) ON ((SKUxLOC.Storerkey = PICKDETAIL.Storerkey) AND
												(SKUxLOC.Sku = PICKDETAIL.Sku) AND
												(SKUxLOC.Loc = PICKDETAIL.Loc) )
			 JOIN (SELECT LOTxLOCxID.Storerkey, LOTxLOCxID.SKu, LOTxLOCxID.Loc, SUM(Qty) Qty
                FROM LOTxLOCxID (NOLOCK)
                GROUP BY LOTxLOCxID.Storerkey, LOTxLOCxID.SKu, LOTxLOCxID.Loc) LLI 
										  ON ((LLI.Storerkey = PICKDETAIL.Storerkey) AND
												(LLI.Sku = PICKDETAIL.Sku) AND
												(LLI.Loc = PICKDETAIL.Loc) )
          JOIN #GRP
                ON (( #GRP.LoadKey 		= LoadPlanDetail.Loadkey ) AND
					      ( #GRP.Sku    	 	= PICKDETAIL.Sku ) AND
					      ( #GRP.Loc    	 	= PICKDETAIL.Loc ) AND
					      ( 1 					= CASE WHEN #GRP.Lottable04 IS NULL AND LA.Lottable04 IS NULL 
                                					 THEN 1
															 WHEN #GRP.Lottable04 IS  NOT NULL AND LA.Lottable04 IS NOT NULL AND
                                 				      #GRP.Lottable04 = LA.Lottable04
															 THEN 1
														    ELSE 0
															 END ) AND
					      ( #GRP.Lottable02 	= LA.Lottable02 ) )
      WHERE ( LoadPlan.LoadKey = @a_s_LoadKey ) 
      AND   ( PICKHEADER.Zone = '7' ) 
      --AND   (ORDERDETAIL.Lottable04 = '19000101' OR ORDERDETAIL.Lottable04 IS NULL) --(KC01)

		DROP TABLE #GRP
   END

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      execute nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList09'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
END /* main procedure */




GO