SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_838ExtUpd03                                     */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev  Author      Purposes                                 */  
/* 17-10-2018 1.0  James       WMS6549 Created                          */  
/* 04-04-2019 1.1  Ung         WMS-8134 Add PackData1..3 parameter      */
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_838ExtUpd03] (  
   @nMobile          INT,  
   @nFunc            INT,  
   @cLangCode        NVARCHAR( 3),  
   @nStep            INT,  
   @nInputKey        INT,  
   @cFacility        NVARCHAR( 5),  
   @cStorerKey       NVARCHAR( 15),  
   @cPickSlipNo      NVARCHAR( 10),  
   @cFromDropID      NVARCHAR( 20),  
   @nCartonNo        INT,  
   @cLabelNo         NVARCHAR( 20),  
   @cSKU             NVARCHAR( 20),  
   @nQTY             INT,  
   @cUCCNo           NVARCHAR( 20),  
   @cCartonType      NVARCHAR( 10),  
   @cCube            NVARCHAR( 10),  
   @cWeight          NVARCHAR( 10),  
   @cRefNo           NVARCHAR( 20),  
   @cSerialNo        NVARCHAR( 30),  
   @nSerialQTY       INT,  
   @cOption          NVARCHAR( 1),  
   @cPackDtlRefNo    NVARCHAR( 20),   
   @cPackDtlRefNo2   NVARCHAR( 20),   
   @cPackDtlUPC      NVARCHAR( 30),   
   @cPackDtlDropID   NVARCHAR( 20),   
   @cPackData1       NVARCHAR( 30), 
   @cPackData2       NVARCHAR( 30), 
   @cPackData3       NVARCHAR( 30), 
   @nErrNo           INT            OUTPUT,  
   @cErrMsg          NVARCHAR( 20)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @cLabelLine        NVARCHAR( 5)  
   DECLARE @cUserName         NVARCHAR( 18)
   DECLARE @nTranCount        INT  
   DECLARE @cRoute            NVARCHAR( 10)
   DECLARE @cConsigneeKey     NVARCHAR( 15)
   DECLARE @cExternOrderKey   NVARCHAR( 30)
   DECLARE @cCartonGroup      NVARCHAR( 10)
   DECLARE @cOrderKey         NVARCHAR( 10)
   DECLARE @nWeight           FLOAT  
   DECLARE @nCube             FLOAT  
   DECLARE @nCartonWeight     FLOAT  
   DECLARE @nCartonCube       FLOAT  
   DECLARE @nCartonLength     FLOAT  
   DECLARE @nCartonWidth      FLOAT  
   DECLARE @nCartonHeight     FLOAT  

  
   SET @nTranCount = @@TRANCOUNT  
  
   IF @nFunc = 838 -- Pack  
   BEGIN  
      IF @nStep = 3 -- SKU  
      BEGIN  
         IF @nInputKey = 1 -- ENTER  
         BEGIN  
            -- Without ToDropID  
            IF @cPackDtlDropID = ''  
               GOTO Quit  
                 
            -- New carton without SKU QTY  
            IF @nCartonNo = 0  
               GOTO Quit  
           
            -- PackDetail need to update  
            IF EXISTS( SELECT 1  
               FROM dbo.PackDetail WITH (NOLOCK)  
               WHERE PickSlipNo = @cPickSlipNo  
                  AND CartonNo = @nCartonNo  
                  AND LabelNo = @cLabelNo  
                  AND DropID <> @cPackDtlDropID)  
            BEGIN  
               -- Handling transaction  
               BEGIN TRAN  -- Begin our own transaction  
               SAVE TRAN rdt_838ExtUpd03 -- For rollback or commit only our own transaction  
              
               DECLARE @curPD CURSOR  
               SET @curPD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT LabelLine  
                  FROM dbo.PackDetail WITH (NOLOCK)  
                  WHERE PickSlipNo = @cPickSlipNo  
                     AND CartonNo = @nCartonNo  
                     AND LabelNo = @cLabelNo  
                     AND DropID <> @cPackDtlDropID  
              
               -- Loop PickDetail  
               OPEN @curPD  
               FETCH NEXT FROM @curPD INTO @cLabelLine  
               WHILE @@FETCH_STATUS = 0  
               BEGIN  
                  -- Update Packdetail  
                  UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
                     DropID = @cPackDtlDropID,   
                     EditWho = 'rdt.' + SUSER_SNAME(),  
                     EditDate = GETDATE(),  
                     ArchiveCop = NULL  
                  WHERE PickSlipNo = @cPickSlipNo  
                     AND CartonNo = @nCartonNo  
                     AND LabelNo = @cLabelNo  
                     AND LabelLine = @cLabelLine  
                  IF @@ERROR <> 0  
                  BEGIN  
                     SET @nErrNo = 130401  
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackDtlFail  
                     GOTO RollBackTran  
                  END  
                 
                  FETCH NEXT FROM @curPD INTO @cLabelLine  
               END  
           
               COMMIT TRAN rdt_838ExtUpd03  
            END  
         END  

         IF @nInputKey = 0 -- ESC
         BEGIN
            -- Get carton info
            SET @cCartontype = ''
            SELECT TOP 1 
               @cCartonType = CartonType, 
               @nCartonWeight = ISNULL( CartonWeight, 0), 
               @nCartonCube = ISNULL( Cube, 0), 
               @nCartonLength = ISNULL( CartonLength, 0),
               @nCartonWidth  = ISNULL( CartonWidth, 0), 
               @nCartonHeight = ISNULL( CartonHeight, 0)
            FROM Storer S WITH (NOLOCK)
               JOIN Cartonization C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)
            WHERE S.StorerKey = @cStorerKey
            ORDER BY C.UseSequence
            
            -- Loop missing PackInfo
            SET @curPD = CURSOR FOR
               SELECT DISTINCT PD.CartonNo
               FROM PackDetail PD WITH (NOLOCK) 
               WHERE PD.PickSlipNo = @cPickSlipNo
               AND   NOT EXISTS ( SELECT 1 FROM dbo.PackInfo PIF WITH (NOLOCK) 
                                  WHERE PD.PickSlipNo = PIF.PickSlipNo 
                                  AND   PD.CartonNo = PIF.CartonNo 
                                  AND   ISNULL( UCCNo, '') = '')
            OPEN @curPD
            FETCH NEXT FROM @curPD INTO @nCartonNo
            WHILE @@FETCH_STATUS = 0
            BEGIN
               -- Get PackDetail info
               SELECT 
                  @nQTY = SUM( PD.QTY), 
                  @nWeight = SUM( PD.QTY * SKU.STDGrossWGT), 
                  @nCube = SUM( PD.QTY * SKU.STDCube)
               FROM PackDetail PD WITH (NOLOCK) 
                  JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
               WHERE PD.PickSlipNo = @cPickSlipNo
                  AND PD.CartonNo = @nCartonNo               
               
               -- Calc weight, cube
               SET @nWeight = @nWeight + @nCartonWeight 
               IF @nCartonCube <> 0
                  SET @nCube = @nCartonCube            

               IF NOT EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK) 
                               WHERE PickSlipNo = @cPickSlipNo 
                               AND   CartonNo = @nCartonNo)
               BEGIN
                  -- Insert PackInfo
                  INSERT INTO PackInfo (PickSlipNo, CartonNo, Weight, Cube, Qty, Cartontype, Length, Width, Height)
                  VALUES (@cPickSlipNo, @nCartonNo, @nWeight, @nCube, @nQTY, @cCartonType, @nCartonLength, @nCartonWidth, @nCartonHeight)

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 130402
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS PKInf Fail
                     GOTO RollBackTran
                  END
               END
               ELSE
               BEGIN
                  UPDATE dbo.PackInfo SET
                     Weight = @nWeight, 
                     Cube = @nCube, 
                     Qty = @nQTY
                  WHERE PickSlipNo = @cPickSlipNo
                  AND   CartonNo = @nCartonNo

                  IF @@ERROR <> 0
                  BEGIN
                     SET @nErrNo = 130403
                     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- UPD PKInf Fail
                     GOTO RollBackTran
                  END
               END
                              
               FETCH NEXT FROM @curPD INTO @nCartonNo
            END
         END
      END  

      IF @nStep = 8 -- UCC
      BEGIN
         SELECT @cUserName = UserName
         FROM RDT.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         DECLARE CUR_UPDUPC CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT LabelLine
         FROM dbo.PackDetail WITH (NOLOCK)  
         WHERE PickSlipNo = @cPickSlipNo  
            AND CartonNo = @nCartonNo  
            AND LabelNo = @cLabelNo
            AND AddWho = 'rdt.' + @cUserName
            AND ISNULL( UPC, '') = ''
         ORDER BY CartonNo, LabelNo, LabelLine
         OPEN CUR_UPDUPC
         FETCH NEXT FROM CUR_UPDUPC INTO @cLabelLine
         WHILE @@FETCH_STATUS = 0
         BEGIN
            -- Update Packdetail  
            UPDATE dbo.PackDetail WITH (ROWLOCK) SET  
               UPC = @cUCCNo,   
               EditWho = 'rdt.' + SUSER_SNAME(),  
               EditDate = GETDATE(),  
               ArchiveCop = NULL  
            WHERE PickSlipNo = @cPickSlipNo  
               AND CartonNo = @nCartonNo  
               AND LabelNo = @cLabelNo  
               AND LabelLine = @cLabelLine  

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 130404  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackUPCFail  
               GOTO RollBackTran  
            END  

            FETCH NEXT FROM CUR_UPDUPC INTO @cLabelLine
         END
         CLOSE CUR_UPDUPC
         DEALLOCATE CUR_UPDUPC

         IF EXISTS ( SELECT 1 FROM dbo.PackHeader WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   ( ISNULL( Route, '') = '' OR 
                             ISNULL( OrderRefNo, '') = '' OR 
                             ISNULL( ConsigneeKey, '') = '' OR 
                             ISNULL( CartonGroup, '') = ''))
         BEGIN
            SELECT @cCartonGroup = CartonGroup
            FROM dbo.Storer WITH (NOLOCK)
            WHERE StorerKey = @cStorerKey

            SELECT @cOrderKey = OrderKey
            FROM dbo.PackHeader WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            SELECT @cRoute = Route,
                   @cConsigneeKey = ConsigneeKey,
                   @cExternOrderKey = ExternOrderKey
            FROM dbo.ORDERS WITH (NOLOCK)
            WHERE OrderKey = @cOrderKey

            UPDATE dbo.PackHeader WITH (ROWLOCK) SET 
               Route = @cRoute,
               OrderRefNo = @cExternOrderKey,
               ConsigneeKey = @cConsigneeKey,
               CartonGroup = @cCartonGroup
            WHERE PickSlipNo = @cPickSlipNo

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 130405  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --UpdPackHdrFail  
               GOTO RollBackTran  
            END  
         END

         -- Update packinfo for ucc
         -- rdt_Pack_Confirm will create packinfo
         IF EXISTS ( SELECT 1 FROM dbo.PackInfo WITH (NOLOCK)
                     WHERE PickSlipNo = @cPickSlipNo
                     AND   CartonNo = @nCartonNo)
         BEGIN
          -- Get carton info  
            SET @cCartontype = ''  
            SELECT TOP 1   
               @cCartonType = CartonType,   
               @nCartonWeight = ISNULL( CartonWeight, 0),   
               @nCartonCube = ISNULL( Cube, 0),   
               @nCartonLength = ISNULL( CartonLength, 0),  
               @nCartonWidth  = ISNULL( CartonWidth, 0),   
               @nCartonHeight = ISNULL( CartonHeight, 0)  
            FROM Storer S WITH (NOLOCK)  
            JOIN Cartonization C WITH (NOLOCK) ON (S.CartonGroup = C.CartonizationGroup)  
            WHERE S.StorerKey = @cStorerKey  
            ORDER BY C.UseSequence  

            -- Get PackDetail info  
            SELECT   
               @nQTY = SUM( PD.QTY),   
               @nWeight = SUM( PD.QTY * SKU.STDGrossWGT),   
               @nCube = SUM( PD.QTY * SKU.STDCube)  
            FROM PackDetail PD WITH (NOLOCK)   
            JOIN SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
            AND   PD.CartonNo = @nCartonNo  

            -- Calc weight, cube  
            SET @nWeight = @nWeight + @nCartonWeight   
            IF @nCartonCube <> 0  
               SET @nCube = @nCartonCube    

            UPDATE dbo.PackInfo SET 
               Cartontype = @cCartonType,
               Weight = @nWeight,
               Cube = @nCube
            WHERE PickSlipNo = @cPickSlipNo  
            AND   CartonNo = @nCartonNo 

            IF @@ERROR <> 0  
            BEGIN  
               SET @nErrNo = 130406  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Upd PKInf Fail  
               GOTO RollBackTran  
            END 
         END
      END
   END  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_838ExtUpd03 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END  

GO