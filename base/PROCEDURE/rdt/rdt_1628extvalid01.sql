SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_1628ExtValid01                                  */  
/* Purpose: Cluster Pick Drop ID validation (ID+LoadKey)                */  
/*                                                                      */  
/* Called from: rdtfnc_Cluster_Pick                                     */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date        Rev  Author     Purposes                                 */  
/* 30-Nov-2017 1.0  James      WMS3572. Created                         */  
/* 04-Apr-2018 1.1  James      WMS4338-Check printer setup if label     */  
/*                             config is turned on (james01)            */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_1628ExtValid01] (  
   @nMobile          INT,  
   @nFunc            INT,   
   @cLangCode        NVARCHAR( 3),   
   @nStep            INT,   
   @nInputKey        INT,   
   @cStorerkey       NVARCHAR( 15),   
   @cWaveKey         NVARCHAR( 10),   
   @cLoadKey         NVARCHAR( 10),   
   @cOrderKey        NVARCHAR( 10),   
   @cLoc             NVARCHAR( 10),   
   @cDropID          NVARCHAR( 20),   
   @cSKU             NVARCHAR( 20),   
   @nQty             INT,   
   @nErrNo           INT           OUTPUT,   
   @cErrMsg          NVARCHAR( 20) OUTPUT  
)  
AS  
  
   SET NOCOUNT ON      
   SET QUOTED_IDENTIFIER OFF      
   SET ANSI_NULLS OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF    
  
   DECLARE @cLabelPrinter  NVARCHAR( 10),  
           @cPaperPrinter  NVARCHAR( 10),  
           @cOption        NVARCHAR( 1),  
           @cUserName      NVARCHAR( 18)  
  
   SELECT @cLabelPrinter = Printer,  
          @cPaperPrinter = Printer_Paper,  
          @cOption = I_Field01,  
          @cUserName = UserName  
   FROM RDT.RDTMOBREC WITH (NOLOCK)   
   WHERE Mobile = @nMobile  
  
   SET @nErrNo = 0  
  
   IF @nInputKey = 1  
   BEGIN  
      IF @nStep = 3  
      BEGIN  
         -- Label setup then need setup label printer (james01)  
         IF rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey) <> ''  
         BEGIN  
            IF @cLabelPrinter = ''  
            BEGIN  
               SET @nErrNo = 117551  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoLabelPrinter'  
               GOTO Quit  
            END  
         END  
      END  
  
      IF @nStep = 7  
      BEGIN  
         IF ISNULL( @cLoadKey, '') = ''  
         BEGIN  
            SET @nErrNo = 117552  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'No LoadKey'  
            GOTO Quit  
         END  
  
         IF SUBSTRING(@cDropID, 1, 2) + SUBSTRING(@cDropID, 3, 10) <> 'ID' + @cLoadKey  
         BEGIN  
            SET @nErrNo = 117553  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Invalid DropId'  
            GOTO Quit  
         END  
  
         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)  
                     WHERE DropID = @cDropID  
                     AND   LoadKey = @cLoadKey  
                     AND   [Status] = '9')  
         BEGIN  
            SET @nErrNo = 117554  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DropId Close'  
            GOTO Quit  
         END  
      END  
  
      IF @nStep = 15  
      BEGIN  
         IF @cOption = '1' AND  
            NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)     
                        WHERE DropID = @cDropID  
                        AND   LoadKey = @cLoadKey  
                        AND   [Status] < '9')    
         BEGIN    
            -- If drop id not exists before , check if dropid has picked something in  
            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK)  
                            WHERE LoadKey = @cLoadKey  
                            AND   AddWho = @cUserName  
                            AND   DropID = @cDropID  
                            AND   PickQTY > 0  
                            AND   [Status] < '9')  
            SET @nErrNo = 117555    
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROP ID'    
            GOTO Quit    
         END    
      END  
   END  
  
QUIT:  
GO