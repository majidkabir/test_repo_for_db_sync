SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure: nspConsoPickList23                                  */
/* Creation Date: 09-09-2009                                            */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: IDSCN Maxxium Consolidated PickSlip (print from LoadPlan)   */
/*          (refer to nspConsoPickList21)                               */
/* Input Parameters: @as_LoadKey - (LoadKey)                            */
/*                                                                      */
/* Called By: r_dw_consolidated_pick23_2                                */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 09-09-2009   James     Modified from nspConsoPickList21              */
/* 03-06-2010   Vanessa   SOS#174859 Add lottable01. -- (Vanessa01)     */
/* 15-Dec-2018  TLTING01  1.1   Missing nolock                          */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList23] (@as_LoadKey NVARCHAR(10) )
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE
		@n_starttrancnt  int, 
		@n_continue      int,
		@b_success       int,
		@n_err           int,
		@c_errmsg        NVARCHAR(255)

	DECLARE 
		@c_PrintedFlag   NVARCHAR(1),
		@c_PickHeaderKey NVARCHAR(10)

	SELECT @n_starttrancnt = @@TRANCOUNT, @n_continue = 1

   /********************************/
   /* Use Zone as a UOM Picked     */
   /* 1 = Pallet                   */
   /* 2 = Case                     */
   /* 6 = Each                     */
   /* 7 = Consolidated pick list   */
   /* 8 = By Order                 */
   /********************************/

   SELECT @c_PickHeaderKey = SPACE(10)

   IF NOT EXISTS (SELECT PickHeaderKey FROM PICKHEADER (NOLOCK) WHERE ExternOrderKey = @as_LoadKey AND Zone = '7') 
	BEGIN
		SELECT @c_PrintedFlag = 'N'
		
		SELECT @b_success = 0

		EXECUTE nspg_GetKey
			'PICKSLIP',
			9,   
			@c_PickHeaderKey  OUTPUT,
			@b_success   	   OUTPUT,
			@n_err       	   OUTPUT,
			@c_errmsg    	   OUTPUT

		IF @b_success <> 1
		BEGIN
			SELECT @n_continue = 3
		END

		IF @n_continue = 1 OR @n_continue = 2
		BEGIN
			SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

			INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
			VALUES (@c_PickHeaderKey, @as_LoadKey, '1', '7')
          
			SELECT @n_err = @@ERROR
	
			IF @n_err <> 0 
			BEGIN
				SELECT @n_continue = 3
				SELECT @n_err = 63501
				SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList23)'
			END
		END -- @n_continue = 1 or @n_continue = 2
	END
   ELSE
   BEGIN
      SELECT @c_PrintedFlag = 'Y'

      SELECT @c_PickHeaderKey = PickHeaderKey
      FROM  PICKHEADER (NOLOCK)  
      WHERE ExternOrderKey = @as_LoadKey 
       AND  Zone = '7'
   END

   IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NULL OR dbo.fnc_RTrim(@c_PickHeaderKey) = ''
   BEGIN
		SELECT @n_continue = 3
		SELECT @n_err = 63502
		SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Get LoadKey Failed. (nspConsoPickList23)'
   END

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		SELECT
         LoadPlan.LoadKey,   
			LoadPlan.Facility,
         LoadPlan.Route,
			LoadPlan.AddDate, 
			PickHeader.PickHeaderKey,  
			PickDetail.LOC,   
			PickDetail.SKU,   
			PickDetail.Qty,   
			SKU.DESCR,   
         ( SELECT SUM(OpenQty)
           FROM OrderDetail (NOLOCK)
           WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyOrdered, 
         ( SELECT SUM(QtyAllocated+QtyPicked+ShippedQty)
           FROM OrderDetail (NOLOCK)
           WHERE OrderDetail.Loadkey = LoadPlanDETAIL.LoadKey ) AS TotalQtyAllocated, 
         PACK.PackUOM3 As UOM,
         LOTATTRIBUTE.Lottable01, -- (Vanessa01)
         LOTATTRIBUTE.Lottable02, 
			PACK.Casecnt,
			SKU.BUSR4,
         Round((SKUxLOC.Qty-SKUxLOC.QtyPicked)/Pack.CaseCnt,0) AS Remain_Case,
         CAST((SKUxLOC.Qty-SKUxLOC.QtyPicked) AS INT) % CAST(Pack.CaseCnt AS INT) AS Remain_Loose
	   FROM LoadPlan (NOLOCK) 
      INNER JOIN LoadPlanDetail (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
      INNER JOIN Orders (NOLOCK) ON (LoadPlanDetail.OrderKey = ORDERS.OrderKey)
      INNER JOIN OrderDetail (NOLOCK) ON (Orders.OrderKey = OrderDetail.OrderKey AND OrderDetail.LoadKey = LoadPlanDetail.LoadKey) 
      INNER JOIN PickDetail (NOLOCK) ON (Orders.OrderKey = PickDetail.OrderKey AND OrderDetail.OrderLineNumber = PickDetail.OrderLineNumber)
		INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = PickDetail.Storerkey) AND (SKU.SKU = PickDetail.SKU)
		INNER JOIN PACK (NOLOCK) ON (PACK.PackKey = SKU.PackKey)    
      INNER JOIN PickHeader (NOLOCK)  ON (PickHeader.ExternOrderKey = LoadPlan.LoadKey)  --tlting01
		INNER JOIN LOT (NOLOCK) ON (PickDetail.LOT = LOT.LOT)
		INNER JOIN LOTATTRIBUTE (NOLOCK) ON (LOTATTRIBUTE.LOT = LOT.LOT)
		INNER JOIN LOC (NOLOCK) ON (LOC.LOC = PickDetail.LOC)
		INNER JOIN SKUxLOC (NOLOCK) ON (PickDetail.SKU = SKUxLOC.SKU AND PickDetail.LOC = SKUxLOC.LOC)
   	WHERE PickHeader.PickHeaderKey = @c_PickHeaderKey 
   	ORDER BY	Loc.LogicalLocation, Loc.Loc, Pickdetail.SKU, Lotattribute.Lottable04, Lotattribute.Lottable05, Lotattribute.Lottable02, Lotattribute.Lottable03
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
		EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList23'
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