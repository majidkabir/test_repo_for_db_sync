SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_841BTSP06                                       */
/* Copyright      : LFL                                                 */
/*                                                                      */
/* Purpose: ANF Ecomm Bartender Printing SP                             */
/*                                                                      */
/* Called from: rdtfnc_DTC_Dispatc                                      */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 07-Aug-2020 1.0  Chermaine WMS-14276 Created                         */  
/************************************************************************/

CREATE PROC [RDT].[rdt_841BTSP06] (
   @nMobile     INT,
   @nFunc       INT,
   @cLangCode   nvarchar(3),
   @cFacility   nvarchar(5),
   @cStorerKey  nvarchar(15),
   @cPrinterID  nvarchar(10),
   @cDropID     nvarchar(20),
   @cLoadKey    nvarchar(10),
   @cLabelNo    nvarchar(20),
   @cUserName   nvarchar(18),
   @nErrNo      int            OUTPUT,
   @cErrMsg     nvarchar(1024) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cLabelType     NVARCHAR(30)
          ,@cOrderType     NVARCHAR(10)
          ,@cLabelFlag     NVARCHAR(1)
          ,@cPickSlipNo    NVARCHAR(10)
          ,@cExternORderKey   NVARCHAR(30)
          ,@cOrderKey      NVARCHAR(10)
          ,@cShipperKey    NVARCHAR(10)
          ,@cPrinterName   NVARCHAR(100)
          
   DECLARE @tOutBoundList AS VariableTable  

   SET @nErrNo     = 0
   SET @cERRMSG    = ''

   SET @cPickSlipNo = ''
   SET @cOrderType = ''
   SET @cLabelFlag = ''

   SELECT @cPickSlipNo = PickSlipNo
   FROM dbo.PackDetail WITH (NOLOCK)
   WHERE DropID = @cDropID
   AND LabelNo = @cLabelNo

   -- (ChewKP01)
   IF ISNULL(RTRIM(@cPickSlipNo),'') = ''
   BEGIN
      SELECT --@cPickSlipNo = PH.PickHeaderKey
             @cOrderKey   = PH.OrderKey
      FROM dbo.Pickheader PH WITH (NOLOCK)
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK)  ON PD.OrderKey = PH.OrderKey
      WHERE PD.DropID = @cDropID
      AND PD.CaseID = @cLabelNo
   END
   ELSE
   BEGIN
      SELECT @cOrderKey = OrderKey
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE PickSlipNo = @cPickSlipNo
   END

   SELECT  @cExternOrderKey = ExternOrderKey
          ,@cShipperKey     = ShipperKey
          ,@cLoadKey        = LoadKey
   FROM dbo.Orders WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND OrderKey = @cOrderKey

   IF @cShipperKey LIKE 'LFL%'
   BEGIN
   	-- Common params    
      DELETE FROM @tOutBoundList  
        
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cStorerKey',  @cStorerKey)  
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)   

      -- Print label  
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterID, '',   
         'WAYBLLBL01', -- Report type  
         @tOutBoundList, -- Report params  
         'rdt_841BTSP06',   
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT
   END

   IF @cShipperKey IN ( 'DHL' )
   BEGIN
   	
   	-- Common params    
      DELETE FROM @tOutBoundList  
        
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cLoadKey',  @cLoadKey) 
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)  
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cExternOrderKey',   @cExternOrderKey) 
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@cCaseID',   @cLabelNo) 
      INSERT INTO @tOutBoundList (Variable, Value) VALUES ( '@ckey02',   @cShipperKey)

      -- Print label  
      EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cPrinterID, '',   
         'SHIPLBLDTC', -- Report type  
         @tOutBoundList, -- Report params  
         'rdt_841BTSP06',   
         @nErrNo  OUTPUT,  
         @cErrMsg OUTPUT
   END
   
   SET @nErrNo     = 0
   SET @cERRMSG    = ''
END

GO