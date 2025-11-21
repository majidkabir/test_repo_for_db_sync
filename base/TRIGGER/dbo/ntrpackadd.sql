SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrPackAdd                                                  */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By: When records Added                                        */
/*                                                                      */
/* PVCS Version: 1.1                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 03-Mar-2011  SPChin   1.0  SOS#207316 - Allow Pack update            */
/* 29-Mar-2012  NJOW01   1.1  SOS#244886 - Calculate cube by multi-uom  */
/* 21-Jul-2017  TLTING   1.7  SET Option                                */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrPackAdd]
 ON  [dbo].[PACK]
 FOR INSERT
 AS
 BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

 DECLARE
 @b_Success            int       -- Populated by calls to stored procedures - was the proc successful?
 ,         @n_err                int       -- Error number returned by stored procedure or this trigger
 ,         @n_err2 int              -- For Additional Error Detection
 ,         @c_errmsg             NVARCHAR(250) -- Error message returned by stored procedure or this trigger
 ,         @n_continue int
 ,         @n_starttcnt int                -- Holds the current transaction count
 ,         @c_preprocess NVARCHAR(250)         -- preprocess
 ,         @c_pstprocess NVARCHAR(250)         -- post process
 ,         @n_cnt int
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

 /* SOS#207316 Start
 IF UPDATE(TrafficCop)
 BEGIN
 SELECT @n_continue = 4
 END
 IF UPDATE(ArchiveCop)
 BEGIN
 SELECT @n_continue = 4
 END
 SOS#207316 End */

 --SOS#207316 Start
 IF @n_continue = 1 OR @n_continue = 2
  BEGIN
    IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
    BEGIN
       SELECT @n_continue = 4
    END
  END
 --SOS#207316 End

      /* #INCLUDE <TRPA_1.SQL> */
 IF @n_continue = 1 or @n_continue = 2
 BEGIN
 UPDATE PACK SET
 PACK.CubeUOM1 = dbo.fnc_CalculateCube(INSERTED.LengthUOM1, INSERTED.WidthUOM1, INSERTED.HeightUOM1,'','',''),  --NJOW01
 PACK.CubeUOM2 = dbo.fnc_CalculateCube(INSERTED.LengthUOM2, INSERTED.WidthUOM2, INSERTED.HeightUOM2,'','',''),  --NJOW01 
 PACK.CubeUOM3 = dbo.fnc_CalculateCube(INSERTED.LengthUOM3, INSERTED.WidthUOM3, INSERTED.HeightUOM3,'','',''),  --NJOW01 
 PACK.CubeUOM4 = dbo.fnc_CalculateCube(INSERTED.LengthUOM4, INSERTED.WidthUOM4, INSERTED.HeightUOM4,'','',''),  --NJOW01 
 TrafficCop = NULL
 FROM PACK, INSERTED
 WHERE PACK.PACKKEY = INSERTED.PACKKEY
 END
 SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
 IF @n_err <> 0
 BEGIN
 SELECT @n_continue = 3
 SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=85700   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table PACK. (ntrPackAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
 END
      /* #INCLUDE <TRPA_2.SQL> */
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
 execute nsp_logerror @n_err, @c_errmsg, "ntrPackAdd"
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