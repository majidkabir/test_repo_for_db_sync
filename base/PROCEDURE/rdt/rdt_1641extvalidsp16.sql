SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP16                                      */
/* Purpose: Validate pallet                                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2021-10-26 1.0  YeeKung  WMS-18261 Created                                */  
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP16] (
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR(3),
   @nStep        INT,
   @nInputKey    INT, 
   @cStorerKey   NVARCHAR(15),
   @cDropID      NVARCHAR(20),
   @cUCCNo       NVARCHAR(20),
   @cPrevLoadKey NVARCHAR(10),
   @cParam1      NVARCHAR(20),
   @cParam2      NVARCHAR(20),
   @cParam3      NVARCHAR(20),
   @cParam4      NVARCHAR(20),
   @cParam5      NVARCHAR(20),
   @nErrNo       INT          OUTPUT,
   @cErrMsg      NVARCHAR(20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

IF @nFunc = 1641
BEGIN
   DECLARE @cPickSlipNo NVARCHAR(10) 
          ,@cOrderKey   NVARCHAR(10) 
          ,@cSortCode   NVARCHAR(13)
          ,@cRoute      NVARCHAR(10) 
          ,@cExternOrderKey NVARCHAR(30) 
          ,@cPalletSortCode NVARCHAR(13) 
          ,@cUserDefine09   NVARCHAR(10)
          ,@cUCCvalue   NVARCHAR(20)
          ,@clottablevalue NVARCHAR(20) 
          ,@cCountry  NVARCHAR(20)

       
   SET @nErrNo = 0

   IF @nStep = 1 -- Drop id              
   BEGIN              
      IF @nInputKey = 1 -- ENTER              
      BEGIN              
         IF EXISTS ( SELECT 1 FROM dbo.Pallet WITH (NOLOCK)       
                     WHERE StorerKey = @cStorerKey              
                     AND   PalletKey = @cDropID              
                     AND  [Status] = '9')              
         BEGIN              
            SET @nErrNo = 177551              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- Pallet closed              
            GOTO Quit                             
         END              
      END              
   END   

   IF @nStep = 3 -- UCC
   BEGIN
      IF @nInputKey='1'
      BEGIN
         IF EXISTS ( SELECT 1 FROM dbo.PalletDetail WITH (NOLOCK)              
            WHERE StorerKey = @cStorerKey              
            AND   CaseID = @cUCCNo              
            AND  [Status] < '9')              
         BEGIN              
            SET @nErrNo = 177552              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4              
            GOTO Quit                             
         END              
              
         -- carton exists in another closed pallet, prompt error     
         IF EXISTS ( SELECT 1 FROM dbo.PALLETDETAIL WITH (NOLOCK)              
                     WHERE StorerKey = @cStorerKey              
                     AND   CaseID = @cUCCNo              
                     AND   [Status] = '9'              
                     AND   PalletKey <> @cDropID)              
         BEGIN              
            SET @nErrNo = 177553              
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- carton scan b4              
            GOTO Quit                             
         END  



         SELECT @cOrderKey=orderkey
         FROM packheader ph(NOLOCK) JOIN
         packdetail pd on ph.pickslipno=pd.pickslipno and ph.StorerKey=pd.StorerKey
         where pd.refno=@cUCCNo
         and pd.StorerKey=@cStorerKey

         IF EXISTS (SELECT 1 from PALLETDETAIL (Nolock) 
                    where palletkey=@cdropid
                    and storerkey=@cStorerKey)
         BEGIN

            DECLARE  @cShipperkey NVARCHAR(20)

            SELECT 
                   @cShipperkey=o.ShipperKey
            FROM  orders O (NOLOCK)
            JOIN orderinfo Oi (NOLOCK) ON o.orderkey=oi.OrderKey 
            WHERE o.orderkey=@cOrderKey

            IF EXISTS (SELECT 1 FROM PALLETDETAIL pd(NOLOCK)
                       JOIN orders O (NOLOCK) ON o.orderkey=pd.UserDefine02 AND pd.StorerKey=o.StorerKey
                       JOIN orderinfo Oi (NOLOCK) ON o.orderkey=oi.OrderKey
                       WHERE pd.palletkey=@cDropID
                       AND pd.StorerKey=@cStorerKey
                       and  o.ShipperKey<>@cShipperkey)
            BEGIN
               SET @nErrNo = 177554      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --diffshipperkey
               GOTO QUIT     
            END

         END
      END
   END
END

Quit:



GO