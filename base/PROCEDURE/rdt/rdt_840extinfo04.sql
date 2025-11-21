SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo04                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2019-10-23 1.0  James      WMS10896. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInfo04] (
   @nMobile       INT,
   @nFunc         INT, 
   @cLangCode     NVARCHAR( 3), 
   @nStep         INT, 
   @nAfterStep    INT, 
   @nInputKey     INT, 
   @cStorerkey    NVARCHAR( 15), 
   @cOrderKey     NVARCHAR( 10), 
   @cPickSlipNo   NVARCHAR( 10), 
   @cTrackNo      NVARCHAR( 20), 
   @cSKU          NVARCHAR( 20), 
   @nCartonNo     INT,
   @cExtendedInfo NVARCHAR( 20) OUTPUT,
   @nErrNo        INT           OUTPUT, 
   @cErrMsg       NVARCHAR( 20) OUTPUT
)
AS
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  @nFragileChk   INT,
            @nPackaging    INT,
            @nVAS          INT,
            @cBUSR4        NVARCHAR( 20),
            @cOVAS         NVARCHAR( 20),
            @cUDF01        NVARCHAR( 60),
            @cDescr        NVARCHAR( 250),
            @dOrderDate    DATETIME

   DECLARE @cErrMsg01        NVARCHAR( 20),
           @cErrMsg02        NVARCHAR( 20),
           @cErrMsg03        NVARCHAR( 20)

   
   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nAfterStep IN (2, 3) -- TrackNo/SKU
      BEGIN
         IF @nStep = 1  -- Only need prompt fragile screen once
         BEGIN
            SET @nFragileChk = 0

            SET @cErrMsg01 = ''
            SET @cErrMsg02 = ''
            SET @cErrMsg03 = ''

            IF rdt.RDTGetConfig( @nFunc, 'FRAGILECHK', @cStorerKey) = 1 AND
               EXISTS ( SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                        WHERE [Stop] = 'Y'
                        AND   OrderKey = @cOrderKey
                        AND   StorerKey = @cStorerKey)
            BEGIN
               SET @nErrNo = 0
               SET @cErrMsg01 = rdt.rdtgetmessage( 110101, @cLangCode, 'DSP')
               SET @cErrMsg02 = rdt.rdtgetmessage( 110102, @cLangCode, 'DSP')
               SET @cErrMsg03 = rdt.rdtgetmessage( 110103, @cLangCode, 'DSP')

               SET @nFragileChk = 1
            END

             -- Nothing to display then no need display msg queue
            IF @nFragileChk = 0 
               GOTO Quit

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
            @cErrMsg01, @cErrMsg02, @cErrMsg03
         END
      END
   END

   QUIT:

GO