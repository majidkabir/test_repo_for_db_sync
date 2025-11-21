SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_DynamicPick_UCCPickAndPack_GetNextTask          */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date       Rev  Author      Purposes                                 */
/* 25-04-2013 1.0  Ung         SOS262114 Created                        */
/************************************************************************/

CREATE PROC [RDT].[rdt_DynamicPick_UCCPickAndPack_GetNextTask] (
   @nMobile      INT,
   @nFunc        INT, 
   @cLangCode    NVARCHAR( 3),
   @cStorerKey   NVARCHAR( 15),
   @cWaveKey     NVARCHAR( 10),
   @cLOC         NVARCHAR( 10),
   @cSKU         NVARCHAR( 20) OUTPUT,
   @cSKUDescr    NVARCHAR( 60) OUTPUT,        
   @cLottable01  NVARCHAR( 18) OUTPUT,   
   @cLottable02  NVARCHAR( 18) OUTPUT, 
   @cLottable03  NVARCHAR( 18) OUTPUT, 
   @dLottable04  DATETIME  OUTPUT, 
   @nBal         INT       OUTPUT, -- Balance UCC to pick in the LOC
   @nTotal       INT       OUTPUT, -- Total UCC to pick in the LOC
   @nErrNo       INT       OUTPUT, 
   @cErrMsg      NVARCHAR( 20) OUTPUT
)
AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @dZero DATETIME
   SET @dZero = 0  -- 1900-01-01

   SET @nErrNo = 0
   SET @cErrMsg = ''

   SELECT TOP 1
      @cSKU        = PD.SKU,
      @cLottable01 = LA.Lottable01,         
      @cLottable02 = LA.Lottable02,
      @cLottable03 = LA.Lottable03,
      @dLottable04 = CONVERT( NVARCHAR( 10), IsNULL(LA.Lottable04, @dZero), 120)
   FROM dbo.PickDetail PD WITH (NOLOCK)
      JOIN dbo.LotAttribute LA WITH (NOLOCK) ON (PD.LOT = LA.LOT)
   WHERE PD.WaveKey = @cWaveKey
      AND PD.LOC = @cLOC
      AND PD.Status < '3'
      AND PD.QTY > 0
      AND PD.UOM = '2' -- Full case
      AND NOT EXISTS (SELECT 1 
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD1 WITH (NOLOCK) ON (O.OrderKey = PD1.OrderKey)
         WHERE O.OrderKey = PD.OrderKey
            AND O.SOStatus = 'CANC'
            AND PD1.UOM = '2' -- Full case
         GROUP BY PD1.Status
         HAVING MAX( PD1.Status) = '0')

   -- Check if any task
   IF @@ROWCOUNT = 0
   BEGIN
      SET @nErrNo = 80851
      SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --No more TASK
      GOTO Quit
   END
   
   -- Get total UCC to pick
   SELECT @nTotal = COUNT( DISTINCT PD.DropID) 
   FROM dbo.PickDetail PD WITH (NOLOCK)
   WHERE PD.WaveKey = @cWaveKey
      AND PD.LOC = @cLOC
      AND PD.Status <= '3' -- Everythig. Picked and not yet pick
      AND PD.QTY > 0 
      AND PD.UOM = '2' -- Full case
      AND NOT EXISTS (SELECT 1 
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD1 WITH (NOLOCK) ON (O.OrderKey = PD1.OrderKey)
         WHERE O.OrderKey = PD.OrderKey
            AND O.SOStatus = 'CANC'
            AND PD1.UOM = '2' -- Full case
         GROUP BY PD1.Status
         HAVING MAX( PD1.Status) = '0')

   -- Get UCC not yet pick
   SELECT @nBal = COUNT( DISTINCT PD.DropID) 
   FROM dbo.PickDetail PD WITH (NOLOCK)
   WHERE PD.WaveKey = @cWaveKey
      AND PD.LOC = @cLOC
      AND PD.Status < '3' -- Not yet pick
      AND PD.QTY > 0 
      AND PD.UOM = '2' -- Full case
      AND NOT EXISTS (SELECT 1 
         FROM dbo.Orders O WITH (NOLOCK)
            JOIN dbo.PickDetail PD1 WITH (NOLOCK) ON (O.OrderKey = PD1.OrderKey)
         WHERE O.OrderKey = PD.OrderKey
            AND O.SOStatus = 'CANC'
            AND PD1.UOM = '2' -- Full case
         GROUP BY PD1.Status
         HAVING MAX( PD1.Status) = '0')

   IF @dLottable04 = '1900-01-01 00:00:00.000' 
      SET @dLottable04 = NULL

   -- Get SKU description
   SELECT @cSKUDescr = Descr
   FROM dbo.SKU SKU WITH (NOLOCK)
   WHERE Storerkey = @cStorerKey 
      AND SKU = @cSKU

Quit:
   
END

GO