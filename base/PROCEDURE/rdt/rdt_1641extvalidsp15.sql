SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP15                                      */
/* Purpose: Validate pallet                                                   */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2021-08-01  1.0  YeeKung  WMS-17111 Created                                */  
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP15] (
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

   IF @nStep = 3 -- UCC
   BEGIN
      IF @nInputKey='1'
      BEGIN
         SELECT @cOrderKey=orderkey
         FROM packheader ph(NOLOCK) JOIN
         packdetail pd on ph.pickslipno=pd.pickslipno and ph.StorerKey=pd.StorerKey
         where pd.refno=@cUCCNo
         and pd.StorerKey=@cStorerKey

         IF EXISTS (SELECT 1 from PALLETDETAIL (Nolock) 
                    where palletkey=@cdropid
                    and storerkey=@cStorerKey)
         BEGIN

            DECLARE @cOrderCountry NVARCHAR(20),
                    @cPlatform NVARCHAR(20),
                    @cShipperkey NVARCHAR(20)


            SELECT  @cOrderCountry=o.C_Country,
                   @cPlatform=oi.Platform,
                   @cShipperkey=o.ShipperKey
            FROM  orders O (NOLOCK)
            JOIN orderinfo Oi (NOLOCK) ON o.orderkey=oi.OrderKey 
            WHERE o.orderkey=@cOrderKey

            IF EXISTS (SELECT 1 FROM PALLETDETAIL pd(NOLOCK)
                       JOIN orders O (NOLOCK) ON o.orderkey=pd.UserDefine02 AND pd.StorerKey=o.StorerKey
                       JOIN orderinfo Oi (NOLOCK) ON o.orderkey=oi.OrderKey
                       WHERE pd.palletkey=@cDropID
                       AND pd.StorerKey=@cStorerKey
                       and (o.C_Country<>@cOrderCountry
                          OR oi.Platform<>@cPlatform
                          OR o.ShipperKey<>@cShipperkey)) 
            BEGIN
               SET @nErrNo = 169051      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --ordercannotmix
               GOTO QUIT     
            END

         END
      END
   END
END

Quit:



GO