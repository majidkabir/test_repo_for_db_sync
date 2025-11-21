SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store procedure: [rdt_600ExtValVLT]                                   */
/* Copyright: Maersk                                                     */
/*                                                                       */
/*                                                                       */
/* Date         Rev   Author   Purposes                                  */
/* 21/03/2024   1.0   PPA374   To NOT allow condition code to be used    */
/* 03/07/2024   1.1   PPA374   To stop using same ID that is in use      */
/* 18/10/2024   1.2   PPA374   Adding check for SKU style (shlv/inb)     */
/* 18/10/2024   1.3   PPA374   Consolidaton receiving prevention         */
/*************************************************************************/

CREATE   PROC [RDT].[rdt_600ExtValVLT] (
   @nMobile            INT,
   @nFunc              INT,
   @cLangCode          NVARCHAR( 3),
   @nStep              INT,
   @nInputKey          INT,
   @cFacility          NVARCHAR( 5),
   @cStorerKey         NVARCHAR( 15),
   @cReceiptKey        NVARCHAR( 10),
   @cPOKey             NVARCHAR( 10),
   @cLOC               NVARCHAR( 10),
   @cID                NVARCHAR( 18),
   @cSKU               NVARCHAR( 20),
   @cLottable01        NVARCHAR( 18),
   @cLottable02        NVARCHAR( 18),
   @cLottable03        NVARCHAR( 18),
   @dLottable04        DATETIME,
   @dLottable05        DATETIME,
   @cLottable06        NVARCHAR( 30),
   @cLottable07        NVARCHAR( 30),
   @cLottable08        NVARCHAR( 30),
   @cLottable09        NVARCHAR( 30),
   @cLottable10        NVARCHAR( 30),
   @cLottable11        NVARCHAR( 30),
   @cLottable12        NVARCHAR( 30),
   @dLottable13        DATETIME,
   @dLottable14        DATETIME,
   @dLottable15        DATETIME,
   @nQTY               INT,
   @cReasonCode        NVARCHAR( 10),
   @cSuggToLOC         NVARCHAR( 10),
   @cFinalLOC          NVARCHAR( 10),
   @cReceiptLineNumber NVARCHAR( 10),
   @nErrNo             INT            OUTPUT,
   @cErrMsg            NVARCHAR( 20)  OUTPUT
) AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
      
   IF @nFunc = 600
   BEGIN
      IF @nStep = 6 --QTY
      BEGIN
         IF ISNULL(@cReasonCode,'') <> ''
         BEGIN
            SET @nErrNo = 217970
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --217970KeepCondEmpty
            GOTO Quit
         END

         IF EXISTS (SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'SHELFRHUSQ' AND Storerkey = @cStorerKey
         AND udf01 = (SELECT TOP 1 style FROM sku WITH(NOLOCK) WHERE sku = @cSKU AND Storerkey = @cStorerKey)
         AND udf02 = (SELECT TOP 1 PutawayZone FROM loc WITH(NOLOCK) WHERE loc = @cLOC AND facility = @cFacility))
         AND
         (SELECT convert(float,Cube)*
            (SELECT ISNULL((SELECT TOP 1 case when short = 1 then convert(float,Long) else 100 end 
            FROM dbo.CODELKUP WITH(NOLOCK)
            WHERE listname = 'TRLCAPHUSQ'
               AND StorerKey = @cStorerKey
               AND code = 'IN'),100))/100
         -
            (SELECT ISNULL(sum(COL1),0) FROM
               (SELECT LLI.Qty * LengthUOM3 * WidthUOM3 * HeightUOM3 col1
               FROM dbo.LOTxLOCxID lli WITH(NOLOCK)
               INNER JOIN dbo.SKU s WITH(NOLOCK)
                  ON LLI.Sku = S.Sku
               INNER JOIN dbo.PACK P WITH(NOLOCK)
                  ON P.PackKey = s.PACKKey
               WHERE lli.StorerKey = @cStorerKey
                  AND loc = @cLOC
                  AND LLI.qty > 0)T1)
         -
            (SELECT @nQTY * LengthUOM3 * WidthUOM3 * HeightUOM3 FROM dbo.SKU S WITH(NOLOCK)
            INNER JOIN dbo.PACK P WITH(NOLOCK)
               ON P.PackKey = s.PACKKey
            WHERE sku = @cSKU AND StorerKey = @cStorerKey)
            FROM LOC WITH(NOLOCK)
            WHERE facility = @cFacility
               AND loc = @cLOC)<0
         BEGIN
            SET @nErrNo = 218019
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'Over cart capacity'
            GOTO Quit
         END

         IF EXISTS (SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'SHELFRHUSQ' AND Storerkey = @cStorerKey
            AND udf01 = (SELECT TOP 1 style FROM dbo.sku WITH(NOLOCK) WHERE sku = @cSKU AND Storerkey = @cStorerKey)
            AND udf02 = (SELECT TOP 1 PutawayZone FROM dbo.loc WITH(NOLOCK) WHERE loc = @cLOC AND facility = @cFacility))
         BEGIN
            Declare @nCubic INT = 0,
            @nWeight float = 0
       
            SELECT 
               @nCubic = cast(SUBSTRING(CAST(P.LengthUOM3 * P.WidthUOM3 * P.HeightUOM3 * @nQTY AS VARCHAR(50)), 1, 9)AS INT),
               @nWeight = cast(SUBSTRING(CAST(SKU.STDGROSSWGT * @nQTY AS VARCHAR(50)), 1, 9) AS FLOAT)
            FROM dbo.SKU WITH (NOLOCK) 
            LEFT JOIN dbo.PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
            WHERE SKU.SKU = @cSKU
               AND SKU.StorerKey = @cStorerKey

            IF NOT EXISTS (SELECT 1 FROM dbo.LOC WITH (NOLOCK) 
               LEFT JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON (LLI.LOC = LOC.LOC AND LLI.StorerKey = @cStorerKey)
               LEFT JOIN dbo.SKU WITH (NOLOCK) ON LLI.SKU = SKU.SKU AND SKU.StorerKey = LLI.StorerKey
               LEFT JOIN dbo.PACK P WITH (NOLOCK) ON SKU.PACKKey = P.PackKey
               INNER JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON SL.Loc = LOC.Loc
               WHERE 
                  LOC.LocationType = 'SHELF'
                  AND LOC.LocationCategory = 'SHELVING'
                  AND LOC.LocationFlag = 'NONE'
                  AND LOC.STATUS = 'OK'
                  AND LOC.FACILITY = @cFacility
                  AND SL.Sku = @cSKU
                  AND SL.LocationType = 'PICK'
               GROUP BY LOC.LOC
               HAVING SUM(ISNULL((LLI.qty-LLI.QtyPicked+PendingMoveIn),0) * ISNULL(P.CubeUOM3,0)) + @nCubic <= MAX(LOC.CubicCapacity)
                  AND SUM(ISNULL((LLI.qty-LLI.QtyPicked+PendingMoveIn),0) * ISNULL(SKU.STDGROSSWGT,0)) + @nWeight <= MAX(LOC.WeightCapacity))
            BEGIN
               SET @nErrNo = 218038
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'No loc OR big/heavy'
               GOTO Quit
            END
         END
      END

      ELSE IF @nStep = 4 --SKU
      BEGIN
         IF EXISTS (SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'SHELFRHUSQ' AND Storerkey = @cStorerKey
            AND udf01 = (SELECT TOP 1 style FROM dbo.sku WITH(NOLOCK) WHERE sku = @cSKU AND Storerkey = @cStorerKey)
            AND udf02 <> (SELECT TOP 1 PutawayZone FROM dbo.loc WITH(NOLOCK) WHERE loc = @cLOC AND facility = @cFacility)
            AND udf03 <> (SELECT TOP 1 PutawayZone FROM dbo.loc WITH(NOLOCK) WHERE loc = @cLOC AND facility = @cFacility))
         BEGIN
            SET @nErrNo = 218004
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Receive to trolley'
            GOTO Quit
         END

         IF EXISTS (SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'SHELFRHUSQ' AND Storerkey = @cStorerKey
            AND udf01 <> (SELECT TOP 1 style FROM dbo.sku WITH(NOLOCK) WHERE sku = @cSKU AND Storerkey = @cStorerKey)
            AND udf02 = (SELECT TOP 1 PutawayZone FROM dbo.loc WITH(NOLOCK) WHERE loc = @cLOC AND facility = @cFacility))
         BEGIN
            SET @nErrNo = 218005
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Receive to INB stage'
            GOTO Quit
         END

         IF (SELECT TOP 1 Style FROM dbo.SKU WITH(NOLOCK) WHERE Sku = @cSKU AND StorerKey = @cStorerKey) = 'CON'
         BEGIN
            SET @nErrNo = 218035
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --'Cannot receive cons'
            GOTO Quit
         END

         IF EXISTS (SELECT 1 FROM dbo.CODELKUP WITH(NOLOCK) WHERE LISTNAME = 'SHELFRHUSQ'  AND StorerKey = @cStorerKey
            AND udf01 = (SELECT TOP 1 style FROM sku WITH(NOLOCK) WHERE sku = @cSKU AND Storerkey = @cStorerKey))
            AND (NOT EXISTS 
                  (SELECT 1 FROM SKUxLOC SL WITH(NOLOCK) WHERE sku = @cSKU AND LocationType = 'PICK' 
            AND EXISTS (SELECT 1 FROM LOC L WITH(NOLOCK) WHERE SL.Loc = L.Loc AND L.LocationType = 'SHELF')))
         BEGIN
            SET @nErrNo = 218039
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP')--'No shelfpick loc set'
            GOTO Quit          
         END
      END

      ELSE IF @nstep = 3 --ID
      BEGIN
         IF len(replace(rtrim(ltrim(@cID)),' ',''))<>10 OR (SELECT CHARINDEX (' ',@cID))>0
         BEGIN
            SET @nErrNo = 217971
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --217971BadFormat
            GOTO Quit
         END
         
         IF EXISTS (SELECT 1 FROM dbo.RECEIPTDETAIL WITH(NOLOCK) WHERE toid = @cID AND storerkey = @cStorerKey)
         BEGIN
            SET @nErrNo = 217972
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --217972IDinUse
            GOTO Quit
         END
      END
   END
Quit:
END

GO