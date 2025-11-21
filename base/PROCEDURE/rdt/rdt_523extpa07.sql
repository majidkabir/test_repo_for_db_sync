SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_523ExtPA07                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 05-09-2017  1.0  ChewKP   WMS-2694 Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_523ExtPA07] (
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
   
   DECLARE @nTranCount  INT
   DECLARE @cSuggToLOC  NVARCHAR( 10)
   
   SET @nTranCount = @@TRANCOUNT
   SET @cSuggToLOC = ''
   
   -- Get from SKUConfig
   DECLARE @cDPPLoc  NVARCHAR(10) 
   
   SELECT @cDPPLoc = Data
   FROM dbo.SKUConfig WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
   AND SKU = @cSKU
   AND ConfigType = 'DefaultDPP'

   --SELECT  @cSKU '@cSKU' , @cStorerKey '@cStorerKey' 
   
   IF ISNULL(@cDPPLoc,'' )  <> '' 
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.Loc WITH (NOLOCK) 
                  WHERE Loc = @cDPPLoc 
                  AND Facility = @cFacility ) 
      BEGIN
         SET @cSuggestedLOC = @cDPPLoc
      END
      ELSE
      BEGIN
         SET @nErrNo = -1
         GOTO Quit
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
      SAVE TRAN rdt_523ExtPA07 -- For rollback or commit only our own transaction
      
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

      COMMIT TRAN rdt_523ExtPA07 -- Only commit change made here
   END
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_523ExtPA07 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO