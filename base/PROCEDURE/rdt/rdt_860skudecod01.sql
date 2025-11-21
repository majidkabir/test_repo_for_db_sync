SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: rdt_860SKUDecod01                                   */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Decode SKU field. Scan lottable02 and return sku.           */
/*          Lottable02 = serial no and unique                           */
/*                                                                      */
/* Date        Rev  Author      Purposes                                */
/* 22-03-2018  1.0  James       WMS3621 Created                         */
/************************************************************************/

CREATE PROCEDURE [RDT].[rdt_860SKUDecod01]
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3), 
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerkey       NVARCHAR(15),
   @cPickSlipNo      NVARCHAR(10),
   @cBarcode         NVARCHAR(60),
   @cDropID          NVARCHAR(20)   OUTPUT,
   @cLOC             NVARCHAR(10)   OUTPUT,
   @cID              NVARCHAR(18)   OUTPUT,
   @cSKU             NVARCHAR(20)   OUTPUT,
   @nQty             INT            OUTPUT, 
   @cLottable01      NVARCHAR( 18)  OUTPUT, 
   @cLottable02      NVARCHAR( 18)  OUTPUT, 
   @cLottable03      NVARCHAR( 18)  OUTPUT, 
   @dLottable04      DATETIME       OUTPUT,  
   @dLottable05      DATETIME       OUTPUT,  
   @cLottable06      NVARCHAR( 30)  OUTPUT,  
   @cLottable07      NVARCHAR( 30)  OUTPUT,  
   @cLottable08      NVARCHAR( 30)  OUTPUT,  
   @cLottable09      NVARCHAR( 30)  OUTPUT,  
   @cLottable10      NVARCHAR( 30)  OUTPUT,  
   @cLottable11      NVARCHAR( 30)  OUTPUT,  
   @cLottable12      NVARCHAR( 30)  OUTPUT,  
   @dLottable13      DATETIME       OUTPUT,   
   @dLottable14      DATETIME       OUTPUT,   
   @dLottable15      DATETIME       OUTPUT,   
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR(250)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE  @cZone         NVARCHAR( 10),
            @cOrderKey     NVARCHAR( 10),
            @cLoadKey      NVARCHAR( 10),
            @cDecodedSKU   NVARCHAR( 20),
            @cSuggestedSKU NVARCHAR( 20)

   DECLARE     
      @cNewLottable01   NVARCHAR( 18),    @cNewLottable02   NVARCHAR( 18),    
      @cNewLottable03   NVARCHAR( 18),    @dNewLottable04   DATETIME,         
      @dNewLottable05   DATETIME,         @cNewLottable06   NVARCHAR( 30),    
      @cNewLottable07   NVARCHAR( 30),    @cNewLottable08   NVARCHAR( 30),    
      @cNewLottable09   NVARCHAR( 30),    @cNewLottable10   NVARCHAR( 30),    
      @cNewLottable11   NVARCHAR( 30),    @cNewLottable12   NVARCHAR( 30),    
      @dNewLottable13   DATETIME,         @dNewLottable14   DATETIME,         
      @dNewLottable15   DATETIME

   DECLARE     
      @cCurLottable01   NVARCHAR( 18),    @cCurLottable02   NVARCHAR( 18),    
      @cCurLottable03   NVARCHAR( 18),    @dCurLottable04   DATETIME,         
      @dCurLottable05   DATETIME,         @cCurLottable06   NVARCHAR( 30),    
      @cCurLottable07   NVARCHAR( 30),    @cCurLottable08   NVARCHAR( 30),    
      @cCurLottable09   NVARCHAR( 30),    @cCurLottable10   NVARCHAR( 30),    
      @cCurLottable11   NVARCHAR( 30),    @cCurLottable12   NVARCHAR( 30),    
      @dCurLottable13   DATETIME,         @dCurLottable14   DATETIME,         
      @dCurLottable15   DATETIME

   IF ISNULL( @cBarcode, '') = ''
      GOTO Quit

   SELECT 
      @cZone = Zone, 
      @cOrderKey = OrderKey, 
      @cLoadKey = ExternOrderKey     
   FROM dbo.PickHeader WITH (NOLOCK)     
   WHERE PickHeaderKey = @cPickSlipNo   

   SELECT @cCurLottable02 = V_Lottable02, 
          @cSuggestedSKU = O_FIELD03
   FROM rdt.RDTMOBREC WITH (NOLOCK)
   WHERE Mobile = @nMobile

   IF @nInputKey = 1
   BEGIN
      IF @nStep = 3
      BEGIN
         IF @cZone = 'XD' OR @cZone = 'LB' OR @cZone = 'LP' 
         BEGIN
            SELECT TOP 1 @cDecodedSKU = LA.SKU 
            FROM dbo.LotAttribute LA WITH (NOLOCK) 
            WHERE LA.Lottable02 = @cBarcode
            AND   EXISTS ( SELECT 1 
                           FROM RefKeyLookup WITH (NOLOCK) 
                           JOIN PickDetail PD WITH (NOLOCK) ON (RefKeyLookup.PickDetailKey = PD.PickDetailKey)
                           WHERE RefKeyLookup.PickslipNo = @cPickSlipNo
                           AND   PD.ID  = @cID  
                           AND   PD.LOC = @cLOC
                           AND   PD.Status < '4' -- Not yet picked
                           AND   PD.QTY > 0
                           AND   PD.SKU = LA.SKU
                           AND   PD.StorerKey = LA.StorerKey
                           AND   PD.LOT = LA.LOT)
            ORDER BY 1
         END
         ELSE IF @cOrderKey = ''
         BEGIN
            SELECT TOP 1 @cDecodedSKU = LA.SKU 
            FROM dbo.LotAttribute LA WITH (NOLOCK) 
            WHERE LA.Lottable02 = @cBarcode
            AND   EXISTS ( SELECT 1 
                           FROM dbo.PickHeader PH (NOLOCK)
                           JOIN dbo.LoadPlanDetail LPD WITH (NOLOCK) ON (PH.ExternOrderKey = LPD.LoadKey)
                           JOIN dbo.PickDetail PD WITH (NOLOCK) ON (LPD.OrderKey = PD.OrderKey)
                           WHERE PH.PickHeaderKey = @cPickSlipNo
                           AND   PD.ID  = @cID  
                           AND   PD.LOC = @cLOC
                           AND   PD.Status < '4' -- Not yet picked
                           AND   PD.QTY > 0
                           AND   PD.SKU = LA.SKU
                           AND   PD.StorerKey = LA.StorerKey
                           AND   PD.LOT = LA.LOT)
            ORDER BY 1
         END
         ELSE
         BEGIN
            SELECT TOP 1 @cDecodedSKU = LA.SKU 
            FROM dbo.LotAttribute LA WITH (NOLOCK) 
            WHERE LA.Lottable02 = @cBarcode
            AND   EXISTS ( SELECT 1 
                           FROM dbo.PickHeader PH (NOLOCK)
                           JOIN dbo.PickDetail PD WITH (NOLOCK) ON (PH.OrderKey = PD.OrderKey)
                           WHERE PH.PickHeaderKey = @cPickSlipNo
                           AND   PD.ID  = @cID  
                           AND   PD.LOC = @cLOC  
                           AND   PD.Status < '4' -- Not yet picked
                           AND   PD.QTY > 0
                           AND   PD.SKU = LA.SKU
                           AND   PD.StorerKey = LA.StorerKey
                           AND   PD.LOT = LA.LOT)
            ORDER BY 1
         END

         -- Serial no not allocated, check available qty (must same pallet id)
         IF ISNULL( @cDecodedSKU, '') = ''
            SELECT TOP 1 @cDecodedSKU = LA.SKU 
            FROM dbo.LotAttribute LA WITH (NOLOCK) 
            JOIN dbo.LotxLocxID LLI WITH (NOLOCK) ON LA.LOT = LLI.LOT
            WHERE LA.Lottable02 = @cBarcode
            AND   LLI.ID  = @cID 
            AND   LLI.LOC = @cLOC
            AND   LLI.QTY > 0
            AND   LLI.SKU = @cSuggestedSKU
            AND   LLI.StorerKey = @cStorerkey
            ORDER BY 1

         IF ISNULL( @cDecodedSKU, '') = ''
         BEGIN
            SET @nErrNo = 123651
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Inv Serial No'
            GOTO Quit
         END

         SET @cLottable02 = @cBarcode
         SET @cSKU = CASE WHEN ISNULL( @cDecodedSKU, '') = '' THEN '' ELSE @cDecodedSKU END
      END
   END
QUIT:

END -- End Procedure


GO