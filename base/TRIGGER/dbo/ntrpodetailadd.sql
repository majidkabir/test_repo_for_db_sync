SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: ntrPODetailAdd                                      */
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
/* Date       Rev  Author    Purposes                                   */
/* 2002-08-05 1.0  admin     Initial version                            */
/* 2003-09-16 1.1  wtshong   SOS# 14983 PO Header did not update        */
/*                           Supplier code                              */
/* 2003-09-16 1.2  wtshong   Bugs fixing                                */
/* 2006-06-17 1.3  ung       SOS53688 Retrieve archived PO              */
/*                           Added ArchiveCop                           */
/* 2009-06-16 1.4  Rick Liew SOS96737 - Remove hardcoding for C4LGMY		*/
/* 2014-08-26 1.5  YTWan     SOS#319232 - TH-PO not allow to add        */
/*                           Invactive-SKU. (Wan01)                     */
/* 2017-07-27 1.6  TLTING   1.1  SET Option, missing nolock             */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrPODetailAdd]
ON  [dbo].[PODETAIL]
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
,       @c_storerkey NVARCHAR(15)
,       @c_authority   NVARCHAR(1)

DECLARE @c_primaryPDKey NVARCHAR(15), @c_POKey NVARCHAR(20), @c_Poline NVARCHAR(20),
      @n_rowcount int, @c_TransmitLogKey NVARCHAR(10)
      ,  @c_PODisallowInactiveSku   NVARCHAR(10)      --(Wan01)
      ,  @c_InactiveSku             NVARCHAR(20)      --(Wan01)

SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT

-- SOS53688 Added ArchiveCop
IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   SELECT @n_continue = 4

   /* #INCLUDE <TRPODA1.SQL> */
/* 12.9.99 WALLY - copy externpokey of header */
/*
IF @n_continue = 1 or @n_continue=2
BEGIN
DECLARE @n_lineno int
SELECT @n_lineno = MAX(CONVERT(int,PODetail.externlineno)) + 1
FROM PODetail, INSERTED
WHERE PODetail.pokey = INSERTED.pokey
UPDATE PODetail
SET PODetail.externpokey = PO.externpokey, PODetail.externlineno = @n_lineno
FROM PO, PODETAIL, INSERTED
WHERE PO.pokey = INSERTED.pokey
AND PODETAIL.pokey = PO.pokey
AND PODETAIL.polinenumber = INSERTED.polinenumber
SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
IF @n_err <> 0
BEGIN
SELECT @n_continue = 3
SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64603   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert failed on table PO. (ntrPODetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
END
END
*/

--(Wan01) - START
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT TOP 1 @c_Storerkey = Storerkey
   FROM   INSERTED

   SET @c_PODisAllowInactiveSku = 0
   SET @b_success = 0
   Execute nspGetRight null   -- facility
           ,  @c_StorerKey    -- Storerkey
           ,  null            -- Sku
           ,  'PODisallowInactiveSku'    -- Configkey
           ,  @b_success               OUTPUT
           ,  @c_PODisAllowInactiveSku OUTPUT
           ,  @n_err                   OUTPUT
           ,  @c_errmsg                OUTPUT
   IF @b_success <> 1
   BEGIN
      SET @n_continue = 3
      SET @c_errmsg = 'ntrPODetailAdd ' + RTRIM(@c_errmsg)
   END
   ELSE IF @c_PODisAllowInactiveSku = '1'
   BEGIN
      SET @c_InactiveSku = ''
      SELECT TOP 1 @c_InactiveSku = RTRIM(SKU.Sku)
      FROM INSERTED 
      JOIN SKU WITH (NOLOCK) ON (INSERTED.Storerkey = SKU.Storerkey) 
                             AND(INSERTED.Sku = SKU.Sku)
      WHERE SKU.SkuStatus = 'Inactive'

      IF @c_InactiveSku <> '' 
      BEGIN
         SET @n_continue = 3
         SET @c_errmsg = 'ntrPODetailAdd. Disallow Inactive Sku: ' + RTRIM(@c_InactiveSku) + 'add to PO.'
      END
   END
END  
--(Wan01) - END

-- Added for IDSV5 by June 21.Jun.02, (extract from IDSSG) *** Start
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @c_Storerkey = Storerkey
   FROM   Inserted

   SELECT @b_success = 0
   Execute nspGetRight null,  -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'EXTPOKEYUPD',   -- Configkey
             @b_success    output,
             @c_authority  output,
             @n_err        output,
             @c_errmsg     output
   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrPODetailAdd' + dbo.fnc_RTrim(@c_errmsg)
   END
   ELSE IF @c_authority = '1'
   BEGIN
    /* Added by YokeBeen (4-October-2001) - Ticket # 1876
      To update the ExternPOKey in PODETAIL when the new PO is being created
      - START */
    UPDATE PODetail WITH (ROWLOCK)
       SET PODetail.EXTERNPOKEY = PO.EXTERNPOKEY
    FROM PO (NOLOCK), PODETAIL, INSERTED
    WHERE PO.pokey = INSERTED.pokey
      AND PODETAIL.pokey = INSERTED.pokey
      AND PODETAIL.polinenumber = INSERTED.polinenumber
    /* - END */
   END
END -- Added for IDSV5 by June 21.Jun.02, (extract from IDSSG) *** End

-- Added by Ricky for carrefour CrossDock Impl.
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @c_Storerkey = Storerkey
   FROM   Inserted

   SELECT @b_success = 0, @c_authority = 0

   Execute nspGetRight null,  -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'XDLottable02Link',   -- Configkey
             @b_success    output,
             @c_authority  output,
             @n_err        output,
             @c_errmsg     output

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrPODetailAdd' + dbo.fnc_RTrim(@c_errmsg)
   END
   ELSE IF @c_authority = '1'
   BEGIN
    UPDATE PODetail
       SET PODetail.LOTTABLE02 = PO.EXTERNPOKEY,
           PODetail.Trafficcop = NULL
    FROM PO (NOLOCK), PODETAIL, INSERTED
    WHERE PO.pokey = INSERTED.pokey
      AND PODETAIL.pokey = INSERTED.pokey
      AND PODETAIL.polinenumber = INSERTED.polinenumber
      AND PO.POTYPE IN ('5', '8')
   END
END

/* 2 Dec 2004 YTWan C4- Populate Externpokey to Lottable03 - Start */
IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @b_success = 0, @c_authority = 0

   Execute nspGetRight null,  -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'XDLottable03Link',   -- Configkey
             @b_success    output,
             @c_authority  output,
             @n_err        output,
             @c_errmsg     output

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrPODetailAdd' + dbo.fnc_RTrim(@c_errmsg)
   END
   ELSE IF @c_authority = '1'
   BEGIN
	 -- Start : SOS96737
	 /*      
    UPDATE PODetail
       SET PODetail.LOTTABLE03 = PO.EXTERNPOKEY,
           PODetail.Trafficcop = NULL
    FROM PO (NOLOCK), PODETAIL, INSERTED
    WHERE PO.pokey = INSERTED.pokey
      AND PODETAIL.pokey = INSERTED.pokey
      AND PODETAIL.polinenumber = INSERTED.polinenumber
      AND PO.POTYPE IN ('5', '6', '8', '8A')
    */
    UPDATE PODetail
       SET PODetail.LOTTABLE03 = PO.EXTERNPOKEY,
           PODetail.Trafficcop = NULL
    FROM PO (NOLOCK), PODETAIL, CODELKUP (NOLOCK), INSERTED
    WHERE PO.pokey = INSERTED.pokey
      AND PODETAIL.pokey = INSERTED.pokey
      AND PODETAIL.polinenumber = INSERTED.polinenumber
		AND PO.POTYPE = CODELKUP.CODE
	   AND CODELKUP.LISTNAME = 'Lot03Link'
	 -- End : SOS96737    
   END
END
/* 2 Dec 2004 YTWan C4- Populate Externpokey to Lottable03 - End */

IF @n_continue=1 or @n_continue=2
BEGIN
   SELECT @c_Storerkey = Storerkey
   FROM   Inserted

   SELECT @b_success = 0, @c_authority = 0

   Execute nspGetRight null,  -- facility
             @c_StorerKey,    -- Storerkey
             null,            -- Sku
             'XDOCKSKUEXISTINWHALERT',   -- Configkey
             @b_success    output,
             @c_authority  output,
             @n_err        output,
             @c_errmsg     output

   IF @b_success <> 1
   BEGIN
      SELECT @n_continue = 3, @c_errmsg = 'ntrPODetailAdd' + dbo.fnc_RTrim(@c_errmsg)
   END
   ELSE IF @c_authority = '1'
   BEGIN
      IF (SELECT count(*) FROM INSERTED
            JOIN SKUXLOC (Nolock)
                  ON INSERTED.STORERKEY = SKUXLOC.STORERKEY
                 AND INSERTED.SKU = SKUXLOC.SKU
            JOIN LOC WITH (NOLOCK)
                  ON SKUXLOC.LOC = LOC.LOC
           WHERE SKUXLOC.STORERKEY = @c_StorerKey
             AND LOC.Locationflag = 'NONE'
             AND SKUXLOC.QTY - SKUXLOC.QtyAllocated - SKUXLOC.QtyPicked > 0) > 0
      BEGIN
         -- Create the log for the Alert (VB) to pick up
         SELECT @c_primaryPDKey = ''
         WHILE (1=1)
         BEGIN
            SET ROWCOUNT 1

            SELECT @c_primaryPDKey = dbo.fnc_RTrim(INSERTED.POKey)+dbo.fnc_RTrim(INSERTED.POLineNumber),
                   @c_POKey = dbo.fnc_RTrim(INSERTED.POKey),
                   @c_Poline = dbo.fnc_RTrim(INSERTED.POLineNumber)
              FROM INSERTED
              JOIN SKUXLOC (Nolock)
                   ON INSERTED.STORERKEY = SKUXLOC.STORERKEY
                   AND INSERTED.SKU = SKUXLOC.SKU
              JOIN LOC WITH (NOLOCK)
                   ON SKUXLOC.LOC = LOC.LOC
             WHERE SKUXLOC.STORERKEY = @c_StorerKey
               AND LOC.Locationflag = 'NONE'
               AND SKUXLOC.QTY - SKUXLOC.QtyAllocated - SKUXLOC.QtyPicked > 0
               AND dbo.fnc_RTrim(INSERTED.POKey)+dbo.fnc_RTrim(INSERTED.POLineNumber) > @c_primaryPDKey
            ORDER BY POKey, POLineNumber

            SELECT @n_rowcount = @@ROWCOUNT

            SET ROWCOUNT 0

            IF @n_rowcount = 0 Break

            IF NOT EXISTS (SELECT 1 FROM TRANSMITLOG2 (NOLOCK)
                            WHERE TableName = 'SOHALERT'
                              AND key1 = @c_POKey
                              AND Key2 = @c_Poline )
            BEGIN
               SELECT @c_TransmitLogKey=''
               SELECT @b_success=1

               EXECUTE nspg_getkey
                  'TransmitLogKey2'
                  , 10
                  , @c_TransmitLogKey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF NOT @b_success=1
               BEGIN
                  SELECT @n_continue=3
               END

               IF ( @n_continue = 1 or @n_continue = 2 )
               BEGIN -- @n_continue inner loop
                  INSERT TransmitLog2 (TransmitLogKey,    tablename,  key1,  key2, key3)
                  VALUES (@c_TransmitLogKey, 'SOHALERT', @c_POKey, @c_Poline, @c_Storerkey )

                  SELECT @n_err= @@Error
                  IF NOT @n_err=0
                  BEGIN
                     SELECT @n_continue=3
                     Select @c_errmsg= CONVERT(char(250), @n_err), @n_err=22806
                     Select @c_errmsg= "NSQL"+CONVERT(char(5), @n_err)+":Insert failed on TransmitLog2. (ntrPodetailAdd)"+"("+"SQLSvr MESSAGE="+dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg))+")"
                  END
               END
            END
         END -- End While Loop
      END
   END
END

IF @n_continue = 1 or @n_continue=2
BEGIN
   DECLARE @n_insertedcount int
   SELECT @n_insertedcount = (select count(*) FROM inserted)
   IF @n_insertedcount = 1
   BEGIN
      UPDATE PO
      SET  PO.OpenQty = PO.OpenQty + (INSERTED.QtyOrdered - INSERTED.QtyReceived)
      FROM PO, INSERTED
      WHERE PO.POKey = INSERTED.POKey
   END
   ELSE
   BEGIN
      UPDATE PO SET PO.OpenQty
      = (Select Sum(PODetail.QtyOrdered - PODetail.QtyReceived)
      From PODETAIL WITH (NOLOCK)
      Where PODetail.PoKey = PO.PoKey)
      FROM PO,INSERTED
      WHERE PO.POkey IN (Select Distinct POkey From Inserted)
      AND PO.POkey = Inserted.POkey
   END
   SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
   IF @n_err <> 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64603   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Insert failed on table PO. (ntrPODetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
   ELSE IF @n_cnt = 0
   BEGIN
      SELECT @n_continue = 3
      SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=64604   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
      SELECT @c_errmsg="NSQL"+CONVERT(char(5),@n_err)+": Zero rows affected updating table PO. (ntrPODetailAdd)" + " ( " + " SQLSvr MESSAGE=" + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + " ) "
   END
END  

/* #INCLUDE <TRPODA2.SQL> */
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
   execute nsp_logerror @n_err, @c_errmsg, "ntrPODetailAdd"
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