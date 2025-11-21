SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_TrackNoToPallet_Confirm                               */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2017-06-07 1.0  Ung      WMS-2016 Created                                  */
/* 2017-08-15 1.1  Ung      WMS-2692                                          */
/*                          Add TrackOrderWeight auto calc SKU, SKU + Carton  */
/*                          Add auto copy PackInfo.CartonType/Cube/Weight     */
/* 2018-07-18 1.2  Ung      WMS-4304 Add PalletDetail.UserDefine01            */
/* 2019-04-24 1.3  James    WMS-8751 Enable accumulate mbold weight (james01) */
/* 2019-07-16 1.4  Ung      Fix MBOL shipped                                  */
/* 2020-10-01 1.5  Chermaine WMS-15370 Add StdEventLog (cc01)                 */
/* 2021-04-08 1.6  James    WMS-16024 Standarized use of TrackingNo (james02) */
/* 2021-09-23 1.7  James    WMS-17937 Add update cartontype and weight        */
/*                          into packinfo table                               */
/* 2022-06-23 1.8  Ung      WMS-19666 Add recheck status                      */
/* 2023-04-13 1.9  Ung      WMS-22284 Add MBOL accumulate weight, cube        */
/* 2023-07-27 2.0  James    WMS-23006 Insert PackInfo if not exists (james03) */
/******************************************************************************/

CREATE   PROC [RDT].[rdt_TrackNoToPallet_Confirm] (
   @nMobile           INT,           
   @nFunc             INT,           
   @cLangCode         NVARCHAR( 3),  
   @nStep             INT,           
   @nInputKey         INT,           
   @cFacility         NVARCHAR( 5),   
   @cStorerKey        NVARCHAR( 15), 
   @cPalletKey        NVARCHAR( 20), 
   @cMBOLKey          NVARCHAR( 10), 
   @cTrackNo          NVARCHAR( 20), 
   @cOrderKey         NVARCHAR( 10), 
   @cShipperKey       NVARCHAR( 15), 
   @cCartonType       NVARCHAR( 10),  
   @cWeight           NVARCHAR( 10), 
   @cCube             NVARCHAR( 10), 
   @cUseSequence      NVARCHAR( 10), 
   @cTrackCartonType  NVARCHAR( 1), 
   @cTrackOrderWeight NVARCHAR( 1), 
   @cTrackOrderCube   NVARCHAR( 1), 
   @cPalletLOC        NVARCHAR( 10), 
   @cSKU              NVARCHAR( 20), 
   @nErrNo            INT            OUTPUT,
   @cErrMsg           NVARCHAR( 20)  OUTPUT
) AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   /***********************************************************************************************
                                       Recheck status (same as parent)
   ***********************************************************************************************/
   -- This is to close the gap where after scanned tracking no, and before carton type/weight/cube, 
   -- interface receive to cancel the order
   IF @nStep <> 3 -- Tracking no. 
   BEGIN
      -- Get order info  
      DECLARE @cStatus NVARCHAR(10)  
      DECLARE @cSOStatus NVARCHAR(10)  
      SELECT  
         @cStatus = Status,  
         @cSOStatus = SOStatus
      FROM dbo.Orders WITH (NOLOCK)  
      WHERE OrderKey = @cOrderKey  

      -- Check order status  
      IF @cStatus < '5'  
      BEGIN  
         SET @nErrNo = 111267  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderNotPick  
         EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
         GOTO Quit  
      END  
      
      DECLARE @cExtendedCheckSOStatusSP NVARCHAR(20)
      SET @cExtendedCheckSOStatusSP = rdt.RDTGetConfig( @nFunc, 'ExtendedCheckSOStatusSP', @cStorerKey)
      IF @cExtendedCheckSOStatusSP = '0'
         SET @cExtendedCheckSOStatusSP = ''

      -- Extended validate sostatus
      IF @cExtendedCheckSOStatusSP <> ''
      BEGIN
         IF EXISTS( SELECT 1 FROM dbo.sysobjects WHERE name = @cExtendedCheckSOStatusSP AND type = 'P')
         BEGIN
            DECLARE @cSQL NVARCHAR( MAX)
            DECLARE @cSQLParam NVARCHAR( MAX)
            DECLARE @cOption NVARCHAR(1)
            DECLARE @tValidateSOStatus VariableTable
            SET @cSQL = 'EXEC rdt.' + RTRIM( @cExtendedCheckSOStatusSP) +
               ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, ' +
               ' @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, ' + 
               ' @cSOStatus, @tValidateSOStatus, @nErrNo OUTPUT, @cErrMsg OUTPUT '
            SET @cSQLParam =
               '@nMobile         INT,           ' +
               '@nFunc           INT,           ' +
               '@cLangCode       NVARCHAR( 3),  ' +
               '@nStep           INT,           ' +
               '@nInputKey       INT,           ' +
               '@cFacility       NVARCHAR( 5),  ' +
               '@cStorerKey      NVARCHAR( 15), ' +
               '@cPalletKey      NVARCHAR( 20), ' + 
               '@cPalletLOC      NVARCHAR( 10), ' + 
               '@cMBOLKey        NVARCHAR( 10), ' + 
               '@cTrackNo        NVARCHAR( 20), ' + 
               '@cOrderKey       NVARCHAR( 10), ' + 
               '@cShipperKey     NVARCHAR( 15), ' +  
               '@cCartonType     NVARCHAR( 10), ' +  
               '@cWeight         NVARCHAR( 10), ' + 
               '@cOption         NVARCHAR( 1),  ' + 
               '@cSOStatus       NVARCHAR( 10), ' + 
               '@tValidateSOStatus VariableTable   READONLY, ' + 
               '@nErrNo          INT               OUTPUT,   ' +
               '@cErrMsg         NVARCHAR( 20)     OUTPUT    '

            EXEC sp_ExecuteSQL @cSQL, @cSQLParam,
               @nMobile, @nFunc, @cLangCode, 3, @nInputKey, @cFacility, @cStorerKey, -- Force step = 3, same as parent
               @cPalletKey, @cPalletLOC, @cMBOLKey, @cTrackNo, @cOrderKey, @cShipperKey, @cCartonType, @cWeight, @cOption, 
               @cSOStatus, @tValidateSOStatus, @nErrNo OUTPUT, @cErrMsg OUTPUT 

            IF @nErrNo <> 0
            BEGIN
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg
               GOTO Quit
            END
         END
      END
      ELSE
      BEGIN
         -- Check extern status  
         IF @cSOStatus = 'HOLD'  
         BEGIN  
            SET @nErrNo = 111268  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order on HOLD  
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
            GOTO Quit  
         END  
     
         ELSE IF @cSOStatus = 'PENDPACK'  
         BEGIN  
            SET @nErrNo = 111269  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending Update  
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
            GOTO Quit  
         END  
     
         ELSE IF @cSOStatus = 'PENDCANC'  
         BEGIN  
            SET @nErrNo = 111270  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Pending CANC  
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
            GOTO Quit  
         END  
     
         IF @cSOStatus = 'CANC'  
         BEGIN  
            SET @nErrNo = 111271  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Order CANCEL  
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
            GOTO Quit  
         END  
     
         IF @cSOStatus = 'PACK&HOLD'  
         BEGIN  
            SET @nErrNo = 111284  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderPACK&HOLD  
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
            GOTO Quit  
         END  
     
         -- Check SOStatus blocked  
         IF EXISTS( SELECT TOP 1 1 FROM CodeLKUP WITH (NOLOCK) WHERE ListName = 'SOSTSBLOCK' AND Code = @cSOStatus AND StorerKey = @cStorerKey AND Code2 = @nFunc)  
         BEGIN  
            SET @nErrNo = 111286  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Status blocked  
            EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', @nErrNo, @cErrMsg  
            GOTO Quit  
         END  
      END
   END
   
   /***********************************************************************************************
                                              Confirm
   ***********************************************************************************************/
   DECLARE @nWeight        FLOAT
   DECLARE @nCube          FLOAT
   DECLARE @nUseSequence   INT
   DECLARE @cLoadKey       NVARCHAR(10)
   DECLARE @nIsPackInfoExists INT = 1
   
   SET @nWeight = 0
   SET @nCube = 0 

   -- Weight (key-in)
   -- 6 = ACccumulate each carton weight (user key-in) into mboldetail
   IF @cTrackOrderWeight IN ( '1', '6')
      SET @nWeight = CAST( @cWeight AS FLOAT)

   -- Weight (SKU)
   ELSE IF @cTrackOrderWeight IN ('2', '3')
   BEGIN
      SELECT @nWeight = ISNULL( SUM( SKU.STDGrossWGT * PD.QTY), 0) 
      FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.SKU SKU WITH (NOLOCK) ON (SKU.StorerKey = PD.StorerKey AND SKU.SKU = PD.SKU)
      WHERE PD.OrderKey = @cOrderKey

      -- Weight (SKU + carton)
      IF @cTrackOrderWeight = '3'
      BEGIN         
         -- Get carton type info
         DECLARE @nCartonWeight FLOAT
         SELECT @nCartonWeight = CartonWeight
         FROM Cartonization C WITH (NOLOCK)
            JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.CartonType = @cCartonType
            
         SET @nWeight = @nWeight + @nCartonWeight
      END
   END
   
   IF @cTrackOrderCube = '1'
      SET @nCube = CAST( @cCube AS FLOAT)

   IF @cTrackCartonType IN ('1', '2')
      SET @nUseSequence = CAST( @cUseSequence AS INT)

   -- Copy carton type, weight, cube from PackInfo
   IF @cTrackCartonType = '5' OR 
      @cTrackOrderCube = '5' OR
      @cTrackOrderWeight = '5'
   BEGIN
      -- Get PickSlipNo
      DECLARE @cPickSlipNo NVARCHAR(10)
      SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cOrderKey 
      
      -- Get PackInfo info
      SELECT 
         @cCartonType = CASE WHEN @cTrackCartonType = '5' THEN CartonType ELSE @cCartonType END, 
         @nWeight = CASE WHEN @cTrackOrderWeight = '5' THEN Weight ELSE @nWeight END, 
         @nCube = CASE WHEN @cTrackOrderCube = '5' THEN Cube ELSE @nCube END
      FROM PackInfo WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo 
         AND TrackingNo = @cTrackNo -- (james02)
      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 111304
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Missing PkInfo
         GOTO Quit
      END

      IF @cTrackCartonType = '5'
      BEGIN
         -- Get carton type info
         SELECT @nUseSequence = UseSequence
         FROM Cartonization C WITH (NOLOCK)
            JOIN Storer S WITH (NOLOCK) ON (C.CartonizationGroup = S.CartonGroup)
         WHERE S.StorerKey = @cStorerKey
            AND C.CartonType = @cCartonType
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 111305
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Bad CartonType
            GOTO Quit
         END
      END
   END

   -- Handling transaction
   DECLARE @nTranCount  INT
   SET @nTranCount = @@TRANCOUNT
   BEGIN TRAN  -- Begin our own transaction
   SAVE TRAN rdt_TrackNoToPallet_Confirm -- For rollback or commit only our own transaction

   -- PalletDetail
   IF NOT EXISTS( SELECT 1 FROM PalletDetail WITH (NOLOCK) WHERE PalletKey = @cPalletKey AND CaseID = @cTrackNo)
   BEGIN
      INSERT INTO PalletDetail
         (PalletKey, PalletLineNumber, CaseID, StorerKey, SKU, LOC, QTY, Status, UserDefine01)
      VALUES
         (@cPalletKey, '0', @cTrackNo, @cStorerKey, @cSKU, @cPalletLOC, 0, '0', @cOrderKey)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 111301
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS PLDtl Fail
         GOTO RollbackTran
      END
   END

   -- Insert MBOLDetail
   IF NOT EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)
   BEGIN
      -- Check MBOL shipped (temporary workaround, instead of changing ntrMBOLDetailAdd trigger)
      IF EXISTS( SELECT 1 FROM dbo.MBOL WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND Status = '9')
      BEGIN
         SET @nErrNo = 111306
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MBOL Shipped
         GOTO RollbackTran
      END
      
      DECLARE 
         @nCtnCnt1 INT, 
         @nCtnCnt2 INT, 
         @nCtnCnt3 INT, 
         @nCtnCnt4 INT, 
         @nCtnCnt5 INT, 
         @cUDF01   NVARCHAR(20), 
         @cUDF02   NVARCHAR(20), 
         @cUDF03   NVARCHAR(20), 
         @cUDF04   NVARCHAR(20), 
         @cUDF05   NVARCHAR(20), 
         @cUDF09   NVARCHAR(10), 
         @cUDF10   NVARCHAR(10)
      
      SELECT 
         @nCtnCnt1 = '', 
         @nCtnCnt2 = '', 
         @nCtnCnt3 = '', 
         @nCtnCnt4 = '', 
         @nCtnCnt5 = '', 
         @cUDF01 = '', 
         @cUDF02 = '', 
         @cUDF03 = '', 
         @cUDF04 = '', 
         @cUDF05 = '', 
         @cUDF09 = '', 
         @cUDF10 = ''
      
      IF @cTrackCartonType <> ''  -- IN ('1', '2')
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
      
      SELECT @cLoadKey = LoadKey FROM LoadPlanDetail WITH (NOLOCK) WHERE OrderKey = @cOrderKey
      
      INSERT INTO dbo.MBOLDetail 
         (MBOLKey, MBOLLineNumber, OrderKey, LoadKey, AddWho, AddDate, EditWho, EditDate, Weight, Cube, 
          CtnCnt1, CtnCnt2, CtnCnt3, CtnCnt4, CtnCnt5, UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine09, UserDefine10)
      VALUES 
         (@cMBOLKey, '00000', @cOrderKey, @cLoadKey, 'rdt.' + SUSER_SNAME(), GETDATE(), 'rdt.' + SUSER_SNAME(), GETDATE(), @nWeight, @nCube, 
          @nCtnCnt1, @nCtnCnt2, @nCtnCnt3, @nCtnCnt4, @nCtnCnt5, @cUDF01, @cUDF02, @cUDF03, @cUDF04, @cUDF05, @cUDF09, @cUDF10)
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 111302
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INS MBDtl Fail
         GOTO RollbackTran
      END
   END
   ELSE
   BEGIN
      UPDATE dbo.MBOLDetail SET
          CtnCnt1      = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 1  THEN CtnCnt1 + 1 ELSE CtnCnt1 END
         ,CtnCnt2      = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 2  THEN CtnCnt2 + 1 ELSE CtnCnt2 END
         ,CtnCnt3      = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 3  THEN CtnCnt3 + 1 ELSE CtnCnt3 END
         ,CtnCnt4      = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 4  THEN CtnCnt4 + 1 ELSE CtnCnt4 END
         ,CtnCnt5      = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 5  THEN CtnCnt5 + 1 ELSE CtnCnt5 END
         ,UserDefine01 = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 6  THEN CAST( UserDefine01 AS INT) + 1 ELSE UserDefine01 END
         ,UserDefine02 = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 7  THEN CAST( UserDefine02 AS INT) + 1 ELSE UserDefine02 END
         ,UserDefine03 = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 8  THEN CAST( UserDefine03 AS INT) + 1 ELSE UserDefine03 END
         ,UserDefine04 = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 9  THEN CAST( UserDefine04 AS INT) + 1 ELSE UserDefine04 END
         ,UserDefine05 = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 10 THEN CAST( UserDefine05 AS INT) + 1 ELSE UserDefine05 END
         ,UserDefine09 = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 11 THEN CAST( UserDefine09 AS INT) + 1 ELSE UserDefine09 END
         ,UserDefine10 = CASE WHEN @cTrackCartonType IN ('1', '2') AND @nUseSequence = 12 THEN CAST( UserDefine10 AS INT) + 1 ELSE UserDefine10 END
         ,Cube         = CASE WHEN @cTrackOrderCube > '0' THEN Cube + @nCube ELSE Cube END
         ,Weight       = CASE WHEN @cTrackOrderWeight > '0' THEN Weight + @nWeight ELSE Weight END
         ,EditWho      = SUSER_SNAME()
         ,EditDate     = GETDATE()
      WHERE MBOLKey = @cMBOLKey
         AND OrderKey = @cOrderKey
      IF @@ERROR <> 0
      BEGIN
         SET @nErrNo = 111303
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD MBDtl Fail
      END
   END
   
   DECLARE @cPackInfoCartonType  NVARCHAR( 1)
   DECLARE @cPackInfoWeight      NVARCHAR( 1)
   DECLARE @cPackInfoCube        NVARCHAR( 1)
   DECLARE @nCartonNo            INT
   DECLARE @cPackInfoTrackNo     NVARCHAR( 1)
   
   SET @cPackInfoCartonType = rdt.RDTGetConfig( @nFunc, 'PackInfoCartonType', @cStorerKey)
   SET @cPackInfoWeight = rdt.RDTGetConfig( @nFunc, 'PackInfoWeight', @cStorerKey)
   SET @cPackInfoCube = rdt.RDTGetConfig( @nFunc, 'PackInfoCube', @cStorerKey)
   SET @cPackInfoTrackNo = rdt.RDTGetConfig( @nFunc, 'PackInfoTrackNo', @cStorerKey)
   
   IF ISNULL( @cPickSlipNo, '') = ''
      SELECT @cPickSlipNo = PickSlipNo FROM PackHeader WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND OrderKey = @cOrderKey
   
   SELECT @nCartonNo = CartonNo
   FROM dbo.PackInfo WITH (NOLOCK)
   WHERE PickSlipNo = @cPickSlipNo
   AND   TrackingNo = @cTrackNo
   
   IF @@ROWCOUNT = 0
   BEGIN
      SELECT TOP 1 @nCartonNo = PD.CartonNo
      FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
      JOIN dbo.Orders O WITH (NOLOCK) ON ( PH.OrderKey = O.OrderKey) 
      WHERE PH.PickSlipNo = @cPickSlipNo
      AND   O.TrackingNo = @cTrackNo
      ORDER BY 1
      
      IF NOT EXISTS ( SELECT 1 
                     FROM dbo.PackInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   CartonNo = @nCartonNo)
          SET @nIsPackInfoExists = 0                   
   END
   ELSE
   	SET @nIsPackInfoExists = 1

   IF @nIsPackInfoExists = 0
   BEGIN
   	IF ISNULL( @nCartonNo, 0) > 0
   	BEGIN
   	   INSERT INTO dbo.PackInfo
   	   ( PickSlipNo, CartonNo, [Weight], [Cube], Qty, AddDate, AddWho, EditDate, EditWho, 
           CartonType, TrackingNo) VALUES
         ( @cPickSlipNo, @nCartonNo, @nWeight, @nCube, 0, GETDATE(), SUSER_SNAME(), GETDATE(), SUSER_SNAME(),
           @cCartonType, @cTrackNo)
        
         IF @@ERROR <> 0
         BEGIN
            SET @nErrNo = 111310
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InsPackInfoEr
         END
      END
   END
   ELSE
   BEGIN
      IF @nCartonNo > 0
      BEGIN
         IF CAST( @cTrackCartonType AS INT) > 0 AND @cPackInfoCartonType = '1'
         BEGIN
            UPDATE dbo.PackInfo SET
               CartonType = @cCartonType,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
      
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 111307
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD CtnTyp Err
            END
         END
      
         IF CAST( @cTrackOrderWeight AS INT) > 0 AND @cPackInfoWeight = '1'
         BEGIN
            UPDATE dbo.PackInfo SET 
               [Weight] = @nWeight,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
      
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 111308
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Weight Err
            END
         END
      
         IF CAST( @cTrackOrderCube AS INT) > 0 AND @cPackInfoCube = '1'
         BEGIN
            UPDATE dbo.PackInfo SET 
               [Cube] = @nCube,
               EditWho = SUSER_SNAME(),
               EditDate = GETDATE()
            WHERE PickSlipNo = @cPickSlipNo
            AND   CartonNo = @nCartonNo
      
            IF @@ERROR <> 0
            BEGIN
               SET @nErrNo = 111309
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD Cube Err
            END
         END

         IF @cPackInfoTrackNo = '1'
         BEGIN
         	IF EXISTS ( SELECT 1 
         	            FROM dbo.PackInfo WITH (NOLOCK)
         	            WHERE PickSlipNo = @cPickSlipNo
         	            AND   CartonNo = @nCartonNo
         	            AND   ISNULL( TrackingNo, '') = '')
            BEGIN
               UPDATE dbo.PackInfo SET
                  TrackingNo = @cTrackNo,
                  EditWho = SUSER_SNAME(),
                  EditDate = GETDATE()
               WHERE PickSlipNo = @cPickSlipNo
               AND   CartonNo = @nCartonNo
      
               IF @@ERROR <> 0
               BEGIN
                  SET @nErrNo = 111311
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPD TrackNo Err
               END
            END
         END
      END 
   END
   
   COMMIT TRAN rdt_TrackNoToPallet_Confirm

   DECLARE @cUserName NVARCHAR(10)
   SET @cUserName = LEFT( SUSER_SNAME(), 10)

   -- Eventlog
   EXEC RDT.rdt_STD_EventLog
      @cActionType = '3', -- Creating MBOLDetail
      @cUserID     = @cUserName,
      @nMobileNo   = @nMobile,
      @nFunctionID = @nFunc,
      @cFacility   = @cFacility,
      @cStorerKey  = @cStorerkey,
      @cRefNo1     = @cMBOLKey,
      -- @cRefNo2     = @cLoadKey,
      @cRefNo3     = @cOrderKey,
      @cMBOLKey    = @cMBOLKey,
      @cOrderKey   = @cOrderKey,
      @cTrackingNo = @cTrackNo, 
      @cCartonType = @cCartonType, 
      @fWeight     = @nWeight, 
      @fCube       = @nCube
   
   GOTO Quit

RollBackTran:
   ROLLBACK TRAN rdt_TrackNoToPallet_Confirm -- Only rollback change made here
Quit:
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started
      COMMIT TRAN
END

GO