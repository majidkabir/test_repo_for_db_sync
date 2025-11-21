SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetConsoPickTicketUSA                          */
/* Creation Date: 23-Jul-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: MCTang                                                   */
/*                                                                      */
/* Purpose:  SOS#84285 - Consolidated Pick Ticket for IDSUS.            */
/*                                                                      */
/* Called By:  PB - r_dw_consolidated_pick16_conso                      */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 15-Sep-2007  YokeBeen  Modified PickHeader.Zone -> Conso = 'C'       */ 
/*                                                 -> Discrete = 'D'    */
/* 21-Sep-2007  June      Change of Conso Pickslip format (June01)      */
/* 09-Oct-2007  Vicky     SOS#84285 - Adjust the Pickslip Qty Position  */
/* 14-Jul-2010  Shong     Replace USER_NAME to sUSER_sName              */ 
/* 20-Jul-2010  KHLim     Synronize version of PVCS to US live db       */ 
/* 17-Dec-2013  NJOW01    Fix commit issue                              */
/************************************************************************/

CREATE PROC [dbo].[isp_GetConsoPickTicketUSA] ( 
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
				@n_RowId int,
				@c_LoadPickHeaderKey NVARCHAR(10),
				@c_OrderPickHeaderKey NVARCHAR(10),
				@c_LoadPrintedFlag NVARCHAR(1),
				@c_OrderPrintedFlag NVARCHAR(1),
				@c_OrderKey NVARCHAR(10),
				@c_Facility NVARCHAR(5), 
				@c_Company NVARCHAR(45), 
				@c_Route NVARCHAR(10), 
				@c_StorerKey NVARCHAR(15),
				@c_Sku NVARCHAR(20), 
				@c_Prepack NVARCHAR(1),
				@d_LoadPlanAddDate DateTime,
				@c_tpickslipno NVARCHAR(10),
				@n_SumOriginalQty int,
				@n_SumAllocatedQty int,
				@n_OriginalQty int,
				@n_AllocatedQty int,
				@c_AltSku NVARCHAR(20),
				@c_CartonGroup NVARCHAR(10),
				@f_Pallet float,
				@f_Casecnt float,
				@f_OtherUnit1 float,
				@f_InnerPack float,
			 	@c_tempOrderKey NVARCHAR(10)
-- Start : June01
			  ,@c_Putawayzone NVARCHAR(10)
			  ,@c_Style NVARCHAR(20)
			  ,@c_Color NVARCHAR(10)
			  ,@c_Size  NVARCHAR(5)
			  ,@c_Measurement NVARCHAR(5)
			  ,@c_Busr1 NVARCHAR(18)
			  ,@c_Lottable01 NVARCHAR(18)
			  ,@c_Lottable02 NVARCHAR(18)
			  ,@c_Lottable03 NVARCHAR(18)
			  ,@c_LogicalLoc NVARCHAR(18)
			  ,@c_Loc NVARCHAR(10)
			  ,@n_Qty   int
			  ,@n_EAQty  int
			  ,@n_UOMQty int
			  ,@n_BOMQty int
			  ,@n_RemainQty int
			  ,@n_NoOfUnits int
			  ,@n_PPK_Per   int
			  ,@n_CompQty   int
			  ,@n_UOMLevel  int
			  ,@n_SUMCompQty int
			  ,@n_TotalEAQty int
			  ,@n_TotalUOMQty int
			  ,@n_TotalPPKQty int
			  ,@c_UOM 		 NVARCHAR(10)
			  ,@c_PPK_per NVARCHAR(30)					
			  ,@c_PrevLoc NVARCHAR(10)
			  ,@c_PrevZone NVARCHAR(10)
			  ,@c_PrevFacility NVARCHAR(5)
			  ,@c_PrevStyle NVARCHAR(20)
			  ,@c_PrevPPKInd NVARCHAR(30)
			  ,@c_PrevCompColor NVARCHAR(10)
			  ,@c_PrevCartonGroup NVARCHAR(10)
			  ,@c_CompSku NVARCHAR(20)
			  ,@c_CompColor NVARCHAR(10)
			  ,@c_CompSize  NVARCHAR(5)
			  ,@c_CompFind  NVARCHAR(100)
			  ,@c_DispSize NVARCHAR(80)
			  ,@c_DispQty  NVARCHAR(80)
			  ,@b_Repeat  NVARCHAR(1)
			  ,@b_LastRec NVARCHAR(1)
			  ,@c_ErrFlag NVARCHAR(2)
			  ,@c_LineText NVARCHAR(200)
-- End : June01
 
   DECLARE @c_color1   NVARCHAR(10), 
           @c_busr8 NVARCHAR(30),
           @c_Prevcolor   NVARCHAR(10), 
           @c_Prevbusr8 NVARCHAR(30)
 

	CREATE TABLE #TempConsoPickSlip
					( 	RowId int IDENTITY (1, 1) NOT NULL,
						LoadPickSlipNo NVARCHAR(10),
						LoadKey NVARCHAR(10),
						OrderKey NVARCHAR(10),
						StorerKey NVARCHAR(15),
						Facility NVARCHAR(5) NULL, 
						Company NVARCHAR(45) NULL, 
						Route NVARCHAR(10) NULL, 
						LoadPlanAddDate DateTime,
						LoadPrintedFlag NVARCHAR(1) NULL,
						AltSku NVARCHAR(20) NULL,
						CartonGroup NVARCHAR(10) NULL,
						UserDefine03 NVARCHAR(18) NULL,
						UserDefine04 NVARCHAR(18) NULL,
						SKU NVARCHAR(20),
						DisplaySku NVARCHAR(20) NULL,
						Style NVARCHAR(20) NULL,
						Color NVARCHAR(10) NULL,
						Susr3 NVARCHAR(18) NULL,
						Busr1 NVARCHAR(30) NULL,
						Measurement NVARCHAR(5) NULL,
						Size NVARCHAR(5) NULL,
--						Putawayzone NVARCHAR(10), -- June01
						LogicalLoc NVARCHAR(18), -- June01
						Loc NVARCHAR(10),
						-- ID NVARCHAR(18) NULL, -- June01
						Qty int NULL,
						Lottable01 NVARCHAR(18) NULL,
						Lottable02 NVARCHAR(18) NULL,
						Lottable03 NVARCHAR(18) NULL,
						Lottable05 datetime NULL,
						TotalAllocateQty int NULL,
						TotalOrderQty int NULL,
						Pallet  float NULL,
						Shipper float NULL, -- June01
						Casecnt float NULL,
						InnerPack float NULL, -- June01
						ErrFlag  NVARCHAR(2) NULL, -- June01
                  BUSR8  NVARCHAR(30) NULL -- Vicky02
					 )

	-- Start : June01
   DECLARE @t_ConsoPS TABLE 
			( 	RowId int IDENTITY (1, 1) NOT NULL,
				LoadPickSlipNo NVARCHAR(10),
				LoadKey NVARCHAR(10),
				Route NVARCHAR(10) NULL, 
				LoadPlanAddDate DateTime,
				LoadPrintedFlag NVARCHAR(1) NULL,
				StorerKey NVARCHAR(15),
				Company NVARCHAR(45) NULL, 
				Facility NVARCHAR(5) NULL, 
--				PutawayZone NVARCHAR(10),
				TotalAllocateQty int NULL,
				TotalOrderQty int NULL,
				LineText NVARCHAR(200) NULL,
				LineFlag NVARCHAR(2) 
			 )	
	-- End : June01

	SELECT @n_continue = 1 
	SELECT @n_SumOriginalQty = 0, @n_SumAllocatedQty = 0 

	BEGIN TRAN

	-- Check Load-PickHeader Exists, if not exists assign new pickslipno for loadplan
	IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE ExternOrderKey = @c_LoadKey AND Zone = 'C')
	BEGIN
		SELECT @c_LoadPrintedFlag = 'Y'
	END
	ELSE
	BEGIN
		SELECT @c_LoadPrintedFlag = 'N'
	END

	-- Uses PickType as a Printed Flag
	UPDATE PickHeader WITH (ROWLOCK)
	SET 	PickType = '1',
			TrafficCop = NULL
	WHERE ExternOrderkey = @c_LoadKey
	AND Zone IN ('C') 
	AND PickType = '0'

	SELECT @n_err = @@ERROR
	IF @n_err <> 0
	BEGIN
		SELECT @n_continue = 3
		IF @@TRANCOUNT >= 1
		BEGIN
			ROLLBACK TRAN
		END
	END

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN    
		-- Get LoadPickSlipNo  
		IF @c_LoadPrintedFlag = 'N' 
		BEGIN
			EXECUTE nspg_GetKey
				'PICKSLIP',
				9,
				@c_LoadPickHeaderKey OUTPUT,
				@b_success OUTPUT,
				@n_err OUTPUT,
				@c_errmsg OUTPUT
				
			SELECT @c_LoadPickHeaderKey = 'P' + @c_LoadPickHeaderKey
			
			INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderkey, PickType, Zone, TrafficCop)
			VALUES (@c_LoadPickHeaderKey, @c_LoadKey, '0', 'C', '')

			SELECT @n_err = @@ERROR
			IF @n_err <> 0
			BEGIN
				SELECT @n_continue = 3
				IF @@TRANCOUNT >= 1
				BEGIN
					ROLLBACK TRAN
				END
			END
		END --@c_LoadPrintedFlag = 'N'
		ELSE --@c_LoadPrintedFlag = 'Y' 
		BEGIN		
			SELECT @c_LoadPickHeaderKey = PickHeaderKey 
			FROM   PickHeader WITH (NOLOCK)
			WHERE  ExternOrderKey = @c_LoadKey
			AND    Zone = 'C'
		END --@c_LoadPrintedFlag = 'Y' 				
	END

	-- Create TempConsoPickSlip Table
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		INSERT INTO #TempConsoPickSlip 
						( LoadPickSlipNo,
						LoadKey,
						OrderKey,
						StorerKey,
						Facility, 
						Company, 
						Route, 
						LoadPlanAddDate,
						LoadPrintedFlag,
						AltSku,
						CartonGroup,
						UserDefine03,
						UserDefine04,
						SKU,
						Style,
						Color,
						Susr3,
						Busr1,
						Measurement,
						Size,
--						Putawayzone, -- June01
						LogicalLoc, -- June01
						Loc,
						-- ID, -- June01
						Qty,
						Lottable01,
						Lottable02,
						Lottable03,
						Lottable05,
					   ErrFlag,
                  BUSR8 ) -- June01 
				SELECT @c_LoadPickHeaderKey,
						@c_LoadKey,
						ORDERS.OrderKey, 
						ORDERS.StorerKey, 
						ORDERS.Facility, 
						STORER.Company, 
						LOADPLAN.Route, 
						LOADPLAN.AddDate,
						@c_LoadPrintedFlag,
						PICKDETAIL.AltSku,
						PICKDETAIL.CartonGroup, -- June01
						OrderDetail.UserDefine03, 
						OrderDetail.UserDefine04,
						SKU.SKU,
						SKU.Style,
						SKU.Color,
						SKU.Susr3,
						SKU.Busr1,
						SKU.Measurement,
						SKU.Size,
--						LOC.Putawayzone, -- June01
						LOC.LogicalLocation, -- June01
						PICKDETAIL.Loc,
						-- PICKDETAIL.ID, -- June01
						SUM(PICKDETAIL.Qty) Qty,
						LOTTABLE01 = MIN(LOTATTRIBUTE.LOTTABLE01), -- June01
						LOTTABLE02 = MIN(LOTATTRIBUTE.LOTTABLE02), -- June01
						LOTATTRIBUTE.LOTTABLE03,
						LOTTABLE05 = MIN(LOTATTRIBUTE.LOTTABLE05), -- June01
						'' , -- Errflag - June01,
                  SKU.BUSR8 -- Vicky02
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
				JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) -- June01
				WHERE PICKDETAIL.Status < '9'
				AND   LOADPLANDETAIL.LoadKey = @c_LoadKey
				GROUP BY	ORDERS.OrderKey, 
							ORDERS.StorerKey, 
							ORDERS.Facility, 
							STORER.Company, 
							LOADPLAN.Route, 
							LOADPLAN.AddDate,
							PICKDETAIL.AltSku,
							PICKDETAIL.CartonGroup,
							OrderDetail.UserDefine03,
							OrderDetail.UserDefine04,
							SKU.SKU,
							SKU.Style,
							SKU.Color,
							SKU.Susr3,
							SKU.Busr1,
							SKU.Measurement,
							SKU.Size,
							--LOC.Putawayzone, -- June01
							LOC.LogicalLocation, -- June01
							PICKDETAIL.Loc,
							-- PICKDETAIL.ID, -- June01
							-- LOTATTRIBUTE.LOTTABLE01, -- June01
							-- LOTATTRIBUTE.LOTTABLE02, -- June01
							LOTATTRIBUTE.LOTTABLE03, -- , June01
							-- LOTATTRIBUTE.LOTTABLE05  -- 
                     SKU.BUSR8 -- Vicky02
				--ORDER BY ORDERS.Storerkey, LOC.PutawayZone, LOC.LogicalLocation, SKU.Style, LOTATTRIBUTE.LOTTABLE03 -- June01
              ORDER BY LOC.LogicalLocation, PICKDETAIL.LOC, SKU.Style, SKU.Color, SKU.BUSR8, SKU.Measurement, LOTATTRIBUTE.LOTTABLE03 -- Vicky02

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

	SELECT @c_tempOrderKey = ''

	-- Check Order-PickHeader Exists, if not exists assign new pickslipno for each order
	-- Check Prepack, if Prepack PickSlipNo LIKE 'T%', convert Prepack Temporary PickSlipNo-'T%' to Actual PickSlipNo  
	DECLARE conso_order_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT OrderKey, RowId, Storerkey, Sku, AltSku, CartonGroup
	FROM   #TempConsoPickSlip
	WHERE  LoadKey = @c_LoadKey
	ORDER BY OrderKey

	OPEN conso_order_cur
	FETCH NEXT FROM conso_order_cur INTO @c_OrderKey, @n_RowId, @c_Storerkey, @c_Sku, @c_AltSku, @c_CartonGroup
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF @n_continue = 3
		BEGIN
			BREAK
		END

		IF @c_tempOrderKey <> @c_OrderKey
		BEGIN
			SELECT @c_tempOrderKey = @c_OrderKey
			
			-- Check Order-PickHeader Exists
			IF EXISTS(SELECT 1 FROM PickHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND Zone = 'D')
			BEGIN
				SELECT @c_OrderPrintedFlag = 'Y'
			END
			ELSE
			BEGIN
				SELECT @c_OrderPrintedFlag = 'N'
			END
			
			-- Uses PickType as a Printed Flag
			UPDATE PickHeader WITH (ROWLOCK)
			SET 	PickType = '1',
					TrafficCop = NULL
			WHERE Orderkey = @c_OrderKey
			AND   Zone = 'D'
			AND   PickType = '0'

			SELECT @n_err = @@ERROR
			IF @n_err <> 0
			BEGIN
				SELECT @n_continue = 3
				IF @@TRANCOUNT >= 1
				BEGIN
					ROLLBACK TRAN
				END
			END

			IF @n_continue = 1 OR @n_continue = 2
			BEGIN    
				-- Get PickSlipNo  
				IF @c_OrderPrintedFlag = 'N' 
				BEGIN
					EXECUTE nspg_GetKey
						'PICKSLIP',
						9,
						@c_OrderPickHeaderKey OUTPUT,
						@b_success OUTPUT,
						@n_err OUTPUT,
						@c_errmsg OUTPUT
				
					SELECT @c_OrderPickHeaderKey = 'P' + @c_OrderPickHeaderKey

					INSERT INTO PICKHEADER
					(PickHeaderKey, ExternOrderkey, Orderkey, PickType, Zone, TrafficCop)
					VALUES
					(@c_OrderPickHeaderKey, @c_Loadkey, @c_OrderKey, '0', 'D', '')

					SELECT @n_err = @@ERROR
					IF @n_err <> 0
					BEGIN
						SELECT @n_continue = 3
						IF @@TRANCOUNT >= 1
						BEGIN
							ROLLBACK TRAN
						END
					END

					-- Update Pickdetail.PickSlipNo	
					IF @n_continue = 1 OR @n_continue = 2
					BEGIN					
						UPDATE PICKDETAIL WITH (ROWLOCK)
						SET 	PICKSLIPNO = @c_OrderPickHeaderKey, 
								Trafficcop = NULL
						FROM  PICKDETAIL 
						WHERE Orderkey = @c_OrderKey
						AND   Status < '9'
						AND   ISNULL(dbo.fnc_RTrim(Pickslipno),'') = ''
	
						SELECT @n_err = @@ERROR
						IF @n_err <> 0
						BEGIN
							SELECT @n_continue = 3
							IF @@TRANCOUNT >= 1
							BEGIN
								ROLLBACK TRAN
							END
						END
					END
				END --@c_OrderPrintedFlag = 'N'
				ELSE --@c_OrderPrintedFlag = 'Y' 
				BEGIN		
					SELECT @c_OrderPickHeaderKey = PickHeaderKey 
					FROM  PickHeader WITH (NOLOCK)
					WHERE OrderKey = @c_OrderKey
					AND Zone IN ('C','D')
				END --@c_OrderPrintedFlag = 'Y' 				
			END

			IF @n_continue = 1 OR @n_continue = 2
			BEGIN
				-- Check Is Prepack?
				IF EXISTS(SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey AND LoadKey = @c_LoadKey)
				BEGIN
					SELECT @c_Prepack = 'Y'

					SELECT @c_tpickslipno = PickSlipNo
					FROM   PACKHEADER PACK WITH (NOLOCK)
					JOIN   PICKHEADER PICK WITH (NOLOCK)
					ON    (PACK.Orderkey = PICK.Orderkey)
					WHERE  PACK.PickSlipNo LIKE 'T%'
					AND    PICK.PickHeaderKey = @c_OrderPickHeaderKey
				
					-- Convert Prepack Temporary PickSlipNo-'T%' to Actual PickSlipNo 
					IF dbo.fnc_RTrim(@c_tpickslipno)<> '' AND dbo.fnc_RTrim(@c_tpickslipno) IS NOT NULL
					BEGIN
						INSERT INTO PACKHEADER (PickSlipNo, StorerKey, Route, OrderKey, OrderRefNo, 
                                          LoadKey, ConsigneeKey, Status, AddWho, AddDate)
						SELECT 	@c_OrderPickHeaderKey, 
				 					PACK.StorerKey, 
				 					PACK.Route, 
				 					PACK.OrderKey, 
					 				PACK.OrderRefNo, 
					 				PACK.LoadKey, 
					 				PACK.ConsigneeKey, 
					 				PACK.Status, 
					 				PACK.AddWho, 
				 					PACK.AddDate 
						FROM  PACKHEADER PACK WITH (NOLOCK)
						JOIN  PICKHEADER PICK WITH (NOLOCK) ON (PACK.Orderkey = PICK.Orderkey)
						WHERE PACK.PickSlipNo LIKE 'T%'
						AND   PICK.PickHeaderKey = @c_OrderPickHeaderKey			

						SELECT @n_err = @@ERROR
						IF @n_err <> 0
						BEGIN
							SELECT @n_continue = 3
							IF @@TRANCOUNT >= 1
							BEGIN
								ROLLBACK TRAN
							END
						END

						IF @n_continue = 1 OR @n_continue = 2
						BEGIN
							UPDATE PACKDETAIL WITH (ROWLOCK) 
							SET 	PickSlipNo = @c_OrderPickHeaderKey,
		    						EditWho    = sUser_sName(),
			 						EditDate   = GetDate()
							WHERE PickSlipNo = @c_tpickslipno

							SELECT @n_err = @@ERROR
							IF @n_err <> 0
							BEGIN
								SELECT @n_continue = 3
								IF @@TRANCOUNT >= 1
								BEGIN
									ROLLBACK TRAN
								END
							END
						END

						IF @n_continue = 1 OR @n_continue = 2
						BEGIN
							UPDATE PACKINFO WITH (ROWLOCK)
							SET 	PickSlipNo = @c_OrderPickHeaderKey,
		    						EditWho    = sUser_sName(),
			 						EditDate   = GetDate()
							WHERE PickSlipNo = @c_tpickslipno

							SELECT @n_err = @@ERROR
							IF @n_err <> 0
							BEGIN
								SELECT @n_continue = 3
								IF @@TRANCOUNT >= 1
								BEGIN
									ROLLBACK TRAN
								END
							END
						END

						IF @n_continue = 1 OR @n_continue = 2
						BEGIN
							DELETE FROM PACKHEADER 
							WHERE PickSlipNo = @c_tpickslipno

							SELECT @n_err = @@ERROR
							IF @n_err <> 0
							BEGIN
								SELECT @n_continue = 3
								IF @@TRANCOUNT >= 1
								BEGIN
									ROLLBACK TRAN
								END
							END
						END

					END -- Convert Prepack Temporary PickSlipNo-'T%' to Actual PickSlipNo 
				END -- Check Is Prepack
				ELSE -- Check Not Prepack
				BEGIN
					SELECT @c_Prepack = 'N'
				END -- Check Not Prepack
			END

			IF @n_continue = 1 OR @n_continue = 2
			BEGIN
				SELECT @n_OriginalQty = SUM(OriginalQty)
				FROM  ORDERDETAIL WITH (NOLOCK)
				WHERE Orderkey = @c_OrderKey

				SELECT @n_AllocatedQty = SUM(Qty)
				FROM  PICKDETAIL WITH (NOLOCK)
				WHERE Orderkey = @c_OrderKey
				AND   Status < '9'

				SELECT @n_SumOriginalQty  = @n_SumOriginalQty + @n_OriginalQty
				SELECT @n_SumAllocatedQty = @n_SumAllocatedQty + @n_AllocatedQty
			END
		END --IF @c_tempOrderKey <> @c_OrderKey

		IF @n_continue = 1 OR @n_continue = 2
		BEGIN
			--Check Prepack  
			IF dbo.fnc_RTrim(@c_CartonGroup) = 'PREPACK' AND ISNULL(dbo.fnc_RTrim(@c_AltSku),'') <> '' 
			BEGIN
				SELECT @f_Pallet = 0.0, @f_Casecnt = 0.0

				--Get Parrent Sku - Pallet, CaseCnt		
				SELECT @f_Pallet  = PACK.Pallet, 
						 @f_Casecnt = PACK.Casecnt,
						 @f_OtherUnit1 = PACK.Otherunit1, -- June01
						 @f_InnerPack = PACK.InnerPack -- June01
				FROM  SKU WITH (NOLOCK)
            JOIN  PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
				WHERE SKU.StorerKey = @c_Storerkey
				AND   SKU.Sku = @c_AltSku

				IF ISNULL(dbo.fnc_RTrim(@f_Pallet),'') = '' 
				BEGIN
					SELECT @f_Pallet = 0.0
				END 

				IF ISNULL(dbo.fnc_RTrim(@f_Casecnt),'') = '' 
				BEGIN
					SELECT @f_Casecnt = 0.0
				END

				-- Start : June01
				IF ISNULL(dbo.fnc_RTrim(@f_OtherUnit1),'') = '' 
				BEGIN
					SELECT @f_OtherUnit1 = 0.0
				END

				IF ISNULL(dbo.fnc_RTrim(@f_InnerPack),'') = '' 
				BEGIN
					SELECT @f_InnerPack = 0.0
				END
				-- End : June01

				UPDATE #TempConsoPickSlip
				SET 	Pallet = @f_Pallet,
						Casecnt = @f_Casecnt,
						Shipper = @f_OtherUnit1, -- June01
						Innerpack = @f_innerpack, -- June01
						DisplaySku = @c_AltSku
				WHERE Rowid = @n_RowId
				AND   OrderKey = @c_OrderKey
			END 
			ELSE
			BEGIN
				UPDATE #TempConsoPickSlip
				SET 	DisplaySku = @c_Sku
				WHERE Rowid = @n_RowId
				AND OrderKey = @c_OrderKey
			END
		END --@n_continue = 1 OR @n_continue = 2

		FETCH NEXT FROM conso_order_cur INTO @c_OrderKey, @n_RowId, @c_StorerKey, @c_Sku, @c_AltSku, @c_CartonGroup
	END -- END WHILE (@@FETCH_STATUS <> -1)
	CLOSE conso_order_cur
	DEALLOCATE conso_order_cur		

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		UPDATE #TempConsoPickSlip 
		SET 	TotalAllocateQty = @n_SumAllocatedQty,
				TotalOrderQty = @n_SumOriginalQty
		WHERE Loadkey = @c_LoadKey
	END

	IF @b_debug = 1
	BEGIN
		Print '#TempConsoPickSlip' 
		Select * From #TempConsoPickSlip
	END 


	-- Start : June01
	-- E1 : Check In-syn PPK allocated among Component SKUs
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN		
		UPDATE #TempConsoPickSlip
		SET    ErrFlag = 'E1'
		FROM ( 
            SELECT BOMQty.Storerkey, BOMQty.Orderkey, BOMQty.AltSKU, BOMQty.Loc, BOMQty.NoBOMQty, MINPPK.PPKQty
				FROM (SELECT #TempConsoPickSlip.Storerkey, #TempConsoPickSlip.Orderkey, #TempConsoPickSlip.AltSKU, #TempConsoPickSlip.Loc, NoBOMQty = #TempConsoPickSlip.Qty/BOM.Qty
						FROM #TempConsoPickSlip
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempConsoPickSlip.Sku 
																			    AND BOM.Sku = #TempConsoPickSlip.AltSku
																				 AND BOM.Storerkey = #TempConsoPickSlip.Storerkey 
		
						GROUP BY #TempConsoPickSlip.Storerkey, #TempConsoPickSlip.Orderkey, #TempConsoPickSlip.AltSKU, #TempConsoPickSlip.Loc, (#TempConsoPickSlip.Qty/BOM.Qty)
						) BOMQty
			   JOIN (	
						SELECT #TempConsoPickSlip.Storerkey, #TempConsoPickSlip.Orderkey, AltSku, Loc, PPKQty = MIN(#TempConsoPickSlip.Qty / BOM.Qty)
						FROM  #TempConsoPickSlip (nolock) 
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempConsoPickSlip.Sku 
																			    AND BOM.Sku = #TempConsoPickSlip.AltSku
																				 AND BOM.Storerkey = #TempConsoPickSlip.Storerkey 
						GROUP BY #TempConsoPickSlip.Storerkey, #TempConsoPickSlip.Orderkey, AltSku, Loc) MINPPK 
																				ON  MINPPK.Storerkey = BOMQty.Storerkey 
																				AND MINPPK.Orderkey = BOMQty.Orderkey
																				AND MINPPK.AltSKU = BOMQty.AltSKU	
																				AND   MINPPK.Loc = BOMQty.Loc
				WHERE NoBOMQty <> PPKQty
			  ) AS Prob
		WHERE Prob.Loc = #TempConsoPickSlip.Loc 
		AND   Prob.AltSku = #TempConsoPickSlip.AltSKU 
		AND   Prob.Orderkey = #TempConsoPickSlip.Orderkey
		AND   Prob.Storerkey = #TempConsoPickSlip.Storerkey
      AND   CartonGroup = 'PREPACK'
		AND   ErrFlag = ''
	END 

	-- E2 : Check Bad Ratio
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN		
		-- Bad Ratio
		UPDATE #TempConsoPickSlip
		SET    ErrFlag = 'E2'
		FROM (  
            SELECT BadRatio.Storerkey, BadRatio.Orderkey, BadRatio.Loc, BadRatio.AltSKU 
				FROM (
						SELECT #TempConsoPickSlip.Storerkey, #TempConsoPickSlip.Orderkey, #TempConsoPickSlip.Loc, #TempConsoPickSlip.AltSKU --, BOM.Qty, #TempConsoPickSlip.Qty, Remaining = (#TempConsoPickSlip.Qty % BOM.Qty)
						FROM   #TempConsoPickSlip
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempConsoPickSlip.Sku 
																			    AND BOM.Sku = #TempConsoPickSlip.AltSku
																				 AND BOM.Storerkey = #TempConsoPickSlip.Storerkey 
						WHERE  CartonGroup = 'PREPACK'
						AND    ErrFlag = ''
						GROUP BY #TempConsoPickSlip.Storerkey, #TempConsoPickSlip.Orderkey, #TempConsoPickSlip.Loc, #TempConsoPickSlip.AltSKU, BOM.Qty, #TempConsoPickSlip.Qty, (#TempConsoPickSlip.Qty % BOM.Qty)
						HAVING (#TempConsoPickSlip.Qty % BOM.Qty) > 0
						) BadRatio
				GROUP BY BadRatio.Storerkey, BadRatio.Orderkey, BadRatio.Loc, BadRatio.AltSKU 
 			  ) AS Prob
 		WHERE Prob.Loc = #TempConsoPickSlip.Loc 
		AND 	Prob.AltSku = #TempConsoPickSlip.AltSKU 
		AND   Prob.Orderkey = #TempConsoPickSlip.Orderkey
		AND   Prob.Storerkey = #TempConsoPickSlip.Storerkey
      AND   CartonGroup = 'PREPACK'
		AND   ErrFlag = ''
	END

	-- Calc PackUOM* and UOM qty 
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		SET @c_PrevLoc = ''
		SET @c_PrevStyle = ''	
		SET @c_PrevPPKInd = ''
		SET @c_PrevCartonGroup = ''
		SET @c_PrevZone = ''
		SET @c_PrevFacility = ''
		SET @b_LastRec = '0'
      SET @c_PrevColor = ''
      SET @c_PrevBusr8 = ''
	
		SELECT Loadkey, LoadPickSlipNo, StorerKey, Company, Facility, 
		       Route, LoadPlanAddDate, LoadPrintedFlag, --Putawayzone, -- Vicky02
             CartonGroup, 
		       CASE WHEN CartonGroup = 'PREPACK' AND LEFT(ErrFlag, 1) <> 'E' THEN AltSku 
						Else SKU END As AltSKU, 
				 Style, loc, Qty = SUM(Qty), Lottable01, Lottable02, Lottable03, 	
		       TotalAllocateQty, TotalOrderQty, Pallet, Shipper, Casecnt, InnerPack, ErrFlag = Max(ErrFlag), LogicalLoc = ISNULL(LogicalLoc, '')
             --,BUSR8, Color
		INTO   #TempConsoPickSlip2
		FROM   #TempConsoPickSlip
		WHERE  LoadKey = @c_LoadKey
		GROUP BY Loadkey, LoadPickSlipNo, StorerKey, Company, Facility, 
					Route, LoadPlanAddDate, LoadPrintedFlag, --Putawayzone, 
               CartonGroup, 
		       	CASE WHEN CartonGroup = 'PREPACK' AND LEFT(ErrFlag, 1) <> 'E' THEN AltSku 
							Else SKU END, 
					 Style, loc, LogicalLoc, Lottable01, Lottable02, Lottable03, 	
					 TotalAllocateQty, TotalOrderQty, Pallet, Shipper, Casecnt, InnerPack--, BUSR8, Color
      ORDER BY Storerkey, LogicalLoc, Loc, Lottable03, Style--, BUSR8, Color	
		
		IF @b_Debug = 1
		BEGIN
			PRINT '#TempConsoPickSlip2'
			SELECT * FROM #TempConsoPickSlip2
		END

		DECLARE conso_calcqty_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
		SELECT #TempConsoPickSlip2.LoadPickSlipNo, #TempConsoPickSlip2.StorerKey, #TempConsoPickSlip2.Company, #TempConsoPickSlip2.Facility, 
		       #TempConsoPickSlip2.Route, #TempConsoPickSlip2.LoadPlanAddDate, #TempConsoPickSlip2.LoadPrintedFlag, --Putawayzone, 
             #TempConsoPickSlip2.CartonGroup, 
		       #TempConsoPickSlip2.AltSKU, #TempConsoPickSlip2.Style, #TempConsoPickSlip2.loc, #TempConsoPickSlip2.Qty, 
             #TempConsoPickSlip2.Lottable01, #TempConsoPickSlip2.Lottable02, #TempConsoPickSlip2.Lottable03, 	
		       #TempConsoPickSlip2.TotalAllocateQty, #TempConsoPickSlip2.TotalOrderQty, #TempConsoPickSlip2.Pallet, 
             #TempConsoPickSlip2.Shipper, #TempConsoPickSlip2.Casecnt, #TempConsoPickSlip2.InnerPack, #TempConsoPickSlip2.ErrFlag, 
             #TempConsoPickSlip2.LogicalLoc--, BUSR8, Color
		FROM   #TempConsoPickSlip2
      JOIN   SKU (NOLOCK) ON (SKU.Storerkey = #TempConsoPickSlip2. Storerkey AND SKU.SKU = #TempConsoPickSlip2.AltSKU)
		WHERE  LoadKey = @c_LoadKey
--		ORDER BY Storerkey, Putawayzone, LogicalLoc, Loc, Style, Lottable03	
		ORDER BY #TempConsoPickSlip2.Storerkey, #TempConsoPickSlip2.LogicalLoc, #TempConsoPickSlip2.Loc,  
      #TempConsoPickSlip2.Lottable03, #TempConsoPickSlip2.Style, SKU.Color, SKU.BUSR8


		OPEN conso_calcqty_cur
		FETCH NEXT FROM conso_calcqty_cur INTO  @c_LoadPickHeaderKey, @c_Storerkey, @c_Company, @c_Facility,
							@c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, --@c_PutawayZone, 
                     @c_CartonGroup,
							@c_AltSku, @c_Style, @c_loc, @n_Qty, @c_Lottable01, @c_Lottable02, @c_Lottable03,
							@n_SumAllocatedQty, @n_SumOriginalQty, @f_Pallet, @f_OtherUnit1, @f_Casecnt, @f_InnerPack, @c_ErrFlag, @c_Logicalloc
                     --@c_busr8, @c_color1
	
		WHILE (@@FETCH_STATUS <> -1)
		BEGIN		
			IF @b_debug = 1
			BEGIN
				Select @c_Loc '@c_Loc', @c_Style '@c_Style', @c_Lottable03 '@c_Lottable03', @c_CartonGroup '@c_CartonGroup',
						 @c_PrevLoc '@c_PrevLoc', @c_PrevStyle '@c_PrevStyle', @c_PrevPPKInd '@c_PrevPPKInd', @c_PrevCartonGroup '@c_PrevCartonGroup', @c_PrevZone '@c_PrevZone',
                   @c_PrevColor '@c_PrevColor', @c_PrevBusr8 '@c_PrevColor'
			END 
	
			IF (@c_PrevLoc <> @c_Loc) OR (@c_PrevLoc = '') OR (@c_PrevStyle <> @c_Style) OR (@c_PrevStyle = '') 
			OR (@c_PrevPPKInd <> @c_Lottable03) OR (@c_PrevPPKInd = '') --OR 
            --(@c_PrevColor <> @c_Color1) OR (@c_PrevColor = '') OR (@c_PrevBusr8 <> @c_busr8) OR (@c_PrevBusr8 = '')
			BEGIN
				IF @c_CartonGroup = 'PREPACK' -- AND @c_PrevPPKInd <> @c_Lottable03
				BEGIN
					SELECT @n_BOMQty = ISNULL(SUM(Qty), 0)
					FROM   BillOfMaterial WITH (NOLOCK)
					WHERE  Storerkey = @c_Storerkey
					AND    Sku = @c_AltSKU
				END			
	
			GetBOM:
			IF @b_debug = 1
			BEGIN
				Select 'GETBOM', @c_Loc '@c_Loc', @c_Style '@c_Style', @c_Lottable03 '@c_Lottable03', @c_CartonGroup '@c_CartonGroup',
						 @c_PrevLoc '@c_PrevLoc', @c_PrevStyle '@c_PrevStyle', @c_PrevPPKInd '@c_PrevPPKInd', @c_PrevCartonGroup '@c_PrevCartonGroup', @c_PrevZone '@c_PrevZone'
			END 

				IF @c_PrevLoc > '' AND @c_PrevStyle > '' AND @c_PrevPPKInd > ''
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
							ORDER BY SKU.Color, SKU.BUSR8--SKU.Size 
			
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
									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_PrevFacility, --@c_PrevZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
											 SPACE(15) + '|' + '    SZ    ' + '|' + LEFT(dbo.fnc_RTrim(@c_DispSize) +  REPLICATE('', 70), 70), 'B1')
	
									-- BOM Box 1 : COLOUR
									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_PrevFacility, --@c_PrevZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
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
							INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
															Company, Facility, ---Putawayzone, 
                                             TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
									 @c_Company, @c_PrevFacility,-- @c_PrevZone, 
                            @n_SumAllocatedQty, @n_SumOriginalQty, 
									 SPACE(15) + '|' + '    SZ    ' + '|' + LEFT(dbo.fnc_RTrim(@c_DispSize) +  REPLICATE('', 70), 70), 'B1')

							-- BOM Box 2 : COLOUR
							INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
															Company, Facility, --Putawayzone, 
                                             TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
									 @c_Company, @c_PrevFacility, --@c_PrevZone, 
                            @n_SumAllocatedQty, @n_SumOriginalQty, 
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
						INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
													Company, Facility, --Putawayzone, 
                                       TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag,  @c_Storerkey,
								  @c_Company, @c_PrevFacility, --@c_PrevZone, 
                          @n_SumAllocatedQty, @n_SumOriginalQty, 
								  REPLICATE('-', 150), '')
					END
				END -- @c_PrevLoc > '' AND @c_PrevStyle > '' AND @c_PrevPPKInd > ''						
	
				IF @b_LastRec = '1'
				BEGIN				
					GOTO Resume_Process				
				END
	
				SET @c_PrevLoc    = @c_Loc
				SET @c_PrevStyle  = @c_Style
				SET @c_PrevPPKInd = @c_Lottable03
				SET @c_PrevCartonGroup = @c_CartonGroup
				--SET @c_PrevZone = @c_Putawayzone
				SET @c_PrevFacility = @c_Facility
				SET @n_TotalEAQty  = 0
				SET @n_TotalUOMQty = 0						
				SET @n_TotalPPKQty = 0						
				SET @b_Repeat = '1'
--            SET @c_PrevBusr8 = @c_busr8
--            SET @c_PrevColor = @c_color1
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
					SELECT 'Before PackUOM*', @c_PrevPPKInd '@c_PrevPPKInd', @n_Qty '@n_Qty', @n_RemainQty '@n_RemainQty',  @c_PrevCartonGroup '@c_PrevCartonGroup', CONVERT(CHAR(10), @f_Pallet) '@f_Pallet', CONVERT(CHAR(10), @f_OtherUnit1) '@f_OtherUnit1', CONVERT(CHAR(
10), @f_Casecnt) '@f_Casecnt', CONVERT(CHAR(10), @f_InnerPack) '@f_InnerPack'
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
						GOTO Insert_t_Conso
	
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
						GOTO Insert_t_Conso
	
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
						GOTO Insert_t_Conso
	
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
						GOTO Insert_t_Conso
	
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
						GOTO Insert_t_Conso

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
		
			   Insert_t_Conso:
					-- Display 'Allocation Problem message & show all components as LOOSE'
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
                  ORDER BY Style, Color, BUSR8, Measurement

						IF @c_CartonGroup = 'PREPACK' AND LEFT(@c_ErrFlag, 1) <> 'E'
						BEGIN
							IF @b_Repeat = '1'
							BEGIN
								-- New PPK Detail 1
                        -- Modified By Vicky on 09-Oct-2007 (Start)
								INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																Company, Facility, --Putawayzone, 
                                                TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
										 @c_Company, @c_Facility, --@c_PutawayZone, 
                               @n_SumAllocatedQty, @n_SumOriginalQty, 
										 CONVERT(CHAR(12), ISNULL(dbo.fnc_RTrim(@c_Loc), '')) + CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + 
                               CONVERT(CHAR(50), ISNULL(LEFT(dbo.fnc_RTrim(@c_Busr1),50), '')) +
                               CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +  --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + 
                               SPACE(3) + CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 'PCs' + SPACE(18) + -- Vicky02
										 LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_UOMQty)) + REPLICATE('', 10), 10) + 
										 LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_EAQty)) + REPLICATE('', 10), 10), '')
		
								-- New PPK Detail 2
								INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																Company, Facility, --Putawayzone, 
                                                TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
										 @c_Company, @c_Facility,-- @c_PutawayZone, 
                               @n_SumAllocatedQty, @n_SumOriginalQty, 
										 SPACE(62) + CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) + CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) +
										 CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')), '')
		
							    SET @b_Repeat = '0'
							END 
							ELSE
							BEGIN
								-- Repeat PPK Detail
								INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																Company, Facility,-- Putawayzone, 
                                                TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
										 @c_Company, @c_Facility, --@c_PutawayZone, 
                               @n_SumAllocatedQty, @n_SumOriginalQty, 
										 SPACE(37) +  
										 CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) +  CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) + 
                               CONVERT(CHAR(20), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')) + 
                               CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +  --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + -- Vicky02
                               SPACE(3) + CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 'PCs' +  SPACE(18) + 
										 LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_UOMQty)) + REPLICATE('', 10), 10) + 
										 LEFT(dbo.fnc_RTrim(CONVERT(CHAR(10), @n_EAQty)) + REPLICATE('', 10), 10), '')
							END							 
						END
						ELSE -- Print Loose
						BEGIN		
							IF @b_Repeat = '1'
							BEGIN
								-- Loose Item Detail 1
								INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																Company, Facility, --Putawayzone, 
                                                TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
-- 								VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
-- 										 @c_Company, @c_Facility, --@c_PutawayZone, 
--                                @n_SumAllocatedQty, @n_SumOriginalQty, 
-- 										 CONVERT(CHAR(12), ISNULL(dbo.fnc_RTrim(@c_Loc), '')) + CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + 
--                                CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 
--                                CONVERT(CHAR(60), ISNULL(dbo.fnc_RTrim(@c_Busr1), '')) + CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +
-- 										 CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')), '' )


                        VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
										 @c_Company, @c_Facility,-- @c_PutawayZone, 
                               @n_SumAllocatedQty, @n_SumOriginalQty, 
										 CONVERT(CHAR(12), ISNULL(dbo.fnc_RTrim(@c_Loc), '')) + CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + 
                             CONVERT(CHAR(50), ISNULL(LEFT(dbo.fnc_RTrim(@c_Busr1),50), '')) + CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +
                               --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per) + 
                               SPACE(3) + CONVERT(CHAR(5), ISNULL(@n_NoOfUnits, '')) + 'PCs', '')
							END			
                     -- Modified By Vicky on 09-Oct-2007 (End)
							IF @c_ErrFlag = 'E1'
							BEGIN
								IF @b_Repeat = '1'
								BEGIN
									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_Facility, --@c_PutawayZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
											 SPACE(150), '')

									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_Facility, --@c_PutawayZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
											 SPACE(12) + '*** Allocation Error : No Of Prepack Allocated Different Among Component SKUs ***', '')

									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_Facility, --@c_PutawayZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
											 SPACE(150), '')
								END	
							END
							ELSE IF @c_ErrFlag = 'E2'
							BEGIN
								IF @b_Repeat = '1'
								BEGIN
									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_Facility, --@c_PutawayZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
											 SPACE(150), '')

									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_Facility, --@c_PutawayZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
											 SPACE(12) + '*** Allocation Error : Bad Prepack Ratio Allocated In Component SKUs ***', '')

									INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
																	Company, Facility, --Putawayzone, 
                                                   TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
											 @c_Company, @c_Facility, --@c_PutawayZone, 
                                  @n_SumAllocatedQty, @n_SumOriginalQty, 
											 SPACE(150), '')
								END	
							END 

							-- Loose Item Detail 2
							INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
															Company, Facility, --Putawayzone,
                                             TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
									 @c_Company, @c_Facility, --@c_PutawayZone, 
                            @n_SumAllocatedQty, @n_SumOriginalQty, 
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
							INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
															Company, Facility, --Putawayzone, 
                                             TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES  (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag, @c_Storerkey,
										@c_Company, @c_Facility, --@c_PutawayZone, 
                              @n_SumAllocatedQty, @n_SumOriginalQty, 
										REPLICATE('-', 150), '')
						END
					END -- Insert_t_Conso : FLOOR(@n_Qty / @n_NoOfUnits) > 0
			END -- While @n_RemainQty > 0
			-- Calculate PackUOM* End Here
			
			FETCH NEXT FROM conso_calcqty_cur INTO  @c_LoadPickHeaderKey, @c_Storerkey, @c_Company, @c_Facility,
								@c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag,-- @c_PutawayZone,
                        @c_CartonGroup,
								@c_AltSku, @c_Style, @c_loc, @n_Qty, @c_Lottable01, @c_Lottable02, @c_Lottable03,
								@n_SumAllocatedQty, @n_SumOriginalQty, @f_Pallet, @f_OtherUnit1, @f_Casecnt, @f_InnerPack, @c_ErrFlag, @c_Logicalloc
                       -- @c_busr8, @c_color1
	
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
			-- Seperator Dotted Line for Last record
			INSERT INTO @t_ConsoPS (LoadPickSlipNO, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey,
										Company, Facility, --Putawayzone, 
                              TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
			VALUES (@c_LoadPickHeaderKey, @c_Loadkey, @c_Route, @d_LoadPlanAddDate, @c_LoadPrintedFlag,  @c_Storerkey,
					 @c_Company, @c_PrevFacility, --@c_PrevZone, 
                @n_SumAllocatedQty, @n_SumOriginalQty, 
					 REPLICATE('-', 150), '')
		END

		CLOSE conso_calcqty_cur
		DEALLOCATE conso_calcqty_cur		
	END -- @n_continue = 1 OR @n_continue = 2
	-- End : June01
	
	IF @n_continue <> 3 AND @n_err = 0
	BEGIN
		WHILE @@TRANCOUNT > 0
		BEGIN
			COMMIT TRAN
		END
	END
	ELSE
	BEGIN
		ROLLBACK TRAN
	END
  
	-- Start : June01
	/*
	SELECT 	LoadPickSlipNo, LoadKey, StorerKey, Facility, Company, 
				Route, LoadPlanAddDate, LoadPrintedFlag, CartonGroup, UserDefine03, UserDefine04, 
				DisplaySku, Style, Color, Busr1, Measurement, Size, 
				Loc, ID, SUM(Qty) Qty,  
				Lottable01, Lottable02, Lottable03, Lottable05,
				TotalAllocateQty, TotalOrderQty, Pallet, Casecnt, sUser_sName() UserId
	FROM #TempConsoPickSlip
	GROUP BY LoadPickSlipNo, LoadKey, StorerKey, Facility, Company, 
				Route, LoadPlanAddDate, LoadPrintedFlag, CartonGroup, UserDefine03, UserDefine04, 
				DisplaySku, Style, Color, Busr1, Measurement, Size, 
				Loc, ID, 
				Lottable01, Lottable02, Lottable03, Lottable05,
				TotalAllocateQty, TotalOrderQty, Pallet, Casecnt
	*/

 	SELECT RowID, LoadPickSlipNo, Loadkey, Route, LoadPlanAddDate, LoadPrintedFlag, Storerkey, Company, Facility, --Putawayzone, 
      TotalAllocateQty, TotalOrderQty -- * 	
    , LineText, LineFlag
	-- 	SELECT LineText
 	FROM  @t_ConsoPS
 	ORDER BY RowID
	-- End : June01

	DROP TABLE #TempConsoPickSlip
	DROP TABLE #TempConsoPickSlip2 -- June01
END





GO