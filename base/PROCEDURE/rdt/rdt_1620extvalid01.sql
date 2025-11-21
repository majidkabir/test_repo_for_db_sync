SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_1620ExtValid01                                  */
/* Purpose: Cluster Pick Extended Validate SP for Under Armor           */
/*                                                                      */
/* Called from: rdtfnc_Cluster_Pick                                     */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 05-May-2015 1.0  James      SOS342111 - Created                      */
/* 16-Jul-2015 1.1  James      Add RDT config to control mix CC (james01*/
/************************************************************************/

CREATE PROC [RDT].[rdt_1620ExtValid01] (
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

   SET @nMultiStorer = 0
   IF EXISTS (SELECT 1 FROM dbo.StorerGroup WITH (NOLOCK) WHERE StorerGroup = @cStorerKey)
      SET @nMultiStorer = 1

   SELECT @cUserName = UserName FROM RDT.RDTMOBREC WITH (NOLOCK) WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 8
      BEGIN
--Give error if any of the following situation occurs:
--1.	SKU in Box COO (Lotattribute.Lottable08) is different from current scanned SKU
--2.	If Orders.Userdeifne10=Æ P01Æ and SKU in box is different from current scanned SKU
--3.	If Orders.Userdeifne10=ÆP02Æ and SKU in box is with different SKU.Style from current scanned SKU
--4.	If Orders.Userdeifne10=ÆP03Æ and SKU in box is with different SKU.Style from current scanned SKU
--5.	If Orders.Userdeifne10=ÆP03Æ and SKU in box is with different SKU.Color from current scanned SKU
         SELECT TOP 1 
            @cPicked_Lottable08 = LA.Lottable08, 
            @cPicked_SKU = PD.SKU, 
            @cPicked_Style = SKU.Style,
            @cPicked_Color = SKU.Color  
         FROM dbo.PickDetail PD WITH (NOLOCK) 
         JOIN dbo.LotAttribute LA (NOLOCK) ON ( PD.Lot = LA.Lot)
         JOIN dbo.SKU WITH (NOLOCK) ON ( PD.SKU = SKU.SKU AND PD.StorerKey = SKU.StorerKey)
         WHERE PD.StorerKey = @cStorerKey 
         AND   PD.DropID = @cDropID
         AND   PD.Status = '5'            

         IF ISNULL( @cPicked_Lottable08, '') <> '' AND rdt.RDTGetConfig( @nFunc, 'CartonNotCheckMixCOO', @cStorerKey) <> '1'
         BEGIN
            SELECT TOP 1 @cNew_Lottable08 = LA.Lottable08
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            JOIN dbo.LotAttribute LA (NOLOCK) ON ( PD.Lot = LA.Lot)
            WHERE PD.StorerKey = @cStorerKey 
            AND   PD.OrderKey = @cOrderKey
            AND   PD.SKU = @cSKU
            AND   PD.Status = '0'

            IF @cPicked_Lottable08 <> @cNew_Lottable08
            BEGIN
               SET @nErrNo = 93701
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Box mix coo'
               GOTO Quit
            END
         END

         SELECT @cUserDefine10 = UserDefine10 
         FROM dbo.Orders WITH (NOLOCK) 
         WHERE StorerKey = @cStorerKey
         AND   OrderKey = @cOrderKey

         SELECT @cStyle = Style,
                @cColor = Color
         FROM dbo.SKU WITH (NOLOCK)
         WHERE StorerKey = @cStorerKey
         AND   SKU = @cSKU

         -- Check SKU in box is having different SKU from current scanned SKU
         IF @cUserDefine10 = 'P01'
         BEGIN
            IF ISNULL( @cPicked_SKU, '') <> ''
            BEGIN
               IF @cSKU <> @cPicked_SKU
               BEGIN
                  SET @nErrNo = 93702
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Box mix sku'
                  GOTO Quit
               END            
            END
         END

         -- Check SKU in box is having different SKU.Style from current scanned SKU
         IF @cUserDefine10 IN ('P02', 'P03')
         BEGIN
            IF ISNULL( @cPicked_Style, '') <> ''
            BEGIN
               IF ISNULL( @cStyle, '') <> ISNULL( @cPicked_Style, '')
               BEGIN
                  SET @nErrNo = 93703
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Box mix style'
                  GOTO Quit
               END            
            END
         END

         -- Check SKU in box is having different SKU.Style & SKU.Colour from current scanned SKU
         IF @cUserDefine10 = 'P03'
         BEGIN
            IF ISNULL( @cPicked_Color, '') <> ''
            BEGIN
               IF ISNULL( @cColor, '') <> ISNULL( @cPicked_Color, '')
               BEGIN
                  SET @nErrNo = 93704
                  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') -- 'Box mix color'
                  GOTO Quit
               END            
            END
         END
      END
   END

QUIT:

GO