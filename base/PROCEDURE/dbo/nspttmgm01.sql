SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: nspTTMGM01                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 22-Sep-2010  KHLIM         disable settings and fix bug (KHLim01)    */
/* 22-Dec-2010  James         Remove UserKeyOverride opt (james01)      */
/************************************************************************/

CREATE PROC    [dbo].[nspTTMGM01]
@c_userid           NVARCHAR(18)
,              @c_areakey01        NVARCHAR(10)
,              @c_areakey02        NVARCHAR(10)
,              @c_areakey03        NVARCHAR(10)
,              @c_areakey04        NVARCHAR(10)
,              @c_areakey05        NVARCHAR(10)
,              @c_lastloc          NVARCHAR(10)
AS
BEGIN

-- disable all settings for sub SP (KHLim01)

   DECLARE @b_debug int
   SELECT @b_debug = 0
   DECLARE        @n_continue int        ,
   @n_starttcnt int        , -- Holds the current transaction count
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations
   @n_err2 int             , -- For Additional Error Detection
   @b_Success int          ,
   @n_err int              ,
   @c_errmsg NVARCHAR(250)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0
   DECLARE @c_executestmt NVARCHAR(255)
   /* #INCLUDE <SPTMGM01_1.SQL> */
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      DECLARE CURSOR_GMTASKCANDIDATES
      CURSOR FAST_FORWARD READ_ONLY FOR -- (KHLim01)
      SELECT TaskDetailKey
      FROM TaskDetail
      WHERE TaskDetail.Status = "0"
--      AND TaskDetail.UserKeyOverride = @c_userid (james01)
      AND TaskDetail.TaskType = "GM"
      ORDER BY Priority, SourcePriority,TaskDetailKey
      SELECT @n_err = @@ERROR
      IF @n_err = 16915 OR @n_err = 16905 -- if CURSOR_GMTASKCANDIDATES already exists   (KHLim01)
      BEGIN
         CLOSE CURSOR_GMTASKCANDIDATES  
         DEALLOCATE CURSOR_GMTASKCANDIDATES
         SELECT @n_err = @@ERROR
      END
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=79001   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Execute Of Move Tasks Pick Code Failed. (nspTTMGM01)" + " ( " + " SQLSvr MESSAGE=" + LTRIM(RTRIM(@c_errmsg)) + " ) "
      END
   END
   /* #INCLUDE <SPTMGM01_2.SQL> */
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
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
         execute nsp_logerror @n_err, @c_errmsg, 'nspTTMGM02'  
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