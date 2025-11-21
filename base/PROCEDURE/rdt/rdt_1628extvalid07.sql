SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1628ExtValid07                                  */
/* Purpose: Cluster Pick Drop ID validation (ID+LoadKey)                */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 26-01-2022 1.0  yeekung     WMS18619. Created                         */
/************************************************************************/

CREATE PROC [RDT].[rdt_1628ExtValid07] (
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

   DECLARE @cLabelPrinter  NVARCHAR( 10),
           @cPaperPrinter  NVARCHAR( 10),
           @cOption        NVARCHAR( 1),
           @cUserName      NVARCHAR( 18)

   SELECT @cLabelPrinter = Printer,
          @cPaperPrinter = Printer_Paper,
          @cOption = I_Field01,
          @cUserName = UserName
   FROM RDT.RDTMOBREC WITH (NOLOCK) 
   WHERE Mobile = @nMobile

   SET @nErrNo = 0

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         -- Label setup then need setup label printer (james01)
         IF rdt.RDTGetConfig( @nFunc, 'ShipLabel', @cStorerKey) NOT IN('','0')
         BEGIN
            IF @cLabelPrinter = ''
            BEGIN
               SET @nErrNo = 181101
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'NoLabelPrinter'
               GOTO Quit
            END
         END
      END

      IF @nStep = 7
      BEGIN
         IF ISNULL( @cLoadKey, '') = ''
         BEGIN
            SET @nErrNo = 181102
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'No LoadKey'
            GOTO Quit
         END

         IF EXISTS ( SELECT 1 FROM dbo.DropID WITH (NOLOCK)
                     WHERE DropID = @cDropID
                     AND   LoadKey = @cLoadKey
                     AND   [Status] = '9')
         BEGIN
            SET @nErrNo = 181104
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'DropId Close'
            GOTO Quit
         END
      END

      IF @nStep in(7,8)
      BEGIN
         IF ISNULL(@cWaveKey,'')=''
         BEGIN
            SELECT top 1 @cOrderKey=orderkey
            from orders (nolock)
            where loadkey=@cLoadKey
            and storerkey=@cStorerkey

            SELECT @cWaveKey=wavekey
            from pickdetail (nolock)
            where orderkey=@corderkey
            and storerkey=@cStorerkey
         END

         IF EXISTS (SELECT 1 FROM wave (NOLOCK)
                    WHERE wavekey=@cWaveKey
                    AND ISNULL(UserDefine01,'')<>'')
         BEGIN
            DECLARE @cPRELottable03 NVARCHAR(20),
                    @cPOSTLottable03  NVARCHAR(20)

            SELECT @cPRELottable03=lot.lottable03
            FROM pickdetail pd (NOLOCK) JOIN
				dbo.orders o (nolock) ON o.orderkey=pd.orderkey and pd.storerkey=o.StorerKey
            JOIN dbo.LOTATTRIBUTE lot (NOLOCK) ON pd.Lot=lot.lot AND pd.Storerkey=lot.StorerKey
            WHERE pd.Status='5'
            AND pd.DropID=@cDropID
				AND pd.sku=@csku
				and o.LoadKey=@cLoadKey
            AND pd.Storerkey=@cStorerkey

            SELECT top 1 @cPOSTLottable03=lot.lottable03
            FROM pickdetail pd (NOLOCK) JOIN
            dbo.orders o (nolock) ON o.orderkey=pd.orderkey and pd.storerkey=o.StorerKey
            JOIN dbo.LOTATTRIBUTE lot (NOLOCK) ON pd.Lot=lot.lot AND pd.Storerkey=lot.StorerKey
            WHERE pd.Status='0'
            AND ISNULL(pd.DropID,'')=''
            AND pd.Storerkey=@cStorerkey
            AND pd.loc=@cLoc
            AND pd.sku=@cSKU
				and o.LoadKey=@cLoadKey

            IF @cPOSTLottable03<>@cPRELottable03 AND ISNULL(@cPRELottable03,'')<>''
            BEGIN
               SET @nErrNo = 181105
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'COOMixed'
               GOTO Quit
            END
         END

      END


      IF @nStep = 15
      BEGIN
         IF @cOption = '1' AND
            NOT EXISTS (SELECT 1 FROM dbo.DropID WITH (NOLOCK)   
                        WHERE DropID = @cDropID
                        AND   LoadKey = @cLoadKey
                        AND   [Status] < '9')  
         BEGIN  
            -- If drop id not exists before , check if dropid has picked something in
            IF NOT EXISTS ( SELECT 1 FROM RDT.RDTPICKLOCK WITH (NOLOCK)
                            WHERE LoadKey = @cLoadKey
                            AND   AddWho = @cUserName
                            AND   DropID = @cDropID
                            AND   PickQTY > 0
                            AND   [Status] < '9')
            SET @nErrNo = 181106  
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'INVALID DROP ID'  
            GOTO Quit  
         END  
      END
   END

QUIT:

GO