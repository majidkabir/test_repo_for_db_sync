SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_838PackCfmSP07                                  */  
/* Copyright      : Maersk                                              */  
/*                                                                      */  
/* Date       Rev  Author      Purposes                                 */  
/* 01-28-2025 1.0  JCH507      UWP-29680 Mis update packheader          */  
/************************************************************************/  
  
CREATE   PROC rdt.rdt_838PackCfmSP07 (  
    @nMobile      INT  
   ,@nFunc        INT  
   ,@cLangCode    NVARCHAR( 3)  
   ,@nStep        INT  
   ,@nInputKey    INT  
   ,@cFacility    NVARCHAR( 5)  
   ,@cStorerKey   NVARCHAR( 15)  
   ,@cPickSlipNo  NVARCHAR( 10)  
   ,@cFromDropID  NVARCHAR( 20)  
   ,@cPackDtlDropID NVARCHAR( 20)  
   ,@cPrintPackList NVARCHAR( 1) OUTPUT  
   ,@nErrNo       INT            OUTPUT  
   ,@cErrMsg      NVARCHAR(250)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @bDebugFlag     BINARY = 0
   
  
   /***********************************************************************************************  
                                          838 Standard pack confirm  
   ***********************************************************************************************/  
   DECLARE @bSuccess  INT  
   DECLARE @cLoadKey  NVARCHAR( 10)  
   DECLARE @cOrderKey NVARCHAR( 10)  
   DECLARE @cZone     NVARCHAR( 18)  
   DECLARE @nPackQTY  INT  
   DECLARE @nPickQTY  INT  
   DECLARE @cPickStatus  NVARCHAR( 20)  
   DECLARE @cPackConfirm NVARCHAR( 1)  
  
   SET @cOrderKey = ''  
   SET @cLoadKey = ''  
   SET @cZone = ''  
   SET @cPackConfirm = ''  
   SET @nPackQTY = 0  
   SET @nPickQTY = 0  
  
   -- Check pack confirm already  
   IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')  
      GOTO Quit  
  
   -- Storer config  
   --SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)  -- V1.0

   -- Get PickHeader info  
   SELECT TOP 1  
      @cOrderKey = OrderKey,  
      @cLoadKey = ExternOrderKey,  
      @cZone = Zone  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE PickHeaderKey = @cPickSlipNo

   IF @bDebugFlag = 1
      SELECT 'PickSlipNo has:', @cOrderKey AS OrderKey, @cLoadKey AS LoadKey, @cZone AS Zone
  
   -- Calc pack QTY  
   SET @nPackQTY = 0  
   SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo  
  
   -- Levis only have this scenario Discrete PickSlip  
   IF @cOrderKey <> ''  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1  
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         WHERE PD.OrderKey = @cOrderKey  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            --AND (PD.Status = '4' OR CHARINDEX( PD.Status, @cPickStatus) = 0))  -- Short or not yet pick  --V1.0
            AND (PD.Status = '4' OR PD.Status = '0')) --V1.0
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
        
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( PD.QTY)   
         FROM dbo.PickDetail PD WITH (NOLOCK)   
         WHERE PD.OrderKey = @cOrderKey

         IF @bDebugFlag = 1
            SELECT 'PickQTY:', @nPickQTY, 'PackQTY:', @nPackQTY  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END -- Orderkey <> ''
  
   -- Handling transaction  
   DECLARE @nTranCount  INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_838PackCfmSP07 -- For rollback or commit only our own transaction  
  
   -- Pack confirm  
   IF @cPackConfirm = 'Y'  
   BEGIN
      IF @bDebugFlag = 1
         SELECT 'PackConfirm=Y, Update PackHeader'
      -- Pack confirm  
      UPDATE PackHeader SET   
         Status = '9'   
      WHERE PickSlipNo = @cPickSlipNo  
         AND Status <> '9'  
      SET @nErrNo = @@ERROR   
      IF @nErrNo <> 0  
      BEGIN  
         -- SET @nErrNo = 100251  
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- PackCfm Fail  
         GOTO RollBackTran  
      END  
  
      -- Get storer config  
      DECLARE @cAssignPackLabelToOrdCfg NVARCHAR(1)  
      EXECUTE nspGetRight  
         @cFacility,  
         @cStorerKey,  
         '', --@c_sku  
         'AssignPackLabelToOrdCfg',  
         @bSuccess                 OUTPUT,  
         @cAssignPackLabelToOrdCfg OUTPUT,  
         @nErrNo                   OUTPUT,  
         @cErrMsg                  OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
  
      -- Assign  
      IF @cAssignPackLabelToOrdCfg = '1'  
      BEGIN  
         -- Update PickDetail, base on PackDetail.DropID  
         EXEC isp_AssignPackLabelToOrderByLoad  
             @cPickSlipNo  
            ,@bSuccess OUTPUT  
            ,@nErrNo   OUTPUT  
            ,@cErrMsg  OUTPUT  
         IF @nErrNo <> 0  
            GOTO RollBackTran  
      END  
  
      -- Get storer config  
      DECLARE @cDefault_PackInfo NVARCHAR(1)  
      EXECUTE nspGetRight  
         @cFacility,  
         @cStorerKey,  
         '', --@c_sku  
         'Default_PackInfo',  
         @bSuccess          OUTPUT,  
         @cDefault_PackInfo OUTPUT,  
         @nErrNo            OUTPUT,  
         @cErrMsg           OUTPUT  
      IF @nErrNo <> 0  
         GOTO RollBackTran  
           
      IF @cDefault_PackInfo = '1'  
      BEGIN  
         IF EXISTS( SELECT 1   
            FROM PackDetail PD WITH (NOLOCK)  
               LEFT JOIN PackInfo PInf WITH (NOLOCK) ON (PD.PickSlipNo = PInf.PickSlipNo AND PD.CartonNo = PInf.CartonNo)  
            WHERE PD.PickSlipNo = @cPickSlipNo  
               AND PInf.PickSlipNo IS NULL)  
         BEGIN  
            DECLARE @nCartonNo      INT   
            DECLARE @nWeight        FLOAT  
            DECLARE @nCube          FLOAT  
            DECLARE @nQTY           INT  
            DECLARE @cCartonType    NVARCHAR( 10)  
            DECLARE @nCartonWeight  FLOAT  
            DECLARE @nCartonCube    FLOAT  
            DECLARE @nCartonLength  FLOAT  
            DECLARE @nCartonWidth   FLOAT  
            DECLARE @nCartonHeight  FLOAT  
  
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
            DECLARE @curPD CURSOR  
            SET @curPD = CURSOR FOR  
               SELECT DISTINCT PD.CartonNo  
               FROM PackDetail PD WITH (NOLOCK)  
                  LEFT JOIN PackInfo PInf WITH (NOLOCK) ON (PD.PickSlipNo = PInf.PickSlipNo AND PD.CartonNo = PInf.CartonNo)  
               WHERE PD.PickSlipNo = @cPickSlipNo  
                  AND PInf.PickSlipNo IS NULL  
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
               SET @nWeight = @nWeight + ISNULL(@nCartonWeight,0)   --(cc01)
               IF ISNULL(@nCartonCube,0) <> 0                       --(cc01)
                  SET @nCube = ISNULL(@nCartonCube,0)                --(cc01)        
  
               -- Insert PackInfo  
               INSERT INTO PackInfo (PickSlipNo, CartonNo, Weight, Cube, Qty, Cartontype, Length, Width, Height)  
               VALUES (@cPickSlipNo, @nCartonNo, @nWeight, @nCube, @nQTY, @cCartonType, @nCartonLength, @nCartonWidth, @nCartonHeight)  
               IF @nErrNo <> 0  
               BEGIN  
                  SET @nErrNo = 100252  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') -- INS PKInf Fail  
                  GOTO RollBackTran  
               END  
                 
               FETCH NEXT FROM @curPD INTO @nCartonNo  
            END  
         END  
      END  
   END  
  
   COMMIT TRAN rdt_838PackCfmSP07  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_838PackCfmSP07 -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END

GO