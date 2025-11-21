SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_743ExtPASP02                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 15-Jun-2016 1.0  James    WMS2246. Created                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_743ExtPASP02] (
   @nMobile          INT,                  
   @nFunc            INT,                  
   @cLangCode        NVARCHAR( 3),         
   @cUserName        NVARCHAR( 18),        
   @cStorerKey       NVARCHAR( 15),        
   @cFacility        NVARCHAR( 5),          
   @cFromLOC         NVARCHAR( 10),        
   @cID              NVARCHAR( 18),        
   @cSuggLOC         NVARCHAR( 10) OUTPUT,  
   @cPickAndDropLOC  NVARCHAR( 10) OUTPUT,  
   @cFitCasesInAisle NVARCHAR( 1)  OUTPUT,  
   @nPABookingKey    INT           OUTPUT,  
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT  
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSKU           NVARCHAR(20)
   DECLARE @nTranCount     INT
   DECLARE @nQty           INT
   DECLARE @bDebug         INT

   SET @bDebug = 0

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_743ExtPASP02 -- For rollback or commit only our own transaction

   SELECT @cFacility = Facility ,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile
   
   DECLARE CUR_PA CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
   SELECT SKU, ISNULL( SUM( LLI.QTY - LLI.QTYAllocated - LLI.QTYPicked), 0)
   FROM LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LOC.Facility = @cFacility
   AND LLI.ID = @cID 
   AND LLI.QTY - 
      (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYAlloc', LLI.StorerKey) = '0' THEN LLI.QTYAllocated ELSE 0 END) - 
      (CASE WHEN rdt.rdtGetConfig( @nFunc, 'MoveQTYPick', LLI.StorerKey) = '0' THEN LLI.QTYPicked ELSE 0 END) > 0  
   GROUP BY SKU
   ORDER BY SKU
   OPEN CUR_PA
   FETCH NEXT FROM CUR_PA INTO @cSKU, @nQty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      -- Suggest LOC
      SET @cSuggLOC = ''

      SELECT TOP 1 @cSuggLOC = SL.LOC
      FROM dbo.SKUxLOC SL WITH (NOLOCK) 
      JOIN dbo.LOC LOC WITH (NOLOCK) ON ( SL.LOC = LOC.LOC)
      WHERE SL.StorerKey = @cStorerKey
      AND   SL.LocationType = 'PICK'
      AND   SL.SKU = @cSKU
      AND   LOC.Facility = @cFacility
         
      -- Lock suggested location
      IF @cSuggLOC <> '' 
      BEGIN
         SET @nPABookingKey = 0
         EXEC rdt.rdt_Putaway_PendingMoveIn @cUserName, 'LOCK'
            ,@cFromLOC
            ,@cID
            ,@cSuggLOC
            ,@cStorerKey
            ,@nErrNo  OUTPUT
            ,@cErrMsg OUTPUT
            ,@cSKU
            ,@nPABookingKey = @nPABookingKey OUTPUT

         IF @nErrNo <> 0
            GOTO RollBackTran
         
      END
      ELSE
      BEGIN  
         SET @nErrNo = 111151
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Home Loc'  
         GOTO RollBackTran
      END  

      FETCH NEXT FROM CUR_PA INTO @cSKU, @nQty
   END
   CLOSE CUR_PA
   DEALLOCATE CUR_PA
   
   GOTO Quit  
  
   ROLLBACKTRAN:  
      ROLLBACK TRAN rdt_743ExtPASP02  
  
   QUIT:  
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
         COMMIT TRAN

END

GO