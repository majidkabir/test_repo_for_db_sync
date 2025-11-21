SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

  
/************************************************************************/  
/* Store procedure: rdt_841ExtPrntORDLbl                                */  
/* Purpose: Print carton label                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-02-22 1.0  SK      WMS-<<>>. Created                            */  
/*                                                                      */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_841ExtPrntORDLbl] (  
   @nMobile             INT,  
   @nFunc               INT,   
   @cLangCode           NVARCHAR(3),   
   @cFacility           NVARCHAR(5),    
   @cStorerkey          NVARCHAR(15),   
   @cLabelPrinter       NVARCHAR(10) ,
   @cDropID             NVARCHAR(20),   
   @cLoadKey            NVARCHAR(20),   
   @cLabelNo            NVARCHAR(20),   
   @cUserName           NVARCHAR(18),
   @nErrNo              INT           OUTPUT,   
   @cErrMsg             NVARCHAR(20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON     
   SET ANSI_NULLS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cPaperPrinter        NVARCHAR(10),  
           @nInputKey            INT,  
           @nStep                INT,  
           @cOrderkey            NVARCHAR(10),  
           @cPickSlipNo          NVARCHAR(10),  
           @cPackList            NVARCHAR(10),
           @cOrd_TrackNo         NVARCHAR(40),
           @cExternOrderKey      NVARCHAR(50),
           @cFileName            NVARCHAR(50),
           @dOrderDate           DATETIME,
           @nExpectedQty         INT = 0,
           @nPackedQty           INT = 0, 
           @nTempCartonNo        INT
             
  
   DECLARE @tPackList      VariableTable  

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
      SELECT --@cPickSlipNo = PH.PickHeaderKey
             @cOrderKey   = PH.OrderKey
      FROM dbo.Pickheader PH WITH (NOLOCK)
      INNER JOIN dbo.PickDetail PD WITH (NOLOCK)  ON PD.OrderKey = PH.OrderKey
      WHERE PD.StorerKey = @cStorerKey 
      AND PD.DropID = @cDropID
      AND PD.CaseID = @cLabelNo
   END
   ELSE
   BEGIN

      SELECT @cOrderKey = OrderKey
      FROM dbo.PackHeader WITH (NOLOCK)
      WHERE StorerKey = @cStorerKey 
      AND PickSlipNo = @cPickSlipNo

   END

   SELECT @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper,       
          @cUserName = UserName,
        @nInputKey = InputKey,
        @nStep = Step
   FROM RDT.RDTMOBREC WITH (NOLOCK)  
   WHERE Mobile = @nMobile  
  

   -- Insert test
   INSERT INTO [dbo].[TraceInfo]
      ([TraceName]
      ,[TimeIn]
      ,[TimeOut]
      ,[TotalTime]
      ,[Step1]
      ,[Step2]
      ,[Step3]
      ,[Step4]
      ,[Step5]
      ,[Col1]
      ,[Col2]
      ,[Col3]
      ,[Col4]
      ,[Col5])
   Select 'rdt_841ExtPrntORDLbl'
      ,getdate()
      ,NULL
      ,NULL
      ,@nInputKey
      ,@nStep
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL
      ,NULL


   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 2  
      BEGIN  

         SET @cPackList = rdt.RDTGetConfig( @nFunc, 'PackList', @cStorerKey)    
         IF @cPackList = '0'  
            SET @cPackList = ''  


         -- TH use this to print QR label by carton  
         IF @cPackList <> ''  
         BEGIN  
            INSERT INTO @tPackList (Variable, Value) VALUES ( '@cOrderKey',   @cOrderKey)  
              
            -- Print label  
            EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, @nStep, @nInputKey, @cFacility, @cStorerkey, @cLabelPrinter, @cPaperPrinter,   
               @cPackList, -- Report type  
               @tPackList, -- Report params  
               'rdt_841ExtPrntORDLbl',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT   
         END  
      END   -- IF @nStep = 2  
   END   -- @nInputKey = 1  
  
Quit:  

GO