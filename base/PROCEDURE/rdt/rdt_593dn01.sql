SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/      
/* Store procedure: rdt_593DN01                                            */      
/*                                                                         */      
/* Modifications log:                                                      */      
/*                                                                         */      
/* Date       Rev  Author     Purposes                                     */      
/* 2021-03-09 1.0  Chermaine  WMS-16510 Created                            */     
/***************************************************************************/      
      
CREATE PROC [RDT].[rdt_593DN01] (      
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
         
   -- @cOrderKey mapping      
   SET @cOrderKey = @cParam1  
  
   DECLARE @cOrdType             NVARCHAR( 1)
   DECLARE @cDelNotes            NVARCHAR( 10)
   DECLARE @tDelNotes            VARIABLETABLE
   DECLARE @cUserDefine03        NVARCHAR( 20)
   DECLARE @cRtnNotes            NVARCHAR( 10)
   DECLARE @tRtnNotes            VARIABLETABLE
   DECLARE @cFacility            NVARCHAR( 5)
   DECLARE @cC_ISOCntryCode      NVARCHAR( 10)
   DECLARE @cDelNotesN           NVARCHAR( 10)
   DECLARE @tDelNotesN           VARIABLETABLE
   DECLARE @cRtnNotesN           NVARCHAR( 10)
   DECLARE @tRtnNotesN           VARIABLETABLE

   BEGIN  
      SELECT 
         @cOrdType = DocType,
         @cUserDefine03 = UserDefine03,
         @cC_ISOCntryCode = C_ISOCntryCode,
         @cFacility = Facility
      FROM dbo.Orders WITH (NOLOCK) 
      WHERE OrderKey = @cOrderKey
         
      IF @cOrdType = 'E' AND @cUserDefine03 <> 'FF' 
      BEGIN
         SELECT @cPaperPrinter = Printer_Paper
         FROM rdt.RDTMOBREC WITH (NOLOCK)
         WHERE Mobile = @nMobile

         IF @cC_ISOCntryCode = 'KR'
         BEGIN
            SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'PREDELNOTE', @cStorerKey)
            IF @cDelNotes = '0'
               SET @cDelNotes = ''

            SET @cRtnNotes = rdt.RDTGetConfig( @nFunc, 'PRERTNNOTE', @cStorerKey)
            IF @cRtnNotes = '0'
               SET @cRtnNotes = ''

            IF @cDelNotes <> ''
            BEGIN
               INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)  
               INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
               INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)
 
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,   
                  @cDelNotes, -- Report type  
                  @tDelNotes, -- Report params  
                  'rdtIICB2CDN',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
            END

            IF @cRtnNotes <> ''
            BEGIN
               INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)  
               INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
               INSERT INTO @tRtnNotes (Variable, Value) VALUES ( '@cFacility', @cFacility)

               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,   
                  @cRtnNotes, -- Report type  
                  @tRtnNotes, -- Report params  
                  'rdtIICB2CDN',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
            END
         END
         ELSE
         BEGIN
            SET @cDelNotesN = rdt.RDTGetConfig( @nFunc, 'PREDELNOTEN', @cStorerKey)
            IF @cDelNotesN = '0'
               SET @cDelNotesN = ''

            SET @cRtnNotesN = rdt.RDTGetConfig( @nFunc, 'PRERTNNOTEN', @cStorerKey)
            IF @cRtnNotesN = '0'
               SET @cRtnNotesN = ''

            IF @cDelNotesN <> ''
            BEGIN
               INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)  
               INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
               INSERT INTO @tDelNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)
 
               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,   
                  @cDelNotesN, -- Report type  
                  @tDelNotesN, -- Report params  
                  'rdtIICB2CDN',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
            END

            IF @cRtnNotesN <> ''
            BEGIN
               INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)  
               INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cC_ISOCntryCode', @cC_ISOCntryCode)
               INSERT INTO @tRtnNotesN (Variable, Value) VALUES ( '@cFacility', @cFacility)

               -- Print label  
               EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,   
                  @cRtnNotesN, -- Report type  
                  @tRtnNotesN, -- Report params  
                  'rdtIICB2CDN',   
                  @nErrNo  OUTPUT,  
                  @cErrMsg OUTPUT  
            END
         END
      END
   END
   
Quit: 

GO