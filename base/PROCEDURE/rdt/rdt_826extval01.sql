SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/************************************************************************/  
/* Store procedure: rdt_826ExtVal01                                     */  
/* Copyright      : LF Logistics                                        */  
/*                                                                      */  
/* Date        Rev  Author      Purposes                                */  
/* 04-Feb-2021 1.0  Chermaine   WMS-16159. Created                      */  
/************************************************************************/  
  
CREATE PROC [RDT].[rdt_826ExtVal01] (  
   @nMobile       INT,  
   @nFunc         INT,  
   @nStep         INT,  
   @nInputKey     INT,  
   @cLangCode     NVARCHAR( 3),  
   @cStorerKey    NVARCHAR( 15),  
   @cUCCNo        NVARCHAR( 20),
   @cSKU          NVARCHAR( 20),
   @nQTY          INT,
   @nErrNo        INT            OUTPUT,
   @cErrMsg       NVARCHAR( 20)  OUTPUT  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   IF @nStep = 1 -- UCC/SKU
   BEGIN
      IF @nInputKey = 1 -- ENTER
      BEGIN
         IF NOT EXISTS ( SELECT 1 FROM dbo.skuxLoc WITH (NOLOCK)
                         WHERE storerKey = @cStorerKey
                         AND   SKU = @cSKU)
         BEGIN
            SET @nErrNo = 163151
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- NoPickPosition
            GOTO Quit
         END

         IF NOT EXISTS ( SELECT TOP 1 1 FROM dbo.skuxLoc WITH (NOLOCK)
                         WHERE storerKey = @cStorerKey
                         AND SKU = @cSKU
                         AND LocationType ='PICK' 
                         ORDER BY AddDate desc)
         BEGIN
            SET @nErrNo = 163152
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')-- InvalidLocType
            GOTO Quit
         END
      END   
   END   

   Quit:
END  

GO