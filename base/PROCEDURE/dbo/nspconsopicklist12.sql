SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nspConsoPickList12                                 */
/* Creation Date:  14-Apr-2006                                          */
/* Copyright: IDS                                                       */
/* Written by:  ONGGB                                                   */
/*                                                                      */
/* Purpose:  Johnson Diversey Consolidated Picked List From LoadPlan  	*/
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
/* Called By:  r_dw_consolidated_pick12_2                               */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Purposes                                        */
/* 2006-04-14   ONG		  Modify from nspConsoPickList06 (SOS48666)	   */
/* 2006-06-20   ONG01	  Add PrintFlag Indicator (SOS51561)				*/
/* 2010-04-21   GTGOH	  Replace Commodity with SKU.Style, SKU.Color   */
/*                      And SKU.Size if is not blank (GOH01)            */
/* 2014-04-18   NJOW01  310245-Configurable update pslip# to pickdetail */
/* 09-Nov-2015  SHONG01   1.6   Performance Tuning                      */ 
/* 02-Aug-2016  CSCHONG   1.7   Add new field (CS01)                    */
/* 15-Dec-2018  TLTING01  1.8   Missing nolock                          */
/************************************************************************/

CREATE PROC [dbo].[nspConsoPickList12] (@a_s_LoadKey NVARCHAR(10) )
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
		@n_StartTranCnt  int,
		@n_clkcnt        int, --NJOW01
		@c_newps         NCHAR(1), --NJOW01
		@c_showField     NCHAR(1)  --(CS01)

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

  SELECT @c_newps = 'N' --NJOW01

    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order
  SELECT @c_PickHeaderKey = SPACE(10)
	-- Initialize @c_PrintedFlag
	SELECT @c_PrintedFlag = 'N'			-- ONG01			TEMPORARILY Force to 'N ' so that NO REPRINT FLAG will be shown!

  SELECT @c_PickHeaderKey = PickHeaderKey
  FROM  PickHeader (NOLOCK)  
  WHERE ExternOrderKey = @a_s_LoadKey 
  AND  Zone = '7'
  
  --NJOW01
  SELECT TOP 1 @c_Storerkey = Storerkey
  FROM ORDERS (NOLOCK)
  WHERE Loadkey = @a_s_LoadKey
  
  SELECT @n_clkcnt = COUNT(*)    
  FROM Codelkup CLR (NOLOCK) 
  WHERE CLR.Storerkey = @c_Storerkey
  AND CLR.Code = 'UPDPICKSLIP2PICKDETAIL' 
  AND CLR.Listname = 'REPORTCFG' 
  AND CLR.Long = 'r_dw_consolidated_pick12'
  AND ISNULL(CLR.Short,'') <> 'N'
  
  /*CS01 Start*/
  SELECT @c_showField = CASE WHEN ISNULL(CLR1.Code,'') <> '' THEN 'Y' ELSE 'N' END
  FROM Codelkup CLR1 (NOLOCK) 
  WHERE CLR1.Storerkey = @c_Storerkey
  AND CLR1.Code = 'SHOWFIELD' 
  AND CLR1.Listname = 'REPORTCFG' 
  AND CLR1.Long = 'r_dw_consolidated_pick12'
  AND ISNULL(CLR1.Short,'') <> 'N'
  /*CS01 End*/
  
	/* Assign New Pick Slip No If it is first time printing */
   IF dbo.fnc_RTrim(@c_PickHeaderKey) = NULL OR dbo.fnc_RTrim(@c_PickHeaderKey) = ''
	BEGIN
		SELECT @c_PrintedFlag = 'N'
		
		SELECT @c_newps = 'Y' --NJOW01
		
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
				SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into PICKHEADER Failed. (nspConsoPickList12)"
			END
		END -- @n_continue = 1 or @n_continue = 2
	END

   IF dbo.fnc_RTrim(@c_PickHeaderKey) IS NULL OR dbo.fnc_RTrim(@c_PickHeaderKey) = ''
   BEGIN
		SELECT @n_continue = 3
		SELECT @n_err = 63501
		SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Get LoadKey Failed. (nspConsoPickList12)"
   END
  
  --NJOW01 
  IF @n_continue = 1 or @n_continue = 2
  BEGIN
  	 IF @n_clkcnt > 0 
  	 BEGIN
  	    UPDATE PICKDETAIL WITH (ROWLOCK)
  	    SET PICKDETAIL.Pickslipno = @c_PickHeaderKey,
  	        PICKDETAIL.TrafficCop = NULL,
  	        PICKDETAIL.EditWho = SUSER_SNAME(),
  	        PICKDETAIL.EditDate = GetDate()
  	    FROM PICKDETAIL 
  	    JOIN ORDERS (NOLOCK) ON PICKDETAIL.Orderkey = ORDERS.Orderkey
  	    WHERE ORDERS.Loadkey = @a_s_LoadKey
  	    AND ISNULL(Pickslipno,'') = CASE WHEN @c_newps = 'Y' THEN ISNULL(Pickslipno,'') ELSE '' END
  	 END
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
            
		SELECT Loadplan.Facility
			,Loadplan.Route
			,Loadplan.Loadkey
			,Pickheader.Pickheaderkey
			,Loadplan.AddDate
			,PICKDETAIL.Loc   
			,PICKDETAIL.Sku
			,LOTATTRIBUTE.Lottable01 
			,LOTATTRIBUTE.Lottable02 
			,LOTATTRIBUTE.Lottable03
			,SKU.DESCR
			,SKU.PackKey			
			,PICKDETAIL.Qty
			,AreaDetail.Areakey
			,Loc.LogicalLocation LogicalLoc
         ,@n_TotalQtyOrdered AS TotalQtyOrdered 
         ,@n_TotalQtyAllocated AS TotalQtyAllocated 
--			,( SELECT SUM(OpenQty)
--			  FROM ORDERDETAIL (NOLOCK)
--			  WHERE ORDERDETAIL.Loadkey = LOADPLANDETAIL.Loadkey ) AS TotalQtyOrdered
--			,( SELECT SUM(QtyAllocated)					
--			  FROM ORDERDETAIL (NOLOCK)
--			  WHERE ORDERDETAIL.Loadkey = LOADPLANDETAIL.Loadkey ) AS TotalQtyAllocated
			,( SELECT SUM(PD.Qty)
			  FROM PICKDETAIL PD(NOLOCK)
			  JOIN LoadPlanDetail LPD (NOLOCK) ON  PD.Orderkey = LPD.Orderkey 
			  JOIN LoadPlan LP (NOLOCK) ON LP.LoadKey = LPD.LoadKey 
			  JOIN Loc (NOLOCK) ON (PD.Loc = LOC.Loc)
			  JOIN AreaDetail AD (NOLOCK) ON (AD.PutawayZone = Loc.PutawayZone)
			  WHERE LP.Loadkey = Loadplan.Loadkey and 
			  AD.Areakey = AreaDetail.AreaKey ) AS TotalQtyArea
			 ,@c_PrintedFlag	PrintFlag								-- ONG01
			 ,(SELECT RTRIM(SK.Style) + '-' + RTRIM(SK.Color) + '-' + RTRIM(SK.Size) 
			   FROM SKU SK(NOLOCK)
				WHERE SK.StorerKey = PICKDETAIL.Storerkey and SK.Sku = PICKDETAIL.Sku
				AND SK.Style <> '' and SK.Color <> '' and SK.Size <> '' and SK.Size <> NULL) 
				AS StyCoSz,	--GOH01
				LOTATTRIBUTE.Lottable06,
				ISNULL(@c_showField,'N') AS ShowField				
	   FROM LOADPLAN (NOLOCK) 
      JOIN LoadPlanDetail (NOLOCK) ON ( LOADPLAN.LoadKey = LoadPlanDetail.LoadKey ) 
      JOIN PICKDETAIL (NOLOCK) ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey) 
		JOIN SKU  (NOLOCK) ON ( SKU.StorerKey = PICKDETAIL.Storerkey ) and (SKU.Sku = PICKDETAIL.Sku )
      JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)   --tlting01
		JOIN LOT (NOLOCK) ON (PICKDETAIL.LOT = LOT.LOT)
		JOIN LOTATTRIBUTE (NOLOCK) ON (LOTATTRIBUTE.LOT = LOT.LOT)
		JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
		JOIN AreaDetail (NOLOCK) ON (AreaDetail.PutawayZone = Loc.PutawayZone)
   	WHERE  PICKHeader.PickHeaderKey = @c_PickHeaderKey 
		ORDER BY Areadetail.AreaKey, Loc.LogicalLocation, Loc.Loc, Pickdetail.SKU, 			
					LOTATTRIBUTE.Lottable01, LOTATTRIBUTE.Lottable02, LOTATTRIBUTE.Lottable03
   END -- @n_continue = 1 or @n_continue = 2


	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		execute nsp_logerror @n_err, @c_errmsg, "nspConsoPickList12"
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