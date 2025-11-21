SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_842ExtValidSP02                                 */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-10-14 1.0  James      WMS-18115. Created                        */
/* 2022-02-03 1.1  LZG        JSM-49354 - Added PD.Status (ZG01)        */
/************************************************************************/

CREATE PROC [RDT].[rdt_842ExtValidSP02] (
  @nMobile        INT,
  @nFunc          INT,
  @cLangCode      NVARCHAR(3),
  @nStep          INT,
  @cUserName      NVARCHAR( 18),
  @cFacility      NVARCHAR( 5),
  @cStorerKey     NVARCHAR( 15),
  @cDropID        NVARCHAR( 20),
  @cSKU           NVARCHAR( 20),
  @cOption        NVARCHAR( 1),
  @cOrderKey      NVARCHAR( 10),
  @cTrackNo       NVARCHAR( 20),
  @cCartonType    NVARCHAR( 10),
  @cWeight        NVARCHAR( 20),
  @nErrNo         INT OUTPUT,
  @cErrMsg        NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nInputKey         INT
   DECLARE @cEcom_Single_Flag NVARCHAR( 1)

   SET @nErrNo = 0
   SET @cErrMSG = ''

   SELECT @nInputKey = InputKey
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 1
   BEGIN
      IF @nInputKey = 1
      BEGIN
         SELECT @cEcom_Single_Flag = O.ECOM_SINGLE_Flag
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
         WHERE PD.DropID = @cDropID
         AND   O.StorerKey = @cStorerKey
         AND   PD.Status = '5'   -- ZG01
         GROUP BY O.ECOM_SINGLE_Flag

         IF @@ROWCOUNT > 1
         BEGIN
            SET @nErrNo = 177051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Ecom Flag
            GOTO QUIT
         END

         IF @cEcom_Single_Flag <> 'S'
         BEGIN
            SET @nErrNo = 177052
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Inv Ecom Flag
            GOTO QUIT
         END
      END
   END

QUIT:

GO