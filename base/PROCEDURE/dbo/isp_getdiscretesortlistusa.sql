SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_GetDiscreteSortListUSA                         */
/* Creation Date: 29-Sept-2007                                          */
/* Copyright: IDS                                                       */
/* Written by: June	                                                   */
/*                                                                      */
/* Purpose:  SOS#87477 - Discrete Sort List for IDSUS.            		*/
/*                                                                      */
/* Called By:  PB - r_dw_consolidated_pick16_sortlist                   */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 08-Oct-2007  Vicky     SOS#84285 - Adjust the Pickslip Qty Position  */
/* 15-Jul-2010  KHLim     Replace USER_NAME to sUSER_sName              */ 
/* 20-Jul-2010  KHLim     Synronize version of PVCS to US Live DB(KHLim1)*/ 
/************************************************************************/

CREATE PROC [dbo].[isp_GetDiscreteSortListUSA] ( 
            @c_LoadKey  NVARCHAR(10)
           ,@b_debug  NVARCHAR(1) = '')
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
	

	DECLARE 	@n_continue int,
				@c_errmsg NVARCHAR(255),
				@b_success int,
				@n_err int,
				@c_Pickslipno NVARCHAR(10),
				@c_OrderKey NVARCHAR(10),
				@c_StorerKey NVARCHAR(15),
				@n_OriginalQty int,
				@n_AllocatedQty int,
				@c_AltSku NVARCHAR(20),
				@c_CartonGroup  NVARCHAR(10),
			   @c_PrintedFlag NVARCHAR(1),
				@f_Pallet float,
				@f_Casecnt float,
				@f_OtherUnit1 float,
				@f_InnerPack float
			  ,@c_Putawayzone NVARCHAR(10)
			  ,@c_Loc NVARCHAR(10)
			  ,@c_Style NVARCHAR(20)
			  ,@c_Color NVARCHAR(10)
			  ,@c_Size  NVARCHAR(5)
			  ,@c_Measurement NVARCHAR(5)
			  ,@c_Busr1 NVARCHAR(18)
			  ,@c_Lottable01 NVARCHAR(18)
			  ,@c_Lottable02 NVARCHAR(18)
			  ,@c_Lottable03 NVARCHAR(18)
			  ,@c_LogicalLoc NVARCHAR(18)
			  ,@n_Qty   int
			  ,@n_EAQty  int
			  ,@n_UOMQty int
			  ,@n_BOMQty int
			  ,@n_RemainQty int
			  ,@n_NoOfUnits int
			  ,@n_PPK_Per   int
			  ,@n_UOMLevel  int
			  ,@n_SUMCompQty int
			  ,@n_TotalEAQty int
			  ,@n_TotalUOMQty int
			  ,@n_TotalPPKQty int
			  ,@c_UOM 		 NVARCHAR(10)
			  ,@c_PPK_per   NVARCHAR(30)					
			  ,@c_PrevPickslip NVARCHAR(10)			
			  ,@c_PrevOrder NVARCHAR(10)
			  ,@c_PrevStorer NVARCHAR(15)
			  ,@c_PrevLoc NVARCHAR(10)
			  ,@c_PrevZone NVARCHAR(10)
			  ,@c_PrevStyle NVARCHAR(20)
			  ,@c_PrevPPKInd NVARCHAR(30)
			  ,@c_PrevCompColor NVARCHAR(10)
			  ,@c_PrevCartonGroup NVARCHAR(10)
			  ,@c_PrevPrintedflag NVARCHAR(1)
			  ,@n_PrevAllocatedQty int
			  ,@n_PrevOriginalQty int
			  ,@c_CompSku NVARCHAR(20)
			  ,@c_CompColor NVARCHAR(10)
			  ,@c_CompSize  NVARCHAR(5)
			  ,@n_CompQty   int
			  ,@c_CompFind  NVARCHAR(100)
			  ,@c_DispSize NVARCHAR(80)
			  ,@c_DispQty  NVARCHAR(80)
			  ,@b_Repeat  NVARCHAR(1)
			  ,@b_LastRec NVARCHAR(1)
			  ,@c_ErrFlag NVARCHAR(2)
			  ,@c_LineText NVARCHAR(150)
				,@c_DataWindow NVARCHAR(50)
			  ,@c_TargetDB NVARCHAR(10)
			  ,@c_Printer  NVARCHAR(10)
			  
	CREATE TABLE #TempDiscSortList
				( 	RowId int IDENTITY (1, 1) NOT NULL,
					PickSlipNo NVARCHAR(10) NULL,
					LoadKey NVARCHAR(10),
					OrderKey NVARCHAR(10),
					StorerKey NVARCHAR(15),
 					PrintedFlag NVARCHAR(1) NULL,
 					AltSku NVARCHAR(20) NULL,
 					CartonGroup NVARCHAR(10) NULL,
					SKU NVARCHAR(20),
					Style NVARCHAR(20) NULL,
					Color NVARCHAR(10) NULL,
					Busr1 NVARCHAR(30) NULL,
					Measurement NVARCHAR(5) NULL,
					Size NVARCHAR(5) NULL,
					Putawayzone NVARCHAR(10), 
					LogicalLoc NVARCHAR(18), 
					Loc NVARCHAR(10),
					Qty int NULL,
					Lottable01 NVARCHAR(18) NULL,
					Lottable02 NVARCHAR(18) NULL,
					Lottable03 NVARCHAR(18) NULL,
					Lottable05 datetime NULL,
					TotalAllocateQty int NULL,
					TotalOrderQty int NULL,
					ErrFlag  NVARCHAR(2) NULL
				)

  DECLARE @t_DiscSortList TABLE 
			( 	RowId int IDENTITY (1, 1) NOT NULL,
				PickSlipNo NVARCHAR(10),
				LoadKey NVARCHAR(10),
				Orderkey NVARCHAR(10), 
				PrintedFlag NVARCHAR(1) NULL,
				StorerKey NVARCHAR(15),
				Putawayzone NVARCHAR(10), 
				TotalAllocateQty int NULL,
				TotalOrderQty int NULL,
				LineText NVARCHAR(150) NULL,
				LineFlag NVARCHAR(2) 
			 )	

	SELECT @n_continue = 1 

	BEGIN TRAN

	-- Create #TempDiscSortList Table
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		INSERT INTO #TempDiscSortList 
					(  Pickslipno,
						LoadKey,
						OrderKey,
						StorerKey,
						PrintedFlag,
						AltSku,
						CartonGroup,
						SKU,
						Style,
						Color,
						Busr1,
						Measurement,
						Size,
						Putawayzone,
						LogicalLoc, 
						Loc,
						Qty,
						Lottable01,
						Lottable02,
						Lottable03,
						Lottable05,
					   ErrFlag )
		SELECT PICKDETAIL.Pickslipno, 
			   ORDERS.Loadkey,
				ORDERS.OrderKey, 
				ORDERS.StorerKey, 
			   '',  -- PrintedFlag : Can't tell is a REPRINT OR NOT. P/S already produced when Conso is printed.
				PICKDETAIL.AltSku,
				PICKDETAIL.CartonGroup, 
				SKU.SKU,
				SKU.Style,
				SKU.Color,
				SKU.Busr1,
				SKU.Measurement,
				SKU.Size,
				LOC.Putawayzone, 
				LOC.LogicalLocation, 
				PICKDETAIL.Loc,
				SUM(PICKDETAIL.Qty) Qty,
				LOTTABLE01 = MIN(LOTATTRIBUTE.LOTTABLE01), 
				LOTTABLE02 = MIN(LOTATTRIBUTE.LOTTABLE02), 
				LOTATTRIBUTE.LOTTABLE03,
				LOTTABLE05 = MIN(LOTATTRIBUTE.LOTTABLE05), 
				'' -- ErrFlag
		FROM ORDERS WITH (NOLOCK) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY)
      JOIN PICKDETAIL WITH (NOLOCK) ON  (ORDERS.OrderKey = PICKDETAIL.OrderKey AND 
                                         ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
      JOIN STORER WITH (NOLOCK) ON (PICKDETAIL.StorerKey = STORER.StorerKey)
      JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.SKU = SKU.SKU)				
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot AND 
                                          SKU.SKU = LOTATTRIBUTE.SKU AND 
                                          SKU.StorerKey = LOTATTRIBUTE.StorerKey)
      JOIN LOADPLAN WITH (NOLOCK) ON (ORDERS.LoadKey = LOADPLAN.LoadKey)
      JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey AND 
                                            LOADPLANDETAIL.Orderkey = ORDERS.OrderKey)
		JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) 
		WHERE PICKDETAIL.Status < '9' -- KHLim1
		AND   LOADPLANDETAIL.LoadKey = @c_LoadKey
		AND   PICKDETAIL.CartonGroup = 'PREPACK'
		GROUP BY PICKDETAIL.Pickslipno, ORDERS.Loadkey, ORDERS.OrderKey, ORDERS.StorerKey, 
					PICKDETAIL.AltSku, PICKDETAIL.CartonGroup, SKU.SKU, SKU.Style, SKU.Color, SKU.Busr1,
					SKU.Measurement, SKU.Size, LOC.Putawayzone, LOC.LogicalLocation, PICKDETAIL.Loc,
					LOTATTRIBUTE.LOTTABLE03 
		UNION
		SELECT PICKDETAIL.Pickslipno, 
			   ORDERS.Loadkey,
				ORDERS.OrderKey, 
				ORDERS.StorerKey, 
			   '',  -- PrintedFlag : Can't tell is a REPRINT OR NOT. P/S already produced when Conso is printed.
				PICKDETAIL.AltSku,
				PICKDETAIL.CartonGroup, 
				SKU.SKU,
				SKU.Style,
				SKU.Color,
				SKU.Busr1,
				SKU.Measurement,
				SKU.Size,
				LOC.Putawayzone, 
				LOC.LogicalLocation, 
				PICKDETAIL.Loc,
				SUM(PICKDETAIL.Qty) Qty,
				LOTTABLE01 = LOTATTRIBUTE.LOTTABLE01, 
				LOTTABLE02 = LOTATTRIBUTE.LOTTABLE02, 
				LOTATTRIBUTE.LOTTABLE03,
				LOTTABLE05 = MIN(LOTATTRIBUTE.LOTTABLE05), 
				'' -- ErrFlag
		FROM ORDERS WITH (NOLOCK) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY)
      JOIN PICKDETAIL WITH (NOLOCK) ON  (ORDERS.OrderKey = PICKDETAIL.OrderKey AND 
                                         ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
      JOIN STORER WITH (NOLOCK) ON (PICKDETAIL.StorerKey = STORER.StorerKey)
      JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.SKU = SKU.SKU)				
      JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot AND 
                                          SKU.SKU = LOTATTRIBUTE.SKU AND 
                                          SKU.StorerKey = LOTATTRIBUTE.StorerKey)
      JOIN LOADPLAN WITH (NOLOCK) ON (ORDERS.LoadKey = LOADPLAN.LoadKey)
      JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey AND 
                                            LOADPLANDETAIL.Orderkey = ORDERS.OrderKey)
		JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) 
		WHERE PICKDETAIL.Status < '9' -- KHLim1
		AND   LOADPLANDETAIL.LoadKey = @c_LoadKey
		AND   PICKDETAIL.CartonGroup <> 'PREPACK'
		GROUP BY PICKDETAIL.Pickslipno, ORDERS.Loadkey, ORDERS.OrderKey, ORDERS.StorerKey, 
					PICKDETAIL.AltSku, PICKDETAIL.CartonGroup, SKU.SKU, SKU.Style, SKU.Color, SKU.Busr1,
					SKU.Measurement, SKU.Size, LOC.Putawayzone, LOC.LogicalLocation, PICKDETAIL.Loc,
					LOTATTRIBUTE.LOTTABLE03, LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.LOTTABLE02
		ORDER BY ORDERS.Storerkey, ORDERS.Orderkey, SKU.Style, LOTATTRIBUTE.LOTTABLE03 

		SELECT @n_err = @@ERROR
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			IF @@TRANCOUNT >= 1
			BEGIN
				ROLLBACK TRAN
			END
		END
	END --@n_continue = 1 OR @n_continue = 2

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		DELETE FROM #TempDiscSortList WHERE Pickslipno IS NULL
	END

	IF @b_debug = 1
	BEGIN
		Print '#TempDiscSortList' 
		Select * From #TempDiscSortList
	END 


	-- Start : June01
	-- E1 : Check In-syn PPK allocated among Component SKUs
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN		
		UPDATE #TempDiscSortList
		SET    ErrFlag = 'E1'
		FROM ( 
            SELECT BOMQty.Storerkey, BOMQty.Orderkey, BOMQty.AltSKU, BOMQty.Loc, BOMQty.NoBOMQty, MINPPK.PPKQty
				FROM (SELECT #TempDiscSortList.Storerkey, #TempDiscSortList.Orderkey, #TempDiscSortList.AltSKU, #TempDiscSortList.Loc, NoBOMQty = #TempDiscSortList.Qty/BOM.Qty
						FROM #TempDiscSortList
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempDiscSortList.Sku 
																			    AND BOM.Sku = #TempDiscSortList.AltSku
																				 AND BOM.Storerkey = #TempDiscSortList.Storerkey 
		
						GROUP BY #TempDiscSortList.Storerkey, #TempDiscSortList.Orderkey, #TempDiscSortList.AltSKU, #TempDiscSortList.Loc, (#TempDiscSortList.Qty/BOM.Qty)
						) BOMQty
			   JOIN (	
						SELECT #TempDiscSortList.Storerkey, #TempDiscSortList.Orderkey, AltSku, Loc, PPKQty = MIN(#TempDiscSortList.Qty / BOM.Qty)
						FROM  #TempDiscSortList (nolock) 
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempDiscSortList.Sku 
																			    AND BOM.Sku = #TempDiscSortList.AltSku
																				 AND BOM.Storerkey = #TempDiscSortList.Storerkey 
						GROUP BY #TempDiscSortList.Storerkey, #TempDiscSortList.Orderkey, AltSku, Loc) MINPPK 
																				ON  MINPPK.Storerkey = BOMQty.Storerkey 
																				AND MINPPK.Orderkey = BOMQty.Orderkey
																				AND MINPPK.AltSKU = BOMQty.AltSKU	
																				AND MINPPK.Loc = BOMQty.Loc
				WHERE NoBOMQty <> PPKQty
			  ) AS Prob
		WHERE Prob.Loc = #TempDiscSortList.Loc 
		AND   Prob.AltSku = #TempDiscSortList.AltSKU 
		AND   Prob.Orderkey = #TempDiscSortList.Orderkey
		AND   Prob.Storerkey = #TempDiscSortList.Storerkey
      AND   CartonGroup = 'PREPACK'
		AND   ErrFlag = ''
	END 

	-- E2 : Check Bad Ratio
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN		
		-- Bad Ratio
		UPDATE #TempDiscSortList
		SET    ErrFlag = 'E2'
		FROM (  
            SELECT BadRatio.Storerkey, BadRatio.Orderkey, BadRatio.Loc, BadRatio.AltSKU 
				FROM (
						SELECT #TempDiscSortList.Storerkey, #TempDiscSortList.Orderkey, #TempDiscSortList.Loc, #TempDiscSortList.AltSKU --, BOM.Qty, #TempDiscSortList.Qty, Remaining = (#TempDiscSortList.Qty % BOM.Qty)
						FROM   #TempDiscSortList
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempDiscSortList.Sku 
																			    AND BOM.Sku = #TempDiscSortList.AltSku
																				 AND BOM.Storerkey = #TempDiscSortList.Storerkey 
						WHERE  CartonGroup = 'PREPACK'
						AND    ErrFlag = ''
						GROUP BY #TempDiscSortList.Storerkey, #TempDiscSortList.Orderkey, #TempDiscSortList.Loc, #TempDiscSortList.AltSKU, BOM.Qty, #TempDiscSortList.Qty, (#TempDiscSortList.Qty % BOM.Qty)
						HAVING (#TempDiscSortList.Qty % BOM.Qty) > 0
						) BadRatio
				GROUP BY BadRatio.Storerkey, BadRatio.Orderkey, BadRatio.Loc, BadRatio.AltSKU 
 			  ) AS Prob
 		WHERE Prob.Loc = #TempDiscSortList.Loc 
		AND 	Prob.AltSku = #TempDiscSortList.AltSKU 
		AND   Prob.Orderkey = #TempDiscSortList.Orderkey
		AND   Prob.Storerkey = #TempDiscSortList.Storerkey
      AND   CartonGroup = 'PREPACK'
		AND   ErrFlag = ''
	END


	-- Calc PackUOM* and UOM qty 
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		SET @c_PrevPickslip = ''
		SET @c_PrevOrder = ''
		SET @c_PrevStorer = ''
		SET @c_PrevLoc   = ''
		SET @c_PrevStyle = ''	
		SET @c_PrevPPKInd = ''
		SET @c_PrevCartonGroup = ''
		SET @c_PrevZone = ''
		SET @c_PrevPrintedflag = ''
		SET @b_LastRec = '0'
		SET @n_PrevAllocatedQty = 0
		SET @n_PrevOriginalQty = 0

		SELECT   PickSlipNo, Loadkey, Orderkey, StorerKey, PrintedFlag, 
					CASE  WHEN CartonGroup = 'PREPACK' AND LEFT(ErrFlag, 1) <> 'E' THEN AltSku 
							Else SKU END As AltSKU, 
					CartonGroup, Style, Putawayzone,  Loc, Qty = SUM(Qty), 
					Lottable01, Lottable02, Lottable03, Pallet = 0, Shipper = 0, Casecnt = 0, Innerpack = 0, 
					ErrFlag = Max(ErrFlag), LogicalLoc = ISNULL(LogicalLoc, '') 	
		INTO   #TempDiscSortList2
		FROM   #TempDiscSortList
		WHERE  LoadKey = @c_LoadKey
		GROUP BY PickSlipNo, Loadkey, Orderkey, StorerKey,  PrintedFlag, 
					CASE  WHEN CartonGroup = 'PREPACK' AND LEFT(ErrFlag, 1) <> 'E' THEN AltSku 
							Else SKU END, 
					CartonGroup, Style, Putawayzone, Loc, Lottable01, Lottable02, Lottable03, 
					ISNULL(LogicalLoc, '') 			       
				
		UPDATE #TempDiscSortList2
		SET    Pallet = CASE WHEN #TempDiscSortList2.CartonGroup = 'PREPACK' AND ISNULL(PACK.Pallet, 0) > 0 THEN PACK.Pallet ELSE 0 END,
 				 Shipper = CASE WHEN #TempDiscSortList2.CartonGroup = 'PREPACK' AND ISNULL(PACK.OtherUnit1, 0) > 0 THEN PACK.OtherUnit1 ELSE 0 END,
				 Casecnt = CASE WHEN #TempDiscSortList2.CartonGroup = 'PREPACK' AND ISNULL(PACK.Casecnt, 0) > 0 THEN PACK.Casecnt ELSE 0 END,
				 Innerpack = CASE WHEN #TempDiscSortList2.CartonGroup = 'PREPACK' AND ISNULL(PACK.Innerpack, 0) > 0 THEN PACK.Innerpack ELSE 0 END 
		FROM  #TempDiscSortList2
		JOIN  SKU WITH (NOLOCK) ON  SKU.Storerkey = #TempDiscSortList2.Storerkey 
										AND SKU.SKU = #TempDiscSortList2.Altsku
		JOIN  PACK WITH (NOLOCK) ON PACK.Packkey = SKU.Packkey
		WHERE #TempDiscSortList2.AltSKU > '' 
		AND 	#TempDiscSortList2.CartonGroup = 'PREPACK'

		IF @b_Debug = 1
		BEGIN
			PRINT '#TempDiscSortList2'
			SELECT * FROM #TempDiscSortList2
		END


		DECLARE sort_calcqty_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	   SELECT   PickSlipNo, Loadkey, Orderkey, StorerKey, PrintedFlag, 
					AltSku, CartonGroup, Style, Putawayzone, Loc, Qty, Lottable01, 
					Lottable02, Lottable03, Pallet, Shipper, Casecnt, Innerpack,
					ErrFlag, ISNULL(LogicalLoc, '') 	
		FROM   #TempDiscSortList2
		WHERE  LoadKey = @c_LoadKey
		ORDER BY Loadkey, Storerkey, Orderkey, PickSlipno, Style, Lottable03	

		OPEN sort_calcqty_cur
		FETCH NEXT FROM sort_calcqty_cur 
		INTO  @c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Storerkey, @c_PrintedFlag, 
				@c_AltSku, @c_CartonGroup, @c_Style, @c_Putawayzone, @c_loc, @n_Qty, 
				@c_Lottable01, @c_Lottable02, @c_Lottable03,
				@f_Pallet, @f_OtherUnit1, @f_Casecnt, @f_Innerpack, @c_ErrFlag, @c_Logicalloc
	
		WHILE (@@FETCH_STATUS <> -1)
		BEGIN		
			IF @b_debug = 1
			BEGIN
				Select @c_Orderkey '@c_Orderkey', @c_Loc '@c_Loc', @c_Style '@c_Style', @c_Lottable03 '@c_Lottable03', @c_CartonGroup '@c_CartonGroup',
						 @c_PrevOrder '@c_PrevOrder', @c_PrevLoc '@c_PrevLoc', @c_PrevStyle '@c_PrevStyle', @c_PrevPPKInd '@c_PrevPPKInd', @c_PrevCartonGroup '@c_PrevCartonGroup', @c_PrevZone '@c_PrevZone'
			END 
	
			IF (@c_PrevOrder <> @c_Orderkey) OR (@c_PrevOrder = '') 
			OR (@c_PrevLoc <> @c_Loc) OR (@c_PrevLoc = '') 
			OR (@c_PrevStyle <> @c_Style) OR (@c_PrevStyle = '') 
			OR (@c_PrevPPKInd <> @c_Lottable03) OR (@c_PrevPPKInd = '')
			OR (@c_PrevCartonGroup <> @c_CartonGroup) 
			BEGIN
				IF (@c_PrevOrder <> @c_Orderkey) OR (@c_PrevOrder = '')  
				BEGIN
	 				SELECT @n_OriginalQty = SUM(OriginalQty)
					FROM   ORDERDETAIL WITH (NOLOCK)
					WHERE  Orderkey = @c_OrderKey
	
					SELECT @n_AllocatedQty = SUM(Qty)
					FROM  PICKDETAIL WITH (NOLOCK)
					WHERE Orderkey = @c_OrderKey
					AND   Status < '9' -- KHLim1	
				END

				IF @c_CartonGroup = 'PREPACK' 
				BEGIN
					SELECT @n_BOMQty = ISNULL(SUM(Qty), 0)
					FROM   BillOfMaterial WITH (NOLOCK)
					WHERE  Storerkey = @c_Storerkey
					AND    Sku = @c_AltSKU
				END			
	
			GetBOM:
				IF @b_debug = 1
				BEGIN
					Select 'GETBOM', @c_Orderkey '@c_Orderkey', @c_Loc '@c_Loc', @c_Style '@c_Style', @c_Lottable03 '@c_Lottable03', @c_CartonGroup '@c_CartonGroup',
										  @c_PrevOrder '@c_PrevOrder', @c_PrevLoc '@c_PrevLoc', @c_PrevStyle '@c_PrevStyle', @c_PrevPPKInd '@c_PrevPPKInd', @c_PrevCartonGroup '@c_PrevCartonGroup', @c_PrevZone '@c_PrevZone'
				END 

				IF @c_PrevOrder > '' AND @c_PrevLoc > '' AND @c_PrevStyle > '' AND @c_PrevPPKInd > ''
				BEGIN			
					IF @c_PrevCartonGroup = 'PREPACK' 
					BEGIN
						SET @c_PrevCompColor = ''
						SET @c_CompFind = ''

						WHILE (1=1)
						BEGIN
							SET ROWCOUNT 1
							
							SELECT @c_CompColor = SKU.Color, 
									 @c_CompSize  = SKU.Size,
									 @n_CompQty   = Qty,
									 @c_CompSKU   = SKU.SKU,
									 @c_CompFind  = dbo.fnc_RTrim(SKU.Color)+dbo.fnc_RTrim(SKU.Size)+dbo.fnc_RTrim(BillOfMaterial.SKU) + dbo.fnc_RTrim(BillOfMaterial.ComponentSKU)
							FROM  BillOfMaterial WITH (NOLOCK)
							JOIN  SKU WITH (NOLOCK) ON  SKU.Storerkey = BillOfMaterial.Storerkey 
															AND SKU.SKU = BillOfMaterial.ComponentSKU					
							WHERE BillOfMaterial.Storerkey = @c_Storerkey
							AND   BillOfMaterial.SKU = @c_PrevPPKInd
							AND   dbo.fnc_RTrim(SKU.Color)+dbo.fnc_RTrim(SKU.Size)+dbo.fnc_RTrim(BillOfMaterial.SKU) + dbo.fnc_RTrim(BillOfMaterial.ComponentSKU) > @c_CompFind
							ORDER BY SKU.Color, SKU.Size 
			
							IF @@ROWCOUNT = 0
							BEGIN
								BREAK
								SET ROWCOUNT 0
							END							

							IF @b_Debug = 1
							BEGIN
								SELECT 'BillOfMaterial', @c_PrevPPKInd '@c_PrevPPKInd', @c_CompFind '@c_CompFind',
										 @c_CompSKU '@c_CompSKU',  @c_CompColor '@c_CompColor', @c_CompSize '@c_CompSize', 
										 @n_CompQty '@n_CompQty'
							END
	
							IF @c_PrevCompColor <> @c_CompColor 
							BEGIN
								IF @c_PrevCompColor > ''
								BEGIN
									-- BOM Box 1 : SZ
									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey,
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer,
											@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
										 	SPACE(15) + '|' + '    SZ    ' + '|' + LEFT(dbo.fnc_RTrim(@c_DispSize) +  REPLICATE('', 70), 70), 'B1')
	
									-- BOM Box 1 : COLOUR
									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
											@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
											CONVERT(CHAR(15), @c_PrevCompColor) + '|' + 
											LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_SumCompQty)) + REPLICATE('', 10), 10) + '|' + 
											LEFT(dbo.fnc_RTrim(@c_DispQty) + REPLICATE('', 70), 70), 'B1')
								END
	
								SET @c_DispSize = ''
								SET @c_DispQty = ''
								SET @n_SumCompQty = 0
								SET @c_PrevCompColor = @c_CompColor							
							END
	
							SET @c_DispSize = @c_DispSize + RIGHT(REPLICATE('', 7) + dbo.fnc_RTrim(@c_CompSize), 7)
							SET @c_DispQty  = @c_DispQty  + RIGHT(REPLICATE('', 7) + dbo.fnc_RTrim(@n_CompQty), 7)
							SET @n_SumCompQty = @n_SumCompQty + @n_CompQty		
	
							IF @b_Debug = 1
							BEGIN
								SELECT 'Loop BOM', @c_CompColor '@c_CompColor', @c_DispSize '@c_DispSize',  @c_DispQty '@c_DispQty', @n_SumCompQty '@n_SumCompQty'
							END
						END -- While
	
						-- Print last Color group
						IF @c_PrevCompColor > ''
						BEGIN
							-- BOM Box 2 : SZ
							INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
									  @c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
							SPACE(15) + '|' + '    SZ    ' + '|' + LEFT(dbo.fnc_RTrim(@c_DispSize) +  REPLICATE('', 70), 70), 'B1')


							-- BOM Box 2 : COLOUR
							INSERT INTO @t_DiscSortList 
								  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
									Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
									@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
									CONVERT(CHAR(15), @c_PrevCompColor) + '|' + 
									LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_SumCompQty)) + REPLICATE('', 10), 10) + '|' + 
									LEFT(dbo.fnc_RTrim(@c_DispQty) + REPLICATE('', 70), 70), 'B1')
						END
	
						SET ROWCOUNT 0
					END -- 'PREPACK'
	
					-- Draw Seperator dotted line After Display BOM or When Group (Loc/Style/PPK IND) change
					IF @b_LastRec = '0'
					BEGIN
						-- Seperator Dotted Line
						INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
								  @c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
				  		REPLICATE('-', 150), '')
					END
				END -- @c_PrevOrder > '' AND @c_PrevLoc > '' AND @c_PrevStyle > '' AND @c_PrevPPKInd > ''						
	
				IF @b_LastRec = '1'
				BEGIN				
					GOTO Resume_Process				
				END
	
				SET @c_PrevPickslip = @c_Pickslipno
				SET @c_PrevOrder  = @c_Orderkey
				SET @c_PrevStorer = @c_Storerkey
				SET @c_PrevLoc    = @c_Loc
				SET @c_PrevStyle  = @c_Style
				SET @c_PrevPPKInd = @c_Lottable03
				SET @c_PrevCartonGroup = @c_CartonGroup
				SET @c_PrevZone = @c_Putawayzone
				SET @c_PrevPrintedflag = @c_PrintedFlag
				SET @n_TotalEAQty  = 0
				SET @n_TotalUOMQty = 0						
				SET @n_TotalPPKQty = 0						
				SET @n_PrevOriginalQty = @n_OriginalQty
				SET @n_PrevAllocatedQty = @n_AllocatedQty
				SET @b_Repeat = '1'
			END		
	
			-- Calculate PackUOM* Start Here
			SET @n_RemainQty = @n_Qty
			SET @n_UOMLevel  = 1
			SET @n_UOMQty = 0
			SET @n_EAQty  = 0
	
			While @n_RemainQty > 0
			BEGIN
				SET @c_UOM = ''
				SET @c_PPK_per = ''
				SET @n_PPK_per = 1
				SET @n_NoOfUnits = 0
	
				IF @b_Debug = 1
				BEGIN
					SELECT 'Before PackUOM*', @c_PrevPPKInd '@c_PrevPPKInd', @n_Qty '@n_Qty', @n_RemainQty '@n_RemainQty',  @c_PrevCartonGroup '@c_PrevCartonGroup', CONVERT(CHAR(10), @f_Pallet) '@f_Pallet', CONVERT(CHAR(10), @f_OtherUnit1) '@f_OtherUnit1', 
               CONVERT(CHAR(10), @f_Casecnt) '@f_Casecnt', CONVERT(CHAR(10), @f_InnerPack) '@f_InnerPack'
				END
		
				IF @c_CartonGroup = 'PREPACK' AND LEFT(@c_ErrFlag, 1) <> 'E'
				BEGIN
					IF @n_UOMLevel = 1
						GOTO Pallet
					ELSE IF @n_UOMLevel = 2
						GOTO Shipper
					ELSE IF @n_UOMLevel = 3 
						GOTO Casecnt
					ELSE IF @n_UOMLevel = 4 
						GOTO InnerPack	
					ELSE IF @n_UOMLevel = 5 
						GOTO Prepack
	
					Pallet:				
						IF @f_Pallet > 0 
						BEGIN
							SET @c_UOM = 'PL'
							SET @c_PPK_per = '(' + dbo.fnc_RTrim(@f_Pallet) + ' PPK Per)'
							SET @n_PPK_per = @f_pallet
			
							IF @n_BOMQty > 0
								SET @n_NoOfUnits = @f_Pallet * @n_BOMQty	
							ELSE
								SET @n_NoOfUnits = @f_Pallet		
						END 
	
						IF @b_Debug = 1
						BEGIN
							SELECT @n_UOMLevel '@n_UOMLevel', @c_UOM '@c_UOM', @n_BOMQty '@n_BOMQty',  @n_NoOfUnits '@n_NoOfUnits' 
						END							
						SET  @n_UOMLevel = @n_UOMLevel + 1
						GOTO Insert_t_Sortlist
	
					Shipper:	
						IF @f_OtherUnit1 > 0 
						BEGIN
							SET @c_UOM = 'SH'
							SET @c_PPK_per = '(' + dbo.fnc_RTrim(@f_OtherUnit1) + ' PPK Per)'
							SET @n_PPK_per = @f_OtherUnit1
			
							IF @n_BOMQty > 0
								SET @n_NoOfUnits = @f_OtherUnit1 * @n_BOMQty	
							ELSE
								SET @n_NoOfUnits = @f_OtherUnit1	
						END 
						IF @b_Debug = 1
						BEGIN
							SELECT @n_UOMLevel '@n_UOMLevel', @c_UOM '@c_UOM', @n_BOMQty '@n_BOMQty',  @n_NoOfUnits '@n_NoOfUnits' 
						END							
						SET  @n_UOMLevel = @n_UOMLevel + 1
						GOTO Insert_t_Sortlist
	
					Casecnt:	
						IF @f_Casecnt > 0 
						BEGIN
							SET @c_UOM = 'CS'
							SET @c_PPK_per = '(' + dbo.fnc_RTrim(@f_Casecnt) + ' PPK Per)'
							SET @n_PPK_per = @f_Casecnt
			
							IF @n_BOMQty > 0
								SET @n_NoOfUnits = @f_Casecnt * @n_BOMQty	
							ELSE
								SET @n_NoOfUnits = @f_Casecnt	
						END 
						IF @b_Debug = 1
						BEGIN
							SELECT @n_UOMLevel '@n_UOMLevel', @c_UOM '@c_UOM', @n_BOMQty '@n_BOMQty',  @n_NoOfUnits '@n_NoOfUnits' 
						END							
						SET  @n_UOMLevel = @n_UOMLevel + 1
						GOTO Insert_t_Sortlist
	
					InnerPack:	
						IF @f_InnerPack > 0 
						BEGIN
							SET @c_UOM = 'IN'
							SET @c_PPK_per = '(' + dbo.fnc_RTrim(@f_InnerPack) + ' PPK Per)'
							SET @n_PPK_per = @f_InnerPack
			
							IF @n_BOMQty > 0
								SET @n_NoOfUnits = @f_InnerPack * @n_BOMQty	
							ELSE
								SET @n_NoOfUnits = @f_InnerPack	
						END 
						IF @b_Debug = 1
						BEGIN
							SELECT @n_UOMLevel '@n_UOMLevel', @c_UOM '@c_UOM', @n_BOMQty '@n_BOMQty',  @n_NoOfUnits '@n_NoOfUnits' 
						END							
						SET  @n_UOMLevel = @n_UOMLevel + 1
						GOTO Insert_t_Sortlist
	
					Prepack:	
						-- No Pack Setup but has BOM
						IF @c_UOM = '' AND @n_BOMQty > 0
						BEGIN
							SET @c_UOM = 'PK'
							SET @n_NoOfUnits = @n_BOMQty								
						END

						SET  @n_UOMLevel = @n_UOMLevel + 1
						IF @b_Debug = 1
						BEGIN
							SELECT @n_UOMLevel '@n_UOMLevel', @c_UOM '@c_UOM', @n_BOMQty '@n_BOMQty',  @n_NoOfUnits '@n_NoOfUnits' 
						END							
						GOTO Insert_t_Sortlist

				END -- @c_CartonGroup = 'PREPACK'
				ELSE -- Loose ?
				BEGIN				
					SET @c_UOM = 'PC'
					SET @c_PPK_per = ''
					SET @n_PPK_per = 1
					SET @n_NoOfUnits = 1
	
					IF @b_Debug = 1
					BEGIN
						SELECT 'LOOSE', @c_UOM '@c_UOM', @n_NoOfUnits '@n_NoOfUnits' 
					END							
				END
		
			   Insert_t_Sortlist:
					IF @n_NoOfUnits > 0 AND FLOOR(@n_RemainQty / @n_NoOfUnits) > 0
					BEGIN
						SET @n_UOMQty = FLOOR(@n_RemainQty / @n_NoOfUnits)
						SET @n_EAQty  = @n_UOMQty * @n_NoOfUnits						
			
						SELECT @c_Busr1 = Busr1,
								 @c_Color = Color,
								 @c_Size = Size,
								 @c_Measurement = Measurement
						FROM  SKU WITH (NOLOCK)
						WHERE Storerkey = @c_Storerkey
						AND   SKU = @c_AltSKU
	
						IF @c_CartonGroup = 'PREPACK' AND LEFT(@c_ErrFlag, 1) <> 'E'
						BEGIN
							IF @b_Repeat = '1'
							BEGIN
								-- New PPK Detail 1
                        -- Modified By Vicky on 08-Oct-2007 (Start)
								INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,				 
											CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), ''))   + CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +
										 	CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 
                                 SPACE(12) + CONVERT(CHAR(60), ISNULL(dbo.fnc_RTrim(@c_Busr1), '')) +
										 	LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_UOMQty)) + REPLICATE('', 10), 10) + 						
										 	LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_EAQty)) + REPLICATE('', 10), 10), '')
						
								-- New PPK Detail 2
								INSERT INTO @t_DiscSortList 
										(PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
										Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
										@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
										SPACE(62) + CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) + CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) +
										CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')), '')
								
							    SET @b_Repeat = '0'
							END 
							ELSE
							BEGIN
								-- Repeat PPK Detail
								INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(37) + CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) + CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + 
                                 CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 
											CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) +  CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) + 
                                 CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')) + 
											LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_UOMQty)) + REPLICATE('', 10), 10) + 
											LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_EAQty)) + REPLICATE('', 10), 10), '')
							END							 
						END
						ELSE -- Print Loose
						BEGIN		
							IF @b_Repeat = '1'
							BEGIN
								-- Loose Item Detail 1
								INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
										@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
										CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +
										CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 
                              SPACE(12) + CONVERT(CHAR(60), ISNULL(dbo.fnc_RTrim(@c_Busr1), '')), '')
                        -- Modified By Vicky on 08-Oct-2007
							END				
				
							IF @c_ErrFlag = 'E1'
							BEGIN
								IF @b_Repeat = '1'
								BEGIN
									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,	
											SPACE(150), '')

									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(12) + '*** Allocation Error : No Of Prepack Allocated Different Among Component SKUs ***', '')

									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(150), '')
								END	
							END
							ELSE IF @c_ErrFlag = 'E2'
							BEGIN
								IF @b_Repeat = '1'
								BEGIN
									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(150), '')
		
									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(12) + '*** Allocation Error : Bad Prepack Ratio Allocated In Component SKUs ***', '')
		
									INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(150), '')
								END	
							END 

							-- Loose Item Detail 2
							INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
										@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
										CONVERT(CHAR(15), dbo.fnc_RTrim(@c_Color)) + '|' + ' Size ' + '| ' + 
										CONVERT(CHAR(25), dbo.fnc_RTrim(@c_Size) + ' / ' + dbo.fnc_RTrim(@c_Measurement)) + 
										CONVERT(CHAR(20), @c_Lottable01) +  CONVERT(CHAR(20), @c_Lottable02) + CONVERT(CHAR(20), @c_Lottable03) + 
										LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_UOMQty)) + REPLICATE('', 10), 10) + 
										LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_EAQty)) + REPLICATE('', 10), 10), 'C1')		

							IF @b_Repeat = '1' SET @b_Repeat = '0'
						END
	
						SET @n_TotalUOMQty = @n_TotalUOMQty + @n_UOMQty
						SET @n_TotalEAQty  = @n_TotalEAQty  + @n_EAQty
						SET @n_TotalPPKQty = @n_TotalPPKQty + (@n_UOMQty * @n_PPK_per)
						SET @n_RemainQty   = @n_RemainQty - @n_EAQty

						IF @b_Debug = 1
						BEGIN
							SELECT 'Calc PackUOM*', @n_UOMQty '@n_UOMQty', @n_EAQty '@n_EAQty',  @n_TotalUOMQty '@n_TotalUOMQty', @n_TotalEAQty '@n_TotalEAQty', @n_TotalPPKQty '@n_TotalPPKQty', @n_RemainQty '@n_RemainQty', @b_Repeat '@b_Repeat'
						END
	
						IF @n_RemainQty > 0
						BEGIN
							-- Draw Seperator dotted line
							INSERT INTO @t_DiscSortList 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									  @c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									  REPLICATE('-', 150), '')
						END
					END -- Insert_t_Sortlist : FLOOR(@n_Qty / @n_NoOfUnits) > 0
					ELSE IF @n_UOMLevel > 5 
					BEGIN 
						-- Error in Data, Display allocated records as LOOSE
						SET @n_UOMQty = 0
						SET @n_EAQty  = @n_RemainQty
						SET @n_TotalEAQty = @n_TotalEAQty + @n_EAQty
						SET @n_RemainQty  = @n_RemainQty  - @n_EAQty

						SELECT @c_Busr1 = Busr1,
								 @c_Color = Color,
								 @c_Size = Size,
								 @c_Measurement = Measurement
						FROM  SKU WITH (NOLOCK)
						WHERE Storerkey = @c_Storerkey
						AND   SKU = @c_AltSKU

						IF @b_Repeat = '1'
						BEGIN
							-- Error Loose Item Detail 1
							INSERT INTO @t_DiscSortList 
									  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
										Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +
									CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 
                           SPACE(12) + CONVERT(CHAR(60), ISNULL(dbo.fnc_RTrim(@c_Busr1), '')), '')
						END									

						-- Error Loose Item Detail 2
						INSERT INTO @t_DiscSortList 
							  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
								Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
								@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,	
								SPACE(150), '')

						-- Error Loose Item Detail 3
						INSERT INTO @t_DiscSortList 
							  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
								Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
								@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
								 SPACE(12) + '*** Data Error : Records shown as Loose ***', '')

						-- Error Loose Item Detail 4
						INSERT INTO @t_DiscSortList 
							  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
								Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
								@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
								SPACE(150), '')

						IF @c_CartonGroup = 'PREPACK' 
						BEGIN
							INSERT INTO @t_DiscSortList 
								  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
									Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									'Parent SKU : '+ dbo.fnc_RTrim(@c_AltSKU), '')
						END
						ELSE
						BEGIN
							INSERT INTO @t_DiscSortList 
								  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
									Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									'SKU : '+ dbo.fnc_RTrim(@c_AltSKU), '')
						END

						-- Error Loose Item Detail 5						
						INSERT INTO @t_DiscSortList 
									  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
										Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									CONVERT(CHAR(15), dbo.fnc_RTrim(@c_Color)) + '|' + ' Size ' + '| ' + 
									CONVERT(CHAR(25), dbo.fnc_RTrim(@c_Size) + ' / ' + dbo.fnc_RTrim(@c_Measurement)) + 
									CONVERT(CHAR(20), @c_Lottable01) +  CONVERT(CHAR(20), @c_Lottable02) + CONVERT(CHAR(20), @c_Lottable03) + 
									LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_UOMQty)) + REPLICATE('', 10), 10) + 
									LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_EAQty)) + REPLICATE('', 10), 10), 'C1')				

						IF @b_Repeat = '1' SET @b_Repeat = '0'
					END -- Insert_t_Conso : FLOOR(@n_Qty / @n_NoOfUnits) > 0 : @n_UOMLevel > 5
			END -- While @n_RemainQty > 0
			-- Calculate PackUOM* End Here
			
			FETCH NEXT FROM sort_calcqty_cur 
			INTO  @c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Storerkey, @c_PrintedFlag, 
					@c_AltSku, @c_CartonGroup, @c_Style, @c_Putawayzone, @c_loc, @n_Qty, 
					@c_Lottable01, @c_Lottable02, @c_Lottable03,
					@f_Pallet, @f_OtherUnit1, @f_Casecnt, @f_Innerpack, @c_ErrFlag, @c_Logicalloc	
		END -- END WHILE (@@FETCH_STATUS <> -1)
	
		-- Trigger to display BOM detail	for last record
		IF @c_PrevCartonGroup = 'PREPACK' AND @n_EAQty > 0 
		BEGIN				
			SET @b_LastRec = '1'			
			GOTO GetBOM				
		END
	
	Resume_Process:
		IF @n_TotalEAQty > 0
		BEGIN
			-- Seperator Dotted Line for Last Record
			INSERT INTO @t_DiscSortList 
				(PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
				Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
			VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
				@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
				REPLICATE('-', 150), '')
		END

		CLOSE sort_calcqty_cur
		DEALLOCATE sort_calcqty_cur		
	END -- @n_continue = 1 OR @n_continue = 2
	-- End : June01

	IF @n_continue <> 3 AND @n_err = 0
	BEGIN
		IF @@TRANCOUNT > 0
		BEGIN
			COMMIT TRAN
		END
		ELSE
		BEGIN
			ROLLBACK TRAN
		END
	END
	
 	SELECT 	RowId,
				PickSlipNo,
				RESULT.LoadKey,
				RESULT.Orderkey, 
				PrintedFlag,
				RESULT.StorerKey,
				Putawayzone, 
				TotalAllocateQty,
				TotalOrderQty,
				LineText,
				LineFlag,
  				STORER.Company, 
 				ORDERS.Facility,
 				ORDERS.AddDate,
 				ORDERS.OrderDate,
 				ORDERS.DeliveryDate,
  				ORDERS.ExternOrderkey,
 				ORDERS.BuyerPO,
				ORDERS.PmtTerm,
				ORDERS.BillTokey,
				ORDERS.B_Company,
				ORDERS.B_Address1,
				ORDERS.B_Address2,
				ORDERS.B_Address3,
				ORDERS.B_Address4,
				ORDERS.B_City,
				ORDERS.B_State,
				ORDERS.B_Zip,
				ORDERS.ConsigneeKey,
				ORDERS.C_Company,
				ORDERS.C_Address1,
				ORDERS.C_Address2,
				ORDERS.C_Address3,
				ORDERS.C_Address4,
				ORDERS.C_City,
				ORDERS.C_State,
				ORDERS.C_Zip,
				ORDERS.Markforkey,
				ORDERS.M_Company,
				ORDERS.M_Address1,
				ORDERS.M_Address2,
				ORDERS.M_Address3,
				ORDERS.M_Address4,
				ORDERS.M_City,
				ORDERS.M_State,
				ORDERS.M_Zip,
				ORDERS.UserDefine02, 
				ORDERS.UserDefine03, 
				ORDERS.UserDefine04,
 				CONVERT(CHAR(250), ORDERS.Notes) Notes,
 				CONVERT(CHAR(250), ORDERS.Notes2) Notes2,
            CONVERT(CHAR(15), sUser_sName()) UserID
 	FROM  @t_DiscSortList RESULT
	JOIN  ORDERS WITH (NOLOCK) ON ORDERS.Orderkey = RESULT.Orderkey
	JOIN  STORER WITH (NOLOCK) ON STORER.Storerkey = ORDERS.Storerkey	
 	ORDER BY RowID

	-- Start : Get Label Datawindow & Default Printer from RDT db
	SELECT @c_DataWindow = ISNULL(dbo.fnc_RTrim(DataWindow), ''),
	       @c_TargetDB = ISNULL(dbo.fnc_RTrim(TargetDB), '') 
	FROM  [RDT].RDTReport WITH (NOLOCK)
	WHERE StorerKey  = @c_StorerKey
	AND   ReportType = 'AUTOPPKLBL'
	
	SELECT @c_Printer = [DefaultPrinter] 
	FROM  [RDT].[RDTUser]
	WHERE UserName = sUser_sName()

	-- Start : Submit RDT Print Job
	INSERT INTO [RDT].RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, 
													Parm1, Parm2, Parm3, Printer, NoOfCopy, Mobile, TargetDB)
	VALUES('Auto PPK Label (Sort List) - PS#'+dbo.fnc_RTrim(@c_Pickslipno), 'AUTOPPKLBL', '0', dbo.fnc_RTrim(@c_DataWindow), 2, 
	dbo.fnc_RTrim(@c_LoadKey), sUser_sName(), '', dbo.fnc_RTrim(@c_Printer), 1, '', @c_TargetDB)
	-- End : Submit RDT Print Job

	DROP TABLE #TempDiscSortList
	DROP TABLE #TempDiscSortList2 
END





GO