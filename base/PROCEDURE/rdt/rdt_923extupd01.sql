SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_923ExtUpd01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Called from: rdtfnc_UCCReceive                                       */
/*              Release the pallet position after pallet closed         */
/*                                                                      */
/*                                                                      */
/* Date        Rev  Author    Purposes                                  */
/* 27-11-2018  1.0  ChewKP    WMS-6571. Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_923ExtUpd01]
    @nMobile     INT,           
    @nFunc       INT,           
    @cLangCode   NVARCHAR( 3),  
    @nStep       INT,           
    @nInputKey   INT,           
    @cStorerKey  NVARCHAR( 15), 
    @cType       NVARCHAR( 1),  
    @cMBOLKey    NVARCHAR( 10), 
    @cLoadKey    NVARCHAR( 10), 
    @cOrderKey   NVARCHAR( 10), 
    @cLabelNo    NVARCHAR( 20), 
    @cOption     NVARCHAR( 1),  
    @nErrNo      INT           OUTPUT, 
    @cErrMsg     NVARCHAR( 20) OUTPUT  
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE 
           @cPickMethod    NVARCHAR( 10)
          ,@cTaskDetailKey NVARCHAR( 10)
          ,@nRowref        INT
          ,@nTranCount     INT
          ,@cUCCNo         NVARCHAR( 20) 
          ,@cPickSlipNo    NVARCHAR( 10) 
          ,@nCount         INT
          ,@cURNNo         NVARCHAR( 20)

   DECLARE @curRD CURSOR
   

   SELECT @nInputKey = InputKey,
          @cStorerKey = StorerKey
   FROM RDT.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   -- Handling transaction
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_923ExtUpd01 -- For rollback or commit only our own transaction
   
   IF @cMBOLKey  <> ''  SET @cType = 'M'
   IF @cLoadKey  <> ''  SET @cType = 'L'
   IF @cOrderKey <> ''  SET @cType = 'O'

   IF @nStep = 2 
   BEGIN
      IF @nInputKey = 1 
      BEGIN
          SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE LabelNo = @cLabelNo  
          SELECT @cOrderKey = OrderKey FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo  
          
          IF @cType = 'M'
          BEGIN
              
              DELETE FROM rdt.rdtScanToTruck 
              WHERE MBOLKey = @cMBOLKey
              AND URNNo = @cLabelNo
              
              IF @@ERROR <> 0
              BEGIN
                 SET @nErrNo = 132251
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ResetFail
                 GOTO RollBackTran
              END
              
          END
          IF @cType = 'L'
          BEGIN
              DELETE FROM rdt.rdtScanToTruck 
              WHERE LoadKey = @cLoadKey
              AND URNNo = @cLabelNo
              
              IF @@ERROR <> 0
              BEGIN
                 SET @nErrNo = 132252
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ResetFail
                 GOTO RollBackTran
              END
          END
          IF @cType = 'O'
          BEGIN
              DELETE FROM rdt.rdtScanToTruck 
              WHERE OrderKey = @cOrderKey
              AND URNNo = @cLabelNo
              
              IF @@ERROR <> 0
              BEGIN
                 SET @nErrNo = 132253
                 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ResetFail
                 GOTO RollBackTran
              END
          END
          
--          SELECT @nScanCount = Count (Distinct URRNo ) 
--          FROM rdt.rdtScanToTruck WHERE 
--          WHERE MBOLKey = CASE WHEN @cType = 'M' THEN @cMBOLKey ELSE MBOLKey END
--            AND LoadKey = CASE WHEN @cType = 'L' THEN @cLoadKey ELSE LoadKey END
--            AND OrderKey = CASE WHEN @cType = 'O' THEN @cOrderKey ELSE OrderKey END
--          
--               
--          SELECT @nCountTotalLabel = Count (Distinct LabelNo) 
--          FROM dbo.PackDetail WITH (NOLOCK) 
--          WHERE StorerKey = @cStorerKey
--          AND PickSlipNo = @cPickSlipNo 

          SELECT @nCount = Count ( Distinct PD.LabelNo )
          FROM dbo.PackDetail PD WITH (NOLOCK) 
          INNER JOIN rdt.rdtScanToTruck R WITH (NOLOCK) ON R.URNNo = PD.LabelNo 
          WHERE PD.StorerKey = @cStorerKey
          AND PD.PickSlipNo = @cPickSlipNo 
          
          IF ISNULL(@nCount,0 )  = 0  
          BEGIN
            IF @cType = 'M'
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) 
                           WHERE MBOLKey = @cMBOLKey 
                           AND OrderKey = @cOrderKey ) 
               BEGIN 
                  DELETE FROM dbo.MBOLDetail WITH (ROWLOCK) 
                  WHERE MBOLKey = @cMBOLKey
                  AND OrderKey = @cOrderKey 
                  
                  IF @@ERROR <> 0 
                  BEGIN 
                     SET @nErrNo = 132254
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelMBOLDetFail
                     GOTO RollBackTran
                  END
               END
            END
            
            IF @cType = 'L'
            BEGIN
               IF EXISTS ( SELECT 1 FROM dbo.LoadPlanDetail WITH (NOLOCK) 
                           WHERE LoadKey = @cLoadKey
                           AND OrderKey = @cOrderKey ) 
               BEGIN 
                  DELETE FROM dbo.LoadPlanDetail WITH (ROWLOCK) 
                  WHERE LoadKey = @cLoadKey
                  AND OrderKey = @cOrderKey 
                  
                  IF @@ERROR <> 0 
                  BEGIN 
                     SET @nErrNo = 132255
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelLPDetFail
                     GOTO RollBackTran
                  END
               END
            END
            
            
            
          END
          
          
          
      END
   END
   
   IF @nStep = 3 -- LabelNo 
   BEGIN
      IF @nInputKey = 1
      BEGIN
            IF @cOption = '1' 
            BEGIN
                            
              IF @cType = 'M'
              BEGIN
                  SET @curRD = CURSOR FOR 
                  
                  SELECT RowRef , URNNo 
                  FROM rdt.rdtScanToTruck WITH (NOLOCK) 
                  WHERE MBOLKey = @cMBOLKey 
                  
              END
              ELSE IF @cType = 'L'
              BEGIN
                  
                  SET @curRD = CURSOR FOR 
                  
                  SELECT RowRef , URNNo 
                  FROM rdt.rdtScanToTruck WITH (NOLOCK) 
                  WHERE LoadKey = @cLoadKey 
              END
              ELSE IF @cType = 'O'
              BEGIN
                  
                  SET @curRD = CURSOR FOR 
                  
                  SELECT RowRef , URNNo 
                  FROM rdt.rdtScanToTruck WITH (NOLOCK) 
                  WHERE OrderKey = @cOrderKey  
              END
              
                  
              OPEN @curRD
              FETCH NEXT FROM @curRD INTO @nRowRef, @cURNNo 
              WHILE @@FETCH_STATUS = 0
              BEGIN
                  SELECT @cPickSlipNo = PickSlipNo FROM dbo.PackDetail WITH (NOLOCK) WHERE LabelNo = @cURNNo  
                  SELECT @cOrderKey = OrderKey FROM dbo.PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo  
                  
                  IF @cType = 'M' 
                  BEGIN 
                     DELETE FROM dbo.MBOLDetail WITH (ROWLOCK) 
                     WHERE MBOLKey = @cMBOLKey 
                     AND OrderKey = @cOrderKey 
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 132256
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelMBOLDetFail
                        GOTO RollBackTran
                     END
                  END
                  
                  IF @cType = 'L' 
                  BEGIN 
                     DELETE FROM dbo.LoadPlanDetail WITH (ROWLOCK) 
                     WHERE LoadKey = @cLoadKey  
                     AND OrderKey = @cOrderKey 
                     
                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 132257
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DelLPDetFail
                        GOTO RollBackTran
                     END
                  END
                             
                  DELETE FROM rdt.rdtScanToTruck 
                  WHERE RowRef = @nRowRef
                  
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 132258
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ResetFail
                     GOTO RollBackTran
                  END
                      
             
                  
                 FETCH NEXT FROM @curRD INTO @nRowRef, @cURNNo  
              END
            
            END

      END
   END
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_923ExtUpd01 -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN

END

GO