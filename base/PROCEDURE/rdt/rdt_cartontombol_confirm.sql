SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_CartonToMBOL_Confirm                                  */
/* Copyright      : LFLogistics                                               */
/*                                                                            */
/* Date         Rev  Author   Purposes                                        */
/* 2023-03-30   1.0  Ung      WMS-22181 Created                               */
/* 2023-06-07   1.1  Ung      WMS-22678 Add capture PackInfo                  */
/*                            Add rdtCartonToMBOLLog                          */
/******************************************************************************/
CREATE   PROC [RDT].[rdt_CartonToMBOL_Confirm](
    @nMobile         INT
   ,@nFunc           INT
   ,@cLangCode       NVARCHAR( 3)
   ,@nStep           INT
   ,@nInputKey       INT
   ,@cFacility       NVARCHAR( 5)
   ,@cStorerKey      NVARCHAR( 15)
   ,@cMBOLKey        NVARCHAR( 10)
   ,@cRefNo          NVARCHAR( 20)
   ,@cOrderKey       NVARCHAR( 10)
   ,@cCartonID       NVARCHAR( 20)
   ,@cSKU            NVARCHAR( 20) 
   ,@cPickSlipNo     NVARCHAR( 10) 
   ,@nCartonNo       INT
   ,@cData1          NVARCHAR( 20)
   ,@cData2          NVARCHAR( 20)
   ,@cData3          NVARCHAR( 20)
   ,@cData4          NVARCHAR( 20)
   ,@cData5          NVARCHAR( 20)
   ,@tConfirmVar     VariableTable  READONLY
   ,@nTotalCarton    INT            OUTPUT
   ,@nErrNo          INT            OUTPUT
   ,@cErrMsg         NVARCHAR( 20)  OUTPUT
   ,@cCartonType     NVARCHAR( 10) = ''  
   ,@nUseSequence    INT = 0 
   ,@cWeight         NVARCHAR( 10) = '' 
   ,@cCube           NVARCHAR( 10) = '' 
   ,@cPackInfoRefNo  NVARCHAR( 20) = ''
   ,@cLength         NVARCHAR( 10) = '' 
   ,@cWidth          NVARCHAR( 10) = '' 
   ,@cHeight         NVARCHAR( 10) = '' 

) 
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cSQL        NVARCHAR( MAX)
   DECLARE @cSQLParam   NVARCHAR( MAX)
   DECLARE @cConfirmSP   NVARCHAR( 20)

   -- Get storer config
   SET @cConfirmSP = rdt.RDTGetConfig( @nFunc, 'ConfirmSP', @cStorerKey)
   IF @cConfirmSP = '0'
      SET @cConfirmSP = ''
 
   /***********************************************************************************************
                                              Custom confirm
   ***********************************************************************************************/
   IF @cConfirmSP <> ''
   BEGIN
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cConfirmSP AND type = 'P')
      BEGIN
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cConfirmSP) +
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
            ' @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, ' + 
            ' @cData1, @cData2, @cData3, @cData4, @cData5, @tConfirmVar, ' +
            ' @nTotalCarton OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, ' + 
            ' @cCartonType, @nUseSequence, @cWeight, @cCube, @cPackInfoRefNo, @cLength, @cWidth, @cHeight '
         SET @cSQLParam =
            '  @nMobile         INT            ' + 
            ' ,@nFunc           INT            ' + 
            ' ,@cLangCode       NVARCHAR( 3)   ' + 
            ' ,@nStep           INT            ' + 
            ' ,@nInputKey       INT            ' + 
            ' ,@cFacility       NVARCHAR( 5)   ' + 
            ' ,@cStorerKey      NVARCHAR( 15)  ' + 
            ' ,@cMBOLKey        NVARCHAR( 10)  ' + 
            ' ,@cRefNo          NVARCHAR( 20)  ' + 
            ' ,@cOrderKey       NVARCHAR( 10)  ' + 
            ' ,@cCartonID       NVARCHAR( 20)  ' + 
            ' ,@cSKU            NVARCHAR( 20)  ' + 
            ' ,@cPickSlipNo     NVARCHAR( 10)  ' + 
            ' ,@nCartonNo       INT            ' + 
            ' ,@cData1          NVARCHAR( 20)  ' + 
            ' ,@cData2          NVARCHAR( 20)  ' + 
            ' ,@cData3          NVARCHAR( 20)  ' + 
            ' ,@cData4          NVARCHAR( 20)  ' + 
            ' ,@cData5          NVARCHAR( 20)  ' + 
            ' ,@tConfirmVar     VariableTable  READONLY ' + 
            ' ,@nTotalCarton    INT            OUTPUT   ' + 
            ' ,@nErrNo          INT            OUTPUT   ' + 
            ' ,@cErrMsg         NVARCHAR( 20)  OUTPUT   ' + 
            ' ,@cCartonType     NVARCHAR( 10) ' + 
            ' ,@nUseSequence    INT           ' + 
            ' ,@cWeight         NVARCHAR( 10) ' + 
            ' ,@cCube           NVARCHAR( 10) ' + 
            ' ,@cPackInfoRefNo  NVARCHAR( 20) ' + 
            ' ,@cLength         NVARCHAR( 10) ' + 
            ' ,@cWidth          NVARCHAR( 10) ' + 
            ' ,@cHeight         NVARCHAR( 10) ' 

         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, 
            @cMBOLKey, @cRefNo, @cOrderKey, @cCartonID, @cSKU, @cPickSlipNo, @nCartonNo, 
            @cData1, @cData2, @cData3, @cData4, @cData5, @tConfirmVar, 
            @nTotalCarton OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cCartonType, @nUseSequence, @cWeight, @cCube, @cPackInfoRefNo, @cLength, @cWidth, @cHeight

         GOTO Quit
      END
   END

   /***********************************************************************************************
                                             Standard create
   ***********************************************************************************************/
   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_CartonToMBOL_Confirm -- For rollback or commit only our own transaction

   -- MBOL detail
   IF NOT EXISTS( SELECT 1 FROM dbo.MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
   BEGIN
      DECLARE 
         @nCtnCnt1 INT = 0, 
         @nCtnCnt2 INT = 0, 
         @nCtnCnt3 INT = 0, 
         @nCtnCnt4 INT = 0, 
         @nCtnCnt5 INT = 0, 
         @cUDF01   NVARCHAR(20) = '', 
         @cUDF02   NVARCHAR(20) = '', 
         @cUDF03   NVARCHAR(20) = '', 
         @cUDF04   NVARCHAR(20) = '', 
         @cUDF05   NVARCHAR(20) = '', 
         @cUDF09   NVARCHAR(10) = '', 
         @cUDF10   NVARCHAR(10) = ''
      
      IF @cCartonType <> ''
      BEGIN
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
      
      DECLARE @cLoadKey NVARCHAR( 10)
      SELECT @cLoadKey = LoadKey FROM dbo.Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
      INSERT INTO dbo.MBOLDetail 
         (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate, Weight, Cube, 
          CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine09, UserDefine10)
      VALUES 
         (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), @cWeight, @cCube, 
          @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5, @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cUDF09, @cUDF10)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 198901
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail
         GOTO RollBackTran
      END
   END
   ELSE
   BEGIN
      UPDATE dbo.MBOLDetail SET
          CtnCnt1      = CASE WHEN @cCartonType <> '' AND @nUseSequence = 1  THEN CtnCnt1 + 1 ELSE CtnCnt1 END
         ,CtnCnt2      = CASE WHEN @cCartonType <> '' AND @nUseSequence = 2  THEN CtnCnt2 + 1 ELSE CtnCnt2 END
         ,CtnCnt3      = CASE WHEN @cCartonType <> '' AND @nUseSequence = 3  THEN CtnCnt3 + 1 ELSE CtnCnt3 END
         ,CtnCnt4      = CASE WHEN @cCartonType <> '' AND @nUseSequence = 4  THEN CtnCnt4 + 1 ELSE CtnCnt4 END
         ,CtnCnt5      = CASE WHEN @cCartonType <> '' AND @nUseSequence = 5  THEN CtnCnt5 + 1 ELSE CtnCnt5 END
         ,UserDefine01 = CASE WHEN @cCartonType <> '' AND @nUseSequence = 6  THEN CAST( UserDefine01 AS INT) + 1 ELSE UserDefine01 END
         ,UserDefine02 = CASE WHEN @cCartonType <> '' AND @nUseSequence = 7  THEN CAST( UserDefine02 AS INT) + 1 ELSE UserDefine02 END
         ,UserDefine03 = CASE WHEN @cCartonType <> '' AND @nUseSequence = 8  THEN CAST( UserDefine03 AS INT) + 1 ELSE UserDefine03 END
         ,UserDefine04 = CASE WHEN @cCartonType <> '' AND @nUseSequence = 9  THEN CAST( UserDefine04 AS INT) + 1 ELSE UserDefine04 END
         ,UserDefine05 = CASE WHEN @cCartonType <> '' AND @nUseSequence = 10 THEN CAST( UserDefine05 AS INT) + 1 ELSE UserDefine05 END
         ,UserDefine09 = CASE WHEN @cCartonType <> '' AND @nUseSequence = 11 THEN CAST( UserDefine09 AS INT) + 1 ELSE UserDefine09 END
         ,UserDefine10 = CASE WHEN @cCartonType <> '' AND @nUseSequence = 12 THEN CAST( UserDefine10 AS INT) + 1 ELSE UserDefine10 END
         ,Cube         = CASE WHEN @cCube <> '' THEN Cube + CAST( @cCube AS FLOAT) ELSE Cube END
         ,Weight       = CASE WHEN @cWeight <> '' THEN Weight + CAST( @cWeight AS FLOAT) ELSE Weight END
         ,EditWho      = SUSER_SNAME()
         ,EditDate     = GETDATE()
      WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 198902
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBDtl Fail
      END
   END
   
   -- Save to log
   IF NOT EXISTS( SELECT 1 FROM rdt.rdtCartonToMBOLLog WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND CartonID = @cCartonID)
   BEGIN
      INSERT INTO rdt.rdtCartonToMBOLLog
         (MBOLKey, CartonID, StorerKey, OrderKey, PickSlipNo)
      VALUES
         (@cMBOLKey, @cCartonID, @cStorerKey, @cOrderKey, @cPickSlipNo)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 198903
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS Log Fail
         GOTO RollbackTran
      END
   END
   
   -- PackInfo
   IF @cPickSlipNo <> '' AND @nCartonNo > 0
   BEGIN
      -- Get config
      DECLARE @cUpdatePackInfo  NVARCHAR( 1)
      SET @cUpdatePackInfo = rdt.RDTGetConfig( @nFunc, 'UpdatePackInfo', @cStorerKey)

      IF @cUpdatePackInfo = '1'
      BEGIN
         IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)
         BEGIN
            DECLARE @nQTY INT
            SELECT @nQTY = SUM( QTY) 
            FROM dbo.PackDetail WITH (NOLOCK) 
            WHERE PickSlipNo = @cPickSlipNo 
               AND CartonNo = @nCartonNo
            
            INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, QTY, Weight, Cube, Length, Width, Height, CartonType, RefNo)
            VALUES (@cPickSlipNo, @nCartonNo, @nQTY, @cWeight, @cCube, @cLength, @cWidth, @cHeight, @cCartonType, @cRefNo)
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 198904
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail
               GOTO Quit
            END
         END
         ELSE
         BEGIN
            UPDATE dbo.PackInfo SET
               CartonType = CASE WHEN @cCartonType <> '' THEN @cCartonType ELSE CartonType END,
               Weight     = CASE WHEN @cWeight     <> '' THEN @cWeight     ELSE Weight     END,
               Cube       = CASE WHEN @cCube       <> '' THEN @cCube       ELSE Cube       END,
               RefNo      = CASE WHEN @cRefNo      <> '' THEN @cRefNo      ELSE @cRefNo    END,
               Length     = CASE WHEN @cLength     <> '' THEN @cLength     ELSE Length     END,
               Width      = CASE WHEN @cWidth      <> '' THEN @cWidth      ELSE Width      END,
               Height     = CASE WHEN @cHeight     <> '' THEN @cHeight     ELSE Height     END,
               EditWho    = SUSER_SNAME(),
               EditDate   = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
               AND CartonNo = @nCartonNo
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 198905
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD CtnTyp Err
            END
         END
      END
   END

   -- Get stat
   SELECT @nTotalCarton = COUNT(1)
   FROM rdt.rdtCartonToMBOLLog WITH (NOLOCK)
   WHERE MBOLKey = @cMBOLKey

   -- Check max carton
   DECLARE @cMaxCarton NVARCHAR(20)
   DECLARE @nMaxCarton INT
   SET @cMaxCarton = rdt.rdtGetConfig( @nFunc, 'MaxCarton', @cStorerKey)
   SET @nMaxCarton = ISNULL( TRY_CAST( @cMaxCarton AS INT), 0)
   IF @nMaxCarton > 0 AND @nTotalCarton > @nMaxCarton
   BEGIN
      SET @nErrNo = 198907
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Over MAXCarton
      GOTO RollBackTran
   END
   
   -- EventLog
   EXEC RDT.rdt_STD_EventLog
      @cActionType   = '4',
      @nMobileNo     = @nMobile,
      @nFunctionID   = @nFunc,
      @cFacility     = @cFacility,
      @cStorerKey    = @cStorerKey,
      @cMbolkey      = @cMBOLKey, 
      @cRefNo1       = @cData1,
      @cRefNo2       = @cData2,
      @cRefNo3       = @cData3,
      @cRefNo4       = @cData4,
      @cRefNo5       = @cData5,
      @cOrderKey     = @cOrderKey,
      @cPickSlipNo   = @cPickSlipNo, 
      @cCartonID     = @cCartonID, 
      @cSKU          = @cSKU, 
      @cCartonType   = @cCartonType, 
      @fWeight       = @cWeight, 
      @fCube         = @cCube,  
      @fLength       = @cLength, 
      @fWidth        = @cWidth, 
      @fHeight       = @cHeight
      

   COMMIT TRAN rdt_CartonToMBOL_Confirm -- Only commit change made here
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_CartonToMBOL_Confirm -- Only rollback change made here
Fail:
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO