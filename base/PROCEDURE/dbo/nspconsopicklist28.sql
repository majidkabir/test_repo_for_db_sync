SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspConsoPickList28                                 */
/* Creation Date: 18-MAR-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: GTGOH                                                    */
/*                                                                      */
/* Purpose: Consolidated Pickslip for IDSCN	- Carter (SOS#164712)      */
/*                                                                      */
/* Called By: r_dw_consolidated_pick28                                  */ 
/*                                                                      */
/* Parameters: (Input)  @c_loadKey   = Load Number                      */
/*                                                                      */
/* PVCS Version: 1.0	                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/************************************************************************/

CREATE PROCEDURE [dbo].[nspConsoPickList28]
   @c_LoadKey   NVARCHAR(10)
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

	SELECT @n_StartTranCnt=@@TRANCOUNT, @n_continue = 1
	
	DECLARE @n_TotalIntegrity INT
	, @n_TotalOrdered INT
	, @n_TotalAllocated INT

	DECLARE @tTempCheckIntegrity TABLE (
      SKU			 NVARCHAR(20) NULL,
      PDQTY				INT      NULL,
      BOMQTY			INT		NULL, -- (ChewKP01)
      ChkIntegrity	INT		NULL  -- (ChewKP01)
      )

	SET @n_TotalIntegrity = 0 -- (ChewKP01)

	CREATE TABLE #Temp_Pick  -- (ChewKP01)
   (   
      LoadKey          NVARCHAR(10) NULL,  
		Route            NVARCHAR(10) NULL,  
		AddDate			  DateTime NULL,
		OrderKey         NVARCHAR(10) NULL,
		OrderGroup		  NVARCHAR(20) NULL,
		Loc				  NVARCHAR(10) NULL,
		PDQTY				  int,  
		Putawayzone		  NVARCHAR(10) NULL,
		LogicalLocation  NVARCHAR(18) NULL,
		Lottable03		  NVARCHAR(18) NULL,
		Descr				  NVARCHAR(60) NULL,
		Casecnt			  int,
		UOM3				  NVARCHAR(10) NULL,
		BOMQty			  int,
		TotalQTYOrdered     int,
		TotalQTYAllocated	  int)

	DECLARE
		 @c_Route				 NVARCHAR(10) 
		,@d_AddDate				 DateTime 
		,@c_Loc					 NVARCHAR(10) 
		,@n_PDQTY				 int  
		,@c_Putawayzone		 NVARCHAR(10) 
		,@c_LogicalLocation	 NVARCHAR(18) 
		,@c_Lottable03			 NVARCHAR(18) 
		,@c_Descr				 NVARCHAR(60) 
		,@n_Casecnt				 int
		,@c_UOM3					 NVARCHAR(10) 
		,@n_BOMQty				 int
		,@c_storerkey			 NVARCHAR(15)
	
	 -- Create PickHeader (ChewKP01)
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
   	IF NOT EXISTS(SELECT PickHeaderKey 
   					    FROM PICKHEADER WITH (NOLOCK) 
   						WHERE ExternOrderKey = @c_LoadKey 
   						  AND  Zone = '7') 
   	BEGIN
   		SET @b_success = 0
   
   		EXECUTE nspg_GetKey
   			'PICKSLIP',
   			9,   
   			@c_PickHeaderKey     OUTPUT,
   			@b_success   	      OUTPUT,
   			@n_err 	            OUTPUT,
   			@c_errmsg    	      OUTPUT
   
   		IF @b_success <> 1
   		BEGIN
   			SET @n_continue = 3
   		END
   
   		IF @n_continue = 1 or @n_continue = 2
   		BEGIN
   			SET @c_PickHeaderKey = 'P' + @c_PickHeaderKey
   
   			INSERT INTO PICKHEADER (PickHeaderKey,  ExternOrderKey, PickType, Zone)
   			VALUES (@c_PickHeaderKey, @c_LoadKey, '1', '7')
             
   			SET @n_err = @@ERROR
   	
   			IF @n_err <> 0 
   			BEGIN
   				SET @n_continue = 3
   				SET @n_err = 63501
   				SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert Into PICKHEADER Failed. (nspConsoPickList28)'
   			END
   		END -- @n_continue = 1 or @n_continue = 2
   	END
      ELSE
      BEGIN
         SELECT @c_PickHeaderKey = PickHeaderKey
           FROM PickHeader WITH (NOLOCK)  
          WHERE ExternOrderKey = @c_LoadKey 
            AND Zone = '7'
      END
	END 
	
 	-- Uses PickType as a Printed Flag
	IF @n_continue = 1 or @n_continue = 2
	BEGIN
	      SELECT @b_success = 0
	      
         SELECT @b_success = 1 FROM PICKHEADER (NOLOCK)
			WHERE ExternOrderKey = @c_LoadKey

         IF @b_Success <> 1
         BEGIN
				SET @n_err			= 600001
            SET @c_errmsg     = 'PickSlip Not generate for ' + @c_LoadKey
				SELECT @n_continue = 3
				GOTO EXIT_SP 
			END

	      SELECT @b_success = 0
	      
         SELECT @b_success = 1 FROM LoadPlanDetail (NOLOCK)
			WHERE LoadKey = @c_LoadKey AND RTRIM(ISNULL(OrderKey,'')) <> ''

         IF @b_Success <> 1
         BEGIN
            SET @n_err			= 600002
            SET @c_errmsg     = 'Order Not exist in Load Plan for ' + @c_LoadKey
				SELECT @n_continue = 3
				GOTO EXIT_SP 
			END
		
			-- Validate PickDetail Quantity is integral multiple quantity in BOM
			IF @n_continue = 1 or @n_continue = 2
			BEGIN
				INSERT INTO @tTempCheckIntegrity		-- (ChewKP01) 
				SELECT  PICKDETAIL.SKU , PICKDETAIL.Qty , BILLOFMATERIAL.Qty ,  PICKDETAIL.Qty % BILLOFMATERIAL.Qty 
				FROM LoadPlan (NOLOCK)
				INNER JOIN LoadPlanDetail (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey)
				INNER JOIN ORDERS (NOLOCK) ON (LoadPlanDetail.Loadkey = ORDERS.Loadkey 
													AND LoadPlanDetail.Orderkey = ORDERS.Orderkey ) 
				INNER JOIN PICKDETAIL (NOLOCK) ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey)
--				INNER JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LoadPlan.LoadKey AND 
--															  PICKHEADER.OrderKey = PICKDETAIL.OrderKey)
				INNER JOIN LOC (NOLOCK) ON (PICKDETAIL.LOC = LOC.LOC)
				INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = PICKDETAIL.StorerKey AND SKU.SKU = PICKDETAIL.SKU)
				INNER JOIN PACK (NOLOCK) ON (SKU.PackKey = PACK.PackKey)
				INNER JOIN LOTATTRIBUTE (NOLOCK) ON (PICKDETAIL.LOT = LOTATTRIBUTE.LOT)
				INNER JOIN BILLOFMATERIAL (NOLOCK) ON (LOTATTRIBUTE.Lottable03 = BILLOFMATERIAL.SKU
														AND PICKDETAIL.SKU = BILLOFMATERIAL.ComponentSKU )
				WHERE LoadPlanDetail.LoadKey = @c_LoadKey 
	
			
				SELECT @n_TotalIntegrity = SUM(ChkIntegrity) FROM @tTempCheckIntegrity
	         
				
	         IF @n_TotalIntegrity > 0
				BEGIN
					SET @n_err			= 600003
            	SET @c_errmsg     = 'Quantity of component SKU in PickDetail is not integral ' 
					SELECT @n_continue = 3
					GOTO EXIT_SP 
				END

				  

		END				

	END -- IF @n_continue = 1 or @n_continue = 2

	IF @n_continue = 1 or @n_continue = 2
	BEGIN
		-- Re-write Logic for BOM Calculations -- (ChewKP01)
		SELECT @n_TotalOrdered = SUM(OD.OpenQty), 
		       @n_TotalAllocated = SUM(OD.QtyAllocated+OD.QtyPicked+OD.ShippedQty)
		FROM ORDERDETAIL OD (NOLOCK)
		INNER JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = OD.ORDERKEY 
		INNER JOIN LOADPLAN LP (NOLOCK) ON LP.Loadkey = ORDERS.Loadkey 
		WHERE LP.LoadKey = @c_LoadKey 

		DECLARE CUR_BOMQTY CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
		SELECT 
		LP.Loadkey, 
		ORDERS.Storerkey,
		LP.Route, 
		LP.AddDate, 
		PD.Loc, 
		SUM(PD.QTY), 
		LOC.PutawayZone, 
		LOC.LogicalLocation,
		LOTTA.Lottable03
		--SKU.DESCR
  		FROM LoadPlan LP (NOLOCK)
		INNER JOIN LoadPlanDetail LPD (NOLOCK) ON (LP.LoadKey = LPD.LoadKey)
		INNER JOIN ORDERS (NOLOCK) ON (ORDERS.Loadkey = LPD.Loadkey AND ORDERS.Orderkey = LPD.Orderkey) 
		INNER JOIN PICKDETAIL PD (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
		INNER JOIN LOC (NOLOCK) ON (PD.LOC = LOC.LOC)
		INNER JOIN SKU (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
		INNER JOIN LOTATTRIBUTE LOTTA (NOLOCK) ON (PD.LOT = LOTTA.LOT)
		WHERE LP.LoadKey = @c_LoadKey
		GROUP BY	LP.Loadkey, ORDERS.Storerkey, LP.Route, LP.AddDate, PD.Loc, LOC.PutawayZone, LOC.LogicalLocation,	LOTTA.Lottable03, SKU.DESCR
		
		OPEN CUR_BOMQTY
		FETCH NEXT FROM CUR_BOMQTY INTO  @c_Loadkey, @c_Storerkey , @c_Route ,@d_AddDate ,@c_Loc	,@n_PDQTY ,@c_Putawayzone ,@c_LogicalLocation 
												  ,@c_Lottable03 
		WHILE @@FETCH_STATUS <> - 1
		BEGIN
			   SET @c_Descr 	= ''
			   
			   SELECT @c_Descr = DESCR FROM SKU (NOLOCK)
			   WHERE SKU = @c_Lottable03
			   AND Storerkey = @c_Storerkey
			      
				SELECT @n_CaseCnt = 0

				SELECT @n_CaseCnt = PACK.CaseCnt
				FROM PACK WITH (NOLOCK)  
				INNER JOIN SKU WITH (NOLOCK) ON (SKU.PACKKEY = PACK.PACKKEY)
				WHERE  SKU.SKU = @c_Lottable03
				AND	 SKU.Storerkey = @c_Storerkey

				SET @n_BOMQty  = 0

				SELECT @n_BOMQty = SUM(BOM.QTY)
				FROM BillOfMaterial BOM WITH (NOLOCK)
				WHERE BOM.Storerkey = @c_Storerkey
				AND   BOM.SKU = @c_Lottable03

				
				INSERT INTO #TEMP_PICK ( LoadKey ,Route ,AddDate ,OrderKey ,OrderGroup ,Loc ,PDQTY ,Putawayzone ,LogicalLocation 
												,Lottable03 ,Descr ,Casecnt ,UOM3 ,BOMQty ,TotalQTYOrdered ,TotalQTYAllocated)   
				VALUES ( @c_Loadkey, @c_Route ,@d_AddDate, '' , ''  ,@c_Loc	,@n_PDQTY ,@c_Putawayzone ,@c_LogicalLocation ,@c_Lottable03 ,@c_Descr,
						 @n_CaseCnt, '', @n_BOMQty, @n_TotalOrdered, @n_TotalAllocated)
		

			FETCH NEXT FROM CUR_BOMQTY INTO  @c_Loadkey, @c_Storerkey, @c_Route ,@d_AddDate ,@c_Loc	,@n_PDQTY ,@c_Putawayzone ,@c_LogicalLocation
														,@c_Lottable03
		END

		/*DELETE FROM Temp_Pick_Conso
		
		Insert Into Temp_Pick_Conso
		Select * from #TEMP_PICK*/
		
		Select Loadkey, Route, AddDate, Loc , DESCR, PutawayZone, LogicalLocation, TotalQTYOrdered, TotalQTYAllocated,
				 ORDERGROUP, Lottable03,
				 (Sum (PDQTY) / BOMQty) / CaseCnt as Cartons , (Sum (PDQTY) / BOMQty) % CaseCnt as Eaches
		FROM	 #TEMP_PICK 
		GROUP BY Loadkey, Route, AddDate, Loc , DESCR, PutawayZone, LogicalLocation, TotalQTYOrdered, TotalQTYAllocated,
				   ORDERGROUP, Lottable03, CaseCnt, BOMQTY
		
		DROP Table #TEMP_PICK  

	END

   EXIT_SP:

   IF @n_continue=3  -- Error Occured - Process And Return    
   BEGIN    
     SELECT @b_success = 0    
--     EXECUTE nsp_logerror @n_err, @c_errmsg, 'nspConsoPickList28'    
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    
     RETURN    
   END    
   /* End Return Statement */ 

END /* main procedure */

GO