SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store procedure: rdt.rdt_GETSKUCNT                                   */
/* Copyright      : IDS                                                 */
/*                                                                      */
/* Purpose: Get SKU count                                               */
/*                                                                      */
/* Called from: 3                                                       */
/*    1. From PowerBuilder                                              */
/*    2. From scheduler                                                 */
/*    3. From others stored procedures or triggers                      */
/*    4. From interface program. DX, DTS                                */
/*                                                                      */
/* Exceed version: 5.4                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author   Purposes                                   */
/* 10-Dec-2008 1.0  Vicky    Created                                    */
/* 26-Jun-2012 1.1  ChewKP   Allow StorerKey = '' (ChewKP01)            */  
/* 10-Jan-2012 1.2  James    Perfomance tuning (james01)                */
/* 14-May-2013 1.3  Ung      SOS276721 Fix UPC > 20 chars (ung01)       */
/* 08-Feb-2018 1.4  James    WMS3967-Check status of SKU (james02)      */
/* 29-Nov-2021 1.5  Ung      Perfomance tuning                          */
/************************************************************************/
CREATE PROC    [RDT].[rdt_GETSKUCNT]
               @cStorerKey   NVARCHAR(15)
,              @cSKU         NVARCHAR(30) -- (ung01)
,              @nSKUCnt      int               OUTPUT
,              @bSuccess     int               OUTPUT
,              @nErr         int               OUTPUT
,              @cErrMsg      NVARCHAR(250)     OUTPUT
,              @cSKUStatus   NVARCHAR(10) = ''

AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @nContinue int
   SELECT @nContinue = 1
   SELECT @bSuccess = 1
   SELECT @nSKUCnt = 0
   SELECT @nErr = 0
   SELECT @cErrMsg = ''

   IF @cSKUStatus = ''
   BEGIN
      -- (ChewKP01)
      IF ISNULL(@cStorerKey,'') = ''
      BEGIN
         -- since no storerkey then cannot use PKSKU coz index is storerkey + sku. use sku index instead
         IF NOT EXISTS (SELECT 1 
                           FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IDX_SKU_SKU)) WHERE Sku = @cSKU)  -- (james01)
         BEGIN
            SELECT @nSKUCnt = COUNT(DISTINCT SKU)
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
            WHERE AltSku = @cSKU 
         
            IF @nSKUCnt = 1 OR @nSKUCnt = 0 
            BEGIN
               SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               WHERE RetailSku = @cSKU 
   
               IF @nSKUCnt = 1 OR @nSKUCnt = 0 
               BEGIN 
                  SELECT @nSKUCnt = COUNT(DISTINCT SKU)
                  FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                  WHERE ManufacturerSku = @cSKU 

                  IF @nSKUCnt = 1 OR @nSKUCnt = 0 
                  BEGIN
                     SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
                     FROM dbo.UPC UPC WITH (NOLOCK) 
                     WHERE UPC = @cSKU 
                  END
               END 
            END
         END
         ELSE
         BEGIN
            SET @nSKUCnt = 1
         END
         
         GOTO QUIT
      END
   
      IF ISNULL(@cStorerKey,'') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) WHERE StorerKey = @cStorerKey AND Sku = @cSKU)
         BEGIN
   
            SELECT @nSKUCnt = COUNT(DISTINCT SKU)
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
            WHERE AltSku = @cSKU 
              AND StorerKey = @cStorerKey
            IF @nSKUCnt = 0 
            BEGIN
               SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               WHERE RetailSku = @cSKU 
                AND StorerKey = @cStorerKey
   
               IF @nSKUCnt = 0 
               BEGIN 
                  SELECT @nSKUCnt = COUNT(DISTINCT SKU)
                  FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                   WHERE ManufacturerSku = @cSKU 
                     AND StorerKey = @cStorerKey
                  IF @nSKUCnt = 0 
                  BEGIN
                     SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
                     FROM dbo.UPC UPC WITH (NOLOCK) 
                     WHERE UPC = @cSKU 
                       AND StorerKey = @cStorerKey            
                  END
               END 
            END
         END
         ELSE
         BEGIN
            SET @nSKUCnt = 1
         END
      END
   END
   ELSE
   BEGIN
      -- (ChewKP01)
      IF ISNULL(@cStorerKey,'') = ''
      BEGIN
         -- since no storerkey then cannot use PKSKU coz index is storerkey + sku. use sku index instead
         IF NOT EXISTS (SELECT 1 
                           FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IDX_SKU_SKU)) 
                           WHERE Sku = @cSKU               -- (james01)
                           AND   SKUStatus = @cSKUStatus)
         BEGIN
            SELECT @nSKUCnt = COUNT(DISTINCT SKU)
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
            WHERE AltSku = @cSKU 
            AND   SKUStatus = @cSKUStatus
         
            IF @nSKUCnt = 1 OR @nSKUCnt = 0 
            BEGIN
               SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               WHERE RetailSku = @cSKU 
               AND   SKUStatus = @cSKUStatus
   
               IF @nSKUCnt = 1 OR @nSKUCnt = 0 
               BEGIN 
                  SELECT @nSKUCnt = COUNT(DISTINCT SKU)
                  FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                  WHERE ManufacturerSku = @cSKU 
                  AND   SKUStatus = @cSKUStatus

                  IF @nSKUCnt = 1 OR @nSKUCnt = 0 
                  BEGIN
                     SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
                     FROM dbo.UPC UPC WITH (NOLOCK) 
                     WHERE UPC = @cSKU 
                  END
               END 
            END
         END
         ELSE
         BEGIN
            SET @nSKUCnt = 1
         END
         
         GOTO QUIT
      END
   
      IF ISNULL(@cStorerKey,'') <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(PKSKU)) 
                        WHERE StorerKey = @cStorerKey 
                        AND   Sku = @cSKU
                        AND   SKUStatus = @cSKUStatus)
         BEGIN
   
            SELECT @nSKUCnt = COUNT(DISTINCT SKU)
            FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_AltSku)) 
            WHERE AltSku = @cSKU 
            AND   StorerKey = @cStorerKey
            AND   SKUStatus = @cSKUStatus

            IF @nSKUCnt = 0 
            BEGIN
               SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
               FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_RetailSKU)) 
               WHERE RetailSku = @cSKU 
               AND   StorerKey = @cStorerKey
               AND   SKUStatus = @cSKUStatus
   
               IF @nSKUCnt = 0 
               BEGIN 
                  SELECT @nSKUCnt = COUNT(DISTINCT SKU)
                  FROM  dbo.SKU SKU WITH (NOLOCK, INDEX(IX_SKU_ManufacturerSku)) 
                   WHERE ManufacturerSku = @cSKU 
                   AND   StorerKey = @cStorerKey
                   AND   SKUStatus = @cSKUStatus

                  IF @nSKUCnt = 0 
                  BEGIN
                     SELECT @nSKUCnt = COUNT(DISTINCT SKU) 
                     FROM dbo.UPC UPC WITH (NOLOCK) 
                     WHERE UPC = @cSKU 
                       AND StorerKey = @cStorerKey            
                  END
               END 
            END
         END
         ELSE
         BEGIN
            SET @nSKUCnt = 1
         END
      END
   END

   QUIT:
   
END




GO