SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Store procedure: rdtLBL01                                               */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date       Rev  Author   Purposes                                       */      
/* 2015-10-29 1.0  ChewKP   SOS#355776 Created                             */     
/***************************************************************************/      
      
CREATE PROC [RDT].[rdtLBL01] (      
   @nMobile    INT,      
   @nFunc      INT,      
   @nStep      INT,      
   @cLangCode  NVARCHAR( 3),      
   @cStorerKey NVARCHAR( 15),      
   @cOption    NVARCHAR( 1),      
   @cParam1    NVARCHAR(20),  -- OrderKey      
   @cParam2    NVARCHAR(20),        
   @cParam3    NVARCHAR(20),  -- ExternOrderKey     
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
         , @cOrderKey     NVARCHAR( 10)
         , @cExternOrderKey NVARCHAR(20)  
         , @cUserName       NVARCHAR(18)
         , @cFileName         NVARCHAR( 50)        
         , @cFilePath         NVARCHAR( 30)     
         , @cPrintFilePath    NVARCHAR(100)    
         , @cPrintCommand     NVARCHAR(MAX)  
         , @cWinPrinter       NVARCHAR(128)
         , @cPrinterName      NVARCHAR(100) 
         , @cTargetDB         NVARCHAR(20)     
    
       
       
   -- mapping      
   SET @cOrderKey       = @cParam1     
   SET @cExternOrderKey = @cParam3  
  
    
   -- Check blank      
   IF ISNULL( @cOrderKey, '') = ''  AND ISNULL( @cExternOrderKey, '') = '' 
   BEGIN      
      SET @nErrNo = 94751      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --EitherKeyReq  
      GOTO Quit      
   END      
   
   IF ISNULL(@cOrderKey,'') <> '' 
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                      WHERE OrderKey = @cOrderKey
                      AND StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 94752 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidOrderKey  
         GOTO Quit    
      END
      
      
   END
   
   IF ISNULL(@cExternOrderKey,'') <> '' 
   BEGIN
      IF NOT EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                      WHERE ExternOrderKey = @cExternOrderKey
                      AND StorerKey = @cStorerKey ) 
      BEGIN
         SET @nErrNo = 94753 
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode,'DSP') --InvalidExternKey  
         GOTO Quit    
      END
      
      SELECT @cOrderKey = OrderKey
      FROM dbo.Orders WITH (NOLOCK)
      WHERE ExternOrderKey = @cExternOrderKey 
      
   END
     
  
    
   -- Get printer info      
   SELECT       
      @cUserName = UserName,     
      @cLabelPrinter = Printer,       
      @cPaperPrinter = Printer_Paper      
   FROM rdt.rdtMobRec WITH (NOLOCK)      
   WHERE Mobile = @nMobile      
       
         
   /*-------------------------------------------------------------------------------      
      
                                    Print Label      
      
   -------------------------------------------------------------------------------*/      
      
   -- Check label printer blank      
   IF @cLabelPrinter = ''      
   BEGIN      
      SET @nErrNo = 94754      
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --LabelPrnterReq      
      GOTO Quit      
   END      
   
   
   IF EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                        WHERE OrderKey = @cOrderKey
                        AND PrintFlag IN ('1' , '2')  ) 
   BEGIN
       SELECT @cTargetDB = TargetDB       
       FROM rdt.rdtReport WITH (NOLOCK)       
       WHERE StorerKey = @cStorerKey      
       AND   ReportType = 'WAYBILL'      

       -- Check if it is Metapack printing  
       SELECT @cFilePath = Long, @cPrintFilePath = Notes   
       FROM dbo.CODELKUP WITH (NOLOCK)    
       WHERE LISTNAME = 'CaiNiao'    
       AND   Code = 'WayBill'  
        
       
       SELECT @cWinPrinter = WinPrinter
       FROM rdt.rdtPrinter WITH (NOLOCK)
       WHERE PrinterID = @cLabelPrinter
       
       SET @cPrinterName = LEFT( @cWinPrinter , (CHARINDEX(',' , @cWinPrinter) - 1) )
       
       
       IF ISNULL( @cFilePath, '') <> ''  
       BEGIN  
          SET @cFileName = 'WB_' + RTRIM(@cOrderKey) + '.pdf'   
          SET @cPrintCommand = '"' + @cPrintFilePath + '" /t "' + @cFilePath + '\' + @cFileName + '" "' + @cPrinterName + '"'                            
          
          
            
          
          EXEC RDT.rdt_BuiltPrintJob        
           @nMobile,        
           @cStorerKey,        
           'WAYBILL',              -- ReportType        
           'WAYBILL',    -- PrintJobName        
           @cFileName,        
           @cLabelPrinter,        
           @cTargetDB,        
           @cLangCode,        
           @nErrNo  OUTPUT,        
           @cErrMsg OUTPUT,         
           '',       
           '',    
           '',  
           '',  
           '',  
           '',  
           '',  
           '',  
           '',  
           '',  
           '1',  
           @cPrintCommand  
     
           
     
           UPDATE dbo.Orders WITH (ROWLOCK) 
           SET PrintFlag = '2'
              ,TrafficCop = NULL 
           WHERE OrderKey = @cOrderKey 
           
           IF @@ERROR <> 0 
           BEGIN
              SET @nErrNo = 94757        
              SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UpdOrdFail'      
              GOTO QUIT       
           END
           
       END   -- @cFilePath 
   END
   ELSE
   BEGIN
      SET @nErrNo = 94756
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NoWayBill      
      GOTO Quit  
   END
     
    
    
Quit:      


GO