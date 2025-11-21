SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_VAP_Palletize_GetNextTask                       */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get next task for VAP Palletize.                            */
/*                                                                      */
/*                                                                      */
/* Called from: rdtfnc_VAP_Uncasing                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 09-Mar-2016 1.0  James       SOS364044 Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_VAP_Palletize_GetNextTask] (
   @nMobile             INT, 
   @nFunc               INT, 
   @cLangCode           NVARCHAR( 3),
   @nInputKey           INT, 
   @nStep               INT, 
   @cStorerKey          NVARCHAR( 15),
   @cID                 NVARCHAR( 18),
   @cJobKey             NVARCHAR( 10),
   @cWorkOrderKey       NVARCHAR( 10),
   @cSKU                NVARCHAR( 20)     OUTPUT, 
   @cLOT                NVARCHAR( 10)     OUTPUT, 
   @nQtyRemaining       INT               OUTPUT, 
   @nTtlCount           INT               OUTPUT, 
   @cLottable01         NVARCHAR( 20)     OUTPUT, 
   @cLottable02         NVARCHAR( 20)     OUTPUT, 
   @cLottable03         NVARCHAR( 20)     OUTPUT, 
   @dLottable04         DATETIME          OUTPUT, 
   @dLottable05         DATETIME          OUTPUT, 
   @cLottable06         NVARCHAR( 20)     OUTPUT, 
   @cLottable07         NVARCHAR( 20)     OUTPUT, 
   @cLottable08         NVARCHAR( 20)     OUTPUT, 
   @cLottable09         NVARCHAR( 20)     OUTPUT, 
   @cLottable10         NVARCHAR( 20)     OUTPUT, 
   @cLottable11         NVARCHAR( 20)     OUTPUT, 
   @cLottable12         NVARCHAR( 20)     OUTPUT, 
   @dLottable13         DATETIME          OUTPUT, 
   @dLottable14         DATETIME          OUTPUT, 
   @dLottable15         DATETIME          OUTPUT, 
   @nErrNo              INT               OUTPUT, 
   @cErrMsg             NVARCHAR( 20)     OUTPUT    
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 1
      BEGIN
         SELECT @nTtlCount = COUNT( 1)
         FROM dbo.WorkOrder_UnCasing U WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( U.SKU = SKU.SKU AND U.StorerKey = SKU.StorerKey)
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey
         AND   [Status] = '3'

         SELECT TOP 1 
            @cSKU = U.SKU,
            @cLottable01 = Lottable01,
            @cLottable02 = Lottable02, 	
            @cLottable03 = Lottable03, 
            @dLottable04 = Lottable04, 
            @cLottable06 = Lottable06, 
            @cLottable07 = Lottable07, 
            @cLottable08 = Lottable08, 
            @nQtyRemaining = ISNULL( SUM( Qty - QtyCompleted), 0)
         FROM dbo.WorkOrder_UnCasing U WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON ( U.SKU = SKU.SKU AND U.StorerKey = SKU.StorerKey)
         WHERE JobKey = @cJobKey
         AND   WorkOrderKey = @cWorkOrderKey
         AND   [Status] = '3'
         AND   ISNULL( Qty - QtyCompleted, 0) > 0
         GROUP BY U.SKU, Lottable01, Lottable02, Lottable03, Lottable04, Lottable06, Lottable07, Lottable08
         ORDER BY U.SKU, Lottable01, Lottable02, Lottable03, Lottable04, Lottable06, Lottable07, Lottable08

         SET @dLottable04 = rdt.rdtFormatDate( @dLottable04)
      END
   END
   
Quit:

END

GO