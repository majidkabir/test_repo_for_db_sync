SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Replenish_V7_GetNextTask                        */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 25-03-2018 1.0  James       WMS-8254 Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_Replenish_V7_GetNextTask] (
    @nMobile            INT
   ,@nFunc              INT
   ,@cLangCode          NVARCHAR( 3)
   ,@nStep              INT
   ,@nInputKey          INT
   ,@cFacility          NVARCHAR( 5)
   ,@cStorerKey         NVARCHAR( 15)
   ,@cReplenBySKUQTY    NVARCHAR( 1)
   ,@cDisplayQtyAvail   NVARCHAR( 1)
   ,@cFromLOC           NVARCHAR( 20)
   ,@cFromID            NVARCHAR( 20)
   ,@cReplenKey         NVARCHAR( 20) OUTPUT
   ,@cSKU               NVARCHAR( 20) OUTPUT
   ,@cLOT               NVARCHAR( 10) OUTPUT
   ,@cLottableCode      NVARCHAR( 30) OUTPUT
   ,@cLottable01        NVARCHAR( 18) OUTPUT
   ,@cLottable02        NVARCHAR( 18) OUTPUT  
   ,@cLottable03        NVARCHAR( 18) OUTPUT  
   ,@dLottable04        DATETIME      OUTPUT  
   ,@dLottable05        DATETIME      OUTPUT  
   ,@cLottable06        NVARCHAR( 30) OUTPUT 
   ,@cLottable07        NVARCHAR( 30) OUTPUT 
   ,@cLottable08        NVARCHAR( 30) OUTPUT 
   ,@cLottable09        NVARCHAR( 30) OUTPUT 
   ,@cLottable10        NVARCHAR( 30) OUTPUT 
   ,@cLottable11        NVARCHAR( 30) OUTPUT
   ,@cLottable12        NVARCHAR( 30) OUTPUT
   ,@dLottable13        DATETIME      OUTPUT
   ,@dLottable14        DATETIME      OUTPUT
   ,@dLottable15        DATETIME      OUTPUT
   ,@nQTY               INT           OUTPUT
   ,@cToLOC             NVARCHAR( 10) OUTPUT
   ,@nErrNo             INT           OUTPUT
   ,@cErrMsg            NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   -- Get next replenish task
   SELECT TOP 1
      @cReplenKey = ReplenishmentKey,
      @cSKU = SKU,
      @cLOT = LOT,
      @nQTY = QTY,
      @cToLOC = ToLOC
   FROM dbo.Replenishment WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND FromLoc = @cFromLOC
      AND ID = @cFromID
      AND Confirmed = 'N'
      AND (@cSKU = '' OR SKU = @cSKU)
      AND ReplenishmentKey > @cReplenKey
   ORDER BY ReplenishmentKey

   -- Check no tasks
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 141501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      GOTO Quit
   END

   SELECT @cLottableCode = LottableCode
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cSKU

   -- Replen by SKU and QTY
   IF @cReplenBySKUQTY = '1'
      SELECT @nQTY = ISNULL( SUM( QTY), 0)
      FROM dbo.Replenishment WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND FromLoc = @cFromLOC
         AND ID = @cFromID
         AND SKU = @cSKU
         AND Confirmed = 'N'
         AND ToLOC = @cToLOC

   -- Make sure replen QTY not more than avail QTY
   IF @cDisplayQtyAvail = '1'
   BEGIN
      DECLARE @nAVL_QTY INT
      SET @nAVL_QTY = 0
      SELECT @nAVL_QTY = ISNULL( SUM( QTY - QTYAllocated - QTYPicked), 0)
      FROM dbo.LOTxLOCxID WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOC = @cFromLOC
         AND ID = @cFromID
         AND (@cReplenBySKUQTY = '1' OR LOT = @cLOT)

      IF @nQTY > @nAVL_QTY
         SET @nQTY = @nAVL_QTY
   END

   -- Get lottables
   IF @cReplenBySKUQTY = '1'
      SELECT
         @cReplenKey  = '',
         @cLOT        = '',
         @cLottable01 = '',
         @cLottable02 = '',
         @cLottable03 = '',
         @dLottable04 = NULL,
         @dLottable05 = NULL,
         @cLottable06 = '',
         @cLottable07 = '',
         @cLottable08 = '',
         @cLottable09 = '',
         @cLottable10 = '',
         @cLottable11 = '',
         @cLottable12 = '',
         @dLottable13 = '',
         @dLottable14 = NULL,
         @dLottable15 = NULL
   ELSE
      SELECT
         @cLottable01 = Lottable01,
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04,
         @dLottable05 = Lottable05,
         @cLottable06 = Lottable06,
         @cLottable07 = Lottable07,
         @cLottable08 = Lottable08,
         @cLottable09 = Lottable09,
         @cLottable10 = Lottable10,
         @cLottable11 = Lottable11,
         @cLottable12 = Lottable12,
         @dLottable13 = Lottable13,
         @dLottable14 = Lottable14,
         @dLottable15 = Lottable15
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOT = @cLOT
Quit:

END

GO