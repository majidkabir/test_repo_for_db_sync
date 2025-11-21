SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_629SuggestLoc01                                       */
/* Copyright: LF Logistics                                                    */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 2021-03-15  1.0  James    WMS-16449. Created                               */
/******************************************************************************/

CREATE PROC [RDT].[rdt_629SuggestLoc01] (
   @nMobile         INT,
   @nFunc           INT,
   @cLangCode       NVARCHAR( 3),
   @nStep           INT,
   @nInputKey       INT,
   @cFacility       NVARCHAR( 5),
   @cStorerkey      NVARCHAR( 15),
   @cType           NVARCHAR( 10),
   @cFromLOC        NVARCHAR( 10),
   @cFromID         NVARCHAR( 18),
   @cSKU            NVARCHAR( 20),
   @nQty            INT,
   @cToID           NVARCHAR( 18),
   @cToLoc          NVARCHAR( 10),
   @cLottableCode   NVARCHAR( 30),
   @cLottable01     NVARCHAR( 18), 
   @cLottable02     NVARCHAR( 18), 
   @cLottable03     NVARCHAR( 18), 
   @dLottable04     DATETIME,     
   @dLottable05     DATETIME,     
   @cLottable06     NVARCHAR( 30), 
   @cLottable07     NVARCHAR( 30), 
   @cLottable08     NVARCHAR( 30), 
   @cLottable09     NVARCHAR( 30), 
   @cLottable10     NVARCHAR( 30), 
   @cLottable11     NVARCHAR( 30), 
   @cLottable12     NVARCHAR( 30), 
   @dLottable13     DATETIME,     
   @dLottable14     DATETIME,     
   @dLottable15     DATETIME,     
   @cSuggestedLOC   NVARCHAR( 10) OUTPUT,
   @nPABookingKey   INT           OUTPUT,
   @nErrNo          INT           OUTPUT,
   @cErrMsg         NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @cUserName   NVARCHAR( 18)
   
   SELECT @cUserName = @cUserName
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile
   
   SET @cSuggestedLOC = ''
   
   IF @cType = 'LOCK'
   BEGIN
      -- Find a friend (same SKU, L02) with min QTY
      SELECT TOP 1 
         @cSuggestedLOC = LOC.LOC
      FROM LOTxLOCxID LLI WITH (NOLOCK)
         JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
         JOIN LOTAttribute LA WITH (NOLOCK) ON (LLI.LOT = LA.LOT)
      WHERE LOC.Facility = @cFacility
         AND LOC.HOSTWHCODE = 'NORMAL'
         AND LLI.StorerKey = @cStorerKey
         AND LLI.SKU = @cSKU
         AND LA.Lottable02 = @cLottable02
         AND LLI.QTY-LLI.QTYPicked > 0
      ORDER BY LLI.QTY-LLI.QTYPicked 

      IF ISNULL( @cSuggestedLOC, '') = ''
      BEGIN  
         SET @nErrNo = 164901  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Suggest Loc'  
         GOTO Quit  
      END  
   END
   
   Quit:
END

GO