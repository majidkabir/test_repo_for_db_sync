SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspLogAlert                                        */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 30-05-2012   ChewKP        SOS#227151 TM CC Alert (ChewKP01)         */
/************************************************************************/

CREATE PROC    [dbo].[nspLogAlert]
   @c_modulename       NVARCHAR(30),
   @c_AlertMessage     NVARCHAR(255),
   @n_Severity         int       = NULL,
   @b_success          int OUTPUT,
   @n_err              int OUTPUT,
   @c_errmsg           NVARCHAR(250)OUTPUT,
   @c_Activity	        NVARCHAR(10) = '' , -- (ChewKP01)
   @c_Storerkey	     NVARCHAR(15) = '' , -- (ChewKP01)
   @c_SKU	           NVARCHAR(20) = '' , -- (ChewKP01)
   @c_UOM	           NVARCHAR(10) = '' , -- (ChewKP01)
   @c_UOMQty	        int = 0 , -- (ChewKP01)
   @c_Qty	           int = 0 , -- (ChewKP01)
   @c_Lot	           NVARCHAR(10) = '' , -- (ChewKP01)
   @c_Loc	           NVARCHAR(10) = '' , -- (ChewKP01)
   @c_ID	              NVARCHAR(20) = '' , -- (ChewKP01)
   @c_TaskDetailKey	  NVARCHAR(10) = '' , -- (ChewKP01)
   @c_UCCNo	           NVARCHAR(20) = ''   -- (ChewKP01)
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue int,
   @n_cnt         int,
   @n_starttcnt   int,
   @c_AlertKey    NVARCHAR(18)
   
   SELECT @n_starttcnt=@@TRANCOUNT, @n_continue=1, @b_success=0, @n_err = 1, @c_errmsg=""
   
   IF @n_Severity IS NULL
   BEGIN
      SELECT @n_severity = 5
   END
   
   /* #INCLUDE <SPLAA1.SQL> */
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      SELECT @b_success=0
      EXECUTE   nspg_getkey
      "LogEvent"
      , 18
      , @c_AlertKey OUTPUT
      , @b_success OUTPUT
      , @n_err OUTPUT
      , @c_errmsg OUTPUT
      IF @b_success=0
      BEGIN
         SELECT @n_continue=3
      END
   END
   
   IF @n_continue=1 OR @n_continue=2
   BEGIN
      INSERT INTO dbo.ALERT
           (   AlertKey
              ,ModuleName
              ,AlertMessage
              ,Severity
              ,Activity
              ,Storerkey
              ,SKU
              ,UOM
              ,UOMQty
              ,Qty
              ,Lot
              ,Loc
              ,ID
              ,TaskDetailKey
              ,UCCNo              )
      VALUES (  @c_AlertKey
              , @c_modulename
              , @c_AlertMessage
              , @n_Severity
              , @c_Activity	      
              , @c_Storerkey	      
              , @c_SKU	            
              , @c_UOM	            
              , @c_UOMQty	         
              , @c_Qty	            
              , @c_Lot	            
              , @c_Loc	            
              , @c_ID	            
              , @c_TaskDetailKey	
              , @c_UCCNo	       )
      
      
      SELECT @n_err = @@ERROR
      
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 76351   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Itrn. (nspLogAlert)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
      END
   END
   
   /* #INCLUDE <SPLAA2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      -- (ChewKP01)
      DECLARE @n_IsRDT INT
      EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

      IF @n_IsRDT = 1 
      BEGIN
          -- RDT cannot handle rollback (blank XML will generate). So we are not going to issue a rollback here
          -- Instead we commit and raise an error back to parent, let the parent decide

          -- Commit until the level we begin with
          WHILE @@TRANCOUNT > @n_starttcnt
             COMMIT TRAN

          -- Raise error with severity = 10, instead of the default severity 16.
          -- RDT cannot handle error with severity > 10, which stop the processing after executed this trigger
          RAISERROR (@n_err, 10, 1) WITH SETERROR

          -- The RAISERROR has to be last line, to ensure @@ERROR is not getting overwritten
      END
      ELSE
      BEGIN
            SELECT @b_success = 0
            IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
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
            execute nsp_logerror @n_err, @c_errmsg, "nspLogAlert"
            RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
            RETURN
      END
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