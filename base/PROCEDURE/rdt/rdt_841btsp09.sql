SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

    
/************************************************************************/    
/* Store procedure: rdt_841BTSP09                                       */    
/* Copyright      : LFL                                                 */    
/*                                                                      */    
/* Purpose: ANF Ecomm Bartender Printing SP                             */    
/*                                                                      */    
/* Called from: 3                                                       */    
/*    1. From PowerBuilder                                              */    
/*    2. From scheduler                                                 */    
/*    3. From others stored procedures or triggers                      */    
/*    4. From INTerface program. DX, DTS                                */    
/*                                                                      */    
/* Exceed version: 5.4                                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date         Rev  Author   Purposes                                  */      
/* 03-08-2022  1.0  yeekung  WMS-20464 Created                          */ 
/* 12-08-2022  1.1  yeekung  WMS-20500 Add PDF print (yeekung01)        */
/************************************************************************/    
    
CREATE   PROC [RDT].[rdt_841BTSP09] (    
   @nMobile     INT    
  ,@nFunc       INT    
  ,@cLangCode   NVARCHAR(3)    
  ,@cFacility   NVARCHAR(5)    
  ,@cStorerKey  NVARCHAR(15)    
  ,@cPrinterID  NVARCHAR(10)    
  ,@cDropID     NVARCHAR(20)    
  ,@cLoadKey    NVARCHAR(10)    
  ,@cLabelNo    NVARCHAR(20)    
  ,@cUserName   NVARCHAR(18)    
  ,@nErrNo      INT            OUTPUT    
  ,@cErrMsg     NVARCHAR(1024) OUTPUT    
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
    
   DECLARE @cLabelType  AS NVARCHAR(30)    
          ,@cOrderType  AS NVARCHAR(10)    
          ,@cLabelFlag  AS NVARCHAR(1)    
          ,@cPickSlipNo AS NVARCHAR(10)    
          ,@cExternORderKey AS NVARCHAR(30)    
          ,@cOrderKey   AS NVARCHAR(10)    
          ,@cShipperKey AS NVARCHAR(10)    
         ,@nCartonNo         INT     
         ,@cOrderGroup  NVARCHAR(20)
         ,@cTrackingno  NVARCHAR(20)
         ,@cPlatform    NVARCHAR(20)
         , @cShipLabelEcom NVARCHAR(20)
    
    
   SET @nErrNo     = 0    
   SET @cERRMSG    = ''    
    
   SET @cPickSlipNo = ''    
   SET @cOrderType = ''    
   SET @cLabelFlag = ''    
    
   IF ISNULL(@cLabelNo ,'' )  <> '' AND ISNULL(@cDropID ,'' )  = ''     
   BEGIN    
      SELECT TOP 1 @cPickSlipNo = PickSlipNo    
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND LabelNo = @cLabelNo    
   END    
   ELSE IF ISNULL(@cLabelNo ,'' )  = '' AND ISNULL(@cDropID ,'' )  <> ''     
   BEGIN    
      SELECT TOP 1  @cPickSlipNo = PickSlipNo    
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND DropID = @cDropID    
   END    
   ELSE    
   BEGIN    
      SELECT TOP 1  @cPickSlipNo = PickSlipNo    
      FROM dbo.PackDetail WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey    
      AND DropID = @cDropID    
      AND LabelNo = @cLabelNo     
   END    
    
   IF ISNULL(RTRIM(@cPickSlipNo),'') = ''    
   BEGIN    
      SELECT @cOrderKey   = PH.OrderKey,    
          @cPickSlipNo = PH.PickHeaderKey    
      FROM dbo.Pickheader PH WITH (NOLOCK)    
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK)  ON PD.OrderKey = PH.OrderKey    
      WHERE PD.StorerKey = @cStorerKey     
      AND PD.CaseID = @cLabelNo    
   END    
   ELSE    
   BEGIN    
      SELECT @cOrderKey = OrderKey    
      FROM dbo.PackHeader WITH (NOLOCK)    
      WHERE StorerKey = @cStorerKey     
      AND PickSlipNo = @cPickSlipNo    
   END    
    
   SELECT  @cExternOrderKey = ExternOrderKey    
          ,@cShipperKey     = ShipperKey    
          ,@cLoadKey        = LoadKey   
          , @cOrderGroup    = ordergroup
          ,@cTrackingno     = Trackingno
          ,@cPlatform       = Ecom_Platform
   FROM dbo.Orders WITH (NOLOCK)    
   WHERE StorerKey = @cStorerKey    
   AND OrderKey = @cOrderKey     
    
   IF @cShipperKey IN ( 'LFL01', 'DHL' )         
   BEGIN      
      SET @cLabelType = 'SHIPPLABELDTC'    
      EXEC dbo.isp_BT_GenBartenderCommand    
            @cPrinterID    
          , @cLabelType    
         , @cUserName    
          , @cLoadKey    
          , @cOrderKey -- OrderKey    
          , @cExternOrderKey    
          , @cLabelNo    
          , @cShipperKey    
          , ''    
          , ''    
          , ''    
          , ''    
          , ''    
          , @cStorerKey    
          , '1'    
          , '0'    
          , 'N'    
          , @nErrNo  OUTPUT    
          , @cERRMSG OUTPUT    
   END    
   ELSE    
   BEGIN   
      IF EXISTS (SELECT 1 FROM Codelkup (nolock) 
                  where listname='VIPORDTYPE' 
                     and storerkey=@cstorerkey
                     and code = @cOrdergroup
                     and short =@nFunc) 
      BEGIN
         SET @cLabelType = rdt.RDTGetConfig( @nFunc, 'ShipLabels', @cStorerKey)      
         IF @cLabelType = '0'      
            SET @cLabelType = ''   
      END
      ELSE
      BEGIN
         SET @cLabelType = rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey)      
         IF @cLabelType = '0'      
            SET @cLabelType = ''   
      END

      SET @cShipLabelEcom = rdt.RDTGetConfig( @nFunc, 'ShipLabelEC', @cStorerKey)        
      IF @cShipLabelEcom = '0'        
         SET @cShipLabelEcom = ''   
    
      IF @cLabelType <> ''      
      BEGIN      
         SELECT TOP 1 @nCartonNo = CartonNo      
         FROM dbo.PackDetail WITH (NOLOCK)      
         WHERE PickSlipNo = @cPickSlipNo      
         AND   LabelNo = @cLabelNo      
         ORDER BY 1      
      
         SET @nErrNo = 0      
         DECLARE @tSHIPPLABEL AS VariableTable      
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cStorerKey',   @cStorerKey)      
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cPickSlipNo',  @cPickSlipNo)    
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cloadkey',  @cLoadKey)    
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cOrderkey',  @cOrderKey)    
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@cShipperKey',  @cShipperKey)    
         INSERT INTO @tSHIPPLABEL (Variable, Value) VALUES ( '@nCartonNo',    @nCartonNo)  
         

         IF @cPlatform='PDD'
         BEGIN
            DECLARE @cPrinter      NVARCHAR( 10)
                  ,@cPrintData        NVARCHAR( MAX)
                  ,@cWorkingFilePath  NVARCHAR( 250)
                  ,@cFilePath         NVARCHAR( 250)
                  ,@cFileType         NVARCHAR( 10)
                  ,@cPrintServer      NVARCHAR( 50)
                  ,@cPrintFilePath  NVARCHAR(250)
                  ,@cFileName         NVARCHAR( 100)

            DECLARE @cWinPrinterName   NVARCHAR( 100),
                       @cPrintCommand       NVARCHAR(MAX) 

            SELECT @cWorkingFilePath = UDF01,
                     @cFileType = UDF02,
                     @cPrintServer = UDF03,
                     @cPrintFilePath = Notes   -- foxit program
            FROM dbo.CODELKUP WITH (NOLOCK)      
            WHERE LISTNAME = 'printlabel'        
            AND   StorerKey = @cStorerKey
            Order By Code

            SELECT @cWinPrinterName = WinPrinter
            FROM rdt.rdtPrinter WITH (NOLOCK)  
            WHERE PrinterID = @cPrinterID

            SET @cFileName =  RTRIM( @cTrackingno) + '.' + @cFileType

            IF CHARINDEX( 'SEND2PRINTER', @cPrintFilePath) > 0    
               SET @cPrintCommand = '"' + @cPrintFilePath + '" "' + @cWorkingFilePath + '\' + @cFileName + '" "33" "3" "' + @cWinPrinterName + '"'  

            SET @cLabelType=@cShipLabelEcom
            -- Print label
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cPrinterID, '',
               @cLabelType,  -- Report type
               @tSHIPPLABEL, -- Report params
               'rdt_840ExtInsPack06',
               @nErrNo  OUTPUT,
               @cErrMsg OUTPUT,
               1,
               @cPrintCommand
         END
         ELSE
         BEGIN
            -- Print label      
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 2, 1, @cFacility, @cStorerkey, @cPrinterID, '',       
               @cLabelType, -- Report type      
               @tSHIPPLABEL, -- Report params      
               'rdt_841BTSP09',       
               @nErrNo  OUTPUT,      
               @cErrMsg OUTPUT       
         END
      END    
      ELSE    
      BEGIN    
         SET @cLabelType = 'SHIPPLBLSP' -- 'SHIPPLABEL'    
    
         EXEC dbo.isp_BT_GenBartenderCommand    
               @cPrinterID    
             , @cLabelType    
             , @cUserName    
             , @cLoadKey    
             , @cOrderKey -- OrderKey    
             , @cShipperKey    
             , 0    
             , ''    
             , ''    
             , ''    
             , ''    
             , ''    
             , ''    
             , @cStorerKey    
             , '1'    
             , '0'    
             , 'N'    
             , @nErrNo  OUTPUT    
             , @cERRMSG OUTPUT    
      END     
   END    
    
   -- To Proceed Ecomm Despatch while Printing having error --    
   SET @nErrNo     = 0    
   SET @cERRMSG    = ''    
    
    
END 

GO