SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_840PackSkipTrk01                                */
/* Purpose: Check if rdt pack by track no module need to scan track no  */
/* 1.If CN orders then return svalue = 1 and skip tracking no.          */
/*	2.If HK&MO orders and orders.shipperkey =ÆSF2Æ then return           */
/*   svalue = 0 and need scan tracking no.                              */
/*                                                                      */
/* Called from: rdtfnc_PackByTrackNo                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2015-08-04  1.0  James      SOS349301 - Created                      */
/* 2020-07-03  1.1  James      WMS-13965 Remove step (james01)          */
/************************************************************************/

CREATE PROC [RDT].[rdt_840PackSkipTrk01] (
   @nMobile          INT, 
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nAfterStep       INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cOrderKey        NVARCHAR( 10), 
   @cPackSkipTrackNo NVARCHAR( 1)  OUTPUT,    
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT 
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cCountryDestination  NVARCHAR( 30), 
           @cShipperKey          NVARCHAR( 15) 

   SET @cPackSkipTrackNo = '1'

   IF ISNULL( @cOrderKey, '') = ''
      GOTO Quit
         
   SELECT @cCountryDestination = CountryDestination, 
            @cShipperKey = ShipperKey 
   FROM dbo.Orders WITH (NOLOCK) 
   WHERE OrderKey = @cOrderKey

   IF @cCountryDestination = 'CN'
   BEGIN
      SET @cPackSkipTrackNo = '1'
      GOTO Quit
   END

   IF @cCountryDestination IN ('HK', 'MO')
   BEGIN
      IF @cShipperKey = 'SF2'
      BEGIN
         SET @cPackSkipTrackNo = '0'
         GOTO Quit
      END
   END         

QUIT:

GO