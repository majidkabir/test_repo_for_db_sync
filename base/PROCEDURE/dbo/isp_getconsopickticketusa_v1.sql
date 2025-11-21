SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetConsoPickTicketUSA_V1                       */
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
/* 12-Oct-2007  Vicky     Fix on the Prepack Qty calculation (Vicky01)  */
/* 24-Oct-2007  Vicky     Take out grouping by Orderkey (Vicky02)       */
/* 30-Oct-2007  Shong     Reverse back Vicky changes on 24-Oct-2007     */ 
/* 30-Nov-2007  Ricky     To remove the Userdefine03 in the group       */   
/*                        when insert #TempConsoPickSlip2 to resolve    */   
/*                        the missing qty when having same prepack      */  
/* 27-Jun-2008  TLTING	  consider lottable02 in totpick calcalation    */	
/* 15-Jul-2010  KHLim     Replace USER_NAME to sUSER_sName              */ 
/* 20-Jul-2010  KHLim     Synronize version of PVCS to US Live DB       */ 
/* 20-Jul-2010  Ricky     Include Lottable02 in the Fetch (Ricky072010) */ 
/* 21-Jul-2010  KHLim     fix bug (KHLim01)                             */ 
/* 17-Dec-2013  NJOW01    Fix commit issue                              */
/************************************************************************/

CREATE PROC [dbo].[isp_GetConsoPickTicketUSA_V1] ( 
            @c_LoadKey  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE 	@n_continue int,
				@c_errmsg NVARCHAR(255),
				@b_success int,
				@n_err int,
				@c_LoadPickHeaderKey NVARCHAR(10),
				@c_OrderPickHeaderKey NVARCHAR(10),
				@c_OrderKey NVARCHAR(10),
				@c_LoadPrintedFlag NVARCHAR(1),
				@c_OrderPrintedFlag NVARCHAR(1),
				@c_Prepack NVARCHAR(1),
				@c_StorerKey NVARCHAR(15),
				@c_Sku NVARCHAR(20), 
				@c_Facility NVARCHAR(5), 
				@c_Company NVARCHAR(45), 
				@c_Route NVARCHAR(10), 
				@d_LoadPlanAddDate DateTime,
				@c_tpickslipno NVARCHAR(10),
				@n_SumOriginalQty int,
				@n_SumAllocatedQty int,
				@n_OriginalQty int,
				@n_AllocatedQty int,
				@n_RowId int,
				@c_AltSku NVARCHAR(20),
				@c_CartonGroup NVARCHAR(10),
				@c_UserDefine03 NVARCHAR(18),
				@c_UserDefine04 NVARCHAR(18),
				@f_Pallet int,
				@f_Casecnt int,
				@f_OtherUnit1 float,
				@f_InnerPack int,
				@f_EachQty float,
				@f_PrepackCnt float,
				@n_TotalExpQty int,
			 	@c_tempOrderKey NVARCHAR(10)

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
						Busr8 NVARCHAR(30) NULL, -- June01
						Loc NVARCHAR(10),
						LogicalLocation NVARCHAR(18) NULL, -- June01
						ID NVARCHAR(18) NULL,
						Qty int NULL,
						Lottable01 NVARCHAR(18) NULL,
						Lottable02 NVARCHAR(18) NULL,
						Lottable03 NVARCHAR(18) NULL,
						Lottable05 datetime NULL,
						TotalAllocateQty int NULL,
						TotalOrderQty int NULL,
						Pallet    int NULL,
						Casecnt   int NULL, 
                  InnerPack int NULL, 
                  Eaches   int NULL, 
                  TotQty    int NULL,
                  Prepack   int NULL -- Vicky01  
					 )
-- Vicky02
CREATE TABLE #TempConsoPickSlip2
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
						Busr8 NVARCHAR(30) NULL, -- June01
						Loc NVARCHAR(10),
						LogicalLocation NVARCHAR(18) NULL, -- June01
						ID NVARCHAR(18) NULL,
						Qty int NULL,
						Lottable01 NVARCHAR(18) NULL,
						Lottable02 NVARCHAR(18) NULL,
						Lottable03 NVARCHAR(18) NULL,
						Lottable05 datetime NULL,
						TotalAllocateQty int NULL,
						TotalOrderQty int NULL,
						Pallet    int NULL,
						Casecnt   int NULL, 
                  InnerPack int NULL, 
                  Eaches    int NULL, 
                  TotQty    int NULL,
                  Prepack   int NULL -- Vicky01  
					 )

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
			FROM PickHeader WITH (NOLOCK)
			WHERE ExternOrderKey = @c_LoadKey
			AND Zone = 'C'
		END --@c_LoadPrintedFlag = 'Y' 				
	END -- End Generate PickSlip#

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
						Busr8, -- June01
						Loc,
						Logicallocation, -- June01
						ID,
						Qty,
						Lottable01,
						Lottable02,
						Lottable03,
						Lottable05 )
			SELECT	@c_LoadPickHeaderKey,
						@c_LoadKey,
						ORDERS.OrderKey, 
						ORDERS.StorerKey, 
						ORDERS.Facility, 
						STORER.Company, 
						LOADPLAN.Route, 
						LOADPLAN.AddDate,
						@c_LoadPrintedFlag,
						PICKDETAIL.AltSku,
						UPPER(PICKDETAIL.CartonGroup),
						OrderDetail.UserDefine03,
						OrderDetail.UserDefine04,
						SKU.SKU,
						SKU.Style,
						SKU.Color,
						SKU.Susr3,
						SKU.Busr1,
						SKU.Measurement,
						SKU.Size,
						SKU.Busr8, -- June01
						PICKDETAIL.Loc,
						ISNULL(LOC.LogicalLocation, ''), -- June01
						PICKDETAIL.ID,
						SUM(PICKDETAIL.Qty) PickQty,
						LOTATTRIBUTE.LOTTABLE01,
						LOTATTRIBUTE.LOTTABLE02,
						LOTATTRIBUTE.LOTTABLE03,
						LOTATTRIBUTE.LOTTABLE05
				FROM ORDERS WITH (NOLOCK) 
            JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY)
            JOIN PICKDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = PICKDETAIL.OrderKey AND 
                                              ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
            JOIN STORER WITH (NOLOCK) ON (PICKDETAIL.StorerKey = STORER.StorerKey)
            JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.SKU = SKU.SKU)
            JOIN LOTATTRIBUTE WITH (NOLOCK) ON (PICKDETAIL.Lot = LOTATTRIBUTE.Lot AND 
                                                SKU.SKU = LOTATTRIBUTE.SKU AND 
                                                SKU.StorerKey = LOTATTRIBUTE.StorerKey)
            JOIN LOADPLAN WITH (NOLOCK) ON (ORDERS.LoadKey = LOADPLAN.LoadKey)
            JOIN LOADPLANDETAIL WITH (NOLOCK) ON (LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey AND 
                                                  LOADPLANDETAIL.Orderkey = ORDERS.OrderKey)
				JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PICKDETAIL.LOC) -- June01
				WHERE PICKDETAIL.Status < '9'  -- KHLim01
				AND LOADPLANDETAIL.LoadKey = @c_LoadKey
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
							SKU.Busr8, -- June01
							PICKDETAIL.Loc,
							LOC.LogicalLocation, -- June01
							PICKDETAIL.ID,
							LOTATTRIBUTE.LOTTABLE01,
							LOTATTRIBUTE.LOTTABLE02,
							LOTATTRIBUTE.LOTTABLE03,
							LOTATTRIBUTE.LOTTABLE05

		SELECT @n_err = @@ERROR
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			IF @@TRANCOUNT >= 1
			BEGIN
				ROLLBACK TRAN
			END
		END
	END -- Create TempConsoPickSlip Table

	SELECT @c_tempOrderKey = ''

	-- Check Order-PickHeader Exists, if not exists assign new pickslipno for each order
	-- Check Prepack, if Prepack PickSlipNo LIKE 'T%', convert Prepack Temporary PickSlipNo-'T%' to Actual PickSlipNo  
	DECLARE conso_order_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT OrderKey, RowId, Storerkey, Sku, AltSku, CartonGroup
	FROM #TempConsoPickSlip
	WHERE LoadKey = @c_LoadKey
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
			IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE OrderKey = @c_OrderKey AND Zone = 'D')
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
			AND Zone = 'D'
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
					(PickHeaderKey, Orderkey, PickType, Zone, TrafficCop)
					VALUES
					(@c_OrderPickHeaderKey, @c_OrderKey, '0', 'D', '')

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
						FROM PICKDETAIL 
						WHERE Orderkey = @c_OrderKey
				        AND Status < '9'  -- KHLim01
						AND ISNULL(dbo.fnc_RTrim(Pickslipno),'') = ''
	
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
					FROM PickHeader WITH (NOLOCK)
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
					FROM PACKHEADER PACK WITH (NOLOCK)
					JOIN PICKHEADER PICK WITH (NOLOCK)
					ON (PACK.Orderkey = PICK.Orderkey)
					WHERE PACK.PickSlipNo LIKE 'T%'
					AND PICK.PickHeaderKey = @c_OrderPickHeaderKey
				
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
						FROM PACKHEADER PACK WITH (NOLOCK)
						JOIN PICKHEADER PICK WITH (NOLOCK) ON (PACK.Orderkey = PICK.Orderkey)
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
				FROM ORDERDETAIL WITH (NOLOCK)
				WHERE Orderkey = @c_OrderKey

				SELECT @n_AllocatedQty = SUM(Qty)
				FROM PICKDETAIL WITH (NOLOCK)
				WHERE Orderkey = @c_OrderKey
				AND Status < '9'  -- KHLim01

				SELECT @n_SumOriginalQty = @n_SumOriginalQty + @n_OriginalQty
				SELECT @n_SumAllocatedQty = @n_SumAllocatedQty + @n_AllocatedQty
			END

		END --IF @c_tempOrderKey <> @c_OrderKey


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
	
-----------------------------
   DECLARE @c_PrevLoc         NVARCHAR(10),
			  @c_PrevCartonGroup NVARCHAR(10),
           @c_PrevID          NVARCHAR(18),
           @c_PrevAltSKU      NVARCHAR(20), 
           @c_PrevOrderKey    NVARCHAR(10), 
           @c_PrevUserDefine03 NVARCHAR(18),
           @c_Loc             NVARCHAR(10), 
           @c_ID              NVARCHAR(18), 
           @c_Style           NVARCHAR(20),
           @n_BOMQty          int, 
           @n_Qty             int, 
           @c_Color           NVARCHAR(10),    
           @c_Busr8           NVARCHAR(18), 
           @c_Measurement     NVARCHAR(5), 
           @n_BundleQty       int,
           @n_LooseQty        int,
           @n_PalletQty       int, 
           @n_CaseQty         int,
           @n_TotBOMQty       int, 
           @n_TotPickQty      int,
           @n_InnerQty        int,
           @n_PrepackQty      int       

-- Added TLTING 2008/6/27 
   DECLARE @c_Lottable02      NVARCHAR(18) ,
			  @c_PrevLottable02  NVARCHAR(18)

   SET @c_PrevLottable02 = ''

   SET @c_PrevCartonGroup = ''
   SET @c_PrevLoc = ''
   SET @c_PrevID = ''
   SET @c_PrevAltSKu = ''
   SET @c_PrevOrderKey = ''

-- Vicky02
		INSERT INTO #TempConsoPickSlip2 
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
						Busr8, -- June01
						Loc,
						Logicallocation, -- June01
						ID,
						Qty,
						Lottable01,
						Lottable02,
						Lottable03,
						Lottable05,
                  TotalAllocateQty,
                  TotalOrderQty)
      SELECT      LoadPickSlipNo,
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
                        '' UserDefine03,  -- KHLim01  
						UserDefine04,
						SKU,
						Style,
						Color,
						Susr3,
						Busr1,
						Measurement,
						Size,
						Busr8, -- June01
						Loc,
						Logicallocation, -- June01
						[ID],
						SUM(Qty),
						Lottable01,
						Lottable02,
						Lottable03,
						Lottable05,
                  TotalAllocateQty,
                  TotalOrderQty
       FROM #TempConsoPickSlip (NOLOCK)
       GROUP BY   LoadPickSlipNo,
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
--						UserDefine03, -- KHLim01
						UserDefine04,
						SKU,
						Style,
						Color,
						Susr3,
						Busr1,
						Measurement,
						Size,
						Busr8, -- June01
						Loc,
						Logicallocation, -- June01
						ID,
						Lottable01,
						Lottable02,
						Lottable03,
						Lottable05,
                  TotalAllocateQty,
                  TotalOrderQty

	DECLARE conso_pickslip_sort CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT Rowid, OrderKey, Storerkey, AltSku, Lottable02, CartonGroup, Loc, ID, Style, color, busr8, measurement, SKU, Qty
	FROM #TempConsoPickSlip2 -- Vicky02
	WHERE LoadKey = @c_LoadKey
	ORDER BY OrderKey, Loc, ID, AltSku, Lottable02, Style, color, busr8, measurement 
   --ORDER BY  Loc, ID, AltSku, Style, color, busr8, measurement -- Vicky02
  -- Added TLTING Lottable02  2008/6/27
	OPEN conso_pickslip_sort

   -- Ricky072010
	FETCH NEXT FROM conso_pickslip_sort INTO @n_RowId, @c_OrderKey, @c_Storerkey, @c_AltSku, @c_Lottable02, @c_CartonGroup, @c_Loc, 
            @c_ID, @c_Style, @c_Color, @c_Busr8, @c_Measurement, @c_SKU, @n_Qty  -- Vicky02

	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF dbo.fnc_RTrim(@c_CartonGroup) = 'PREPACK' AND ISNULL(dbo.fnc_RTrim(@c_AltSku),'') <> '' 
		BEGIN
         IF @c_PrevCartonGroup <> @c_CartonGroup OR 
            @c_PrevLoc <> @c_Loc OR 
            @c_PrevID <> @c_ID OR 
            @c_PrevAltSKu <> @c_AltSku OR 
			   @c_PrevLottable02 <> @c_Lottable02 OR	-- TLTING 2008/6/27  - as one of the slit calculateion
            @c_PrevOrderKey <>  @c_OrderKey
         BEGIN 
            SELECT @c_PrevCartonGroup = @c_CartonGroup, 
                   @c_PrevLoc = @c_Loc,
                   @c_PrevID = @c_ID,
                   @c_PrevAltSKu = @c_AltSku, 
                   @c_PrevOrderKey =  @c_OrderKey,
					    @c_PrevLottable02 = @c_Lottable02 -- TLTING 2008/6/27

			   -- Check Prepack  
            SELECT @n_TotBOMQty = SUM(Qty)
            FROM   BillOfMaterial BOM WITH (NOLOCK) 
            WHERE  BOM.Storerkey = @c_Storerkey 
            AND    BOM.SKU = @c_AltSku 
 
            SELECT @n_BOMQty = Qty
            FROM   BillOfMaterial BOM WITH (NOLOCK) 
            WHERE  BOM.Storerkey = @c_Storerkey 
            AND    BOM.SKU = @c_AltSku 
            AND    BOM.ComponentSKU = @c_SKU 


            SELECT @f_Pallet  = 0.0
            SELECT @f_Casecnt = 0.0
            SELECT @f_InnerPack = 0.0 -- Vicky01

				--Get Parrent Sku - Pallet, CaseCnt		
				SELECT 	-- @f_Pallet = PACK.Pallet, 
							@f_Casecnt = PACK.Casecnt,
                     @f_InnerPack = PACK.InnerPack -- Vicky01
				FROM SKU WITH (NOLOCK)
            JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
				WHERE SKU.StorerKey = @c_Storerkey
				AND SKU.Sku = @c_AltSku

				IF ISNULL(dbo.fnc_RTrim(@f_Pallet),'') = '' 
				BEGIN
					SELECT @f_Pallet = 0.0
				END 

				IF ISNULL(dbo.fnc_RTrim(@f_Casecnt),'') = '' 
				BEGIN
					SELECT @f_Casecnt = 0.0
				END

            -- Vicky01
				IF ISNULL(dbo.fnc_RTrim(@f_InnerPack),'') = '' 
				BEGIN
					SELECT @f_InnerPack = 0.0
				END

            -- Convert to Bundle Qty 
            SET @n_BundleQty = @n_Qty / @n_BOMQty 
            -- Calculate Total Eaches in All the Bundle
            SET @n_TotBOMQty = @n_BundleQty * @n_TotBOMQty 
            -- Calculcate Loose Unit 
            SET @n_LooseQty  = @n_Qty % @n_BOMQty
            
            SET @n_TotPickQty = ISNULL(@n_TotBOMQty,0) + ISNULL(@n_LooseQty, 0) 

            IF @n_BundleQty >= @f_Pallet and @f_Pallet > 0 -- Vicky01
            BEGIN 
               SET @n_PalletQty = FLOOR(@n_BundleQty / @f_Pallet)
               SET @n_BundleQty = @n_BundleQty % @f_Pallet 
            END 
            ELSE
               SET @n_PalletQty = 0 

            IF @n_BundleQty >= @f_Casecnt and @f_Casecnt > 0 -- Vicky01
            BEGIN 
               SET @n_CaseQty = FLOOR(@n_BundleQty / @f_Casecnt)
               SET @n_BundleQty = @n_BundleQty % @f_Casecnt 
            END 
            ELSE
               SET @n_CaseQty = 0 
            
            -- Vicky01
            IF @n_BundleQty >= @f_InnerPack and @f_InnerPack > 0
            BEGIN 
           SET @n_InnerQty = FLOOR(@n_BundleQty / @f_InnerPack)
               SET @n_BundleQty = @n_BundleQty % @f_InnerPack 
            END 
            ELSE
               SET @n_InnerQty = 0 


   				UPDATE #TempConsoPickSlip2 -- Vicky02
   				SET 	Pallet  = @n_PalletQty,
   						Casecnt = @n_CaseQty,
   						DisplaySku = @c_AltSku, 
                     --InnerPack = @n_BundleQty, 
                     InnerPack = @n_InnerQty, -- Vicky01
                     Prepack   = @n_BundleQty,-- Vicky01 
                     Eaches    = @n_LooseQty, 
                     TotQty    = @n_TotPickQty 
   				WHERE Rowid = @n_RowId
			END 
      END
		ELSE
		BEGIN
			UPDATE #TempConsoPickSlip2 -- Vicky02
			SET 	DisplaySku = @c_Sku, 
               Eaches     = Qty, 
               TotQty     = Qty  
			WHERE Rowid = @n_RowId
		END

		-- Ricky072010
   	FETCH NEXT FROM conso_pickslip_sort INTO @n_RowId,  @c_OrderKey, @c_Storerkey, @c_AltSku, @c_Lottable02, @c_CartonGroup, @c_Loc, 
               @c_ID, @c_Style, @c_Color, @c_Busr8, @c_Measurement, @c_SKU, @n_Qty   -- Vicky02
   END -- While 
   CLOSE conso_pickslip_sort 
   DEALLOCATE conso_pickslip_sort 



-----------------------------
   
	SELECT 	LoadPickSlipNo, LoadKey, StorerKey, Facility, Company, 
				Route, LoadPlanAddDate, LoadPrintedFlag, CartonGroup, UserDefine03, UserDefine04, 
				CASE WHEN CartonGroup = 'PREPACK' THEN AltSKU ELSE SKU END As DisplaySKU, 
            Style, Color, Busr1, Measurement, Size, 
				Loc, ID, Qty, 
				Lottable01, Lottable02, Lottable03, Lottable05,
				TotalAllocateQty, TotalOrderQty,  sUser_sName() UserId, 
				LogicalLocation, Busr8, 
            Pallet,	Casecnt, InnerPack, Eaches, TotQty, Prepack -- Vicky01  
 	FROM #TempConsoPickSlip2 -- Vicky02
   ORDER By LogicalLocation, Loc, ID, Style, CASE WHEN CartonGroup = 'PREPACK' THEN AltSKU ELSE SKU END, Color, Busr8, Measurement


	DROP TABLE #TempConsoPickSlip
	DROP TABLE #TempConsoPickSlip2 -- Vicky02
END


GO