SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_838ShipLabel02                                  */
/* Copyright      : LF Logistics                                        */
/*                                                                      */
/* Date        Rev  Author       Purposes                               */
/* 13-06-2017  1.0  Ung          WMS-2164 Created                       */
/* 19-06-2019  1.1  Ung          WMS-9050 Add data window param         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_838ShipLabel02]
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
   @cDataWindow   NVARCHAR( 50) OUTPUT
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

   -- Variable mapping
   SELECT @cPickSlipNo = Value FROM @tReportParam WHERE Variable = '@cPickSlipNo'
   SELECT @cLabelNo = Value FROM @tReportParam WHERE Variable = '@cLabelNo'

   -- Get PickSlip info
   SELECT @cOrderKey = OrderKey FROM PackHeader WITH (NOLOCK) WHERE PickSlipNo = @cPickSlipNo
   
   -- Output param (isp_BT_Bartender_HK_Carton_Label_NIKE)
   SET @cValue01 = @cOrderKey -- Orders.OrderKey
   SET @cValue02 = @cLabelNo  -- LabelNo

Quit:

END


GO