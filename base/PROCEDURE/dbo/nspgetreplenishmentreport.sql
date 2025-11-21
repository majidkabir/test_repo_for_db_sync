SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: nspGetReplenishmentReport                          */
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
/************************************************************************/

CREATE PROC [dbo].[nspGetReplenishmentReport] AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @n_continue       int
   ,        @n_starttcnt      int         -- Holds the current transaction count
   ,        @c_preprocess     NVARCHAR(250)   -- preprocess
   ,        @c_pstprocess     NVARCHAR(250)   -- post process
   ,        @n_cnt            int
   ,        @n_err2           int         -- For Additional Error Detection
   ,        @n_err            int
   ,        @c_errmsg         NVARCHAR(250)
   ,        @b_success        int
   ,        @b_debug          int
   ,        @c_storerkey      NVARCHAR(20)    -- Values passed to the move itrn SP --
   ,        @c_lot            NVARCHAR(20)    --
   ,        @c_fromid         NVARCHAR(20)    --
   ,        @c_toid           NVARCHAR(20)    --
   ,        @c_sourcekey      NVARCHAR(20)    --
   ,        @c_packkey        NVARCHAR(20)    --
   ,        @n_qty            int         --
   ,        @c_uom            NVARCHAR(20)
   ,        @n_cntlr          int         --
   ,        @c_ReplenishmentKey	 NVARCHAR(10)
   -- Populate the security table --
   -- Insert Replen_security Values(1)
   SELECT @n_starttcnt=@@TRANCOUNT , @n_continue=1, @n_err2=0
   SELECT @b_debug = 0
   -- Get the Pick Locations that need replenishing --
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT TOLOC = SKUxLOC.loc,
      SKU.sku,
      SKU.Storerkey,
      description = Convert(Char(20), Sku.descr)
      INTO #QtyNeed
      FROM SKUxLOC ,SKU
      WHERE SKUxLOC.locationtype IN ('PICK', 'CASE')
      and SKU.sku = SKUxLOC.sku
      and SKU.storerkey = SKUxLOC.storerkey
      and SKUxLOC.sku is not NULL
      --      and (SKUxLOC.qty - SKUxLOC.qtyallocated - SKUxLOC.qtypicked) <= SKUxLOC.qtylocationminimum
      and (SKUxLOC.qty - SKUxLOC.qtyallocated - SKUxLOC.qtypicked) <= SKUxLOC.qtylocationlimit
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 79400
         SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " Creation of #tempLoc table failed. (nspGetReplenishmentReport)."
      END
      IF @b_debug > 0
      BEGIN
         SELECT * FROM #QtyNeed
      END
   END
   -- Checked and OK. --
   -- Get the location to get from and the quantity available to move --
   -- Make sure not to get inventory that are on hold --
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      SELECT #QTYNEED.Storerkey,
      #QTYNEED.Sku,
      LOTxLOCxID.Lot,
      Fromloc = LOTxLOCxID.Loc,
      FromID  = LOTxLOCxID.ID,
      quantityavailable = (LOTxLOCxID.qty - LOTxLOCxID.qtyallocated - LOTxLOCxID.qtypicked),
      SKU.Packkey,
      LOTATTRIBUTE.Lottable03,
      LOTATTRIBUTE.Lottable04
      INTO   #QtyAvail
      FROM   LOTxLOCxID, #QTYNEED, LOC, PACK, SKU, LOTATTRIBUTE
      WHERE  LOTxLOCxID.sku       = #QTYNEED.SKU
      and LOTxLOCxID.storerkey = #QTYNEED.Storerkey
      and LOTxLOCxID.loc       = LOC.loc
      and LOTxLOCxID.Sku       = SKU.Sku
      and LOTxLOCxID.Storerkey = SKU.Storerkey
      and SKU.Packkey          = PACK.Packkey
      and PACK.PALLET          > 0
      and LOTxLOCxID.Lot       = LOTATTRIBUTE.Lot
      -- and LOC.locationtype     NOT IN ('PICK', 'CASE')
      and LOC.Locationflag     <> "HOLD"
      and LOC.Locationflag     <> "DAMAGE"
      and LOTxLOCxID.Loc       <> "STAGE"
      and (LOTxLOCxID.qty - LOTxLOCxID.qtyallocated - LOTxLOCxID.qtypicked) > 0
      and LOTxLOCxID.Id NOT IN (SELECT Id FROM INVENTORYHOLD (nolock) WHERE HOLD = '1')
      and LOTxLOCxID.Loc NOT IN ( SELECT DISTINCT toloc from #QtyNEED)
      ORDER BY #QTYNEED.Storerkey, #QTYNEED.sku, LOTATTRIBUTE.lottable04, LOTxLOCxID.Lot, LOTxLOCxID.loc
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
      SELECT * INTO #TEMPCHECK FROM #QtyNeed
      SELECT @n_cntlr = @@ROWCOUNT
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 79403
         SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " Creation of #QtyAvail table failed. (nspBOCReplishment)."
      END
   ELSE IF @n_cnt = 0 And @n_cntlr = 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 79404
         SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " No Stock Available. (nspGetReplenishmentReport)."
      END
      IF @b_debug > 0
      BEGIN
         PRINT 'Table #QtyAvail'
         SELECT * FROM #QtyAvail
      END
   END
   -- Checked and OK --
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @c_lasttoloc    NVARCHAR(10)        -- To Location --
      ,       @c_lastfromloc  NVARCHAR(10)        -- From Location --
      ,       @c_lastsku              NVARCHAR(20)-- Product ID --
      ,        @c_lastqn               NVARCHAR(5) -- Quantity needed --
      ,       @c_lastqa               NVARCHAR(5) -- Quantity available --
      ,       @n_lastqn               INT
      ,       @n_lastqa               INT
      ,       @c_laststorerkey        NVARCHAR(20)
      ,       @c_lastlot              NVARCHAR(20)
      ,       @c_lastfromid           NVARCHAR(20)
      ,       @c_lasttoid             NVARCHAR(20)
      ,       @c_lastpackkey          NVARCHAR(20)
      ,       @d_lastlottable04       DATETIME
      ,       @c_lastdescr            NVARCHAR(30)
      ,       @c_descr                NVARCHAR(30)
      ,       @c_toloc        NVARCHAR(10)        -- To Location --
      ,       @c_fromloc      NVARCHAR(10)        -- From Location --
      ,       @c_sku          NVARCHAR(20)        -- Product ID --
      ,       @n_qn           INT             -- Quantity needed --
      ,       @n_qa           INT             -- Quantity available --
      ,       @d_lottable04   DATETIME
      ,       @c_lottable03   NVARCHAR(20)
      ,       @n_ql           INT
      ,       @n_tempqn       INT
      ,       @n_tempqa       INT
      ,       @n_maxqa        INT
      ,       @c_tempfromloc  NVARCHAR(10)
      ,       @c_replen       NVARCHAR(1)
      SELECT @c_lasttoid = '', @c_toid = ''
      DECLARE @b_QN_CURSOR_open INT
      SELECT @b_QN_CURSOR_open = 0
      DECLARE_QUANTIY_NEEDED:
      DECLARE QUANTITYNEEDED_CURSOR CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT * FROM #QtyNeed
      SELECT @n_err = @@ERROR
      IF @n_err = 16915
      BEGIN
         IF @b_debug > 0
         BEGIN
            PRINT 'QUANTITYNEEDED_CURSOR ERROR 16915'
         END
         CLOSE QUANTITYNEEDED_CURSOR
         DEALLOCATE QUANTITYNEEDED_CURSOR
         --GOTO DECLARE_QUANTIY_NEEDED
      END
      OPEN QUANTITYNEEDED_CURSOR
      SELECT @n_err = @@ERROR
      IF @n_err = 16905
      BEGIN
         IF @b_debug > 0
         BEGIN
            PRINT 'QUANTITYNEEDED_CURSOR ERROR 16905'
         END
         CLOSE QUANTITYNEEDED_CURSOR
         DEALLOCATE QUANTITYNEEDED_CURSOR
         --GOTO DECLARE_QUANTIY_NEEDED
      END
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 79501
         SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " Could not open QUANTITYNEEDED_CURSOR. (nspGetReplenishmentReport)."
      END
   ELSE
      BEGIN
         SELECT @b_QN_CURSOR_open = 1
         IF @b_debug > 0
         BEGIN
            PRINT 'QUANTITYNEEDED_CURSOR opened'
         END
      END
   END
   -- Setup the final table for MOVES(replenishment)  --
   IF @b_debug = 1
   BEGIN
      PRINT 'move start ...'
   END
   IF (@n_continue = 1) OR (@n_continue = 2)
   BEGIN
      SELECT fromloc,
      fromid = @c_lastfromid,
      toloc ,
      toid   = @c_lasttoid,
      #QtyNeed.sku ,
      quantityavailable,
      storerkey  = @c_laststorerkey,
      lot        = @c_lastlot,
      packkey    = @c_lastpackkey,
      lottable04 = @d_lastlottable04,
      descr      = @c_lastdescr,
      lottable03 = @c_lottable03
      INTO #FINAL
      FROM #QtyAvail, #QtyNeed
      WHERE 1 = 2
      SELECT @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 79500
         SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " Creation of #FINAL temp table failed. (nspGetReplenishmentReport)."
      END
   END
   -- Replenishment starts
   IF (@n_continue = 1) OR (@n_continue = 2)
   BEGIN
      IF @b_debug > 0
      BEGIN
         PRINT 'Replenishment starts....'
      END
      WHILE (1=1) AND ((@n_continue = 1) OR (@n_continue = 2))
      BEGIN
         FETCH QUANTITYNEEDED_CURSOR
         INTO @c_lasttoloc, @c_lastsku, @c_laststorerkey, @c_lastdescr
         IF @b_debug = 1
         BEGIN
            PRINT 'move start ...'
            select @c_lasttoloc, @c_lastsku, @c_laststorerkey, @c_lastdescr
         END
         IF @@FETCH_STATUS = -1
         BEGIN
            BREAK
         END
      ELSE IF @@FETCH_STATUS < -1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 79502
            SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " Could not fetch from QUANTITYNEEDED_CURSOR. (nspGetReplenishmentReport)."
            BREAK
         END
      ELSE IF @@FETCH_STATUS = 0
         BEGIN
            -- Set replen to 0 shows no replenishment on this row has occurred
            SELECT @c_replen = '0'
            -- Reset variables
            SELECT @c_fromloc = '',@c_fromid = '',@c_lot = '',@n_qa = 0
            IF @b_debug > 0
            BEGIN
               PRINT 'From QUANTITYNEEDED_CURSOR...'
               SELECT @c_lasttoloc, @c_lastsku, @c_laststorerkey, @c_lastdescr
            END
            /*  Check to see if their are any to replenish with earliest Expiry Date(lottable04), */
            /*  Largest qty available and nearest pick location */
            SET ROWCOUNT 1
            SELECT @c_fromloc = fromloc, @c_lot = lot, @n_qa = quantityavailable, @d_lottable04 = lottable04,
            @c_fromid = fromid, @c_storerkey = storerkey, @c_packkey = packkey, @c_lottable03 = lottable03
            FROM #QtyAvail
            WHERE sku = @c_lastsku
            AND storerkey = @c_laststorerkey
            and lottable04 <> ( select convert(datetime,'01/01/1900' ))
            and lottable04 = (SELECT MIN(lottable04) FROM #QtyAvail
            WHERE sku = @c_lastsku and storerkey = @c_laststorerkey and lottable04 <> ( select convert(datetime,'01/01/1900' )))
            ORDER BY Lottable04, quantityavailable DESC
            SET ROWCOUNT 0
            IF @b_debug = 1
            BEGIN
               PRINT ' ====== b4 insert'
               SELECT fromloc,  lot,   quantityavailable,  lottable04,
               fromid, storerkey,  packkey,  lottable03
               FROM #QtyAvail  WHERE sku = @c_lastsku
               AND storerkey = @c_laststorerkey
               and  lottable04 > ( select convert(datetime,'01/01/1999' ))
               PRINT ' ====== after insert'
            END
            -- Got a fromloc with earliest expiry date
            IF @c_fromloc <> '' AND ( isnull(@c_fromloc,'1') <> '1')
            BEGIN
               IF @b_debug > 0
               BEGIN
                  PRINT 'replenish with earliest Expiry...'
                  SELECT @c_fromloc, @c_fromid, @c_lasttoloc, @c_fromid, @c_lastsku
               END
               IF @b_debug = 1
               BEGIN
                  PRINT 'TABLE #FINAL expiry date '
                  SELECT * FROM #FINAL (NOLOCK)
               END
               INSERT #FINAL VALUES(@c_fromloc, @c_fromid, @c_lasttoloc, @c_fromid, @c_lastsku,
               @n_qa, @c_storerkey, @c_lot, @c_packkey, @d_lottable04, @c_lastdescr, @c_lottable03)
               DELETE FROM #QtyAvail
               WHERE fromid = @c_fromid AND fromloc = @c_fromloc and lot = @c_lot
               SELECT @c_replen = '1'
            END  -- end replenishment with earliest Expiry Date
            -- IF no replenishment on expiry date then replenish with lowest lot (FIFO)
            IF @c_replen = '0'
            BEGIN
               SET ROWCOUNT 1
               SELECT @c_fromloc = fromloc, @c_lot = lot, @n_qa = quantityavailable, @c_lot = lot,
               @c_fromid = fromid, @c_storerkey = storerkey, @c_packkey = packkey, @c_lottable03 = lottable03
               FROM #QtyAvail
               WHERE sku = @c_lastsku
               AND storerkey = @c_laststorerkey
               order by lot
               SET ROWCOUNT 0
               IF @c_fromloc <> '' AND @c_fromloc <> NULL
               BEGIN
                  IF @b_debug > 0
                  BEGIN
                     PRINT 'replenish with lowest lot...'
                     SELECT @c_fromloc, @c_fromid, @c_lasttoloc, @c_fromid, @c_lastsku
                  END
                  INSERT #FINAL VALUES(@c_fromloc, @c_fromid, @c_lasttoloc, @c_fromid, @c_lastsku,
                  @n_qa, @c_storerkey, @c_lot, @c_packkey, @d_lottable04, @c_lastdescr, @c_lottable03)
                  DELETE FROM #QtyAvail
                  WHERE fromid = @c_fromid AND fromloc = @c_fromloc and lot = @c_lot
                  SELECT @c_replen = '1'
               END
            END  -- end replenishment with lowest lot
            -- Added by Ricky for no lot found
            IF @c_replen = '0'
            BEGIN
               INSERT #FINAL VALUES(@c_fromloc, @c_fromid, @c_lasttoloc, @c_fromid, @c_lastsku,
               @n_qa, @c_laststorerkey, @c_lot, @c_packkey, @d_lottable04, @c_lastdescr, @c_lottable03)
               DELETE FROM #QtyAvail
               WHERE fromid = @c_fromid AND fromloc = @c_fromloc and lot = @c_lot
            END
         END  -- @@FETCH_STATUS  = 0
      END  -- While
      IF @b_debug > 0
      BEGIN
         PRINT 'TABLE #FINAL'
         SELECT * FROM #FINAL (NOLOCK)  ORDER BY STORERKEY, SKU
      END
   END
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN
      DECLARE @b_REPLEN_CURSOR_open INT
      SELECT @b_REPLEN_CURSOR_open = 0
      DECLARE_QUANTIY_REPLEN:
      DECLARE QUANTITYREPLEN_CURSOR CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT * FROM #FINAL WHERE FROMLOC > ' '
      SELECT @n_err = @@ERROR
      IF @n_err = 16915
      BEGIN
         IF @b_debug > 0
         BEGIN
            PRINT 'QUANTITYREPLEN_CURSOR ERROR 16915'
         END
         CLOSE QUANTITYREPLEN_CURSOR
         DEALLOCATE QUANTITYREPLEN_CURSOR
         GOTO DECLARE_QUANTIY_REPLEN
      END
      OPEN QUANTITYREPLEN_CURSOR
      SELECT @n_err = @@ERROR
      IF @n_err = 16905
      BEGIN
         IF @b_debug > 0
         BEGIN
            PRINT 'QUANTITYREPLEN_CURSOR ERROR 16905'
         END
         CLOSE QUANTITYREPLEN_CURSOR
         DEALLOCATE QUANTITYREPLEN_CURSOR
         GOTO DECLARE_QUANTIY_REPLEN
      END
      IF @n_err <> 0
      BEGIN
         SELECT @n_continue = 3
         SELECT @n_err = 79508
         SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " Could not open QUANTITYREPLEN_CURSOR. (nspGetReplenishmentReport)."
      END
   ELSE
      BEGIN
         SELECT @b_REPLEN_CURSOR_open = 1
         IF @b_debug > 0
         BEGIN
            PRINT 'QUANTITYREPLEN_CURSOR opened'
         END
      END
   END
   -- Finalised Replenishment
   IF (@n_continue = 1) OR (@n_continue = 2)
   BEGIN
      IF @b_debug > 0
      BEGIN
         PRINT 'Finalised Replenishment....'
      END
      WHILE (1=1) AND ((@n_continue = 1) OR (@n_continue = 2))
      BEGIN
         FETCH QUANTITYREPLEN_CURSOR
         INTO @c_fromloc, @c_fromid, @c_toloc, @c_toid, @c_sku,
         @n_qa, @c_storerkey, @c_lot, @c_packkey, @d_lottable04, @c_lastdescr, @c_lottable03
         IF @@FETCH_STATUS = -1
         BEGIN
            BREAK
         END
      ELSE IF @@FETCH_STATUS < -1
         BEGIN
            SELECT @n_continue = 3
            SELECT @n_err = 79509
            SELECT @c_errmsg = "NSQL " + CONVERT(CHAR(5), @n_err) + " Could not fetch from QUANTITYAVAILABLE_CURSOR. (nspBOCReplishment)."
            BREAK
         END
      ELSE IF @@FETCH_STATUS = 0
         BEGIN
            SELECT @n_qty = @n_qa   -- MOVE all from location
            IF @b_debug > 0
            BEGIN
               PRINT 'Execute nspAddItrnMove .....'
               SELECT @c_fromloc, @c_fromid, @c_toloc, @c_toid, @c_sku, @n_qty, @c_storerkey, @c_lot, @c_packkey
            END
            -- Execute nspAddItrnMove
            SELECT @b_success = 1
         END  -- end @@FETCH_STATUS = 0
      END  -- end while
   END
   -- Close all open cursors
   IF @b_QN_CURSOR_open = 1
   BEGIN
      CLOSE QUANTITYNEEDED_CURSOR
      DEALLOCATE QUANTITYNEEDED_CURSOR
   END
   IF @b_REPLEN_CURSOR_open = 1
   BEGIN
      CLOSE QUANTITYREPLEN_CURSOR
      DEALLOCATE QUANTITYREPLEN_CURSOR
   END
   IF @n_continue = 3 -- Error occured - Process and return
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "nspGetReplenishmentReport"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
         COMMIT TRAN
      END
   END
   -- Free up the security table --
   --DELETE Replen_security
   SELECT #FINAL.*, LOC.Putawayzone
   FROM #FINAL, LOC
   WHERE #FINAL.ToLoc = LOC.Loc
   ORDER BY LOC.Putawayzone, #FINAL.ToLoc
   -- List the Replenishment Report
   -- SELECT * FROM #FINAL ORDER BY storerkey, sku, toLOC
END


GO