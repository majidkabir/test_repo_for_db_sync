SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  nsp_CancelExpiredPOOrders                   		   */
/* Creation Date: 15-Apr-2005                           						*/
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                    					*/
/*                                                                      */
/* Purpose:  Cancel Expired PO and Orders (C4MY) - SOS34015		         */
/*                                                                      */
/* Input Parameters:  @c_module,    - Module name: PO or ORDERS         */
/*                    @c_storerkey, - Storerkey                         */
/*                    @c_criteria1, - Criteria1:PO.POType or Orders.Type*/
/*                    @c_criteria1value, - Criteria1 value              */
/*                    @c_criteria2, - Critria2, normally is a date      */
/*                    @c_criteria2value, - Criteria2 value              */
/*                    @n_buffer,    - in days                           */
/*                    @c_originalstatus, - Current Status               */
/*                    @c_finalstatus,    - Updated Status               */
/*                    @b_success,        - return value                 */
/*                    @n_err,            - error number                 */
/*                    @c_errmsg          - error message                */
/*                                                                      */
/* Called By:                                       							*/
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 29-Nov-2005  MaryVong		SOS43525 											*/
/*										-> Fixed performance issue while	bulk 		*/
/*											Cancel Expired Orders. Thus, a new sp 	*/
/*											is created, nsp_CancelExpiredOrders		*/
/*										-> Changed BEGIN TRAN to lock for only 	*/
/*											record for each update				      */
/* 22-Feb-2013  TLTING        Paremeter value truncated (tlting01)      */
/*																								*/
/************************************************************************/

CREATE PROCEDURE [dbo].[nsp_CancelExpiredPOOrders]
   @c_module              NVARCHAR(20),
   @c_storerkey           NVARCHAR(15),
   @c_criteria1           NVARCHAR(40),
   @c_criteria1value      NVARCHAR(100),     
   @c_criteria2           NVARCHAR(40),                 
   @c_criteria2value      NVARCHAR(100),
   @n_buffer              int,
   @c_originalstatus      NVARCHAR(10),
   @c_finalstatus         NVARCHAR(10),
	@b_success             int        OUTPUT,
	@n_err                 int        OUTPUT,    
	@c_errmsg              NVARCHAR(250)  OUTPUT    
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF   
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 

	DECLARE	@n_continue int,  
		@n_starttcnt       int, -- Holds the current transaction count
		@n_cnt            int, -- Holds @@ROWCOUNT after certain operations
		@b_debug          int  -- Debug On or Off

	DECLARE @d_DateCompared		datetime,
      @c_originalstatuscol  NVARCHAR(20),
      @c_finalstatuscol     NVARCHAR(20),
		@c_POKey					 NVARCHAR(10),
		@c_ReceiptKey			 NVARCHAR(10),		
      @c_UpdateStmt			 NVARCHAR(200),
      @c_WhereClause			 NVARCHAR(1000)

	SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='',
	       @b_debug=0

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
      -- Get date for comparison
		SELECT @d_DateCompared = DATEADD(DAY, -@n_buffer, GETDATE())
		SELECT @d_DateCompared = DATEADD(DAY, 1, @d_DateCompared)
	END

	IF (@n_continue = 1 OR @n_continue = 2)
	BEGIN
      -- BEGIN TRAN

      SELECT @c_UpdateStmt = ''
		SELECT @c_WhereClause = ''

      IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) = 'PO'
      BEGIN
         SELECT @c_originalstatuscol = 'ExternStatus'
         SELECT @c_finalstatuscol = 'ExternStatus'
      END
      ELSE IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) = 'ORDERS'
      BEGIN
         SELECT @c_originalstatuscol = 'Status'
         SELECT @c_finalstatuscol = 'SOStatus'
      END
      ELSE
      BEGIN
         SELECT @n_continue=3
      END

      -- Build Update statement
      SELECT @c_UpdateStmt = 'UPDATE ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) + ' WITH (ROWLOCK) ' +
                     ' SET ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_finalstatuscol)) + ' = ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_finalstatus)) 

		SELECT @c_WhereClause = ' WHERE StorerKey = ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_storerkey)) + 
                     ' AND ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_criteria1)) + ' IN ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_criteria1value)) +
                     ' AND ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_criteria2)) + ' < ' + 'N''' + CONVERT(char(8),@d_DateCompared,112) + '''' +
                     ' AND ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_originalstatuscol)) + ' = ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_originalstatus))	

      IF @b_debug = 1
      BEGIN
         SELECT '@c_UpdateStmt: ' + @c_UpdateStmt
			SELECT '@c_WhereClause: ' + @c_WhereClause
      END
		
		IF (@n_continue = 1 OR @n_continue = 2)
		BEGIN 
			IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) = 'ORDERS'
			BEGIN
				-- Cancel Orders
				-- SOS43525 Causing performance issue
	         -- EXEC (@c_UpdateStmt + @c_WhereClause)
				SELECT @b_success = 1
				EXEC nsp_CancelExpiredOrders
					@c_module, 
					@c_UpdateStmt, 
					@c_WhereClause,
					@b_success OUTPUT, 
					@n_err OUTPUT, 
					@c_errmsg OUTPUT

				IF NOT @b_success = 1
				BEGIN
	            SELECT @n_continue = 3
	            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=61000   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) + ' (nsp_CancelExpiredPOOrders)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
				END
			END
			ELSE IF dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) = 'PO'
			BEGIN
				IF (@n_continue = 1 OR @n_continue = 2)
				BEGIN
					SELECT @c_POKey = ''
					SELECT @c_ReceiptKey = ''

					-- Check if Receipt exists and not processed
		         EXEC (
		         ' DECLARE RECEIPT_CUR CURSOR FAST_FORWARD READ_ONLY FOR ' + 
		         ' SELECT POKey FROM PO (NOLOCK) ' + @c_WhereClause + 
		         ' ORDER BY POKey ' ) 

		         OPEN RECEIPT_CUR 
		         
		         FETCH NEXT FROM RECEIPT_CUR INTO @c_POKey
	
					WHILE @@FETCH_STATUS <> -1
					BEGIN
						IF @b_debug = 1
						BEGIN
							SELECT @c_POKey '@c_POKey'
						END

						-- NO ASN exists for the PO
						IF NOT EXISTS (SELECT 1 FROM RECEIPT(NOLOCK) WHERE POKey = @c_POKey)
						BEGIN
							BEGIN TRAN
							-- Cancel PO directly
				         EXEC (@c_UpdateStmt + @c_WhereClause + ' AND POKey = N''' + @c_POKey + ''' ')
				
							SELECT @n_err = @@ERROR
							IF @n_err <> 0
							BEGIN 
				            SELECT @n_continue = 3
				            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=61001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
				            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) + ' (nsp_CancelExpiredPOOrders)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
								ROLLBACK TRAN	
							END
							ELSE
							BEGIN
								COMMIT TRAN
							END
						END
						-- 1 PO to 1 ASN (not processed yet)
						ELSE IF (SELECT COUNT(1) FROM RECEIPT(NOLOCK) WHERE POKey = @c_POKey AND Status = '0' AND ASNStatus = '0') = 1
						BEGIN
							SELECT @c_ReceiptKey = ReceiptKey FROM RECEIPT(NOLOCK) 
							WHERE POKey = @c_POKey AND Status = '0' AND ASNStatus = '0'

							IF @b_debug = 1
							BEGIN
								SELECT @c_ReceiptKey '@c_ReceiptKey'
							END

							-- Cancelled ASN only when no qty received and no finalized receiptlines
							IF NOT EXISTS (SELECT 1 FROM RECEIPTDETAIL(NOLOCK) WHERE ReceiptKey = @c_ReceiptKey
													 				AND (QtyReceived > 0  OR FinalizeFlag = 'Y')  ) 
							BEGIN
								BEGIN TRAN
								UPDATE RECEIPT
								SET	ASNStatus = 'CANC'
								WHERE ReceiptKey = @c_ReceiptKey

								SELECT @n_err = @@ERROR
								IF @n_err <> 0
								BEGIN 
					            SELECT @n_continue = 3
					            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=61002   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
					            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) + ' (nsp_CancelExpiredPOOrders)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
									ROLLBACK TRAN
								END
								ELSE
								BEGIN
									COMMIT TRAN
								END

								IF (@n_continue = 1 OR @n_continue = 2) 
								BEGIN
									-- Cancel PO
									IF @b_debug = 1
									BEGIN
										SELECT 'Cancel PO'
										SELECT @c_UpdateStmt + @c_WhereClause + ' AND POKey = N''' + @c_POKey + ''' '
									END

									BEGIN TRAN
						         EXEC (@c_UpdateStmt + @c_WhereClause + ' AND POKey = N''' + @c_POKey + ''' ')
						
									SELECT @n_err = @@ERROR
									IF @n_err <> 0
									BEGIN 
						            SELECT @n_continue = 3
						            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=61003   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
						            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) + ' (nsp_CancelExpiredPOOrders)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
										ROLLBACK TRAN
									END
									ELSE
									BEGIN
										COMMIT TRAN
									END												
								END -- IF (@n_continue = 1 OR @n_continue = 2) 
							END
						END -- 1 PO to 1 ASN

		         	FETCH NEXT FROM RECEIPT_CUR INTO @c_POKey
					END -- @@FETCH_STATUS <> -1
					
					CLOSE RECEIPT_CUR
					DEALLOCATE RECEIPT_CUR
				END

			END -- IF (@n_continue = 1 OR @n_continue = 2)
		END -- module = 'PO'

		-- Remarked (SOS43525)
		-- IF (@n_continue = 1 OR @n_continue = 2)
		-- BEGIN
		-- 	COMMIT TRAN
		-- END
		-- ELSE
		-- BEGIN
		-- 	ROLLBACK TRAN
		-- END 

	END

	/* #INCLUDE <SPARReceipt2.SQL> */     
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		SELECT @b_success = 0
		IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		ELSE
		BEGIN
			WHILE @@TRANCOUNT > @n_starttcnt
			BEGIN
				COMMIT TRAN
			END
		END

		EXECUTE nsp_logerror @n_err, @c_errmsg, 'nsp_CancelExpiredPOOrders'
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
		SELECT @b_success = 1
		WHILE @@TRANCOUNT > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
END -- main

GO