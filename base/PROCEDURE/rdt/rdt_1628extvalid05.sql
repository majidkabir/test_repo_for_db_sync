SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1628ExtValid05                                  */
/* Purpose: Check dropid can pick in 4 sku only                         */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-08-24  1.0  James      WMS-14577. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtValid05] (
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

   DECLARE @cUserName            NVARCHAR( 18),
           @cPutAwayZone         NVARCHAR( 10),
           @cPickZone            NVARCHAR( 10),
           @nSKUCnt              INT

   SET @nErrNo = 0

   SELECT @cUserName = UserName, 
          @cPutAwayZone = V_String10, 
          @cPickZone = V_String11
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nStep = 8
   BEGIN
      IF @nInputKey = 1
      BEGIN
         -- Check same dropid cannot mix COO (lottable01)
         SET @nSKUCnt = 0
         SELECT @nSKUCnt = COUNT(1)
		 FROM TRANSMITLOG3 WITH (NOLOCK)
		 WHERE TABLENAME = 'DPIDRDTLOG'
		 AND   KEY1 = @cDropID
		 AND   KEY2 = @cWaveKey
		 AND   KEY3 = @cStorerkey

         IF @nSKUCnt > 0
         BEGIN
            SET @nErrNo = 164051
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -->SKUMaxCount
            GOTO Quit
         END
      END
   END

QUIT:

GO