SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593TestPrinter01                                   */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author		Purposes                                   */
/* 2017-Oct-23 1.0  YeeKung    Label and Paper Printing                    */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593TestPrinter01] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR(20),  -- Label Printing
   @cParam2    NVARCHAR(20),  -- Paper Printing
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

   DECLARE	@cLabelPrinter  NVARCHAR( 10)
				,@cPaperPrinter  NVARCHAR( 10)
				,@cPrintJob	   NVARCHAR( 10)
				,@bSuccess	   INT

   -- Parameter mapping
   SET @cLabelPrinter = @cParam1
   SET @cPaperPrinter = @cParam2

	DECLARE @i INT
	SET @i = 0
	IF @cLabelPrinter <> '' AND @cLabelPrinter  IS NOT NULL SET @i = @i + 1
	IF @cPaperPrinter <> '' AND @cPaperPrinter  IS NOT NULL SET @i = @i + 1
      
	--Check Validation whether both @cLabelPrinter and @cPaperPrinter is null
	IF @i = 0
	BEGIN
		SET @nErrNo = 116151
		SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Label or Printer Require
		GOTO Quit
	END

   ELSE
   BEGIN
		-- Check validation whether the paper printer is valid or not
		IF NOT EXISTS (SELECT * FROM RDT.RDTPRINTER WITH (NOLOCK) WHERE PRINTERID=@cPaperPrinter) AND
		   @cPaperPrinter <> ''
		BEGIN
			SET @nErrNo = 116152
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Printer Inv
			GOTO Quit
		END

		-- Check validation whether the label printer is valid or not
		IF NOT EXISTS (SELECT * FROM RDT.RDTPRINTER WITH (NOLOCK) WHERE PRINTERID=@cLabelPrinter) AND
		   @cLabelPrinter <> ''
		BEGIN
			SET @nErrNo = 116152
			SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --Printer Inv
			GOTO Quit
		END

		IF @cLabelPrinter <> ''
		BEGIN
		-- whether the label printing record is valid
			IF NOT EXISTS ( SELECT * FROM RDT.RDTREPORT WITH (NOLOCK) WHERE STORERKEY=@cStorerKey AND Function_ID=@nFunc AND ReportType='TESTPRNLBL')
			BEGIN
			--insert value to rdtreport
			INSERT INTO RDT.RDTREPORT(StorerKey,ReportType,RptDesc,Datawindow,parm1_label,parm2_label,parm3_label,Function_ID,ProcessType,PaperType,NoOfCopy)
			VALUES(@cStorerKey,'TESTPRNLBL', 'For test print Label','r_dw_bartender_shipplabel_sf',@nMobile,@cLabelPrinter,@cPrintJob,@nFunc,'BARTENDER','LABEL',1)

			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo =  116153
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --16153InsertLBLFail
				GOTO Quit
			END

			--Insert value to bartender
			IF NOT EXISTS (SELECT * FROM BartenderLabelCfg WITH (NOLOCK) WHERE storerkey=@cStorerKey)
			BEGIN
					Insert into BartenderLabelCfg (Labeltype,key01,key02,key03,key04,key05,TemplatePath,StoreProcedure,storerkey)
					VALUES ('TESTPRNLBL','test','','','','','C:\Users\Public\Documents\BarTender\TemplateFile\CN\Printer_test.btw','isp_test_Print_Label',@cStorerKey)

					IF @@ERROR <> 0
					BEGIN
						SET @nErrNo =  116154
						SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --16154InsertBarTdFail
						GOTO Quit
					END
			END
		END
		

			--Validate the parm1_label in rdtreport is current mobile number or not
			IF NOT EXISTS (SELECT * FROM RDT.RDTReport WITH (NOLOCK) WHERE parm1_label=cast(@nMobile AS NVARCHAR(3)))
			BEGIN
				UPDATE RDT.RDTREPORT
				SET parm1_label=cast(@nMobile AS NVARCHAR(3))
				WHERE STORERKEY=@cStorerKey AND Function_ID=@nFunc AND ReportType='TESTPRNLBL';
			END

			--Set ncounter for each print job
			EXECUTE nspg_getkey        
			@KeyName       = 'PrintJob_ID'        
			,@fieldlength   = 10        
			,@keystring     = @cPrintJob	      OUTPUT        
			,@b_Success     = @bSuccess         OUTPUT        
			,@n_err         = @nErrNo           OUTPUT        
			,@c_errmsg      = @cErrMsg          OUTPUT   

			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo =  116155
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --16154InsertBarTdFail
				GOTO Quit
			END

			UPDATE RDT.RDTREPORT 
			SET parm3_label=@cPrintJob
			WHERE STORERKEY=@cStorerKey AND Function_ID=@nFunc AND ReportType='TESTPRNLBL';

			DECLARE @LabelPrint AS VariableTable
			INSERT INTO @LabelPrint (Variable, Value) VALUES ( '@nMobile',@nMobile)
			INSERT INTO @LabelPrint (Variable, Value) VALUES ( '@cLabelPrinter',@cLabelPrinter)
			INSERT INTO @LabelPrint (Variable, Value) VALUES ( '@cPrintJob',@cPrintJob)

			--Label printing
			EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '', 
			'TESTPRNLBL', -- Report type
			@LabelPrint, -- Report params
			'rdt.rdt_593TestPrinter01', 
			@nErrNo  OUTPUT,
			@cErrMsg OUTPUT

			IF @nErrNo <> 0
			GOTO Quit
		END

		IF @cPaperPrinter <> ''
		BEGIN
		-- whether the Paper printing record is valid
			IF NOT EXISTS ( SELECT * FROM RDT.RDTREPORT WITH (NOLOCK) WHERE STORERKEY=@cStorerKey AND Function_ID=@nFunc AND ReportType='TESTPRNPPR')
			BEGIN
				INSERT INTO RDT.RDTREPORT(StorerKey,ReportType,RptDesc,Datawindow,parm1_label,parm2_label,parm3_label,Function_ID,PaperType,NoOfCopy)
				VALUES(@cStorerKey,'TESTPRNPPR', 'Test print paper','r_dw_printer_test_print',@nMobile,@cPaperPrinter,@cPrintJob,@nFunc,'PAPER',1)

			END

			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo =  116156
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --16155^GetKeyFail
				GOTO Quit
			END

			--Validate the parm1_label in rdtreport is current mobile number or not
			IF NOT EXISTS (SELECT * FROM RDT.RDTReport WITH (NOLOCK) WHERE parm1_label=cast(@nMobile AS NVARCHAR(3)))
			BEGIN
				UPDATE RDT.RDTREPORT
				SET parm1_label=cast(@nMobile AS NVARCHAR(3))
				WHERE STORERKEY=@cStorerKey AND Function_ID=@nFunc AND ReportType='TESTPRNPPR';
			END

			--Set ncounter for each print job
			EXECUTE nspg_getkey        
			@KeyName       = 'PrintJob_ID'        
			,@fieldlength   = 10        
			,@keystring     = @cPrintJob	      OUTPUT        
			,@b_Success     = @bSuccess         OUTPUT        
			,@n_err         = @nErrNo           OUTPUT        
			,@c_errmsg      = @cErrMsg          OUTPUT   

			IF @@ERROR <> 0
			BEGIN
				SET @nErrNo =  116155
				SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --16156InsertPPRFail
				GOTO Quit
			END
	
			UPDATE RDT.RDTREPORT 
			SET parm3_label=@cPrintJob
			WHERE STORERKEY=@cStorerKey AND Function_ID=@nFunc AND ReportType='TESTPRNPPR';

			DECLARE @PaperPrint AS VariableTable
			INSERT INTO @PaperPrint (Variable, Value) VALUES ( '@nMobile',@nMobile)
			INSERT INTO @PaperPrint (Variable, Value) VALUES ( '@cPaperPrinter',@cPaperPrinter)
			INSERT INTO @PaperPrint (Variable, Value) VALUES ( '@cPrintJob',@cPrintJob)

			-- Paper printing
			EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey,'', @cPaperPrinter, 
			'TESTPRNPPR', -- Report type
			@PaperPrint, -- Report params
			'rdt.rdt_593TestPrinter01', 
			@nErrNo  OUTPUT,
			@cErrMsg OUTPUT

			IF @nErrNo <> 0
			GOTO Quit
		END

		
   END


Quit:






GO