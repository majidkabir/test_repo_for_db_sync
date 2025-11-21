SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************************/
/* Trigger: ntrOTMLogUpdate                                                         	*/
/* Creation Date: 21-Sep-2016                                                       	*/
/* Copyright: IDS                                                                   	*/
/* Written by: MCTang                                                               	*/
/*                                                                                  	*/
/* Purpose: Trigger related Update in OTMLOG table.                                 	*/
/*                                                                                  	*/
/* Input Parameters:                                                                	*/
/*                                                                                  	*/
/* Output Parameters:                                                               	*/
/*                                                                                  	*/
/* Usage:                                                                           	*/
/*                                                                                  	*/
/* Called By:  Interface                                                            	*/
/*                                                                                  	*/
/* PVCS Version: 1.1                                                                	*/
/*                                                                                  	*/
/* Version: 5.4                                                                     	*/
/*                                                                                  	*/
/* Data Modifications:                                                              	*/
/* Date         Author    		Ver.  Purposes                                           */
/* 2022-05-17   kelvinongcy	1.1	WMS-19673 prevent bulk update or delete (kocy01)	*/
/***************************************************************************************/
  
CREATE   TRIGGER [dbo].[ntrOTMLogUpdate]  
ON  [dbo].[OTMLOG]  
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
  
   DECLARE @b_debug int  
   SELECT  @b_debug = 0  

   DECLARE @b_Success            int         
         , @n_Err                int         
         , @n_Err2               int         
         , @c_ErrMsg             char(250)   
         , @n_Continue           int  
         , @n_StartTCnt          int   
         , @n_Cnt                int        
  
   SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT  
  
   IF UPDATE(ArchiveCop)
   BEGIN
      SELECT @n_continue = 4
   END

	IF UPDATE(TrafficCop)
	BEGIN
		SELECT @n_continue = 4 
	END
 
   IF ( @n_continue = 1 or @n_continue = 2 ) AND NOT UPDATE(EditDate)
   BEGIN
      UPDATE OTMLOG	WITH (ROWLOCK)
      SET    EditDate   = GETDATE()
           , EditWho    = SUSER_SNAME()
           , Trafficcop = NULL
      FROM   OTMLOG, INSERTED
      WHERE  OTMLOG.OTMLOGKey = INSERTED.OTMLOGKey

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72804   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table OTMLOG. (ntrOTMLogUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END

   IF ( (SELECT COUNT(1) FROM INSERTED WITH (NOLOCK) ) > 100 )   --kocy01
       AND NOT EXISTS (SELECT Code FROM dbo.CODELKUP WITH (NOLOCK) WHERE Listname = 'TrgUserID' AND Short = '1' AND Code = SUSER_NAME())
   BEGIN      
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68102   -- Should Be Set To The SQL Err message but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table OTMLOG. Batch Update not allow! (ntrOTMLogUpdate)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
   END

      /* #INCLUDE <TRTHD2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrOTMLogUpdate"
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