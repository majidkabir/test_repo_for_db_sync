SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetDiscretePickTicketUSA_3                     */
/* Creation Date: 28-JUL-2009                                           */
/* Copyright: IDS                                                       */
/* Written by: NJOW (Modified from isp_GetDiscretePickTicketUSA)        */
/*                                                                      */
/* Purpose:  SOS#141342 - Discrete Pick Ticket By Loc for IDSUS.    		*/
/*                                                                      */
/* Called By:  PB - r_dw_consolidated_pick16_discrete_v3                */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 25-Sep-2009  NJOW01  1.1   Fix error checking E1 to include id       */ 
/* 12-Oct-2009  NJOW02  1.2   SOS#150311 - Fix 1 SKU multiple PPK issue */ 
/*                            and fix alignment                         */
/* 01-Dec-2009	NJOW03  1.3   154602 - Remove bad ratio checking and    */
/*                            adjust layout.                            */
/* 06-Jan-2010  NJOW04  1.4   158014 - Fix null pick slip no for new    */
/*                            pickdetail lines for the order            */
/* 20-Jan-2010  NJOW05  1.5   Fix prepack qty calculation by location   */
/* 04-Mar-2010  NJOW06  1.6   160294 - If @n_UOMLevel > 5 with error UOM*/
/*                            set to PC                                 */
/* 17-Dec-2013  TLTING  1.7   Bug fix on Tran Commit                    */
/************************************************************************/

CREATE PROC [dbo].[isp_GetDiscretePickTicketUSA_v3] ( 
            @c_LoadKey  NVARCHAR(10)
			  ,@b_debug  NVARCHAR(1) = '')
AS
BEGIN
   SET NOCOUNT ON
	SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
	
	DECLARE 	@n_continue int,
				@c_errmsg NVARCHAR(255),
				@b_success int,
				@n_err int,
				@c_Pickslipno NVARCHAR(10),
				@c_OrderKey NVARCHAR(10),
			 	@c_tempOrderKey NVARCHAR(10),
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
        ,@c_Prepack NVARCHAR(1)
			  ,@c_tpickslipno NVARCHAR(10)
			  ,@c_id NVARCHAR(18)

  DECLARE @n_cnt int, 
          @c_sku NVARCHAR(20), 
          @n_rowid int,
          @n_trancount int

   SELECT @n_trancount = @@TRANCOUNT

	CREATE TABLE #TempDiscPickSlipSum
				( Loadkey NVARCHAR(10) NOT NULL,
				  Orderkey NVARCHAR(10) NOT NULL,
				  Pickslipno NVARCHAR(10) NULL,
				  PrintedFlag NVARCHAR(1) NULL
				)

	CREATE TABLE #TempDiscPickSlip
				( 	RowId int IDENTITY (1, 1) NOT NULL,
					PickSlipNo NVARCHAR(10),
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
					ErrFlag  NVARCHAR(2) NULL,
					Id NVARCHAR(18) NULL)

  DECLARE @t_DiscretePS TABLE 
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
				LineFlag NVARCHAR(2),
				Id NVARCHAR(18) 
			 )	

	SELECT @n_continue = 1 

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		 SELECT IDENTITY(int,1,1) AS rowid, PD.Storerkey, PD.Sku, PD.Altsku, PD.CartonGroup, PD.Loc, PD.Orderkey, PD.OrderLineNumber, PD.Lot, PD.Qty, 
		        LA.Lottable03, CONVERT(int,0) AS pkqty, PD.Status, PD.Id
		 INTO #TMP_PICKDET
		 FROM LOADPLANDETAIL LD (NOLOCK)		 
		 JOIN PICKDETAIL PD (NOLOCK) ON (LD.Orderkey = PD.Orderkey)
		 JOIN LOTATTRIBUTE LA (NOLOCK) ON (PD.Lot = LA.Lot)
		 WHERE PD.Status < '5'
		 AND LD.Loadkey = @c_LoadKey		 
	 
		 SELECT DISTINCT TP.Orderkey, BM.Storerkey, BM.SKU, BM.ComponentSku, BM.Qty 
		 INTO #TMP_BOM
		 FROM #TMP_PICKDET TP (NOLOCK)
		 JOIN BILLOFMATERIAL BM (NOLOCK) ON (TP.Storerkey = BM.Storerkey AND TP.Lottable03 = BM.SKU)
		 WHERE ISNULL(RTRIM(TP.AltSku),'') = ''
  	 AND cartongroup <> 'PREPACK'		 
		 ORDER BY TP.Orderkey, BM.Storerkey, BM.SKU, BM.ComponentSku

     --NJOW05
		 SELECT TP.Loc, TP.Storerkey, TP.Sku, TP.Lottable03, SUM(TP.Qty) % ISNULL(BM.Qty,1) AS Seq
		 INTO #TMP_SORT
		 FROM #TMP_PICKDET TP (NOLOCK)
		 LEFT JOIN BILLOFMATERIAL BM (NOLOCK) ON (TP.Storerkey = BM.Storerkey AND TP.Lottable03 = BM.SKU
                                           AND TP.SKU = BM.Componentsku)
     GROUP BY TP.Loc, TP.Storerkey, TP.Sku, TP.Lottable03, BM.qty

		 UPDATE #TMP_PICKDET 
		 SET #TMP_PICKDET.AltSku = '', #TMP_PICKDET.cartongroup = 'STD'
		 FROM #TMP_PICKDET 
		 LEFT JOIN BILLOFMATERIAL ON (#TMP_PICKDET.Storerkey = BILLOFMATERIAL.Storerkey AND 
		                              #TMP_PICKDET.Lottable03 = BILLOFMATERIAL.Sku)
		 WHERE BILLOFMATERIAL.Sku IS NULL

		 SELECT @c_storerkey = '', @c_sku = '', @c_orderkey = ''
		 WHILE 1=1
		 BEGIN
		 	  SET ROWCOUNT 1
		 	  SELECT @c_storerkey = Storerkey, @c_sku = Sku, @c_orderkey = Orderkey
		 	  FROM #TMP_BOM
		 	  WHERE Orderkey+Storerkey+SKU > @c_orderkey+@c_storerkey+@c_sku
		 	  ORDER BY Orderkey, Storerkey, SKU
		 	  
		 	  SELECT @n_cnt = @@ROWCOUNT		 	  
		 	  SET ROWCOUNT 0
        IF @n_cnt = 0
		       BREAK
		    
		    SELECT @c_CompSku = '', @c_prepack = 'Y'
		    BEGIN TRAN
				WHILE 1=1
		    BEGIN
		    	 SET ROWCOUNT 1
	  		 	 SELECT @c_storerkey = Storerkey, @c_compsku = ComponentSku, @n_compqty = qty
 		       FROM #TMP_BOM
		       WHERE Storerkey = @c_storerkey
		       AND Sku = @c_sku  
		       AND ComponentSku > @c_compSku
		       ORDER BY ComponentSku		       
      	 	 
      	 	 SELECT @n_cnt = @@ROWCOUNT
		       SET ROWCOUNT 0
		       
           IF @n_cnt = 0
           BEGIN
		          SELECT @c_CompSku = '', @c_prepack = 'Y'		          
		          COMMIT TRAN
		          BEGIN TRAN
		          CONTINUE
		       END
		       		       
		       WHILE @n_Compqty > 0
		       BEGIN
		       	  SELECT TOP 1 @n_rowid = TP.rowid, @n_qty = TP.qty-TP.pkqty
		       	  FROM #TMP_PICKDET TP
                 JOIN #TMP_SORT TS ON (TP.Loc = TS.Loc   --NJOW05
                                    AND TP.Storerkey = TS.Storerkey
                                    AND TP.Sku = TS.Sku
                                    AND TP.Lottable03 = TS.Lottable03)
		       	  WHERE TP.Storerkey = @c_storerkey AND TP.Sku = @c_compsku
		       	  AND TP.qty - TP.pkqty > 0
							AND ((ISNULL(RTRIM(TP.AltSku),'') = '' AND TP.cartongroup <> 'PREPACK') OR TP.pkqty > 0)
							AND TP.lottable03 = @c_sku --NJOW02
		       	  ORDER BY TS.Seq, 2 DESC

		       	  IF @@ROWCOUNT = 0
		       	  BEGIN
		       	     SELECT @c_prepack = 'N'
		       	     BREAK
		       	  END
		       	  IF @n_Compqty >= @n_qty 
		       	  BEGIN		       	 
  		       	  UPDATE #TMP_PICKDET
	  	       	  SET pkqty = pkqty + @n_qty,
	  	       	      altsku = @c_sku, cartongroup = 'PREPACK'
	  	       	  WHERE rowid = @n_rowid	  	       	  
	  	       	  
	  	       	  SELECT @n_Compqty = @n_Compqty - @n_qty 	  	       	 
		       	  END		       	  
		       	  ELSE
		       	  BEGIN
  		       	  UPDATE #TMP_PICKDET
	  	       	  SET pkqty = pkqty + @n_Compqty,
	  	       	      altsku = @c_sku, cartongroup = 'PREPACK'
	  	       	  WHERE rowid = @n_rowid	  	       	  
	  	       	  
	  	       	  SELECT @n_Compqty = 0
		       	  END		       	  
		       END -- while 3
		       IF @c_prepack = 'N'
		       BEGIN
		       	  ROLLBACK TRAN
		          BREAK
		       END
		    END	-- while 2
		 END -- while 1		 
		 
		 SELECT Storerkey, Sku, Altsku, CartonGroup, Loc, Orderkey, OrderLineNumber, Lot, Qty, Status, Id
		 INTO #TMP_PICKDET2
		 FROM #TMP_PICKDET
		 WHERE pkqty = 0
		 
		 INSERT INTO #TMP_PICKDET2
		 SELECT Storerkey, Sku, Altsku, CartonGroup, Loc, Orderkey, OrderLineNumber, Lot, pkqty, Status, Id
		 FROM #TMP_PICKDET
		 WHERE pkqty > 0

		 INSERT INTO #TMP_PICKDET2
		 SELECT Storerkey, Sku, '', '', Loc, Orderkey, OrderLineNumber, Lot, qty - pkqty, Status, Id
		 FROM #TMP_PICKDET
		 WHERE pkqty > 0
		 AND qty - pkqty > 0
		 		 
	END -- continue

   WHILE @n_trancount > 0
   BEGIN
      BEGIN TRAN
      SELECT @n_trancount = @n_trancount - 1
   END

	BEGIN TRAN

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		INSERT INTO #TempDiscPickSlipSum ( Loadkey, Orderkey)
		SELECT ORDERS.Loadkey, 
				 ORDERS.OrderKey 
		FROM   ORDERS WITH (NOLOCK) 
      JOIN   ORDERDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY)
      JOIN   PICKDETAIL WITH (NOLOCK) ON  (ORDERS.OrderKey = PICKDETAIL.OrderKey AND 
                                          ORDERDETAIL.OrderLineNumber = PICKDETAIL.OrderLineNumber)
		WHERE PICKDETAIL.Status < '5'
		AND   ORDERS.LoadKey = @c_LoadKey
		GROUP BY ORDERS.Loadkey, ORDERS.OrderKey
		ORDER BY ORDERS.Loadkey, ORDERS.OrderKey				
	END

	SELECT @c_tempOrderKey = ''

	-- Check PickHeader Exists, if not exists assign new pickslipno for each order
	DECLARE discrete_pick_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT OrderKey  
	FROM   #TempDiscPickSlipSum
	WHERE  LoadKey = @c_LoadKey
	ORDER BY OrderKey

	OPEN discrete_pick_cur
	FETCH NEXT FROM discrete_pick_cur INTO @c_OrderKey

	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
		IF @n_continue = 3
		BEGIN
			BREAK
		END

		IF @c_tempOrderKey <> @c_OrderKey
		BEGIN
			SELECT @c_tempOrderKey = @c_OrderKey
			
			IF EXISTS(SELECT 1 FROM PickHeader (NOLOCK) WHERE OrderKey = @c_OrderKey AND Zone = 'D')
			BEGIN
				SELECT @c_PrintedFlag = 'Y'
			END
			ELSE
			BEGIN
				SELECT @c_PrintedFlag = 'N'
			END			

			BEGIN TRAN

			-- Uses PickType as a Printed Flag
			UPDATE PICKHEADER WITH (ROWLOCK)
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
						@c_Pickslipno OUTPUT,
						@b_success OUTPUT,
						@n_err OUTPUT,
						@c_errmsg OUTPUT
				
					SELECT @c_Pickslipno = 'P' + @c_Pickslipno

					BEGIN TRAN

               IF @b_debug = 1
	               SELECT 'Insert PickHeader in progress, @c_Pickslipno: ', @c_Pickslipno 

               -- Shong001 15-Sep-2007 
					INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, Orderkey, PickType, Zone, TrafficCop)
					VALUES (@c_Pickslipno, @c_LoadKey, @c_OrderKey, '0', 'D', '')

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
						SET 	PICKSLIPNO = @c_Pickslipno, 
								Trafficcop = NULL
						FROM  PICKDETAIL 
						WHERE Orderkey = @c_OrderKey
						AND   Status < '5'
						AND   ISNULL(dbo.fnc_RTrim(Pickslipno),'') = ''

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
            END -- IF NOT EXISTS Zone IN ('D') 
			END
			ELSE --@c_PrintedFlag = 'Y' 
			BEGIN		
				SELECT @c_Pickslipno = PickHeaderKey 
				FROM  PickHeader WITH (NOLOCK)
				WHERE OrderKey = @c_OrderKey
				AND   Zone IN ('D') 

        -- NJOW04
       	UPDATE PICKDETAIL WITH (ROWLOCK) 
				SET 	PICKSLIPNO = @c_Pickslipno, 
  						Trafficcop = NULL
				FROM  PICKDETAIL 
				WHERE Orderkey = @c_OrderKey
				AND   Status < '5'
				AND   ISNULL(dbo.fnc_RTrim(Pickslipno),'') = ''
			END			

			UPDATE #TempDiscPickSlipSum
			SET    Pickslipno = @c_Pickslipno,
					 PrintedFlag = @c_PrintedFlag
			WHERE  Orderkey = @c_OrderKey
			AND    Loadkey = @c_Loadkey
		     -- SOS 111163 - Update temp pickslip no
         IF @n_continue = 1 OR @n_continue = 2
			BEGIN
				-- Check Is Prepack?
				IF EXISTS(SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE OrderKey = @c_OrderKey)
				BEGIN
					SELECT @c_Prepack = 'Y'

					SELECT @c_tpickslipno = PickSlipNo
					FROM   PACKHEADER PACK WITH (NOLOCK)
					JOIN   PICKHEADER PICK WITH (NOLOCK)
					ON    (PACK.Orderkey = PICK.Orderkey)
					WHERE  PACK.PickSlipNo LIKE 'T%'
					AND    PICK.PickHeaderKey = @c_Pickslipno
				
					-- Convert Prepack Temporary PickSlipNo-'T%' to Actual PickSlipNo 
					IF dbo.fnc_RTrim(@c_tpickslipno)<> '' AND dbo.fnc_RTrim(@c_tpickslipno) IS NOT NULL
					BEGIN
						INSERT INTO PACKHEADER (PickSlipNo, StorerKey, Route, OrderKey, OrderRefNo, 
                                          LoadKey, ConsigneeKey, Status, AddWho, AddDate)
						SELECT 	@c_Pickslipno, 
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
						AND   PICK.PickHeaderKey = @c_Pickslipno			

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
							SET 	PickSlipNo = @c_Pickslipno,
		    						EditWho    = Suser_Sname(),
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
							SET 	PickSlipNo = @c_Pickslipno,
		    						EditWho    = Suser_Sname(),
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
		END --IF @c_tempOrderKey <> @c_OrderKey

		FETCH NEXT FROM discrete_pick_cur INTO @c_OrderKey
	END -- END WHILE 
	CLOSE discrete_pick_cur
	DEALLOCATE discrete_pick_cur		


	-- Create #TempDiscPickSlip Table
	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		INSERT INTO #TempDiscPickSlip 
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
					   ErrFlag,
					  Id )
		SELECT #TempDiscPickSlipSum.Pickslipno, 
			   ORDERS.Loadkey,
				ORDERS.OrderKey, 
				ORDERS.StorerKey, 
			   #TempDiscPickSlipSum.PrintedFlag, 
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
				'', -- ErrFlag
				PICKDETAIL.Id
		FROM ORDERS WITH (NOLOCK) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY)
      JOIN #TMP_PICKDET2 PICKDETAIL WITH (NOLOCK) ON  (ORDERS.OrderKey = PICKDETAIL.OrderKey AND --NJOW
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
		JOIN #TempDiscPickSlipSum ON (#TempDiscPickSlipSum.Loadkey = ORDERS.Loadkey AND 
											   #TempDiscPickSlipSum.Orderkey = ORDERS.Orderkey)
		WHERE PICKDETAIL.Status < '5'
		AND   PICKDETAIL.CartonGroup = 'PREPACK'
		AND   LOADPLANDETAIL.LoadKey = @c_LoadKey
		GROUP BY #TempDiscPickSlipSum.Pickslipno, #TempDiscPickSlipSum.PrintedFlag, 
					ORDERS.Loadkey, ORDERS.OrderKey, ORDERS.StorerKey, 
					PICKDETAIL.AltSku, PICKDETAIL.CartonGroup, SKU.SKU, SKU.Style, SKU.Color, SKU.Busr1,
					SKU.Measurement, SKU.Size, LOC.Putawayzone, LOC.LogicalLocation, PICKDETAIL.Loc,
					LOTATTRIBUTE.LOTTABLE03, PICKDETAIL.Id
		UNION
		SELECT #TempDiscPickSlipSum.Pickslipno, 
			   ORDERS.Loadkey,
				ORDERS.OrderKey, 
				ORDERS.StorerKey, 
			   #TempDiscPickSlipSum.PrintedFlag, 
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
				'', -- ErrFlag
				PICKDETAIL.Id
		FROM ORDERS WITH (NOLOCK) 
      JOIN ORDERDETAIL WITH (NOLOCK) ON (ORDERS.ORDERKEY = ORDERDETAIL.ORDERKEY)
      JOIN #TMP_PICKDET2 PICKDETAIL WITH (NOLOCK) ON  (ORDERS.OrderKey = PICKDETAIL.OrderKey AND --NJOW
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
		JOIN #TempDiscPickSlipSum ON (#TempDiscPickSlipSum.Loadkey = ORDERS.Loadkey AND 
											   #TempDiscPickSlipSum.Orderkey = ORDERS.Orderkey)
		WHERE PICKDETAIL.Status < '5'
		AND   PICKDETAIL.CartonGroup <> 'PREPACK'
		AND   LOADPLANDETAIL.LoadKey = @c_LoadKey
		GROUP BY #TempDiscPickSlipSum.Pickslipno, #TempDiscPickSlipSum.PrintedFlag, 
					ORDERS.Loadkey, ORDERS.OrderKey, ORDERS.StorerKey, 
					PICKDETAIL.AltSku, PICKDETAIL.CartonGroup, SKU.SKU, SKU.Style, SKU.Color, SKU.Busr1,
					SKU.Measurement, SKU.Size, LOC.Putawayzone, LOC.LogicalLocation, PICKDETAIL.Loc,
					LOTATTRIBUTE.LOTTABLE03, LOTATTRIBUTE.LOTTABLE01, LOTATTRIBUTE.LOTTABLE02, PICKDETAIL.Id
		ORDER BY ORDERS.Storerkey, ORDERS.Orderkey, LOC.Putawayzone, LOC.LogicalLocation, 
					SKU.Style, LOTATTRIBUTE.LOTTABLE03 

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

	IF @b_debug = 1
	BEGIN
		Print '#TempDiscPickSlip' 
		Select * From #TempDiscPickSlip
	END 


	-- Start : June01
	-- E1 : Check In-syn PPK allocated among Component SKUs
	/*IF @n_continue = 1 OR @n_continue = 2
	BEGIN		
		UPDATE #TempDiscPickSlip
		SET    ErrFlag = 'E1'
		FROM ( 
            SELECT BOMQty.Storerkey, BOMQty.Orderkey, BOMQty.AltSKU, BOMQty.Loc, BOMQty.NoBOMQty, MINPPK.PPKQty
				FROM (SELECT #TempDiscPickSlip.Storerkey, #TempDiscPickSlip.Orderkey, #TempDiscPickSlip.AltSKU, #TempDiscPickSlip.Loc, NoBOMQty = #TempDiscPickSlip.Qty/BOM.Qty, #TempDiscPickSlip.ID
						FROM #TempDiscPickSlip
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempDiscPickSlip.Sku 
																			    AND BOM.Sku = #TempDiscPickSlip.AltSku
																				 AND BOM.Storerkey = #TempDiscPickSlip.Storerkey 		
						GROUP BY #TempDiscPickSlip.Storerkey, #TempDiscPickSlip.Orderkey, #TempDiscPickSlip.AltSKU, #TempDiscPickSlip.Loc, (#TempDiscPickSlip.Qty/BOM.Qty), #TempDiscPickSlip.ID
						) BOMQty
			   JOIN (	
						SELECT #TempDiscPickSlip.Storerkey, #TempDiscPickSlip.Orderkey, AltSku, Loc, PPKQty = MIN(#TempDiscPickSlip.Qty / BOM.Qty), #TempDiscPickSlip.ID
						FROM  #TempDiscPickSlip (nolock) 
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempDiscPickSlip.Sku 
																			    AND BOM.Sku = #TempDiscPickSlip.AltSku
																				 AND BOM.Storerkey = #TempDiscPickSlip.Storerkey 			
			GROUP BY #TempDiscPickSlip.Storerkey, #TempDiscPickSlip.Orderkey, AltSku, Loc, #TempDiscPickSlip.ID) MINPPK 
																				ON  MINPPK.Storerkey = BOMQty.Storerkey 
																				AND MINPPK.Orderkey = BOMQty.Orderkey
																				AND MINPPK.AltSKU = BOMQty.AltSKU	
																				AND MINPPK.Loc = BOMQty.Loc
																				AND MINPPK.ID = BOMQty.ID
				WHERE NoBOMQty <> PPKQty
			  ) AS Prob
		WHERE Prob.Loc = #TempDiscPickSlip.Loc 
		AND   Prob.AltSku = #TempDiscPickSlip.AltSKU 
		AND   Prob.Orderkey = #TempDiscPickSlip.Orderkey
		AND   Prob.Storerkey = #TempDiscPickSlip.Storerkey
      AND   CartonGroup = 'PREPACK'
		AND   ErrFlag = ''
	END */ --NJOW03

	-- E2 : Check Bad Ratio
	/*IF @n_continue = 1 OR @n_continue = 2
	BEGIN		
		-- Bad Ratio
		UPDATE #TempDiscPickSlip
		SET    ErrFlag = 'E2'
		FROM (  
 
           SELECT BadRatio.Storerkey, BadRatio.Orderkey, BadRatio.Loc, BadRatio.AltSKU 
				FROM (
						SELECT #TempDiscPickSlip.Storerkey, #TempDiscPickSlip.Orderkey, #TempDiscPickSlip.Loc, #TempDiscPickSlip.AltSKU --, BOM.Qty, #TempDiscPickSlip.Qty, Remaining = (#TempDiscPickSlip.Qty % BOM.Qty)
						FROM   #TempDiscPickSlip
						LEFT OUTER JOIN BillOfMaterial BOM (nolock) ON BOM.ComponentSku = #TempDiscPickSlip.Sku 
																			    AND BOM.Sku = #TempDiscPickSlip.AltSku
																				 AND BOM.Storerkey = #TempDiscPickSlip.Storerkey 
						WHERE  CartonGroup = 'PREPACK'
						AND    ErrFlag = ''
						GROUP BY #TempDiscPickSlip.Storerkey, #TempDiscPickSlip.Orderkey, #TempDiscPickSlip.Loc, #TempDiscPickSlip.AltSKU, BOM.Qty, #TempDiscPickSlip.Qty, (#TempDiscPickSlip.Qty % BOM.Qty)
						HAVING (#TempDiscPickSlip.Qty % BOM.Qty) > 0
						) BadRatio
				GROUP BY BadRatio.Storerkey, BadRatio.Orderkey, BadRatio.Loc, BadRatio.AltSKU 
 			  ) AS Prob
 		WHERE Prob.Loc = #TempDiscPickSlip.Loc 
		AND 	Prob.AltSku = #TempDiscPickSlip.AltSKU 
		AND   Prob.Orderkey = #TempDiscPickSlip.Orderkey
		AND   Prob.Storerkey = #TempDiscPickSlip.Storerkey
      AND   CartonGroup = 'PREPACK'
		AND   ErrFlag = ''
	END */ --NJOW03


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
					ErrFlag = Max(ErrFlag), LogicalLoc = ISNULL(LogicalLoc, ''), Id 	
		INTO   #TempDiscPickSlip2
		FROM   #TempDiscPickSlip
		WHERE  LoadKey = @c_LoadKey
		GROUP BY PickSlipNo, Loadkey, Orderkey, StorerKey,  PrintedFlag, 
					CASE  WHEN CartonGroup = 'PREPACK' AND LEFT(ErrFlag, 1) <> 'E' THEN AltSku 
							Else SKU END, 
					CartonGroup, Style, Putawayzone, Loc, Lottable01, Lottable02, Lottable03, 
					ISNULL(LogicalLoc, ''), Id			       
			
	  SELECT DISTINCT UPC.storerkey, UPC.sku, UPC.packkey  --NJOW
	  INTO #TMP_UPC	
	  FROM UPC (NOLOCK)
	  JOIN #TempDiscPickSlip2 ON (#TempDiscPickSlip2.Altsku = UPC.SKU AND #TempDiscPickSlip2.Storerkey  = UPC.Storerkey)
	 	WHERE #TempDiscPickSlip2.AltSKU > '' 
		AND 	#TempDiscPickSlip2.CartonGroup = 'PREPACK'
		
		UPDATE #TempDiscPickSlip2
		SET    Pallet = CASE WHEN #TempDiscPickSlip2.CartonGroup = 'PREPACK' AND ISNULL(PACK.Pallet, 0) > 0 THEN PACK.Pallet ELSE 0 END,
 				 Shipper = CASE WHEN #TempDiscPickSlip2.CartonGroup = 'PREPACK' AND ISNULL(PACK.OtherUnit1, 0) > 0 THEN PACK.OtherUnit1 ELSE 0 END,
				 Casecnt = CASE WHEN #TempDiscPickSlip2.CartonGroup = 'PREPACK' AND ISNULL(PACK.Casecnt, 0) > 0 THEN PACK.Casecnt ELSE 0 END,
				 Innerpack = CASE WHEN #TempDiscPickSlip2.CartonGroup = 'PREPACK' AND ISNULL(PACK.Innerpack, 0) > 0 THEN PACK.Innerpack ELSE 0 END 
		FROM  #TempDiscPickSlip2
--		JOIN  SKU WITH (NOLOCK) ON  SKU.Storerkey = #TempDiscPickSlip2.Storerkey 
--										AND SKU.SKU = #TempDiscPickSlip2.Altsku        
	  JOIN  #TMP_UPC ON (#TMP_UPC.Storerkey = #TempDiscPickSlip2.Storerkey  --NJOW
  										AND #TMP_UPC.SKU = #TempDiscPickSlip2.Altsku)        
		JOIN PACK WITH (NOLOCK) ON (PACK.Packkey = #TMP_UPC.Packkey)
		WHERE #TempDiscPickSlip2.AltSKU > '' 
		AND 	#TempDiscPickSlip2.CartonGroup = 'PREPACK'
		
		
		IF @b_Debug = 1
		BEGIN
			PRINT '#TempDiscPickSlip2'
			SELECT * FROM #TempDiscPickSlip2
		END


		DECLARE disc_calcqty_cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	   SELECT   PickSlipNo, Loadkey, Orderkey, StorerKey, PrintedFlag, 
					AltSku, CartonGroup, Style, Putawayzone, Loc, Qty, Lottable01, 
					Lottable02, Lottable03, Pallet, Shipper, Casecnt, Innerpack,
					ErrFlag, ISNULL(LogicalLoc, ''), Id 	
		FROM   #TempDiscPickSlip2
		WHERE  LoadKey = @c_LoadKey
		ORDER BY Loadkey, Storerkey, Orderkey, PickSlipno, Putawayzone, LogicalLoc, Loc, Style, Lottable03, Id	

		OPEN disc_calcqty_cur
		FETCH NEXT FROM disc_calcqty_cur 
		INTO  @c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Storerkey, @c_PrintedFlag, 
				@c_AltSku, @c_CartonGroup, @c_Style, @c_Putawayzone, @c_loc, @n_Qty, 
				@c_Lottable01, @c_Lottable02, @c_Lottable03,
				@f_Pallet, @f_OtherUnit1, @f_Casecnt, @f_Innerpack, @c_ErrFlag, @c_Logicalloc, @c_id
	
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
					AND   Status < '5'	
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
									 @c_CompFind  = dbo.fnc_RTrim(SKU.Color)+dbo.fnc_RTrim(SKU.Busr8)+dbo.fnc_RTrim(BillOfMaterial.SKU) + dbo.fnc_RTrim(BillOfMaterial.ComponentSKU)
							FROM  BillOfMaterial WITH (NOLOCK)
							JOIN  SKU WITH (NOLOCK) ON  SKU.Storerkey = BillOfMaterial.Storerkey 
															AND SKU.SKU = BillOfMaterial.ComponentSKU					
							WHERE BillOfMaterial.Storerkey = @c_Storerkey
							AND   BillOfMaterial.SKU = @c_PrevPPKInd
							AND   dbo.fnc_RTrim(SKU.Color)+dbo.fnc_RTrim(SKU.Busr8)+dbo.fnc_RTrim(BillOfMaterial.SKU) + dbo.fnc_RTrim(BillOfMaterial.ComponentSKU) > @c_CompFind
							ORDER BY SKU.Color, SKU.Busr8 --SKU.Size 
			
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
									INSERT INTO @t_DiscretePS 

										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey,
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer,
											@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
										  SPACE(15) + '^' + '  Size  ' + '^' + LEFT(dbo.fnc_RTrim(@c_DispSize) +  REPLICATE('', 70), 70), 'B1')

									-- BOM Box 2 : COLOUR
									INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
											@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
											CONVERT(CHAR(15), @c_PrevCompColor) + '^' + 
											LEFT(dbo.fnc_RTrim(CONVERT(CHAR(8), @n_SumCompQty))+SPACE(8),8) + '^' + 
											LEFT(dbo.fnc_RTrim(@c_DispQty) + REPLICATE('', 70), 70), 'B1')
								END
	
								SET @c_DispSize = ''
								SET @c_DispQty = ''
								SET @n_SumCompQty = 0
								SET @c_PrevCompColor = @c_CompColor							
							END
	
							SET @c_DispSize = @c_DispSize + RIGHT(SPACE(7) + dbo.fnc_RTrim(@c_CompSize), 7)
							SET @c_DispQty  = @c_DispQty  + RIGHT(SPACE(7) + dbo.fnc_RTrim(@n_CompQty), 7)
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
							INSERT INTO @t_DiscretePS 
						
				  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
									  @c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
									 SPACE(15) + '^' + '  Size  ' + '^' + LEFT(dbo.fnc_RTrim(@c_DispSize) +  REPLICATE('', 70), 70), 'B1')

							-- BOM Box 2 : COLOUR
							INSERT INTO @t_DiscretePS 
								  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
									Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
									@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
									CONVERT(CHAR(15), @c_PrevCompColor) + '^' + 
									 LEFT(dbo.fnc_RTrim(CONVERT(CHAR(8), @n_SumCompQty))+SPACE(8),8) + '^' + 
									LEFT(dbo.fnc_RTrim(@c_DispQty) + REPLICATE('', 70), 70), 'B1')
						END
	
						SET ROWCOUNT 0
					END -- 'PREPACK'
	
					-- Draw Seperator dotted line After Display BOM or When Group (Loc/Style/PPK IND) change
					IF @b_LastRec = '0'
					BEGIN
						-- Seperator Dotted line
						INSERT INTO @t_DiscretePS 
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
						GOTO Insert_t_Discrete
	
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
						GOTO Insert_t_Discrete
	
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
						GOTO Insert_t_Discrete
	
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
						GOTO Insert_t_Discrete
	
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
						GOTO Insert_t_Discrete

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
		
			   Insert_t_Discrete:
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
                        -- Modified By Vicky on 09-Oct-2007 (Start)                        
								INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,				 
										 CONVERT(CHAR(12), ISNULL(dbo.fnc_RTrim(@c_Loc), '')) + CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + SPACE(2)+
                               CONVERT(CHAR(50), ISNULL(LEFT(dbo.fnc_RTrim(@c_Busr1),50), '')),'') --+ SPACE(1) +
                               --CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +  --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + 
                               --SPACE(3) + RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_NoOfUnits)),8) + SPACE(13)+  -- 'PCs' + SPACE(20) + -- Vicky02										 
										 --RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_EAQty)),8) + SPACE(3)+
                     --RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_UOMQty)),8),'')
			
								-- New PPK Detail 2
								INSERT INTO @t_DiscretePS 
										(PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
										Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag, Id)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
										@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
										 --SPACE(39) + CONVERT(CHAR(15), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) + CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) +
										 --CONVERT(CHAR(16), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')), '', @c_id)								
										 SPACE(39) +  
										 CONVERT(CHAR(15), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) +  CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) + 
                     CONVERT(CHAR(16), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')) + SPACE(3) +
                     CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +  --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + 
                     SPACE(3) + RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_NoOfUnits)),8) + SPACE(13)+  -- 'PCs' + SPACE(20) + -- Vicky02										 
										 RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_EAQty)),8) + SPACE(3)+
                     RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_UOMQty)),8),'',@c_id)																					

							    SET @b_Repeat = '0'
							END 
							ELSE
							BEGIN
								-- Repeat PPK Detail
								INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag, Id)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
										 SPACE(39) +  
										 CONVERT(CHAR(15), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) +  CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) + 
                     CONVERT(CHAR(16), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')) + SPACE(3) +
                     CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +  --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + 
                     SPACE(3) + RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_NoOfUnits)),8) + SPACE(13)+  -- 'PCs' + SPACE(20) + -- Vicky02										 
										 RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_EAQty)),8) + SPACE(3)+
                     RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_UOMQty)),8),'',@c_id)																					
							END							 
						END
						ELSE -- Print Loose
						BEGIN		
							IF @b_Repeat = '1'
							BEGIN
								-- Loose Item Detail 1
								INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
								VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
										@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
										 CONVERT(CHAR(12), ISNULL(dbo.fnc_RTrim(@c_Loc), '')) + CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + SPACE(2) +
                             CONVERT(CHAR(50), ISNULL(LEFT(dbo.fnc_RTrim(@c_Busr1),50), '')),'') --+ SPACE(1)+
                             --CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) + SPACE(3)+  --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) 
                             --RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_NoOfUnits)),8),'') 										
							END				
                     -- Modified By Vicky on 09-Oct-2007 (End)
				
							/*IF @c_ErrFlag = 'E1'
							BEGIN
								IF @b_Repeat = '1'
								BEGIN
									INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,	
											SPACE(150), '')
	
									INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(12) + '*** Allocation Error : No Of Prepack Allocated Different Among Component SKUs ***', '')
	
									INSERT INTO @t_DiscretePS 
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
									INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(150), '')
		
									INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(12) + '*** Allocation Error : Bad Prepack Ratio Allocated In Component SKUs ***', '')
		
									INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
									VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
											@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
											SPACE(150), '')
								END	
							END */

							-- Loose Item Detail 2
							INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag, Id)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 		
							@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									 SPACE(39)+ CONVERT(CHAR(15), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) +  CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) 
									 + CONVERT(CHAR(16), ISNULL(dbo.fnc_RTrim(@c_Lottable03), '')) + SPACE(3)+
                             CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) + SPACE(3)+  
                             RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_NoOfUnits)),8) + SPACE(13) +
									 RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_UOMQty)),8),'', @c_id)
							
							/*INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 		
							@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									 CONVERT(CHAR(15), dbo.fnc_RTrim(@c_Color)) + '^' + ' Size ' + '^ ' + 
									 CONVERT(CHAR(25), dbo.fnc_RTrim(@c_Size) + ' ^ ' + dbo.fnc_RTrim(@c_Measurement)),'C1')*/
							
							--NJOW03		 
  						INSERT INTO @t_DiscretePS 
				      (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									  @c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									 SPACE(15) + '^' + '  Size  ' + '^' + LEFT(RIGHT(SPACE(7) + dbo.fnc_RTrim(@c_Size), 7) + ' ^ ' + dbo.fnc_RTrim(@c_Measurement)+ REPLICATE('', 70), 70), 'B1')

							-- BOM Box 2 : COLOUR
							INSERT INTO @t_DiscretePS 
								  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
									Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									CONVERT(CHAR(15), @c_Color) + '^' + 
									 LEFT(dbo.fnc_RTrim(CONVERT(CHAR(8), @n_NoOfUnits))+SPACE(8),8) + '^' + 
									LEFT(RIGHT(SPACE(7) + dbo.fnc_RTrim(@n_NoOfUnits), 7) + REPLICATE('', 70), 70), 'B1')

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
							INSERT INTO @t_DiscretePS 
										  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
											Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									  @c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									  REPLICATE('-', 150), '')
						END

					END -- Insert_t_Discrete : FLOOR(@n_Qty / @n_NoOfUnits) > 0
					ELSE IF @n_UOMLevel > 5 
					BEGIN 
						-- Error in Data, Display allocated records as LOOSE
						SET @n_UOMQty = 0
						SET @n_EAQty  = @n_RemainQty
						SET @n_TotalEAQty = @n_TotalEAQty + @n_EAQty
						SET @n_RemainQty  = @n_RemainQty  - @n_EAQty
            SET @c_UOM = 'PC' --NJOW06

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
							INSERT INTO @t_DiscretePS 
									  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
										Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
								 CONVERT(CHAR(12), ISNULL(dbo.fnc_RTrim(@c_Loc), '')) + CONVERT(CHAR(25), ISNULL(dbo.fnc_RTrim(@c_Style), '')) + SPACE(2)+
                 CONVERT(CHAR(50), ISNULL(LEFT(dbo.fnc_RTrim(@c_Busr1),50), '')) + SPACE(1) +
                 CONVERT(CHAR(3), ISNULL(dbo.fnc_RTrim(@c_UOM), '')) +  --CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_PPK_per), '')) + 
                 SPACE(3) + RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_NoOfUnits)),8),'') 
						END								
		
						-- Error Loose Item Detail 2
						INSERT INTO @t_DiscretePS 
							  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
								Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
								@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,	
								SPACE(150), '')

						-- Error Loose Item Detail 3
		
				INSERT INTO @t_DiscretePS 
							  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
								Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 

								@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
								SPACE(12) + '*** Data Error : Records shown as Loose ***', '')

						-- Error Loose Item Detail 4
						INSERT INTO @t_DiscretePS 
							  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
								Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
								@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
								SPACE(150), '')

						IF @c_CartonGroup = 'PREPACK' 
						BEGIN
							INSERT INTO @t_DiscretePS 
								  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
									Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									'Parent SKU : '+ dbo.fnc_RTrim(@c_AltSKU), '')
						END
						ELSE
						BEGIN
							INSERT INTO @t_DiscretePS 
								  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
									Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
							VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									'SKU : '+ dbo.fnc_RTrim(@c_AltSKU), '')
						END
					
						-- Error Loose Item Detail 5						
						INSERT INTO @t_DiscretePS 
									  (PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
										Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag, Id)
						VALUES (@c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Printedflag, @c_Storerkey, 
									@c_Putawayzone, @n_AllocatedQty, @n_OriginalQty,
									CONVERT(CHAR(14), dbo.fnc_RTrim(@c_Color)) + '^' + ' Size ' + '^' + 
									CONVERT(CHAR(23), dbo.fnc_RTrim(@c_Size) + '/' + dbo.fnc_RTrim(@c_Measurement)) + SPACE(2)+
									CONVERT(CHAR(15), ISNULL(dbo.fnc_RTrim(@c_Lottable01), '')) +  CONVERT(CHAR(17), ISNULL(dbo.fnc_RTrim(@c_Lottable02), '')) +
									CONVERT(CHAR(16), ISNULL(dbo.fnc_RTrim(@c_Lottable03), ''))+ SPACE(30)+
									 RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_EAQty)),8) + SPACE(3) +
									 RIGHT(SPACE(8)+dbo.fnc_RTrim(CONVERT(CHAR(8), @n_UOMQty)),8),'C1', @c_id)
									 
						IF @b_Repeat = '1' SET @b_Repeat = '0'
					END -- Insert_t_Conso : FLOOR(@n_Qty / @n_NoOfUnits) > 0 : @n_UOMLevel > 5
			END -- While @n_RemainQty > 0
			-- Calculate PackUOM* End Here
			
			FETCH NEXT FROM disc_calcqty_cur 
			INTO  @c_Pickslipno, @c_Loadkey, @c_Orderkey, @c_Storerkey, @c_PrintedFlag, 
					@c_AltSku, @c_CartonGroup, @c_Style, @c_Putawayzone, @c_loc, @n_Qty, 
					@c_Lottable01, @c_Lottable02, @c_Lottable03,
					@f_Pallet, @f_OtherUnit1, @f_Casecnt, @f_Innerpack, @c_ErrFlag, @c_Logicalloc, @c_id
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
			-- Seperator Dotted Line for last record
			INSERT INTO @t_DiscretePS 
				(PickSlipNo, LoadKey, Orderkey, PrintedFlag, StorerKey, 
				Putawayzone, TotalAllocateQty, TotalOrderQty, LineText, LineFlag)
			VALUES (@c_PrevPickslip, @c_Loadkey, @c_PrevOrder, @c_PrevPrintedflag, @c_PrevStorer, 
				@c_Prevzone, @n_PrevAllocatedQty, @n_PrevOriginalQty,
	
			REPLICATE('-', 150), '')
		END

		CLOSE disc_calcqty_cur
		DEALLOCATE disc_calcqty_cur		
	END -- @n_continue = 1 OR @n_continue = 2
	-- End : June01


   -- tlting
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

   While @@TRANCOUNT < @n_trancount
   BEGIn 
      BEGIN TRAN
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
            CONVERT(CHAR(15), Suser_Sname()) UserID,
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
 
                  '|', master.dbo.fnc_GetCharASCII(13))AS rightnotes1,  -- SOS#107784 
        RESULT.Id
 	FROM  @t_DiscretePS RESULT
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
	VALUES('Auto PPK Label (Discrete Pickslip) - PS#'+dbo.fnc_RTrim(@c_Pickslipno), 'AUTOPPKLBL', '0', dbo.fnc_RTrim(@c_DataWindow), 2, 
	dbo.fnc_RTrim(@c_LoadKey), sUser_sName(), '', dbo.fnc_RTrim(@c_Printer), 1, '', @c_TargetDB)
	-- End : Submit RDT Print Job

	DROP TABLE #TempDiscPickSlipSum
	DROP TABLE #TempDiscPickSlip
	DROP TABLE #TempDiscPickSlip2 
END

GO