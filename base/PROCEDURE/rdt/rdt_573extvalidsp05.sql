SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Store procedure: rdt_573ExtValidSP05                                 */  
/* Copyright: LF Logistics                                              */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2022-02-10 1.0  Ung        WMS-18907 Created                         */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_573ExtValidSP05] (  
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
            DECLARE @nSTDGrossWGT FLOAT
            DECLARE @nSTDCube     FLOAT
            DECLARE @cMsg1        NVARCHAR( 20) = ''
            DECLARE @cMsg2        NVARCHAR( 20) = ''
            
            -- Get SKU info
            SELECT 
               @nSTDGrossWGT = SKU.STDGrossWGT, 
               @nSTDCube = SKU.STDCube
            FROM dbo.ReceiptDetail RD WITH (NOLOCK)
               JOIN dbo.SKU SKU WITH (NOLOCK) ON ( RD.StorerKey = SKU.StorerKey AND RD.SKU = SKU.SKU)
            WHERE RD.Userdefine01 = @cUCC

            -- Check weight
            IF ISNULL( @nSTDGrossWGT, 0) = 0
               SET @cMsg1 = rdt.rdtgetmessage( 182051, @cLangCode, 'DSP') -- SETUP Weight
            
            -- Check cube
            IF ISNULL( @nSTDCube, 0) = 0
               SET @cMsg2 = rdt.rdtgetmessage( 182052, @cLangCode, 'DSP') -- SETUP Cubic

            -- Warning only, can continue scan
            IF @cMsg1 <> '' OR @cMsg2 <> ''
               EXEC rdt.rdtInsertMsgQueue @nMobile, 0, '', '', @cMsg1, @cMsg2
         END
      END
   END
   
Quit:  


GO