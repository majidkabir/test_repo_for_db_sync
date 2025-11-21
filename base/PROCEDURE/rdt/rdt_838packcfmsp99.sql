SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
    
    
/************************************************************************/    
/* Store procedure: rdt_838PackCfmSP99                                  */    
/* Copyright      : LF Logistics                                        */    
/*                                                                      */    
/* Date       Rev  Author      Purposes                                 */    
/* 2019-12-19 1.0  James       WMS-10890. Created                       */    
/************************************************************************/    
    
CREATE     PROC [RDT].[rdt_838PackCfmSP99] (    
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
    
   DECLARE @bSuccess  INT    
   DECLARE @cLoadKey  NVARCHAR( 10)    
   DECLARE @cOrderKey NVARCHAR( 10)    
   DECLARE @cZone     NVARCHAR( 18)    
   DECLARE @nPackQTY  INT    
   DECLARE @nPickQTY  INT    
   DECLARE @cPickStatus  NVARCHAR(1)    
   DECLARE @cPackConfirm NVARCHAR(1)    
   DECLARE @cWavekey NVARCHAR(20)    
    
   SET @cOrderKey = ''    
   SET @cLoadKey = ''    
   SET @cZone = ''    
   SET @cPackConfirm = ''    
   SET @nPackQTY = 0    
   SET @nPickQTY = 0    
    
  -- -- Check pack confirm already    
  -- IF EXISTS( SELECT 1 FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo AND Status = '9')    
  --    GOTO Quit    
    
  -- -- Storer config    
  -- SET @cPickStatus = rdt.rdtGetConfig( @nFunc, 'PickStatus', @cStorerKey)    
    
  -- -- Get PickHeader info    
  -- SELECT TOP 1    
  --    @cOrderKey = OrderKey,    
  --    @cLoadKey = ExternOrderKey,    
  --    @cZone = Zone    
  -- FROM dbo.PickHeader WITH (NOLOCK)    
  -- WHERE PickHeaderKey = @cPickSlipNo    
    
  -- -- Calc pack QTY    
  -- SET @nPackQTY = 0    
  -- SELECT @nPackQTY = ISNULL( SUM( QTY), 0) FROM PackDetail WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo    
    
  -- -- Cross dock PickSlip    
  -- IF @cZone IN ('XD', 'LB', 'LP')    
  -- BEGIN    
  --    -- Check outstanding PickDetail    
  --    IF EXISTS( SELECT TOP 1 1    
  --       FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
  --          JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)    
  --       WHERE RKL.PickSlipNo = @cPickSlipNo    
  --          AND PD.Status < '5'    
  --          AND PD.QTY > 0    
  --          AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick    
  --       SET @cPackConfirm = 'N'    
  --    ELSE    
  --       SET @cPackConfirm = 'Y'    
    
  --    -- Check fully packed    
  --    IF @cPackConfirm = 'Y'    
  --    BEGIN    
  --       SELECT @nPickQTY = SUM( QTY)    
  --       FROM dbo.RefKeyLookup RKL WITH (NOLOCK)    
  --          JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PD.PickDetailKey = RKL.PickDetailKey)    
  --       WHERE RKL.PickSlipNo = @cPickSlipNo    
    
  --       IF @nPickQTY <> @nPackQTY    
  --          SET @cPackConfirm = 'N'    
  --    END    
  -- END    
    
  -- -- Discrete PickSlip    
  -- ELSE IF @cOrderKey <> ''    
  -- BEGIN    
  --    -- Check outstanding PickDetail    
  --    IF EXISTS( SELECT TOP 1 1    
  --       FROM dbo.PickDetail PD WITH (NOLOCK)    
  --       WHERE PD.OrderKey = @cOrderKey    
  --          AND PD.Status < '5'    
  --          AND PD.QTY > 0    
  --          AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick    
  --       SET @cPackConfirm = 'N'    
  --    ELSE    
  --       SET @cPackConfirm = 'Y'    
    
  --    -- Check fully packed    
  --    IF @cPackConfirm = 'Y'    
  --    BEGIN    
  --       SELECT @nPickQTY = SUM( PD.QTY)    
  --       FROM dbo.PickDetail PD WITH (NOLOCK)    
  --WHERE PD.OrderKey = @cOrderKey    
    
  --       IF @nPickQTY <> @nPackQTY    
  --          SET @cPackConfirm = 'N'    
  --    END    
  -- END    
    
  -- -- Conso PickSlip    
  -- ELSE IF @cLoadKey <> ''    
  -- BEGIN    
  --    -- Check outstanding PickDetail    
  --  IF EXISTS( SELECT TOP 1 1    
  --       FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)    
  --          JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
  --       WHERE LPD.LoadKey = @cLoadKey    
  --          AND PD.Status < '5'    
  --          AND PD.QTY > 0    
  --          AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick    
  --       SET @cPackConfirm = 'N'    
  --    ELSE    
  --       SET @cPackConfirm = 'Y'    
    
  --    -- Check fully packed    
  --    IF @cPackConfirm = 'Y'    
  --    BEGIN    
  --       SELECT @nPickQTY = SUM( PD.QTY)    
  --       FROM dbo.LoadPlanDetail LPD WITH (NOLOCK)    
  --          JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)    
  --       WHERE LPD.LoadKey = @cLoadKey    
    
  --       IF @nPickQTY <> @nPackQTY    
  --          SET @cPackConfirm = 'N'    
  --    END    
  -- END    
    
  -- -- Custom PickSlip    
  -- ELSE    
  -- BEGIN    
  --    -- Check outstanding PickDetail    
  --    IF EXISTS( SELECT TOP 1 1    
  --       FROM PickDetail PD WITH (NOLOCK)    
  --       WHERE PD.PickSlipNo = @cPickSlipNo    
  --          AND PD.Status < '5'    
  --          AND PD.QTY > 0    
  --          AND (PD.Status = '4' OR PD.Status <> @cPickStatus))  -- Short or not yet pick    
  --       SET @cPackConfirm = 'N'    
  --    ELSE    
  --       SET @cPackConfirm = 'Y'    
    
  --    -- Check fully packed    
  --    IF @cPackConfirm = 'Y'    
  --    BEGIN    
  --       SELECT @nPickQTY = SUM( PD.QTY)    
  --       FROM PickDetail PD WITH (NOLOCK)    
  --       WHERE PD.PickSlipNo = @cPickSlipNo    
    
  --       IF @nPickQTY <> @nPackQTY    
  --          SET @cPackConfirm = 'N'    
  --    END    
  -- END    
    
   -- Handling transaction    
   DECLARE @nTranCount  INT    
   SET @nTranCount = @@TRANCOUNT    
   BEGIN TRAN  -- Begin our own transaction    
   SAVE TRAN rdt_838PackCfmSP99 -- For rollback or commit only our own transaction    
    
   ---- Pack confirm    
   --IF @cPackConfirm = 'Y'    
   --BEGIN    
    declare @cpacklist nvarchar(20)    
      DECLARE @cLabelprinter NVARCHAR(20)    
      DECLARE @cPaperprinter NVARCHAR(20)    
    declare  @cExternOrderkey NVARCHAR(20)    
      SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList1', @cStorerKey)    
    IF @cPackList = '0'    
    SET @cPackList = ''    
    
      select    @cPaperPrinter    = Printer_Paper,    
                @cLabelPrinter    = Printer    
      FROM RDT.rdtmobrec (NOLOCK)    
      WHERE mobile=@nMobile    
    
    
   -- Get PickHeader info    
      SELECT TOP 1    
         @cWavekey = wavekey,    
         @cExternOrderkey = ExternOrderKey  ,
		 @cLoadkey = ExternOrderKey
      FROM dbo.PickHeader WITH (NOLOCK)    
      WHERE PickHeaderKey = @cPickSlipNo    
  
           -- Get report param    
  DECLARE @tPackList AS VariableTable    
  INSERT INTO @tPackList (Variable, Value) VALUES    
  ( '@cLoadkey',    @cLoadkey),    
  ( '@cWavekey',    @cWavekey),    
  ( '@cExternOrderkey', @cLoadkey)    
    
  -- Print packing list    
  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,    
  @cPackList, -- Report type    
  @tPackList, -- Report params    
  'rdtfnc_Pack',    
  @nErrNo  OUTPUT,    
  @cErrMsg OUTPUT    
  IF @nErrNo <> 0    
  GOTO Quit    
    
 --  END    
    
   COMMIT TRAN rdt_838PackCfmSP99    
   GOTO Quit    
    
RollBackTran:    
   ROLLBACK TRAN rdt_838PackCfmSP99 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
    
END 
GO