SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/
/* Store procedure: rdt_Print_CustomMap_BBGCN                                 */
/* Copyright      : LF Logistics                                              */
/*                                                                            */
/* Date       Rev  Author      Purposes                                       */
/* 31-05-2019 1.0  Ung         WMS-9050 Created                               */
/* 15-08-2021 1.1  YeeKung     WMS-17055 Add printcommand sp (yeekung01)      */
/******************************************************************************/

CREATE PROC [RDT].[rdt_Print_CustomMap_BBGCN] (
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
   
   IF @cReportType = 'PACKLIST'
   BEGIN
   	DECLARE @cPickSlipNo NVARCHAR(10)
   	DECLARE @cOrderKey NVARCHAR(10)
   	DECLARE @cOrderGroup NVARCHAR(20)
   	
   	-- Get pick slip info
   	SELECT @cPickSlipNo = Value FROM @tReportParam WHERE Variable = '@cPickSlipNo'
      SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
      SELECT @cOrderGroup = OrderGroup FROM Orders WITH (NOLOCK) WHERE OrderKey = @cOrderKey 
      
      SET @cValue01 = @cPickSlipNo
      SET @cValue02 = @cOrderGroup
      
      -- Output respective data window
      IF @cValue02 = 'EU' SET @cDataWindow = 'r_dw_packing_list_by_ctn17_rdt' ELSE
      IF @cValue02 = 'AU' SET @cDataWindow = 'r_dw_packing_list_by_ctn15_rdt' ELSE            
      IF @cValue02 = 'US' SET @cDataWindow = 'r_dw_packing_list_by_ctn16_rdt' ELSE SET @cDataWindow = ''

   END
   
Quit:

END

GO