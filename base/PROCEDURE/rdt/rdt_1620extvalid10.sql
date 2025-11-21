SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Store procedure: rdt_1620ExtValid10                                  */
/* Purpose: DropID must be empty                                        */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2020-08-27  1.0  James      WMS-12223. Created                       */
/* 2021-08-03  1.1  James      WMS-17497 Check dropid in used in other  */
/*                             wave (james01)                           */
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtValid10] (
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
	SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @cTempOrderKey     NVARCHAR( 10)  
   DECLARE @cTempWaveKey      NVARCHAR( 10)  
   
   SET @nErrNo = 0
   
   IF @nFunc = 1620  
   BEGIN  
      IF @nStep = 7  
      BEGIN  
         IF @nInputKey = 1  
         BEGIN  
            IF EXISTS ( SELECT 1 FROM dbo.PackHeader PH WITH (NOLOCK)  
                        WHERE EXISTS ( SELECT 1 FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
                                       WHERE PH.OrderKey = PD.OrderKey  
                                       AND   PH.StorerKey = PD.Storerkey  
                                       AND   PD.DropID = @cDropID)  
                        AND   PH.StorerKey = @cStorerkey  
                        AND   PH.[Status] < '9')   
            BEGIN  
               SET @nErrNo = 158451  
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --DropIDNotEmpty  
               GOTO Quit  
            END  

            SELECT @cWaveKey = ISNULL( V_String1, '')  
            FROM RDT.RDTMOBREC WITH (NOLOCK)  
            WHERE Mobile = @nMobile  
   
            SELECT TOP 1 @cTempOrderKey = PD.OrderKey  
            FROM dbo.PICKDETAIL PD WITH (NOLOCK)  
            WHERE PD.Storerkey = @cStorerkey  
            AND   PD.DropID = @cDropID  
            AND   PD.[Status] < '9'  
            ORDER BY 1  
              
            -- If this dropid already picked something  
            IF ISNULL( @cTempOrderKey, '') <> ''  
            BEGIN  
               -- Check if the orders inside this dropid has the same  
               -- wavekey as the one that user scan from screen 1  
               SELECT @cTempWaveKey = UserDefine09  
               FROM dbo.ORDERS WITH (NOLOCK)  
               WHERE OrderKey = @cTempOrderKey  
                 
               IF @cTempWaveKey <> @cWaveKey  
               BEGIN  
                  SET @nErrNo = 158452  
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OtherWaveInTote  
                  GOTO Quit  
               END  
            END  
         END  
      END  
   END  

QUIT:


GO