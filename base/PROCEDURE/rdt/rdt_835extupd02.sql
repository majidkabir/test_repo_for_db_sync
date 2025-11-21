SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_835ExtUpd02                                     */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Update ucc.status = 6 if finish pack                        */
/*                                                                      */
/* Called from: rdtfnc_Pallet_Pack                                      */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2021-12-01  1.0  James       WMS-18471.Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_835ExtUpd02] (
   @nMobile       INT,
   @nFunc         INT,
   @cLangCode     NVARCHAR( 3),
   @nStep         INT,
   @nInputKey     INT,
   @cFacility     NVARCHAR( 5), 
   @cStorerKey    NVARCHAR( 15),
   @tExtUpdate    VariableTable READONLY, 
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cID            NVARCHAR( 18)
   DECLARE @nCount         INT = 0
   DECLARE @nRowRef        INT
   DECLARE @nTranCount     INT
   DECLARE @nCartonNo      INT
   DECLARE @cLabelNo       NVARCHAR( 20)
   DECLARE @cUserdefined01 NVARCHAR( 15)
   DECLARE @fCartonCube    FLOAT
   DECLARE @cMoveToLoc     NVARCHAR( 20)
   DECLARE @cFromLOC       NVARCHAR( 10)
   DECLARE @cPickConfirmStatus      NVARCHAR( 1)
   DECLARE @cPackByPickDetailDropID NVARCHAR( 1)
   DECLARE @cPackByPickDetailID     NVARCHAR( 1)

   -- Variable mapping
   SELECT @cPickSlipNo = Value FROM @tExtUpdate WHERE Variable = '@cDocValue'
   SELECT @cID = Value FROM @tExtUpdate WHERE Variable = '@cPltValue'

   SET @cPackByPickDetailDropID = rdt.RDTGetConfig( @nFunc, 'PackByPickDetailDropID', @cStorerKey)
   IF @cPackByPickDetailDropID = '0'
      SET @cPackByPickDetailID = '1'
   ELSE
      SET @cPackByPickDetailID = '0'

   SET @cPickConfirmStatus = rdt.RDTGetConfig( @nFunc, 'PickConfirmStatus', @cStorerKey)
   IF @cPickConfirmStatus = '0'
      SET @cPickConfirmStatus = '5'
         
   SET @cMoveToLoc = rdt.RDTGetConfig( @nFunc, 'MoveToLoc', @cStorerKey)
   IF @cMoveToLoc = '0'    
      SET @cMoveToLoc = ''   
      
   SET @nTranCount = @@TRANCOUNT  
  
   BEGIN TRAN  
   SAVE TRAN rdt_835ExtUpd02  
   
   IF @nStep = 2
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @nCount = 1
         FROM dbo.UCC UCC WITH (NOLOCK)
         WHERE Storerkey = @cStorerKey
         AND   Id = @cID
         AND   [Status] > '0'
         AND   [Status] < '6'
         AND   NOT EXISTS ( SELECT 1 FROM dbo.PackDetail PD WITH (NOLOCK)
                            WHERE UCC.UCCNo = PD.LabelNo
                            AND   UCC.Id = PD.DropID)
         
         IF @@ROWCOUNT = 0
         BEGIN
            DECLARE @curUPDUCC   CURSOR
            SET @curUPDUCC = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
            SELECT UCC_RowRef 
            FROM dbo.UCC WITH (NOLOCK)
            WHERE Storerkey = @cStorerKey
            AND   Id = @cID
            AND   [Status] > '0'
            AND   [Status] < '6'
            OPEN @curUPDUCC
            FETCH NEXT FROM @curUPDUCC INTO @nRowRef
            WHILE @@FETCH_STATUS = 0
            BEGIN
               UPDATE dbo.UCC SET 
                  STATUS = '6',
                  EditWho = SUSER_SNAME(), 
                  EditDate = GETDATE()
               WHERE UCC_RowRef = @nRowRef
               
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 179551
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- Loose UCC Err
                  GOTO RollBackTran
               END
               
               FETCH NEXT FROM @curUPDUCC INTO @nRowRef
            END
         END

         IF @cMoveToLoc <> ''
         BEGIN
            SELECT TOP 1 @cFromLOC = PD.Loc
            FROM dbo.PickDetail PD (NOLOCK)     
            WHERE ( ( @cPackByPickDetailDropID = '1' AND DropID = @cID) OR 
                    ( @cPackByPickDetailID = '1' AND ID = @cID))
            AND   PD.Status = @cPickConfirmStatus
            AND   PD.StorerKey  = @cStorerKey
            ORDER BY 1

            EXECUTE rdt.rdt_Move  
               @nMobile     = @nMobile,  
               @cLangCode   = @cLangCode,   
               @nErrNo      = @nErrNo  OUTPUT,  
               @cErrMsg     = @cErrMsg OUTPUT, -- screen limitation, 20 NVARCHAR max  
               @cSourceType = 'rdt_835ExtUpd02',   
               @cStorerKey  = @cStorerKey,  
               @cFacility   = @cFacility,   
               @cFromLOC    = @cFromLOC,   
               @cToLOC      = @cMoveToLoc,   
               @cFromID     = @cID,   
               @cToID       = NULL,  -- NULL means not changing ID  
               @nFunc       = @nFunc  

            IF @nErrNo <> 0  
               GOTO RollBackTran  
         END
      END
   END

   GOTO Quit  
  
   RollBackTran:  
         ROLLBACK TRAN rdt_835ExtUpd02  
   Quit:  
      WHILE @@TRANCOUNT > @nTranCount  
         COMMIT TRAN  

   Fail:  
END

GO