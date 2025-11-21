SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_1663ExtUpd06                                          */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-07-30 1.0  James    WMS-14383. Created                                */
/* 2020-11-01 1.1  James    Addhoc fix. TL2 only when codelkup setup (james01)*/
/* 2021-04-08 1.2  James    WMS-16024 Standarized use of TrackingNo (james02) */  
/* 2021-06-11 1.3  James    WMS-17260 Modify TL2 trigger (james03)            */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1663ExtUpd06](
   @nMobile       INT,  
   @nFunc         INT,  
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,  
   @nInputKey     INT,  
   @cFacility     NVARCHAR( 5),  
   @cStorerKey    NVARCHAR( 15),  
   @cPalletKey    NVARCHAR( 20),   
   @cPalletLOC    NVARCHAR( 10),   
   @cMBOLKey      NVARCHAR( 10),   
   @cTrackNo      NVARCHAR( 20),   
   @cOrderKey     NVARCHAR( 10),   
   @cShipperKey   NVARCHAR( 15),    
   @cCartonType   NVARCHAR( 10),    
   @cWeight       NVARCHAR( 10),   
   @cOption       NVARCHAR( 1),    
   @nErrNo        INT            OUTPUT,  
   @cErrMsg       NVARCHAR( 20)  OUTPUT  
) AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @bSuccess       INT  
   DECLARE @nTranCount     INT  
   DECLARE @cTableName     NVARCHAR( 30)  
   DECLARE @nCartonNo      INT
   DECLARE @nQTY           INT
   DECLARE @fCube          FLOAT
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cUDF01         NVARCHAR( 60)
   
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_1663ExtUpd06 -- For rollback or commit only our own transaction  

   IF @nFunc = 1663 -- TrackNoToPallet  
   BEGIN  
      IF @nStep = 3 OR -- Track no  
         @nStep = 4 OR -- Weight  
         @nStep = 5    -- Carton type  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- MBOLDetail created  
            IF EXISTS( SELECT 1 FROM MBOLDetail WITH (NOLOCK) WHERE MBOLKey = @cMBOLKey AND OrderKey = @cOrderKey)  
            BEGIN  
               -- Check pack confirm  
               IF EXISTS( SELECT TOP 1 1   
                  FROM PackInfo PInf WITH (NOLOCK)   
                     JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PInf.PickSlipNo)  
                  WHERE PInf.TrackingNo = @cTrackNo -- (james02)    
                     AND PH.OrderKey = @cOrderKey  
                     AND PH.Status = '9')  
               BEGIN  
                  -- Send order confirm to carrier  
                  SELECT @cTableName = Long, 
                         @cUDF01 = UDF01   -- (james03)  
                  FROM  dbo.Codelkup WITH (NOLOCK)  
                  WHERE ListName = 'RDTINSTL2'   
                  AND   StorerKey = @cStorerKey  
                  AND   Code = @cFacility  
                  AND   Code2 = @nFunc  
                  AND   Short = 'TrackNo2Pl'  

                  IF ISNULL( @cTableName, '') <> ''
                  BEGIN
                     -- Send order confirm to carrier  
                     EXEC dbo.ispGenTransmitLog2   
                        @c_TableName      = @cTableName,   
                        @c_Key1           = @cOrderKey,   
                        @c_Key2           = @cUDF01,   -- (james03)
                        @c_Key3           = @cStorerKey,   
                        @c_TransmitBatch  = '',   
                        @b_success        = @bSuccess    OUTPUT,   
                        @n_err            = @nErrNo      OUTPUT,   
                        @c_errmsg         = @cErrMsg     OUTPUT  
  
                     IF @bSuccess <> 1  
                     BEGIN  
                        SET @nErrNo = 156251  
                        SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Gen TLOG3 Fail  
                        GOTO RollBackTran  
                     END  
                  END
               END  
            END  
            
            IF @nStep = 5    -- Carton type 
            BEGIN
               -- Sephora B2C orders, one orders one trackingno one carton
               SET @nCartonNo = 1

               SELECT @cPickSlipNo = PickSlipNo
               FROM dbo.PackHeader WITH (NOLOCK)
               WHERE StorerKey = @cStorerKey
               AND   OrderKey = @cOrderKey

               IF @@ROWCOUNT = 0
               BEGIN  
                  SET @nErrNo = 156252  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No PickSlip  
                  GOTO RollBackTran  
               END  

               SELECT @nQTY = ISNULL( SUM( Qty), 0)
               FROM dbo.PackDetail WITH (NOLOCK)
               WHERE PickSlipNo = @cPickSlipNo
            
               SELECT @fCube = CZ.[Cube] 
               FROM dbo.CARTONIZATION CZ WITH (NOLOCK)
               JOIN dbo.Storer ST WITH (NOLOCK) ON ( CZ.CartonizationGroup = ST.CartonGroup)
               WHERE ST.StorerKey = @cStorerKey
               AND   CZ.CartonType = @cCartonType
            
               IF NOT EXISTS (SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo)  
               BEGIN  
                  INSERT INTO dbo.PackInfo (PickslipNo, CartonNo, Qty, Weight, Cube, CartonType)  
                  VALUES (@cPickSlipNo, @nCartonNo, @nQTY, CAST( @cWeight AS FLOAT), @fCube, @cCartonType)  

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 156253  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --INSPackInfFail  
                     GOTO RollBackTran  
                  END  
               END  
               ELSE  
               BEGIN  
                  UPDATE dbo.PackInfo SET  
                     CartonType = @cCartonType,  
                     Weight = CAST( @cWeight AS FLOAT),  
                     Cube = @fCube  
                  WHERE PickSlipNo = @cPickSlipNo  
                  AND   CartonNo = @nCartonNo

                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 156254  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UPDPackInfFail  
                     GOTO RollBackTran  
                  END  
               END
            END   -- Carton type
         END  
      END  
        
      IF @nStep = 6 -- Close pallet  
      BEGIN  
         IF rdt.rdtGetConfig( @nFunc, 'MoveCarton', @cStorerKey) = '1'  
         BEGIN  
            DECLARE @cFromLOT       NVARCHAR(10)  
            DECLARE @cFromLOC       NVARCHAR(10)  
            DECLARE @cFromID        NVARCHAR(18)  
            DECLARE @cSKU           NVARCHAR(20)  
            DECLARE @cCaseID        NVARCHAR(20)  
            DECLARE @cLabelNo       NVARCHAR(20)  
            DECLARE @cPickDetailKey NVARCHAR(10)  
              
            DECLARE @curPL CURSOR  
            DECLARE @curPD CURSOR  
              
            -- Loop pallet detail  
            SET @curPL = CURSOR FOR  
               SELECT CaseID  
               FROM PalletDetail WITH (NOLOCK)  
               WHERE StorerKey = @cStorerKey  
                  AND PalletKey = @cPalletKey  
               ORDER BY PalletLineNumber  
            OPEN @curPL  
            FETCH NEXT FROM @curPL INTO @cCaseID  
            WHILE @@FETCH_STATUS = 0  
            BEGIN  
               -- Get PickSlipNo  
               SELECT   
                  @cPickSlipNo = PH.PickSlipNo,   
                  @nCartonNo = CartonNo  
               FROM PackInfo PINF WITH (NOLOCK)  
                  JOIN PackHeader PH WITH (NOLOCK) ON (PH.PickSlipNo = PINF.PickSlipNo)  
               WHERE PH.StorerKey = @cStorerKey  
                  AND PINF.TrackingNo = @cCaseID   -- (james02)    
  
               -- Get LabelNo  
               SELECT TOP 1 @cLabelNo = LabelNo FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND CartonNo = @nCartonNo  
  
               -- Move carton  
               SET @curPD = CURSOR FOR  
                  SELECT LOT, LOC, ID, SKU, SUM( QTY)  
                  FROM PickDetail WITH (NOLOCK)  
                  WHERE StorerKey = @cStorerKey  
                     AND CaseID = @cLabelNo  
                     AND Status = '5'  
                     AND QTY > 0  
                     AND (LOC <> @cPalletLOC OR ID <> @cPalletKey) -- Change LOC / ID  
                  GROUP BY LOT, LOC, ID, SKU  
               OPEN @curPD  
               FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY  
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
                  -- EXEC move  
                  EXECUTE rdt.rdt_Move  
                     @nMobile     = @nMobile,  
                     @cLangCode   = @cLangCode,  
                     @nErrNo      = @nErrNo  OUTPUT,  
                     @cErrMsg     = @cErrMsg OUTPUT,   
                     @cSourceType = 'rdt_1663ExtUpd06',  
                     @cStorerKey  = @cStorerKey,  
                     @cFacility   = @cFacility,  
                     @cFromLOC    = @cFromLOC,  
                     @cToLOC      = @cPalletLOC,  
                     @cFromID     = @cFromID,       
                     @cToID       = @cPalletKey,        
                     @cFromLOT    = @cFromLOT,    
                     @cSKU        = @cSKU,  
                     @nQTY        = @nQTY,  
                     @nQTYAlloc   = 0,  
                     @nQTYPick    = @nQTY,   
                     @nFunc       = @nFunc,   
                     @cCaseID     = @cLabelNo  
                  IF @nErrNo <> 0  
                     GOTO RollbackTran  
                    
                  FETCH NEXT FROM @curPD INTO @cFromLOT, @cFromLOC, @cFromID, @cSKU, @nQTY  
               END  
                 
               FETCH NEXT FROM @curPL INTO @cCaseID  
            END  
              
            COMMIT TRAN rdt_1663ExtUpd06  
         END  
         
         DECLARE @cPalletLabel      NVARCHAR( 10)
         DECLARE @cPaperPrinter     NVARCHAR( 10)
         
         SELECT @cPaperPrinter = Printer_Paper
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile
         
         SET @cPalletLabel = rdt.rdtGetConfig( @nFunc, 'PalletLabel', @cStorerKey)
         IF @cPalletLabel = '0'
            SET @cPalletLabel = ''
            
         IF @cPalletLabel <> ''
         BEGIN
            DECLARE @tPalletLabel AS VariableTable
            DELETE FROM @tPalletLabel
            INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cPalletKey',   @cPalletKey)
            INSERT INTO @tPalletLabel (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)

            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter, 
               @cPalletLabel,  -- Report type
               @tPalletLabel, -- Report params
               'rdt_1663ExtUpd06', 
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT 

            IF @nErrNo <> 0
               GOTO RollBackTran
         END
      END  
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_1663ExtUpd06  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO