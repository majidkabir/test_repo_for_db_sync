SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/
/* Store procedure: rdt_1641ExtValidSP13                                      */
/* Purpose: Validate Pallet DropID  (05->12)                                  */
/*                                                                            */
/* Modifications log:                                                         */
/*                                                                            */
/* Date       Rev  Author   Purposes                                          */
/* 2020-12-09 1.0  YeeKung  WMS-16514 Created                                 */
/******************************************************************************/

CREATE PROC [RDT].[rdt_1641ExtValidSP13] (
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
         SELECT @cOrderKey=orderkey,@clottablevalue=pd.lottablevalue
         FROM packheader ph(NOLOCK) JOIN
         packdetail pd on ph.pickslipno=pd.pickslipno and ph.StorerKey=pd.StorerKey
         where pd.LabelNo=@cUCCNo
         and pd.StorerKey=@cStorerKey

         IF EXISTS (SELECT 1 from PALLETDETAIL (Nolock) 
                    where palletkey=@cdropid
                    and storerkey=@cStorerKey)
         BEGIN

            IF EXISTS (SELECT 1 FROM PALLETDETAIL (NOLOCK)
                       WHERE palletkey=@cDropID
                       AND StorerKey=@cStorerKey
                       and userdefine02<>@cOrderKey) 
            BEGIN
               SET @nErrNo = 162801      
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --OrderkeyCannotMix
               GOTO QUIT     
            END

            SELECT TOP 1 @cUCCvalue =caseid
            from palletdetail (NOLOCK)
            WHERE palletkey=@cdropid
            and storerkey=@cstorerkey

            IF EXISTS (SELECT 1 FROM PACKDETAIL (NOLOCK)
                       WHERE labelno=@cUCCvalue
                       AND StorerKey=@cStorerKey
                       and lottablevalue<>@clottablevalue) 
            BEGIN
               SET @nErrNo = 162802    
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --COOCannotMix
               GOTO QUIT     
            END

            SELECT @cCountry=C_Country
            FROM orders (NOLOCK)
            where orderkey=@cOrderKey
            and storerkey=@cStorerKey

            IF EXISTS (SELECT 1 FROM storer (NOLOCK)
                     WHERE storerkey=@cStorerKey
                     AND country<>@cCountry) 
            BEGIN
               SET @nErrNo = 162803   
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --WrongCountry
               GOTO QUIT     
            END




         END
      END
   END
END

Quit:



GO