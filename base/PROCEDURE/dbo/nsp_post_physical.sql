SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/* 2014-Mar-21  TLTING        SQL20112 Bug                              */
CREATE PROCEDURE [dbo].[nsp_post_physical] (
@c_PostMode NVARCHAR(1)
)
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   DECLARE @n_cnt_loop int
   SELECT @n_cnt_loop = 0
   DECLARE @b_debug tinyint
   DECLARE @n_cnt tinyint
   SELECT @b_debug = 0
   IF @b_debug = 1
   BEGIN
      SELECT @c_PostMode "PostMode"
      SELECT "SELECT * FROM PHYSICAL ORDER BY Team, StorerKey, Sku"
      SELECT * FROM PHYSICAL ORDER BY Team, StorerKey, Sku
      SELECT "SELECT * FROM PhysicalParameters"
      SELECT * FROM PhysicalParameters
      SELECT ReceiptKey INTO #RECEIPT FROM RECEIPT
      SELECT ReceiptKey, ReceiptLineNumber INTO #RECEIPTDETAIL FROM RECEIPTDETAIL
      SELECT AdjustmentKey INTO #ADJUSTMENT FROM ADJUSTMENT
      SELECT AdjustmentKey, AdjustmentLineNumber INTO #ADJUSTMENTDETAIL FROM ADJUSTMENTDETAIL
   END
   SELECT PHYSICAL.StorerKey,
   PHYSICAL.Sku,
   PHYSICAL.Loc,
   PHYSICAL.Lot,
   PHYSICAL.Id,
   PHYSICAL.Qty "QtyTeamA",
   PHYSICAL.Uom,
   PHYSICAL.Packkey,
   LOTxLOCxID.Qty "QtyLOTxLOCxID"
   INTO #PHYDET
   FROM PHYSICAL (NOLOCK)
   LEFT JOIN LOTxLOCxID (NOLOCK) ON (LOTxLOCxID.loc = PHYSICAL.loc
                  AND LOTxLOCxID.sku = PHYSICAL.sku
                  AND LOTxLOCxID.lot = PHYSICAL.lot
                  AND LOTxLOCxID.id = PHYSICAL.id) , PHYSICALPARAMETERS (NOLOCK) 
   WHERE PHYSICAL.StorerKey BETWEEN PHYSICALPARAMETERS.StorerKeyMin
   AND PHYSICALPARAMETERS.StorerKeyMax
   AND PHYSICAL.Sku BETWEEN PHYSICALPARAMETERS.SkuMin
   AND PHYSICALPARAMETERS.SkuMax
   AND PHYSICAL.Team = "A"
   SELECT #PHYDET.StorerKey,
   #PHYDET.Sku,
   #PHYDET.Loc,
   #PHYDET.Lot,
   #PHYDET.Id,
   #PHYDET.QtyTeamA "QtyTeamA",
   #PHYDET.Uom,
   #PHYDET.Packkey,
   #PHYDET.QtyLOTxLOCxID "QtyLOTxLOCxID"
   INTO #PHY_POST_DETAIL
   FROM #PHYDET
   WHERE #PHYDET.QtyTeamA != #PHYDET.QtyLOTxLOCxID
   OR #PHYDET.QtyLOTxLOCxID IS NULL
   IF @b_debug = 1
   BEGIN
      SELECT "SELECT * FROM #PHYDET ORDER BY StorerKey, Sku, Loc, Lot"
      SELECT * FROM #PHYDET ORDER BY StorerKey, Sku, Loc, Lot, Id
      SELECT "SELECT * FROM #PHY_POST_DETAIL ORDER BY StorerKey, Sku, Loc, Lot, Id"
      SELECT * FROM #PHY_POST_DETAIL ORDER BY StorerKey, Sku, Loc, Lot, Id
   END
   UPDATE #PHY_POST_DETAIL SET QtyLOTxLOCxID = 0
   WHERE QtyLOTxLOCxID IS NULL
   DECLARE CURSOR_PHYDET CURSOR FAST_FORWARD READ_ONLY
   FOR SELECT
   StorerKey,
   Sku,
   Loc,
   Lot,
   Id,
   QtyTeamA,
   Uom,
   Packkey,
   QtyLOTxLOCxID
   FROM #PHY_POST_DETAIL
   OPEN CURSOR_PHYDET
   DECLARE @c_PHYDET_StorerKey NVARCHAR(15),
   @c_PHYDET_Sku NVARCHAR(20),
   @c_PHYDET_Loc NVARCHAR(10),
   @c_PHYDET_Lot NVARCHAR(10),
   @c_PHYDET_Id NVARCHAR(18),
   @n_PHYDET_QtyTeamA int,
   @c_PHYDET_Uom NVARCHAR(10),
   @c_PHYDET_Packkey NVARCHAR(10),
   @n_PHYDET_QtyLOTxLOCxID int
   
   DECLARE @c_PHYHDR_StorerKey NVARCHAR(15)
   DECLARE @c_PHYHDR_Sku NVARCHAR(20)
   SELECT @c_PHYHDR_StorerKey = SPACE(15)
   SELECT @c_PHYHDR_Sku = SPACE(20)
   DECLARE @b_PHYHDR_Receipt bit
   DECLARE @b_PHYHDR_Adjustment bit
   DECLARE @b_success int
   DECLARE @n_err int
   DECLARE @c_errmsg NVARCHAR(255)
   DECLARE @c_ReceiptKey NVARCHAR(10)
   DECLARE @n_ReceiptLineNumber int
   DECLARE @c_AdjustmentKey NVARCHAR(10)
   DECLARE @n_AdjustmentLineNumber int
   WHILE (1=1)
   BEGIN
      FETCH NEXT FROM CURSOR_PHYDET
      INTO    @c_PHYDET_StorerKey,
      @c_PHYDET_Sku,
      @c_PHYDET_Loc,
      @c_PHYDET_Lot,
      @c_PHYDET_Id,
      @n_PHYDET_QtyTeamA,
      @c_PHYDET_Uom,
      @c_PHYDET_Packkey,
      @n_PHYDET_QtyLOTxLOCxID
      IF NOT @@FETCH_STATUS = 0
      BEGIN
         BREAK
      END
      IF NOT @c_PHYDET_StorerKey = @c_PHYHDR_StorerKey OR NOT @c_PHYDET_Sku = @c_PHYHDR_Sku
      BEGIN
         SELECT @c_PHYHDR_StorerKey = @c_PHYDET_StorerKey
         SELECT @c_PHYHDR_Sku = @c_PHYDET_Sku
         SELECT @b_PHYHDR_Receipt = 0
         SELECT @b_PHYHDR_Adjustment = 0
      END
      IF @c_PostMode = "R" AND @n_PHYDET_QtyTeamA - @n_PHYDET_QtyLOTxLOCxID > 0
      BEGIN
         IF @b_PHYHDR_Receipt = 0
         BEGIN
            SELECT @b_PHYHDR_Receipt = 1
            SELECT @b_success = 1
            EXECUTE nspg_getkey
            "Receipt",
            10,
            @c_ReceiptKey OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_cnt_loop = @n_cnt_loop + 1
               SELECT Sku FROM PHY_POSTED
               WHERE StorerKey =  @c_PHYDET_StorerKey
               AND Sku = @c_PHYDET_Sku
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_cnt = 0
               BEGIN
                  INSERT INTO PHY_POSTED
                  (StorerKey, Sku, QtyTeamA, QtyLOTxLOCxID, ErrorMessage)
                  VALUES ( @c_PHYDET_StorerKey, @c_PHYDET_Sku,
                  @n_PHYDET_QtyTeamA, @n_PHYDET_QtyLOTxLOCxID,
                  "GETKEY() Failed " + @c_errmsg)
               END
               ELSE
               BEGIN
                  UPDATE PHY_POSTED
                  SET ErrorMessage = "GETKEY() Failed " + @c_errmsg
                  WHERE StorerKey = @c_PHYHDR_StorerKey
                  AND Sku = @c_PHYHDR_Sku
               END
               IF @n_cnt_loop < 500
                  CONTINUE
               ELSE
                  BREAK
            END
            ELSE
            BEGIN
               INSERT RECEIPT (
               ReceiptKey,
               StorerKey
               )
               VALUES (
               @c_ReceiptKey,
               @c_PHYHDR_StorerKey
               )
               SELECT @n_err = @@ERROR
               IF NOT @n_err = 0
               BEGIN
                  SELECT @n_cnt_loop = @n_cnt_loop + 1
                  SELECT Sku FROM PHY_POSTED
                  WHERE StorerKey =  @c_PHYDET_StorerKey
                  AND Sku = @c_PHYDET_Sku
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_cnt = 0
                  BEGIN
                     INSERT INTO PHY_POSTED
                     (StorerKey, Sku, QtyTeamA, QtyLOTxLOCxID, ErrorMessage)
                     VALUES ( @c_PHYDET_StorerKey, @c_PHYDET_Sku,
                     @n_PHYDET_QtyTeamA, @n_PHYDET_QtyLOTxLOCxID,
                     "GETKEY() Failed " + @c_errmsg)
                  END
                  ELSE
                  BEGIN
                     UPDATE PHY_POSTED
                     SET ErrorMessage = "GETKEY() Failed " + @c_errmsg
                     WHERE StorerKey = @c_PHYHDR_StorerKey
                     AND Sku = @c_PHYHDR_Sku
                  END
                  IF @n_cnt_loop < 500
                     CONTINUE
                  ELSE
                     BREAK
               END
               SELECT @n_ReceiptLineNumber = 0
            END
            SELECT @n_ReceiptLineNumber = @n_ReceiptLineNumber + 1
            INSERT RECEIPTDETAIL (
            ReceiptKey,
            ReceiptLineNumber,
            StorerKey,
            Sku,
            ToLoc,
            ToLot,
            ToId,
            QtyReceived
            )
            VALUES (
            @c_ReceiptKey,
            SUBSTRING(CONVERT(char(6), @n_ReceiptLineNumber + 100000), 2, 5),
            @c_PHYHDR_StorerKey,
            @c_PHYHDR_Sku,
            @c_PHYDET_Loc,
            @c_PHYDET_Lot,
            @c_PHYDET_Id,
            @n_PHYDET_QtyTeamA - @n_PHYDET_QtyLOTxLOCxID
            )
            SELECT @n_err = @@ERROR
            IF NOT @n_err = 0
            BEGIN
               SELECT @n_cnt_loop = @n_cnt_loop + 1
               SELECT Sku FROM PHY_POSTED
               WHERE StorerKey =  @c_PHYDET_StorerKey
               AND Sku = @c_PHYDET_Sku
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_cnt = 0
               BEGIN
                  INSERT INTO PHY_POSTED
                  (StorerKey, Sku, QtyTeamA, QtyLOTxLOCxID, ErrorMessage)
                  VALUES ( @c_PHYDET_StorerKey, @c_PHYDET_Sku,
                  @n_PHYDET_QtyTeamA, @n_PHYDET_QtyLOTxLOCxID,
                  "GETKEY() Failed " + @c_errmsg)
               END
            ELSE
               BEGIN
                  UPDATE PHY_POSTED
                  SET ErrorMessage = "GETKEY() Failed " + @c_errmsg
                  WHERE StorerKey = @c_PHYHDR_StorerKey
                  AND Sku = @c_PHYHDR_Sku
               END
               IF @n_cnt_loop < 500
               CONTINUE
            ELSE
               BREAK
            END
         END
      END
   ELSE
      BEGIN
         IF @b_PHYHDR_Adjustment = 0
         BEGIN
            SELECT @b_PHYHDR_Adjustment = 1
            SELECT @b_success = 1
            EXECUTE nspg_getkey
            "Adjustment",
            10,
            @c_AdjustmentKey OUTPUT,
            @b_success OUTPUT,
            @n_err OUTPUT,
            @c_errmsg OUTPUT
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_cnt_loop = @n_cnt_loop + 1
               SELECT Sku FROM PHY_POSTED
               WHERE StorerKey =  @c_PHYDET_StorerKey
               AND Sku = @c_PHYDET_Sku
               SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
               IF @n_cnt = 0
               BEGIN
                  INSERT INTO PHY_POSTED
                  (StorerKey, Sku, QtyTeamA, QtyLOTxLOCxID, ErrorMessage)
                  VALUES ( @c_PHYDET_StorerKey, @c_PHYDET_Sku,
                  @n_PHYDET_QtyTeamA, @n_PHYDET_QtyLOTxLOCxID,
                  "GETKEY() Failed " + @c_errmsg)
               END
            ELSE
               BEGIN
                  UPDATE PHY_POSTED
                  SET ErrorMessage = "GETKEY() Failed " + @c_errmsg
                  WHERE StorerKey = @c_PHYHDR_StorerKey
                  AND Sku = @c_PHYHDR_Sku
               END
               IF @n_cnt_loop < 500
               CONTINUE
            ELSE
               BREAK
            END
         ELSE
            BEGIN
               INSERT ADJUSTMENT (
               AdjustmentKey,
               StorerKey
               )
               VALUES (
               @c_AdjustmentKey,
               @c_PHYHDR_StorerKey
               )
               SELECT @n_err = @@ERROR
               IF NOT @n_err = 0
               BEGIN
                  SELECT @n_cnt_loop = @n_cnt_loop + 1
                  SELECT Sku FROM PHY_POSTED
                  WHERE StorerKey =  @c_PHYDET_StorerKey
                  AND Sku = @c_PHYDET_Sku
                  SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
                  IF @n_cnt = 0
                  BEGIN
                     INSERT INTO PHY_POSTED
                     (StorerKey, Sku, QtyTeamA, QtyLOTxLOCxID, ErrorMessage)
                     VALUES ( @c_PHYDET_StorerKey, @c_PHYDET_Sku,
                     @n_PHYDET_QtyTeamA, @n_PHYDET_QtyLOTxLOCxID,
                     "GETKEY() Failed " + @c_errmsg)
                  END
               ELSE
                  BEGIN
                     UPDATE PHY_POSTED
                     SET ErrorMessage = "GETKEY() Failed " + @c_errmsg
                     WHERE StorerKey = @c_PHYHDR_StorerKey
                     AND Sku = @c_PHYHDR_Sku
                  END
                  IF @n_cnt_loop < 500
                  CONTINUE
               ELSE
                  BREAK
               END
            END
            SELECT @n_AdjustmentLineNumber = 0
         END
         SELECT @n_AdjustmentLineNumber = @n_AdjustmentLineNumber + 1
         INSERT ADJUSTMENTDETAIL (
         AdjustmentKey,
         AdjustmentLineNumber,
         StorerKey,
         Sku,
         Loc,
         Lot,
         Id,
         Qty,
         Uom,
         Packkey,
         ReasonCode
         )
         VALUES (
         @c_AdjustmentKey,
         SUBSTRING(CONVERT(char(6), @n_AdjustmentLineNumber + 100000), 2, 5),
         @c_PHYHDR_StorerKey,
         @c_PHYHDR_Sku,
         @c_PHYDET_Loc,
         @c_PHYDET_Lot,
         @c_PHYDET_Id,
         @n_PHYDET_QtyTeamA - @n_PHYDET_QtyLOTxLOCxID,
         @c_PHYDET_Uom,
         @c_PHYDET_Packkey,
         "General Adjustment"
         )
         SELECT @n_err = @@ERROR
         IF NOT @n_err = 0
         BEGIN
            SELECT @n_cnt_loop = @n_cnt_loop + 1
            SELECT Sku FROM PHY_POSTED
            WHERE StorerKey =  @c_PHYDET_StorerKey
            AND Sku = @c_PHYDET_Sku
            SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
            IF @n_cnt = 0
            BEGIN
               INSERT INTO PHY_POSTED
               (StorerKey, Sku, QtyTeamA, QtyLOTxLOCxID, ErrorMessage)
               VALUES ( @c_PHYDET_StorerKey, @c_PHYDET_Sku,
               @n_PHYDET_QtyTeamA, @n_PHYDET_QtyLOTxLOCxID,
               "GETKEY() Failed " + @c_errmsg)
            END
         ELSE
            BEGIN
               UPDATE PHY_POSTED
               SET ErrorMessage = "GETKEY() Failed " + @c_errmsg
               WHERE StorerKey = @c_PHYHDR_StorerKey
               AND Sku = @c_PHYHDR_Sku
            END
            IF @n_cnt_loop < 500
            CONTINUE
         ELSE
            BREAK
         END
      END
   END
   DROP TABLE #PHY_POST_DETAIL
   DROP TABLE #PHYDET
   CLOSE CURSOR_PHYDET
   DEALLOCATE CURSOR_PHYDET
   IF @b_debug = 1
   BEGIN
      SELECT "SELECT * FROM PHY_POSTED WHERE NOT ErrorMessage IS NULL ORDER BY StorerKey, Sku"
      SELECT * FROM PHY_POSTED WHERE NOT ErrorMessage IS NULL ORDER BY StorerKey, Sku
      SELECT "VALUE OF @n_cnt_loop, How many times did we get this error."
      SELECT @n_cnt_loop
      SELECT "SELECT * FROM RECEIPT WHERE ReceiptKey NOT IN (SELECT ReceiptKey FROM #RECEIPT)"
      SELECT ReceiptKey, StorerKey FROM RECEIPT WHERE ReceiptKey NOT IN (SELECT ReceiptKey FROM #RECEIPT)
      SELECT "SELECT * FROM RECEIPTDETAIL WHERE ReceiptKey + ReceiptLineNumber NOT IN (SELECT ReceiptKey + ReceiptLineNumber FROM #RECEIPTDETAIL)"
      SELECT ReceiptKey, ReceiptLineNumber, StorerKey, Sku, ToLoc, ToLot, ToId, QtyReceived FROM RECEIPTDETAIL WHERE ReceiptKey + ReceiptLineNumber NOT IN (SELECT ReceiptKey + ReceiptLineNumber FROM #RECEIPTDETAIL)
      SELECT "SELECT * FROM ADJUSTMENT WHERE AdjustmentKey NOT IN (SELECT AdjustmentKey FROM #ADJUSTMENT)"
      SELECT AdjustmentKey, StorerKey FROM ADJUSTMENT WHERE AdjustmentKey NOT IN (SELECT AdjustmentKey FROM #ADJUSTMENT)
      SELECT "SELECT * FROM ADJUSTMENTDETAIL WHERE AdjustmentKey + AdjustmentLineNumber NOT IN (SELECT AdjustmentKey + AdjustmentLineNumber FROM #ADJUSTMENTDETAIL)"
      SELECT AdjustmentKey, AdjustmentLineNumber, StorerKey, Sku, Loc, Lot, Id, Qty FROM ADJUSTMENTDETAIL WHERE AdjustmentKey + AdjustmentLineNumber NOT IN (SELECT AdjustmentKey + AdjustmentLineNumber FROM #ADJUSTMENTDETAIL)
      DROP TABLE #RECEIPT
      DROP TABLE #RECEIPTDETAIL
      DROP TABLE #ADJUSTMENT
      DROP TABLE #ADJUSTMENTDETAIL
   END
END


GO