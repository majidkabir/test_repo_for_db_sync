SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrMbolHeaderDelete                                         */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:   MBOL Header Delete Transaction                            */
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
/* Called By: When records delete                                       */
/*                                                                      */
/* PVCS Version: 1.13                                                   */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Purposes                                        */
/*  9-Jun-2011  KHLim01   1.1   Insert Delete log                       */
/* 14-Jul-2011  KHLim02   1.2   GetRight for Delete log                 */
/* 22-May-2012  TLTING01  1.3   Data integrity - insert dellog 4        */
/*                               status < '9'                           */
/* 12-Sep-2012  SHONG   1.9   Prevent Splitted Order MBOL Accidentally  */
/*                            Deleted by someone SOS#256080             */ 
/************************************************************************/


CREATE TRIGGER ntrMbolHeaderDelete
 ON MBOL
 FOR DELETE
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

 DECLARE @b_Success       int,       -- Populated by calls to stored procedures - was the proc successful?
 @n_err              int,       -- Error number returned by stored procedure or this trigger
 @c_errmsg           NVARCHAR(250), -- Error message returned by stored procedure or this trigger
 @n_continue         int,       -- continuation flag: 1=Continue, 2=failed but continue processsing, 3=failed do not continue processing, 4=successful but skip further processing
 @n_starttcnt        int,       -- Holds the current transaction count
 @n_cnt              int        -- Holds the number of rows affected by the DELETE statement that fired this trigger.
,@c_authority        NVARCHAR(1)  -- KHLim02
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRMBOHD1.SQL> */  

 if (select count(*) from DELETED) =
 (select count(*) from DELETED where DELETED.ArchiveCop = '9')
 BEGIN
 select @n_continue = 4
 END
       
 -- TLTING01
 IF EXISTS ( SELECT 1 FROM DELETED WHERE [STATUS] < '9' )
 BEGIN
  -- Start (KHLim01)
   IF @n_continue = 1 or @n_continue = 2
   BEGIN
      SELECT @b_success = 0         --    Start (KHLim02)
      EXECUTE nspGetRight  NULL,             -- facility  
                           NULL,             -- Storerkey  
                           NULL,             -- Sku  
                           'DataMartDELLOG', -- Configkey  
                           @b_success     OUTPUT, 
                           @c_authority   OUTPUT, 
                           @n_err         OUTPUT, 
                           @c_errmsg      OUTPUT  
      IF @b_success <> 1
      BEGIN
         SELECT @n_continue = 3
               ,@c_errmsg = 'ntrMBOLDelete' + dbo.fnc_RTrim(@c_errmsg)
      END
      ELSE 
      IF @c_authority = '1'         --    End   (KHLim02)
      BEGIN
         INSERT INTO dbo.MBOL_DELLOG ( MbolKey )
         SELECT MbolKey FROM DELETED
         WHERE [STATUS] < '9'
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Trigger On Table ORDERS Failed. (ntrMBOLDelete)' + ' ( ' + ' SQLSvr MESSAGE=' + LTrim(RTrim(@c_errmsg)) + ' ) '
         END
      END
   END
   -- End (KHLim01)
 END
             
 IF @n_continue=1 OR @n_continue=2
 BEGIN
     IF EXISTS (SELECT 1 FROM DELETED WHERE STATUS = '9')
     BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 72702
         SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                ": DELETE rejected. MBOL.Status = 'Shipped'. (ntrMbolHeaderDelete)"
     END
 END
 
 IF @n_continue=1 OR @n_continue=2
 BEGIN
     DELETE MBOLDetail
     FROM   MBOLDETAIL
           ,DELETED
     WHERE  MBOLDETAIL.MBOLKey = DELETED.MBOLKey
     
     SELECT @n_err = @@ERROR
           ,@n_cnt = @@ROWCOUNT
     
     IF @n_err<>0
     BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(CHAR(250) ,@n_err)
               ,@n_err = 72701 -- Should Be Set To The SQL Errmessage but I don't know how to do so.
         SELECT @c_errmsg = "NSQL"+CONVERT(CHAR(5) ,@n_err)+
                ": Delete Trigger On Table MBOLDETAIL Failed. (ntrMbolHeaderDelete)" 
               +" ( "+" SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) 
               +" ) "
     END
 END

 -- Added By SHONG on 12-Sep-2012, to Prevent Splitted Order MBOL Accidentally Deleted by someone
 IF @n_Continue = 1 OR @n_Continue = 2  
 BEGIN  
    IF EXISTS(SELECT 1 FROM RDT.RDTScanToTruck STT WITH (NOLOCK) 
              JOIN DELETED DEL ON STT.MbolKey = DEL.MBOLKey AND STT.Status = '9' 
              JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.MBOLKey = DEL.MBOLKey 
              JOIN ORDERDETAIL OD WITH (NOLOCK) ON OD.OrderKey = MD.OrderKey AND OD.UserDefine10 <> '' AND OD.UserDefine10 IS NOT NULL)
    BEGIN
       SELECT @n_Continue = 3  
       SELECT @n_err = 72703 
       SELECT @c_errmsg = 'NSQL'+CONVERT(Char(5), @n_err)+': RDTScanToTruck.Status = 9. DELETE rejected. (ntrMBOLDetailDelete)'  
    END 
 END 

 /* #INCLUDE <TRMBOHD2.SQL> */
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
     EXECUTE nsp_logerror @n_err, @c_errmsg, "ntrMbolHeaderDelete"
     RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
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