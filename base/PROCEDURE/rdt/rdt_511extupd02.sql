SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_511ExtUpd02                                     */  
/* Purpose: Lose ID for serial no                                       */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-02-01 1.0  Ung        WMS-3923 Created                          */ 
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_511ExtUpd02] (  
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cFacility      NVARCHAR( 5), 
   @cStorerKey     NVARCHAR( 15), 
   @cFromID        NVARCHAR( 18), 
   @cFromLOC       NVARCHAR( 10), 
   @cToLOC         NVARCHAR( 10), 
   @nErrNo         INT           OUTPUT, 
   @cErrMsg        NVARCHAR( 20) OUTPUT
)  
AS  
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
  
   DECLARE @nTranCount  INT
   DECLARE @cLoseID     NVARCHAR( 1)
   DECLARE @cSKU        NVARCHAR( 20)
   DECLARE @cSerialNoKey NVARCHAR( 10)
   DECLARE @cSerialNoCapture  NVARCHAR( 10)
     
   SET @nTranCount = @@TRANCOUNT
     
   IF @nFunc = 511 -- Move by ID
   BEGIN  
      IF @nStep = 3 -- ToLOC
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            -- Get ToLOC info
            SELECT @cLoseID = LoseID FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
            
            -- Lose ID LOC
            IF @cLoseID = '1'
            BEGIN
               -- Check ToLOC contain serial no (cannot check base on ID, since it is LoseID)
               IF EXISTS( SELECT 1
                  FROM LOTxLOCxID LLI WITH (NOLOCK) 
                     JOIN SKU WITH (NOLOCK) ON (LLI.StorerKey = SKU.StorerKey AND LLI.SKU = SKU.SKU)
                  WHERE LLI.LOC = @cToLOC 
                     AND LLI.QTY > 0
                     AND SKU.SerialNoCapture = '1')
               BEGIN
                  -- Handling transaction
                  BEGIN TRAN  -- Begin our own transaction
                  SAVE TRAN rdt_511ExtUpd02 -- For rollback or commit only our own transaction

                  -- Loop serial no on ID
                  DECLARE @curSNO CURSOR 
                  SET @curSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT SerialNoKey
                     FROM dbo.SerialNo WITH (NOLOCK)
                     WHERE StorerKey = @cStorerKey
                        AND ID = @cFromID
                  OPEN @curSNO
                  FETCH NEXT FROM @curSNO INTO @cSerialNoKey
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                     -- Update SerialNo ID
                     UPDATE dbo.SerialNo SET
                        ID = '',
                        EditDate = GETDATE(),
                        EditWho  = SUSER_SNAME(),
                        Trafficcop = NULL
                     WHERE SerialNoKey = @cSerialNoKey
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 119251
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd SNO Fail
                        GOTO RollBackTran
                     END
                     FETCH NEXT FROM @curSNO INTO @cSerialNoKey
                  END

                  COMMIT TRAN rdt_511ExtUpd02 -- Only commit change made here
               END
            END
         END
      END
   END  
  
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1819ExtUpd06 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO