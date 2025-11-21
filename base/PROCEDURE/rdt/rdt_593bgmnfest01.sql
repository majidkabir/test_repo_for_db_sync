SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Store procedure: rdt_593BGMnfest01                                      */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date       Rev  Author     Purposes                                     */      
/* 2021-03-09 1.0  Chermaine  WMS-16510 Created                            */    
/***************************************************************************/      
      
CREATE PROC [RDT].[rdt_593BGMnfest01] (      
   @nMobile    INT,      
   @nFunc      INT,      
   @nStep      INT,      
   @cLangCode  NVARCHAR( 3),      
   @cStorerKey NVARCHAR( 15),      
   @cOption    NVARCHAR( 1),      
   @cParam1    NVARCHAR(20),  -- LoadKey      
   @cParam2    NVARCHAR(20),        
   @cParam3    NVARCHAR(20),  -- LabelNo      
   @cParam4    NVARCHAR(20),      
   @cParam5    NVARCHAR(20),      
   @nErrNo     INT OUTPUT,      
   @cErrMsg    NVARCHAR( 20) OUTPUT      
)      
AS      
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
      
   DECLARE @b_Success     INT      
         
   DECLARE @cLabelPrinter NVARCHAR( 10)      
   DECLARE @cPaperPrinter NVARCHAR( 10)      
   
   DECLARE @cLabelType    NVARCHAR( 20)      
   DECLARE @cUserName     NVARCHAR( 18)       
     
   DECLARE @cLabelNo      NVARCHAR(20)    
         , @cDropid       NVARCHAR(20) 
         , @cPrintCartonLabel NVARCHAR(1)   
         , @cOrderCCountry    NVARCHAR(30)  
         , @cOrderType        NVARCHAR(10)  
         , @cLoadKey      NVARCHAR(10)   
         , @cTargetDB     NVARCHAR(20)    
         , @cVASType      NVARCHAR(10)  
         , @cField01      NVARCHAR(10)   
         , @cTemplate     NVARCHAR(50)   
         , @cOrderKey     NVARCHAR(10)  
         , @cPickSlipNo   NVARCHAR(10)   
         , @nCartonNo     INT  
         , @cCodeTwo      NVARCHAR(30)  
         , @cTemplateCode NVARCHAR(60)  
         , @cPasscode     NVARCHAR(20) -- (ChewKP02) 
         , @cDataWindow   NVARCHAR( 50) -- (ChewKP03) 
         
   -- cLabelNo mapping      
   SET @cLabelNo = @cParam1  

   SELECT @cOrderKey = b.orderkey 
   FROM PACKDETAIL A WITH (NOLOCK)
   JOIN PACKHEADER B WITH (NOLOCK) ON A.PICKSLIPNO = B.PICKSLIPNO
   WHERE A.LABELNO = @cLabelNo
   AND   A.STORERKEY = @cStorerKey   
   
   SELECT       
      @cUserName = UserName,     
      @cLabelPrinter = Printer,       
      @cPaperPrinter = Printer_Paper      
   FROM rdt.rdtMobRec WITH (NOLOCK)      
   WHERE Mobile = @nMobile  

   SELECT @cDataWindow = DataWindow,          
         @cTargetDB = TargetDB          
   FROM rdt.rdtReport WITH (NOLOCK)          
   WHERE StorerKey = @cStorerKey          
   AND   ReportType = 'BAGMANFEST'     
   AND   Function_id in ('0','593')


   BEGIN
        EXEC RDT.rdt_BuiltPrintJob          
        @nMobile,          
        @cStorerKey,          
        'BAGMANFEST',              -- ReportType          
        'LVS_CUSTOMERMANIFEST',    -- PrintJobName          
        @cDataWindow,          
        @cPaperPrinter,          
        @cTargetDB,          
        @cLangCode,          
        @nErrNo  OUTPUT,          
        @cErrMsg OUTPUT,          
        @cOrderkey,          
        @cLabelNo 
   END

Quit: 

GO