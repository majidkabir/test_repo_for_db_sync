SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Store procedure: rdt_BOM_Packkey_Matching                               */
/* Copyright      : IDS                                                    */
/*                                                                         */
/* Purposes:                                                               */
/* 1) To Match the Packkey of the Matched BOM                              */
/*                                                                         */
/* Called from: rdtfnc_BOMCreation                                         */
/*                                                                         */
/* Exceed version: 5.4                                                     */
/*                                                                         */
/* Modifications log:                                                      */
/*                                                                         */
/* Date        Rev  Author      Purposes                                   */
/* 07-Aug-2007 1.0  Vicky       Created                                    */
/* 20-Nov-2007 1.1  Vicky       Display MatchSKU as an Output              */ 
/*                              This is to make sure that exact match      */
/*                              ParentSKU is being parse correctly         */
/* 08-Dec-2008 1.2  Ricky       To display the correct UPC Sku             */ 
/*                              based on the BOMSKU provided               */
/* 03-Jun-2009 1.3  Vicky       Add Username when filter rdtBOMCreationLog */ 
/*                              Add Status = 5 filtering                   */
/*                              (Vicky01)                                  */
/* 09-Jul-2009 1.4  Vicky       SOS#140937 - Check ParentSKU matching if   */
/*                              ParentSKU being entered in Screen 1        */
/*                              (Vicky02)                                  */
/***************************************************************************/

CREATE PROC [RDT].[rdt_BOM_Packkey_Matching] (
   @cStorerkey      NVARCHAR(15),
   @cParentSKU      NVARCHAR(18), -- first 15 chars
   @cStyle          NVARCHAR(20),
   @nMobile         INT,
   @cUsername       NVARCHAR(18), -- (Vicky01)
   @nInnerPack      INT,
   @nCaseCnt        INT,
   @nShipper        INT,
   @nPallet         INT,
   @nMatchFound     INT        OUTPUT,
   @cMatchSKU       NVARCHAR(20)   OUTPUT,
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

   DECLARE @nCnt INT

   SET @n_debug = 0
   SET @nSKUCnt = 0
   SET @nSKUQty = 0
   SET @nMatchCnt = 0
   SET @nWeighting = 0
   SET @cMatchFlag = 'N'
   SET @nCnt = 0

   CREATE TABLE #TEMPPACK (BOMSKU NVARCHAR(20) NULL, Storerkey NVARCHAR(15))

   SELECT @nSKUCnt = COUNT(ComponentSKU),
          @nWeighting = SUM(Qty) * COUNT(ComponentSKU)
   FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
   WHERE Storerkey = @cStorerkey
   AND   ParentSKU = RTRIM(@cParentSKU)
   AND   Status = '0'
   AND   MobileNo = @nMobile
   AND   Username = @cUsername -- (Vicky01)

   IF @nSKUCnt = 0 AND @nWeighting = 0
   BEGIN
       SELECT @nSKUCnt = COUNT(ComponentSKU),
              @nWeighting = SUM(Qty) * COUNT(ComponentSKU)
       FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
       WHERE Storerkey = @cStorerkey
       AND   ParentSKU = RTRIM(@cParentSKU)
       AND   Status = '5'
       AND   MobileNo = @nMobile
       AND   Username = @cUsername -- (Vicky01)
   END
-- 
--    print 'vicky1'
--    select '@nSKUCnt', @nSKUCnt
--    select '@nWeighting', @nWeighting

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
    IF EXISTS (SELECT 1 FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
               WHERE Storerkey = @cStorerkey
               AND   ParentSKU = RTRIM(@cParentSKU)
               AND   Status = '0'
               AND   MobileNo = @nMobile
               AND   Username = @cUsername)
    BEGIN
      DECLARE C_CSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   SELECT RTRIM(ComponentSKU), QTY
		   FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
		   WHERE Storerkey = @cStorerkey
		   AND   ParentSKU = RTRIM(@cParentSKU)
		   AND   Status = '0'
		   AND   MobileNo = @nMobile
         AND   Username = @cUsername
    END 
    ELSE IF EXISTS (SELECT 1 FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
                    WHERE Storerkey = @cStorerkey
                    AND   ParentSKU = RTRIM(@cParentSKU)
                    AND   Status = '5'
                    AND   MobileNo = @nMobile
                    AND   Username = @cUsername)
    BEGIN
      DECLARE C_CSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		   SELECT RTRIM(ComponentSKU), QTY
		   FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)
		   WHERE Storerkey = @cStorerkey
		   AND   ParentSKU = RTRIM(@cParentSKU)
		   AND   Status = '5'
		   AND   MobileNo = @nMobile
         AND   Username = @cUsername
    END  
	   
		OPEN C_CSKU
		
		FETCH NEXT FROM C_CSKU INTO @cComponentSKU, @nSKUQty
		
		WHILE @@FETCH_STATUS <> -1 
		BEGIN
-- 
--            select '@cComponentSKU', @cComponentSKU
--            select '@nSKUQty', @nSKUQty 

          IF EXISTS (SELECT 1 FROM dbo.BillOfMaterial BOM WITH (NOLOCK)
                     WHERE BOM.Storerkey = @cStorerkey
                     AND   BOM.SKU = @cBOMSKU
                     AND   BOM.ComponentSKU = @cComponentSKU
                     AND   BOM.QTY = @nSKUQty)
          BEGIN
--              SELECT @cMatchFlag = 'Y'
              SET @nMatchCnt = 1

--              select '@nMatchCnt' ,@nMatchCnt
          END
          ELSE
          BEGIN
              SET @nMatchCnt = 0
              GOTO NEXT_REC
--               select '@cMatchFlag', @cMatchFlag
-- 	           select '@cBOMSKU', @cBOMSKU
          END
          
          IF @nMatchCnt = 0
          GOTO NEXT_BOM
	       
          NEXT_REC:
      	 FETCH NEXT FROM C_CSKU INTO @cComponentSKU, @nSKUQty
      NEXT_BOM:  
		END
		CLOSE C_CSKU
		DEALLOCATE C_CSKU
 
      IF @nMatchCnt = 1
      BEGIN
        INSERT INTO #TEMPPACK (BOMSKU, Storerkey)
        VALUES (@cBOMSKU, @cStorerkey)
      END

	 FETCH NEXT FROM C_BOM INTO @cBOMSKU

	END
	CLOSE C_BOM
	DEALLOCATE C_BOM

   IF @n_debug = 1
   BEGIN
     SELECT '@nMatchCnt', @nMatchCnt 
   END

   SELECT @nCnt = COUNT(*)
   FROM #TEMPPACK WITH (NOLOCK)

   IF @nCnt > 0
   BEGIN
		/*
      SELECT @nMatchFound = COUNT(DISTINCT PACK.Packkey), 
             @cMatchSKU = UPC.SKU
      FROM dbo.PACK PACK WITH (NOLOCK)
      JOIN dbo.UPC UPC WITH (NOLOCK) ON (UPC.Packkey = PACK.Packkey)
      WHERE PACK.Packkey in (SELECT DISTINCT SKU.Packkey 
                        FROM dbo.SKU SKU WITH (NOLOCK)
                        JOIN #TEMPPACK T WITH (NOLOCK)
                          ON (T.BOMSKU = SKU.SKU AND T.Storerkey = SKU.Storerkey))
      AND ISNULL(PACK.InnerPack, 0) = @nInnerPack
      AND ISNULL(PACK.Casecnt, 0) = ISNULL(@nCaseCnt, 0)
      AND ISNULL(PACK.OtherUnit1, 0) = ISNULL(@nShipper, 0)
      AND ISNULL(PACK.Pallet, 0) = ISNULL(@nPallet, 0)
      GROUP BY UPC.SKU, Pack.packkey 
		*/

      SELECT @nMatchFound = COUNT(DISTINCT PACK.Packkey), 
             @cMatchSKU = UPC.SKU
      FROM dbo.UPC UPC WITH (NOLOCK)
		  JOIN #TEMPPACK T WITH (NOLOCK) ON (UPC.Storerkey = T.Storerkey and UPC.Sku = T.BOMSku)
      JOIN dbo.PACK PACK WITH (NOLOCK) ON (UPC.Packkey = PACK.Packkey)
      AND ISNULL(PACK.InnerPack, 0) = @nInnerPack 
      AND ISNULL(PACK.Casecnt, 0) = ISNULL(@nCaseCnt, 0)
      AND ISNULL(PACK.OtherUnit1, 0) = ISNULL(@nShipper, 0)
      AND ISNULL(PACK.Pallet, 0) = ISNULL(@nPallet, 0)
      GROUP BY UPC.SKU, Pack.packkey
   END
   ELSE
   BEGIN
      SELECT @nMatchFound = 0
   END
END


GO