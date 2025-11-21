SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nspConsoPickList15                        		   */
/* Creation Date: 2007-07-02                            			    		*/
/* Copyright: IDS                                                       */
/* Written by: NickYeo                                     			    	*/
/*                                                                      */
/* Purpose:  Consolidated Pickslip for IDSMY - AQRS							*/
/*                                                                      */
/* Input Parameters:  @c_loadkey  - Loadkey 										*/
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_consolidated_pick15_4       			*/
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver   Purposes                                  */
/* 13-Mar-2014  YTWan   1.1   SOS#305559 - Add AltSku to                */
/*                            r_dw_consolidated_pick15 report.(Wan01)   */
/* 18-Mar-2014  YTWan   1.1   SOS#305559 - Invisible Lottables & move   */
/*                            Altsku after SKu.(Wan02)                  */
/* 13-Apr-2014  TLTING  1.2   SQL2012                                   */
/* 02-JUN-2014  SPChin  1.3   SOS312876 - Avoid Duplicate Record        */
/************************************************************************/

-- TTL FBR93585 2007/12/21 - added lottable01, lottable03, lottable04, lottable05


CREATE PROC [dbo].[nspConsoPickList15] (
@c_LoadKey NVARCHAR(10)
)
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

	 DECLARE @c_FirstTime	  NVARCHAR(1),
			 	@c_PrintedFlag   NVARCHAR(1),
			 	@n_err           int,
	         @n_continue      int,
	         @c_PickHeaderKey NVARCHAR(10),
	         @b_success       int,
	         @c_errmsg        NVARCHAR(255),
	         @n_StartTranCnt  int
         ,  @n_ShowAltSku     INT         --(Wan01)
         ,  @c_Storerkey      NVARCHAR(15)--(Wan01)
         ,  @n_InvisibleLottables INT     --(Wan02)

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1
	-- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order

   SET @n_ShowAltSku = 0                  --(Wan01)
   SET @c_Storerkey  = ''                 --(Wan01)
   SET @n_InvisibleLottables = 0          --(Wan02)

   BEGIN TRAN

	SELECT @c_PickHeaderKey = ''
	SELECT @c_PickHeaderKey = PickHeaderKey
	FROM  PickHeader WITH (NOLOCK)
	WHERE ExternOrderKey = @c_LoadKey
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

	-- Uses PickType as a Printed Flag
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
            GOTO EXIT_SP
 	      END

	      IF @n_continue = 1 or @n_continue = 2
	      BEGIN
	         SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey
	         INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone, TrafficCop)
	                         VALUES (@c_PickHeaderKey, @c_LoadKey,      '0',  '7', '')
			END

			-- Do Auto Scan-in when only 1 storer found and configkey is setup
			IF @n_continue = 1 or @n_continue = 2
			BEGIN
				DECLARE @nCnt	int,
						  @cStorerKey NVARCHAR(15)

				IF ( SELECT COUNT(DISTINCT StorerKey) FROM ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)
					  WHERE LOADPLANDETAIL.OrderKey = ORDERS.OrderKey AND	LOADPLANDETAIL.LoadKey = @c_LoadKey ) = 1
				BEGIN
					-- Only 1 storer found
					SET @cStorerKey = ''
					SELECT @cStorerKey = (SELECT DISTINCT StorerKey
												 FROM   ORDERS WITH (NOLOCK), LOADPLANDETAIL WITH (NOLOCK)
												 WHERE  LOADPLANDETAIL.OrderKey = ORDERS.OrderKey
												 AND	  LOADPLANDETAIL.LoadKey = @c_LoadKey )

					IF EXISTS (SELECT 1 FROM STORERCONFIG WITH (NOLOCK) WHERE CONFIGKEY = 'AUTOSCANIN' AND
								  SValue = '1' AND StorerKey = @cStorerKey)
					BEGIN
						-- Configkey is setup
			         IF NOT Exists(SELECT 1 FROM PickingInfo WITH (NOLOCK) WHERE PickSlipNo = @c_PickHeaderKey)
			         BEGIN
			            INSERT INTO PickingInfo  (PickSlipNo, ScanInDate, PickerID, ScanOutDate)
			            VALUES (@c_PickHeaderKey, GetDate(), sUser_sName(), NULL)
				      END
					END -- Configkey is setup
				END -- Only 1 storer found
			END

		END  -- @c_FirstTime = 'Y'
	END -- IF @n_continue = 1 or @n_continue = 2

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
      --(Wan01) - START
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
      FROM LOADPLANDETAIL LPD WITH (NOLOCK)
      JOIN ORDERS         OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
      WHERE LPD.LoadKey = @c_LoadKey
      ORDER BY LPD.LoadLineNumber

      -- When @n_ShowAltSku turn on, @n_InvisibleLottables must turn on as well
      SELECT @n_ShowAltSku = ISNULL(MAX(CASE WHEN Code = 'ShowAltSku' THEN 1 ELSE 0 END),0)
            ,@n_InvisibleLottables = ISNULL(MAX(CASE WHEN Code = 'InvisibleLottables' THEN 1 ELSE 0 END),0) --(Wan02)
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'REPORTCFG'
      AND   Storerkey= @c_Storerkey
      AND   Long = 'r_dw_consolidated_pick15'
      AND   ISNULL(Short,'') <> 'N'
      --(Wan01) - END

		--SOS312876 Start
		IF ISNULL(@n_ShowAltSku, 0) = 0 AND ISNULL(@n_InvisibleLottables, 0 ) = 0
		BEGIN
	  		SELECT LoadPlanDetail.LoadKey,
	      	PICKHEADER.PickHeaderKey PickSlipNO,
	      	ISNULL(LoadPlan.Route, '') Route,
	      	LoadPlan.AddDate,
	      	PICKDETAIL.Loc,
	      	PICKDETAIL.Sku,
	      	PICKDETAIL.Qty,
	      	SKU.DESCR SKU_DESCR,
	      	PACK.CaseCnt,
	      	PACK.PackKey,
	      	ISNULL(LoadPlan.CarrierKey, '') CarrierKey,
	      	PICKDETAIL.ID AS Pallet_ID,
	      	LOTATTRIBUTE.Lottable01, -- TTL FBR93585 2007/12/21 - added
	      	LOTATTRIBUTE.Lottable02, -- TTL FBR93585 2007/12/21 - change label
	      	LOTATTRIBUTE.Lottable03, -- TTL FBR93585 2007/12/21 - added
	      	LOTATTRIBUTE.Lottable04, -- TTL FBR93585 2007/12/21 - added
	      	LOTATTRIBUTE.Lottable05  -- TTL FBR93585 2007/12/21 - added
      	,  @n_ShowAltSku            -- (Wan01)
      	,  SKU.ALTSku               -- (Wan01)
      	,  @n_InvisibleLottables    -- (Wan02)
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
	  		JOIN PICKHEADER WITH (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LoadPlan.LoadKey ) AND
	                        	( PICKHEADER.Zone = '7' )
	  		JOIN LOTATTRIBUTE WITH (NOLOCK) ON ( LOTATTRIBUTE.Lot = PICKDETAIL.Lot )
	  		WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )
		END
		ELSE
		BEGIN
			SELECT LoadPlanDetail.LoadKey,
		      PICKHEADER.PickHeaderKey AS PickSlipNO,
		      ISNULL(LoadPlan.Route, '') AS Route,
		      LoadPlan.AddDate,
		      PICKDETAIL.Loc,
		      PICKDETAIL.Sku,
		      SUM(PICKDETAIL.Qty) AS Qty,
		      SKU.DESCR AS SKU_DESCR,
		      PACK.CaseCnt,
		      PACK.PackKey,
		      ISNULL(LoadPlan.CarrierKey, '') CarrierKey,
		      MAX(PICKDETAIL.ID) AS Pallet_ID,
		      '',--LOTATTRIBUTE.Lottable01, -- TTL FBR93585 2007/12/21 - added
		      '',--LOTATTRIBUTE.Lottable02, -- TTL FBR93585 2007/12/21 - change label
		      '',--LOTATTRIBUTE.Lottable03, -- TTL FBR93585 2007/12/21 - added
		      GETDATE(),--LOTATTRIBUTE.Lottable04, -- TTL FBR93585 2007/12/21 - added
		      GETDATE() --LOTATTRIBUTE.Lottable05  -- TTL FBR93585 2007/12/21 - added
		   ,  @n_ShowAltSku            -- (Wan01)
		   ,  SKU.ALTSku               -- (Wan01)
		   ,  @n_InvisibleLottables    -- (Wan02)
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
		   JOIN PICKHEADER WITH (NOLOCK) ON ( PICKHEADER.ExternOrderKey = LoadPlan.LoadKey ) AND
		                        ( PICKHEADER.Zone = '7' )
		   --JOIN LOTATTRIBUTE WITH (NOLOCK) ON ( LOTATTRIBUTE.Lot = PICKDETAIL.Lot )
		   WHERE ( LoadPlanDetail.LoadKey = @c_LoadKey )
		   GROUP BY LoadPlanDetail.LoadKey,
		         PICKHEADER.PickHeaderKey,
		         ISNULL(LoadPlan.Route, '') ,
		         LoadPlan.AddDate,
		         PICKDETAIL.Loc,
		         PICKDETAIL.Sku,
		         SKU.DESCR,
		         PACK.CaseCnt,
		         PACK.PackKey,
		         ISNULL(LoadPlan.CarrierKey, ''),
		         SKU.ALTSku
		END
		--SOS312876 End
	END

   EXIT_SP:

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
     EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList15'
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