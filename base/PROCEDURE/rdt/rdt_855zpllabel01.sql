SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_855ZPLLabel01                                   */
/* Copyright      : Maersk                                              */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 2025-01-23  1.0  Dennis       FCR-1824 Created                       */
/************************************************************************/

CREATE   PROCEDURE rdt.rdt_855ZPLLabel01
   @nMobile       INT,           
   @nFunc         INT,           
   @cLangCode     NVARCHAR( 3),  
   @nStep         INT,           
   @nInputKey     INT,           
   @cFacility     NVARCHAR( 5),   
   @cStorerKey    NVARCHAR( 15), 
   @cLabelPrinter NVARCHAR( 10),  
   @cPaperPrinter NVARCHAR( 10),  
   @cReportType   NVARCHAR( 10),  
   @tReportParam  VariableTable READONLY,
   @cValue01      NVARCHAR( 20) OUTPUT,  
   @cValue02      NVARCHAR( 20) OUTPUT,  
   @cValue03      NVARCHAR( 20) OUTPUT,  
   @cValue04      NVARCHAR( 20) OUTPUT,  
   @cValue05      NVARCHAR( 20) OUTPUT,  
   @cValue06      NVARCHAR( 20) OUTPUT,  
   @cValue07      NVARCHAR( 20) OUTPUT,    
   @cValue08      NVARCHAR( 20) OUTPUT,   
   @cValue09      NVARCHAR( 20) OUTPUT,   
   @cValue10      NVARCHAR( 20) OUTPUT,   
   @cPrinter      NVARCHAR( 10) OUTPUT,   
   @cSpoolerGroup NVARCHAR( 20) OUTPUT,   
   @nNoOfCopy     INT           OUTPUT,   
   @nErrNo        INT           OUTPUT,  
   @cErrMsg       NVARCHAR( 20) OUTPUT, 
   @cDataWindow   NVARCHAR( 50) OUTPUT,
   @cPrintCommand NVARCHAR( MAX) OUTPUT,  
   @cProcessType  NVARCHAR( 20) OUTPUT,   
   @c_PrintMethod NVARCHAR( 18) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount   INT
   DECLARE @cPickSlipNo NVARCHAR(10)
   DECLARE @cOrderKey   NVARCHAR(10)
   DECLARE @cLabelNo    NVARCHAR(20)
   DECLARE @cUserName   NVARCHAR( 20)
   DECLARE @cPrintType   NVARCHAR( 20) -- 'ZPL' or 'BARTENDER'

   -- Variable mapping
   SELECT @cLabelNo = Value FROM @tReportParam WHERE Variable = '@cLabelNo'
   SELECT @cPrintType = Value FROM @tReportParam WHERE Variable = '@cPrintType'
   SET @cValue01 = @cLabelNo
   SET @cValue02 = @cReportType

   IF @cPrintType = 'ZPL'
   BEGIN
      SET @cProcessType = 'ZPL'
   END


Quit:

END


GO