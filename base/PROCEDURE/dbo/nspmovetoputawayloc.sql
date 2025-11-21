SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: nspMovetoPutawayLoc                                         */
/* Creation Date: 06-Aug-2004                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Move to Putaway Location                                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.2                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 13-Aug-2004  Wally         Avoid unnecessary looping thru the whole  */
/*                            receipt                                   */
/* 22-Aug-2005  MaryVong      SOS39602 Modified to allow re-submit of   */
/*                            Putaway task by using cursor              */
/* 21-May-2014  Audrey        SOS311698 - turn off uomconv	 (ang01)    */
/* 30-JUN-2014  CSCHONG       SQL2012 Fixing Bugs (CS01)                */ 
/* 16-JUL-2015  CSCHONG       SOS347956 (CS02)                          */
/*************************************************************************/

CREATE PROC    [dbo].[nspMovetoPutawayLoc]
               @c_receiptkey   NVARCHAR(10)
,              @b_Success      int        OUTPUT
,              @n_err          int        OUTPUT
,              @c_errmsg       NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE   @n_continue int      ,
      @n_starttcnt   int       , -- Holds the current transaction count
      @c_preprocess   NVARCHAR(250) , -- preprocess
      @c_pstprocess   NVARCHAR(250) , -- post process
      @n_err2         int,        -- For Additional Error Detection
      @c_receiptLineno NVARCHAR(5),
      @c_storerkey  NVARCHAR(15),
      @c_sku      NVARCHAR(20),
      @c_uom      NVARCHAR(10),
      @c_packkey     NVARCHAR(10),
      @c_lot      NVARCHAR(10),
      @c_fromloc     NVARCHAR(10),
      @c_toid      NVARCHAR(18),
      @c_putawayloc  NVARCHAR(10),
      @n_recvqty   int,
      @n_itrncnt     int,
      @c_sourcekey  NVARCHAR(15)

   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @b_success=0,@n_err=0,@c_errmsg='',@n_err2=0
   /* #INCLUDE <SPIAM1.SQL> */

 -- SOS39602
 -- If no MOVE performed before
 IF NOT EXISTS (SELECT 1 FROM ITRN (NOLOCK) WHERE SUBSTRING(Sourcekey,1,10) = dbo.fnc_RTrim(@c_receiptkey)
     AND SourceType = 'nspMovetoPutawayLoc' AND TranType = 'MV' )
 BEGIN
  DECLARE MV01_CUR CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT RD.ReceiptLineNumber, RD.Storerkey, RD.Sku, RD.UOM, RD.PackKey,
          RD.ToLoc, RD.ToId, RD.PutawayLoc, RD.QtyReceived, I.Lot
       FROM  ReceiptDetail RD(NOLOCK)
       JOIN  ITRN I (NOLOCK) ON (I.SourceKey = dbo.fnc_RTrim(RD.ReceiptKey) + RD.ReceiptLineNumber)
       WHERE RD.ReceiptKey = @c_receiptkey
   AND RD.FinalizeFlag = 'Y'
   AND RD.PutawayLoc > ''
       AND   I.SourceType = 'ntrReceiptDetailUpdate'
       AND   I.TranType   = 'DP'
   ORDER BY RD.ReceiptLineNumber

  OPEN MV01_CUR

  FETCH NEXT FROM MV01_CUR INTO @c_receiptlineno, @c_storerkey, @c_sku, @c_uom, @c_packkey,
            @c_fromloc, @c_toid, @c_putawayloc, @n_recvqty, @c_lot

  WHILE @@FETCH_STATUS <> -1
  BEGIN
   SELECT @c_sourcekey = dbo.fnc_RTrim(@c_receiptkey) + @c_receiptlineno

   EXEC nspItrnAddMove
      NULL ,
    @c_storerkey ,
    @c_sku,
    @c_lot,
    @c_fromloc,
    @c_toid,
    @c_putawayloc,
    @c_toid,
    '0',
    ' ',
    ' ',
    ' ',
    NULL,
    NULL,
    ' ',       --Lottable 06 (CS02)
    ' ',       --Lottable 07 (CS02)
    ' ',       --Lottable 08 (CS02)
    ' ',       --Lottable 09 (CS02)
    ' ',       --Lottable 10 (CS02)
    ' ',       --Lottable 11 (CS02)
    ' ',       --Lottable 12 (CS02)
    NULL,      --Lottable 13 (CS02)
    NULL,      --Lottable 14 (CS02)
    NULL,      --Lottable 15 (CS02) 
    0 ,
    0 ,
    @n_recvqty,
    0 ,
    0 ,
    0 ,
    0 ,
    0 ,
    0 ,
    @c_sourcekey,
    'nspMovetoPutawayLoc',
    @c_packkey,
    @c_uom,
    0 , --ang01
    NULL,
    '',
     @b_success,
    @n_err,
    @c_errmsg

       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Movement Fail. (''nspMovetoPutawayLoc'')' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
       END

   FETCH NEXT FROM MV01_CUR INTO @c_receiptLineno, @c_storerkey, @c_sku, @c_uom, @c_packkey,
            @c_fromloc, @c_toid, @c_putawayloc, @n_recvqty, @c_lot
  END -- @@FETCH_STATUS <> -1

  CLOSE MV01_CUR
  DEALLOCATE MV01_CUR
 END -- No MOVE performed before

 ELSE
 BEGIN
  -- Only move those with ITRN.Qty = NULL
  SELECT SUBSTRING(SourceKey,1,10) as ReceiptKey, RIGHT(dbo.fnc_RTrim(SourceKey),5) as ReceiptLineNumber, Lot, Qty
  INTO  #TempITRN
  FROM  ITRN (NOLOCK)
  WHERE SUBSTRING(SourceKey,1,10) = dbo.fnc_RTrim(@c_receiptkey)
  AND  SourceType = 'nspMovetoPutawayLoc'
  AND TranType = 'MV'

  DECLARE MV02_CUR CURSOR FAST_FORWARD READ_ONLY FOR
       SELECT RD.ReceiptLineNumber, RD.Storerkey, RD.Sku, RD.UOM, RD.PackKey,
          RD.ToLoc, RD.ToId, RD.PutawayLoc, RD.QtyReceived, I.Lot
       FROM  ReceiptDetail RD (NOLOCK)
   LEFT OUTER JOIN #TempITRN I (NOLOCK) ON (RD.ReceiptKey = I.ReceiptKey AND RD.ReceiptLineNumber = I.ReceiptLineNumber)
   WHERE RD.ReceiptKey = @c_receiptkey
   AND I.Qty = NULL
   ORDER BY RD.ReceiptLineNumber

  OPEN MV02_CUR

  FETCH NEXT FROM MV02_CUR INTO @c_receiptlineno, @c_storerkey, @c_sku, @c_uom, @c_packkey,
            @c_fromloc, @c_toid, @c_putawayloc, @n_recvqty, @c_lot

  WHILE @@FETCH_STATUS <> -1
  BEGIN
   SELECT @c_sourcekey = dbo.fnc_RTrim(@c_receiptkey) + @c_receiptlineno

   EXEC nspItrnAddMove
      NULL ,
    @c_storerkey ,
    @c_sku,
    @c_lot,
    @c_fromloc,
    @c_toid,
    @c_putawayloc,
    @c_toid,
    '0',
    ' ',
    ' ',
    ' ',
    NULL,
    NULL,
    ' ',       --Lottable 06 (CS02)
    ' ',       --Lottable 07 (CS02)
    ' ',       --Lottable 08 (CS02)
    ' ',       --Lottable 09 (CS02)
    ' ',       --Lottable 10 (CS02)
    ' ',       --Lottable 11 (CS02)
    ' ',       --Lottable 12 (CS02)
    NULL,      --Lottable 13 (CS02)
    NULL,      --Lottable 14 (CS02)
    NULL,      --Lottable 15 (CS02) 
    0 ,
    0 ,
    @n_recvqty,
    0 ,
    0 ,
    0 ,
    0 ,
    0 ,
    0 ,
    @c_sourcekey,
    'nspMovetoPutawayLoc',
    @c_packkey,
    @c_uom,
    0 ,--ang01
    NULL,
    '',
     @b_success,
    @n_err,
    @c_errmsg

       SELECT @n_err = @@ERROR
       IF @n_err <> 0
       BEGIN
          SELECT @n_continue = 3
          SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err=62101   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
          SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Movement Fail. (''nspMovetoPutawayLoc'')' + ' ( ' + ' SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
       END

   FETCH NEXT FROM MV02_CUR INTO @c_receiptlineno, @c_storerkey, @c_sku, @c_uom, @c_packkey,
             @c_fromloc, @c_toid, @c_putawayloc, @n_recvqty, @c_lot
  END  -- @@FETCH_STATUS <> -1

  CLOSE MV02_CUR
  DEALLOCATE MV02_CUR
 END

   /* #INCLUDE <SPIAM2.SQL> */
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
      execute nsp_logerror @n_err, @c_errmsg, 'nspMovetoPutawayLoc'
      --RAISERROR @n_err @c_errmsg
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