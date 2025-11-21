SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_639GetTask01                                          */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Purpose: Move QTY from RFPutaway                                           */
/*                                                                            */
/* Date       Rev  Author     Purposes                                        */
/* 2023-03-09 1.0  Ung        WMS-21506 Created                               */
/* 2023-04-28 1.1  Ung        WMS-21506 Add L12 inaccessible                  */
/* 2023-04-11 1.2  Ung        WMS-22105 Allow SKU to process once Printed     */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_639GetTask01] (
   @nMobile         INT, 
   @nFunc           INT, 
   @cLangCode       NVARCHAR(3), 
   @nStep           INT, 
   @nInputKey       INT, 
   @cStorerKey      NVARCHAR( 15), 
   @cFacility       NVARCHAR( 5), 
   @cType           NVARCHAR( 10), -- Blank=1st lottable, NEXT=next lottable
   @cToLOC          NVARCHAR( 10), 
   @cToID           NVARCHAR( 18), 
   @cFromLOC        NVARCHAR( 10), 
   @cFromID         NVARCHAR( 18), 
   @cUCC            NVARCHAR( 20), 
   @cSKU            NVARCHAR( 20) OUTPUT,
   @nQTY            INT           OUTPUT,
   @nTotalRec       INT           OUTPUT,
   @cLottableCode   NVARCHAR( 30) OUTPUT,
   @cLottable01     NVARCHAR( 18) OUTPUT,
   @cLottable02     NVARCHAR( 18) OUTPUT,  
   @cLottable03     NVARCHAR( 18) OUTPUT,  
   @dLottable04     DATETIME      OUTPUT,  
   @dLottable05     DATETIME      OUTPUT,  
   @cLottable06     NVARCHAR( 30) OUTPUT, 
   @cLottable07     NVARCHAR( 30) OUTPUT, 
   @cLottable08     NVARCHAR( 30) OUTPUT, 
   @cLottable09     NVARCHAR( 30) OUTPUT, 
   @cLottable10     NVARCHAR( 30) OUTPUT, 
   @cLottable11     NVARCHAR( 30) OUTPUT,
   @cLottable12     NVARCHAR( 30) OUTPUT,
   @dLottable13     DATETIME      OUTPUT,
   @dLottable14     DATETIME      OUTPUT,
   @dLottable15     DATETIME      OUTPUT,
   @tExtGetTask     VARIABLETABLE READONLY, 
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0 -- Require if calling GetTask multiple times (NEXTSKU then NEXTLOC)
   SET @cErrMsg = ''
   
   SELECT @nQTY = ISNULL( SUM( RF.QTYPrinted), 0)
   FROM dbo.RFPutaway RF WITH (NOLOCK)
      JOIN dbo.LOC WITH (NOLOCK) ON (RF.SuggestedLOC = LOC.LOC)
      JOIN dbo.LOTAttribute LA WITH (NOLOCK) ON (RF.LOT = LA.LOT)
   WHERE RF.FromLOC = @cFromLOC
      AND RF.FromID = @cFromID
      AND RF.StorerKey = @cStorerKey
      AND RF.SKU = @cSKU
      AND RF.QTYPrinted > 0
      AND LOC.LocationCategory IN ('FP','HP','FC')
      AND LA.Lottable12 <> 'inaccessible'

   SET @nTotalRec = @@ROWCOUNT

GO