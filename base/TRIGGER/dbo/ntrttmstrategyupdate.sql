SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrTTMStrategyUpdate                                                  		*/
/* Creation Date:  18-March-2020                                                  		*/
/* Copyright: IDS                                                                 		*/
/* Written by:  TLTING                                                            		*/
/*                                                                                		*/
/* Purpose: TTMStrategy Update                                                    		*/
/*                                                                                		*/
/* Input Parameters:                                                              		*/
/*                                                                                		*/
/* Output Parameters:                                                             		*/
/*                                                                                		*/
/* Return Status:                                                                 		*/
/*                                                                                		*/
/* Usage:                                                                         		*/
/*                                                                                		*/
/* Local Variables:                                                               		*/
/*                                                                                		*/
/* Called By: When records updated                                                		*/
/*                                                                                		*/
/* PVCS Version: 1.5                                                              		*/
/*                                                                                		*/
/* Version: 5.4                                                                   		*/
/*                                                                                		*/
/* Data Modifications:                                                            		*/
/*                                                                                		*/
/* Updates:                                                                       		*/
/* Date         Author    		Ver   Purposes                                          	*/
/* 2022-04-12   kelvinongcy	1.1	WMS-19428 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/

CREATE   TRIGGER [dbo].[ntrTTMStrategyUpdate]
ON [dbo].[TTMStrategy] 
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
	
	DECLARE	 @n_err              INT           -- Error number returned by stored procedure or this trigger
	         ,@c_errmsg           NVARCHAR(250) -- Error message returned by stored procedure or this trigger
	         ,@n_continue         INT                 
	         ,@n_starttcnt        INT           -- Holds the current transaction count
	         ,@n_cnt              INT                  
	
	SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

   IF UPDATE(ArchiveCop)
   BEGIN
   	SELECT @n_continue = 4 
   END
   
   -- TLTING01
	IF ( @n_continue = 1 or @n_continue=2 ) AND NOT UPDATE(EditDate)
	BEGIN
		UPDATE TTMStrategy WITH (ROWLOCK)
		SET EditDate = GETDATE(),
		    EditWho  = SUSER_SNAME(),
		    TrafficCop = NULL	
		FROM TTMStrategy , INSERTED
		WHERE TTMStrategy.TTMStrategyKey = INSERTED.TTMStrategyKey

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62303   -- Should Be Set To The SQL Err message but I don't know how to do so.
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE Failed on TTMStrategy table. (ntrTTMStrategyUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
		END
	END
   
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62304   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table Strategy. Batch Update not allow! (ntrTTMStrategyUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END
	
	IF UPDATE(TrafficCop)
   BEGIN
   	SELECT @n_continue = 4 
   END 
	
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrTTMStrategyUpdate"
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