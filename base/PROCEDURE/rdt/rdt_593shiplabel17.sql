SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_593ShipLabel17                                     */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Date        Rev  Author   Purposes                                      */
/* 2022-09-29  1.0  yeekung  WMS-20839 Created                              */
/***************************************************************************/

CREATE    PROC [RDT].[rdt_593ShipLabel17] (
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
   DECLARE @cExternorderkey   NVARCHAR( 20)
   DECLARE @nCartonNo      INT
   DECLARE @cOrderRefNo    NVARCHAR(20)
   DECLARE @dOrderDate     DATETIME
   DECLARE @cFileName      NVARCHAR(500)
   DECLARE @cShipLabel     NVARCHAR(20)
   DECLARE @cInvoiceLbl    NVARCHAR(20)
   DECLARE @cTrackingNo    NVARCHAR(20)

   IF @cOption ='3'
   BEGIN

      -- Parameter mapping
      SET @cStorerkey = @cParam1
      SET @cPickSlipNo = @cParam2
      SET @nCartonNo = @cParam3

      -- Check blank
      IF @cPickSlipNo = ''
      BEGIN
         SET @nErrNo = 192201
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
         SET @nErrNo = 192202
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid pickslipno
         GOTO Quit
      END

          
      SELECT     
         @cOrderRefNo = ExternOrderkey,
         @dOrderDate = OrderDate,
         @cTrackingNo = trackingno
      FROM Orders WITH (NOLOCK)     
      WHERE OrderKey = @cOrderkey  
      AND ECOM_Platform='SFCC'

      IF @@ROWCOUNT = 0
      BEGIN
         SET @nErrNo = 192203
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid order
         GOTO Quit
      END

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
            'rdt_593ShipLabel17',         
            @nErrNo  OUTPUT,        
            @cErrMsg OUTPUT, 
            NULL, 
            '', 
            @cFileName            
      END     
   END
   ELSE IF @cOption ='4'
   BEGIN
      -- Parameter mapping
      SET @cOrderKey = @cParam1

      DECLARE @tOrderkey table
      ( orderkey nvarchar(20))

      INSERT into @tOrderkey (orderkey)
      select value 
      from string_split(@cParam1,',')

      SET @cInvoiceLbl = rdt.RDTGetConfig( @nFunc, 'InvoiceLbl', @cStorerkey)        
      IF @cInvoiceLbl = '0'        
         SET @cInvoiceLbl = ''        
      
      IF @cInvoiceLbl <> ''      
      BEGIN      

         SELECT @cLabelPrinter=printer,
                @cPaperprinter = printer_paper
         FROM rdt.rdtmobrec (nolock)
         where mobile=@nMobile

         DECLARE @cur_order cursor
         SET @cur_order =  CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         SELECT o.orderkey,o.externorderkey
         from orders o WITH (nolock) 
         JOIN @tOrderkey od on (o.orderkey=od.orderkey)
         WHERE o.storerkey=@cstorerkey

         OPEN @cur_order  
         FETCH NEXT FROM @cur_order INTO @cOrderkey, @cExternorderkey  

         WHILE @@FETCH_STATUS<>-1
         BEGIN
                   
            SELECT     
               @cOrderRefNo = ExternOrderkey,
               @dOrderDate = OrderDate,
               @cTrackingNo = trackingno
            FROM Orders WITH (NOLOCK)     
            WHERE OrderKey = @cOrderkey  
            AND ECOM_Platform<>'SFCC'

            IF @@ROWCOUNT = 0
            BEGIN
               SET @nErrNo = 192204
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid order
               GOTO Quit
            END
         
            DECLARE @tInvoicelbl VariableTable

            INSERT INTO @tInvoicelbl (Variable, Value) VALUES ( '@cOrderkey',   @cOrderkey)        
            INSERT INTO @tInvoicelbl (Variable, Value) VALUES ( '@cExternorderkey',  @cExternorderkey)      

            -- Print label        
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, @cPaperprinter,         
               @cInvoiceLbl, -- Report type        
               @tInvoicelbl, -- Report params        
               'rdt_593ShipLabel17',         
               @nErrNo  OUTPUT,        
               @cErrMsg OUTPUT, 
               NULL, 
               ''       
            FETCH NEXT FROM @cur_order INTO @cOrderkey, @cExternorderkey  
         END
         CLOSE @cur_order  
         DEALLOCATE @cur_order  
      END   
   END


Quit:

GO