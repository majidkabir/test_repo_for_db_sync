SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_514ExtUpdSP02                                   */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Purpose: Update transferdetail (if exists) after ucc move            */
/*                                                                      */
/* Called from: rdtfnc_Move_UCC                                         */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2019-07-02  1.0  James    WMS-9565 Created                           */
/* 2023-01-20  1.1  Ung      WMS-21577 Add unlimited UCC to move        */
/* 2024-10-28  1.1  ShaoAn   Extend Parameter                           */
/************************************************************************/

CREATE   PROC [rdt].[rdt_514ExtUpdSP02] (
   @nMobile        INT, 
   @nFunc          INT, 
   @cLangCode      NVARCHAR( 3),  
   @nStep          INT, 
   @nInputKey      INT, 
   @cStorerKey     NVARCHAR( 15), 
   @cToID          NVARCHAR( 18), 
   @cToLoc         NVARCHAR( 10), 
   @cFromLoc       NVARCHAR( 10), 
   @cFromID        NVARCHAR( 18), 
   @cUCC1          NVARCHAR( 20), 
   @cUCC2          NVARCHAR( 20), 
   @cUCC3          NVARCHAR( 20), 
   @cUCC4          NVARCHAR( 20), 
   @cUCC5          NVARCHAR( 20), 
   @cUCC6          NVARCHAR( 20), 
   @cUCC7          NVARCHAR( 20), 
   @cUCC8          NVARCHAR( 20), 
   @cUCC9          NVARCHAR( 20), 
   @cUDF01         NVARCHAR( 30), 
   @nErrNo         INT           OUTPUT,  
   @cErrMsg        NVARCHAR( 20) OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   DECLARE @i          INT
   DECLARE @nRowCount  INT
   DECLARE @nQTY       INT
   DECLARE @cFacility  NVARCHAR( 5)
   DECLARE @cUCC       NVARCHAR( 20)
   DECLARE @cUCCStatus NVARCHAR( 10) 
   DECLARE @cTransferKey       NVARCHAR( 10)  
   DECLARE @cTrasferLineNumber NVARCHAR( 5)  
   DECLARE @cLocationCategory  NVARCHAR( 10)  
   DECLARE @cSKU       NVARCHAR( 20)
   DECLARE @cLOT       NVARCHAR( 10)
   DECLARE @cUCC_ID    NVARCHAR( 18)
   DECLARE @cToLot     NVARCHAR( 10)
   DECLARE @cSourceKey NVARCHAR( 20)

   SELECT @cFacility = Facility
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_514ExtUpdSP02   

   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF EXISTS ( SELECT 1 
            FROM TransferDetail TD WITH (NOLOCK)
               JOIN rdt.rdtMoveUCCLog UCC WITH (NOLOCK) ON ( TD.UserDefine01 = UCC.UCCNo AND UCC.StorerKey = @cStorerKey AND UCC.AddWho = SUSER_SNAME())
            WHERE @cStorerKey IN ( TD.FromStorerKey, TD.ToStorerKey)
               AND TD.Status = '3'
               AND UCC.UCCNo <> '')
         BEGIN
            DECLARE @curUCC CURSOR  
            SET @curUCC = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT UCCNo 
               FROM rdt.rdtMoveUCCLog WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
                  AND AddWho = SUSER_SNAME()
            OPEN @curUCC
            FETCH NEXT FROM @curUCC INTO @cUCC
            WHILE @@FETCH_STATUS = 0
            BEGIN
               SELECT TOP 1 
                  @cTransferKey = TransferKey,
                  @cTrasferLineNumber = TransferLineNumber,
                  @cSKU = FromSKU,
                  @cFromLOC = FromLOC,
                  @cFromID = FromID, 
                  @cLOT = FromLOT,
                  @nQTY = FromQTY
               FROM dbo.TransferDetail WITH (NOLOCK)
               WHERE UserDefine01 = @cUCC
               AND   Status = '3'
               AND   @cStorerKey IN ( FromStorerKey, ToStorerKey)
               ORDER BY 1

               SET @nRowCount = @@ROWCOUNT

               IF @nRowCount = 0
               BEGIN  
                  SET @nErrNo = 141451
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No Tran Record'  
                  GOTO RollBackTran  
               END 

               IF @nRowCount = 1
               BEGIN
                  SELECT @cUCC_ID = ID
                  FROM dbo.UCC WITH (NOLOCK)
                  WHERE UCCNo = @cUCC
                  AND   StorerKey = @cStorerKey

                  UPDATE dbo.TransferDetail WITH (ROWLOCK) SET
                     FromLoc = @cToLoc,
                     FromID  = @cUCC_ID,
                     ToLoc   = @cToLoc,
                     ToID    = @cUCC_ID,
                     ToLot = '',
                     Status  = '9'  
                  WHERE TransferKey = @cTransferKey  
                  AND   TransferLineNumber = @cTrasferLineNumber  

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 141452
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdTransferDetFail'  
                     GOTO RollBackTran  
                  END  

                  SET @cSourceKey = RTRIM( @cTransferKey) + RTRIM( @cTrasferLineNumber )
                  SELECT @cToLot = Lot
                  FROM dbo.ITRN WITH (NOLOCK)
                  WHERE SourceKey = @cSourceKey 
                  AND   SourceType = 'ntrTransferDetailUpdate' 
                  AND   TranType = 'DP'

                  SELECT @cLocationCategory = LocationCategory
                  FROM dbo.LOC WITH (NOLOCK)
                  WHERE LOC = @cToLoc
                  AND   Facility = @cFacility

                  SET @cUCCStatus = ''
                  IF @cLocationCategory = 'SELECTIVE'
                  BEGIN
                     UPDATE dbo.UCC WITH (ROWLOCK) SET 
                        Status = '1',
                        LOT = @cToLot
                     WHERE UCCNo = @cUCC
                     AND   StorerKey = @cStorerKey

                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 141453
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd UCC Fail'  
                        GOTO RollBackTran  
                     END  
                  END
                  ELSE IF @cLocationCategory = 'MEZZANINE'
                  BEGIN
                     UPDATE dbo.UCC WITH (ROWLOCK) SET 
                        Status = '6'
                     WHERE UCCNo = @cUCC
                     AND   StorerKey = @cStorerKey

                     IF @@ERROR <> 0  
                     BEGIN  
                        SET @nErrNo = 141454
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Upd UCC Fail'  
                        GOTO RollBackTran  
                     END  
                  END

                  DECLARE @cRPFTaskKey NVARCHAR( 10)

                  SELECT @cRPFTaskKey = TaskDetailKey
                  FROM dbo.TaskDetail WITH (NOLOCK)
                  WHERE SourceKey = @cSourceKey--@cTransferKey + @cTrasferLineNumber
                  AND   CaseID = @cUCC
                  AND   TaskType = 'RPF'
                  AND   StorerKey = @cStorerKey

                  IF ISNULL( @cRPFTaskKey, '') <> ''
                  BEGIN
                     SET @nErrNo = 0
                     -- Unlock by RPF task
                     EXEC rdt.rdt_Putaway_PendingMoveIn '', 'UNLOCK'
                        ,'' --FromLOC
                        ,'' --FromID
                        ,'' --cSuggLOC
                        ,'' --Storer
                        ,@nErrNo  OUTPUT
                        ,@cErrMsg OUTPUT
                        ,@cTaskDetailKey = @cRPFTaskKey

                     IF @nErrNo <> 0  
                     BEGIN  
                        SET @nErrNo = 141456
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Unlock PMV Err'  
                        GOTO RollBackTran  
                     END  
                  END
               END

               IF @nRowCount > 1
               BEGIN  
                  SET @nErrNo = 141455
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCC Multi Tran'  
                  GOTO RollBackTran  
               END 
               FETCH NEXT FROM @curUCC INTO @cUCC
            END
         END
      END
   END

   GOTO Quit
   
   RollBackTran:
      ROLLBACK TRAN rdt_514ExtUpdSP02 -- Only rollback change made here
   Quit:
      WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
         COMMIT TRAN   
END


GO