SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_GetDiscretePickTicketUSA_V2                    */
/* Creation Date: 22-Jul-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW                                                     */
/*                                                                      */
/* Purpose:  SOS#129705  - Discrete Pick Ticket for LFUSA.              */
/*           Modified from isp_GetDiscretePickTicketUSA_V1              */
/*                                                                      */
/* Called By:  PB - RCM                                                 */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author       Ver. Purposes                              */
/* 30 Apr 2009  Rick Liew    1.0  SOS#107784 - Added Storer.Notes1 field*/
/* 15-Jul-2010  KHLim     Replace USER_NAME to sUSER_sName              */ 
/************************************************************************/

CREATE PROC [dbo].[isp_GetDiscretePickTicketUSA_V2] (
            @c_LoadKey  NVARCHAR(10))
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
	

   DECLARE @b_debug int
   SET @b_debug = 0

	DECLARE 	@n_continue int,
				@c_errmsg NVARCHAR(255),
				@b_success int,
				@n_err int,
				@c_PickHeaderKey NVARCHAR(10),
				@c_OrderKey NVARCHAR(10),
				@c_Loc NVARCHAR(10),
				@c_Style NVARCHAR(20),
				@c_Color NVARCHAR(10),
				@c_Susr3 NVARCHAR(18),
				@c_Measurement NVARCHAR(5),
				@c_Size NVARCHAR(5),
				@n_qty int,
				@n_cnt int,
				@n_RunNumber int,
				@c_PrintedFlag NVARCHAR(1),
				@c_Userdefine04 NVARCHAR(18),
				@c_Sku NVARCHAR(20),
				@c_AltSku NVARCHAR(20),
				@c_CartonGroup NVARCHAR(10),
				@c_DisplaySku NVARCHAR(10),
				@n_ComponentQty int

	DECLARE 	@c_tempOrderKey NVARCHAR(10),
				@c_tempLoc NVARCHAR(10),
				@c_tempStyle NVARCHAR(20),
				@c_tempColor NVARCHAR(10),
				@c_tempSusr3 NVARCHAR(18),
				@c_tempMeasurement NVARCHAR(5),
				@c_tempUserdefine04 NVARCHAR(18),
				@c_tempSku NVARCHAR(20),
				@c_tempAltSku NVARCHAR(20),
				@c_tempCartonGroup NVARCHAR(10)
	
   DECLARE  @c_Lottable03 NVARCHAR(18),
            @c_Storerkey  NVARCHAR(15),
   	      @c_SKUBUSR8   NVARCHAR(30),
				@c_LogicalLoc NVARCHAR(18), -- June01
				@c_Busr1		  NVARCHAR(30), -- June01
				@c_Putawayzone NVARCHAR(10) -- June01

	CREATE TABLE #TempDiscretePickSlip
					( 	RunNumber int,
						PickSlipNo NVARCHAR(10),
						OrderKey NVARCHAR(10),
-- Commented Vicky01 (Start)
--						Loc NVARCHAR(10),
--						LogicalLocation NVARCHAR(18) NULL, -- June01
-- Commented Vicky01 (End)
						Sku NVARCHAR(20),
						Style NVARCHAR(20),
						Color NVARCHAR(10),
						Susr3 NVARCHAR(18),
						Measurement NVARCHAR(5) NULL,
						PrintedFlag NVARCHAR(1) NULL,
						Busr1 NVARCHAR(30), -- June01
-- Commented Vicky01 (Start)
--						Putawayzone NVARCHAR(10), -- June01
-- Commented Vicky01 (End)
						Size1 NVARCHAR(5) NULL,
						Qty1 int NULL,
						Size2 NVARCHAR(5) NULL,
						Qty2 int NULL,
						Size3 NVARCHAR(5) NULL,
						Qty3 int NULL,
						Size4 NVARCHAR(5) NULL,
						Qty4 int NULL,
						Size5 NVARCHAR(5) NULL,
						Qty5 int NULL,
						Size6 NVARCHAR(5) NULL,
						Qty6 int NULL,
						Size7 NVARCHAR(5) NULL,
						Qty7 int NULL,
						Size8 NVARCHAR(5) NULL,
						Qty8 int NULL,
						Size9 NVARCHAR(5) NULL,
						Qty9 int NULL,
						Size10 NVARCHAR(5) NULL,
						Qty10 int NULL,
						Size11 NVARCHAR(5) NULL,
						Qty11 int NULL,
                  CartonGroup NVARCHAR(10) NULL) -- Vicky01
-- Commented Vicky01 (Start)
                  -- BUSR8 NVARCHAR(30) NULL ) June01
-- Commented Vicky01 (End)

	SELECT @c_tempOrderKey = '', @c_tempLoc = '', @c_tempStyle = '', @c_tempColor = '', @c_tempSusr3 = '', 
          @c_tempMeasurement = ''
	SELECT @c_tempUserdefine04 = '', @c_tempSku = '', @c_tempAltSku = '', @c_tempCartonGroup = ''
	SELECT @n_RunNumber = 0 

	DECLARE discrete_pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT	ORDERS.OrderKey,
--				ORDERDETAIL.Userdefine04, -- Commented Vicky01
            ORDERDETAIL.Lottable03,
-- Commented Vicky01 (Start)
-- 				PICKDETAIL.Loc,
-- 				CASE 	WHEN UPPER(PICKDETAIL.CartonGroup) = 'PREPACK' AND ISNULL(dbo.fnc_RTrim(PICKDETAIL.AltSku),'') <> '' 
--                   THEN PICKDETAIL.AltSku 
-- 						ELSE PICKDETAIL.Sku
-- Commented Vicky01 (End)
            PICKDETAIL.Sku AS SKU,
				PICKDETAIL.CartonGroup,
				SUM(PICKDETAIL.Qty) Qty,
				SKU.Style,
				SKU.Color,
				SKU.Susr3,
				SKU.Measurement,
				SKU.Size, 
            PICKDETAIL.Storerkey,
            SKU.BUSR8, 
--				ISNULL(LOC.LogicalLocation, ''),  -- June01 -- Commented Vicky01
				SKU.Busr1 -- June01
--				LOC.Putawayzone -- June01 -- Commented Vicky01
	FROM PICKDETAIL WITH (NOLOCK) 
   JOIN ORDERS WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey)
   JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.OrderKey = ORDERDETAIL.OrderKey AND 
                                      PICKDETAIL.OrderLineNumber = ORDERDETAIL.OrderLineNumber)
   JOIN SKU WITH (NOLOCK) ON (PICKDETAIL.StorerKey = SKU.StorerKey AND PICKDETAIL.Sku = SKU.Sku)
   JOIN LOADPLANDETAIL WITH (NOLOCK) ON (PICKDETAIL.OrderKey = LOADPLANDETAIL.OrderKey)
   JOIN LOTATTRIBUTE WITH (NOLOCK) ON (LOTATTRIBUTE.Storerkey = PICKDETAIL.Storerkey AND 
                                       LOTATTRIBUTE.SKU = PICKDETAIL.SKU AND 
                                       LOTATTRIBUTE.LOT = PICKDETAIL.LOT)
--	JOIN LOC WITH (NOLOCK) ON (LOC.LOC = PICKDETAIL.LOC) -- June01 -- Commented Vicky01
	WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
	AND PICKDETAIL.Status < '5'
	GROUP BY ORDERS.OrderKey,
--				ORDERDETAIL.Userdefine04, -- Commented Vicky01
            ORDERDETAIL.Lottable03, -- Modified Vicky01
--				PICKDETAIL.Loc,
				PICKDETAIL.SKU,
				PICKDETAIL.AltSku,
				PICKDETAIL.CartonGroup,
				SKU.Style,
				SKU.Color,
				SKU.Susr3,
				SKU.Measurement,
				SKU.Size, 
            PICKDETAIL.Storerkey,
            SKU.BUSR8, 
--				LOC.LogicalLocation, -- June01  -- Commented Vicky01
				SKU.Busr1--, -- June01
--				LOC.Putawayzone -- June01
	ORDER BY PICKDETAIL.Storerkey, -- June01 -- Commented Vicky01
				ORDERS.OrderKey,
--				ORDERDETAIL.Userdefine04, -- Commented Vicky01
            -- LOTATTRIBUTE.Lottable03, June01 (remark this)
--				LOC.Putawayzone, -- June01
--				LOC.LogicalLocation, -- June01
				-- PICKDETAIL.Loc, 	 June01 (remark this)
				-- PICKDETAIL.SKU,    June01 (remark this)
				-- PICKDETAIL.AltSku, June01 (remark this)
				PICKDETAIL.CartonGroup, --June01 (remark this)
				SKU.Style,
				SKU.Color,
				
				-- SKU.Susr3, 				 June01 (remark this)
				--SKU.Measurement, 		 June01 (remark this)
--            SKU.BUSR8 -- June01
--				PICKDETAIL.SKU -- June01 -- Commented Vicky01
				SKU.Size --, 				 June01 (remark this)
            -- PICKDETAIL.Storerkey  June01 (remark this)

    	OPEN discrete_pick_cur
-- 	FETCH NEXT FROM discrete_pick_cur INTO @c_OrderKey, @c_Userdefine04, @c_Loc, @c_Sku, @c_CartonGroup, 
--                                           @n_qty, @c_Style, @c_Color, @c_Susr3, @c_Measurement, @c_Size
	FETCH NEXT FROM discrete_pick_cur INTO @c_OrderKey, @c_Lottable03, --@c_Loc, 
                                          @c_Sku, @c_CartonGroup, 
               @n_qty, @c_Style, @c_Color, @c_Susr3, @c_Measurement, @c_Size, 
														@c_Storerkey,
                                          @c_SKUBUSR8, 
														--@c_LogicalLoc,  -- Commented Vicky01
                                          @c_Busr1
                                          --, @c_Putawayzone -- June01 -- Commented Vicky01
	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF dbo.fnc_RTrim(UPPER(@c_CartonGroup)) = 'PREPACK' AND ISNULL(dbo.fnc_RTrim(@c_Lottable03), '') <> '' --ISNUMERIC(@c_Userdefine04) = 1
		BEGIN
--			SELECT @n_ComponentQty = @c_Userdefine04	
         SELECT @n_ComponentQty = Qty
         FROM BillOfMaterial (NOLOCK)
         WHERE SKU = dbo.fnc_RTrim(@c_Lottable03)
         AND   Storerkey = dbo.fnc_RTrim(@c_Storerkey)
         AND   ComponentSKU = dbo.fnc_RTrim(@c_Sku)
		END
		ELSE
		BEGIN
			SELECT @n_ComponentQty = 1
		END

		IF (@c_tempOrderKey <> @c_OrderKey) --OR (@c_tempLoc <> @c_Loc)  -- Commented Vicky01
         OR (@c_tempStyle <> @c_Style) OR 
			-- June01 : Start
         -- (@c_tempColor <> @c_Color) OR (@c_tempSusr3 <> @c_Susr3) OR (@c_tempMeasurement <> @c_Measurement) OR
            (@c_tempColor <> @c_Color) OR (@c_tempMeasurement <> @c_Measurement) OR
			-- June01 : End
			--(@c_tempUserdefine04 <> @c_Userdefine04) OR --(@c_tempSku <> @c_Sku) OR (@c_tempCartonGroup <> @c_CartonGroup) 
			  --(@c_tempSku <> CASE WHEN @c_CartonGroup = 'PREPACK' THEN dbo.fnc_RTrim(@c_Lottable03) ELSE dbo.fnc_RTrim(@c_Sku) END) 
			 (@c_tempCartonGroup <> @c_CartonGroup) 
 		BEGIN
			IF @c_tempOrderKey <> @c_OrderKey
			BEGIN
				IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE OrderKey = @c_OrderKey AND Zone = 'D')
				BEGIN
					SELECT @c_PrintedFlag = 'Y'
				END
				ELSE
				BEGIN
					SELECT @c_PrintedFlag = 'N'
				END

            IF @b_debug = 1
               SELECT '@c_OrderKey: ', @c_OrderKey, '@c_tempOrderKey: ', @c_tempOrderKey

				BEGIN TRAN

				-- Uses PickType as a Printed Flag
				UPDATE PICKHEADER WITH (ROWLOCK)
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
				ELSE
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
        
				IF @c_PrintedFlag = 'N' 
				BEGIN
               IF NOT EXISTS (SELECT 1 FROM PickHeader (NOLOCK) WHERE OrderKey = @c_OrderKey AND Zone IN ('D'))
               BEGIN
						EXECUTE nspg_GetKey
							'PICKSLIP',
							9,
							@c_PickHeaderKey OUTPUT,
							@b_success OUTPUT,
							@n_err OUTPUT,
							@c_errmsg OUTPUT
					
						SELECT @c_PickHeaderKey = 'P' + @c_PickHeaderKey

						BEGIN TRAN

	               IF @b_debug = 1
   	               SELECT 'Insert PickHeader in progress, @c_PickHeaderKey: ', @c_PickHeaderKey 

                  -- Shong001 15-Sep-2007 
						INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
						VALUES (@c_PickHeaderKey, @c_LoadKey, @c_OrderKey, '0', 'D', '')

						SELECT @n_err = @@ERROR
						IF @n_err <> 0
						BEGIN
							IF @@TRANCOUNT >= 1
							BEGIN
								ROLLBACK TRAN
							END
						END
						ELSE
						BEGIN
							UPDATE PICKDETAIL WITH (ROWLOCK)
							SET 	PICKSLIPNO = @c_PickHeaderKey, 
									Trafficcop = NULL
							FROM PICKDETAIL 
							WHERE Orderkey = @c_OrderKey
							AND Status < '5'
							AND ISNULL(dbo.fnc_RTrim(Pickslipno),'') = ''

							SELECT @n_err = @@ERROR
							IF @n_err <> 0
							BEGIN
								IF @@TRANCOUNT >= 1
								BEGIN
									ROLLBACK TRAN
								END
							END
							ELSE
							BEGIN 
								IF @@TRANCOUNT > 0
									COMMIT TRAN
								ELSE
									ROLLBACK TRAN		
							END				
						END
               END -- IF NOT EXISTS Zone IN ('C','D') 
				END
				ELSE --@c_PrintedFlag = 'Y' 
				BEGIN		
					SELECT @c_pickheaderkey = PickHeaderKey 
					FROM PickHeader WITH (NOLOCK)
					WHERE OrderKey = @c_OrderKey
					AND Zone IN ('D') 
				END				
			END --IF @c_tempOrderKey <> @c_OrderKey

			SELECT @c_tempOrderKey = @c_OrderKey, @c_tempLoc = @c_Loc, @c_tempStyle = @c_Style, 
                @c_tempColor = @c_Color, @c_tempSusr3 = @c_Susr3, @c_tempMeasurement = @c_Measurement
			--SELECT @c_tempUserdefine04 = @c_Userdefine04 -- Commented Vicky01
         SELECT @c_tempSku = CASE WHEN @c_CartonGroup = 'PREPACK' THEN dbo.fnc_RTrim(@c_Lottable03) ELSE dbo.fnc_RTrim(@c_Sku) END, @c_tempCartonGroup = @c_CartonGroup--@c_tempSku = @c_Sku, @c_tempCartonGroup = @c_CartonGroup
			SELECT @n_cnt = 1		
			SELECT @n_RunNumber = @n_RunNumber + 1

			INSERT INTO #TempDiscretePickSlip
				(RunNumber, PickSlipNo, OrderKey, PrintedFlag, --Loc, -- Commented Vicky01
             Style, Sku, Color, Susr3, Measurement, Size1, qty1, 
             -- BUSR8, June01 -- Commented Vicky01
				 --LogicalLocation, -- Commented Vicky01
             Busr1, Cartongroup)
             --, Putawayzone) -- June01 -- Commented Vicky01
 			VALUES
-- 				(@n_RunNumber, @c_PickHeaderKey, @c_OrderKey, @c_PrintedFlag, @c_Loc, @c_Style,
-- 				 @c_Sku, @c_Color, @c_Susr3, @c_Measurement, @c_Size, @n_qty/@n_ComponentQty)
				(@n_RunNumber, @c_PickHeaderKey, @c_OrderKey, @c_PrintedFlag, --@c_Loc, 
             @c_Style, CASE WHEN @c_CartonGroup = 'PREPACK' THEN dbo.fnc_RTrim(@c_Lottable03) ELSE dbo.fnc_RTrim(@c_Sku) END, 
             @c_Color, @c_Susr3, @c_Measurement, @c_Size, @n_qty, --  @c_SKUBUSR8, June01
				 ---@c_LogicalLoc, -- Commented Vicky01
             @c_Busr1, @c_CartonGroup)
             --, @c_Putawayzone) -- June01 -- Commented Vicky01
		END 
		ELSE
		BEGIN
			SELECT @n_cnt = @n_cnt + 1

			IF @n_cnt = 2
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size2 = @c_Size,
						Qty2 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END 
			ELSE IF @n_cnt = 3
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size3 = @c_Size,
						Qty3 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END
			ELSE IF @n_cnt = 4
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size4 = @c_Size,
						Qty4 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END 
			ELSE IF @n_cnt = 5
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size5 = @c_Size,
						Qty5 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END
			ELSE IF @n_cnt = 6
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size6 = @c_Size,
						Qty6 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END 
			ELSE IF @n_cnt = 7
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size7 = @c_Size,
						Qty7 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END
			ELSE IF @n_cnt = 8
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size8 = @c_Size,
						Qty8 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END 
			ELSE IF @n_cnt = 9
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size9 = @c_Size,
						Qty9 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END
			ELSE IF @n_cnt = 10
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size10 = @c_Size,
						Qty10 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END
			ELSE IF @n_cnt = 11
			BEGIN
				UPDATE #TempDiscretePickSlip
				SET 	Size11 = @c_Size,
						Qty11 = @n_qty--/@n_ComponentQty
				WHERE RunNumber = @n_RunNumber
			END

 		END
-- 		FETCH NEXT FROM discrete_pick_cur INTO @c_OrderKey, @c_Userdefine04, @c_Loc, @c_Sku, @c_CartonGroup, 
--    	                                       @n_qty, @c_Style, @c_Color, @c_Susr3, @c_Measurement, @c_Size
		
			FETCH NEXT FROM discrete_pick_cur INTO @c_OrderKey, @c_Lottable03, --@c_Loc, -- Commented Vicky01
                                       @c_Sku, @c_CartonGroup, 
		                                          @n_qty, @c_Style, @c_Color, @c_Susr3, @c_Measurement, @c_Size, 
																@c_Storerkey,
                                                @c_SKUBUSR8, 
																--@c_LogicalLoc, -- Commented Vicky01
                                                @c_Busr1
                                                --, @c_Putawayzone -- June01 -- Commented Vicky01
	END -- END WHILE (@@FETCH_STATUS <> -1)
	CLOSE discrete_pick_cur
	DEALLOCATE discrete_pick_cur		

	SELECT 	#TempDiscretePickSlip.RunNumber,
				#TempDiscretePickSlip.PickSlipNo,
				#TempDiscretePickSlip.OrderKey,
--				#TempDiscretePickSlip.Loc, -- Commented Vicky01
				#TempDiscretePickSlip.Sku,
				#TempDiscretePickSlip.Style,
				#TempDiscretePickSlip.Color,
				#TempDiscretePickSlip.Susr3,
				#TempDiscretePickSlip.Measurement,
				#TempDiscretePickSlip.PrintedFlag,
				#TempDiscretePickSlip.Size1,
				#TempDiscretePickSlip.Qty1,
				#TempDiscretePickSlip.Size2,
				#TempDiscretePickSlip.Qty2,
				#TempDiscretePickSlip.Size3,
				#TempDiscretePickSlip.Qty3,
				#TempDiscretePickSlip.Size4,
				#TempDiscretePickSlip.Qty4,
				#TempDiscretePickSlip.Size5,
				#TempDiscretePickSlip.Qty5,
				#TempDiscretePickSlip.Size6,
				#TempDiscretePickSlip.Qty6,
				#TempDiscretePickSlip.Size7,
				#TempDiscretePickSlip.Qty7,
				#TempDiscretePickSlip.Size8,
				#TempDiscretePickSlip.Qty8,
				#TempDiscretePickSlip.Size9,
				#TempDiscretePickSlip.Qty9,
				#TempDiscretePickSlip.Size10,
				#TempDiscretePickSlip.Qty10,
				#TempDiscretePickSlip.Size11,
				#TempDiscretePickSlip.Qty11,
				STORER.Company, 				
				ORDERS.Storerkey,
				CONVERT(CHAR(125), ORDERS.Notes) as Notes,
				CONVERT(CHAR(125), ORDERS.Notes2) as Notes2,				
				ORDERS.Facility,
				ORDERS.OrderDate,
				ORDERS.DeliveryDate,
				ORDERS.EffectiveDate,
				ORDERS.BuyerPO,
				ORDERS.UserDefine02,
				ORDERS.UserDefine03,
				ORDERS.UserDefine04,
				ORDERS.PmtTerm,
				ORDERS.BillToKey,
				ORDERS.B_Company,
				ORDERS.B_Address1,
				ORDERS.B_Address2,
				ORDERS.B_Address3,
				ORDERS.B_Address4,
				ORDERS.B_City,
				ORDERS.B_State, 
				ORDERS.B_Zip, 
				ORDERS.B_Country,
				ORDERS.ConsigneeKey,
				ORDERS.C_Company,
				ORDERS.C_Address1,
				ORDERS.C_Address2,
				ORDERS.C_Address3,
				ORDERS.C_Address4,
				ORDERS.C_City,
				ORDERS.C_State, 
				ORDERS.C_Zip, 
				ORDERS.C_Country,
				ORDERS.MarkforKey,
				ORDERS.M_Company,
				ORDERS.M_Address1,
				ORDERS.M_Address2,
				ORDERS.M_Address3,
				ORDERS.M_Address4,
				ORDERS.M_City,
				ORDERS.M_State, 
				ORDERS.M_Zip, 
				ORDERS.M_Country,
				sUser_sName() UserID,
				@c_LoadKey LoadKey,
--				#TempDiscretePickSlip.LogicalLocation, -- June01 -- Commented Vicky01
				#TempDiscretePickSlip.Busr1, -- June01 
--				#TempDiscretePickSlip.Putawayzone, -- June01 -- Commented Vicky01
				ORDERS.ExternOrderkey, -- June01				   -- Commented Vicky01
				ORDERS.Adddate, -- June01
            #TempDiscretePickSlip.CartonGroup, -- Vicky01 -- Commented Vicky01
            REPLACE(
               CONVERT(CHAR(250),SUBSTRING( STORER.Notes1, 1, 250)),
                   '|', master.dbo.fnc_GetCharASCII(13))AS leftnotes,  -- SOS#107784 
             REPLACE(
               CONVERT(CHAR(250),SUBSTRING( STORER.Notes1, 251, 250)),
                   '|', master.dbo.fnc_GetCharASCII(13))AS rightnotes,  -- SOS#107784 
            REPLACE(
               CONVERT(CHAR(250),SUBSTRING( STORER.Notes1, 501, 250)),
                   '|', master.dbo.fnc_GetCharASCII(13))AS leftnotes1,  -- SOS#107784 
             REPLACE(
               CONVERT(CHAR(250),SUBSTRING( STORER.Notes1, 751, 250)),
                   '|', master.dbo.fnc_GetCharASCII(13))AS rightnotes1  -- SOS#107784 
	FROM #TempDiscretePickSlip 
   JOIN ORDERS WITH (NOLOCK) ON (#TempDiscretePickSlip.Orderkey =  ORDERS.Orderkey)
   JOIN STORER WITH (NOLOCK) ON (ORDERS.StorerKey = STORER.StorerKey)
   ORDER BY RunNumber

	DROP TABLE #TempDiscretePickSlip
END



GO