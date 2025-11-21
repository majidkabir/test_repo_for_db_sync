SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/
/* Store procedure: rdt_727Inquiry24                                       */
/* Copyright      : Maersk                                                 */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2023-12-01 1.0  Ung        WMS-24311 base on rdt_727Inquiry18           */
/* 2024-03-21 1.1  yeekung    UWP-17016 Add New requirement                */
/***************************************************************************/
CREATE     PROC [RDT].[rdt_727Inquiry24] (
   @nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @cLangCode    NVARCHAR(3),  
   @cStorerKey   NVARCHAR(15),  
   @cOption      NVARCHAR(1),  
   @cParam1      NVARCHAR(60),  
   @cParam2      NVARCHAR(60),  
   @cParam3      NVARCHAR(60),  
   @cParam4      NVARCHAR(60),  
   @cParam5      NVARCHAR(60),  
   @c_oFieled01  NVARCHAR(20) OUTPUT,  
   @c_oFieled02  NVARCHAR(20) OUTPUT,  
   @c_oFieled03  NVARCHAR(20) OUTPUT,  
   @c_oFieled04  NVARCHAR(20) OUTPUT,  
   @c_oFieled05  NVARCHAR(20) OUTPUT,  
   @c_oFieled06  NVARCHAR(20) OUTPUT,  
   @c_oFieled07  NVARCHAR(20) OUTPUT,  
   @c_oFieled08  NVARCHAR(20) OUTPUT,  
   @c_oFieled09  NVARCHAR(20) OUTPUT,  
   @c_oFieled10  NVARCHAR(20) OUTPUT,  
   @c_oFieled11  NVARCHAR(20) OUTPUT,  
   @c_oFieled12  NVARCHAR(20) OUTPUT,  
   @nNextPage    INT          OUTPUT,  
   @nErrNo       INT          OUTPUT,  
   @cErrMsg      NVARCHAR(20) OUTPUT  
)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   SET @nErrNo = 0
   DECLARE @cID         NVARCHAR( 18)
   DECLARE @cMethod     NVARCHAR(2)
   DECLARE @cWaveKey    NVARCHAR(20)
   DECLARE @cStatus     NVARCHAR(20)
   DECLARE @cTOLOC      NVARCHAR(20)
   DECLARE @nNoofTote   INT
   DECLARE @nToteCompleted INT
   DECLARE @nTotePending INT
   DECLARE @cPreviousSKU  NVARCHAR( 20)
   DECLARE @cSKU          NVARCHAR( 20)
   DECLARE @cEditWho      NVARCHAR( 20)
   DECLARE @nQty          INT

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module
      BEGIN
         DECLARE @cUserDefine01 NVARCHAR( 20)
         DECLARE @cUserDefine02 NVARCHAR( 20)
         DECLARE @cDropID       NVARCHAR( 20)

         -- Parameter mapping
         SET @cDropID = @cParam1

         -- Check blank
         IF @cDropID = '' 
         BEGIN
            SET @nErrNo = 209201
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Need DROP ID
            GOTO Quit
         END

         -- Get drop ID info
         SELECT TOP 1 
            @cWaveKey = ISNULL( O.UserDefine09, '')
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.Storerkey = @cStorerkey
            AND PD.DropID = @cDropID
            AND PD.Status IN ( '3', '5')
            AND PD.QTY > 0
         ORDER By PD.EditDate DESC

         -- Check valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 209202
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Invalid DropID
            GOTO Quit
         END
                     
         -- Check wave
         IF @cWaveKey = ''
         BEGIN
            SET @nErrNo = 209203
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No wave
            GOTO Quit
         END

         -- Get wave info
         SELECT 
            @cUserDefine01 = ISNULL( UserDefine01, ''),
            @cUserDefine02 = ISNULL( UserDefine02, '')
         FROM dbo.Wave WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey

         SET @cPreviousSKU = @c_oFieled10

         IF ISNULL(@cPreviousSKU,'') = ''
         BEGIN
            SELECT  TOP 1  @cSKU = SKU,  
                           @cEditWho = Editwho,
                           @nQTY = SUM(QTY)
            FROM dbo.PickDetail PD WITH (NOLOCK) 
            WHERE PD.Storerkey = @cStorerkey
               AND PD.DropID = @cDropID
               AND PD.Status IN ( '3', '5')
               AND PD.QTY > 0
            GROUP BY SKU,Editwho
            ORDER By PD.SKU
         END
         ELSE
         BEGIN
            SELECT  TOP 1  @cSKU = SKU,
                           @cEditWho = Editwho,
                           @nQTY = SUM(QTY) 
            FROM dbo.PickDetail PD WITH (NOLOCK)
            WHERE PD.Storerkey = @cStorerkey
               AND PD.DropID = @cDropID
               AND PD.Status IN ( '3', '5')
               AND PD.QTY > 0
               AND SKU > @cPreviousSKU
            GROUP BY SKU,Editwho
            ORDER By PD.SKU 
         END

         -- Get label
         SET @c_oFieled01 = rdt.rdtgetmessage( 209204, @cLangCode, 'DSP') + @cDropID--TOTE NO: 
         SET @c_oFieled02 = rdt.rdtgetmessage( 209205, @cLangCode, 'DSP') --SORTING RAMP:
         SET @c_oFieled03 = @cUserDefine02
         SET @c_oFieled04 = rdt.rdtgetmessage( 209206, @cLangCode, 'DSP') --PTL STATION:
         SET @c_oFieled05 = @cUserDefine01
         SET @c_oFieled06 = rdt.rdtgetmessage( 209207, @cLangCode, 'DSP') --WAVEKEY:
         SET @c_oFieled07 = @cWaveKey
         SET @c_oFieled08 = rdt.rdtgetmessage( 209208, @cLangCode, 'DSP') +  @cEditWho --Editwho:
         SET @c_oFieled09 = rdt.rdtgetmessage( 209209, @cLangCode, 'DSP') --SKU:
         SET @c_oFieled10 = @cSKU
         SET @c_oFieled12 = rdt.rdtgetmessage( 209210, @cLangCode, 'DSP') + CAST(@nQTY AS NVARCHAR(5))--qty:

         IF @cSKU = @cPreviousSKU
         BEGIN
            SET @nNextPage = 1
         END
         ELSE
         BEGIN
            SET @nNextPage = -1  
         END
      END
   END

Quit:

END

GO