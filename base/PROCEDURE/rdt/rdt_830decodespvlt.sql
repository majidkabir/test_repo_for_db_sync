SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/****************************************************************************************/
/* Stored Procedure: rdt_830DecodeSPVLT                                                 */
/*                                                                                      */
/* Updates:                                                                             */
/* Date         Author  Ver.    Purposes                                                */
/* 05/05/2024   PPA374  1.0     Allowing to scan ID instead of SKU for WA AND VNA picks */
/* 31/10/2024   PPA374  1.1.0   UWP-26437 Adding shelf logic to the SP                  */
/* 2024-10-29   PXL009  1.2.0   FCR-759 ID and UCC Length Issue                         */
/* 02/07/2025   PPA374  1.2.1   UWP-297978 PE code review                               */
/****************************************************************************************/
CREATE   PROC [RDT].[rdt_830DecodeSPVLT]
   @nMobile      INT,
   @nFunc        INT,
   @cLangCode    NVARCHAR( 3),
   @nStep        INT,
   @nInputKey    INT,
   @cStorerKey   NVARCHAR( 15),
   @cFacility    NVARCHAR( 20),
   @cLOC         NVARCHAR( 10),
   @cDropid      NVARCHAR( 20),
   @cPickSlipNo  NVARCHAR( 20),
   @cBarcode     NVARCHAR( 60),
   @cFieldName   NVARCHAR( 10),
   @cUPC         NVARCHAR( 20)  OUTPUT,
   @cSKU         NVARCHAR( 20)  OUTPUT,
   @cDefaultQTY  INT            OUTPUT,
   @cLottable01  NVARCHAR( 18)  OUTPUT,
   @cLottable02  NVARCHAR( 18)  OUTPUT,
   @cLottable03  NVARCHAR( 18)  OUTPUT,
   @dLottable04  DATETIME       OUTPUT,
   @dLottable05  DATETIME       OUTPUT,
   @cLottable06  NVARCHAR( 30)  OUTPUT,
   @cLottable07  NVARCHAR( 30)  OUTPUT,
   @cLottable08  NVARCHAR( 30)  OUTPUT,
   @cLottable09  NVARCHAR( 30)  OUTPUT,
   @cLottable10  NVARCHAR( 30)  OUTPUT,
   @cLottable11  NVARCHAR( 30)  OUTPUT,
   @cLottable12  NVARCHAR( 30)  OUTPUT,
   @dLottable13  DATETIME       OUTPUT,
   @dLottable14  DATETIME       OUTPUT,
   @dLottable15  DATETIME       OUTPUT,
   @cUserDefine01 NVARCHAR(30)  OUTPUT,
   @nErrNo       INT            OUTPUT,
   @cErrMsg      NVARCHAR( 20)  OUTPUT
AS
BEGIN   
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   IF @nFunc = 830 AND @nStep = 3 AND @nInputKey = 1
   BEGIN
      IF (SELECT COUNT (DISTINCT SKU) FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE Id = @cBarcode AND StorerKey = @cStorerKey AND qty > 0 AND loc = @cLOC) > 1
      BEGIN
         SET @nErrNo = 217915
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUID
         GOTO skip
      END

      IF (SELECT COUNT (DISTINCT sku) FROM dbo.SKU WITH(NOLOCK) WHERE ALTSKU = @cBarcode AND StorerKey = @cStorerKey) > 1
      OR
      (SELECT COUNT (DISTINCT sku) FROM dbo.UPC WITH(NOLOCK) WHERE UPC = @cBarcode AND StorerKey = @cStorerKey) > 1
      BEGIN
         SET @nErrNo = 217916
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --MultiSKUBarcode
         GOTO skip
      END

      IF EXISTS (SELECT 1 FROM dbo.SKU WITH(NOLOCK) WHERE sku = @cBarcode AND StorerKey = @cStorerKey)
      BEGIN
         SET @cUPC = LEFT( @cBarcode, 30)
         GOTO skip
      END

      IF EXISTS (SELECT 1 FROM dbo.SKU WITH(NOLOCK) WHERE ALTSKU = @cBarcode AND StorerKey = @cStorerKey)
      BEGIN
         SET @cUPC = LEFT( (SELECT sku FROM dbo.SKU WITH(NOLOCK) WHERE ALTSKU = @cBarcode AND StorerKey = @cStorerKey), 30)
         GOTO skip
      END

      IF EXISTS (SELECT 1 FROM dbo.UPC WITH(NOLOCK) WHERE UPC = @cBarcode AND StorerKey = @cStorerKey)
      BEGIN
         SET @cUPC = LEFT( (SELECT SKU FROM dbo.UPC WITH(NOLOCK) WHERE UPC = @cBarcode AND StorerKey = @cStorerKey), 30)
         GOTO skip
      END

      IF EXISTS (SELECT 1 FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE Id = @cBarcode AND qty > 0 AND @cBarcode <> '' AND Loc = @cLOC AND StorerKey = @cStorerKey)
      BEGIN
         SET @cUPC = LEFT( (SELECT TOP 1 sku FROM dbo.LOTxLOCxID WITH(NOLOCK) WHERE Id = @cBarcode AND qty > 0 AND Loc = @cLOC AND StorerKey = @cStorerKey), 30)
         GOTO skip
      END
      ELSE
      BEGIN
         SET @nErrNo = 217917
         SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --IDorSKUNotFound
         GOTO Quit
      END

      SKIP:
         SET @cDefaultQTY = (SELECT SUM(qty) FROM dbo.PICKDETAIL WITH(NOLOCK) WHERE loc = @cLOC 
            AND NOT EXISTS (SELECT 1 FROM dbo.LOC (NOLOCK) WHERE Facility = @cFacility AND LocationType IN ('PICK','CASE','SHELF') AND loc = @cLOC)
            AND sku = @cSKU AND Storerkey = @cStorerKey AND OrderKey = (SELECT TOP 1 OrderKey FROM dbo.PICKHEADER WITH(NOLOCK) WHERE PickHeaderKey = @cpickslipno))
   END

   Quit:
END

GO