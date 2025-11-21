SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtValid05                                  */
/* Purpose: PVH, check no duplicate dropid in pickdetail.status <=3     */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 29-Oct-2018 1.0  James      WMS6843. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtValid05] (
   @nMobile          INT,
   @nFunc            INT,
   @cLangCode        NVARCHAR( 3),
   @nStep            INT,
   @nInputKey        INT,
   @cStorerkey       NVARCHAR( 15),
   @cWaveKey         NVARCHAR( 10),
   @cLoadKey         NVARCHAR( 10),
   @cOrderKey        NVARCHAR( 10),
   @cLoc             NVARCHAR( 10),
   @cDropID          NVARCHAR( 20),
   @cSKU             NVARCHAR( 20),
   @nQty             INT,
   @nErrNo           INT           OUTPUT,
   @cErrMsg          NVARCHAR( 20) OUTPUT
)
AS

   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF

   DECLARE @cPicked_Lottable08   NVARCHAR( 30),
           @cNew_Lottable08      NVARCHAR( 30),
           @cStyle               NVARCHAR( 20),
           @cPicked_Style        NVARCHAR( 20),
           @cColor               NVARCHAR( 10),
           @cPicked_Color        NVARCHAR( 10),
           @cUserDefine10        NVARCHAR( 10),
           @cUserName            NVARCHAR( 20),
           @cPicked_SKU          NVARCHAR( 20),
           @nMultiStorer         INT

   SET @nErrNo = 0

   SELECT @cUserName = UserName 
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   IF @nStep = 7
   BEGIN
      IF @nInputKey = 1
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.PickDetail WITH (NOLOCK) 
                     WHERE Storerkey = @cStorerkey
                     AND   DropID = @cDropID 
                     AND   Status <= '3')
         BEGIN
            SET @nErrNo = 131051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicate ID
            GOTO Quit
         END
      END

   END

QUIT:

GO