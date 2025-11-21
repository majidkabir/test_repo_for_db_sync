SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ntrPOHeaderAdd                                      */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: normal receipt                                              */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2002-08-05 1.0  admin    Initial version                             */
/* 2003-09-16 1.1  wtshong  SOS# 14983 PO Header did not update         */
/*                          Supplier code                               */
/* 2003-09-16 1.2  wtshong  Bugs fixing                                 */
/* 2006-06-17 1.3  ung      SOS53688 Retrieve archived PO               */
/*                          Added ArchiveCop                            */
/* 2017-07-27 1.4  TLTING   SET Option                                  */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrPOHeaderAdd]
ON  [dbo].[PO]
FOR INSERT
AS
BEGIN
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

SET CONCAT_NULL_YIELDS_NULL OFF 
SET NOCOUNT ON 
SET QUOTED_IDENTIFIER OFF 
SET ANSI_NULLS OFF


 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT
      /* #INCLUDE <TRPOHA1.SQL> */     
      
-- SOS53688 Added ArchiveCop
IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   SELECT @n_continue = 4

IF @n_continue=1 or @n_continue=2
BEGIN
   DECLARE @cPOKey NVARCHAR(10)
    
   SELECT @cPOKey = Space(10)
    
   If EXISTS(SELECT 1 FROM INSERTED 
             JOIN STORER (NOLOCK) ON (STORER.Storerkey = INSERTED.SellerName AND STORER.Type = '5')
             WHERE SellerAddress1 = '')
   BEGIN
         Update PO
            Set SellerAddress1 = STORER.Address1,         
                SellerAddress2 = STORER.Address2,
                SellerAddress3 = STORER.Address3,
                SellerAddress4 = STORER.Address4,
                SellerCity = STORER.City,
                SellerState= STORER.State,
                SellerZip = STORER.Zip,
                SellerPhone = STORER.Phone1
         FROM PO (NOLOCK)
         JOIN INSERTED ON (PO.POKey = INSERTED.POKey)
         JOIN STORER (NOLOCK) ON (STORER.StorerKey = PO.SellerName AND STORER.Type = '5')
         WHERE PO.SellerAddress1 = ''
         SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64301   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
            SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert Failed On Table PO. (nspPOHeaderAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
         END
      END
   END
END 
      /* #INCLUDE <TRPOHA2.SQL> */
IF @n_continue=3  -- Error Occured - Process And Return
BEGIN
   IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_starttcnt
   BEGIN
     ROLLBACK TRAN
   END
   Else
   BEGIN
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
        COMMIT TRAN
      END
   END
   Execute nsp_logerror @n_err, @c_errmsg, "ntrPOHeaderAdd"
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

GO