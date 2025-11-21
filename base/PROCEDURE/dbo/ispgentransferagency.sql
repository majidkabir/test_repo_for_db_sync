SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispGenTransferAgency                               */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* 20-May-2014  TKLIM      1.1   Added Lottables 06-15                  */
/************************************************************************/

CREATE PROCedure [dbo].[ispGenTransferAgency]
      @c_TransferKey NVARCHAR(10)
    , @c_AgencyCode  NVARCHAR(18)
AS
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   CREATE TABLE #TD (
      TransferKey          NVARCHAR(10) NOT NULL ,
      TransferLineNumber   INT IDENTITY(1,1),
      FromStorerKey        NVARCHAR(15) NOT NULL ,
      FromSku              NVARCHAR(20) NOT NULL ,
      FromLoc              NVARCHAR(10) NOT NULL ,
      FromLot              NVARCHAR(10) NOT NULL ,
      FromId               NVARCHAR(18) NOT NULL ,
      FromQty              INT NOT NULL ,
      FromPackKey          NVARCHAR(10) NOT NULL,
      FromUOM              NVARCHAR(10) NOT NULL ,
      Lottable01           NVARCHAR(18) NOT NULL,
      Lottable02           NVARCHAR(18) NOT NULL,
      Lottable03           NVARCHAR(18) NOT NULL,
      Lottable04           DATETIME NULL,
      Lottable05           DATETIME NULL,
      Lottable06           NVARCHAR(30) NOT NULL,
      Lottable07           NVARCHAR(30) NOT NULL,
      Lottable08           NVARCHAR(30) NOT NULL,
      Lottable09           NVARCHAR(30) NOT NULL,
      Lottable10           NVARCHAR(30) NOT NULL,
      Lottable11           NVARCHAR(30) NOT NULL,
      Lottable12           NVARCHAR(30) NOT NULL,
      Lottable13           DATETIME NULL,
      Lottable14           DATETIME NULL,
      Lottable15           DATETIME NULL,
      ToStorerKey          NVARCHAR(15) NOT NULL,
      ToSku                NVARCHAR(20) NOT NULL,
      ToLoc                NVARCHAR(10) NOT NULL,
      ToLot                NVARCHAR(10) NOT NULL,
      ToId                 NVARCHAR(18) NOT NULL,
      ToQty                INT NOT NULL,
      ToPackKey            NVARCHAR(10),
      ToUOM                NVARCHAR(10),
      Status               NVARCHAR(10),
      EffectiveDate        DATETIME NOT NULL,
      ToLottable01         NVARCHAR(18) NULL,
      ToLottable02         NVARCHAR(18) NULL,
      ToLottable03         NVARCHAR(18) NULL,
      ToLottable04         DATETIME NULL,
      ToLottable05         DATETIME NULL,
      ToLottable06         NVARCHAR(30) NOT NULL,
      ToLottable07         NVARCHAR(30) NOT NULL,
      ToLottable08         NVARCHAR(30) NOT NULL,
      ToLottable09         NVARCHAR(30) NOT NULL,
      ToLottable10         NVARCHAR(30) NOT NULL,
      ToLottable11         NVARCHAR(30) NOT NULL,
      ToLottable12         NVARCHAR(30) NOT NULL,
      ToLottable13         DATETIME NULL,
      ToLottable14         DATETIME NULL,
      ToLottable15         DATETIME NULL,
   )


   INSERT INTO #TD (
      TransferKey, 
      FromStorerKey, 
      FromSku, 
      FromLoc, 
      FromLot, 
      FromId, 
      FromQty, 
      FromPackKey, 
      FromUOM, 
      Lottable01, 
      Lottable02, 
      Lottable03, 
      Lottable04, 
      Lottable05, 
      Lottable06,
      Lottable07,
      Lottable08,
      Lottable09,
      Lottable10,
      Lottable11,
      Lottable12,
      Lottable13,
      Lottable14,
      Lottable15,
      ToStorerKey, 
      ToSku, 
      ToLoc, 
      ToLot, 
      ToId, 
      ToQty, 
      ToPackKey, 
      ToUOM, 
      Status, 
      EffectiveDate, 
      ToLottable01, 
      ToLottable02, 
      ToLottable03, 
      ToLottable04, 
      ToLottable05,
      ToLottable06,
      ToLottable07,
      ToLottable08,
      ToLottable09,
      ToLottable10,
      ToLottable11,
      ToLottable12,
      ToLottable13,
      ToLottable14,
      ToLottable15
      )
   SELECT t.TransferKey, -- replace this with transfer key
      lli.StorerKey, -- from Agency
      lli.SKU,
      lli.Loc, -- from loc
      lli.Lot, -- from Lot
      lli.Id, -- from id
      (lli.Qty - lli.QtyAllocated - lli.QtyPicked ), -- from Qty 
      p.PackKey, 
      p.PACKUOM3, -- alway using lowest unit
      la.Lottable01, 
      la.Lottable02, 
      la.Lottable03, 
      la.Lottable04, 
      la.Lottable05, 
      la.Lottable06,
      la.Lottable07,
      la.Lottable08,
      la.Lottable09,
      la.Lottable10,
      la.Lottable11,
      la.Lottable12,
      la.Lottable13,
      la.Lottable14,
      la.Lottable15,
      ToStorerKey,  -- ToStorerKey
      lli.SKU,
      lli.Loc, -- to loc
      '', -- to Lot
      lli.Id, -- to id
      (lli.Qty - lli.QtyAllocated - lli.QtyPicked ), -- to Qty 
      p.PackKey, 
      p.PACKUOM3, -- alway using lowest unit
      '0', -- status
      GetDate(), -- Effective Date
      la.Lottable01, 
      la.Lottable02, 
      la.Lottable03, 
      la.Lottable04, 
      la.Lottable05,
      la.Lottable06,
      la.Lottable07,
      la.Lottable08,
      la.Lottable09,
      la.Lottable10,
      la.Lottable11,
      la.Lottable12,
      la.Lottable13,
      la.Lottable14,
      la.Lottable15
   FROM LOTxLOCxID lli (NOLOCK)
   JOIN LOTAttribute la (NOLOCK) ON (lli.LOT = la.LOT)
   JOIN SKU s (NOLOCK) ON (s.StorerKey = lli.StorerKey and s.SKU = lli.SKU)
   JOIN PACK p (NOLOCK) ON (s.PackKey = p.PackKey)
   JOIN Transfer t (NOLOCK) ON (lli.StorerKey = t.FromStorerKey)
   WHERE t.TransferKey = @c_TransferKey
   AND   lli.Qty - lli.QtyAllocated - lli.QtyPicked  > 0
   AND   S.SUSR3 = @c_AgencyCode


   INSERT INTO TRANSFERDETAIL(TransferKey, TransferLineNumber, FromStorerKey, FromSku, FromLoc, 
                              FromLot, FromId, FromQty, FromPackKey, FromUOM, 
                              Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
                              Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
                              Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, 
                              ToStorerKey, ToSku, ToLoc, ToLot, ToId, 
                              ToQty, ToPackKey, ToUOM, Status, EffectiveDate, 
                              ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05,
                              ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10,
                              ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15
                              )
   SELECT TransferKey, RIGHT( dbo.fnc_RTrim('0000' + CAST(TransferLineNumber as NVARCHAR(5))), 5), FromStorerKey, FromSku, FromLoc, 
            FromLot, FromId, FromQty, FromPackKey, FromUOM, 
            Lottable01, Lottable02, Lottable03, Lottable04, Lottable05, 
            Lottable06, Lottable07, Lottable08, Lottable09, Lottable10, 
            Lottable11, Lottable12, Lottable13, Lottable14, Lottable15, 
            ToStorerKey, ToSku, ToLoc, ToLot, ToId, 
            ToQty, ToPackKey, ToUOM, Status, EffectiveDate, 
            ToLottable01, ToLottable02, ToLottable03, ToLottable04, ToLottable05,
            ToLottable06, ToLottable07, ToLottable08, ToLottable09, ToLottable10,
            ToLottable11, ToLottable12, ToLottable13, ToLottable14, ToLottable15
   FROM #TD

GO