SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_610ExtInsCCDtl01                                */
/* Copyright      : LF logistics                                        */
/*                                                                      */
/* Purpose: Insert new ccdetail if ucc is valid but exists another loc  */
/*                                                                      */
/*                                                                      */
/* Modifications log:                                                   */
/* Date        Rev  Author      Purposes                                */
/* 2021-04-07  1.0  James       WMS-16665. Created                      */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_610ExtInsCCDtl01]
    @nMobile      INT
   ,@nFunc        INT
   ,@nStep        INT
   ,@nInputKey    INT
   ,@cLangCode    NVARCHAR( 3)
   ,@cStorer      NVARCHAR( 15)
   ,@cCCRefNo     NVARCHAR( 10) 
   ,@cCCSheetNo   NVARCHAR( 10)
   ,@nCCCountNo   INT  
   ,@cLOC         NVARCHAR( 10) 
   ,@cID          NVARCHAR( 18)
   ,@cUCC         NVARCHAR( 20) 
   ,@cCCDetailKey NVARCHAR( 10) OUTPUT
   ,@nErrNo       INT           OUTPUT 
   ,@cErrMsg      NVARCHAR( 20) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nUCCQTY INT,
           @nCountQty  INT

   DECLARE @cUserName      NVARCHAR( 18),
           @cLottable01    NVARCHAR( 18),
           @cLottable02    NVARCHAR( 18),
           @cLottable03    NVARCHAR( 18),
           @dLottable04    DATETIME,
           @dLottable05    DATETIME,
           @cSKU           NVARCHAR( 20),
           @cLot           NVARCHAR( 10)

   IF @nStep = 9 -- UCC
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         DECLARE @cur_UCC  CURSOR
         SET @cur_UCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT SKU, Lot, SUM( Qty)
         FROM dbo.UCC WITH (NOLOCK)
         WHERE Storerkey = @cStorer
         AND   UCCNo = @cUCC
         GROUP BY SKU, Lot
         OPEN @cur_UCC
         FETCH NEXT FROM @cur_UCC INTO @cSKU, @cLot, @nUCCQTY
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SELECT 
               @cLottable01 = Lottable01,
               @cLottable02 = Lottable02,
               @cLottable03 = Lottable03,
               @dLottable04 = Lottable04,
               @dLottable05 = Lottable05
            FROM dbo.LOTATTRIBUTE WITH (NOLOCK)
            WHERE Lot = @cLot
            
            -- Insert a record into CCDETAIL
            EXECUTE rdt.rdt_CycleCount_InsertCCDetail
               @cCCRefNo,
               @cCCSheetNo,
               @nCCCountNo,
               @cStorer,
               @cSKU,
               @cUCC,      
               '',         
               @cLOC,      
               @cID,       
               @nUCCQTY,
               @cLottable01,
               @cLottable02,
               @cLottable03,
               @dLottable04,
               @dLottable05,
               @cUserName,
               @cLangCode,
               @cCCDetailKey OUTPUT,
               @nErrNo       OUTPUT,
               @cErrMsg      OUTPUT   -- screen limitation, 20 char max

            IF @nErrNo <> 0
               BREAK

            FETCH NEXT FROM @cur_UCC INTO @cSKU, @cLot, @nUCCQTY
         END
      END
   END

Quit:
END

GO