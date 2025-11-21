SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*****************************************************************************/
/* Store procedure: rdt_727Inquiry26                                         */
/* Copyright      : Maersk                                                   */
/*                                                                           */
/* Modifications log:                                                        */
/*                                                                           */
/* Date       Rev    Author     Purposes                                     */
/* 2024-12-12 1.1.0  PSJ036     RITM7378987 - UWP-28428 Add New requirement  */
/*****************************************************************************/
CREATE      PROC [RDT].[rdt_727Inquiry26] (
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
         DECLARE @cUserDefine01 NVARCHAR(20)
         DECLARE @cUserDefine02 NVARCHAR(20)
         DECLARE @cDropID       NVARCHAR(20)
         DECLARE @cLoadKey       NVARCHAR(20)
         DECLARE @cOrderKey       NVARCHAR(20)
         DECLARE @cConsigneeKey NVARCHAR(30)
         DECLARE @cStorer      NVARCHAR(30)
         DECLARE @cLastLoc       NVARCHAR(20)
         DECLARE @cEditwhoPD   NVARCHAR(20)
         DECLARE @cIDPD          NVARCHAR(20)
         DECLARE @cCountSKU       INT
         DECLARE @cCountOrder   INT
         DECLARE @cConsolidate  NVARCHAR(5)
         DECLARE @cConsoStatus  NVARCHAR(5)

         -- Parameter mapping
         SET @cDropID = @cParam1
         SET @cCountSKU = 0
         set @cCountOrder = 0

         -- Check blank
         IF @cDropID = ''
         BEGIN
            SET @nErrNo = 231001
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NeedDROPID
            GOTO Quit
         END

         -- Get drop ID info
         SELECT TOP 1
            @cWaveKey =  ISNULL( pd.WaveKey, ''),
            @cLoadKey =  ISNULL( O.LoadKey , ''),
            @cOrderKey = ISNULL( O.OrderKey , ''),
            @cConsigneeKey = O.C_Company,
            @cLastLoc = pd.Loc,
            @cEditwhoPD = PD.EditWho,
            @cIDPD = PD.ID
         FROM dbo.PickDetail PD WITH (NOLOCK)
         INNER JOIN dbo.Orders O WITH (NOLOCK) ON (O.OrderKey = PD.OrderKey)
         WHERE O.Storerkey = @cStorerkey
            AND PD.DropID = @cDropID
            AND PD.Status IN ( '3', '5')
            AND PD.QTY > 0
         ORDER By PD.EditDate DESC
       
         -- Check valid
         IF @@ROWCOUNT = 0
         BEGIN
            SET @nErrNo = 231002
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidDropID
            GOTO Quit
         END

         -- Check wave
         IF @cWaveKey = ''
         BEGIN
            SET @nErrNo = 231003
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --NowWave
            GOTO Quit
         END

         -- Get wave info Consolidated
         SELECT @cConsolidate = DispatchCasePickMethod 
         FROM dbo.WAVE WITH (NOLOCK)
         WHERE WaveKey = @cWaveKey
       
         IF ISNULL(@cConsolidate,'') = '2'
         BEGIN
            SET @cConsoStatus = 'Yes'
         END
         ELSE
         BEGIN
            SET @cConsoStatus = 'No'
         END

         --Get count SKU and Order by PickDetail
         SELECT 
            @cCountSKU = COUNT(DISTINCT SKU),
            @cCountOrder = COUNT(DISTINCT OrderKey)
         FROM PICKDETAIL WITH (NOLOCK) 
         WHERE DropID = @cDropID
            AND WaveKey = @cWaveKey
       
         -- Get label
         SET @c_oFieled01 = 'WaveKey: ' + @cWaveKey --WaveKey:
         SET @c_oFieled02 = 'LoadKey: ' + @cLoadKey --LoadKey:
         SET @c_oFieled03 = 'OrderKey: ' + @cOrderKey --OrderKey:
         SET @c_oFieled04 = 'Storer: ' + @cConsigneeKey --Storer:
         SET @c_oFieled05 = 'LasLoc: ' + @cLastLoc --LastLocation:
         SET @c_oFieled06 = 'EditWho: ' + @cEditwhoPD --EditWho:
         SET @c_oFieled07 = 'DropID: ' + @cDropID --DropID
         SET @c_oFieled08 = 'PalletID: ' + @cIDPD --PalletID:
         SET @c_oFieled09 = 'Consolidated?: ' + @cConsoStatus --Consolidated?:
         SET @c_oFieled10 = 'Count SKU/Order: ' + CAST(@cCountSKU AS NVARCHAR(5)) + '/' + CAST(@cCountOrder AS NVARCHAR(5))-- Count SKU


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