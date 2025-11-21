SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
    
/***************************************************************************/          
/* Store procedure: rdt_593SKULabel06                                      */          
/*                                                                         */          
/* Modifications log:                                                      */          
/*                                                                         */          
/* Date       Rev  Author   Purposes                                       */          
/* 2019-05-23 1.0  YeeKung  WMS-9060 Created                               */          
/***************************************************************************/          
CREATE PROC [RDT].[rdt_593SKULabel06] (          
   @nMobile       INT,                    
   @nFunc         INT,                    
   @cLangCode     NVARCHAR( 3),           
   @nStep         INT,                    
   @nInputKey     INT,                    
   @cFacility     NVARCHAR( 5),           
   @cStorerKey    NVARCHAR( 15),          
   @cLabelPrinter NVARCHAR( 10),          
   @cPaperPrinter NVARCHAR( 10),          
   @cOption       NVARCHAR( 1),           
   @cParam1Label  NVARCHAR( 20) OUTPUT,          
   @cParam2Label  NVARCHAR( 20) OUTPUT,          
   @cParam3Label  NVARCHAR( 20) OUTPUT,          
   @cParam4Label  NVARCHAR( 20) OUTPUT,          
   @cParam5Label  NVARCHAR( 20) OUTPUT,          
   @cParam1Value  NVARCHAR( 60) OUTPUT,          
   @cParam2Value  NVARCHAR( 60) OUTPUT,          
   @cParam3Value  NVARCHAR( 60) OUTPUT,          
   @cParam4Value  NVARCHAR( 60) OUTPUT,          
   @cParam5Value  NVARCHAR( 60) OUTPUT,          
   @cFieldAttr02  NVARCHAR( 1)  OUTPUT,          
   @cFieldAttr04  NVARCHAR( 1)  OUTPUT,          
   @cFieldAttr06  NVARCHAR( 1)  OUTPUT,          
   @cFieldAttr08  NVARCHAR( 1)  OUTPUT,          
   @cFieldAttr10  NVARCHAR( 1)  OUTPUT,          
   @nErrNo        INT           OUTPUT,          
   @cErrMsg       NVARCHAR( 20) OUTPUT          
)          
AS          
   SET NOCOUNT ON          
   SET QUOTED_IDENTIFIER OFF          
   SET ANSI_NULLS OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF          
          
   DECLARE @b_Success        INT            
            
   DECLARE @cDataWindow      		NVARCHAR( 50)            
         , @cManifestDataWindow  NVARCHAR( 50)            
            
   DECLARE @cTargetDB        		NVARCHAR( 20)            
   DECLARE @cUserName        		NVARCHAR( 18)            
   DECLARE @cLabelType       		NVARCHAR( 20)            
            
   DECLARE @cToteNo            	NVARCHAR( 20)            
          ,@cCartonType        	NVARCHAR( 10)            
          ,@nTranCount         	INT            
          ,@cGenLabelNoSP      	NVARCHAR(30)            
          ,@cPickDetailKey     	NVARCHAR(10)            
          ,@cPickSlipNo        	NVARCHAR(10)            
          ,@cOrderKey          	NVARCHAR(10)            
          ,@cLabelNo           	NVARCHAR(20)            
          ,@nCartonNo          	INT            
          ,@cLabelLine         	NVARCHAR(5)            
          ,@cExecStatements    	NVARCHAR(4000)            
          ,@cExecArguments     	NVARCHAR(4000)            
          ,@cSKU               	NVARCHAR(20)            
          ,@nTTL_PackedQty     	INT            
          ,@nTTL_PickedQty     	INT            
          ,@nQty               	INT            
          ,@nTotalPackedQty    	INT            
          ,@cType              	NVARCHAR(10)            
          ,@cLoadKey           	NVARCHAR(10)            
          ,@cTTLWeight         	NVARCHAR(10)            
          ,@nFocusParam        	INT            
          ,@bsuccess           	INT            
          --,@b_success        INT            
          ,@nSKUCnt            	INT            
          ,@nNoOfCopy          	INT            
          ,@cCountry           	NVARCHAR(30)            
          ,@cUPC               	NVARCHAR(20)            
            
   DECLARE @fCartonWeight    		FLOAT            
          ,@fCartonLength    		FLOAT            
          ,@fCartonHeight    		FLOAT            
          ,@fCartonWidth     		FLOAT            
          ,@fStdGrossWeight   	FLOAT            
          ,@fCartonTotalWeight  	FLOAT            
          ,@fCartonCube      		FLOAT            
          ,@nFromCartonNo    		INT            
          ,@nToCartonNo      		INT            
          ,@cOrderType       		NVARCHAR(10)            
          ,@bPrintManifest   		NVARCHAR(1)            
          ,@cCartonLabelNo   		NVARCHAR(20)            
          ,@cCCountry        		NVARCHAR(30)            
          ,@cAltSKU          		NVARCHAR(20)            
          ,@cStyle           		NVARCHAR(20)            
          ,@cLanguageCode    		NVARCHAR(5)            
          ,@nPreSetNoOfCopy   	INT            
          ,@cConsigneeKey    	NVARCHAR(15)               
         
      -- Check label printer blank            
   IF ISNULL(RTRIM(@cLabelPrinter),'')  = ''            
   BEGIN            
      SET @nErrNo = 138901            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq            
      GOTO Quit            
   END            
            
   SET @nTranCount = @@TRANCOUNT            
            
   BEGIN TRAN            
   SAVE TRAN rdt_593SKULabel06            
          
   SET @cLabelNo      = @cParam1Value            
            
   -- Check blank            
   IF ISNULL(RTRIM(@cLabelNo), '') = ''            
   BEGIN            
      SET @nErrNo = 138902            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --LabelNoReq            
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1            
      GOTO RollBackTran            
   END            
            
   IF NOT EXISTS ( SELECT 1 FROM dbo.RECEIPTDETAIL WITH (NOLOCK)            
                     WHERE StorerKey = @cStorerKey            
                     AND UserDefine01 = @cLabelNo)            
   BEGIN            
      SET @nErrNo = 138903            
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidLabelNo            
      EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1            
      GOTO RollBackTran            
   END            
            
   -- Print Carton Label --            
   SET @cDataWindow = ''            
   SET @cTargetDB   = ''            
   SET @nFromCartonNo = 0            
   SET @nToCartonNo = 0            
   SET @cPickSlipNo = ''            
            
   SELECT  	@cDataWindow = DataWindow,            
        		@cTargetDB = TargetDB            
   FROM rdt.rdtReport WITH (NOLOCK)            
   WHERE StorerKey = @cStorerKey            
    AND   ReportType = 'WWMTLBLLU'             
            
   SET @cOrderKey = ''                 
            
   SELECT TOP 1 @cLanguageCode = Code2            
   FROM dbo.Codelkup (NOLOCK)            
   WHERE ListName = 'LULUWWMT'            
		AND StorerKey = @cStorerKey            
          
   DECLARE C_WWMTLBLLU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
            
   SELECT SKU            
         ,beforereceivedqty            
   FROM dbo.receiptdetail WITH (NOLOCK)            
   WHERE StorerKey = @cStorerKey            
		AND UserDefine01 = @cLabelNo    
		AND beforereceivedqty <> 0             
            
   OPEN C_WWMTLBLLU            
   FETCH NEXT FROM C_WWMTLBLLU INTO  @cSKU, @nNoOfCopy            
   WHILE (@@FETCH_STATUS <> -1)            
   BEGIN         
         
      SET @cCCountry = 'CN'         
      
      IF (@nNoOfCopy  = 0 OR @nNoOfCopy  = '')      
      BEGIN      
         SET @nErrNo = 138904            
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --NoQtyPrint            
         EXEC rdt.rdtSetFocusField @nMobile, 2 -- Param1            
         GOTO Quit       
      END      
           
      SELECT @cAltSKU = AltSKU            
      FROM dbo.SKU WITH (NOLOCK)            
      WHERE StorerKey = @cStorerKey            
      	AND SKU = @cSKU            
            
      SET @cStyle = ''            
            
      SELECT @cStyle = Style         
      FROM dbo.SKU WITH (NOLOCK)            
      WHERE StorerKey = @cStorerKey            
      	AND SKU = @cSKU            
            
            
      IF EXISTS ( SELECT 1 FROM dbo.DocInfo WITH (NOLOCK)            
                  WHERE TableName = 'SKU'            
	                  AND Key1 = @CStyle            
	                  AND Key2 = @cLanguageCode )            
      BEGIN            
            
         EXEC RDT.rdt_BuiltPrintJob            
               @nMobile,            
               @cStorerKey,            
               'WWMTLBLLU',    -- ReportType            
               'WWMTLBLLU',    -- PrintJobName            
               @cDataWindow,            
               @cLabelPrinter,            
               @cTargetDB,            
               @cLangCode,            
               @nErrNo  OUTPUT,            
               @cErrMsg OUTPUT,            
               @cCCountry,            
               @cAltSKU,            
               @nNoOfCopy,            
               @cStorerKey              
            
      END          
      FETCH NEXT FROM C_WWMTLBLLU INTO  @cSKU, @nNoOfCopy            
            
   END            
   CLOSE C_WWMTLBLLU            
   DEALLOCATE C_WWMTLBLLU            
          
   GOTO Quit          
          
RollBackTran:          
   ROLLBACK TRAN rdt_593SKULabel06 -- Only rollback change made here          
Quit:          
   WHILE @@TRANCOUNT > @nTranCount -- Commit until the level we started          
      COMMIT TRAN   

SET QUOTED_IDENTIFIER OFF

GO