SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_840ExtPrntORDLbl                                */  
/* Purpose: Print carton label                                          */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2024-02-22 1.0  SK      WMS-<<>>. Created                            */  
/*                                                                      */
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_840ExtPrntORDLbl] (  
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
             
  

   DECLARE @tPackList      VariableTable  
   
   SELECT @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper,  
          @cFacility = Facility,
        @cStorerkey = StorerKey,        
          @cUserName = UserName  
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
     Select 'rdt_840ExtPrntORDLbl'
           ,NULL
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
      IF @nStep = 3  
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
               'rdt_840ExtPrntORDLbl',   
               @nErrNo  OUTPUT,  
               @cErrMsg OUTPUT   
         END  
      END   -- IF @nStep = 3  
   END   -- @nInputKey = 1  
  
Quit:  

GO