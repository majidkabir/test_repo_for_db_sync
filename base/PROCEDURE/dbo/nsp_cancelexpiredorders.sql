SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nsp_CancelExpiredOrders                      		*/
/* Creation Date: 29-Nov-2005                                           */
/* Copyright: IDS                                                       */
/* Written by: MaryVong                                                 */
/*                                                                      */
/* Purpose: Cancel Expired Orders (SOS43525)	- C4MY - To resolve			*/
/*				Performance issue															*/
/*                                                                      */
/* Called By: nsp_CancelExpiredPOOrders		                           */
/*                                                                      */
/* PVCS Version: 1.0		                                             	*/
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/*                                                                      */
/************************************************************************/

CREATE PROC [dbo].[nsp_CancelExpiredOrders]
	@c_module			 NVARCHAR(20), 
	@c_UpdateStmt		 NVARCHAR(1000),
	@c_WhereClause		 NVARCHAR(1000),
	@b_success				int			OUTPUT,
	@n_err					int			OUTPUT,    
	@c_errmsg			 NVARCHAR(250)	OUTPUT 
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF 

	DECLARE	@n_continue int,  
		@n_starttcnt       int, -- Holds the current transaction count
		@n_cnt            int, -- Holds @@ROWCOUNT after certain operations
		@b_debug          int  -- Debug On or Off
	
	DECLARE	@c_OrderKey NVARCHAR(10)

	SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err=0, @c_errmsg='',
	   @b_debug=0

	IF @n_continue = 1 OR @n_continue = 2
	BEGIN
		
		EXEC (
		' DECLARE ORDER_CUR CURSOR FAST_FORWARD READ_ONLY FOR ' + 
		' SELECT OrderKey FROM ORDERS (NOLOCK) ' + @c_WhereClause + 
		' ORDER BY OrderKey ' ) 
	
		OPEN ORDER_CUR 
		
		FETCH NEXT FROM ORDER_CUR INTO @c_OrderKey
		
		WHILE @@FETCH_STATUS <> -1
		BEGIN
			IF @b_debug = 1
			BEGIN
				SELECT @c_OrderKey '@c_OrderKey'
				SELECT 'update statement: '+ @c_UpdateStmt +  ' WHERE OrderKey = N''' + @c_OrderKey + ''' '
			END

			IF @b_debug = 0
			BEGIN	
				BEGIN TRAN
				EXEC (@c_UpdateStmt +  ' WHERE OrderKey = N''' + @c_OrderKey + ''' ' )
				
				SELECT @n_err = @@ERROR
				IF @n_err <> 0
				BEGIN 
	            SELECT @n_continue = 3
	            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=61000
	            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update Failed On ' + dbo.fnc_RTrim(dbo.fnc_LTrim(@c_module)) + 
											' (nsp_CancelExpiredOrders)' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
					ROLLBACK TRAN
				END	
				ELSE
				BEGIN
					COMMIT TRAN
				END			
			END

      	FETCH NEXT FROM ORDER_CUR INTO @c_OrderKey
		END -- @@FETCH_STATUS <> -1
		
		CLOSE ORDER_CUR
		DEALLOCATE ORDER_CUR
	END

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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nsp_CancelExpiredOrders"
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
END

GO