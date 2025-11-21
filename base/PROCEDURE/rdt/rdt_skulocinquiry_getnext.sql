SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_SKULOCInquiry_GetNext                           */
/*                                                                      */
/* Purpose: Get next SKU and/or LOC                                     */
/*                                                                      */
/* Called from: rdtfnc_SKULOCInquiry                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 02-Feb-2017 1.0  James      WMS746 - Created                         */
/* 22-Sep-2021 1.1  James      WMS-17918 Add display line (james01)     */
/************************************************************************/

CREATE PROC [RDT].[rdt_SKULOCInquiry_GetNext] (
   @nMobile          INT,
   @nFunc            INT, 
   @cLangCode        NVARCHAR( 3),
   @nStep            INT, 
   @nInputKey        INT, 
   @cStorerKey       NVARCHAR( 15), 
   @cFacility        NVARCHAR( 5), 
   @cInquiry_SKU     NVARCHAR( 20), 
   @cInquiry_LOC     NVARCHAR( 10), 
   @cNextSKU         NVARCHAR( 20)  OUTPUT, 
   @cNextLOC         NVARCHAR( 10)  OUTPUT, 
   @cSKUDescr        NVARCHAR( 60)  OUTPUT, 
   @cSummary         NVARCHAR( 20)  OUTPUT, 
   @nNoOfRec         INT            OUTPUT, 
   @cLocType         NVARCHAR( 10)  OUTPUT, 
   @cDisplay01       NVARCHAR( 20)  OUTPUT, 
   @cDisplay02       NVARCHAR( 20)  OUTPUT, 
   @cDisplay03       NVARCHAR( 20)  OUTPUT, 
   @cDisplay04       NVARCHAR( 20)  OUTPUT,
   @cDisplay05       NVARCHAR( 20)  OUTPUT,
   @cDisplay06       NVARCHAR( 20)  OUTPUT,
   @cDisplay07       NVARCHAR( 20)  OUTPUT,
   @cDisplay08       NVARCHAR( 20)  OUTPUT,
   @nErrNo           INT            OUTPUT, 
   @cErrMsg          NVARCHAR( 125) OUTPUT 
)
AS

SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF

DECLARE @nQtyAvailable  INT
DECLARE @nQtyOnHand     INT
DECLARE @nQtyOnHold     INT
DECLARE @nQtyAllocated  INT
DECLARE @nLoop          INT
DECLARE @cPage          NVARCHAR( 2)
DECLARE @cLLI_SKU       NVARCHAR( 20)
DECLARE @cLLI_LocType   NVARCHAR( 10)
DECLARE @nLLI_Qty       INT
DECLARE @cLLI_LOC       NVARCHAR( 10)

SET @cDisplay01 = ''
SET @cDisplay02 = ''
SET @cDisplay03 = ''
SET @cDisplay04 = ''
SET @cDisplay05 = ''
SET @cDisplay06 = ''
SET @cDisplay07 = ''
SET @cDisplay08 = ''

IF ISNULL( @cInquiry_LOC, '') <> ''
   SELECT @nNoOfRec = COUNT( DISTINCT LLI.SKU)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC = @cInquiry_LOC
   AND   ( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LOC.Facility = @cFacility
ELSE
   SELECT @nNoOfRec = COUNT( DISTINCT LLI.LOC)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cInquiry_SKU
   AND   ( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LOC.Facility = @cFacility
   
IF ISNULL( @cSummary, '') = ''
BEGIN
   IF @nNoOfRec > 4
      SET @cSummary = '1/' + CAST( CEILING( @nNoOfRec/CONVERT( DECIMAL( 4, 2), 4)) AS NVARCHAR( 4))
   ELSE
      SET @cSummary = '1/1'
END
ELSE
BEGIN
   SET @cPage = CAST( LEFT( @cSummary, CHARINDEX( '/', @cSummary) - 1) AS INT) + 1
   SET @cSummary = @cPage + '/' + CAST( CEILING( @nNoOfRec/CONVERT( DECIMAL( 4, 2), 4)) AS NVARCHAR( 4))
END

IF ISNULL( @cInquiry_LOC, '') <> ''
BEGIN
   SET @cNextLOC = @cInquiry_LOC

   SELECT @nNoOfRec = COUNT( DISTINCT LLI.SKU)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   ( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LOC.Facility = @cFacility
   AND   LOC.LOC = @cInquiry_LOC
   
   SET @nLoop = 1
   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LLI.SKU, SL.LOCATIONTYPE, SUM( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (LLI.LOC = SL.LOC AND LLI.SKU = SL.SKU)
   WHERE LLI.StorerKey = @cStorerKey
   AND   ( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LLI.SKU > @cNextSKU
   AND   LOC.Facility = @cFacility
   AND   LOC.LOC = @cInquiry_LOC
   GROUP BY LLI.SKU, SL.LOCATIONTYPE
   ORDER BY LLI.SKU, SL.LOCATIONTYPE
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLLI_SKU, @cLLI_LocType, @nLLI_Qty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @cNextSKU = @cLLI_SKU

      IF ISNULL( @cLLI_LocType, '') = ''
         SET @cLLI_LocType = 'UNASSIGNED'

      IF @nLoop = 1
      BEGIN
         SET @cDisplay01 = @cLLI_SKU
         SET @cDisplay02 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + @cLLI_LocType
      END

      IF @nLoop = 2
      BEGIN
         SET @cDisplay03 = @cLLI_SKU
         SET @cDisplay04 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + @cLLI_LocType
      END

      IF @nLoop = 3
      BEGIN
         SET @cDisplay05 = @cLLI_SKU
         SET @cDisplay06 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + @cLLI_LocType
      END

      IF @nLoop = 4
      BEGIN
         SET @cDisplay07 = @cLLI_SKU
         SET @cDisplay08 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + @cLLI_LocType
      END

      SET @nLoop = @nLoop + 1

      IF @nLoop = 5
         BREAK

      FETCH NEXT FROM CUR_LOOP INTO @cLLI_SKU, @cLLI_LocType, @nLLI_Qty
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
END

IF ISNULL( @cInquiry_SKU, '') <> ''
BEGIN
   SET @cNextSKU = @cInquiry_SKU

   SELECT @cSKUDescr = Descr
   FROM dbo.SKU WITH (NOLOCK)
   WHERE StorerKey = @cStorerKey
   AND   SKU = @cInquiry_SKU
      
   SELECT TOP 1 @cLocType = SL.LocationType
   FROM dbo.SKUxLOC SL WITH (NOLOCK)
   JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( SL.SKU = LLI.SKU AND SL.SKU = LLI.SKU)
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cInquiry_SKU
   AND   ( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LOC.Facility = @cFacility
   ORDER BY SL.LocationType DESC

   IF ISNULL( @cLocType, '') = ''
      SET @cLocType = 'UNASSIGNED'

   SET @nLoop = 1
   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LLI.LOC, SUM( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END))
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cInquiry_SKU
   AND   ( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - (CASE WHEN LLI.QtyReplen < 0 THEN 0 ELSE LLI.QtyReplen END)) > 0
   AND   LOC.Facility = @cFacility
   AND   LOC.LOC > @cNextLOC
   GROUP BY LLI.LOC
   ORDER BY LLI.LOC
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLLI_LOC, @nLLI_Qty
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @cNextLOC = @cLLI_LOC

      IF @nLoop = 1
         SET @cDisplay01 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + SPACE( 5) + CAST( @nLLI_Qty AS NVARCHAR( 5))

      IF @nLoop = 2
         SET @cDisplay02 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + SPACE( 5) + CAST( @nLLI_Qty AS NVARCHAR( 5))

      IF @nLoop = 3
         SET @cDisplay03 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + SPACE( 5) + CAST( @nLLI_Qty AS NVARCHAR( 5))

      IF @nLoop = 4
         SET @cDisplay04 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + SPACE( 5) + CAST( @nLLI_Qty AS NVARCHAR( 5))

      SET @nLoop = @nLoop + 1
      
      IF @nLoop = 5
         BREAK

      FETCH NEXT FROM CUR_LOOP INTO @cLLI_LOC, @nLLI_Qty
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
   --(james01)
   SET @cDisplay05 = 'LOC        QTY   AVL'   
END

Quit:

SET QUOTED_IDENTIFIER OFF

GO