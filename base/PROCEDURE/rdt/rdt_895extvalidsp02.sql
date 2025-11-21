SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_895ExtValidSP02                                 */
/* Purpose:                                                             */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author     Purposes                                  */
/* 2021-04-30 1.0  Chermain   WMS-16885 Created(dup rdt_895ExtValidSP01)*/
/************************************************************************/

CREATE PROC [RDT].[rdt_895ExtValidSP02] (
      @nMobile        INT,
      @nFunc          INT,
      @cLangCode      NVARCHAR( 3),
      @nStep          INT,
      @cStorerKey     NVARCHAR( 15),
      @cReplenishmentKey  NVARCHAR( 20),
      @cLabelNo           NVARCHAR( 20),
      @nErrNo             INT           OUTPUT,
      @cErrMsg            NVARCHAR( 20) OUTPUT
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

IF @nFunc = 895
BEGIN

    DECLARE  @cLottable09Validation NVARCHAR(10)
            ,@cLot                  NVARCHAR(10)
            ,@cLottable09           NVARCHAR(60)
            ,@nUCCQty               INT
            ,@nQty                  INT
            ,@cRefNo                NVARCHAR(20)
            ,@cWaveKey              NVARCHAR(10)
            ,@cSKU                  NVARCHAR(20)
            ,@cUCCSKU               NVARCHAR(20)
            ,@nCountSKU             INT
            ,@cReplenNo             NVARCHAR(10)

    SET @nErrNo          = 0
    SET @cErrMSG         = ''

    IF @nStep = 5
    BEGIN

       IF NOT EXISTS ( SELECT 1 FROM dbo.UCC WITH (NOLOCK)
                       WHERE StorerKey = @cStorerKey
                       AND UCCNo = @cLabelNo )
       BEGIN
         SET @nErrNo = 93805
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'
         GOTO QUIT
       END

       SELECT @nUCCQty = Qty
             ,@cSKU    = SKU
       FROM dbo.UCC WITH (NOLOCK)
       WHERE UCCNo = @cLabelNo
       AND Status IN ('0', '1','3')

       SELECT @nCountSKU = Count(DISTINCT SKU )
       FROM dbo.UCC WITH (NOLOCK)
       WHERE UCCNo = @cLabelNo

       SELECT @nQty = Qty
             ,@cLot = Lot
             ,@cRefNo = RefNo
             ,@cWaveKey = WaveKey
             ,@cUCCSKU     = SKU
             ,@cReplenNo    = ReplenNo
       FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
       WHERE ReplenishmentKey = @cReplenishmentKey

       IF @nCountSKU = 1
       BEGIN
         IF ISNULL(RTRIM(@cSKU),'')  <> ISNULL(RTRIM(@cUCCSKU),'')
         BEGIN
            SET @nErrNo = 93806
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidSKU'
            GOTO QUIT
         END

       END

       IF ISNULL(RTRIM(@cReplenNo),'')  <> 'RPL-COMBCA'
       BEGIN
          IF ISNULL(@nUCCQty,0) <> ISNULL(@nQty,0 )
          BEGIN
            SET @nErrNo = 93802
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCCQty'
            GOTO QUIT
          END
       END

       IF ISNULL(RTRIM(@cRefNo),'')  <> '' AND ISNULL(RTRIM(@cReplenNo),'')  <> 'RPL-COMBCA'
       BEGIN
         IF ISNULL(RTRIM(@cLabelNo),'')  <> ISNULL(RTRIM(@cRefNo),'')
         BEGIN
            SET @nErrNo = 93803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidUCC'
            GOTO QUIT
         END
       END

--       IF EXISTS ( SELECT 1 FROM rdt.rdtReplenishmentLog WITH (NOLOCK)
--                   WHERE WaveKey = @cWaveKey
--                   AND DropID = @cLabelNo )
--       BEGIN
--            SET @nErrNo = 93804
--            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCScanned'
--            GOTO QUIT
--       END
--

       IF EXISTS ( SELECT 1 FROM dbo.WaveDetail WD WITH (NOLOCK)
                  INNER JOIN dbo.Orders O WITH (NOLOCK) ON O.OrderKey = WD.OrderKey
                  INNER JOIN dbo.PackHeader PH WITH (NOLOCK) ON PH.OrderKey  = O.OrderKey
                  INNER JOIN dbo.PackDetail PD WITH (NOLOCK) ON PD.PickslipNo = PH.PickslipNo
                  WHERE WD.WaveKey = @cWaveKey
                  AND PD.DropID = @cLabelNo )
       BEGIN
            SET @nErrNo = 93807
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'UCCScanned'
            GOTO QUIT
       END




       SELECT @cLottable09Validation = Short
       FROM dbo.Codelkup WITH (NOLOCK)
       WHERE ListName = 'REPLENUA'
       AND Code = 'LOT09'



       SELECT @cLottable09 = Lottable09
       FROM dbo.LotAttribute WITH (NOLOCK)
       WHERE Lot = @cLot


--       IF ISNULL(RTRIM(@cLottable09Validation),'')  <> ISNULL(RTRIM(@cLottable09),'')
--       BEGIN
--         SET @nErrNo = 93801
--         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'InvalidLot09'
--         GOTO QUIT
--       END


    END




END

QUIT:


GO