SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/***************************************************************************/
/* Stored Procedure: ispFetchStorersAndTriggerAutoFinalize             */
/* Creation Date: 19-June-2024                                         */
/* Copyright: Maersk                                                   */
/* Purpose: UWP-19599                                                  */
/* Written by: Ansuman                                                 */
/* Purpose: Fetch StorerKeys and Trigger AutoFinalize Workflow         */
/* Called By: DB Scheduler                                             */
/***************************************************************************/

CREATE   PROC [dbo].[ispFetchStorersAndTriggerAutoFinalize](
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
			 @c_StorerKey    NVARCHAR(80)
		    ,@n_Continue     INT
		    ,@c_AlertMessage NVARCHAR(255) = ''
		    ,@b_SuccessLog   INT= 1

		BEGIN
			DECLARE CUR_TEMP CURSOR LOCAL FORWARD_ONLY STATIC FOR
				SELECT StorerKey FROM [dbo].[StorerConfig] WITH (NOLOCK) WHERE ConfigKey = 'AutoTransferFinalize' AND SValue = '1'

			OPEN CUR_TEMP
			FETCH NEXT FROM CUR_TEMP INTO @c_StorerKey

			WHILE @@FETCH_STATUS <> -1
				BEGIN
					EXEC [dbo].[ispTransferAllocationForFinalize] @c_StorerKey,
					     @b_Success OUTPUT
					    ,@n_Err OUTPUT
					    ,@c_ErrMsg OUTPUT
					IF @n_err <> 0
							BEGIN
								SET @n_continue = 3
								SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
								SET @n_err = 81182
								SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': The AutoFinalize processing has an error . The flow is Scheduler->ispFetchStorersAndTriggerAutoFinalize ->ispTransferAllocationForFinalize'
									+ ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '
								GOTO ERROR_HANDLE
							END

					ERROR_HANDLE:

					IF @n_continue = 3  -- Error Occured
							BEGIN
								--- Error Handling ----
								SET @c_AlertMessage = 'The AutoFinalize processing triggered by scheduler has an error.' +' - ' + @c_ErrMsg
								BEGIN TRAN
									EXEC nspLogAlert
									      @c_modulename       = 'ispFetchStorersAndTriggerAutoFinalize'
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
					FETCH NEXT FROM CUR_TEMP INTO @c_StorerKey
				END
			CLOSE CUR_TEMP
			DEALLOCATE CUR_TEMP
		END
	END
END

GO