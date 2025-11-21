SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1837ExtInfo01                                   */
/*                                                                      */
/* Purpose: Prompt screen when last carton of the loadkey scanned       */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 2019-09-26  1.0  James       WMS-10316. Created                      */
/************************************************************************/

CREATE PROC [RDT].[rdt_1837ExtInfo01] (
   @nMobile        INT,
   @nFunc          INT,
   @cLangCode      NVARCHAR( 3),
   @nStep          INT,
   @nInputKey      INT,
   @cFacility      NVARCHAR( 5),
   @cStorerKey     NVARCHAR( 15),
   @cCartonID      NVARCHAR( 20), 
   @cPalletID      NVARCHAR( 20), 
   @cLoadKey       NVARCHAR( 10), 
   @cLoc           NVARCHAR( 10), 
   @cOption        NVARCHAR( 1), 
   @tExtValidate   VariableTable READONLY,
   @cExtendedInfo  NVARCHAR( 20) OUTPUT,
   @nErrNo         INT           OUTPUT,
   @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cErrMsg01        NVARCHAR( 20),
           @cErrMsg02        NVARCHAR( 20)

   IF @nStep = 2 -- To Pallet
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Check if all carton scanned to PPS loc ( carton moved to PPS loc after scan)
         IF NOT EXISTS ( 
            SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)
            JOIN dbo.LOC LOC WITH (NOLOCK) ON ( PD.LOC = LOC.LOC)
            JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON ( LPD.OrderKey = PD.OrderKey)
            WHERE PD.StorerKey = @cStorerKey
            AND   PD.Status = '5'
            AND   PD.QTY > 0
            AND   LPD.LoadKey = @cLoadKey
            AND   LOC.Facility = @cFacility
            AND   LOC.LocationCategory <> 'PPS')
         BEGIN
            SET @cErrMsg01 = ''
            SET @cErrMsg02 = ''

            SET @nErrNo = 0
            SET @cErrMsg01 = rdt.rdtgetmessage( 145601, @cLangCode, 'DSP')
            SET @cErrMsg02 = rdt.rdtgetmessage( 145602, @cLangCode, 'DSP') + @cLoadKey

            EXEC rdt.rdtInsertMsgQueue @nMobile, @nErrNo OUTPUT, @cErrMsg OUTPUT, 
                 @cErrMsg01, @cErrMsg02
            SET @nErrNo = 0   -- Reset error no
         END
      END
   END


   Quit:

END

GO