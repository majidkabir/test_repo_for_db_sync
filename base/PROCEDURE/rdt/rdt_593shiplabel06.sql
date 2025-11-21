SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593ShipLabel06                                     */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author   Purposes                                       */
/* 2017-06-06 1.0  James    WMS2128. Created                               */
/* 2017-08-18 1.1  CheeMun  WMS2128 - WMS2128 - Check for Datawindow value */
/*                                    before insert into rdt.rdtprintjob   */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593ShipLabel06] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- Label No
   @cParam2    NVARCHAR(20),  
   @cParam3    NVARCHAR(20),  
   @cParam4    NVARCHAR(20),
   @cParam5    NVARCHAR(20),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cLabelPrinter  NVARCHAR( 10)
          ,@cPaperPrinter  NVARCHAR( 10)
          ,@cLabelNo       NVARCHAR( 20)
          ,@cPickSlipNo    NVARCHAR( 10)
          ,@cDataWindow    NVARCHAR( 50)  
          ,@cTargetDB      NVARCHAR( 20)   
          ,@cReportType    NVARCHAR(10) 
          ,@nCartonNo      INT
          ,@nTranCount     INT

   -- Parameter mapping
   SET @cLabelNo = @cParam1

   -- Check blank
   IF ISNULL( @cLabelNo, '') = ''
   BEGIN
      SET @nErrNo = 110901
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNo req
      GOTO Quit
   END

   SELECT TOP 1 @cPickSlipNo = PickSlipNo, 
                @nCartonNo = CartonNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   LabelNo = @cLabelNo

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 110902
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Invalid Label
      GOTO Quit
   END

    -- Get login info
   SELECT @cLabelPrinter = Printer
   FROM rdt.rdtMobrec WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   -- Check label printer blank
   IF @cLabelPrinter = ''
   BEGIN
      SET @nErrNo = 110903
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq
      GOTO Quit
   END

   SET @nTranCount = @@TRANCOUNT  
   BEGIN TRAN  
   SAVE TRAN rdt_593ShipLabel06  

   -- Get UCCLABEL list report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   
   IF EXISTS(SELECT 1 FROM RDT.RDTREPORT WITH(NOLOCK) WHERE STORERKEY = @cStorerKey
			 AND ReportType = 'UCCLABEL'
			 AND( Function_ID = @nFunc OR Function_ID = 0))
   BEGIN 
		SELECT 
			@cDataWindow = ISNULL(RTRIM(DataWindow), ''),
			@cTargetDB = ISNULL(RTRIM(TargetDB), '') 
		FROM RDT.RDTReport WITH (NOLOCK) 
		WHERE StorerKey = @cStorerKey
		AND   ReportType = 'UCCLABEL'
		AND   ( Function_ID = @nFunc OR Function_ID = 0)
		
		-- Check data window
		IF ISNULL( @cDataWindow, '') = ''
		BEGIN
			SET @nErrNo = 110904
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
			GOTO RollBackTran
		END
		
		-- Check database
		IF ISNULL( @cTargetDB, '') = ''
		BEGIN
			SET @nErrNo = 110905
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
			GOTO RollBackTran
		END
		
		EXEC RDT.rdt_BuiltPrintJob
			@nMobile,
			@cStorerKey,
			'UCCLABEL',       -- ReportType
			'rdt_593ShipLabel06', -- PrintJobName
			@cDataWindow,
			@cLabelPrinter,
			@cTargetDB,
			@cLangCode,
			@nErrNo  OUTPUT,
			@cErrMsg OUTPUT, 
			@cPickSlipNo, 
			@nCartonNo,    -- Start CartonNo
			@nCartonNo    -- End CartonNo
		
		IF @nErrNo <> 0
			GOTO RollBackTran
   END
   
   --Get CTNMNFLBL list report info
   SET @cDataWindow = ''
   SET @cTargetDB = ''
   
   IF EXISTS(SELECT 1 FROM RDT.RDTREPORT WITH(NOLOCK) WHERE STORERKEY = @cStorerKey
			 AND ReportType = 'CTNMNFLBL'
			 AND( Function_ID = @nFunc OR Function_ID = 0))
   BEGIN 
		SELECT 
			@cDataWindow = ISNULL(RTRIM(DataWindow), ''),
			@cTargetDB = ISNULL(RTRIM(TargetDB), '') 
		FROM RDT.RDTReport WITH (NOLOCK) 
		WHERE StorerKey = @cStorerKey
		AND   ReportType = 'CTNMNFLBL'
		AND   ( Function_ID = @nFunc OR Function_ID = 0)
		
		-- Check data window
		IF ISNULL( @cDataWindow, '') = ''
		BEGIN
			SET @nErrNo = 110906
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DWNOTSetup
			GOTO RollBackTran
		END
		
		-- Check database
		IF ISNULL( @cTargetDB, '') = ''
		BEGIN
			SET @nErrNo = 110907
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --TgetDB Not Set
			GOTO RollBackTran
		END
		
		EXEC RDT.rdt_BuiltPrintJob
			@nMobile,
			@cStorerKey,
			'CTNMNFLBL',       -- ReportType
			'rdt_593ShipLabel06', -- PrintJobName
			@cDataWindow,
			@cLabelPrinter,
			@cTargetDB,
			@cLangCode,
			@nErrNo  OUTPUT,
			@cErrMsg OUTPUT, 
			@cPickSlipNo, 
			@nCartonNo,    -- Start CartonNo
			@nCartonNo    -- End CartonNo
		
		IF @nErrNo <> 0
			GOTO RollBackTran
   END
   
   -- Close carton (if not yet close b4)
   UPDATE dbo.DropID WITH (ROWLOCK) SET 
      [Status] = '9'
   WHERE DropID = @cLabelNo 
   AND   PickSlipNo = @cPickSlipNo
   AND   [Status] <> '9'

   IF @@ERROR <> 0
   BEGIN
      SET @nErrNo = 110908
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'CLOSE CTN FAIL'
      GOTO RollBackTran
   END

GOTO Quit

RollBackTran:  
      ROLLBACK TRAN rdt_593ShipLabel06  
Quit:  
   WHILE @@TRANCOUNT > @nTranCount  
      COMMIT TRAN  


GO