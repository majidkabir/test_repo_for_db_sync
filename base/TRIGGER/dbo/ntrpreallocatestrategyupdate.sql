SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrPreAllocateStrategyUpdate                                           		*/
/* Creation Date:  18-March-2020                                                   		*/
/* Copyright: IDS                                                                  		*/
/* Written by:  TLTING                                                             		*/
/*                                                                                 		*/
/* Purpose: PreAllocateStrategy Update                                             		*/
/*                                                                                 		*/
/* Input Parameters:                                                               		*/
/*                                                                                 		*/
/* Output Parameters:                                                              		*/
/*                                                                                 		*/
/* Return Status:                                                                  		*/
/*                                                                                 		*/
/* Usage:                                                                          		*/
/*                                                                                 		*/
/* Local Variables:                                                                		*/
/*                                                                                 		*/
/* Called By: When records updated                                                 		*/
/*                                                                                 		*/
/* PVCS Version: 1.5                                                               		*/
/*                                                                                 		*/
/* Version: 5.4                                                                    		*/
/*                                                                                 		*/
/* Data Modifications:                                                             		*/
/*                                                                                 		*/
/* Updates:                                                                        		*/
/* Date         Author   		Ver  	Purposes                                           */
/* 2022-04-12   kelvinongcy	1.1	WMS-19428 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/

CREATE   TRIGGER [dbo].[ntrPreAllocateStrategyUpdate]
ON [dbo].[PreAllocateStrategy] 
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
		UPDATE PreAllocateStrategy WITH (ROWLOCK)
		SET EditDate = GETDATE(),
		    EditWho  = SUSER_SNAME(),
		    TrafficCop = NULL	
		FROM PreAllocateStrategy , INSERTED
		WHERE PreAllocateStrategy.PreAllocateStrategyKey = INSERTED.PreAllocateStrategyKey

		SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
		IF @n_err <> 0
		BEGIN
			SELECT @n_continue = 3
			SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=62303   -- Should Be Set To The SQL Err message but I don't know how to do so.
			SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": UPDATE Failed on PreAllocateStrategy table. (ntrPreAllocateStrategyUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTrim(RTrim(@c_errmsg)) + " ) "
		END
	END

   IF UPDATE(TrafficCop)
   BEGIN
   	SELECT @n_continue = 4 
   END   
    
   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=67405   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(CHAR(5),@n_err)+": Update Failed On Table PreAllocateStrategy. Batch Update not allow! (ntrPreAllocateStrategyUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END
	
	IF @n_continue=3  -- Error Occured - Process And Return
	BEGIN
		IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
		BEGIN
			ROLLBACK TRAN
		END
		execute nsp_logerror @n_err, @c_errmsg, "ntrPreAllocateStrategyUpdate"
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