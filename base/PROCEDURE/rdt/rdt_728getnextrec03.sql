SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt_728GetNextRec03                                 */
/*                                                                      */
/* Purpose: Get next SKU and/or LOC (for FastPick loc)                  */
/*                                                                      */
/* Called from: rdtfnc_SKULOCInquiry                                    */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 2021-09-14  1.0  James      WMS-17918. Created                       */
/************************************************************************/

CREATE PROC [RDT].[rdt_728GetNextRec03] (
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
DECLARE @nLLI_Alc       INT
DECLARE @nLLI_Avl       INT
DECLARE @cFilterLocType NVARCHAR( 10)

SET @cDisplay01 = ''
SET @cDisplay02 = ''
SET @cDisplay03 = ''
SET @cDisplay04 = ''
SET @cDisplay05 = ''
SET @cDisplay06 = ''
SET @cDisplay07 = ''
SET @cDisplay08 = ''

SET @cFilterLocType = rdt.RDTGetConfig( @nFunc, 'FilterLocType', @cStorerKey)
IF @cFilterLocType = '0'
   SET @cFilterLocType = ''

IF ISNULL( @cInquiry_LOC, '') <> ''
   SELECT @nNoOfRec = COUNT( DISTINCT LLI.SKU)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.LOC = @cInquiry_LOC
   AND   ( LLI.QTY + LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
   AND   LOC.Facility = @cFacility
ELSE
   SELECT @nNoOfRec = COUNT( DISTINCT LLI.LOC)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cInquiry_SKU
   AND   ( LLI.QTY + LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
   AND   LOC.Facility = @cFacility
   AND   (( @cFilterLocType = '') OR ( LOC.LocationType = @cFilterLocType))
   
   IF @cFilterLocType = 'FASTPICK'
      SET @nNoOfRec = 1
      
IF ISNULL( @cSummary, '') = ''
BEGIN
   IF @nNoOfRec > 4
      SET @cSummary = '1/' + CAST( CEILING( @nNoOfRec/CONVERT( DECIMAL( 4, 2), 4)) AS NVARCHAR( 4))
   ELSE
      SET @cSummary = '1/1'
END
ELSE
BEGIN
   IF @cFilterLocType = 'FASTPICK'
   BEGIN
      GOTO Quit
   END
   ELSE
   BEGIN
      SET @cPage = CAST( LEFT( @cSummary, CHARINDEX( '/', @cSummary) - 1) AS INT) + 1
      SET @cSummary = @cPage + '/' + CAST( CEILING( @nNoOfRec/CONVERT( DECIMAL( 4, 2), 4)) AS NVARCHAR( 4))
   END
END

IF ISNULL( @cInquiry_LOC, '') <> ''
BEGIN
   SET @cNextLOC = @cInquiry_LOC

   SELECT @nNoOfRec = COUNT( DISTINCT LLI.SKU)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   ( LLI.QTY + LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
   AND   LOC.Facility = @cFacility
   AND   LOC.LOC = @cInquiry_LOC
   
   SET @nLoop = 1
   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LLI.SKU, SUM( LLI.QTY - LLI.QTYPICKED), SUM( LLI.QTYALLOCATED), SUM( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   JOIN dbo.SKUxLOC SL WITH (NOLOCK) ON (LLI.LOC = SL.LOC AND LLI.SKU = SL.SKU)
   WHERE LLI.StorerKey = @cStorerKey
   AND   ( LLI.QTY + LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
   AND   LLI.SKU > @cNextSKU
   AND   LOC.Facility = @cFacility
   AND   LOC.LOC = @cInquiry_LOC
   GROUP BY LLI.SKU, SL.LOCATIONTYPE
   ORDER BY LLI.SKU, SL.LOCATIONTYPE
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLLI_SKU, @nLLI_Qty, @nLLI_Alc, @nLLI_Avl
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @cNextSKU = @cLLI_SKU

      IF @nLoop = 1
      BEGIN
         SET @cDisplay01 = @cLLI_SKU
         SET @cDisplay02 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + 
                           LEFT( CAST( @nLLI_Alc AS NVARCHAR( 4)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 4)) + SPACE( 4), 4)
      END

      IF @nLoop = 2
      BEGIN
         SET @cDisplay03 = @cLLI_SKU
         SET @cDisplay04 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + 
                           LEFT( CAST( @nLLI_Alc AS NVARCHAR( 4)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 4)) + SPACE( 4), 4)
      END

      IF @nLoop = 3
      BEGIN
         SET @cDisplay05 = @cLLI_SKU
         SET @cDisplay06 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + 
                           LEFT( CAST( @nLLI_Alc AS NVARCHAR( 4)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 4)) + SPACE( 4), 4)
      END

      IF @nLoop = 4
      BEGIN
         SET @cDisplay07 = @cLLI_SKU
         SET @cDisplay08 = SPACE( 6) + LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 5), 5) + ' ' + 
                           LEFT( CAST( @nLLI_Alc AS NVARCHAR( 4)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 4)) + SPACE( 4), 4)
      END

      SET @nLoop = @nLoop + 1

      IF @nLoop = 5
         BREAK

      FETCH NEXT FROM CUR_LOOP INTO @cLLI_SKU, @nLLI_Qty, @nLLI_Alc, @nLLI_Avl
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
      
   IF @cFilterLocType = ''
   BEGIN
      SELECT TOP 1 @cLocType = SL.LocationType
      FROM dbo.SKUxLOC SL WITH (NOLOCK)
      JOIN dbo.LOTxLOCxID LLI WITH (NOLOCK) ON ( SL.SKU = LLI.SKU AND SL.SKU = LLI.SKU)
      JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
      WHERE LLI.StorerKey = @cStorerKey
      AND   LLI.SKU = @cInquiry_SKU
      AND   ( LLI.QTY + LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
      AND   LOC.Facility = @cFacility
      ORDER BY SL.LocationType DESC

      IF ISNULL( @cLocType, '') = ''
         SET @cLocType = 'UNASSIGNED'
   END
   ELSE
      SET @cLocType = @cFilterLocType

   SET @nLoop = 1
   DECLARE CUR_LOOP CURSOR LOCAL READ_ONLY FAST_FORWARD FOR 
   SELECT LLI.LOC, SUM( LLI.QTY - LLI.QTYPICKED), SUM( LLI.QTYALLOCATED), SUM( LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED)
   FROM dbo.LOTxLOCxID LLI WITH (NOLOCK) 
   JOIN dbo.LOC WITH (NOLOCK) ON (LLI.LOC = LOC.LOC)
   WHERE LLI.StorerKey = @cStorerKey
   AND   LLI.SKU = @cInquiry_SKU
   AND   ( LLI.QTY + LLI.QTYALLOCATED - LLI.QTYPICKED) > 0
   AND   LOC.Facility = @cFacility
   AND   LOC.LOC > @cNextLOC
   AND   (( @cFilterLocType = '') OR ( LOC.LocationType = @cFilterLocType))
   GROUP BY LLI.LOC
   ORDER BY LLI.LOC
   OPEN CUR_LOOP
   FETCH NEXT FROM CUR_LOOP INTO @cLLI_LOC, @nLLI_Qty, @nLLI_Alc, @nLLI_Avl
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @cNextLOC = @cLLI_LOC

      IF @nLoop = 1
         SET @cDisplay01 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + ' ' +
                           LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 5)) + SPACE( 4), 4) 

      IF @nLoop = 2
         SET @cDisplay02 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + ' ' +
                           LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 5)) + SPACE( 4), 4) 

      IF @nLoop = 3
         SET @cDisplay03 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + ' ' +
                           LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 5)) + SPACE( 4), 4) 

      IF @nLoop = 4
         SET @cDisplay04 = LEFT( CAST( @cLLI_LOC AS NVARCHAR( 10)) + SPACE( 10), 10) + ' ' +
                           LEFT( CAST( @nLLI_Qty AS NVARCHAR( 5)) + SPACE( 4), 4) + ' ' +
                           LEFT( CAST( @nLLI_Avl AS NVARCHAR( 5)) + SPACE( 4), 4) 

      SET @nLoop = @nLoop + 1
      
      IF @nLoop = 5 OR @cFilterLocType = 'FASTPICK'
         BREAK

      FETCH NEXT FROM CUR_LOOP INTO @cLLI_LOC, @nLLI_Qty, @nLLI_Alc, @nLLI_Avl
   END
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
   
   SET @cDisplay05 = 'LOC        QTY  AVL'
END

Quit:

SET QUOTED_IDENTIFIER OFF

GO