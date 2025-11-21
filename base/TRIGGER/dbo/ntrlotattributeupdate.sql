SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Trigger: ntrLOTATTRIBUTEUpdate                                       */
/* Creation Date:  09-Sept-2008                                         */
/* Copyright: IDS                                                       */
/* Written by:  TLTING                                                  */
/*                                                                      */
/* Purpose: LOTATTRIBUTE Update Transaction                             */
/*                                                                      */
/* Input Parameters:                                                    */
/*                                                                      */
/* Output Parameters:                                                   */
/*                                                                      */
/* Return Status:                                                       */
/*                                                                      */
/* Usage:                                                               */
/*                                                                      */
/* Local Variables:                                                     */
/*                                                                      */
/* Called By: When records updated                                      */
/*                                                                      */
/* PVCS Version: 1.5                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 23 May 2012  TLTING01      DM integrity - add update editdate B4     */
/*                            TrafficCop                                */ 
/* 28-Oct-2013  TLTING        Review Editdate column update             */
/* 24-Apr-2014  TLTING   1.1  Add Lottable06-15                         */
/* 09-JAN-2015  CSCHONG  1.2  Fix RDT bugs (CS01)                       */
/* 28-Sep-2018  TLTING   1.3  Remove row lock                           */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrLOTATTRIBUTEUpdate]
ON [dbo].[LOTATTRIBUTE]
FOR UPDATE
AS 
BEGIN
IF @@ROWCOUNT = 0
BEGIN
   RETURN
END   
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
	SET CONCAT_NULL_YIELDS_NULL OFF
	
	DECLARE	@n_err                int       -- Error number returned by stored procedure or this trigger
	,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
	,         @n_continue int                 
	,         @n_starttcnt int                -- Holds the current transaction count
	,         @n_cnt int                  
	
	SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
   	SELECT @n_continue = 4 
   END
   
   -- TLTING01
	IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
	BEGIN
		UPDATE LOTATTRIBUTE  
		SET EditDate = GETDATE(),
		    EditWho  = SUSER_SNAME(),
		    TrafficCop = NULL	
		FROM LOTATTRIBUTE , INSERTED (NOLOCK)
		WHERE LOTATTRIBUTE.LOT = INSERTED.LOT
		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62303   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE Failed on LOTATTRIBUTE table. (ntrlotattributeupdate)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
		END
	END

   IF UPDATE(TrafficCop)
   BEGIN
   	SELECT @n_continue = 4 
   END   
   
  /*Remove CS01 Start
   Declare @c Nvarchar(10)
   Set @c  = NULL
	Select LTRIM( rtrim(@c ))
	
	CS01 End*/

	-- to trim leading and trailing spaces of lotattributes 01, 02, 03
	-- tlting 24Apr14 trim for added lottable06-12
	IF @n_continue=1 or @n_continue=2
	BEGIN
		UPDATE LOTATTRIBUTE
		SET lottable01 = ISNULL(LTrim(RTrim(i.lottable01)), ''),
			 lottable02 = ISNULL(LTrim(RTrim(i.lottable02)), ''),
			 lottable03 = ISNULL(LTrim(RTrim(i.lottable03)), ''),
			 lottable06 = ISNULL(LTrim(RTrim(i.lottable06)), ''), -- tlting
			 lottable07 = ISNULL(LTrim(RTrim(i.lottable07)), ''),
			 lottable08 = ISNULL(LTrim(RTrim(i.lottable08)), ''),
			 lottable09 = ISNULL(LTrim(RTrim(i.lottable09)), ''),			 			 			 			 
			 lottable10 = ISNULL(LTrim(RTrim(i.lottable10)), ''),			 			 			 			 
			 lottable11 = ISNULL(LTrim(RTrim(i.lottable11)), ''),			 			 			 			 
			 lottable12 = ISNULL(LTrim(RTrim(i.lottable12)), '')
		FROM LOTATTRIBUTE la JOIN inserted i
			ON la.lot = i.lot
		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE Failed on LOTATTRIBUTE table. (ntrlotattributeupdate)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
		END
	END
	
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		execute nsp_logerror @n_err, @c_errmsg, "ntrlotattributeupdate"
		RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
		RETURN
	END
	ELSE
	BEGIN
		WHILE @@TRANCOUNT > @n_starttcnt
		BEGIN
			COMMIT TRAN
		END
		RETURN
	END
END

GO