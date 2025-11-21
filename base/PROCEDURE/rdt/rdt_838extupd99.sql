SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
/************************************************************************/
/* Store procedure: rdt_838ExtUpd01                                     */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 13-05-2016 1.0  Ung         SOS368666 Created                        */
/* 06-12-2016 1.1  Ung         WMS-458 Change parameter                 */
/* 24-05-2017 1.2  Ung         WMS-1919 Change parameter                */
/* 04-04-2019 1.3  Ung         WMS-8134 Add PackData1..3 parameter      */
/************************************************************************/

CREATE   PROC [RDT].[rdt_838ExtUpd99] (
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

	DECLARE @nTranCount  INT    
	SET @nTranCount = @@TRANCOUNT    
	BEGIN TRAN  -- Begin our own transaction    
	SAVE TRAN rdt_838ExtUpd99 -- For rollback or commit only our own transaction    
    
	IF @nstep =6
	BEGIN

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
    
     
    
   COMMIT TRAN rdt_838ExtUpd99    
   GOTO Quit    

   END
    
RollBackTran:    
   ROLLBACK TRAN rdt_838ExtUpd99 -- Only rollback change made here    
Quit:    
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started    
      COMMIT TRAN    
    
END 
GO