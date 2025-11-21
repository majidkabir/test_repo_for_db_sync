SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_UCCPutaway_Confirm                                    */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date        Rev  Author   Purposes                                         */
/* 27-03-2020  1.0  Ung      WMS-12634 Created                                */
/******************************************************************************/

CREATE PROC [RDT].[rdt_UCCPutaway_Confirm] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT,
   @cStorerKey       NVARCHAR( 15),
   @cFacility        NVARCHAR( 5),
   @cFromLOC         NVARCHAR( 10),
   @cID              NVARCHAR( 18),
   @cLOT             NVARCHAR( 10),
   @cUCCNo           NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQTY             INT,
   @cToLOC           NVARCHAR( 10),
   @cSuggestedLOC    NVARCHAR( 10),
   @cPickAndDropLoc  NVARCHAR( 10),
   @nPABookingKey    INT,
   @nErrNo           INT            OUTPUT,
   @cErrMsg          NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @nTranCount  INT
   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   
   SET @nTranCount = @@TRANCOUNT
   
   -- Get extended putaway
   DECLARE @cConfirmSP NVARCHAR(20)
   SET @cConfirmSP = rdt.rdtGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''  

   /***********************************************************************************************
                                             Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cID, @cLOT, @cUCCNo, @cSKU, @nQTY, @cToLOC, ' + 
            ' @cSuggestedLOC, @cPickAndDropLoc, @nPABookingKey, @nErrNo OUTPUT, @cErrMsg OUTPUT'
         SET @cSQLParam =
            '@nMobile          INT,             ' +
            '@nFunc            INT,             ' +
            '@cLangCode        NVARCHAR( 3),    ' +
            '@nStep            INT,             ' +
            '@nInputKey        INT,             ' +
            '@cStorerKey       NVARCHAR( 15),   ' +
            '@cFacility        NVARCHAR( 5),    ' + 
            '@cFromLOC         NVARCHAR( 10),   ' +
            '@cID              NVARCHAR( 18),   ' +
            '@cLOT             NVARCHAR( 10),   ' +
            '@cUCCNo           NVARCHAR( 20),   ' + 
            '@cSKU             NVARCHAR( 20),   ' +
            '@nQTY             INT,             ' +
            '@cToLOC           NVARCHAR( 10),   ' +
            '@cSuggestedLOC    NVARCHAR( 10),   ' + 
            '@cPickAndDropLoc  NVARCHAR( 10),   ' + 
            '@nPABookingKey    INT,             ' + 
            '@nErrNo           INT           OUTPUT, ' +
            '@cErrMsg          NVARCHAR( 20) OUTPUT  '

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cStorerKey, @cFacility, @cFromLOC, @cID, @cLOT, @cUCCNo, @cSKU, @nQTY, @cToLOC, 
            @cSuggestedLOC, @cPickAndDropLoc, @nPABookingKey, @nErrNo OUTPUT, @cErrMsg OUTPUT

            GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard confirm
   ***********************************************************************************************/
   DECLARE @cUserName NVARCHAR( 10) = SUSER_SNAME()

   -- Get UCC info
   DECLARE @nSKUCnt INT
   SELECT @nSKUCnt = COUNT( DISTINCT SKU)
   FROM dbo.UCC WITH (NOLOCK) 
   WHERE StorerKey = @cStorerKey
      AND UCCNo = @cUCCNo
      AND [Status] = '1'

   -- Handling transaction
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdtfnc_UCCPutaway -- For rollback or commit only our own transaction 

   -- Single SKU UCC
   IF @nSKUCnt = 1
   BEGIN
      -- Execute putaway process  
      EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,  
         @cLOT, 
         @cFromLOC,  
         @cID,  
         @cStorerKey,  
         @cSKU,  
         @nQTY,  
         @cToLOC,  
         '',      --@cLabelType OUTPUT, -- optional  
         @cUCCNo, -- optional  --(cc01- for event log)
         @nErrNo     OUTPUT,  
         @cErrMsg    OUTPUT  
      IF @nErrNo <> 0
         GOTO RollBackTran
   END
   
   -- Multi SKU UCC
   ELSE
   BEGIN
      DECLARE @cUCC_SKU NVARCHAR(20)
      DECLARE @cUCC_LOT NVARCHAR(10)
      DECLARE @nUCC_QTY INT
      DECLARE @curUCC   CURSOR

      SET @curUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
         SELECT SKU, QTY, LOT
         FROM dbo.UCC WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
            AND UCCNo = @cUCCNo
            AND [Status] = '1'
      OPEN @curUCC
      FETCH NEXT FROM @curUCC INTO @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
      WHILE @@FETCH_STATUS = 0
      BEGIN
         -- Execute putaway process  
         EXEC rdt.rdt_Putaway @nMobile, @nFunc, @cLangCode, @cUserName, @cFacility,  
            @cUCC_LOT,  
            @cFromLOC,  
            @cID,  
            @cStorerKey,  
            @cUCC_SKU,  
            @nUCC_QTY,  
            @cToLOC,  
            '',      --@cLabelType OUTPUT, -- optional  
            @cUCCNo, -- optional  --(cc01--for Eventlog)
            @nErrNo     OUTPUT,  
            @cErrMsg    OUTPUT  

         IF @nErrNo <> 0
            GOTO RollBackTran
         
         FETCH NEXT FROM @curUCC INTO @cUCC_SKU, @nUCC_QTY, @cUCC_LOT
      END
   END

   -- Get LOC info  
   DECLARE @cLoseID  NVARCHAR( 1)
   DECLARE @cLoseUCC NVARCHAR( 1)
   SELECT   
      @cLoseID = LoseID,   
      @cLoseUCC = LoseUCC  
   FROM LOC WITH (NOLOCK)   
   WHERE LOC = @cToLOC  

   -- Update UCC
   UPDATE dbo.UCC WITH (ROWLOCK) SET 
      ID = CASE WHEN @cLoseID = '1' THEN '' ELSE ID END,   
      LOC = @cToLOC,   
      EditWho  = SUSER_SNAME(),    
      EditDate = GETDATE(),   
      [Status] = CASE WHEN @cLoseUCC = '1' THEN '6' ELSE [Status] END  
   WHERE UCCNo = @cUCCNo   
      AND StorerKey = @cStorerKey  
      AND Status = '1'  
   IF @@ERROR <> 0
   BEGIN    
      SET @nErrNo = 50020 
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'UPD UCC FAIL 
      GOTO RollBackTran    
   END    

   -- Unlock current session suggested LOC
   IF @nPABookingKey <> 0
   BEGIN
      EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
         ,'' --FromLOC
         ,'' --FromID
         ,'' --SuggLOC
         ,'' --Storer
         ,@nErrNo  OUTPUT
         ,@cErrMsg OUTPUT
         ,@nPABookingKey = @nPABookingKey OUTPUT
      IF @nErrNo <> 0  
         GOTO RollBackTran
   
      SET @nPABookingKey = 0
   END

   COMMIT TRAN rdt_UCCPutaway_Confirm
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_UCCPutaway_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO