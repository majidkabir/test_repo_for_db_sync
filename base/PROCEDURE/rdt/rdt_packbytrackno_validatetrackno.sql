SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_PackByTrackNo_ValidateTrackNo                   */
/*                                                                      */
/* Modifications log: Validate track no                                 */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 06-Sep-2016 1.0  James    Created                                    */
/************************************************************************/

CREATE PROC [RDT].[rdt_PackByTrackNo_ValidateTrackNo] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR( 15), 
   @cOrderKey        NVARCHAR( 10), 
   @cTrackNo         NVARCHAR( 20), 
   @nErrNo           INT           OUTPUT, 
   @cErrMsg          NVARCHAR( 20) OUTPUT
) AS
   BEGIN
      SET NOCOUNT ON
      SET QUOTED_IDENTIFIER OFF
      SET ANSI_NULLS OFF
      SET CONCAT_NULL_YIELDS_NULL OFF

      DECLARE @cShipperKey    NVARCHAR( 15),
              @cTrackRegExp   NVARCHAR( 255)

      -- (For home deliveries, 1 tracking no only link to 1 orderkey)
      IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK)
                  WHERE StorerKey = @cStorerKey
                  AND OrderKey = @cOrderKey
                  AND Userdefine04 = @cTrackNo
                  GROUP BY Userdefine04
                  HAVING COUNT(DISTINCT ORDERKEY) > 1)
      BEGIN
         SET @nErrNo = 103701
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Track# > 1 ORD
         GOTO Fail
      END

      SET @cShipperKey = ''
      SELECT @cShipperKey = ShipperKey FROM dbo.ORDERS WITH (NOLOCK)
      WHERE Orderkey = @cOrderkey
         AND Storerkey = @cStorerkey

      IF ISNULL(@cShipperKey,'') = ''
      BEGIN
         SET @nErrNo = 103702
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv ShipperKey
         GOTO Fail
      END

      SET @cTrackRegExp = ''
      SELECT @cTrackRegExp = Notes1 FROM dbo.Storer WITH (NOLOCK)
      WHERE Storerkey = @cShipperKey

      IF master.dbo.RegExIsMatch( ISNULL( RTRIM( @cTrackRegExp),''), ISNULL( RTRIM( @cTrackNo),''), 0) <> 1   
      BEGIN
         SET @nErrNo = 103703
         SET @cErrMsg = rdt.rdtgEtmessage( @nErrNo, @cLangCode, 'DSP') --Inv TrackNo
         GOTO Fail
      END
   
 
   FAIL:  

END

GO