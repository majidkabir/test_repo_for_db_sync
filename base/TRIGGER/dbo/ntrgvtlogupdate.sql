SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: ntrGVTLogUpdate                                             */  
/* Creation Date: 21-Sep-2016                                           */  
/* Copyright: IDS                                                       */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose: Trigger related Update in GVTLog table.                     */  
/*                                                                      */  
/* Input Parameters:                                                    */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:  Interface                                                */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrGVTLogUpdate]  
ON  [dbo].[GVTLog]  
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
      UPDATE GVTLog
      SET    EditDate   = GETDATE()
           , EditWho    = SUSER_SNAME()
           , Trafficcop = NULL
      FROM   GVTLog, INSERTED
      WHERE  GVTLog.GVTLogKey = INSERTED.GVTLogKey

      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72804   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update Failed On Table GVTLog. (ntrGVTLogUpdate)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
END

GO