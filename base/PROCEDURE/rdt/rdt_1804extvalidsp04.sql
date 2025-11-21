SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store procedure: rdt_1804ExtValidSP04                                */  
/* Purpose: Validate qty key in must equal casecnt                      */  
/*                                                                      */  
/* Modifications log:                                                   */  
/*                                                                      */  
/* Date       Rev  Author     Purposes                                  */  
/* 2018-04-18 1.0  James      WMS4665. Created                          */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_1804ExtValidSP04] (  
     @nMobile         INT, 
     @nFunc           INT, 
     @cLangCode       NVARCHAR(3), 
     @nStep           INT, 
     @cStorerKey      NVARCHAR(15),
     @cFacility       NVARCHAR(5), 
     @cFromLOC        NVARCHAR(10),
     @cFromID         NVARCHAR(18),
     @cSKU            NVARCHAR(20),
     @nQTY            INT, 
     @cUCC            NVARCHAR(20),
     @cToID           NVARCHAR(18),
     @cToLOC          NVARCHAR(10),
     @nErrNo          INT OUTPUT, 
     @cErrMsg         NVARCHAR(20) OUTPUT
)  
AS  
  
SET NOCOUNT ON    
SET QUOTED_IDENTIFIER OFF    
SET ANSI_NULLS OFF    
SET CONCAT_NULL_YIELDS_NULL OFF    

   DECLARE @nCaseCnt    INT
   DECLARE @cUCCLabel   NVARCHAR( 20)
   DECLARE @cLabelPrinter  NVARCHAR( 10)
   DECLARE @cInField11  NVARCHAR( 60)

   SELECT @cInField11 = I_Field11 FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE MOBILE = @nMobile

   IF @nFunc = 1804  
   BEGIN  
      IF @nStep = 6 -- SKU, QTY
      BEGIN  
         IF @nQTY > 0         -- Screen can enter sku only and leave qty blank/0
         AND @cInField11 = '' -- If user enter blank sku and qty > 0 then go to step 7
         BEGIN
            SELECT @nCaseCnt = PACK.CaseCnt 
            FROM dbo.SKU SKU WITH (NOLOCK)
            JOIN dbo.PACK PACK WITH (NOLOCK) ON ( SKU.PACKKey = PACK.PackKey)
            WHERE SKU.Sku = @cSKU
            AND   SKU.StorerKey = @cStorerKey

            IF @nQTY <> @nCaseCnt
            BEGIN
               SET @nErrNo = 122951
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- QTY <> CASECNT
               GOTO Quit
            END
         END
      END

      IF @nStep = 7 -- To UCC
      BEGIN
         SET @cUCCLabel = rdt.rdtGetConfig( @nFunc, 'UCCLabel', @cStorerKey)
         IF @cUCCLabel = '0'
            SET @cUCCLabel = ''

         IF @cUCCLabel <> ''
         BEGIN
            SELECT @cLabelPrinter = Printer
            FROM RDT.RDTMOBREC WITH (NOLOCK)
            WHERE Mobile = @nMobile

            IF ISNULL( @cLabelPrinter, '') = ''
            BEGIN
               SET @nErrNo = 122952
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- NOLABELPRINTER
               GOTO Quit
            END
         END

      END
   END
  
QUIT:  

 

GO