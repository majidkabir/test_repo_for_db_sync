SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry21                                       */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-02-22 1.0  yeekung    WMS-23380 Created                            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_727Inquiry21] (
 	@nMobile      INT,  
   @nFunc        INT,  
   @nStep        INT,  
   @cLangCode    NVARCHAR(3),  
   @cStorerKey   NVARCHAR(15),  
   @cOption      NVARCHAR(1),  
   @cParam1      NVARCHAR(20),  
   @cParam2      NVARCHAR(20),  
   @cParam3      NVARCHAR(20),  
   @cParam4      NVARCHAR(20),  
   @cParam5      NVARCHAR(20),  
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

   DECLARE @cFloor NVARCHAR(20)
   DECLARE @CSKU NVARCHAR(20)
   DECLARE @cLottable12 NVARCHAR(20)
   DECLARE @nOption NVARCHAR(1)
   DECLARE @cID     NVARCHAR(20)
   DECLARE @cLOC     NVARCHAR(20)
   DECLARE @nTTlQTY     INT
   DECLARE @nAvailStock    INT
   DECLARE @nCountID    INT
   DECLARE @cCurLoc CURSOR
   DECLARE @cCurLottable12 CURSOR
   DECLARE @nCounter INT = 0
   DECLARE @cPreviousID NVARCHAR(20)
   DECLARE @cPreviousLoc NVARCHAR(10)
   DECLARE @cNewLottable12 NVARCHAR(20) = ''
   DECLARE @nStockQTY  INT
   DECLARE @nTotalQty INT

   IF @nFunc = 727 -- General inquiry
   BEGIN
      IF @nStep = 2 -- Inquiry sub module
      BEGIN
         SET @c_oFieled01  = ''
         SET @c_oFieled02  = ''
         SET @c_oFieled03  = ''
         SET @c_oFieled04  = ''
         SET @c_oFieled05  = ''
         SET @c_oFieled06  = ''
         SET @c_oFieled07  = ''
         SET @c_oFieled08  = ''
         SET @c_oFieled09  = ''
         SET @c_oFieled10  = ''
         SET @c_oFieled11  = ''
         SET @c_oFieled12  = ''

         -- Parameter mapping
         SET @CSKU = @cParam1
         SET @cFloor = @cParam2
         SET @cLottable12 = @cParam3
         
         -- Check blank
         IF @CSKU = '' 
         BEGIN
            SET @nErrNo = -203701
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
            GOTO QUIT
         END

         IF NOT EXISTS (SELECT 1 FROM SKU (nolock)
               where sku= @CSKU
               AND storerkey=@cStorerkey)
         BEGIN
            SET @nErrNo = 203702
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU
            EXEC rdt.rdtSetFocusField @nMobile, 2 -- SKU
            GOTO QUIT
         END


         -- Check blank
         IF @cFloor = '' 
         BEGIN
            SET @nErrNo = -1
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
            GOTO QUIT
         END

         IF NOT EXISTS (SELECT 1 FROM codelkup (nolock)
               WHERE code= @cFloor
               AND Listname ='LOCWH'
               AND storerkey=@cStorerkey)
         BEGIN
            SET @nErrNo = 203703
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidFloor
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
            GOTO QUIT
         END
         
         ---- Check blank
         --IF @cLottable12 = '' 
         --BEGIN
         --   SET @nErrNo = -1
         --   EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
         --   GOTO QUIT
         --END

         IF ISNULL(@cLottable12,'') <> '' 
         BEGIN
            IF NOT EXISTS (SELECT 1 FROM codelkup (nolock)
                  WHERE code= @cLottable12
                  AND Listname ='LOT12WH'
                  AND storerkey=@cStorerkey)
            BEGIN
               SET @nErrNo = 203703
               SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU
               EXEC rdt.rdtSetFocusField @nMobile, 6 -- SKU
               GOTO QUIT
            END
         END

         SET @cCurLoc = CURSOR FOR
         SELECT  LLI.loc,
               LLI.ID
               ,SKU.Size- SUM(QTY-QtyPicked)
               ,LOT.Lottable12
         FROM LOTXLOCXID LLI (NOLOCK)
         JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
         JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
         JOIN SKU SKU (NOLOCK) ON LLI.storerkey=SKU.storerkey AND LLI.SKU=SKU.SKU
         WHERE LLI.storerkey=@cStorerkey
            AND LLI.SKU=@cSKU
            AND LOT.Lottable12 = CASE WHEN ISNULL(@cLottable12,'') ='' THEN LOT.Lottable12 ELSE @cLottable12 END
            AND LOC.Floor = @cFloor
         GROUP by LLI.loc,LLI.ID,LOC.MaxPallet,SKU.Height,LOT.Lottable12,SKU.Size
         HAVING  SUM (LLI.QTY  -LLI.QtyPicked) >0
            AND   SKU.Size- SUM(QTY-QtyPicked) > 0
         ORDER BY LLI.LOC,LLI.ID

         OPEN @cCurLoc
         FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@nCountID,@cNewLottable12
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nCounter >=2
            BEGIN
               SET @nNextPage = -1
               BREAK;
            END

            SELECT @nStockQTY = SUM (LLI.QTY  -LLI.QtyPicked) 
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LOT.Lottable12 = @cNewLottable12
               AND LOC.Floor = @cFloor
               AND LLI.ID = @cID
               AND LOC.LOC = @cLOC

            
            SELECT @nTotalQty =  SUM (LLI.QTY  -LLI.QtyPicked) 
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LOC.Floor = @cFloor
               AND LLI.ID = @cID
               AND LOC.LOC = @cLOC

            IF @nCounter = 0
            BEGIN
               SET @c_oFieled01 = @cLOC
               SET @c_oFieled02 = @cID
               SET @c_oFieled03 = @cNewLottable12
               SET @c_oFieled04 = 'QTY: ' + CAST(@nStockQTY AS NVARCHAR(3)) +'/' + CAST(@nTotalQty AS NVARCHAR(3)) + ' AV:' + CAST(@nCountID AS NVARCHAR(3))

            END

            ELSE IF @nCounter = 1
            BEGIN
               SET @c_oFieled06 = @cLOC
               SET @c_oFieled07 = @cID
               SET @c_oFieled08 = @cNewLottable12
               SET @c_oFieled09 = 'QTY: ' + CAST(@nStockQTY AS NVARCHAR(3)) +'/' + CAST(@nTotalQty AS NVARCHAR(3)) + ' AV:' + CAST(@nCountID AS NVARCHAR(3))
            END

            SET @c_oFieled05 = '****************************'

            SET @nCounter= @nCounter+1
               
            FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@nCountID,@cNewLottable12  
         END


      END
      IF @nStep = 3 -- Inquiry sub module
      BEGIN
         SET @nNextPage = 0 
         -- Parameter mapping
         SET @CSKU = @cParam1
         SET @cFloor = @cParam2
         SET @cLottable12 = @cParam3

         SET @cPreviousID = @c_oFieled07
         SET @cPreviousLOC = @c_oFieled06

         IF ISNULL(@cPreviousID,'') =''
         BEGIN
            SET @cPreviousID = @c_oFieled02
            SET @cPreviousLOC = @c_oFieled01
         END

         SET @c_oFieled01  = ''
         SET @c_oFieled02  = ''
         SET @c_oFieled03  = ''
         SET @c_oFieled04  = ''
         SET @c_oFieled05  = ''
         SET @c_oFieled06  = ''
         SET @c_oFieled07  = ''
         SET @c_oFieled08  = ''
         SET @c_oFieled09  = ''
         SET @c_oFieled10  = ''
         SET @c_oFieled11  = ''
         SET @c_oFieled12  = ''

         
         IF EXISTS ( SELECT   1
                     FROM LOTXLOCXID LLI (NOLOCK)
                     JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
                     JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
                     JOIN SKU SKU (NOLOCK) ON LLI.storerkey=SKU.storerkey AND LLI.SKU=SKU.SKU
                     WHERE LLI.storerkey=@cStorerkey
                        AND LLI.SKU=@cSKU
                        AND LOT.Lottable12 = CASE WHEN ISNULL(@cLottable12,'') ='' THEN LOT.Lottable12 ELSE @cLottable12 END
                        AND LOC.Floor = @cFloor
                        AND (LLI.LOC = @cPreviousLoc AND LLI.id > @cPreviousID)  
                     GROUP by LLI.loc,LLI.ID,LOC.MaxPallet,SKU.Height,LOT.Lottable12,SKU.Size
                     HAVING  SUM (LLI.QTY  -LLI.QtyPicked) >0
                        AND   SKU.Size- SUM(QTY-QtyPicked) > 0)
         BEGIN
            SET @cCurLoc = CURSOR FOR
            SELECT  LLI.loc,
                  LLI.ID
                  ,SKU.Size- SUM(QTY-QtyPicked)
                  ,LOT.Lottable12
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            JOIN SKU SKU (NOLOCK) ON LLI.storerkey=SKU.storerkey AND LLI.SKU=SKU.SKU
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LOT.Lottable12 = CASE WHEN ISNULL(@cLottable12,'') ='' THEN LOT.Lottable12 ELSE @cLottable12 END
               AND LOC.Floor = @cFloor
               AND (LLI.LOC = @cPreviousLoc AND LLI.id > @cPreviousID)  
            GROUP by LLI.loc,LLI.ID,LOC.MaxPallet,SKU.Height,LOT.Lottable12,SKU.Size
            HAVING  SUM (LLI.QTY  -LLI.QtyPicked) >0
               AND   SKU.Size- SUM(QTY-QtyPicked) > 0
            ORDER BY LLI.LOC,LLI.ID
         END
         ELSE
         BEGIN
            SET @cCurLoc = CURSOR FOR
            SELECT  LLI.loc,
                  LLI.ID
                  ,SKU.Size- SUM(QTY-QtyPicked)
                  ,LOT.Lottable12
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            JOIN SKU SKU (NOLOCK) ON LLI.storerkey=SKU.storerkey AND LLI.SKU=SKU.SKU
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LOT.Lottable12 = CASE WHEN ISNULL(@cLottable12,'') ='' THEN LOT.Lottable12 ELSE @cLottable12 END
               AND LOC.Floor = @cFloor
               AND (LLI.LOC > @cPreviousLoc )  
            GROUP by LLI.loc,LLI.ID,LOC.MaxPallet,SKU.Height,LOT.Lottable12,SKU.Size
            HAVING  SUM (LLI.QTY  -LLI.QtyPicked) >0
               AND   SKU.Size- SUM(QTY-QtyPicked) > 0
            ORDER BY LLI.LOC,LLI.ID
         END

         OPEN @cCurLoc
         FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@nCountID,@cNewLottable12  
         WHILE @@FETCH_STATUS = 0
         BEGIN
            IF @nCounter >=2
            BEGIN
               SET @nNextPage = -1
               BREAK;
            END

            SELECT @nStockQTY = SUM (LLI.QTY  -LLI.QtyPicked) 
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LOT.Lottable12 = @cNewLottable12
               AND LOC.Floor = @cFloor
               AND LLI.ID = @cID
               AND LOC.LOC = @cLOC

            
            SELECT @nTotalQty = SUM (LLI.QTY  -LLI.QtyPicked) 
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LOC.Floor = @cFloor
               AND LLI.ID = @cID
               AND LOC.LOC = @cLOC

            IF @nCounter = 0
            BEGIN
               SET @c_oFieled01 = @cLOC
               SET @c_oFieled02 = @cID
               SET @c_oFieled03 = @cNewLottable12
               SET @c_oFieled04 = 'QTY: ' + CAST(@nStockQTY AS NVARCHAR(3)) +'/' + CAST(@nTotalQty AS NVARCHAR(3)) + ' AV:' + CAST(@nCountID AS NVARCHAR(3))

            END

            ELSE IF @nCounter = 1
            BEGIN
               SET @c_oFieled06 = @cLOC
               SET @c_oFieled07 = @cID
               SET @c_oFieled08 = @cNewLottable12
               SET @c_oFieled09 = 'QTY: ' + CAST(@nStockQTY AS NVARCHAR(3)) +'/' + CAST(@nTotalQty AS NVARCHAR(3)) + ' AV:' + CAST(@nCountID AS NVARCHAR(3))
            END

            SET @c_oFieled05 = '****************************'

            SET @nCounter= @nCounter+1
               
            FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@nCountID,@cNewLottable12   
         END


         IF @nCounter <>0
           SET @nNextPage = -1


      END
   END

Quit:

END

GO