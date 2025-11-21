SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_727Inquiry19                                       */
/* Copyright      : LF Logistics                                           */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date       Rev  Author     Purposes                                     */
/* 2022-02-22 1.0  yeekung    WMS-21626 Created                            */
/* 2022-02-22 1.1  yeekung    WMS-23380 remove byid (yeekung01)            */
/***************************************************************************/

CREATE   PROC [RDT].[rdt_727Inquiry19] (
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

         -- Check blank
         IF @CSKU = '' 
         BEGIN
            SET @nErrNo = -1
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
            GOTO QUIT
         END

         IF NOT EXISTS (SELECT 1 FROM SKU (nolock)
               where sku= @CSKU
               AND storerkey=@cStorerkey)
         BEGIN
            SET @nErrNo = 196803
            SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --InvalidSKU
            EXEC rdt.rdtSetFocusField @nMobile, 4 -- SKU
            GOTO QUIT
         END

         -- Check blank
         IF @nOption = '' 
         BEGIN
            SET @nErrNo = -1
            EXEC rdt.rdtSetFocusField @nMobile, 8 -- SKU
            GOTO QUIT
         END

         SET @cCurLoc = CURSOR FOR
         SELECT   LLI.loc,
                  LLI.ID,
                  LLI.SKU,
                  SUM (LLI.QTY - LLI.qtypicked ),
                  SKU.Size - SUM (LLI.QTY - LLI.qtypicked) 
         FROM LOTXLOCXID LLI (NOLOCK)
         JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
         JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
         JOIN SKU SKU (NOLOCK) ON LLI.storerkey=SKU.storerkey AND LLI.SKU=SKU.SKU
         WHERE LLI.storerkey=@cStorerkey
            AND LLI.SKU=@cSKU
         GROUP by LLI.id,LLI.loc,LLI.SKU,SKU.Size
         HAVING  SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen  ) >0
            AND SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen) < CAST (SKU.Size AS INT)
         ORDER BY LLI.LOC

         OPEN @cCurLoc
         FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@CSKU,@nTTlQTY,@nAvailStock
         WHILE @@FETCH_STATUS = 0
         BEGIN
            SET @cCurLottable12 = CURSOR FOR
            SELECT DISTINCT LOT.Lottable12
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LLI.ID = @cID
               AND LLI.Loc = @cLOC
            OPEN @cCurLottable12
            FETCH NEXT FROM @cCurLottable12 INTO @cLottable12
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF ISNULL(@cNewLottable12,'') = ''
               BEGIN
                  SET @cNewLottable12 = @cLottable12
               END
               ELSE
               BEGIN
                  SET @cNewLottable12 = @cNewLottable12 +',' + @cLottable12
               END
               FETCH NEXT FROM @cCurLottable12 INTO @cLottable12
            END 
            IF @nCounter >=2
            BEGIN
               SET @nNextPage = -1
               BREAK;
            END
            IF @nCounter = 0
            BEGIN
               SET @c_oFieled01 = @cLOC
               SET @c_oFieled02 = @cID
               SET @c_oFieled03 = @CSKU
               SET @c_oFieled04 = @cNewLottable12
               SET @c_oFieled05 = 'TotQTY:' + CAST(@nTTlQTY AS NVARCHAR(5)) + ' '+ 'AvaiStk:' + CAST(@nAvailStock AS NVARCHAR(5))
            END
            ELSE IF @nCounter = 1
            BEGIN
               SET @c_oFieled07 = @cLOC
               SET @c_oFieled08 = @cID
               SET @c_oFieled09 = @CSKU
               SET @c_oFieled10 = @cNewLottable12
               SET @c_oFieled12 = 'TotQTY:' + CAST(@nTTlQTY AS NVARCHAR(5)) + ' '+ 'AvaiStk:' + CAST(@nAvailStock AS NVARCHAR(5))
            END
            SET @c_oFieled06 = '****************************'

            SET @nCounter= @nCounter+1
            SET @cNewLottable12 = ' '

            FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@CSKU,@nTTlQTY,@nAvailStock
         END
                 

      END
      IF @nStep = 3 -- Inquiry sub module
      BEGIN
         SET @nNextPage = 0 
         -- Parameter mapping
         SET @CSKU = @cParam1

         SET @cPreviousID = @c_oFieled08
         SET @cPreviousLOC = @c_oFieled07

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
                        AND (LLI.LOC = @cPreviousLoc AND LLI.id > @cPreviousID)
                     GROUP by LLI.id,LLI.loc,LLI.SKU,SKU.Size,LOT.Lottable12
                     HAVING  SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen  ) >0
                        AND SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen) < CAST (SKU.Size AS INT))
         BEGIN
            SET @cCurLoc = CURSOR FOR
            SELECT   LLI.loc,
                     LLI.ID,
                     LLI.SKU,
                     SUM (LLI.QTY - LLI.qtypicked ),
                     SKU.Size - SUM (LLI.QTY - LLI.qtypicked) 
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            JOIN SKU SKU (NOLOCK) ON LLI.storerkey=SKU.storerkey AND LLI.SKU=SKU.SKU
            WHERE LLI.storerkey=@cStorerkey
                        AND LLI.SKU=@cSKU
                        AND (LLI.LOC = @cPreviousLoc AND LLI.id > @cPreviousID)
            GROUP by LLI.id,LLI.loc,LLI.SKU,SKU.Size
            HAVING  SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen  ) >0
               AND SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen) < CAST (SKU.Size AS INT)
            ORDER BY LLI.LOC
         END
         ELSE
         BEGIN
            SET @cCurLoc = CURSOR FOR
            SELECT   LLI.loc,
                     LLI.ID,
                     LLI.SKU,
                     SUM (LLI.QTY - LLI.qtypicked ),
                     SKU.Size - SUM (LLI.QTY - LLI.qtypicked) 
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            JOIN LOC LOC (NOLOCK) ON LLI.LOC =LOC.LOC 
            JOIN SKU SKU (NOLOCK) ON LLI.storerkey=SKU.storerkey AND LLI.SKU=SKU.SKU
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND (LLI.LOC > @cPreviousLoc)
            GROUP by LLI.id,LLI.loc,LLI.SKU,SKU.Size
            HAVING  SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen  ) >0
            AND SUM (LLI.QTY - LLI.QtyPicked -LLI.qtyexpected-LLI.qtyreplen) < SUM( CAST (SKU.Size AS INT))
            ORDER BY LLI.LOC
         END


         OPEN @cCurLoc
         FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@CSKU,@nTTlQTY,@nAvailStock
         WHILE @@FETCH_STATUS = 0
         BEGIN

            SET @cCurLottable12 = CURSOR FOR
            SELECT DISTINCT LOT.Lottable12
            FROM LOTXLOCXID LLI (NOLOCK)
            JOIN lotattribute LOT (NOLOCK) ON LLI.lot=LOT.lot AND LLI.Storerkey=LOT.storerkey
            WHERE LLI.storerkey=@cStorerkey
               AND LLI.SKU=@cSKU
               AND LLI.ID = @cID
               AND LLI.Loc = @cLOC
            OPEN @cCurLottable12
            FETCH NEXT FROM @cCurLottable12 INTO @cLottable12
            WHILE @@FETCH_STATUS = 0
            BEGIN
               IF ISNULL(@cNewLottable12,'') = ''
               BEGIN
                  SET @cNewLottable12 = @cLottable12
               END
               ELSE
               BEGIN
                  SET @cNewLottable12 = @cNewLottable12 +',' + @cLottable12
               END
               FETCH NEXT FROM @cCurLottable12 INTO @cLottable12
            END 
               
            IF @nCounter >=2
            BEGIN
               SET @nNextPage = -1
               BREAK;
            END
            IF @nCounter = 0
            BEGIN
               SET @c_oFieled01 = @cLOC
               SET @c_oFieled02 = @cID
               SET @c_oFieled03 = @CSKU
               SET @c_oFieled04 = @cNewLottable12
               SET @c_oFieled05 = 'TotQTY:' + CAST(@nTTlQTY AS NVARCHAR(5)) + ' '+ 'AvaiStk:' + CAST(@nAvailStock AS NVARCHAR(5))
            END
            ELSE IF @nCounter = 1
            BEGIN
               SET @c_oFieled07 = @cLOC
               SET @c_oFieled08 = @cID
               SET @c_oFieled09 = @CSKU
               SET @c_oFieled10 = @cNewLottable12
               SET @c_oFieled12 = 'TotQTY:' + CAST(@nTTlQTY AS NVARCHAR(5)) + ' '+ 'AvaiStk:' + CAST(@nAvailStock AS NVARCHAR(5))
            END

            SET @c_oFieled06 = '****************************'

            SET @nCounter= @nCounter+1
            SET @cNewLottable12  = ''

            FETCH NEXT FROM @cCurLoc INTO @cLOC,@cID,@CSKU,@nTTlQTY,@nAvailStock
         END
                  

         IF @nCounter <>0
           SET @nNextPage = -1


      END
   END

Quit:

END

GO