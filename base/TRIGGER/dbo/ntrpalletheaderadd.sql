SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Trigger: ntrPalletHeaderAdd                                             */  
/* Creation Date:                                                          */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose:                                                                */  
/*                                                                         */  
/* Input Parameters: NONE                                                  */  
/*                                                                         */  
/* Output Parameters: NONE                                                 */  
/*                                                                         */  
/* Return Status: NONE                                                     */  
/*                                                                         */  
/* Usage:                                                                  */  
/*                                                                         */  
/* Local Variables:                                                        */  
/*                                                                         */  
/* Called By: When records added                                           */  
/*                                                                         */  
/* PVCS Version: 1.2                                                       */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author    Ver.  Purposes                                   */  
/* 17-Mar-2009  TLTING    1.0   Change user_name() to SUSER_SNAME()        */
/* 31-Mar-2020  kocy      1.1   Skip when data move from Archive (kocy01)  */
/* 13-Jan-2021  Shong     1.2   Comment the update for AddWho... Schema    */
/*                              Default already have this. Redundancy      */
/***************************************************************************/  
CREATE TRIGGER [dbo].[ntrPalletHeaderAdd]
 ON  [dbo].[PALLET]
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
      /* #INCLUDE <TRPALHA1.SQL> */     
      
 -- kocy01(s)
 IF @n_continue=1 or @n_continue=2  
 BEGIN
    IF EXISTS (SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
    BEGIN
       SELECT @n_continue = 4
    END
 END
 --kocy01(e)
 
 IF @n_continue=1 OR @n_continue=2
 BEGIN
     IF EXISTS ( SELECT * FROM  INSERTED WHERE STATUS = '9'
        )
     BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 67302
         SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': Bad PALLET.Status. (nspPalletHeaderAdd)'
     END
 END
 
 --IF @n_continue=1 OR @n_continue=2
 --BEGIN
 --    UPDATE PALLET
 --    SET    TrafficCop = NULL
 --          ,AddDate = GETDATE()
 --          ,AddWho = SUSER_SNAME()
 --          ,EditDate = GETDATE()
 --          ,EditWho = SUSER_SNAME()
 --    FROM   PALLET
 --          ,INSERTED
 --    WHERE  PALLET.PalletKey = INSERTED.PalletKey
     
 --    SELECT @n_err = @@ERROR
 --          ,@n_cnt = @@ROWCOUNT
     
 --    IF @n_err<>0
 --    BEGIN
 --        SELECT @n_continue = 3
 --        SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
 --              ,@n_err = 67301 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
 --        SELECT @c_errmsg = 'NSQL'+CONVERT(CHAR(5) ,@n_err)+': Insert Failed On Table PALLET. (nspPalletHeaderAdd)'+
 --               ' ( '+' SQLSvr MESSAGE='+ISNULL(TRIM(@c_errmsg),'')+' ) '
 --    END
 --END
      /* #INCLUDE <TRPALHA2.SQL> */
 IF @n_continue=3 -- Error Occured - Process And Return
 BEGIN
     IF @@TRANCOUNT=1
        AND @@TRANCOUNT>=@n_starttcnt
     BEGIN
         ROLLBACK TRAN
     END
     ELSE
     BEGIN
         WHILE @@TRANCOUNT>@n_starttcnt
         BEGIN
             COMMIT TRAN
         END
     END
     EXECUTE nsp_logerror @n_err,
          @c_errmsg,
          'ntrPalletHeaderAdd'
     
     RAISERROR (@c_errmsg ,16 ,1) WITH SETERROR -- SQL2012
     RETURN
 END
 ELSE
 BEGIN
     WHILE @@TRANCOUNT>@n_starttcnt
     BEGIN
         COMMIT TRAN
     END
     RETURN
 END
 END


GO