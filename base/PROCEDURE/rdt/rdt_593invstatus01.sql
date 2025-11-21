SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/********************************************************************************/
/* Store procedure: rdt_593InvStatus01                                          */
/*                                                                              */
/* Copyright: Maersk                                                            */
/* Customer : Barry                                                             */
/*                                                                              */
/* Modifications log:                                                           */
/*                                                                              */
/* Date       Rev    Author     Purposes                                        */
/* 2024-07-20 1.0    Bruce      UWP-21099 Created                               */
/* 2024-12-03 1.1.0  Bruce      UWP-21099 Created                               */
/********************************************************************************/

CREATE    PROC [RDT].[rdt_593InvStatus01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- BatchNo
   @cParam2    NVARCHAR(20),  -- PalletID
   @cParam3    NVARCHAR(20),
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success      INT
   DECLARE @n_Err          INT
   DECLARE @c_ErrMsg       NVARCHAR(250)
   DECLARE @c_Code2        NVARCHAR(30)

   DECLARE @cBatchNo               NVARCHAR(20)
   DECLARE @cPalletID              NVARCHAR(20)
   DECLARE @cStatus                NVARCHAR(10)
   DECLARE @cID                    NVARCHAR(20)
   DECLARE @c_adjustmentkey        NVARCHAR(10)
   DECLARE @c_facility             NVARCHAR(5)
   DECLARE @c_type                 NVARCHAR(2)
   DECLARE @cSku                   NVARCHAR(20)
   DECLARE @cLoc                   NVARCHAR(10)
   DECLARE @cLot                   NVARCHAR(10)
   DECLARE @cPackkey               NVARCHAR(10)
   DECLARE @nQty                   INT
   DECLARE @c_adjustmentlineNumber NVARCHAR(5) 
   DECLARE @cHoldStatus            NVARCHAR(10)

   DECLARE @c_Lottable01 NVARCHAR(18)
   DECLARE @c_Lottable02 NVARCHAR(18)
   DECLARE @c_Lottable03 NVARCHAR(18)
   DECLARE @d_Lottable04 DATETIME
   DECLARE @d_Lottable05 DATETIME
   DECLARE @c_Lottable06 NVARCHAR(30)
   DECLARE @c_Lottable07 NVARCHAR(30)
   DECLARE @c_Lottable08 NVARCHAR(30)
   DECLARE @c_Lottable09 NVARCHAR(30)
   DECLARE @c_Lottable10 NVARCHAR(30)
   DECLARE @c_Lottable11 NVARCHAR(30)
   DECLARE @c_Lottable12 NVARCHAR(30)
   DECLARE @d_Lottable13 DATETIME
   DECLARE @d_Lottable14 DATETIME
   DECLARE @d_Lottable15 DATETIME

   -- Parameter mapping
   SET @cBatchNo  = @cParam1
   SET @cPalletID = @cParam2
   SET @c_adjustmentkey = ''

   SELECT @c_Code2 = code2 
   FROM dbo.CODELKUP WITH(NOLOCK) 
   WHERE Storerkey = @cStorerKey
      AND LISTNAME = 'RDTLBLRPT'
      AND code = @cOption

   IF @cBatchNo = ''
   BEGIN
      SET @nErrNo = 219851                                                 --Need BatchNo
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit      
   END


   IF NOT EXISTS (SELECT 1 
                  FROM dbo.LOTxLOCxID inv WITH(NOLOCK) 
                  INNER JOIN dbo.LOTATTRIBUTE lot WITH(NOLOCK) ON inv.Lot = lot.Lot AND inv.StorerKey  = lot.StorerKey AND inv.Sku = lot.Sku
                  WHERE inv.StorerKey  = @cStorerKey 
                     AND lot.Lottable01 = @cBatchNo
                     AND inv.Qty > 0)
   BEGIN
      SET @nErrNo = 219852                                                --Batch# Invalid
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit   
   END

   IF @cPalletID != ''
   AND NOT EXISTS (SELECT 1
                  FROM dbo.LOTxLOCxID inv WITH(NOLOCK) 
                  INNER JOIN dbo.LOTATTRIBUTE lot WITH(NOLOCK) ON inv.Lot = lot.Lot AND inv.StorerKey  = lot.StorerKey AND inv.Sku = lot.Sku
                  INNER JOIN dbo.ID WITH(NOLOCK) ON inv.Id = ID.Id
                  WHERE inv.StorerKey  = @cStorerKey 
                     AND lot.Lottable01 = @cBatchNo
                     AND Id.Id = @cPalletID
                     AND inv.Qty > 0
                  )
   BEGIN
      SET @nErrNo = 219853                                                --ID Invalid
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit   
   END

   IF EXISTS(SELECT 1 
            FROM dbo.LOTxLOCxID inv WITH(NOLOCK) 
            INNER JOIN dbo.LOTATTRIBUTE lot WITH(NOLOCK) ON inv.Lot = lot.Lot AND inv.StorerKey  = lot.StorerKey AND inv.Sku = lot.Sku
            WHERE inv.StorerKey  = @cStorerKey 
               AND lot.Lottable01 = @cBatchNo
               AND inv.QtyAllocated > 0
             )
   BEGIN
      SET @nErrNo = 219854                                                --Batch# Allocated
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit            
   END

   IF EXISTS(SELECT 1 
            FROM dbo.LOTxLOCxID inv WITH(NOLOCK) 
            INNER JOIN dbo.LOTATTRIBUTE lot WITH(NOLOCK) ON inv.Lot = lot.Lot AND inv.StorerKey  = lot.StorerKey AND inv.Sku = lot.Sku
            WHERE inv.StorerKey  = @cStorerKey 
               AND lot.Lottable01 = @cBatchNo
               AND inv.QtyPicked > 0
             )
   BEGIN
      SET @nErrNo = 219855                                                --Batch# Picked
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit            
   END

   IF EXISTS(SELECT  1
            FROM dbo.LOTxLOCxID inv WITH(NOLOCK)
            INNER JOIN dbo.LOT lot WITH(NOLOCK) ON inv.Lot = lot.Lot AND inv.StorerKey = lot.StorerKey AND inv.Sku = lot.Sku
            INNER JOIN dbo.LOTATTRIBUTE attr WITH(NOLOCK) ON inv.Lot = attr.Lot AND inv.StorerKey  = attr.StorerKey AND inv.Sku = attr.Sku
            WHERE inv.StorerKey  = @cStorerKey
               AND attr.Lottable01 = @cBatchNo
               AND lot.Qty > 0
               AND lot.Status = 'HOLD'
            )
   BEGIN
      SET @nErrNo = 219856                                                --InvHoldByLot
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
      GOTO Quit            
   END

   -- Release Inventory(QI Pass) --
   IF @c_Code2 = 'UNRESTRICTED'
   BEGIN
     IF @cPalletID != ''
     BEGIN
        SELECT @cStatus      = ID.Status,
               @c_facility   = LOC.Facility,
               @cSku         = inv.Sku,
               @cLoc         = inv.Loc,
               @cLot         = inv.Lot,
               @cPackkey     = ID.Packkey,
               @nQty         = inv.Qty,
               @c_Lottable01 = attr.Lottable01,
               @c_Lottable02 = attr.Lottable02,
               @c_Lottable03 = attr.Lottable03,
               @d_Lottable04 = attr.Lottable04,
               @d_Lottable05 = attr.Lottable05,
               @c_Lottable06 = attr.Lottable06,
               @c_Lottable07 = attr.Lottable07,
               @c_Lottable08 = attr.Lottable08,
               @c_Lottable09 = attr.Lottable09,
               @c_Lottable10 = attr.Lottable10,
               @c_Lottable11 = attr.Lottable11,
               @c_Lottable12 = attr.Lottable12,
               @d_Lottable13 = attr.Lottable13,
               @d_Lottable14 = attr.Lottable14,
               @d_Lottable15 = attr.Lottable15
          FROM dbo.ID WITH(NOLOCK) 
          INNER JOIN dbo.LOTxLOCxID  inv WITH(NOLOCK) ON ID.Id = INV.Id
          INNER JOIN dbo.LOC WITH(NOLOCK) ON inv.Loc = Loc.Loc
          INNER JOIN dbo.LOTATTRIBUTE attr WITH(NOLOCK) ON inv.Lot = attr.Lot and inv.StorerKey = attr.StorerKey and inv.Sku = attr.Sku
          WHERE ID.Id = @cPalletID
            AND attr.Lottable01 = @cBatchNo
            AND inv.Qty > 0

         IF @cStatus = 'OK' AND @c_Lottable11 ='UU'
         BEGIN
           SET @nErrNo = 219857                                                --already available
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
           GOTO Quit   
         END

         IF @cStatus != 'OK'
         BEGIN
               SELECT TOP 1 @cHoldStatus = Status
               FROM dbo.INVENTORYHOLD WITH(NOLOCK)
               WHERE Id = @cPalletID
                  AND Storerkey = @cStorerKey
                  AND Hold = '1'

               EXEC nspInventoryHold
                    '',                   --lot
                    '',                   --loc
                     @cPalletID,          --id
                    @cHoldStatus,         --status
                    '0',                  --hold
                    @b_Success OUTPUT,
                    @n_Err     OUTPUT,
                    @c_ErrMsg  OUTPUT,
                    ''
               IF @n_Err <> 0
               BEGIN
                  SET @nErrNo = 219858                                                --Hold Err
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit
               END
          END

         IF @c_Lottable11 !='UU'
         BEGIN
              EXECUTE nspg_getkey
                     'Adjustment'
                   , 10
                   , @c_adjustmentkey OUTPUT
                   , @b_success OUTPUT
                   , @n_err OUTPUT
                   , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 219859                                                --nspg_GetKey
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit   
               END

               SET @nQty = -1 * @nQty

               INSERT INTO dbo.adjustment (adjustmentkey, adjustmenttype, storerkey, facility, customerrefno, remarks)
               VALUES (@c_adjustmentkey, 'HMO', @cStorerKey, @c_facility, @c_adjustmentkey, '')

               INSERT INTO dbo.ADJUSTMENTDETAIL(adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
               VALUES(@c_adjustmentkey,'00001',@cStorerKey,@cSku,@cLoc,@cLot,@cPalletID,'ADJ','EA',@cPackkey,@nQty)

               SET @nQty = -1 * @nQty
               SET @c_Lottable11 ='UU'

               INSERT INTO dbo.ADJUSTMENTDETAIL
               (adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, id, reasoncode, uom, packkey, qty,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05,Lottable06,
               Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15)
               VALUES(@c_adjustmentkey,'00002',@cStorerKey,@cSku,@cLoc,@cPalletID,'ADJ','EA',@cPackkey,@nQty,@c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@d_Lottable04,@c_Lottable06,
               @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@c_Lottable11,@c_Lottable12,@d_Lottable13,@d_Lottable14,@d_Lottable15)

               EXEC dbo.isp_FinalizeADJ
                    @c_adjustmentkey
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 219860                                                --finalize failed
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit   
               END
            END

     END

     SET @cID = ''
     IF @cPalletID = '' and @cBatchNo != ''
     BEGIN
        WHILE(1=1)
        BEGIN
            SELECT TOP 1 @cID = ID.Id,
                  @cStatus      = ID.Status,
                  @c_facility   = LOC.Facility,
                  @cSku         = inv.Sku,
                  @cLoc         = inv.Loc,
                  @cLot         = inv.Lot,
                  @cPackkey     = ID.Packkey,
                  @nQty         = inv.Qty,
                  @c_Lottable01 = attr.Lottable01,
                  @c_Lottable02 = attr.Lottable02,
                  @c_Lottable03 = attr.Lottable03,
                  @d_Lottable04 = attr.Lottable04,
                  @d_Lottable05 = attr.Lottable05,
                  @c_Lottable06 = attr.Lottable06,
                  @c_Lottable07 = attr.Lottable07,
                  @c_Lottable08 = attr.Lottable08,
                  @c_Lottable09 = attr.Lottable09,
                  @c_Lottable10 = attr.Lottable10,
                  @c_Lottable11 = attr.Lottable11,
                  @c_Lottable12 = attr.Lottable12,
                  @d_Lottable13 = attr.Lottable13,
                  @d_Lottable14 = attr.Lottable14,
                  @d_Lottable15 = attr.Lottable15
            FROM dbo.LOTATTRIBUTE lot WITH(NOLOCK)
            INNER JOIN dbo.LOTxLOCxID inv  WITH(NOLOCK) ON lot.Lot = inv.Lot
            INNER JOIN dbo.ID  WITH(NOLOCK) ON inv.Id = Id.Id
            INNER JOIN dbo.LOC  WITH(NOLOCK) ON inv.loc = loc.loc
            INNER JOIN dbo.LOTATTRIBUTE attr  WITH(NOLOCK) ON inv.Lot = attr.Lot and inv.StorerKey = attr.StorerKey and inv.Sku = attr.Sku
            WHERE lot.StorerKey = @cStorerKey
               AND lot.Lottable01 = @cBatchNo
               AND inv.Qty > 0
               AND ID.Id > @cID
            ORDER BY ID.Id

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            IF @cStatus = 'OK' AND @c_Lottable11 = 'UU'
            BEGIN
               CONTINUE
            END

            IF @cStatus != 'OK' 
            BEGIN
               SELECT TOP 1 @cHoldStatus = Status
               FROM dbo.INVENTORYHOLD WITH(NOLOCK)
               WHERE Id = @cID
                  AND Storerkey = @cStorerKey
                  AND Hold = '1'

               EXEC nspInventoryHold
                  '',                   --lot
                  '',                   --loc
                  @cID,                 --id
                  @cHoldStatus,         --status
                  '0',                  --hold
                  @b_Success OUTPUT,
                  @n_Err     OUTPUT,
                  @c_ErrMsg  OUTPUT,
                       ''
               IF @n_Err <> 0
               BEGIN
                  SET @nErrNo = 219861                                                --Hold Err
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit   
               END
            END

            IF @c_Lottable11 != 'UU'
            BEGIN
               IF @c_adjustmentkey = ''
               BEGIN
                  EXECUTE nspg_getkey
                  'Adjustment'
                  , 10
                  , @c_adjustmentkey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SET @nErrNo = 219862                                                --nspg_GetKey
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                     GOTO Quit   
                  END

                  INSERT INTO dbo.adjustment (adjustmentkey, adjustmenttype, storerkey, facility, customerrefno, remarks)
                  VALUES (@c_adjustmentkey, 'HMO', @cStorerKey, @c_facility, @c_adjustmentkey, '')
               END

               SELECT @nQty = -1 * @nQty

               SELECT @c_adjustmentlineNumber = FORMAT(COUNT(AdjustmentLineNumber)+1,'00000')
               FROM dbo.ADJUSTMENTDETAIL WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND AdjustmentKey = @c_adjustmentkey


               INSERT INTO dbo.ADJUSTMENTDETAIL(adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
               VALUES(@c_adjustmentkey,@c_adjustmentlineNumber,@cStorerKey,@cSku,@cLoc,@cLot,@cID,'ADJ','EA',@cPackkey,@nQty)

               SELECT @nQty = -1 * @nQty
               SELECT @c_Lottable11 ='UU'

               SELECT @c_adjustmentlineNumber = FORMAT(COUNT(AdjustmentLineNumber)+1,'00000')
               FROM dbo.ADJUSTMENTDETAIL WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND AdjustmentKey = @c_adjustmentkey

               INSERT INTO dbo.ADJUSTMENTDETAIL
               (adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, id, reasoncode, uom, packkey, qty,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05,Lottable06,
               Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15)
               VALUES(@c_adjustmentkey,@c_adjustmentlineNumber,@cStorerKey,@cSku,@cLoc,@cID,'ADJ','EA',@cPackkey,@nQty,@c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@d_Lottable04,@c_Lottable06,
               @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@c_Lottable11,@c_Lottable12,@d_Lottable13,@d_Lottable14,@d_Lottable15)
            END 

            IF @c_adjustmentkey <> ''
            BEGIN
                  EXEC dbo.isp_FinalizeADJ
                     @c_adjustmentkey
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SET @nErrNo = 219863                                                --finalize failed
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit   
                  END
            END
         END
      END
   END
   
   -- Block Inventory(QI Failed) --
   IF @c_Code2 = 'BLOCKED'
   BEGIN
     IF @cPalletID != ''
     BEGIN
         SELECT @cStatus      = ID.Status,
               @c_facility   = LOC.Facility,
               @cSku         = inv.Sku,
               @cLoc         = inv.Loc,
               @cLot         = inv.Lot,
               @cPackkey     = ID.Packkey,
               @nQty         = inv.Qty,
               @c_Lottable01 = attr.Lottable01,
               @c_Lottable02 = attr.Lottable02,
               @c_Lottable03 = attr.Lottable03,
               @d_Lottable04 = attr.Lottable04,
               @d_Lottable05 = attr.Lottable05,
               @c_Lottable06 = attr.Lottable06,
               @c_Lottable07 = attr.Lottable07,
               @c_Lottable08 = attr.Lottable08,
               @c_Lottable09 = attr.Lottable09,
               @c_Lottable10 = attr.Lottable10,
               @c_Lottable11 = attr.Lottable11,
               @c_Lottable12 = attr.Lottable12,
               @d_Lottable13 = attr.Lottable13,
               @d_Lottable14 = attr.Lottable14,
               @d_Lottable15 = attr.Lottable15
         FROM ID WITH(NOLOCK) 
         INNER JOIN LOTxLOCxID  inv WITH(NOLOCK) ON ID.Id = INV.Id
         INNER JOIN LOC WITH(NOLOCK) ON inv.Loc = Loc.Loc
         INNER JOIN LOTATTRIBUTE attr WITH(NOLOCK) ON inv.Lot = attr.Lot and inv.StorerKey = attr.StorerKey and inv.Sku = attr.Sku
         WHERE ID.Id = @cPalletID
            AND attr.Lottable01 = @cBatchNo
            AND inv.Qty > 0

         IF @cStatus = 'HOLD' AND @c_Lottable11 ='Block'
         BEGIN
            SET @nErrNo = 219864                                                --already Block
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
            GOTO Quit   
         END
         
         IF @cStatus = 'OK'
         BEGIN
            EXEC nspInventoryHold
                '',                   --lot
                '',                   --loc
                 @cPalletID,          --id
                'failed QI',          --status
                '1',                  --hold
                @b_Success OUTPUT,
                @n_Err     OUTPUT,
                @c_ErrMsg  OUTPUT,
                ''
            IF @n_Err <> 0
            BEGIN
               SET @nErrNo = 219865                                                --Hold Err
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
               GOTO Quit   
            END
         END

         IF @c_Lottable11 !='Block'
         BEGIN
            EXECUTE nspg_getkey
            'Adjustment'
            , 10
            , @c_adjustmentkey OUTPUT
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SET @nErrNo = 219866                                                --nspg_GetKey
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
               GOTO Quit   
            END

            SET @nQty = -1 * @nQty

            INSERT INTO adjustment (adjustmentkey, adjustmenttype, storerkey, facility, customerrefno, remarks)
            VALUES (@c_adjustmentkey, 'HMO', @cStorerKey, @c_facility, @c_adjustmentkey, '')

            INSERT INTO ADJUSTMENTDETAIL(adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
            VALUES(@c_adjustmentkey,'00001',@cStorerKey,@cSku,@cLoc,@cLot,@cPalletID,'ADJ','EA',@cPackkey,@nQty)

            SET @nQty = -1 * @nQty
            SET @c_Lottable11 ='Block'

            INSERT INTO ADJUSTMENTDETAIL
            (adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, id, reasoncode, uom, packkey, qty,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05,Lottable06,
            Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15)
            VALUES(@c_adjustmentkey,'00002',@cStorerKey,@cSku,@cLoc,@cPalletID,'ADJ','EA',@cPackkey,@nQty,@c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@d_Lottable04,@c_Lottable06,
            @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@c_Lottable11,@c_Lottable12,@d_Lottable13,@d_Lottable14,@d_Lottable15)


            EXEC dbo.isp_FinalizeADJ
            @c_adjustmentkey
            , @b_success OUTPUT
            , @n_err OUTPUT
            , @c_errmsg OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SET @nErrNo = 219867                                                --finalize failed
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
               GOTO Quit   
            END
         END
     END



      SET @cID = ''
      IF @cPalletID = '' and @cBatchNo != ''
      BEGIN
         WHILE(1=1)
         BEGIN
            SELECT TOP 1 @cID = ID.Id,
                  @cStatus      = ID.Status,
                  @c_facility   = LOC.Facility,
                  @cSku         = inv.Sku,
                  @cLoc         = inv.Loc,
                  @cLot         = inv.Lot,
                  @cPackkey     = ID.Packkey,
                  @nQty         = inv.Qty,
                  @c_Lottable01 = attr.Lottable01,
                  @c_Lottable02 = attr.Lottable02,
                  @c_Lottable03 = attr.Lottable03,
                  @d_Lottable04 = attr.Lottable04,
                  @d_Lottable05 = attr.Lottable05,
                  @c_Lottable06 = attr.Lottable06,
                  @c_Lottable07 = attr.Lottable07,
                  @c_Lottable08 = attr.Lottable08,
                  @c_Lottable09 = attr.Lottable09,
                  @c_Lottable10 = attr.Lottable10,
                  @c_Lottable11 = attr.Lottable11,
                  @c_Lottable12 = attr.Lottable12,
                  @d_Lottable13 = attr.Lottable13,
                  @d_Lottable14 = attr.Lottable14,
                  @d_Lottable15 = attr.Lottable15
            FROM dbo.LOTATTRIBUTE lot  WITH(NOLOCK)
            INNER JOIN dbo.LOTxLOCxID inv  WITH(NOLOCK) ON lot.Lot = inv.Lot
            INNER JOIN dbo.ID  WITH(NOLOCK) ON inv.Id = Id.Id
            INNER JOIN dbo.LOC  WITH(NOLOCK) ON inv.loc = loc.loc
            INNER JOIN dbo.LOTATTRIBUTE attr  WITH(NOLOCK) ON inv.Lot = attr.Lot and inv.StorerKey = attr.StorerKey and inv.Sku = attr.Sku
            WHERE lot.StorerKey = @cStorerKey
               AND lot.Lottable01 = @cBatchNo
               AND inv.Qty > 0
               AND ID.Id > @cID
            ORDER BY ID.Id

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            IF @cStatus = 'HOLD' AND @c_Lottable11 ='Block'
            BEGIN
               CONTINUE
            END

            IF @cStatus = 'OK'
            BEGIN
               EXEC nspInventoryHold
                  '',                   --lot
                  '',                   --loc
                  @cID,                 --id
                  'failed QI',          --status
                  '1',                  --hold
                  @b_Success OUTPUT,
                  @n_Err     OUTPUT,
                  @c_ErrMsg  OUTPUT,
                  ''
               IF @n_Err <> 0
               BEGIN
                  SET @nErrNo = 219868                                                --Hold Err
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit   
               END
            END

            IF @c_Lottable11 !='Block'
            BEGIN
               IF @c_adjustmentkey = ''
               BEGIN
                  EXECUTE nspg_getkey
                     'Adjustment'
                  , 10
                  , @c_adjustmentkey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SET @nErrNo = 219869                                                --nspg_GetKey
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                     GOTO Quit   
                  END

                  INSERT INTO adjustment (adjustmentkey, adjustmenttype, storerkey, facility, customerrefno, remarks)
                  VALUES (@c_adjustmentkey, 'HMO', @cStorerKey, @c_facility, @c_adjustmentkey, '')
               END

               SELECT @nQty = -1 * @nQty

               SELECT @c_adjustmentlineNumber = FORMAT(COUNT(AdjustmentLineNumber)+1,'00000')
               FROM dbo.ADJUSTMENTDETAIL WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND AdjustmentKey = @c_adjustmentkey


               INSERT INTO dbo.ADJUSTMENTDETAIL(adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
               VALUES(@c_adjustmentkey,@c_adjustmentlineNumber,@cStorerKey,@cSku,@cLoc,@cLot,@cID,'ADJ','EA',@cPackkey,@nQty)

               SELECT @nQty = -1 * @nQty
               SELECT @c_Lottable11 ='Block'

               SELECT @c_adjustmentlineNumber = FORMAT(COUNT(AdjustmentLineNumber)+1,'00000')
               FROM dbo.ADJUSTMENTDETAIL WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND AdjustmentKey = @c_adjustmentkey

               INSERT INTO dbo.ADJUSTMENTDETAIL
               (adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, id, reasoncode, uom, packkey, qty,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05,Lottable06,
               Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15)
               VALUES(@c_adjustmentkey,@c_adjustmentlineNumber,@cStorerKey,@cSku,@cLoc,@cID,'ADJ','EA',@cPackkey,@nQty,@c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@d_Lottable04,@c_Lottable06,
               @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@c_Lottable11,@c_Lottable12,@d_Lottable13,@d_Lottable14,@d_Lottable15)
            END 

            IF @c_adjustmentkey <> ''
            BEGIN
               EXEC dbo.isp_FinalizeADJ
                     @c_adjustmentkey
                     , @b_success OUTPUT
                     , @n_err OUTPUT
                     , @c_errmsg OUTPUT

               IF NOT @b_success = 1
               BEGIN
                  SET @nErrNo = 219870                                                --finalize failed
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit   
               END
            END
     END
   END
   END
   -- Restricted Inventory --
   IF @c_Code2 = 'RESTRICTED'
   BEGIN
      IF @cPalletID != ''
      BEGIN
         SELECT @cStatus      = ID.Status,
            @c_facility   = LOC.Facility,
            @cSku         = inv.Sku,
            @cLoc         = inv.Loc,
            @cLot         = inv.Lot,
            @cPackkey     = ID.Packkey,
            @nQty         = inv.Qty,
            @c_Lottable01 = attr.Lottable01,
            @c_Lottable02 = attr.Lottable02,
            @c_Lottable03 = attr.Lottable03,
            @d_Lottable04 = attr.Lottable04,
            @d_Lottable05 = attr.Lottable05,
            @c_Lottable06 = attr.Lottable06,
            @c_Lottable07 = attr.Lottable07,
            @c_Lottable08 = attr.Lottable08,
            @c_Lottable09 = attr.Lottable09,
            @c_Lottable10 = attr.Lottable10,
            @c_Lottable11 = attr.Lottable11,
            @c_Lottable12 = attr.Lottable12,
            @d_Lottable13 = attr.Lottable13,
            @d_Lottable14 = attr.Lottable14,
            @d_Lottable15 = attr.Lottable15
         FROM dbo.ID WITH(NOLOCK) 
         INNER JOIN dbo.LOTxLOCxID  inv WITH(NOLOCK) ON ID.Id = INV.Id
         INNER JOIN dbo.LOC WITH(NOLOCK) ON inv.Loc = Loc.Loc
         INNER JOIN dbo.LOTATTRIBUTE attr WITH(NOLOCK) ON inv.Lot = attr.Lot and inv.StorerKey = attr.StorerKey and inv.Sku = attr.Sku
         WHERE ID.Id = @cPalletID
            AND attr.Lottable01 = @cBatchNo
            AND inv.Qty > 0

         IF @cStatus = 'OK' AND @c_Lottable11 ='R'
         BEGIN
           SET @nErrNo = 219871                                                --already available
           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
           GOTO Quit   
         END
         
         IF @cStatus = 'HOLD'
         BEGIN
            SELECT TOP 1 @cHoldStatus = Status
            FROM dbo.INVENTORYHOLD WITH(NOLOCK)
            WHERE Id = @cPalletID
               AND Storerkey = @cStorerKey
               AND Hold = '1'

            EXEC nspInventoryHold
               '',                   --lot
               '',                   --loc
               @cPalletID,           --id
               @cHoldStatus,         --status
               '0',                  --hold
               @b_Success OUTPUT,
               @n_Err     OUTPUT,
               @c_ErrMsg  OUTPUT,
               ''
            IF @n_Err <> 0
            BEGIN
               SET @nErrNo = 219872                                                --Hold Err
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
               GOTO Quit   
            END
         END

         IF @c_Lottable11 !='R'
         BEGIN
            EXECUTE nspg_getkey
               'Adjustment'
               , 10
               , @c_adjustmentkey OUTPUT
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SET @nErrNo = 219873                                                --nspg_GetKey
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
               GOTO Quit   
            END

            SET @nQty = -1 * @nQty

            INSERT INTO dbo.adjustment (adjustmentkey, adjustmenttype, storerkey, facility, customerrefno, remarks)
            VALUES (@c_adjustmentkey, 'HMO', @cStorerKey, @c_facility, @c_adjustmentkey, '')

            INSERT INTO dbo.ADJUSTMENTDETAIL(adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
            VALUES(@c_adjustmentkey,'00001',@cStorerKey,@cSku,@cLoc,@cLot,@cPalletID,'ADJ','EA',@cPackkey,@nQty)

            SET @nQty = -1 * @nQty
            SET @c_Lottable11 ='R'

            INSERT INTO dbo.ADJUSTMENTDETAIL
            (adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, id, reasoncode, uom, packkey, qty,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05,Lottable06,
            Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15)
            VALUES(@c_adjustmentkey,'00002',@cStorerKey,@cSku,@cLoc,@cPalletID,'ADJ','EA',@cPackkey,@nQty,@c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@d_Lottable04,@c_Lottable06,
            @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@c_Lottable11,@c_Lottable12,@d_Lottable13,@d_Lottable14,@d_Lottable15)


            EXEC dbo.isp_FinalizeADJ
               @c_adjustmentkey
               , @b_success OUTPUT
               , @n_err OUTPUT
               , @c_errmsg OUTPUT

            IF NOT @b_success = 1
            BEGIN
               SET @nErrNo = 219874                                                --finalize failed
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
               GOTO Quit   
            END
         END

     END

     SET @cID = ''
     IF @cPalletID = '' and @cBatchNo != ''
     BEGIN
         WHILE(1=1)
         BEGIN
            SELECT TOP 1 @cID = ID.Id,
               @cStatus      = ID.Status,
               @c_facility   = LOC.Facility,
               @cSku         = inv.Sku,
               @cLoc         = inv.Loc,
               @cLot         = inv.Lot,
               @cPackkey     = ID.Packkey,
               @nQty         = inv.Qty,
               @c_Lottable01 = attr.Lottable01,
               @c_Lottable02 = attr.Lottable02,
               @c_Lottable03 = attr.Lottable03,
               @d_Lottable04 = attr.Lottable04,
               @d_Lottable05 = attr.Lottable05,
               @c_Lottable06 = attr.Lottable06,
               @c_Lottable07 = attr.Lottable07,
               @c_Lottable08 = attr.Lottable08,
               @c_Lottable09 = attr.Lottable09,
               @c_Lottable10 = attr.Lottable10,
               @c_Lottable11 = attr.Lottable11,
               @c_Lottable12 = attr.Lottable12,
               @d_Lottable13 = attr.Lottable13,
               @d_Lottable14 = attr.Lottable14,
               @d_Lottable15 = attr.Lottable15
            FROM dbo.LOTATTRIBUTE lot  WITH(NOLOCK)
            INNER JOIN dbo.LOTxLOCxID inv  WITH(NOLOCK) ON lot.Lot = inv.Lot
            INNER JOIN dbo.ID  WITH(NOLOCK) ON inv.Id = Id.Id
            INNER JOIN dbo.LOC  WITH(NOLOCK) ON inv.loc = loc.loc
            INNER JOIN dbo.LOTATTRIBUTE attr  WITH(NOLOCK) ON inv.Lot = attr.Lot and inv.StorerKey = attr.StorerKey and inv.Sku = attr.Sku
            WHERE lot.StorerKey = @cStorerKey
               AND lot.Lottable01 = @cBatchNo
               AND inv.Qty > 0
               AND ID.Id > @cID
            ORDER BY ID.Id

            IF @@ROWCOUNT = 0
            BEGIN
               BREAK
            END

            IF @cStatus = 'OK' AND @c_Lottable11 ='R'
            BEGIN
               CONTINUE
            END

            IF @cStatus = 'HOLD'
            BEGIN
               SELECT TOP 1 @cHoldStatus = Status
               FROM dbo.INVENTORYHOLD WITH(NOLOCK)
               WHERE Id = @cID
                  AND Storerkey = @cStorerKey
                  AND Hold = '1'

               EXEC nspInventoryHold
                  '',                   --lot
                  '',                   --loc
                  @cID,                 --id
                  @cHoldStatus,         --status
                  '0',                  --hold
                  @b_Success OUTPUT,
                  @n_Err     OUTPUT,
                  @c_ErrMsg  OUTPUT,
                  ''
               IF @n_Err <> 0
               BEGIN
                  SET @nErrNo = 219875                                                --Hold Err
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                  GOTO Quit   
               END
            END

            IF @c_Lottable11 !='R'
            BEGIN
               IF @c_adjustmentkey = ''
               BEGIN
                  EXECUTE nspg_getkey
                     'Adjustment'
                  , 10
                  , @c_adjustmentkey OUTPUT
                  , @b_success OUTPUT
                  , @n_err OUTPUT
                  , @c_errmsg OUTPUT

                  IF NOT @b_success = 1
                  BEGIN
                     SET @nErrNo = 219876                                                --nspg_GetKey
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
                     GOTO Quit   
                  END

                  INSERT INTO dbo.adjustment (adjustmentkey, adjustmenttype, storerkey, facility, customerrefno, remarks)
                  VALUES (@c_adjustmentkey, 'HMO', @cStorerKey, @c_facility, @c_adjustmentkey, '')
               END

                SELECT @nQty = -1 * @nQty

               SELECT @c_adjustmentlineNumber = FORMAT(COUNT(AdjustmentLineNumber)+1,'00000')
               FROM dbo.ADJUSTMENTDETAIL WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND AdjustmentKey = @c_adjustmentkey


               INSERT INTO dbo.ADJUSTMENTDETAIL(adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, lot, id, reasoncode, uom, packkey, qty)
               VALUES(@c_adjustmentkey,@c_adjustmentlineNumber,@cStorerKey,@cSku,@cLoc,@cLot,@cID,'ADJ','EA',@cPackkey,@nQty)

               SELECT @nQty = -1 * @nQty
               SELECT @c_Lottable11 ='R'

               SELECT @c_adjustmentlineNumber = FORMAT(COUNT(AdjustmentLineNumber)+1,'00000')
               FROM dbo.ADJUSTMENTDETAIL WITH(NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND AdjustmentKey = @c_adjustmentkey

               INSERT INTO ADJUSTMENTDETAIL
               (adjustmentkey,AdjustmentLineNumber,storerkey, sku, loc, id, reasoncode, uom, packkey, qty,Lottable01,Lottable02,Lottable03,Lottable04,Lottable05,Lottable06,
               Lottable07,Lottable08,Lottable09,Lottable10,Lottable11,Lottable12,Lottable13,Lottable14,Lottable15)
               VALUES(@c_adjustmentkey,@c_adjustmentlineNumber,@cStorerKey,@cSku,@cLoc,@cID,'ADJ','EA',@cPackkey,@nQty,@c_Lottable01,@c_Lottable02,@c_Lottable03,@d_Lottable04,@d_Lottable04,@c_Lottable06,
               @c_Lottable07,@c_Lottable08,@c_Lottable09,@c_Lottable10,@c_Lottable11,@c_Lottable12,@d_Lottable13,@d_Lottable14,@d_Lottable15)
            END
        END

        IF @c_adjustmentkey <> ''
        BEGIN
            EXEC dbo.isp_FinalizeADJ
                 @c_adjustmentkey
                 , @b_success OUTPUT
                 , @n_err OUTPUT
                 , @c_errmsg OUTPUT

            IF NOT @b_success = 1
            BEGIN
              SET @nErrNo = 219877                                                --finalize failed
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') 
              GOTO Quit   
            END
         END
      END
   END

Quit:
END -- END SP

SET QUOTED_IDENTIFIER OFF

GO