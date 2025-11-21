SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo03                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2017-06-06 1.0  James      WMS2052. Created                          */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInfo03] (
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

   DECLARE  @cUpdateSource       NVARCHAR( 10),
            @cDescription        NVARCHAR( 30),
            @cDoor               NVARCHAR( 10),
            @cCountryDestination NVARCHAR( 30) 
   
   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nAfterStep IN (2, 3) -- SKU
      BEGIN
         SELECT @cUpdateSource = UpdateSource
         FROM dbo.Orders WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey

         IF ISNULL( @cUpdateSource, '') = '' OR @cUpdateSource = '0'
            SET @cUpdateSource = ''

         SELECT @cExtendedInfo = [Description]
         FROM dbo.CODELKUP WITH (NOLOCK)
         WHERE ListName = 'COSORDTYPE'
         AND   Code2 = @cUpdateSource
         AND   StorerKey = @cStorerKey
      END
   END

GO