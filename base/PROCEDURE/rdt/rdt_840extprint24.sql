SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_840ExtPrint24                                   */  
/* Purpose: Print carton label                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2022-07-12 1.0  James      WMS-20111. Created                        */  
/* 2022-12-29 1.1  James      WMS-21433 Only shipperkey = KERRY can     */
/*                            print kerry label (james01)               */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtPrint24] (  
   @nMobile     INT,  
   @nFunc       INT,   
   @cLangCode   NVARCHAR( 3),   
   @nStep       INT,   
   @nInputKey   INT,   
   @cStorerkey  NVARCHAR( 15),   
   @cOrderKey   NVARCHAR( 10),   
   @cPickSlipNo NVARCHAR( 10),   
   @cTrackNo    NVARCHAR( 20),   
   @cSKU        NVARCHAR( 20),   
   @nCartonNo   INT,  
   @nErrNo      INT           OUTPUT,   
   @cErrMsg     NVARCHAR( 20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cPaperPrinter     NVARCHAR( 10),  
           @cLabelPrinter     NVARCHAR( 10),  
           @cUserName         NVARCHAR( 18),  
           @cFacility         NVARCHAR( 5),  
           @cShippLabel       NVARCHAR( 10),  
           @cPackList         NVARCHAR( 10),
           @cOrd_TrackNo      NVARCHAR( 40),
           @cExternOrderKey   NVARCHAR( 50),
           @cFileName         NVARCHAR( 50),
           @dOrderDate        DATETIME,
           @nExpectedQty      INT = 0,
           @nPackedQty        INT = 0, 
           @nTempCartonNo     INT
             
  
   DECLARE @tShippLabel    VariableTable  
   DECLARE @tPackList      VariableTable  
   
   DECLARE @cShipperKey    NVARCHAR( 15)
   
   SELECT @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper,  
          @cFacility = Facility,  
          @cUserName = UserName  
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 4  
      BEGIN  
      	SELECT @cShipperKey = ShipperKey
      	FROM dbo.ORDERS WITH (NOLOCK)
      	WHERE OrderKey = @cOrderkey
      	
         SET @cShippLabel = rdt.RDTGetConfig( @nFunc, 'SHIPPLABEL', @cStorerkey)    
         IF @cShippLabel = '0'    
            SET @cShippLabel = ''    

         SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)    
         IF @cPackList = '0'  
            SET @cPackList = ''  
  
         IF @cShippLabel <> '' AND @cShipperKey = 'KERRY' 
         BEGIN  
            SELECT @nExpectedQty = ISNULL(SUM(Qty), 0) FROM PickDetail WITH (NOLOCK)
            WHERE Orderkey = @cOrderkey
               AND Storerkey = @cStorerkey
               AND Status < '9'

            SELECT @nPackedQty = ISNULL(SUM(Qty), 0) FROM dbo.PackDetail WITH (NOLOCK)
            WHERE PickSlipNo = @cPickSlipNo

            IF @nExpectedQty = @nPackedQty
            BEGIN
         	   SELECT 
         	      @cOrd_TrackNo = TrackingNo,
         	      @cExternOrderKey = ExternOrderKey,
         	      @dOrderDate = OrderDate
         	   FROM dbo.ORDERS WITH (NOLOCK)
         	   WHERE OrderKey = @cOrderKey
         	   
         	   DECLARE @curPrint CURSOR
         	   SET @curPrint = CURSOR LOCAL READ_ONLY FAST_FORWARD FOR
         	   SELECT CartonNo
         	   FROM dbo.PackDetail WITH (NOLOCK)
         	   WHERE PickSlipNo = @cPickSlipNo
         	   GROUP BY CartonNo
         	   ORDER BY CartonNo
         	   OPEN @curPrint
         	   FETCH NEXT FROM @curPrint INTO @nTempCartonNo
         	   WHILE @@FETCH_STATUS = 0
         	   BEGIN
         	      SET @cFileName = 'LBL_' + RTRIM( @cExternOrderKey) + '_' + 
         	                        RTRIM( @cOrd_TrackNo) + '_' +
         	                        CONVERT( VARCHAR( 8), @dOrderDate, 112) + '_' + 
         	                        CAST( @nTempCartonNo AS NVARCHAR( 1)) + '.pdf'
         	      DELETE FROM @tShippLabel            
                  INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)    
                  INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)  
                  INSERT INTO @tShippLabel (Variable, Value) VALUES ( '@nCartonNo',    @nTempCartonNo)  
             
                  -- Print label    
                  EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerKey, @cLabelPrinter, '',     
                     @cShippLabel, -- Report type    
                     @tShippLabel, -- Report params    
                     'rdt_840ExtPrint24',     
                     @nErrNo  OUTPUT,    
                     @cErrMsg OUTPUT, 
                     NULL, 
                     '', 
                     @cFileName
                  
                  FETCH NEXT FROM @curPrint INTO @nTempCartonNo
               END
            END    
         END  

         -- TH use this to print QR label by carton  
         IF @cPackList <> ''  
         BEGIN  
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)  
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)  
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)  
              
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, '', @cPaperPrinter,   
               @cPackList, -- Report type  
               @tPackList, -- Report params  
               'rdt_840ExtPrint24',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT   
         END  
      END   -- IF @nStep = 4  
   END   -- @nInputKey = 1  
  
Quit:  

GO