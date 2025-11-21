SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1764ExtUpd04                                          */
/* Purpose: TM Replen From, Extended Update for CN DYSON                      */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date         Author    Ver.  Purposes                                      */
/* 2018-01-04   Ung       1.0   WMS-3717 Created                              */
/******************************************************************************/

CREATE PROCEDURE [RDT].[rdt_1764ExtUpd04]
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@cTaskdetailKey  NVARCHAR( 10)
   ,@nErrNo          INT           OUTPUT
   ,@cErrMsg         NVARCHAR( 20) OUTPUT
   ,@nAfterStep      INT = 0
   ,@cDropID         NVARCHAR( 20) = ''
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount  INT
   
   DECLARE @cStorerKey     NVARCHAR( 15)
   DECLARE @cSKU           NVARCHAR( 20)
   DECLARE @cFromID        NVARCHAR( 18)
   DECLARE @cToLOC         NVARCHAR( 10)
   DECLARE @cToID          NVARCHAR( 18)
   DECLARE @cPickMethod    NVARCHAR( 10)
   DECLARE @cStatus        NVARCHAR( 10)
   DECLARE @cSerialNoKey   NVARCHAR( 10)
   DECLARE @cLoseID        NVARCHAR( 1)

   SET @nTranCount = @@TRANCOUNT

   -- TM Replen From
   IF @nFunc = 1764
   BEGIN
      IF @nStep = 6 -- ToLOC
      BEGIN
         -- Get task info
         SELECT
            @cSKU = SKU, 
            @cPickMethod = PickMethod,
            @cStorerKey = StorerKey,
            @cFromID = FromID, 
            @cToID = ToID, 
            @cToLOC = ToLOC, 
            @cStatus = Status
         FROM dbo.TaskDetail WITH (NOLOCK)
         WHERE TaskdetailKey = @cTaskdetailKey

         -- Completed task
         IF @cStatus = '9'
         BEGIN
            -- Full pallet single SKU
            IF @cFromID <> '' AND @cPickMethod = 'FP' AND @cSKU <> ''
            BEGIN
               -- Serial no
               IF EXISTS( SELECT 1 FROM SKU WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND SKU = @cSKU AND SerialNoCapture = '1')
               BEGIN
                  -- Get LOC info
                  SELECT @cLoseID = LoseID FROM LOC WITH (NOLOCK) WHERE LOC = @cToLOC
               
                  -- ID changed
                  IF @cLoseID = '1' OR @cFromID <> @cToID
                  BEGIN
                     -- Lose ID
                     IF @cLoseID = '1' 
                        SET @cToID = ''
                     
                     BEGIN TRAN
                     SAVE TRAN rdt_1764ExtUpd04

                     -- Loop serial no on ID
                     DECLARE @curSNO CURSOR 
                     SET @curSNO = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                        SELECT SerialNoKey
                        FROM dbo.SerialNo WITH (NOLOCK)
                        WHERE StorerKey = @cStorerKey
                           AND SKU = @cSKU
                           AND ID = @cFromID
                     OPEN @curSNO
                     FETCH NEXT FROM @curSNO INTO @cSerialNoKey
                     WHILE @@FETCH_STATUS = 0
                     BEGIN
                        -- Update SerialNo ID
                        UPDATE dbo.SerialNo SET
                           ID = @cToID,
                           EditDate = GETDATE(),
                           EditWho  = SUSER_SNAME(),
                           Trafficcop = NULL
                        WHERE SerialNoKey = @cSerialNoKey
                        IF @@ERROR <> 0
                        BEGIN
                           SET @nErrNo = 116052
                           SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Upd SNO Fail
                           GOTO RollBackTran
                        END
            
                        FETCH NEXT FROM @curSNO INTO @cSerialNoKey
                     END

                     COMMIT TRAN rdt_1764ExtUpd04 -- Only commit change made here
                  END
               END
            END
         END
      END
   END

   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_1764ExtUpd04 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO