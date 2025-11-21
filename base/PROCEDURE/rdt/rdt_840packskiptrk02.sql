SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_840PackSkipTrk02                                   */
/* Purpose: Check if rdt pack by track no module need to scan track no.    */
/*          By default it is set to skip track no screen                   */
/*                                                                         */
/* Called from: rdtfnc_PackByTrackNo                                       */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author     Purposes                                    */
/* 2015-10-08  1.0  James      SOS353558 - Created                         */
/* 2015-11-18  1.1  James      SOS349301 - Enhance PackSkipTrackNo(james01)*/
/* 2020-07-03  1.2  James      WMS-13965 Remove step (james02)             */
/***************************************************************************/

CREATE PROC [RDT].[rdt_840PackSkipTrk02] (
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

   DECLARE @cFragileChk    NVARCHAR( 1), 
           @cIsFragile     NVARCHAR( 1),
           @cHazmatChk     NVARCHAR( 1), 
           @cIsHazmat      NVARCHAR( 1), 
           @cErrMsg1       NVARCHAR( 20), 
           @cErrMsg2       NVARCHAR( 20), 
           @cErrMsg3       NVARCHAR( 20), 
           @cShort         NVARCHAR( 10) 

   SET @cPackSkipTrackNo = '1'

   IF ISNULL( @cOrderKey, '') = ''
      GOTO Quit

   SELECT @cShort = C.Short
   FROM dbo.CODELKUP C WITH (NOLOCK)
   JOIN dbo.Orders O WITH (NOLOCK) ON (C.Code = O.Type AND C.StorerKey = O.StorerKey)
   WHERE C.ListName = 'HMORDTYPE'
   AND   O.OrderKey = @cOrderkey
   AND   O.StorerKey = @cStorerKey

   -- Move type orders does not have tracking no
   -- then need set to value other than 2 to bypass 
   -- the checking if storer has 'PACKSKIPTRACKNO' turned on
   IF @cShort = 'S'
      SET @cPackSkipTrackNo = '1'
   ELSE
      SET @cPackSkipTrackNo = '2'

   SET @cFragileChk = '0' 
   SET @cIsFragile = '0' 
   SET @cHazmatChk = '0' 
   SET @cIsHazmat = '0' 
                                    
   SET @cFragileChk = rdt.RDTGetConfig( @nFunc, 'FRAGILECHK', @cStorerKey)

   SET @cHazmatChk = rdt.RDTGetConfig( @nFunc, 'HAZMATCHK', @cStorerKey)
                  
   IF @cFragileChk = '1'
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  WHERE PD.StorerKey = @cStorerkey
                  AND   PD.OrderKey = @cOrderKey
                  AND   SKU.SUSR3 = '1')
         SET @cIsFragile = '1'
   END

   IF @cHazmatChk = '1'
   BEGIN
      IF EXISTS ( SELECT 1 FROM dbo.PickDetail PD WITH (NOLOCK) 
                  JOIN dbo.SKU WITH (NOLOCK) ON ( PD.StorerKey = SKU.StorerKey AND PD.SKU = SKU.SKU)
                  WHERE PD.StorerKey = @cStorerkey
                  AND   PD.OrderKey = @cOrderKey
                  AND   SKU.HazardousFlag  = '1')
         SET @cIsHazmat = '1'    
   END

   IF @cIsFragile = '1' OR @cIsHazmat = '1'
   BEGIN
      SET @nErrNo = 0
      SET @cErrMsg1 = ''
      SET @cErrMsg2 = ''
      SET @cErrMsg3 = ''

      IF @cIsFragile = '1' AND @cIsHazmat = '1'
      BEGIN
         SET @cErrMsg1 = 'FRAGILE INSIDE'
         SET @cErrMsg3 = 'HAZMAT INSIDE'
      END

      IF @cIsFragile = '1' AND @cIsHazmat = '0'
      BEGIN
         SET @cErrMsg1 = 'FRAGILE INSIDE'
      END

      IF @cIsFragile = '0' AND @cIsHazmat = '1'
      BEGIN
         SET @cErrMsg1 = 'HAZMAT INSIDE'
      END

      EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, @cErrMsg1, @cErrMsg2, @cErrMsg3
      IF @nErrNo = 1
      BEGIN
         SET @cErrMsg1 = ''
         SET @cErrMsg2 = ''
         SET @cErrMsg3 = ''
      END
   END   


QUIT:

GO