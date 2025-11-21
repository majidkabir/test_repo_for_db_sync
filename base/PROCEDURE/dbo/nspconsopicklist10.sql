SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure nspConsoPickList10 : 
--

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- 

/************************************************************************/
/* Store Procedure:  nspConsoPickList10                                 */
/* Creation Date:  03-Jan-2007                                          */
/* Copyright: IDS                                                       */
/* Written by:  James                                                   */
/*                                                                      */
/* Purpose:  FBR PBCN Consolidated Picked List From Load Plan Module    */
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
/* Called By:  r_dw_consolidated_pick10                                 */
/*                                                                      */
/* PVCS Version: 1.4                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 03-Jan-2007  James     Created                                       */
/* 07-Aug-2012  TLTING01  PB11 value not return fnc_RTRIM               */
/* 15-Dec-2018  TLTING01  1.1   Missing nolock                          */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList10] (@a_s_LoadKey NVARCHAR(10) )
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

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
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
         ( SELECT SUM(OpenQty)
           FROM ORDERDETAIL (NOLOCK)
           WHERE ORDERDETAIL.Loadkey = LOADPLANDETAIL.LoadKey ) AS TotalQtyOrdered, 
         ( SELECT SUM(QtyAllocated+QtyPicked+ShippedQty)
           FROM ORDERDETAIL (NOLOCK)
           WHERE ORDERDETAIL.Loadkey = LOADPLANDETAIL.LoadKey ) AS TotalQtyAllocated, 
         Pack.PackUOM3 As UOM3, 
         LTRIM(RTRIM(SKU.PrePackIndicator)) As PrePackIndicator, 
         (SKU.PackQtyIndicator) As PackQtyIndicator, 
         LOC.LogicalLocation,
         LOC.PutawayZone  
	   FROM LOADPLAN (NOLOCK) 
      JOIN LoadPlanDetail (NOLOCK) ON ( LOADPLAN.LoadKey = LoadPlanDetail.LoadKey ) 
      JOIN PICKDETAIL (NOLOCK) ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey) 
		JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = PICKDETAIL.Storerkey ) and (SKU.Sku = PICKDETAIL.Sku )
		JOIN PACK (NOLOCK) ON ( PACK.PackKey = SKU.PACKKey )    
      JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)  --tlting01
      JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
   	WHERE  PICKHeader.ExternOrderKey = @a_s_LoadKey 
      AND ZONE = '7'

   END -- @n_continue = 1 or @n_continue = 2


	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		execute nsp_logerror @n_err, @c_errmsg, "nspConsoPickList10"
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