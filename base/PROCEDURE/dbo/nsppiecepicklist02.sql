SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

CREATE PROC [dbo].[nspPiecePickList02] (@c_facility		 NVARCHAR(5)
,										@c_LoadKeyStart NVARCHAR(10)
,										@c_LoadKeyEnd	 NVARCHAR(10)	 )
 AS
 BEGIN
	/*******************************************************************************/
   /* 17-Aug-2004 YTWan FBR Pieces Picking Slip By Load									 */
   /*******************************************************************************/
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
	
	DECLARE 	@c_LoadKey  	  NVARCHAR(10),
				@c_PickHeaderKey NVARCHAR(10),
				@n_row           int,
				@n_err           int,
				@n_continue      int,
				@b_success       int,
				@c_errmsg        NVARCHAR(255),
				@n_StartTranCnt  int 

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1

 /* Start Modification */
    -- Use Zone as a UOM Picked 1 - Pallet, 2 - Case, 6 - Each, 7 - Consolidated pick list , 8 - By Order
	
	SELECT @c_LoadKey = ''
	WHILE 1=1 AND @n_continue = 1
   BEGIN

		SELECT @c_LoadKey = MIN(LP.LoadKey)
      FROM	 LOADPLAN LP(NOLOCK), LOADPLANDETAIL LPD(NOLOCK), PICKDETAIL PD(NOLOCK), SKUxLOC SL (NOLOCK)
      WHERE  LPD.Loadkey 		= LP.Loadkey
  		AND 	 PD.Orderkey 		= LPD.Orderkey
		AND  	 PD.Status   		< '5'
		AND    PD.Storerkey		= SL.Storerkey
		AND    PD.Sku		 		= SL.Sku
		AND    PD.Loc 		 		= SL.Loc
		AND    SL.Locationtype 	= 'PICK'
      AND	 LP.Facility 		= @c_facility
      AND    LP.Loadkey  		>= @c_loadkeystart
		AND    LP.Loadkey  		<= @c_loadkeyend
		AND    LP.Loadkey			> @c_LoadKey
      AND    PD.Qty > 0

		IF ISNULL(@c_LoadKey,'') = '' 
			BREAK

		SELECT @c_PickHeaderKey = ''

      IF NOT EXISTS(SELECT 1 FROM  PickHeader (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND Zone = '7') 
		BEGIN
			
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
	
				INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, Zone)
				VALUES (@c_PickHeaderKey, @c_LoadKey, '7')
	          
				SELECT @n_err = @@ERROR
		
				IF @n_err <> 0 
				BEGIN
					SELECT @n_continue = 3
					SELECT @n_err = 63501
					SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Into PICKHEADER Failed. (nspPiecePickList02)"
				END
			END -- @n_continue = 1 or @n_continue = 2

		END
	END 

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		SELECT  LOADPLAN.LoadKey,   
					PICKHeader.PickHeaderKey,   
					LoadPlan.Route,   
					LoadPlan.AddDate,
					OD.TotalQtyOrdered,
					SUM(ISNULL(PICKDETAIL.Qty,0)) TotalQtyInPick,
				   PD.TotalQtyInBulk 
		FROM LOADPLAN (NOLOCK) 
      JOIN LOADPLANDETAIL 	(NOLOCK) ON ( LOADPLANDETAIL.LoadKey = LOADPLAN.LoadKey ) 
	   JOIN PICKDETAIL 		(NOLOCK) ON ( PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey ) 
		JOIN SKUxLOC	  		(NOLOCK)	ON ( PICKDETAIL.Storerkey = SKUxLOC.StorerKey ) and 
                                       ( PICKDETAIL.Sku = SKUxLOC.Sku ) and
													( PICKDETAIL.Loc = SKUxLOC.Loc ) 
   	JOIN PICKHEADER 		(NOLOCK)	ON ( PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey) 
      JOIN ( SELECT Loadkey, SUM(ISNULL(OpenQty,0)) TotalQtyOrdered
					  FROM ORDERDETAIL (NOLOCK)
					  GROUP BY Loadkey ) OD  ON (OD.LoadKey = LOADPLAN.Loadkey)
      LEFT OUTER JOIN ( SELECT Loadkey, SUM(ISNULL(PICKDETAIL.Qty,0)) TotalQtyInBulk
								  FROM LOADPLANDETAIL (NOLOCK), PICKDETAIL (NOLOCK), SKUxLOC (NOLOCK)
								  WHERE PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey
								  AND PICKDETAIL.Storerkey = SKUxLOC.Storerkey 
								  AND PICKDETAIL.Sku = SKUxLOC.Sku
								  AND PICKDETAIL.Loc = SKUxLOC.Loc  
								  AND SKUxLOC.LocationType <> 'PICK' AND SKUxLOC.LocationType <> 'CASE' 
                          GROUP BY Loadkey ) PD
                                       ON (PD.Loadkey = LOADPLAN.Loadkey)
		WHERE LOADPLAN.Facility 	= @c_facility
      AND   LOADPLAN.LoadKey 		>= @c_loadkeystart
		AND   LOADPLAN.LoadKey 		<= @c_loadkeyend
		AND   SKUxLOC.LocationType = 'PICK'
		AND   PICKDETAIL.STATUS < '5'
		AND   PICKHeader.Zone = '7'
   	GROUP BY	LOADPLAN.LoadKey,   
					PICKHeader.PickHeaderKey,   
					LoadPlan.Route,   
					LoadPlan.AddDate,
					OD.TotalQtyOrdered,
					PD.TotalQtyInBulk 
		ORDER BY LOADPLAN.LoadKey, PICKHeader.PickHeaderKey  

   END -- @n_continue = 1 or @n_continue = 2


	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
   	execute nsp_logerror @n_err, @c_errmsg, "nspPiecePickList02"
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