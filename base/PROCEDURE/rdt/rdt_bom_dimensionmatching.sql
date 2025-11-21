SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/  
/* Store procedure: rdt_BOM_DimensionMatching                              */  
/* Copyright      : IDS                                                    */  
/*                                                                         */  
/* Purposes:                                                               */  
/* 1) To Match scanned Parent SKU Dimension LxWxH                          */  
/*                                                                         */  
/* Called from: rdtfnc_BOMCreation                                         */  
/*                                                                         */  
/* Exceed version: 5.4                                                     */  
/*                                                                         */  
/* Modifications log:                                                      */  
/*                                                                         */  
/* Date        Rev  Author      Purposes                                   */  
/* 07-Aug-2007 1.0  Shong       Created                                    */  
/***************************************************************************/  
CREATE PROC [RDT].[rdt_BOM_DimensionMatching] (  
   @cStorerkey       NVARCHAR(15),  
   @cParentSKU       NVARCHAR(18),   
   @cStyle           NVARCHAR(20),  
   @nLength          FLOAT,  
   @nWidth           FLOAT,  
   @nHeight          FLOAT,  
   @nStdGrossWgt     FLOAT,  
   @nMobile          INT,  
   @cUsername        NVARCHAR(18),  
   @cMatchSKU        NVARCHAR(20)      OUTPUT,  
   @cResult          NVARCHAR(1)       OUTPUT,  
   @cMatchDimension  NVARCHAR(1) = 1   OUTPUT,  
   @nBOMDIMTOLERANCE INT,  
   @cParentExt       NVARCHAR(1) = '0',   
   @cCheckDimension  NVARCHAR(1) = '0'    
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
           @nWeighting INT,   
           @nBomStdCube FLOAT,  
           @nBomLength  FLOAT,  
           @nBomWidth   FLOAT,   
           @nBomHeight  FLOAT,  
           @nCube       FLOAT     
  
   SET @n_debug = 0  
   SET @nSKUCnt = 0  
   SET @nSKUQty = 0  
   SET @nMatchCnt = 0  
   SET @nWeighting = 0  
   SET @cMatchFlag = 'N'  
   SET @cResult = '0'  
   SET @nBomStdCube = 0  
   SET @nBomLength  = 0  
   SET @nBomWidth   = 0   
   SET @nBomHeight  = 0  
   SET @nCube       = 0     
  
   SELECT @nSKUCnt = COUNT(ComponentSKU),  
          @nWeighting = SUM(Qty) * COUNT(ComponentSKU)  
   FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)  
   WHERE Storerkey = @cStorerkey  
   AND   ParentSKU = RTRIM(@cParentSKU)  
   AND   Status = '0'  
   AND   MobileNo = @nMobile  
   AND   Username = @cUsername -- (Shong01)  
  
  IF @cParentExt <> '1' -- (Shong05)  
  BEGIN  
      -- If BOM SKU not provided, then check the all  
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
      DECLARE C_CSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR   
     SELECT RTRIM(ComponentSKU), QTY  
     FROM RDT.rdtBOMCreationLog  WITH (NOLOCK)  
     WHERE Storerkey = @cStorerkey  
     AND   ParentSKU = RTRIM(@cParentSKU)  
     AND   Status = '0'  
     AND   MobileNo = @nMobile  
         AND   Username = @cUsername -- (Shong01)  
      
  OPEN C_CSKU  
    
  FETCH NEXT FROM C_CSKU INTO @cComponentSKU, @nSKUQty  
    
  WHILE @@FETCH_STATUS <> -1   
  BEGIN  
          IF EXISTS (SELECT 1 FROM dbo.BillOfMaterial BOM WITH (NOLOCK)  
                     WHERE BOM.Storerkey = @cStorerkey  
                     AND   BOM.SKU = @cBOMSKU  
                     AND   BOM.ComponentSKU = @cComponentSKU  
                     AND   BOM.QTY = @nSKUQty)  
          BEGIN  
              SELECT @cMatchFlag = 'Y'  
              SET @nMatchCnt = @nMatchCnt + 1  
          END  
          ELSE  
          BEGIN  
              SELECT @cMatchFlag = 'N'  
              GOTO NEXT_REC  
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
         IF @cCheckDimension = '1'   
         BEGIN  
            SET @nCube = @nLength * @nWidth * @nHeight  
  
            SELECT @nBomStdCube = CASE WHEN StdCube > 0 THEN StdCube   
                                       ELSE [LENGTH] * [Width] * [Height]     
                                  END,   
                   @nBomLength  = [LENGTH],   
                   @nBomWidth   = [Width],  
                   @nBomHeight  = [Height]  
            FROM dbo.SKU WITH (NOLOCK)   
            WHERE StorerKey = @cStorerKey   
              AND SKU = @cBOMSKU  
  
            IF (ABS((@nBomLength - @nLength)) * 100) / CASE WHEN ISNULL(@nBomLength, 0) = 0 THEN 1 ELSE @nBomLength  END <= @nBOMDIMTOLERANCE AND   
               (ABS((@nBomWidth  - @nWidth))  * 100) / CASE WHEN ISNULL(@nBomWidth, 0) = 0 THEN 1 ELSE  @nBomWidth   END <= @nBOMDIMTOLERANCE AND  
               (ABS((@nBomHeight - @nHeight)) * 100) / CASE WHEN ISNULL(@nBomHeight, 0) = 0 THEN 1 ELSE @nBomHeight  END <= @nBOMDIMTOLERANCE AND   
               (ABS((@nBomStdCube - @nCube))  * 100) / CASE WHEN ISNULL(@nBomStdCube, 0)= 0 THEN 1 ELSE @nBomStdCube END <= @nBOMDIMTOLERANCE   
            BEGIN   
               SET @cResult = '1'  
               SELECT @cMatchSKU = @cBOMSKU   
               SET @cMatchDimension = 1  
               GOTO Match_Found  
            END  
            ELSE  
            BEGIN  
               SET @cMatchDimension = 0  
               --GOTO Match_Found  
            END  
         END  
         ELSE  
         BEGIN   
            SET @cResult = '1'  
            SELECT @cMatchSKU = @cBOMSKU   
            GOTO Match_Found  
         END   
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
  
   IF @cResult = '0'   
   BEGIN  
      SET @cMatchDimension = 0  
   END  
END

GO