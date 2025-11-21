SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/******************************************************************************/    
/* Store procedure: isp_TPS_ExtPrint02                                        */    
/* Copyright      : LFLogistics                                               */    
/*                                                                            */    
/* Date         Rev  Author     Purposes                                      */    
/* 2022-03-31   1.0  yeekung   LFWM-3343 Created                               */    
/******************************************************************************/    
    
CREATE   PROC [API].[isp_TPS_ExtPrint02] (    
 @cStorerKey       NVARCHAR( 15),  
   @cFacility        NVARCHAR( 5),    
   @nFunc            INT,        
   @cUserName        NVARCHAR( 128),  
   @cLangCode        NVARCHAR( 3),   
   @cScanNo          NVARCHAR( 50),  
   @cpickslipNo      NVARCHAR( 30),  
   @cDropID          NVARCHAR( 50),  
   @cOrderKey        NVARCHAR( 10),  
   @cLoadKey         NVARCHAR( 10),  
   @cZone            NVARCHAR( 18),  
   @EcomSingle       NVARCHAR( 1),   
   @nCartonNo        INT,        
   @cCartonType      NVARCHAR( 10),   
   @cType            NVARCHAR( 30),   
   @fCartonWeight    FLOAT,       
   @fCartonCube      FLOAT,       
   @cWorkstation     NVARCHAR( 30),   
   @cLabelNo         NVARCHAR( 20),  
   @cCloseCartonJson NVARCHAR (MAX),  
   @cPrintPackList   NVARCHAR(1),  
   @cLabelJobID      NVARCHAR ( 30) OUTPUT,  
   @cPackingJobID    NVARCHAR ( 30) OUTPUT ,  
   @b_Success        INT = 1        OUTPUT,  
   @n_Err            INT = 0        OUTPUT,  
   @c_ErrMsg         NVARCHAR( 255) = ''  OUTPUT   
)    
AS    
    
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    
  
DECLARE @curAD CURSOR  
DECLARE   
 @cSKU             NVARCHAR(20),  
   @cSkuBarcode      NVARCHAR(60),  
   @cOrderLineNumber NVARCHAR(5),  
   @cWeight          NVARCHAR(10),  
   @cCube            NVARCHAR(10),  
   @cLottableVal     NVARCHAR(20),  
   @cSerialNoKey     NVARCHAR(60),  
   @cErrMsg          NVARCHAR(128),  
   @nQty             INT,  
   @bsuccess         INT,  
   @nErrNo           INT,  
   @nTranCount       INT  
     
DECLARE @CloseCtnList TABLE (  
   SKU             NVARCHAR( 20),  
   QTY             INT,  
   Weight          FLOAT,  
   Cube            FLOAT,    
   lottableVal     NVARCHAR(60),  
   SkuBarcode      NVARCHAR(60),  
   ADCode          NVARCHAR(60)  
)  

  
DECLARE @tShipLabel AS VariableTable  
DECLARE @cConsignee     NVARCHAR(15)  
DECLARE @cLabelPrinter  NVARCHAR ( 30)  
DECLARE @cPaperPrinter  NVARCHAR ( 30)  
DECLARE @nJobID         INT  
DECLARE @nRC            INT  
DECLARE @cSQL           NVARCHAR ( MAX)  
DECLARE @cSQLParam      NVARCHAR ( MAX)  
DECLARE @cColumn        NVARCHAR( 60)  
DECLARE @cValue         NVARCHAR( 60)  
  
set @cLabelJobID = ''  
set @cPackingJobID = ''  
  
BEGIN  
 IF @cPickSlipNo <> ''  
 BEGIN  
    
   INSERT INTO @tShipLabel (Variable, Value) VALUES   
      ( '@c_StorerKey',     @cStorerKey),   
      ( '@c_PickSlipNo',    @cPickSlipNo),   
      ( '@c_StartCartonNo', CAST( @nCartonNo AS NVARCHAR(10))),  
      ( '@c_EndCartonNo',   CAST( @nCartonNo AS NVARCHAR(10)))   
        
      -- Print label  
      IF EXISTS (select TOP 1 1 FROM rdt.rdtReport WITH (NOLOCK) WHERE StorerKey = @cStorerKey AND reportType ='TPSHIPPLBL')  
      BEGIN  
         IF ISNULL(@cLabelPrinter,'') = ''  
         BEGIN  
            SET @b_Success = 0    
            SET @n_Err = 175743    
            SET @c_ErrMsg = rdt.rdtgetmessage( @n_Err, @cLangCode, 'DSP')--'Label Printer setup not done. Please setup the Label Printer. Function : isp_TPS_ExtPrint02'  
            GOTO Quit  
         END  
         ELSE  
         BEGIN  
            EXEC API.isp_Print @cLangCode, @cFacility, @cStorerKey, @cLabelPrinter, @cPaperPrinter,   
               'TPSHIPPLBL', -- Report type  
               @tShipLabel, -- Report params  
               'API.isp_TPS_ExtPrint02', --source Type  
               @n_Err      OUTPUT,  
               @c_ErrMsg   OUTPUT,  
               '1', --noOfCopy  
               '', --@cPrintCommand  
               @nJobID     OUTPUT,  
               @cUsername  
  
            set @cLabelJobID = @nJobID  
         END   
      END
   END
 
   
Quit:  
  
END  

GO