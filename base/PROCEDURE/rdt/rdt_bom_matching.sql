SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_BOM_Matching                                       */
/* Copyright      : IDS                                                    */
/*                                                                         */
/* Purposes:                                                               */
/* 1) To Match scanned ComponentSKU against BOM table                      */
/*                                                                         */
/* Called from: rdtfnc_BOMCreation                                         */
/*                                                                         */
/* Exceed version: 5.4                                                     */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author      Purposes                                   */
/* 07-Aug-2007 1.0  Vicky       Created                                    */
/* 24-Sep-2007 1.1  Vicky       Parse in Style coz Style not always 15     */
/*                              chars                                      */
/* 03-Jun-2009 1.2  Vicky       Add Username when filter rdtBOMCreationLog */ 
/*                              (Vicky01)                                  */
/* 09-Jul-2009 1.3  Vicky       SOS#140937 - Check ParentSKU matching if   */
/*                              ParentSKU being entered in Screen 1        */
/*                              (Vicky02)                                  */
/***************************************************************************/

CREATE PROC [RDT].[rdt_BOM_Matching] (
   @cStorerkey      NVARCHAR(15),
   @cParentSKU      NVARCHAR(18), -- first 15 chars
   @cStyle          NVARCHAR(20),
   @nMobile         INT,
   @cUsername       NVARCHAR(18), -- (Vicky01)
   @cMatchSKU       NVARCHAR(20)   OUTPUT,
   @cResult         NVARCHAR(1)    OUTPUT,
   @cParentExt      NVARCHAR(1) = '0' -- (Vicky02)
) AS
BEGIN
   
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF

   DECLARE @n_debug INT   
   
   DECLARE @cComponentSKU NVARCHAR(20),
           @cBOMSKU       NVARCHAR(20),
           @cMatchFlag    NVARCHAR(1)
 
   DECLARE @nSKUQty    INT,
           @nMatchCnt  INT,
           @nSKUCnt    INT,
           @nWeighting INT

   SET @n_debug = 0
   SET @nSKUCnt = 0
   SET @nSKUQty = 0
   SET @nMatchCnt = 0
   SET @nWeighting = 0
   SET @cMatchFlag = 'N'
   SET @cResult = '0'

   SELECT @nSKUCnt = COUNT(ComponentSKU),
          @nWeighting = SUM(Qty) * COUNT(ComponentSKU)
   FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
   WHERE Storerkey = @cStorerkey
   AND   ParentSKU = RTRIM(@cParentSKU)
   AND   Status = '0'
   AND   MobileNo = @nMobile
   AND   Username = @cUsername -- (Vicky01)

--   print 'vicky1'
--   select '@nSKUCnt', @nSKUCnt
--   select '@nWeighting', @nWeighting

  IF @cParentExt <> '1' -- (Vicky05)
  BEGIN
   DECLARE C_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	       SELECT RTRIM(BOM.SKU)
          FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
          JOIN dbo.SKU SKU WITH (NOLOCK) 
           ON (SKU.Storerkey = BOM.Storerkey AND SKU.SKU = BOM.SKU)
          WHERE BOM.Storerkey = @cStorerkey
          AND   SKU.Style = @cStyle--LEFT(RTRIM(@cParentSKU), 15)
          GROUP BY BOM.SKU
          HAVING COUNT(BOM.ComponentSKU) = @nSKUCnt AND
                 SUM(BOM.Qty) * COUNT(BOM.ComponentSKU) = @nWeighting
 END
 ELSE
 BEGIN
   DECLARE C_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	       SELECT RTRIM(BOM.SKU)
          FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
          JOIN dbo.SKU SKU WITH (NOLOCK) 
           ON (SKU.Storerkey = BOM.Storerkey AND SKU.SKU = BOM.SKU)
          WHERE BOM.Storerkey = @cStorerkey
          AND   SKU.Style = @cStyle
          AND   BOM.SKU = @cParentSKU
          GROUP BY BOM.SKU
          HAVING COUNT(BOM.ComponentSKU) = @nSKUCnt AND
                 SUM(BOM.Qty) * COUNT(BOM.ComponentSKU) = @nWeighting
 END
 
	OPEN C_BOM
	
	FETCH NEXT FROM C_BOM INTO @cBOMSKU
	
	WHILE @@FETCH_STATUS <> -1 
	BEGIN

      SET @nMatchCnt = 0  

--      select '@cBOMSKU', @cBOMSKU

      DECLARE C_CSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   SELECT RTRIM(ComponentSKU), QTY
		   FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
		   WHERE Storerkey = @cStorerkey
		   AND   ParentSKU = RTRIM(@cParentSKU)
		   AND   Status = '0'
		   AND   MobileNo = @nMobile
         AND   Username = @cUsername -- (Vicky01)
	   
		OPEN C_CSKU
		
		FETCH NEXT FROM C_CSKU INTO @cComponentSKU, @nSKUQty
		
		WHILE @@FETCH_STATUS <> -1 
		BEGIN

--           select '@cComponentSKU', @cComponentSKU
--           select '@nSKUQty', @nSKUQty 

          IF EXISTS (SELECT 1 FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
                     WHERE BOM.Storerkey = @cStorerkey
                     AND   BOM.SKU = @cBOMSKU
                     AND   BOM.ComponentSKU = @cComponentSKU
                     AND   BOM.QTY = @nSKUQty)
          BEGIN
              SELECT @cMatchFlag = 'Y'
              SET @nMatchCnt = @nMatchCnt + 1

--              select '@nMatchCnt' ,@nMatchCnt
          END
          ELSE
          BEGIN
              SELECT @cMatchFlag = 'N'
              GOTO NEXT_REC
--               select '@cMatchFlag', @cMatchFlag
-- 	           select '@cBOMSKU', @cBOMSKU
          END
          
          IF @cMatchFlag = 'N'
          GOTO NEXT_BOM
	       
          NEXT_REC:
      	 FETCH NEXT FROM C_CSKU INTO @cComponentSKU, @nSKUQty
      NEXT_BOM:  
		END
		CLOSE C_CSKU
		DEALLOCATE C_CSKU
 
      IF @nMatchCnt = @nSKUCnt
      BEGIN
        SET @cResult = '1'
        SELECT @cMatchSKU = @cBOMSKU 
        GOTO Match_Found
      END

	 FETCH NEXT FROM C_BOM INTO @cBOMSKU

   Match_Found:
	END
	CLOSE C_BOM
	DEALLOCATE C_BOM

   IF @n_debug = 1
   BEGIN
     Print @cResult 
     Print @cMatchSKU
   END

END


SET QUOTED_IDENTIFIER OFF 


GO