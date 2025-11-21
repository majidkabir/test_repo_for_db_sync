SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1638ExtUpd07                                    */
/* Copyright: LFLogistics                                               */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 2022-06-22  1.0  James    WMS-19694. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1638ExtUpd07] (
   @nMobile      INT,           
   @nFunc        INT,           
   @nStep        INT,
   @nAfterStep   INT,        
   @nInputKey    INT,           
   @cLangCode    NVARCHAR( 3),  
   @cFacility    NVARCHAR( 5),  
   @cStorerkey   NVARCHAR( 15), 
   @cPalletKey   NVARCHAR( 30), 
   @cCartonType  NVARCHAR( 10), 
   @cCaseID      NVARCHAR( 20), 
   @cLOC         NVARCHAR( 10), 
   @cSKU         NVARCHAR( 20), 
   @nQTY         INT,            
   @cLength      NVARCHAR(5),    
   @cWidth       NVARCHAR(5),    
   @cHeight      NVARCHAR(5),    
   @cGrossWeight NVARCHAR(5),    
   @nErrNo       INT           OUTPUT,
   @cErrMsg      NVARCHAR( 20) OUTPUT 
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nTranCount INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN
   SAVE TRAN rdt_1638ExtUpd07   

   DECLARE @bSuccess       INT
   DECLARE @cWeight        NVARCHAR( 10)
   DECLARE @cCube          NVARCHAR( 10)
   DECLARE @nUseSequence   INT
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @cLoadKey       NVARCHAR( 10)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cRefNo         NVARCHAR( 20)
   DECLARE @cMBOLKey       NVARCHAR( 10)
   DECLARE @cChkStatus     NVARCHAR( 10)
   DECLARE @cChkFacility   NVARCHAR( 5)
   DECLARE @cCapturePackInfo  NVARCHAR( 10)
   DECLARE 
      @nCtnCnt1 INT = '', 
      @nCtnCnt2 INT = '', 
      @nCtnCnt3 INT = '', 
      @nCtnCnt4 INT = '', 
      @nCtnCnt5 INT = '', 
      @cUDF01   NVARCHAR(20) = '', 
      @cUDF02   NVARCHAR(20) = '', 
      @cUDF03   NVARCHAR(20) = '', 
      @cUDF04   NVARCHAR(20) = '', 
      @cUDF05   NVARCHAR(20) = '', 
      @cUDF09   NVARCHAR(10) = '', 
      @cUDF10   NVARCHAR(10) = ''
                  
   IF @nFunc = 1638 -- Scan to pallet
   BEGIN
      IF @nStep = 6    -- Capture pack info (after)
      BEGIN
         IF @nInputKey = 1 -- ENTER
         BEGIN
            SELECT @cPickSlipNo = V_PickSlipNo,
                   @nCartonNo = V_CartonNo,
                   @cCapturePackInfo = V_String5,
                   @cWeight = I_Field02,
                   @cCube = I_Field03,
                   @cRefNo = I_Field04
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile
            
            IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                        WHERE PickSlipNo = @cPickSlipNo
                        AND   CartonNo = @nCartonNo
                        AND   TrackingNo = @cRefNo)
            BEGIN
               SELECT @cOrderKey = OrderKey
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
               
               IF ISNULL( @cOrderKey, '') = ''
                  SELECT @cOrderKey = OrderKey
                  FROM dbo.PickHeader WITH (NOLOCK)
                  WHERE PickHeaderKey = @cPickSlipNo 

               IF ISNULL( @cOrderKey, '') = ''
               BEGIN    
                  SET @nErrNo = 187501    
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'No OrderKey'    
                  GOTO RollBackTran    
               END 

               -- Get MBOL info  
               SELECT   
                  @cMBOLKey = MBOLKey,   
                  @cChkStatus = Status,   
                  @cChkFacility = Facility  
               FROM MBOL WITH (NOLOCK)  
               WHERE ExternMbolKey = @cPalletKey  
  
               -- Create MBOL  
               IF @@ROWCOUNT = 0  
               BEGIN  
                  -- Get MBOLKey  
                  EXECUTE nspg_GetKey  
                     'MBOL',  
                     10,  
                     @cMBOLKey   OUTPUT,  
                     @bSuccess   OUTPUT,  
                     @nErrNo     OUTPUT,  
                     @cErrMsg    OUTPUT  
                  IF @bSuccess <> 1  
                  BEGIN  
                     SET @nErrNo = 187502  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --GetKey Fail  
                     GOTO RollBackTran  
                  END  
           
                  -- Insert MBOL  
                  INSERT INTO MBOL (MBOLKey, ExternMBOLKey, Facility, STATUS, Remarks) VALUES (@cMBOLKey, @cPalletKey, @cFacility, '0', 'ECOM')  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 187503  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBOL Fail  
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
                  -- Check MBOL status  
                  IF @cChkStatus = '9'  
                  BEGIN  
                     SET @nErrNo = 187504  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL shipped  
                     GOTO RollBackTran  
                  END  
  
                  -- Check MBOL facility  
                  IF @cChkFacility <> @cFacility  
                  BEGIN  
                     SET @nErrNo = 187505  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL FAC Diff  
                     GOTO RollBackTran  
                  END  
               END  
               

               SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey

               IF CHARINDEX( 'T', @cCapturePackInfo) <> 0
               BEGIN
                  -- Get carton type info
                  SELECT @nUseSequence = UseSequence
                  FROM Cartonization C WITH (NOLOCK)
                     JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
                  WHERE S.StorerKey = @cStorerKey
                     AND C.CartonType = @cCartonType

                  IF @nUseSequence = 1  SET @nCtnCnt1 = 1 ELSE
                  IF @nUseSequence = 2  SET @nCtnCnt2 = 1 ELSE
                  IF @nUseSequence = 3  SET @nCtnCnt3 = 1 ELSE
                  IF @nUseSequence = 4  SET @nCtnCnt4 = 1 ELSE
                  IF @nUseSequence = 5  SET @nCtnCnt5 = 1 ELSE
                  IF @nUseSequence = 6  SET @cUDF01 = '1' ELSE
                  IF @nUseSequence = 7  SET @cUDF02 = '1' ELSE
                  IF @nUseSequence = 8  SET @cUDF03 = '1' ELSE
                  IF @nUseSequence = 9  SET @cUDF04 = '1' ELSE
                  IF @nUseSequence = 10 SET @cUDF05 = '1' ELSE
                  IF @nUseSequence = 11 SET @cUDF09 = '1' ELSE
                  IF @nUseSequence = 12 SET @cUDF10 = '1' 
               END
                  
               IF CHARINDEX( 'W', @cCapturePackInfo) = 0
                  SET @cWeight = 0

               IF CHARINDEX( 'C', @cCapturePackInfo) = 0
                  SET @cCube = 0

               IF NOT EXISTS ( SELECT 1 FROM dbo.MBOLDETAIL WITH (NOLOCK) WHERE MbolKey = @cMBOLKey AND OrderKey = @cOrderKey)
               BEGIN
                  INSERT INTO dbo.MBOLDetail 
                     (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate, Weight, Cube, 
                      CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine09, UserDefine10)
                  VALUES 
                     (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), CAST( @cWeight AS FLOAT), CAST( @cCube AS FLOAT),  
                      @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5, @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cUDF09, @cUDF10)
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 187506
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail
                     GOTO RollbackTran
                  END
               END
               ELSE
               BEGIN
                  UPDATE dbo.MBOLDetail SET
                      CtnCnt1      = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 1  THEN CtnCnt1 + 1 ELSE CtnCnt1 END
                     ,CtnCnt2      = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 2  THEN CtnCnt2 + 1 ELSE CtnCnt2 END
                     ,CtnCnt3      = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 3  THEN CtnCnt3 + 1 ELSE CtnCnt3 END
                     ,CtnCnt4      = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 4  THEN CtnCnt4 + 1 ELSE CtnCnt4 END
                     ,CtnCnt5      = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 5  THEN CtnCnt5 + 1 ELSE CtnCnt5 END
                     ,UserDefine01 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 6  THEN CAST( UserDefine01 AS INT) + 1 ELSE UserDefine01 END
                     ,UserDefine02 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 7  THEN CAST( UserDefine02 AS INT) + 1 ELSE UserDefine02 END
                     ,UserDefine03 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 8  THEN CAST( UserDefine03 AS INT) + 1 ELSE UserDefine03 END
                     ,UserDefine04 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 9  THEN CAST( UserDefine04 AS INT) + 1 ELSE UserDefine04 END
                     ,UserDefine05 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 10 THEN CAST( UserDefine05 AS INT) + 1 ELSE UserDefine05 END
                     ,UserDefine09 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 11 THEN CAST( UserDefine09 AS INT) + 1 ELSE UserDefine09 END
                     ,UserDefine10 = CASE WHEN CHARINDEX( 'T', @cCapturePackInfo) <> 0 AND @nUseSequence = 12 THEN CAST( UserDefine10 AS INT) + 1 ELSE UserDefine10 END
                     ,Cube         = CASE WHEN CHARINDEX( 'W', @cCapturePackInfo) <> '0' THEN Cube + CAST( @cCube AS FLOAT) ELSE Cube END
                     ,Weight       = CASE WHEN CHARINDEX( 'W', @cCapturePackInfo) <> 0 THEN Weight + CAST( @cWeight AS FLOAT) ELSE Weight END 
                     ,EditWho      = SUSER_SNAME()
                     ,EditDate     = GETDATE()
                  WHERE MBOLKey = @cMBOLKey
                     AND OrderKey = @cOrderKey
                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 187507
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBDtl Fail
                     GOTO RollBackTran
                  END
               END
               
               IF ISNULL( @cRefNo, '') <> ''
               BEGIN
                  UPDATE dbo.Orders SET 
                     TrackingNo = @cRefNo,
                     EditWho = SUSER_SNAME(), 
                     EditDate = GETDATE()
                  WHERE OrderKey = @cOrderKey

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 187508
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Orders Fail
                     GOTO RollBackTran
                  END
                  
                  DECLARE @curUpdPackInfo CURSOR
                  SET @curUpdPackInfo = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
                  SELECT CartonNo
                  FROM dbo.PackInfo WITH (NOLOCK)
                  WHERE PickSlipNo = @cPickSlipNo
                  OPEN @curUpdPackInfo
                  FETCH NEXT FROM @curUpdPackInfo INTO @nCartonNo
                  WHILE @@FETCH_STATUS = 0
                  BEGIN
                  	UPDATE dbo.PackInfo SET
                  	   RefNo = @cRefNo,
                  	   TrackingNo = @cRefNo,
                  	   EditWho = SUSER_SNAME(),
                  	   EditDate = GETDATE()
                  	WHERE PickSlipNo = @cPickSlipNo
                  	AND   CartonNo = @nCartonNo

                     IF @@ERROR <> 0
                     BEGIN
                        SET @nErrNo = 187509
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD PackI Fail
                        GOTO RollBackTran
                     END
                     
                  	FETCH NEXT FROM @curUpdPackInfo INTO @nCartonNo
                  END
               END
            END
         END
      END


   END

   GOTO Quit
   
RollBackTran:
   ROLLBACK TRAN rdt_1638ExtUpd07 -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN   
END

GO