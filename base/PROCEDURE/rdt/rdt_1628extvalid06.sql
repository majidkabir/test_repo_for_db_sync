SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_1628ExtValid06                                     */
/* Purpose: Check dropid can pick in 4 sku only                            */
/*                                                                         */
/* Called from: rdtfnc_Cluster_Pick                                        */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author     Purposes                                    */
/* 2021-03-10  1.0  Chermaine  WMS-16513 Created (dup rdt_1628ExtValid04)  */
/***************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtValid06] (
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
           @nSKUCnt              INT,
		     @cMaxSKUPerDropID     NVARCHAR( 2),
		     @nTransmitCnt         INT
   
   SET @cMaxSKUPerDropID = rdt.RDTGetConfig( @nFunc, 'MaxSKUPerDropID', @cStorerKey) 

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
         SET @nSKUCnt = 0
         
         -- Check how many sku inside this dropid
         SELECT @nSKUCnt = COUNT( DISTINCT PD.SKU)
         FROM dbo.PICKDETAIL PD WITH (NOLOCK)
         JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
         WHERE PD.Storerkey = @cStorerkey
         AND   PD.DropID = @cDropID
         AND   PD.[Status] < '9'
         AND   (( ISNULL( @cOrderKey, '') = '') OR ( O.OrderKey = @cOrderKey))
         AND   (( ISNULL( @cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
         AND   (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey))

         -- Sku count < 4, can proceed.
         IF @nSKUCnt < @cMaxSKUPerDropID
            GOTO QUIT

         -- Sku count = 4, check the sku currently scanned is one
         -- of the sku exists in this dropid. If not exists, prompt error
         IF @nSKUCnt = @cMaxSKUPerDropID
         BEGIN
            IF NOT EXISTS ( SELECT 1
               FROM dbo.PICKDETAIL PD WITH (NOLOCK)
               JOIN dbo.ORDERS O WITH (NOLOCK) ON ( PD.OrderKey = O.OrderKey)
               WHERE PD.Storerkey = @cStorerkey
               AND   PD.DropID = @cDropID
               AND   PD.[Status] < '9'
               AND   PD.Sku = @cSKU
               AND   (( ISNULL( @cOrderKey, '') = '') OR ( O.OrderKey = @cOrderKey))
               AND   (( ISNULL( @cLoadKey, '') = '') OR ( O.LoadKey = @cLoadKey))
               AND   (( ISNULL( @cWaveKey, '') = '') OR ( O.UserDefine09 = @cWaveKey)))   
            BEGIN
               SET @nErrNo = 164651
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -->SKUMaxCount
               GOTO Quit
            END
         END

         -- Sku count already 4, prompt error
         IF @nSKUCnt > @cMaxSKUPerDropID
         BEGIN
            SET @nErrNo = 164652
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -->SKUMaxCount
            GOTO Quit
         END

		   SET @nTransmitCnt = 0

         IF ISNULL(@cWaveKey,'') = ''
         BEGIN			   
         SELECT TOP 1 @cWaveKey = USERDEFINE09 FROM ORDERS(NOLOCK)
         WHERE Storerkey = @cStorerkey
		   AND   (( ISNULL( @cOrderKey, '') = '') OR ( OrderKey = @cOrderKey))
         AND   (( ISNULL( @cLoadKey, '') = '') OR ( LoadKey = @cLoadKey))
         END

         SELECT @nTransmitCnt = COUNT(1)
		   FROM TRANSMITLOG3 WITH (NOLOCK)
		   WHERE TABLENAME = 'DPIDRDTLOG'
		   AND   KEY1 = @cDropID
		   AND   KEY2 = @cWaveKey
		   AND   KEY3 = @cStorerkey

         IF @nTransmitCnt > 0
         BEGIN
            SET @nErrNo = 164653
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -->DropIDClosed
            GOTO Quit
         END
      END
   END

QUIT:

GO