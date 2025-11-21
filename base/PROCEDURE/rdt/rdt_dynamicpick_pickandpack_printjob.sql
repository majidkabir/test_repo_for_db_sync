SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_PickAndPack_PrintJob                */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Setup print job                             						*/
/*                                                                      */
/* Called from: rdtfnc_DynamicPick_PickAndPack                          */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 18-Jun-2008 1.0  MaryVong    Created                                 */
/* 16-Jan-2018 1.1  ChewKP      WMS-3767-Call rdt.rdtPrintJob (ChewKP01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_PickAndPack_PrintJob] (
	@cStorer	 NVARCHAR( 15),
	@cJobName  NVARCHAR( 50),
	@cReportID  NVARCHAR( 10),
	@cPrinter NVARCHAR( 10),
	@cJobStatus NVARCHAR( 1),
	@nNoOfParms	INT,
	@nNoOfCopy 	INT,  
	@nMobile		INT,
	@cParm1	 NVARCHAR( 30),
	@cParm2	 NVARCHAR( 30),
	@cParm3	 NVARCHAR( 30),
	@cParm4	 NVARCHAR( 30),
	@cParm5	 NVARCHAR( 30),
	@cLangCode NVARCHAR( 3),
   @nErrNo     INT          OUTPUT, 
   @cErrMsg    NVARCHAR( 20) OUTPUT  -- screen limitation, 20 char max 
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE
   	@cDataWindow NVARCHAR( 50),
		@cTargetDB	 NVARCHAR( 20)
   	           		       
   SELECT @cDataWindow = ISNULL(RTRIM(DataWindow), ''),
		@cTargetDB = ISNULL(RTRIM(TargetDB), '') 
   FROM RDT.RDTReport WITH (NOLOCK) 
   WHERE StorerKey = @cStorer
      AND ReportType = @cReportID
   	
   IF @cDataWindow = ''
   BEGIN
      SET @nErrNo = 64651
      SET @cErrMsg = rdt.rdtgetmessage( 64651, @cLangCode, 'DSP') --'DWNOTSetup'
      GOTO Fail
   END

	IF @cTargetDB = ''
   BEGIN
      SET @nErrNo = 64652
      SET @cErrMsg = rdt.rdtgetmessage( 64652, @cLangCode, 'DSP') --'TgetDB Not Set'
      GOTO Fail
   END

   -- (ChewKP01) 
	-- Call printing spooler
	--INSERT INTO RDT.RDTPrintJob(JobName, ReportID, JobStatus, Datawindow, NoOfParms, Parm1, Parm2, Parm3, Parm4, Parm5, Printer, NoOfCopy, Mobile, TargetDB)
	--VALUES(@cJobName, @cReportID, @cJobStatus, @cDataWindow, @nNoOfParms, @cParm1, @cParm2, @cParm3, @cParm4, @cParm5, @cPrinter, @nNoOfCopy, @nMobile, @cTargetDB)
	
	EXEC RDT.rdt_BuiltPrintJob                     
      @nMobile,                    
      @cStorer,                    
      @cReportID,                    
      @cJobName,                    
      @cDataWindow,                    
      @cPrinter,                    
      @cTargetDB,                    
      @cLangCode,                    
      @nErrNo  OUTPUT,                     
      @cErrMsg OUTPUT,                    
      @cParm1,
      @cParm2,
      @cParm3,
      @cParm4,
      @cParm5


	IF @nErrNo <> 0
	BEGIN
		SET @nErrNo = 64653
		SET @cErrMsg = rdt.rdtgetmessage( 64653, @cLangCode, 'DSP') --'InsertPRTFail'
		GOTO Fail
	END

	Fail:

END

GO