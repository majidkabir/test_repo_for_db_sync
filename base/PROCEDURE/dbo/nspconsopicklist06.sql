SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspConsoPickList06                                 */
/* Creation Date:  18-Apr-2003                                          */
/* Copyright: IDS                                                       */
/* Written by:  WANYT                                                   */
/*                                                                      */
/* Purpose:  FBR Nike Consolidated Picked List From Load Plan Module    */
/*                                                                      */
/* Input Parameters:  @a_s_LoadKey  - (LoadKey)                         */
/*                                                                      */
/* Output Parameters:  None                                             */
/*                                                                      */
/* Return Status:  None                                                 */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By:  r_dw_consolidated_pick06_2                               */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/*              SHONG     Review the script to minimize Table Blocking. */
/* 14-Jan-2004  SHONG     Duplicate Pickslip# Found for 1 Loadplan.     */
/*                        - (SOS#19209)                                 */
/* 05-May-2005  ONG       NSC Project Change Request - (SOS#35102).     */ 
/* 30-Nov-2005  MaryVong  SOS42812 Add LOTATTRIBUTE.Lottable02				*/
/* 07-Aug-2012  TLTING01  PB11 value not return fnc_RTRIM               */
/* 06-Nov-2015  Shong01   Performance Tuning                            */
/* 15-Dec-2018  TLTING01  1.3   Missing nolock                          */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList06] (@a_s_LoadKey NVARCHAR(10) )
 AS
 BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
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
   SELECT @c_PickHeaderKey = SPACE(10)

--    SELECT @c_PickHeaderKey = PickHeaderKey
--    FROM  PickHeader (NOLOCK)  
--    WHERE ExternOrderKey = @a_s_LoadKey 
--     AND  Zone = '7'

--	IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NULL OR dbo.fnc_RTrim(@c_PickHeaderKey) = '' 
   --tlting01
   IF NOT EXISTS(SELECT PickHeaderKey FROM  PickHeader (NOLOCK) WHERE ExternOrderKey = @a_s_LoadKey AND  Zone = '7') 
	BEGIN
		SELECT @c_PrintedFlag = 'N'
		
		SELECT @b_success = 0

		EXECUTE nspg_GetKey
			'PICKSLIP',
			9,   
			@c_PickHeaderKey    OUTPUT,
			@b_success   	 OUTPUT,
			@n_err 	 OUTPUT,
			@c_errmsg    	 OUTPUT

		IF @b_success <> 1
		BEGIN
			SELECT @n_continue = 3
		END

		IF @n_continue = 1 or @n_continue = 2
		BEGIN
			SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

			INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
			VALUES (@c_PickHeaderKey, @a_s_LoadKey, '1', '7')
          
			SELECT @n_err = @@ERROR
	
			IF @n_err <> 0 
			BEGIN
				SELECT @n_continue = 3
				SELECT @n_err = 63501
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into PICKHEADER Failed. (nspConsoPickList06)"
			END
		END -- @n_continue = 1 or @n_continue = 2
	END
   ELSE
   BEGIN
      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM  PickHeader (NOLOCK)  
      WHERE ExternOrderKey = @a_s_LoadKey 
       AND  Zone = '7'
   END

   IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NULL OR dbo.fnc_RTrim(@c_PickHeaderKey) = ''
   BEGIN
		SELECT @n_continue = 3
		SELECT @n_err = 63501
		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Get LoadKey Failed. (nspConsoPickList06)"
   END

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
            
		SELECT  LoadPlanDetail.LoadKey,   
			PICKHeader.PickHeaderKey,   
			LoadPlan.Route,   
			LoadPlan.AddDate,   
			PICKDETAIL.Loc,   
			PICKDETAIL.Sku,   
			PICKDETAIL.Qty,   
			SKU.DESCR,   
			PACK.CaseCnt,  
			PACK.PackKey,
         @n_TotalQtyOrdered AS TotalQtyOrdered, 
         @n_TotalQtyAllocated AS TotalQtyAllocated,
         Pack.PackUOM3 As UOM3, 
         LTRIM(RTRIM(ISNULL(SKU.PrePackIndicator,''))) As PrePackIndicator,      -- tlting01  PB11 value not return
         (SKU.PackQtyIndicator) As PackQtyIndicator, /* END added by Ong sos35102 050505 */
			LOTATTRIBUTE.Lottable02 -- SOS42812
	   FROM LOADPLAN (NOLOCK) 
      JOIN LoadPlanDetail (NOLOCK) ON ( LOADPLAN.LoadKey = LoadPlanDetail.LoadKey ) 
      JOIN PICKDETAIL (NOLOCK) ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey) 
		JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = PICKDETAIL.Storerkey ) and (SKU.Sku = PICKDETAIL.Sku )
		JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey )    
      JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)  --tlting01
		-- SOS42812
		JOIN LOT (NOLOCK) ON (PICKDETAIL.LOT = LOT.LOT)
		JOIN LOTATTRIBUTE (NOLOCK) ON (LOTATTRIBUTE.LOT = LOT.LOT)
   	WHERE  PICKHeader.PickHeaderKey = @c_PickHeaderKey 

   END -- @n_continue = 1 or @n_continue = 2


	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
-- 		SELECT @b_success = 0
-- 		IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
-- 		BEGIN
-- 			ROLLBACK TRAN
-- 		END
-- 		ELSE
-- 		BEGIN
-- 			WHILE @@TRANCOUNT > @n_StartTranCnt
-- 			BEGIN
-- 				COMMIT TRAN
-- 			END
-- 		END
		execute nsp_logerror @n_err, @c_errmsg, "nspConsoPickList06"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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