SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_573ExtValidSP06                                 */  
/* Copyright: LF Logistics                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2023-02-07 1.0  Ung        WMS-21436 Created                         */  
/************************************************************************/  
  
CREATE   PROC [RDT].[rdt_573ExtValidSP06] (  
   @nMobile       INT, 
   @nFunc         INT, 
   @cLangCode     NVARCHAR(3), 
   @nStep         INT, 
   @cStorerKey    NVARCHAR(15),
   @cFacility     NVARCHAR(5), 
   @cReceiptKey1  NVARCHAR(20),          
   @cReceiptKey2  NVARCHAR(20),          
   @cReceiptKey3  NVARCHAR(20),          
   @cReceiptKey4  NVARCHAR(20),          
   @cReceiptKey5  NVARCHAR(20),          
   @cLoc          NVARCHAR(20),           
   @cID           NVARCHAR(18),           
   @cUCC          NVARCHAR(20),           
   @nErrNo        INT          OUTPUT,            
   @cErrMsg       NVARCHAR(20) OUTPUT
) 
AS  
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
   
   IF @nFunc = 573 -- UCC inbound receiving
   BEGIN
      IF @nStep = 4 -- UCC
      BEGIN
         -- Get session info
         DECLARE @nInputKey INT 
         SELECT @nInputKey = InputKey FROM rdt.rdtMobRec WITH (NOLOCK) WHERE Mobile = @nMobile
         
         IF @nInputKey = 1 -- ENTER
         BEGIN
            DECLARE @cMixSKUUCC NVARCHAR(1)
            DECLARE @cUCCReceivedDetail NVARCHAR(1)
            
            SET @cUCCReceivedDetail = rdt.RDTGetConfig( @nFunc, 'UCCFromReceivedDetail', @cStorerKey)

            -- Mix SKU UCC
            IF @cUCCReceivedDetail <> '1'       
               SELECT @cMixSKUUCC = 'Y'
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON (RD.ReceiptKey = CR.ReceiptKey)
                  JOIN dbo.PODetail PD WITH (NOLOCK) ON (RD.POKey = PD.POKey AND RD.POLineNumber = PD.POLineNumber)
               WHERE CR.Mobile = @nMobile
                  AND PD.UserDefine01 = @cUCC
               HAVING COUNT( DISTINCT PD.SKU) > 1
            ELSE
               SELECT @cMixSKUUCC = 'Y'
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON (RD.ReceiptKey = CR.ReceiptKey)
               WHERE CR.Mobile = @nMobile
                  AND RD.UserDefine01 = @cUCC
               HAVING COUNT( DISTINCT RD.SKU) > 1
               
            IF @cMixSKUUCC = 'Y'
            BEGIN
               SET @nErrNo = 196251
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- MIX SKU UCC
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cErrMsg
               GOTO Quit
            END

            -- IVAS
            DECLARE @cSKU  NVARCHAR( 20)
            DECLARE @cIVAS NVARCHAR( 20)
            IF @cUCCReceivedDetail <> '1'       
               SELECT TOP 1 
                  @cSKU = PD.SKU, 
                  @cIVAS = ISNULL( SKU.IVAS, '')
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON (RD.ReceiptKey = CR.ReceiptKey)
                  JOIN dbo.PODetail PD WITH (NOLOCK) ON (RD.POKey = PD.POKey AND RD.POLineNumber = PD.POLineNumber)
                  JOIN dbo.SKU WITH (NOLOCK) ON (PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
               WHERE CR.Mobile = @nMobile
                  AND PD.UserDefine01 = @cUCC
            ELSE
               SELECT TOP 1 
                  @cSKU = RD.SKU, 
                  @cIVAS = ISNULL( SKU.IVAS, '')
               FROM dbo.ReceiptDetail RD WITH (NOLOCK)
                  JOIN rdt.rdtConReceiveLog CR WITH (NOLOCK) ON (RD.ReceiptKey = CR.ReceiptKey)
                  JOIN dbo.SKU WITH (NOLOCK) ON (RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
               WHERE CR.Mobile = @nMobile
                  AND RD.UserDefine01 = @cUCC

            IF @cIVAS <> ''
            BEGIN
               DECLARE @cMode NVARCHAR(20)
               SET @cMode = rdt.rdtGetConfig( @nFunc, 'PopUpMode', @cStorerKey) 

               IF @cMode = '1'
                  EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '',  
                     'IVAS:',  
                     @cIVAS,
                     '%I_Field',
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
                     @cMode
            END
         END
      END
   END
   
Quit:


GO