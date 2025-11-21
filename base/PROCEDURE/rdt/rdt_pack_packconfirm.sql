SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_Pack_PackConfirm                                */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date       Rev  Author      Purposes                                 */  
/* 06-05-2016 1.0  Ung         SOS368666 Created                        */  
/* 15-11-2016 1.1  Ung         WMS-458 Add AssignPackLabelToOrdCfg      */  
/* 16-08-2017 1.2  Ung         WMS-1919 show pack confirm error         */  
/* 01-11-2017 1.3  Ung         WMS-3326 Add DEFAULT_PACKINFO            */  
/* 09-04-2018 1.4  Ung         WMS-3845 Add PackConfirmSP               */  
/* 14-09-2020 1.5  Chermaine   WMS-14253 Add isnull (cc01)              */
/* 03-06-2023 1.6  Ung         WMS-22608 Add multi PickDetail.Status    */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_Pack_PackConfirm] (  
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
  
   DECLARE @cSQL           NVARCHAR(MAX)  
   DECLARE @cSQLParam      NVARCHAR(MAX)  
   DECLARE @cPackConfirmSP NVARCHAR(20)  
  
   -- Get storer configure  
   SET @cPackConfirmSP = rdt.RDTGetConfig( @nFunc, 'PackConfirmSP', @cStorerKey)  
   IF @cPackConfirmSP = '0'  
      SET @cPackConfirmSP = ''  
  
   /***********************************************************************************************  
                                              Custom pack confirm  
   ***********************************************************************************************/  
   -- Custom logic  
   IF @cPackConfirmSP <> ''  
   BEGIN  
      IF EXISTS( SELECT 1 FROM sys.objects WHERE name = @cPackConfirmSP AND type = 'P')  
      BEGIN  
         SET @cSQL = 'EXEC rdt.' + RTRIM( @cPackConfirmSP) +  
            ' @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cPackDtlDropID, ' +  
            ' @cPrintPackList OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT '  
  
         SET @cSQLParam =  
            ' @nMobile        INT,           ' +   
            ' @nFunc          INT,           ' +   
            ' @cLangCode      NVARCHAR( 3),  ' +   
            ' @nStep          INT,           ' +   
            ' @nInputKey      INT,           ' +   
            ' @cFacility      NVARCHAR( 5),  ' +   
            ' @cStorerKey     NVARCHAR( 15), ' +     
            ' @cPickSlipNo    NVARCHAR( 10), ' +     
            ' @cFromDropID    NVARCHAR( 20), ' +   
            ' @cPackDtlDropID NVARCHAR( 20), ' +   
            ' @cPrintPackList NVARCHAR( 1)  OUTPUT, ' +   
            ' @nErrNo         INT           OUTPUT, ' +   
            ' @cErrMsg        NVARCHAR(250) OUTPUT  '  
              
         EXEC sp_ExecuteSQL @cSQL, @cSQLParam,  
            @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cPickSlipNo, @cFromDropID, @cPackDtlDropID,   
            @cPrintPackList OUTPUT, @nErrNo OUTPUT, @cErrMsg OUTPUT  
  
         GOTO Quit  
      END  
   END  
  
   /***********************************************************************************************  
                                          Standard pack confirm  
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
   SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)  

   -- Get PickHeader info  
   SELECT TOP 1  
      @cOrderKey = OrderKey,  
      @cLoadKey = ExternOrderKey,  
      @cZone = Zone  
   FROM dbo.PickHeader WITH (NOLOCK)  
   WHERE PickHeaderKey = @cPickSlipNo  
  
   -- Calc pack QTY  
   SET @nPackQTY = 0  
   SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo  
  
   -- Cross dock PickSlip  
   IF @cZone IN ('XD', 'LB', 'LP')  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1  
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
         WHERE RKL.PickSlipNo = @cPickSlipNo  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR CHARINDEX( PD.Status, @cPickStatus) = 0))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
        
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( QTY)   
         FROM dbo.RefKeyLookup RKL WITH (NOLOCK)  
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)  
         WHERE RKL.PickSlipNo = @cPickSlipNo  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  
  
   -- Discrete PickSlip  
   ELSE IF @cOrderKey <> ''  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1  
         FROM dbo.PickDetail PD WITH (NOLOCK)  
         WHERE PD.OrderKey = @cOrderKey  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR CHARINDEX( PD.Status, @cPickStatus) = 0))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
        
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( PD.QTY)   
         FROM dbo.PickDetail PD WITH (NOLOCK)   
         WHERE PD.OrderKey = @cOrderKey  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  
     
   -- Conso PickSlip  
   ELSE IF @cLoadKey <> ''  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1   
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)  
         WHERE LPD.LoadKey = @cLoadKey  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR CHARINDEX( PD.Status, @cPickStatus) = 0))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
        
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( PD.QTY)   
         FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)   
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)  
         WHERE LPD.LoadKey = @cLoadKey  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  
  
   -- Custom PickSlip  
   ELSE  
   BEGIN  
      -- Check outstanding PickDetail  
      IF EXISTS( SELECT TOP 1 1   
         FROM PickDetail PD WITH (NOLOCK)   
         WHERE PD.PickSlipNo = @cPickSlipNo  
            AND PD.Status < '5'  
            AND PD.QTY > 0  
            AND (PD.Status = '4' OR CHARINDEX( PD.Status, @cPickStatus) = 0))  -- Short or not yet pick  
         SET @cPackConfirm = 'N'  
      ELSE  
         SET @cPackConfirm = 'Y'  
  
      -- Check fully packed  
      IF @cPackConfirm = 'Y'  
      BEGIN  
         SELECT @nPickQTY = SUM( PD.QTY)   
         FROM PickDetail PD WITH (NOLOCK)   
         WHERE PD.PickSlipNo = @cPickSlipNo  
           
         IF @nPickQTY <> @nPackQTY  
            SET @cPackConfirm = 'N'  
      END  
   END  
  
   -- Handling transaction  
   DECLARE @nTranCount  INT  
   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  -- Begin our own transaction  
   SAVE TRAN rdt_Pack_PackConfirm -- For rollback or commit only our own transaction  
  
   -- Pack confirm  
   IF @cPackConfirm = 'Y'  
   BEGIN  
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
  
   COMMIT TRAN rdt_Pack_PackConfirm  
   GOTO Quit  
  
RollBackTran:  
   ROLLBACK TRAN rdt_Pack_PackConfirm -- Only rollback change made here  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started  
      COMMIT TRAN  
END

GO