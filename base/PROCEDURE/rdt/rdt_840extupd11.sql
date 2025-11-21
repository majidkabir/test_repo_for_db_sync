SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/    
/* Store procedure: rdt_840ExtUpd11                                     */    
/* Purpose: Insert transmitlog2 record                                  */    
/*                                                                      */    
/* Modifications log:                                                   */    
/*                                                                      */    
/* Date        Rev  Author     Purposes                                 */    
/* 2020-07-05  1.0  James      WMS-14993. Created                       */    
/* 2020-12-02  1.1  James      WMS-15773 Block and print label when user*/  
/*                             scan on hold orders (james01)            */ 
/* 2021-04-01  1.2  YeeKung    WMS-16717 Add serialno and serialqty     */
/*                            Params (yeekung01)                        */  
/************************************************************************/    
    
CREATE PROC [RDT].[rdt_840ExtUpd11] (    
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
   @cSerialNo   NVARCHAR( 30), 
   @nSerialQTY  INT,      
   @nErrNo      INT           OUTPUT,    
   @cErrMsg     NVARCHAR( 20) OUTPUT    
)    
AS    
    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
    
   DECLARE @nTranCount           INT  
   DECLARE @cOrdType             NVARCHAR( 1)  
   DECLARE @cDelNotes            NVARCHAR( 10)  
   DECLARE @tDelNotes            VARIABLETABLE  
   DECLARE @cPaperPrinter        NVARCHAR( 10)  
   DECLARE @cSOStatus            NVARCHAR( 10)  
   DECLARE @cErrMsg1             NVARCHAR( 20)  
   DECLARE @cErrMsg2             NVARCHAR( 20)  
   DECLARE @cErrMsg3             NVARCHAR( 20)  
   DECLARE @cErrMsg4             NVARCHAR( 20)  
   DECLARE @cErrMsg5             NVARCHAR( 20)  
   DECLARE @cOnHoldLbl           NVARCHAR( 10)  
   DECLARE @tOnHoldLbl           VARIABLETABLE  
   DECLARE @cLabelPrinter        NVARCHAR( 10)  
   DECLARE @nOnHold              INT = 0  
     
   IF @nStep = 1    
   BEGIN    
      IF @nInputKey = 1   
      BEGIN    
         SELECT @cPaperPrinter = Printer_Paper,  
                @cLabelPrinter = Printer  
         FROM rdt.RDTMOBREC WITH (NOLOCK)  
         WHERE Mobile = @nMobile  
  
         SELECT @cOrdType = DocType,  
                @cSOStatus = SOStatus  
         FROM dbo.Orders WITH (NOLOCK)   
         WHERE OrderKey = @cOrderKey  
           
         -- (james01)  
         IF EXISTS ( SELECT 1 FROM dbo.PICKDETAIL WITH (NOLOCK)  
                     WHERE OrderKey = @cOrderKey  
                     AND   [Status] = '4') OR @cSOStatus = 'HOLD'  
         BEGIN  
            SET @nOnHold = 1  
            SET @nErrNo = 0  
            SET @cErrMsg1 = 'ORDERS: ' + @cOrderKey  
            SET @cErrMsg2 = 'IS ON HOLD.'  
            SET @cErrMsg3 = ''  
            SET @cErrMsg4 = 'PLS SEND TO'  
            SET @cErrMsg5 = 'INCIDENT TABLE.'  
            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT,   
            @cErrMsg1, @cErrMsg2, @cErrMsg3, @cErrMsg4, @cErrMsg5  
            IF @nErrNo = 1  
            BEGIN  
               SET @cErrMsg1 = ''  
               SET @cErrMsg2 = ''  
               SET @cErrMsg3 = ''  
               SET @cErrMsg4 = ''  
               SET @cErrMsg5 = ''  
            END  
  
            SET @cOnHoldLbl = rdt.RDTGetConfig( @nFunc, 'OnHoldLbl', @cStorerKey)  
            IF @cOnHoldLbl = '0'  
               SET @cOnHoldLbl = ''  
              
            IF @cOnHoldLbl <> ''  
            BEGIN  
              INSERT INTO @tOnHoldLbl (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)    
   
              -- Print label    
              EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, @cLabelPrinter, '',     
                 @cOnHoldLbl, -- Report type    
                 @tOnHoldLbl, -- Report params    
                 'rdt_840ExtUpd11',     
                 @nErrNo  OUTPUT,    
                 @cErrMsg OUTPUT    
            END  
              
            GOTO Quit  
         END  
           
         SET @cDelNotes = rdt.RDTGetConfig( @nFunc, 'DelNotes', @cStorerKey)  
         IF @cDelNotes = '0'  
            SET @cDelNotes = ''  
              
         IF @cOrdType = 'E' AND @cDelNotes <> ''  
         BEGIN  
           INSERT INTO @tDelNotes (Variable, Value) VALUES ( '@cOrderKey', @cOrderKey)    
   
           -- Print label    
           EXEC RDT.rdt_Print @nMobile, @nFunc, @cLangCode, 0, 1, '', @cStorerKey, '', @cPaperPrinter,     
              @cDelNotes, -- Report type    
              @tDelNotes, -- Report params    
              'rdt_840ExtUpd11',     
              @nErrNo  OUTPUT,    
              @cErrMsg OUTPUT    
         END  
      END  
   END    
    
   Quit:  
   IF @nOnHold = 1  
      SET @nErrNo = -1  -- To make it stay at step 1  

GO