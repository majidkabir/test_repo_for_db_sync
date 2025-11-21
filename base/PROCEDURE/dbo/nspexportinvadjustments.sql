SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspExportInvAdjustments                            */
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
/* 16/7/2008   TLTING      transmitflag = '0',                          */
/*                         Apply SQL2005 Std (TLTING01)                 */
/************************************************************************/

/****** Object:  Stored Procedure dbo.nspExportInvAdjustments    Script Date: 09/10/99 3:23:38 PM ******/
CREATE PROCEDURE [dbo].[nspExportInvAdjustments]
AS
BEGIN -- main processing
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- create a temp result table
   SELECT adjustmentkey,
   adjustmentlinenumber,
   customerrefno = space(10),
   adjustmenttype = space(3),
   sku,
   reasoncode,
   fromtowhse = space(6),
   logicalwhse = space(18),
   expiry = space(10),
   mfglot = space(18),
   qty
   INTO #Result
   FROM ADJUSTMENTDETAIL
   WHERE 1 = 2
   DECLARE @c_key1		 NVARCHAR(10),
   @c_key2		 NVARCHAR(5),
   @c_key3		 NVARCHAR(20),
   @c_custrefno	 NVARCHAR(10),
   @c_adjtype	 NVARCHAR(3),
   @c_sku		 NVARCHAR(20),
   @c_reasoncode	 NVARCHAR(10),
   @c_mfglot	 NVARCHAR(18),
   @c_expiry	 NVARCHAR(10),
   @c_fromtowhse	 NVARCHAR(6),
   @c_logicalwhse	 NVARCHAR(18),
   @n_qty			int,
   @c_transmitbatch NVARCHAR(10)
   DECLARE cur_1 CURSOR FAST_FORWARD READ_ONLY
   FOR
   SELECT key1, key2, key3, transmitbatch
   FROM TRANSMITLOG WITH (NOLOCK)      -- TLTING01
   WHERE transmitflag = '0'            -- TLTING01
   OPEN cur_1
   FETCH NEXT FROM cur_1 INTO @c_key1, @c_key2, @c_key3, @c_transmitbatch
   WHILE (@@fetch_status <> -1)
   BEGIN
      IF @c_transmitbatch = 'Adjustment'
      BEGIN
         SELECT @c_custrefno = ADJUSTMENT.customerrefno,
         @c_adjtype = ADJUSTMENT.adjustmenttype,
         @c_sku = ADJUSTMENTDETAIL.sku,
         @c_reasoncode = ADJUSTMENTDETAIL.reasoncode,
         @c_mfglot = LOTATTRIBUTE.lottable02,
         @c_expiry = RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, LOTATTRIBUTE.lottable04))),2) + "/"
         + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, LOTATTRIBUTE.lottable04))),2) + "/"
         + RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, LOTATTRIBUTE.lottable04))),4),
         @c_fromtowhse = ADJUSTMENT.fromtowhse,
         @c_logicalwhse = LOTATTRIBUTE.lottable03,
         @n_qty = SUM(ADJUSTMENTDETAIL.qty)
         FROM ADJUSTMENT WITH (NOLOCK), ADJUSTMENTDETAIL WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK)
         WHERE ADJUSTMENT.adjustmentkey = @c_key1
         AND ADJUSTMENTDETAIL.adjustmentkey = @c_key1
         AND ADJUSTMENTDETAIL.adjustmentlinenumber = @c_key2
         AND ADJUSTMENTDETAIL.lot = LOTATTRIBUTE.lot
         AND ADJUSTMENT.adjustmenttype <> 'WHS'
         GROUP BY ADJUSTMENT.customerrefno,
         ADJUSTMENT.adjustmenttype,
         ADJUSTMENTDETAIL.sku,
         ADJUSTMENTDETAIL.reasoncode,
         LOTATTRIBUTE.lottable02,
         LOTATTRIBUTE.lottable04,
         ADJUSTMENT.fromtowhse,
         LOTATTRIBUTE.lottable03

         IF @@ROWCOUNT <> 0
         BEGIN
            INSERT #Result
            VALUES(@c_key1, @c_key2, @c_custrefno, @c_adjtype, @c_sku, @c_reasoncode,
            @c_fromtowhse, @c_logicalwhse, @c_expiry, @c_mfglot, @n_qty)
         END
      END
      /*
      ELSE IF @c_transmitbatch = 'Move'
      BEGIN
      SELECT @c_sku = ITRN.sku,
      @c_logicalwhse = LOTATTRIBUTE.lottable03,
      @c_expiry = RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, LOTATTRIBUTE.lottable04))),2) + "/"
      + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, LOTATTRIBUTE.lottable04))),2) + "/"
      + RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, LOTATTRIBUTE.lottable04))),4),
      @c_mfglot = LOTATTRIBUTE.lottable02,
      @n_qty = ITRN.qty
      FROM ITRN, LOTATTRIBUTE
      WHERE ITRN.itrnkey = @c_key1
      AND ITRN.lot = LOTATTRIBUTE.lot
      INSERT #Result	-- for positive value
      VALUES(@c_key1, '00001', @c_key1, 'IWT', @c_sku, '', '', @c_logicalwhse,
      @c_expiry, @c_mfglot, @n_qty)
      INSERT #Result	-- for negative value
      VALUES(@c_key1, '00001', @c_key1, 'IWT', @c_sku, '', '', @c_logicalwhse,
      @c_expiry, @c_mfglot, 0 - @n_qty)
      -- to skip next record in transmitlog since it will be the same key1
      FETCH NEXT FROM cur_1 INTO @c_key1, @c_key2, @c_key3, @c_transmitbatch
      END
      */
   ELSE IF @c_transmitbatch = 'Transfer'
      BEGIN
         SELECT @c_reasoncode = reasoncode
         FROM TRANSFER
         WHERE transferkey = @c_key1
         -- for the withdrawal
         SELECT @c_sku = ITRN.sku,
         @c_logicalwhse = LOTATTRIBUTE.lottable03,
         @c_expiry = RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, LOTATTRIBUTE.lottable04))),2) + "/"
         + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, LOTATTRIBUTE.lottable04))),2) + "/"
         + RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, LOTATTRIBUTE.lottable04))),4),
         @c_mfglot = LOTATTRIBUTE.lottable02,
         @n_qty = ITRN.qty
         FROM ITRN WITH (NOLOCK), LOTATTRIBUTE WITH (NOLOCK)
         WHERE ITRN.sourcekey = @c_key1 + @c_key2
         AND ITRN.lot = LOTATTRIBUTE.lot
         AND ITRN.trantype = 'WD'
         AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
         INSERT #Result
         VALUES(@c_key1, @c_key2, @c_key1, 'IWT', @c_sku, @c_reasoncode, '',
         @c_logicalwhse, @c_expiry,@c_mfglot, @n_qty)
         -- for the deposit
         SELECT @c_sku = ITRN.sku,
         @c_logicalwhse = ITRN.lottable03,
         @c_expiry = RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(month, ITRN.lottable04))),2) + "/"
         + RIGHT(dbo.fnc_RTrim("0" + CONVERT(char(2), DATEPART(day, ITRN.lottable04))),2) + "/"
         + RIGHT(dbo.fnc_RTrim("00" + CONVERT(char(4), DATEPART(year, ITRN.lottable04))),4),
         @c_mfglot = ITRN.lottable02,
         @n_qty = ITRN.qty
         FROM ITRN
         WHERE ITRN.sourcekey = @c_key1 + @c_key2
         AND ITRN.trantype = 'DP'
         AND ITRN.sourcetype = 'ntrTransferDetailUpdate'
         INSERT #Result
         VALUES(@c_key1, @c_key2, @c_key1, 'IWT', @c_sku, @c_reasoncode, '',
         @c_logicalwhse, @c_expiry,@c_mfglot, @n_qty)
      END
      FETCH NEXT FROM cur_1 INTO @c_key1, @c_key2, @c_key3, @c_transmitbatch
   END
   CLOSE cur_1
   DEALLOCATE cur_1
   UPDATE #Result
   SET expiry = NULL
   WHERE expiry = '0/0/00'
   -- delete all safekeeping transactions
   DELETE #Result
   WHERE LEFT(logicalwhse, 2) = 'SK'
   SELECT * FROM #Result
   DROP TABLE #Result
END -- main processing


GO