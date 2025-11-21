SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: ispTransferAllocationForFinalize             */
/* Creation Date: 20-May-2024                                    */
/* Copyright: Maersk                                            */
/* Purpose: UWP-18603                                           */
/* Written by: Ansuman                                          */
/* Purpose: Transfer Allocation with Auto Finalize              */
/* Called By: DB Scheduler                                    */
/***************************************************************************/

CREATE   PROC [dbo].[ispTransferAllocationForFinalize](
	@c_FromStorerkey  NVARCHAR(10) = '',
	@b_Success INT= 1 OUTPUT,
	@n_Err INT= 0 OUTPUT,
	@c_ErrMsg NVARCHAR(250)= '' OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF
	SET ANSI_NULLS OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

	DECLARE
		  @n_Continue           INT
		, @c_TransferStatus     NVARCHAR(10) = ''
		, @c_TransferLineNumber NVARCHAR(5) = ''
		, @c_NewTransferLineNo  NVARCHAR(5) = ''
		, @c_TransferKey        NVARCHAR(10) = ''
		, @c_TransferKeyForFinalization        NVARCHAR(10) = ''
		, @c_FromFacility       NVARCHAR(5) = ''
		, @c_FromSku            NVARCHAR(15) = ''
		, @c_FromLot            NVARCHAR(10) = ''
		, @c_FromLoc            NVARCHAR(10) = ''
		, @c_FromID             NVARCHAR(18) = ''
		, @c_FromPackkey        NVARCHAR(10) = ''
		, @c_FromUOM            NVARCHAR(10) = ''
		, @c_ToPackkey          NVARCHAR(10) = ''
		, @c_ToUOM              NVARCHAR(10) = ''
		, @c_ToStorerkey        NVARCHAR(15) = ''
		, @c_ToSku              NVARCHAR(20) = ''
		, @c_Lottable01         NVARCHAR(18) = ''
		, @c_FromLottable02     NVARCHAR(18) = ''
		, @c_ToLottable02       NVARCHAR(18) = ''
		, @c_Lottable03         NVARCHAR(18) = ''
		, @dt_Lottable04        DATETIME
		, @dt_Lottable05        DATETIME
		, @c_Lottable06         NVARCHAR(30) = ''
		, @c_ToLottable06       NVARCHAR(30) = ''
		, @c_Lottable07         NVARCHAR(30) = ''
		, @c_ToLottable07       NVARCHAR(30) = ''
		, @c_Lottable08         NVARCHAR(30) = ''
		, @c_Lottable09         NVARCHAR(30) = ''
		, @c_Lottable10         NVARCHAR(30) = ''
		, @c_Lottable11         NVARCHAR(30) = ''
		, @c_Lottable12         NVARCHAR(30) = ''
		, @dt_Lottable13        DATETIME
		, @dt_Lottable14        DATETIME
		, @dt_Lottable15        DATETIME
		, @n_FromQty            INT = 0
		, @n_IsFirstRecord      INT = 1
		, @n_QtyAvail           INT = 0
		, @c_PrepackIndicator   NVARCHAR(30) = ''
		, @c_LogicalLoc         NVARCHAR(10) = ''
		, @c_AlertMessage       NVARCHAR(255) = ''
		, @c_UserNameInContext  NVARCHAR(128) = ''
		, @c_UserDefined02      NVARCHAR(20) = ''
		, @canBeAllocated       INT =1
		, @b_SuccessLog         INT= 1
		, @c_UpdateSLOnLottable06Change  NVARCHAR(20) = 'N'
		, @c_ConfigKey          NVARCHAR(20)  = 'ShelfLifeCalcFnc'
		, @n_ErrNo              INT = 0

	------- Retrieve records from TRANSFER UserDefine02='AUTOREL'
	BEGIN
	  DECLARE CUR_ANFTRAN CURSOR LOCAL FORWARD_ONLY STATIC FOR
		SELECT TransferKey = TF.TransferKey
			 , TransferLineNumber = TD.TransferLineNumber
			 , ToStorerKey = TD.ToStorerkey
			 , FromSku   = TD.FromSku
			 , ToSku   = TD.ToSku
			 , FromQty = TD.FromQty
			 , Facility = TF.Facility
			 , FromLottable02 = ISNULL(RTRIM(TD.Lottable02),'')
			 , ToLottable02 = ISNULL(RTRIM(TD.ToLottable02),'')
			 , ToLottable04 = ISNULL(RTRIM(TD.ToLottable04),'')
			 , SValue = ISNULL(RTRIM(SC.SValue),'0')
		FROM TRANSFERDETAIL TD WITH (NOLOCK)
			     JOIN TRANSFER TF  WITH (NOLOCK) ON (TD.TransferKey = TF.TransferKey)
			     LEFT JOIN (SELECT SValue, StorerKey, Facility from StorerConfig where ConfigKey = 'UpdateSLOnLottable06Change') SC on (TF.Facility=SC.Facility and TD.ToStorerKey = SC.StorerKey)
		  WHERE TF.Status = '0'
		  AND TF.UserDefine02 = 'AUTOREL'
          AND TF.FromStorerKey = @c_FromStorerkey
		 -- AND TD.FromLot = ''
		ORDER BY TD.TransferKey, TD.TransferLineNumber

	OPEN CUR_ANFTRAN
	FETCH NEXT FROM CUR_ANFTRAN INTO @c_TransferKey
		,  @c_TransferLineNumber
		,  @c_ToStorerkey
		,  @c_FromSku
		,  @c_ToSku
		,  @n_FromQty
		,  @c_FromFacility
		,  @c_FromLottable02
		,  @c_ToLottable02
		,  @dt_Lottable04
		,  @c_UpdateSLOnLottable06Change
	WHILE @@FETCH_STATUS <> -1
		BEGIN
			IF @c_UpdateSLOnLottable06Change = '1'
				SELECT @c_UpdateSLOnLottable06Change = SValue
				FROM StorerConfig WITH (NOLOCK)
				WHERE StorerKey = @c_ToStorerkey
					AND ConfigKey = @c_ConfigKey
			ELSE
				SET @c_UpdateSLOnLottable06Change = 'N'
			
			SELECT @c_FromPackkey = PACK.Packkey
				 , @c_FromUOM     = PACK.PackUOM3
			FROM SKU  WITH (NOLOCK)
				     JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
			WHERE SKU.Storerkey = @c_FromStorerkey
			  AND SKU.Sku       = @c_FromSku

			SELECT @c_ToPackkey = PACK.Packkey
				 , @c_ToUOM     = PACK.PackUOM3
				 , @c_PrepackIndicator = ISNULL(RTRIM(SKU.PrepackIndicator),'')
			FROM SKU WITH (NOLOCK)
				     JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
			WHERE SKU.Storerkey = @c_ToStorerkey
			  AND SKU.Sku       = @c_ToSku

			-- Populate info based on any information from the LotAttribute and LotxLocxId tables
			BEGIN
				DECLARE CUR_RELINV CURSOR LOCAL FORWARD_ONLY STATIC FOR
					SELECT Lot = LLI.Lot
						 , Loc = LLI.Loc
						 , Id = LLI.ID
						 , Qty_Available = (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)
						 , Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')
						 , Lottable03 = ISNULL(RTRIM(LA.Lottable03),'')
						 , Lottable04 = LA.Lottable04
						 , Lottable05 = LA.Lottable05
						 , Lottable06 = ISNULL(RTRIM(LA.Lottable06),'')
						 , Lottable07 = ISNULL(RTRIM(LA.Lottable07),'')
						 , Lottable08 = ISNULL(RTRIM(LA.Lottable08),'')
						 , Lottable09 = ISNULL(RTRIM(LA.Lottable09),'')
						 , Lottable10 = ISNULL(RTRIM(LA.Lottable10),'')
						 , Lottable11 = ISNULL(RTRIM(LA.Lottable11),'')
						 , Lottable12 = ISNULL(RTRIM(LA.Lottable12),'')
						 , Lottable13 = LA.Lottable13
						 , Lottable14 = LA.Lottable14
						 , Lottable15 = LA.Lottable15
						 , LogicalLocation = ISNULL(RTRIM(LOC.LogicalLocation),'')
					FROM LOT LOT WITH (NOLOCK)
						     JOIN LOTATTRIBUTE LA  WITH (NOLOCK) ON (LOT.Lot = LA.Lot)
						     JOIN LOTxLOCxID   LLI WITH (NOLOCK) ON (LOT.Lot = LLI.Lot)
						     JOIN LOC          LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)
						     JOIN ID           ID  WITH (NOLOCK) ON (LLI.ID  = ID.ID)
						     LEFT JOIN (SELECT LOTATTRIBUTE.Storerkey
						                     , LOTATTRIBUTE.Sku
						                     , LOC.LocationType
						                     , LocQtyAvail = SUM(LOTxLOCxID.Qty - LOTxLOCxID.QtyAllocated - LOTxLOCxID.QtyPicked )
						                FROM LOTATTRIBUTE  WITH (NOLOCK)
							                     JOIN LOTxLOCxID    WITH (NOLOCK) ON (LOTATTRIBUTE.Lot = LOTxLOCxID.Lot)
							                     JOIN LOC           WITH (NOLOCK) ON (LOTxLOCxID.Loc = LOC.Loc)
						                WHERE LOTATTRIBUTE.Storerkey = @c_FromStorerkey
							              AND LOTATTRIBUTE.Sku       = @c_FromSku
							              AND LOTATTRIBUTE.Lottable02= @c_FromLottable02
							              AND LOC.Facility           = @c_FromFacility
						                GROUP BY LOTATTRIBUTE.Storerkey
						                       , LOTATTRIBUTE.Sku
						                       , LOC.LocationType ) AS LINV
						               ON (LINV.Storerkey = LOT.Storerkey)
							               AND(LINV.Sku = LOT.Sku)
							               AND(LINV.LocationType = LOC.LocationType)
					WHERE LOT.Storerkey = @c_FromStorerkey
					  AND LOT.Sku       = @c_FromSku
					  AND LOC.Facility  = @c_FromFacility
					  AND LA.Lottable02 = @c_FromLottable02
					  AND LA.Lottable06 = '1'
					  AND LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated > 0
					  AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0
					  AND LOT.Status = 'OK'
					  AND LOC.Status = 'OK'
					  AND LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )
					  AND ID.Status  = 'OK'
					  AND DATEDIFF(DAY, GETDATE(), LA.Lottable04) >= 0
					  AND LA.Lottable07 NOT IN ('ML53', 'ML54')
					ORDER BY
						(LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked)

				OPEN CUR_RELINV
				FETCH NEXT FROM CUR_RELINV INTO
				       @c_FromLot
					,  @c_FromLoc
					,  @c_FromID
					,  @n_QtyAvail
					,  @c_Lottable01
					,  @c_Lottable03
					,  @dt_Lottable04
					,  @dt_Lottable05
				    ,  @c_Lottable06
				    ,  @c_Lottable07
					,  @c_Lottable08
					,  @c_Lottable09
					,  @c_Lottable10
					,  @c_Lottable11
					,  @c_Lottable12
					,  @dt_Lottable13
					,  @dt_Lottable14
					,  @dt_Lottable15
					,  @c_LogicalLoc
				IF (SELECT CURSOR_STATUS('LOCAL','CUR_RELINV')) = 0
					SET @canBeAllocated = 0 -- If this cursor returns no result, then transfer header is not updated.
				WHILE @@FETCH_STATUS <> -1
						BEGIN
							--- Update/Insert into TRANSFERDETAIL -- Split New Transfer Line--
							SET @c_TransferStatus = '0'
							SET @c_UserDefined02 = 'ALLOCATION_DONE'
							IF @c_UpdateSLOnLottable06Change='fnc_CalcShelfLifeBUL'
								SELECT @c_ToLottable07 =  dbo.fnc_CalcShelfLifeBUL(@c_ToStorerkey, @c_ToSku, @dt_Lottable04)
							ELSE IF @c_UpdateSLOnLottable06Change='fnc_CalcShelfLifeBUD'
								SELECT @c_ToLottable07 =  dbo.fnc_CalcShelfLifeBUD(@c_ToStorerkey, @c_ToSku, @dt_Lottable04, @dt_Lottable13)
							ELSE
								SET @c_ToLottable07 = @c_Lottable07
							IF @c_ToLottable07 = 'ML51'
								SET @c_ToLottable06 = '1'
							ELSE
								SET @c_ToLottable06 = '0'
							IF(@n_IsFirstRecord = 1)
							BEGIN TRY
								BEGIN
									UPDATE TRANSFERDETAIL WITH (ROWLOCK)
									SET Status = @c_TransferStatus
									  ,FromLot  = @c_FromLot
									  ,FromLoc  = @c_FromLoc
									  ,FromID   = @c_FromID
									  ,FromQty  = @n_QtyAvail
									  ,Lottable01 = @c_Lottable01
									  ,Lottable03 = @c_Lottable03
									  ,Lottable04 = @dt_Lottable04
									  ,Lottable05 = @dt_Lottable05
									  ,Lottable06 = '1'
									  ,Lottable07 = @c_Lottable07
									  ,Lottable08 = @c_Lottable08
									  ,Lottable09 = @c_Lottable09
									  ,Lottable10 = @c_Lottable10
									  ,Lottable11 = @c_Lottable11
									  ,Lottable12 = @c_Lottable12
									  ,Lottable13 = @dt_Lottable13
									  ,Lottable14 = @dt_Lottable14
									  ,Lottable15 = @dt_Lottable15
									  ,ToLoc      = @c_FromLoc
									  ,ToID       = @c_FromID
									  ,ToQty      = @n_QtyAvail
									  ,ToLottable01 = @c_Lottable01
									  ,ToLottable03 = @c_Lottable03
									  ,ToLottable04 = @dt_Lottable04
									  ,ToLottable05 = @dt_Lottable05
									  ,ToLottable06 = @c_ToLottable06
									  ,ToLottable07 = @c_ToLottable07
									  ,ToLottable08 = @c_Lottable08
									  ,ToLottable09 = @c_Lottable09
									  ,ToLottable10 = @c_Lottable10
									  ,ToLottable11 = @c_Lottable11
									  ,ToLottable12 = @c_Lottable12
									  ,ToLottable13 = @dt_Lottable13
									  ,ToLottable14 = @dt_Lottable14
									  ,ToLottable15 = @dt_Lottable15
									  ,UserDefine02 = @c_UserDefined02
									WHERE Transferkey = @c_Transferkey
									AND TransferLineNumber = @c_TransferLineNumber
								END
							END TRY
							BEGIN CATCH
								BEGIN
									SET @n_err = @@ERROR
										IF @n_err <> 0
											BEGIN
												SET @n_continue = 3
												SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
												SET @n_err = 81005
												SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFERDETAIL Failed. (ispTransferAllocationForFinalize)'
													+ ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
												GOTO NEXT_TRF
											END
								END
							END CATCH
							IF(@n_IsFirstRecord = 1)
							    BEGIN
								    SET @n_IsFirstRecord = 0
								    FETCH NEXT FROM CUR_RELINV INTO
									       @c_FromLot
									    ,  @c_FromLoc
									    ,  @c_FromID
									    ,  @n_QtyAvail
									    ,  @c_Lottable01
									    ,  @c_Lottable03
									    ,  @dt_Lottable04
									    ,  @dt_Lottable05
									    ,  @c_Lottable06
									    ,  @c_Lottable07
									    ,  @c_Lottable08
									    ,  @c_Lottable09
									    ,  @c_Lottable10
									    ,  @c_Lottable11
									    ,  @c_Lottable12
									    ,  @dt_Lottable13
									    ,  @dt_Lottable14
									    ,  @dt_Lottable15
									    ,  @c_LogicalLoc
							        CONTINUE
							    END

							    BEGIN TRY
									BEGIN
										SELECT @c_NewTransferLineNo = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(CONVERT(INT, TransferLineNumber)) + 1),5)
										FROM TRANSFERDETAIL WITH (NOLOCK)
										WHERE Transferkey = @c_Transferkey

										INSERT INTO TRANSFERDETAIL
										( TransferKey
										, TransferLineNumber
										, FromStorerkey
										, FromSku
										, FromLot
										, FromLoc
										, FromID
										, FromPackkey
										, FromUOM
										, Lottable01
										, Lottable02
										, Lottable03
										, Lottable04
										, Lottable05
										, Lottable06
										, Lottable07
										, Lottable08
										, Lottable09
										, Lottable10
										, Lottable11
										, Lottable12
										, Lottable13
										, Lottable14
										, Lottable15
										, FromQty
										, ToStorerkey
										, ToSku
										, ToLoc
										, ToID
										, ToPackkey
										, ToUOM
										, ToLottable01
										, ToLottable02
										, ToLottable03
										, ToLottable04
										, ToLottable05
										, ToLottable06
										, ToLottable07
										, ToLottable08
										, ToLottable09
										, ToLottable10
										, ToLottable11
										, ToLottable12
										, ToLottable13
										, ToLottable14
										, ToLottable15
										, ToQty
										, [Status]
										, UserDefine02
										)
										VALUES
											( @c_TransferKey
											, @c_NewTransferLineNo
											, @c_FromStorerkey
											, @c_FromSku
											, @c_FromLot
											, @c_FromLoc
											, @c_FromID
											, @c_FromPackkey
											, @c_FromUOM
											, @c_Lottable01
											, @c_FromLottable02
											, @c_Lottable03
											, @dt_Lottable04
											, @dt_Lottable05
											, '1'
											, @c_Lottable07
											, @c_Lottable08
											, @c_Lottable09
											, @c_Lottable10
											, @c_Lottable11
											, @c_Lottable12
											, @dt_Lottable13
											, @dt_Lottable14
											, @dt_Lottable15
											, @n_QtyAvail
											, @c_ToStorerkey
											, @c_ToSku
											, @c_FromLoc
											, @c_FromID
											, @c_ToPackkey
											, @c_ToUOM
											, @c_Lottable01
											, @c_ToLottable02
											, @c_Lottable03
											, @dt_Lottable04
											, @dt_Lottable05
											, @c_ToLottable06
											, @c_ToLottable07
											, @c_Lottable08
											, @c_Lottable09
											, @c_Lottable10
											, @c_Lottable11
											, @c_Lottable12
											, @dt_Lottable13
											, @dt_Lottable14
											, @dt_Lottable15
											, @n_QtyAvail
											, @c_TransferStatus
											, @c_UserDefined02
											)
									END
									END TRY

							    BEGIN CATCH
									BEGIN
										SET @n_err = @@ERROR

										IF @n_err <> 0
												BEGIN
													SET @n_continue = 3
													SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
													SET @n_err = 81010
													SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT FOR TRANSFERDETAIL Failed. (ispTransferAllocationForFinalize)'
														+ ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
													GOTO NEXT_TRF
												END
									END
							    END CATCH

						NEXT_TRF:
							IF @n_continue = 3  -- Error Occured
								BEGIN
									SET @b_success = 0
									--- Error Handling ----
									SET @c_AlertMessage = 'There is error on Transfer allocation via Auto Release Process. TransferKey : ' + @c_TransferKey +
									                      ' - ' + @c_ErrMsg
									BEGIN TRAN

										EXEC nspLogAlert
										     @c_modulename       = 'ispTransferAllocationForFin'
											, @c_AlertMessage     = @c_AlertMessage
											, @n_Severity         = '5'
											, @b_success          = @b_SuccessLog   OUTPUT
											, @n_err              = @n_Err        OUTPUT
											, @c_errmsg           = @c_ErrMsg     OUTPUT
											, @c_Activity         = 'Batch process mode'
											, @c_Storerkey        = @c_FromStorerkey
											, @c_SKU              = ''
											, @c_UOM              = ''
											, @c_UOMQty           = ''
											, @c_Qty              = 0
											, @c_Lot              = ''
											, @c_Loc              = ''
											, @c_ID               = ''
											, @c_TaskDetailKey    = ''

										WHILE @@TRANCOUNT > 0
											BEGIN
												COMMIT TRAN
											END
								END
						SET @n_continue = 1 --resetting error flag
						FETCH NEXT FROM CUR_RELINV INTO
							   @c_FromLot
							,  @c_FromLoc
							,  @c_FromID
							,  @n_QtyAvail
							,  @c_Lottable01
							,  @c_Lottable03
							,  @dt_Lottable04
							,  @dt_Lottable05
							,  @c_Lottable06
							,  @c_Lottable07
							,  @c_Lottable08
							,  @c_Lottable09
							,  @c_Lottable10
							,  @c_Lottable11
							,  @c_Lottable12
							,  @dt_Lottable13
							,  @dt_Lottable14
							,  @dt_Lottable15
							,  @c_LogicalLoc
					END
					CLOSE CUR_RELINV
					DEALLOCATE CUR_RELINV

				SET @n_IsFirstRecord = 1
			END
			-- Update UserDefined02 to 'ALLOCATION_DONE' in TRANSFER post allocation --
			IF (@canBeAllocated = 1) -- Flag to track transfer header update based on CUR_RELINV result . If no allocation is done, we aren't updating transfer header
				BEGIN
					SET @c_UserDefined02 = 'ALLOCATION_DONE' -- Indicator for the allocation status
						UPDATE TRANSFER WITH (ROWLOCK)
						SET UserDefine02 = @c_UserDefined02
						WHERE Transferkey = @c_Transferkey
				END
			FETCH NEXT FROM CUR_ANFTRAN INTO @c_TransferKey
				,  @c_TransferLineNumber
				,  @c_ToStorerkey
				,  @c_FromSku
				,  @c_ToSku
				,  @n_FromQty
				,  @c_FromFacility
				,  @c_FromLottable02
				,  @c_ToLottable02
				,  @dt_Lottable04
				,  @c_UpdateSLOnLottable06Change
		SET @canBeAllocated = 1 --setting to default value
		END
	 CLOSE CUR_ANFTRAN
	 DEALLOCATE CUR_ANFTRAN
	END

	---- SELECT Records FOR Finalization, loop over and call : lsp_FinalizeTransfer_Wrapper -> ispFinalizeTransfer ----
	BEGIN
	  DECLARE CUR_FINTRAN CURSOR LOCAL FORWARD_ONLY STATIC FOR
		  SELECT  T.TransferKey
		  FROM TRANSFER T WITH (NOLOCK)
		  WHERE T.UserDefine02 IN ('ALLOCATION_DONE', 'AUTOREL')
          AND T.FromStorerKey = @c_FromStorerkey
		  AND T.Status <> '9'
		  AND NOT EXISTS(SELECT 1
			               FROM TRANSFERDETAIL TD WITH (NOLOCK)
			               WHERE TD.TransferKey = T.TransferKey
				           AND TD.Status = '0'
				           AND TD.FromLot = ''
				           AND TD.ToLottable06 = '1'
			               AND TD.UserDefine02 <> 'ALLOCATION_DONE')

	SET @c_UserNameInContext = SUSER_SNAME()

	OPEN CUR_FINTRAN
	FETCH NEXT FROM CUR_FINTRAN INTO @c_TransferKeyForFinalization
	WHILE @@FETCH_STATUS <> -1
	    BEGIN
			EXEC [WM].lsp_FinalizeTransfer_Wrapper @c_TransferKeyForFinalization,
		@b_Success OUTPUT
			    , @n_Err OUTPUT
				, @c_ErrMsg OUTPUT
				,  @c_username = @c_UserNameInContext
			IF @n_err <> 0
					BEGIN
						SET @n_continue = 3
						SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
						SET @n_err = 81180
						SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Finalize TRANSFER Failed. (ispTransferAllocationForFinalize->lsp_FinalizeTransfer_Wrapper)'
							+ ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
						GOTO ERROR_HANDLE
					END

			ERROR_HANDLE:

			IF @n_continue = 3  -- Error Occured
					BEGIN
						--- Error Handling ----
						SET @c_AlertMessage = 'There is an error on Finalize TRANSFER via Auto Inventory Release Process. TransferKey : ' + @c_TransferKeyForFinalization +
						                      ' - ' + @c_ErrMsg
						BEGIN TRAN
							EXEC nspLogAlert
							      @c_modulename       = 'ispTransferAllocationForFin'
								, @c_AlertMessage     = @c_AlertMessage
								, @n_Severity         = '5'
								, @b_success          = @b_SuccessLog OUTPUT
								, @n_err              = @n_Err        OUTPUT
								, @c_errmsg           = @c_ErrMsg     OUTPUT
								, @c_Activity         = 'Batch process mode'
								, @c_Storerkey        = @c_FromStorerkey
								, @c_SKU              = ''
								, @c_UOM              = ''
								, @c_UOMQty           = ''
								, @c_Qty              = 0
								, @c_Lot              = ''
								, @c_Loc              = ''
								, @c_ID               = ''
								, @c_TaskDetailKey    = ''

							WHILE @@TRANCOUNT > 0
								BEGIN
									COMMIT TRAN
								END
					END
		 IF @b_Success = 1
				 BEGIN
					 SET @c_UserDefined02 = 'DONE'
					 UPDATE TRANSFER WITH (ROWLOCK)
					 SET UserDefine02 = @c_UserDefined02, TrafficCop=NULL
					 WHERE Transferkey = @c_TransferKeyForFinalization
				 END
         SET @n_continue = 1 --resetting error flag
	     FETCH NEXT FROM CUR_FINTRAN INTO @c_TransferKeyForFinalization
		END
		CLOSE CUR_FINTRAN
		DEALLOCATE CUR_FINTRAN
	 END

QUIT_SP:

END

GO