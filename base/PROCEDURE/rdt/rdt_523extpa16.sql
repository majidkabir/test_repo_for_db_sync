SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_523ExtPA16                                            */
/* Copyright      : LF Logistics                                              */  
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 02-08-2018  1.0  ChewKP   WMS-5802 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA16] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @cUserName        NVARCHAR( 18), 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5),
   @cLOC             NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCC             NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cSuggestedLOC    NVARCHAR( 10)  OUTPUT,
   @nPABookingKey    INT            OUTPUT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount INT
   DECLARE @cSuggToLOC NVARCHAR(10)
          ,@dLLILottable04    DATETIME
          ,@dLottable04       DATETIME

                   
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = '' 
   
   
   
   SELECT TOP 1 @dLLILottable04 = LA.Lottable04 
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @cStorerKey 
   AND LLI.SKU = @cSKU 
   AND LLI.Loc <> @cLoc
   AND LLI.ID  <> @cID 
   AND LLI.QTY > 0 
   ORDER BY LA.Lottable04 DESC
   
   SELECT TOP 1 @dLottable04 = LA.Lottable04 
   FROM dbo.LotxLocxID LLI WITH (NOLOCK) 
   INNER JOIN dbo.LotAttribute LA WITH (NOLOCK) ON LA.Lot = LLI.Lot AND LA.StorerKey = LLI.StorerKey 
   WHERE LLI.StorerKey = @cStorerKey 
   AND LLI.SKU = @cSKU 
   AND LLI.Loc = @cLoc
   AND LLI.ID  = @cID 
   AND LLI.QTY > 0 
   ORDER BY LA.Lottable04 DESC
   
   IF @dLLILottable04 > @dLottable04
   BEGIN
      SELECT @cSuggToLoc = Loc 
      FROM dbo.SKUxLOC WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
      AND SKU = @cSKU 
      AND LocationType = 'PICK'
      
      IF ISNULL(@cSuggToLoc,'')  = '' 
      BEGIN
         -- Suggest LOC
         EXEC @nErrNo = [dbo].[nspRDTPASTD]
              @c_userid          = 'RDT'
            , @c_storerkey       = @cStorerKey
            , @c_lot             = @cLOT
            , @c_sku             = @cSKU
            , @c_id              = @cID
            , @c_fromloc         = @cLOC
            , @n_qty             = @nQTY
            , @c_uom             = '' -- not used
            , @c_packkey         = '' -- optional, if pass-in SKU
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggestedLOC OUTPUT

         -- Check suggest loc
         IF @cSuggestedLOC = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
      END
      
      
   END
   ELSE
   BEGIN
       -- Suggest LOC
         EXEC @nErrNo = [dbo].[nspRDTPASTD]
              @c_userid          = 'RDT'
            , @c_storerkey       = @cStorerKey
            , @c_lot             = @cLOT
            , @c_sku             = @cSKU
            , @c_id              = @cID
            , @c_fromloc         = @cLOC
            , @n_qty             = @nQTY
            , @c_uom             = '' -- not used
            , @c_packkey         = '' -- optional, if pass-in SKU
            , @n_putawaycapacity = 0
            , @c_final_toloc     = @cSuggestedLOC OUTPUT

         -- Check suggest loc
         IF @cSuggestedLOC = ''
         BEGIN
            SET @nErrNo = -1
            GOTO Quit
         END
   END
   
   
   /*-------------------------------------------------------------------------------
                                 Book suggested location
   -------------------------------------------------------------------------------*/
   IF @cSuggToLOC <> ''
   BEGIN
      -- Handling transaction
      BEGIN TRAN  -- Begin our own transaction
      SAVE TRAN rdt_523ExtPA16 -- For rollback or commit only our own transaction
      
      EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
         ,@cLOC
         ,@cID
         ,@cSuggToLOC
         ,@cStorerKey
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@cSKU          = @cSKU
         ,@nPutawayQTY   = @nQTY
         ,@cFromLOT      = @cLOT
         ,@cUCCNo        = @cUCC
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0
         GOTO RollBackTran

      SET @cSuggestedLOC = @cSuggToLOC

      COMMIT TRAN rdt_523ExtPA16 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA16 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO