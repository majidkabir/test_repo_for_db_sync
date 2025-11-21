SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_534Confirm01                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2018-03-07 1.0  ChewKP     WMS-4190. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_534Confirm01] (
     @nMobile    INT,                   
     @nFunc      INT,                   
     @cLangCode  NVARCHAR( 3),          
     @nStep      INT,                   
     @cStorerKey NVARCHAR( 15),         
     @cToID      NVARCHAR( 18),         
     @cToLOC     NVARCHAR( 10),         
     @nErrNo     INT       OUTPUT,      
     @cErrMsg    NVARCHAR( 20) OUTPUT   
)
AS
BEGIN      
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cFacility NVARCHAR( 5)
   DECLARE @cFromLOT  NVARCHAR( 10)
   DECLARE @cFromID   NVARCHAR( 18)
   DECLARE @cSKU      NVARCHAR( 20)
   DECLARE @cUCC      NVARCHAR( 20) 
   DECLARE @nQTY      INT
   DECLARE @curLLI    CURSOR
   DECLARE @cFromLOC NVARCHAR( 10)
   

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_534Confirm01

   IF @nFunc = 534
   BEGIN
      
      -- Loop rdtMoveToIDLog
      DECLARE @curMoveToIDLog CURSOR
      SET @curMoveToIDLog = CURSOR FOR 
      SELECT FromLOT, FromLOC, FromID, SKU, QTY, UCC
      FROM rdt.rdtMoveToIDLog WITH (NOLOCK) 
      WHERE StorerKey = @cStorerKey
         AND ToID = @cToID
      OPEN @curMoveToIDLog
      FETCH NEXT FROM @curMoveToIDLog INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC
      WHILE @@FETCH_STATUS = 0
      BEGIN
         

         -- Get facility
         --IF @cFacility = ''
         SELECT @cFacility = Facility FROM dbo.LOC WITH (NOLOCK) WHERE LOC = @cFromLOC
         
         

         -- Reduce LOTxLOCxID.QTYReplen
         UPDATE dbo.LOTxLOCxID SET 
            QTYReplen = CASE WHEN QTYReplen - @nQTY >= 0 THEN QTYReplen - @nQTY ELSE 0 END
         WHERE LOT = @cFromLOT
            AND LOC = @cFromLOC
            AND ID = @cFromID
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 120651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD LLI Fail
            GOTO RollBackTran
         END

         --IF ISNULL(@cUCC,'') = '' 
         ---BEGIN
            
            -- Move
            EXECUTE rdt.rdt_Move
               @nMobile     = @nMobile,
               @cLangCode   = @cLangCode, 
               @nErrNo      = @nErrNo  OUTPUT,
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
               @cSourceType = 'rdt_534Confirm01', 
               @cStorerKey  = @cStorerKey,
               @cFacility   = @cFacility, 
               @cFromLOC    = @cFromLOC, 
               @cToLOC      = @cToLOC, 
               @cFromID     = @cFromID,     -- NULL means not filter by ID. Blank is a valid ID
               @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
               @cFromLOT    = @cFromLOT, 
               @cSKU        = @cSKU, 
               @nQTY        = @nQTY
         --END
         --ELSE
         --BEGIN
         

         --   EXEC RDT.rdt_Move
         --      @nMobile     = @nMobile,
         --      @cLangCode   = @cLangCode, 
         --      @nErrNo      = @nErrNo  OUTPUT,
         --      @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 char max
         --      @cSourceType = 'rdt_534Confirm01', 
         --      @cStorerKey  = @cStorerKey,
         --      @cFacility   = @cFacility, 
         --      @cFromLOC    = @cFromLOC, 
         --      @cToLOC      = @cToLOC, 
         --      @cFromID     = @cFromID,
         --      @cToID       = @cToID,       -- NULL means not changing ID. Blank consider a valid ID
         --      @cSKU        = NULL, 
         --      @cUCC        = @cUCC,
         --      @nFunc       = @nFunc -- (ChewKP02)  
         --END

         IF ISNULL(@cUCC,'') <> '' 
         BEGIN
            UPDATE dbo.UCC WITH (ROWLOCK) 
            SET ID = @cToID
               ,Loc = @cToLoc
            WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCC 

            IF @@ERROR <> 0 
            BEGIN
               SET @nErrNo = 120653
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdUCCFail
               GOTO RollBackTran
            END

         END
         
         IF @nErrNo <> 0
            GOTO RollBackTran
         
         FETCH NEXT FROM @curMoveToIDLog INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY, @cUCC
      END

      -- Delete log
      DELETE rdt.rdtMoveToIDLog
      WHERE StorerKey = @cStorerKey
         AND ToID = @cToID
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 120652
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DEL Log Fail
         GOTO RollBackTran
      END
      
   END
   
     
   GOTO Quit

RollBackTran:
      ROLLBACK TRAN rdt_534Confirm01
Quit:         
   WHILE @@TRANCOUNT > @nTranCount
      COMMIT TRAN rdt_534Confirm01   

END
      

GO