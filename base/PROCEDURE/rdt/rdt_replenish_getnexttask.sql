SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_Replenish_GetNextTask                           */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 21-11-2017 1.2  Ung         WMS-3426 Created                         */
/* 17-05-2018 1.3  Ung         WMS-5195 Misc fixes                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_Replenish_GetNextTask] (
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
   ,@cLottable02        NVARCHAR( 18) OUTPUT
   ,@cLottable03        NVARCHAR( 18) OUTPUT
   ,@dLottable04        DATETIME      OUTPUT
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
      SET @nErrNo = 117101
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more task
      GOTO Quit
   END

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
         @cLottable02 = '',
         @cLottable03 = '',
         @dLottable04 = NULL
   ELSE
      SELECT
         @cLottable02 = Lottable02,
         @cLottable03 = Lottable03,
         @dLottable04 = Lottable04
      FROM dbo.LotAttribute WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey
         AND SKU = @cSKU
         AND LOT = @cLOT

Quit:

END

GO