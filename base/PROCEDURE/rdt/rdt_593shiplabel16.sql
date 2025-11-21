SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_593ShipLabel16                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date        Rev  Author   Purposes                                      */
/* 2022-08-08  1.0  yeekung  WMS-20452 Created                              */
/***************************************************************************/

CREATE PROC [RDT].[rdt_593ShipLabel16] (
   @nMobile    INT,
   @nFunc      INT,
   @nStep      INT,
   @cLangCode  NVARCHAR( 3),
   @cStorerKey NVARCHAR( 15),
   @cOption    NVARCHAR( 1),
   @cParam1    NVARCHAR( 60),  -- Label No
   @cParam2    NVARCHAR( 60),
   @cParam3    NVARCHAR( 60),
   @cParam4    NVARCHAR( 60),
   @cParam5    NVARCHAR( 60),
   @nErrNo     INT OUTPUT,
   @cErrMsg    NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nRowCount      INT
   DECLARE @cFacility      NVARCHAR( 5)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cPaperPrinter  NVARCHAR( 10)
   DECLARE @cDropID        NVARCHAR( 20)
   DECLARE @cCartonType    NVARCHAR( 30)
   DECLARE @cPickSlipNo    NVARCHAR( 10)
   DECLARE @cOrderKey      NVARCHAR( 10)
   DECLARE @nCartonNo      INT
   DECLARE @cOrderRefNo    NVARCHAR(20)
   DECLARE @dOrderDate     DATETIME
   DECLARE @cFileName      NVARCHAR(500)
   DECLARE @cShipLabel     NVARCHAR(20)
   DECLARE @cTrackingNo    NVARCHAR(20)


   -- Parameter mapping
   SET @cStorerkey = @cParam1
   SET @cPickSlipNo = @cParam2
   SET @nCartonNo = @cParam3

   -- Check blank
   IF @cPickSlipNo = ''
   BEGIN
      SET @nErrNo = 189501
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need pickslipno
      GOTO Quit
   END

   -- Get PackDetail info
   SELECT TOP 1
      @cOrderKey = OrderKey
   FROM dbo.PackDetail PD WITH (NOLOCK)
      JOIN dbo.PackHeader PH WITH (NOLOCK) ON ( PD.PickSlipNo = PH.PickSlipNo)
   WHERE PD.pickslipno = @cPickSlipNo
      AND PD.StorerKey = @cStorerKey
      AND PD.cartonno=@nCartonNo

   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 189502
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid pickslipno
      GOTO Quit
   END

          
   SELECT     
      @cOrderRefNo = ExternOrderkey,
      @dOrderDate = OrderDate,
      @cTrackingNo = trackingno
   FROM Orders WITH (NOLOCK)     
   WHERE OrderKey = @cOrderkey   

   SET @cShipLabel = rdt.RDTGetConfig( @nFunc, 'SHIPLABEL', @cStorerkey)        
   IF @cShipLabel = '0'        
      SET @cShipLabel = ''        
      
   IF @cShipLabel <> ''      
   BEGIN      
      SET @cFileName = 'LBL_' + RTRIM( @cOrderRefNo) + '_' + 
                 	      RTRIM( @cTrackingNo) + '_' +
               	      CONVERT( VARCHAR( 8), @dOrderDate, 112) + '_1' + '.pdf'

      SELECT @cLabelPrinter=printer,
             @cPaperprinter = printer_paper
      FROM rdt.rdtmobrec (nolock)
      where mobile=@nMobile

      DECLARE @tShipLabel VariableTable

      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)        
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)      
      INSERT INTO @tShipLabel (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)      
                 
      -- Print label        
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperprinter,         
         @cShipLabel, -- Report type        
         @tShipLabel, -- Report params        
         'rdt_593ShipLabel16',         
         @nErrNo  OUTPUT,        
         @cErrMsg OUTPUT, 
         NULL, 
         '', 
         @cFileName            
   END     

Quit:



GO