SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_521ExtPA18                                      */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Purpose: Customized PA logic for Levis                               */
/*                                                                      */
/* Date         Rev  Author   Purposes                                  */
/* 04-Jun-2024  1.0  Jackc    FCR-264 Created                           */
/************************************************************************/

CREATE   PROC [RDT].[rdt_521ExtPA18] (
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
   @nQty             INT,
   @cSuggestedLOC    NVARCHAR( 10) OUTPUT,
   @cPickAndDropLoc  NVARCHAR( 10) OUTPUT,
   @nPABookingKey    INT           OUTPUT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  @nTranCount INT,
            @bDebugFlag BIT = 0 

   SET @cSuggestedLOC = ''

   -- Get book loc info
   SELECT @cSuggestedLOC = SuggestedLoc
         ,@nPABookingKey = 0  -- Make 521 main do not delete pre-book data when press ESC on Step2
   FROM RFPUTAWAY WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
      AND FromLoc = @cLoc
      AND FromID = @cID
      AND CaseID = @cUCC

   IF @bDebugFlag = 1
      SELECT 'Get booking data', @cSuggestedLOC as SuggtLoc, @nPABookingKey as PABookingKey

   -- No booked loc found, then run the standard PA logic
   IF ISNULL(@cSuggestedLOC,'') = ''
   BEGIN

      IF @bDebugFlag = 1
         SELECT 'Execute standard PA logic'

      -- Suggest LOC
      EXEC @nErrNo = [dbo].[nspRDTPASTD]    
           @c_userid        = 'RDT'          -- NVARCHAR(10)    
         , @c_storerkey     = @cStorerkey    -- NVARCHAR(15)    
         , @c_lot           = ''             -- NVARCHAR(10)    
         , @c_sku           = @cSKU          -- NVARCHAR(20)    
         , @c_id            = @cID           -- NVARCHAR(18)    
         , @c_fromloc       = @cLOC          -- NVARCHAR(10)    
         , @n_qty           = @nQty          -- int    
         , @c_uom           = ''             -- NVARCHAR(10)    
         , @c_packkey       = ''             -- NVARCHAR(10) -- optional    
         , @n_putawaycapacity = 0    
         , @c_final_toloc     = @cSuggestedLOC     OUTPUT    
         , @c_PickAndDropLoc  = @cPickAndDropLoc   OUTPUT     

      IF @bDebugFlag = 1
         SELECT 'Standard PA result', @cSuggestedLOC AS SuggtLoc, @cPickAndDropLoc AS SuggtPnDLoc

      -- Check suggest loc
      IF @cSuggestedLOC = ''
      BEGIN

         IF @bDebugFlag = 1
            SELECT 'No SuggtLoc Found, return -1'

         SET @nErrNo = -1
         GOTO Quit
      END
      
      -- Handling transaction
      SET @nTranCount = @@TRANCOUNT
      
      -- Lock suggested location
      IF @cSuggestedLOC <> '' 
      BEGIN
         BEGIN TRAN  -- Begin our own transaction
         SAVE TRAN rdt_521ExtPA18 -- For rollback or commit only our own transaction
         
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cLOC
            ,@cID
            ,@cSuggestedLOC
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

         COMMIT TRAN rdt_521ExtPA18 -- Only commit change made here
      END
   END -- END suggestLoc=''
   
   GOTO Quit

   RollBackTran:
      ROLLBACK TRAN rdt_521ExtPA18 -- Only rollback change made here

   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN

         -- No loc found finally
      IF ISNULL(@cSuggestedLOC,'') = '' 
         SET @nErrNo = -1 -- No suggested LOC, and allow continue.

END --END SP

GO