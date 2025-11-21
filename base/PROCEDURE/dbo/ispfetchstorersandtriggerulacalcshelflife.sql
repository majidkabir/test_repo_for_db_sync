SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/
/* Stored Procedure: ispFetchStorersAndTriggerULACalcShelfLife             */
/* Creation Date: 03-Aug-2024                                         */
/* Copyright: Maersk                                                   */
/* Purpose: UWP-22018                                                  */
/* Written by: SBA757                                                 */
/* Purpose: Fetch StorerKeys and Trigger ULACalcShelfLife  Workflow   */
/* Called By: DB Scheduler                                             */
/***************************************************************************/

CREATE   PROC [dbo].[ispFetchStorersAndTriggerULACalcShelfLife](
   @b_Success        INT          = 1   OUTPUT
,  @n_Err            INT          = 0   OUTPUT
,  @c_ErrMsg         NVARCHAR(250)= ''  OUTPUT
)
AS
BEGIN
	SET NOCOUNT ON
	SET QUOTED_IDENTIFIER OFF
	SET ANSI_NULLS OFF
	SET CONCAT_NULL_YIELDS_NULL OFF

	BEGIN
		DECLARE
			@c_StorerKey		NVARCHAR(80)
			,@c_TranType    	NVARCHAR(80)
			,@n_Continue     	INT
			,@c_AlertMessage 	NVARCHAR(255) = ''
			,@b_SuccessLog   	INT = 1
			,@b_debug			INT = 0

		BEGIN
			DECLARE CUR_TEMP CURSOR LOCAL FORWARD_ONLY STATIC FOR
				SELECT StorerKey, OPTION1 FROM [dbo].[StorerConfig] WITH (NOLOCK) WHERE ConfigKey = 'UpdateSLOnLottable06Change' AND SValue = '1'

			OPEN CUR_TEMP
			FETCH NEXT FROM CUR_TEMP INTO @c_StorerKey, @c_TranType
			WHILE @@FETCH_STATUS <> -1
				BEGIN
					EXEC [dbo].[msp_ULACalcShelfLife] 
						@c_StorerKey
						, @c_TranType
						, @b_debug
						, @b_Success OUTPUT
						,@n_Err OUTPUT
						,@c_ErrMsg OUTPUT
					IF @n_err <> 0
							BEGIN
								SET @n_continue = 3
								SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
								SET @n_err = 81182
								SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The updating shelf life faced an error . The flow is Scheduler->ispFetchStorersAndTriggerULACalcShelfLife ->msp_ULACalcShelfLife'
									+ ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
								GOTO ERROR_HANDLE
							END

					ERROR_HANDLE:
						IF @n_continue = 3  -- Error Occured
							BEGIN
								--- Error Handling ----
								SET @c_AlertMessage = 'SP msp_ULACalcShelfLife triggered by scheduler has an error.' +' - ' + @c_ErrMsg
								BEGIN TRAN
									EXEC nspLogAlert
									      @c_modulename       = 'ispFetchStorersAndTriggerULACalcShelfLife'
										, @c_AlertMessage     = @c_AlertMessage
										, @n_Severity         = '5'
										, @b_success          = @b_SuccessLog OUTPUT
										, @n_err              = @n_Err        OUTPUT
										, @c_errmsg           = @c_ErrMsg     OUTPUT
										, @c_Activity         = 'Scheduled Task'
										, @c_Storerkey        = @c_StorerKey
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
					FETCH NEXT FROM CUR_TEMP INTO @c_StorerKey, @c_TranType
				END
			CLOSE CUR_TEMP
			DEALLOCATE CUR_TEMP
		END
	END
END

GO