SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_Print_CustomMap_CarterZPL                             */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 20-04-2018 1.0  Ung         WMS-3966 Temporary workaround                  */
/* 14-01-2018 1.1  PakYuen     INC0543032-Unable point to correct server(PY01)*/
/* 19-06-2019 2.0  Ung         WMS-9050 Add data window param                 */
/* 15-08-2021 2.1  YeeKung     WMS-17055 Add printcommand sp (yeekung01)      */
/******************************************************************************/

CREATE PROC [RDT].[rdt_Print_CustomMap_CarterZPL] (
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
   @cprintcommand NVARCHAR(MAX) OUTPUT,
   @cProcessType  NVARCHAR(20)  OUTPUT 
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @cReportType = 'UPSLABEL'
   BEGIN
   	  SELECT @cValue01 = Value FROM @tReportParam WHERE Variable = '@cLabelNo'   --PY01
      SELECT @cSpoolerGroup = 
         CASE @cFacility 
            WHEN 'QHW01' THEN 'QHWZPL' --'CTSZZPL'       -PY01
            WHEN 'SZC5'  THEN 'WGQZPL'
            ELSE @cSpoolerGroup
         END
   END
   
Quit:

END

GO