SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: nspCheckDropId                                     */  
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
/* 24Oct2010    TLTING        Performance Tune                          */
/* 27May2014    ChewKP        Extend ChildID > 20 Char (ChewKP01)       */
/************************************************************************/  
  
CREATE PROC    [dbo].[nspCheckDropId]  
@c_dropid           NVARCHAR(18)  
,              @c_childid          NVARCHAR(20)  -- (ChewKP01)
,              @c_droploc          NVARCHAR(10)  
,              @b_Success          int        OUTPUT  
,              @n_err              int        OUTPUT  
,              @c_errmsg           NVARCHAR(250)  OUTPUT  
AS  
BEGIN  
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_debug int  
   SELECT @b_debug = 0  
   DECLARE        @n_continue int        ,  
   @n_starttcnt int        , -- Holds the current transaction count  
   @n_cnt int              , -- Holds @@ROWCOUNT after certain operations  
   @n_err2 int               -- For Additional Error Detection  
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg="",@n_err2=0  
   /* #INCLUDE <SPCDI_1.SQL> */  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF NOT EXISTS (SELECT DROPID FROM DROPID with (NOLOCK) WHERE DROPID = @c_dropid)  
      BEGIN  
         INSERT DROPID (DROPID,STATUS) VALUES (@c_dropid,"0")  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=84601   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert into table DROPID failed. (nspCheckDropId)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
         END  
      END  
   END  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF EXISTS(SELECT DROPID FROM DROPID with (NOLOCK) WHERE DROPID = @c_dropid and status = "9")  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @n_err = 84602, @c_errmsg = "NSQL84602:" + "DropID Is Already Complete!"  
      END  
   END  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF dbo.fnc_LTrim(dbo.fnc_RTrim(@c_droploc)) IS NOT NULL  
      BEGIN  
         UPDATE DROPID with (Rowlock)
         SET DROPLOC = @c_droploc  
         WHERE DROPID = @c_dropid  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=84603   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Update on table DROPID failed. (nspCheckDropId)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
         END  
      END  
   END  
   IF @n_continue = 1 or @n_continue = 2  
   BEGIN  
      IF NOT EXISTS (SELECT DROPID FROM DROPIDDETAIL with (NOLOCK) WHERE DROPID = @c_dropid  
      AND CHILDID = @c_childID  
      )  
      BEGIN  
         INSERT DROPIDDETAIL (DROPID,CHILDID) VALUES (@c_dropid,@c_childid)  
         SELECT @n_err = @@ERROR  
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=84604   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert into table DROPIDDETAIL failed. (nspCheckDropId)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "  
         END  
      END  
   END  
   /* #INCLUDE <SPCDI_2.SQL> */  
   IF @n_continue=3  -- Error Occured - Process And Return  
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
      execute nsp_logerror @n_err, @c_errmsg, "nspCheckDropId"  
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