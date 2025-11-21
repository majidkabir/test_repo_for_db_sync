SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840ExtInfo02                                    */
/* Copyright: LF Logistics                                              */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2015-07-21 1.0  James      SOS347581. Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_840ExtInfo02] (
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

   DECLARE  @cNotes2             NVARCHAR( 4000),
            @cOrderInfo01        NVARCHAR( 30),
            @cDoor               NVARCHAR( 10),
            @cCountryDestination NVARCHAR( 30) 
   
   IF @nFunc = 840 -- Pack by track no
   BEGIN
      IF @nAfterStep IN (2, 3) -- SKU
      BEGIN
         -- Get Order Info
         SELECT @cDoor = Door, 
                @cCountryDestination = CountryDestination 
         FROM Orders WITH (NOLOCK) 
         WHERE OrderKey = @cOrderKey
         
         IF @cDoor = 'TMALL'
         BEGIN
            IF @cCountryDestination in ( 'HK', 'MO') 
               SET @cExtendedInfo = '*** TMALL ' + RTRIM( @cCountryDestination) + ' ***'
            ELSE
               SET @cExtendedInfo = '*** TMALL ***'            
         END
         ELSE
         BEGIN
            IF @cCountryDestination in ( 'HK', 'MO') 
               SET @cExtendedInfo = '*** ' + RTRIM( @cCountryDestination) + ' ***'
            ELSE
               SET @cExtendedInfo = ''                        
         END
      END
      
      IF @nStep = 4 
      BEGIN
         IF @cExtendedInfo = 'PRINT_GIFTLABEL' -- Printing...
         BEGIN
            SET @cExtendedInfo = ''

            SELECT @cNotes2 = ORDERS.Notes2, @cOrderInfo01 = ORDERINFO.OrderInfo01
            FROM dbo.ORDERS WITH (NOLOCK) 
            LEFT OUTER JOIN dbo.ORDERINFO WITH (NOLOCK) ON ( ORDERS.ORDERKEY = ORDERINFO.ORDERKEY)
            WHERE ORDERS.StorerKey = @cStorerKey 
            AND ORDERS.OrderKey = @cOrderKey 

            IF ISNULL( @cNotes2, '') <> '' OR ISNULL( @cOrderInfo01, '') <> ''
            BEGIN
               IF ISNULL( @cNotes2, '') <> '' AND ISNULL( @cOrderInfo01, '') <> ''
                  SET @cExtendedInfo = 'GIFTLABEL1'
               
               IF ISNULL( @cNotes2, '') <> '' AND ISNULL( @cOrderInfo01, '') = ''
                  SET @cExtendedInfo = 'GIFTLABEL2'

               IF ISNULL( @cNotes2, '') = '' AND ISNULL( @cOrderInfo01, '') <> ''
                  SET @cExtendedInfo = 'GIFTLABEL3'
            END
         END
         ELSE
            SET @cExtendedInfo = ''
      END
   END

GO