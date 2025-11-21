SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: ispGenDiscrete_PPLabel                             */
/* Creation Date: 28-Sep-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: To print Pre-Pack Label for US Operation of Discrete Sort   */
/*          List & Discrete Pick Ticket.                                */
/*                                                                      */
/* Called By: PB RCM - Auto print from Conso & Discrete Pick Ticket     */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 03-Oct-2007  Vicky     SOS#88066 - Prepack Label master qty should be*/
/*                        shown as prepack instead of pieces            */
/* 13-Oct-2007  Vicky     Sort Size by SKU.Busr8                        */
/************************************************************************/

CREATE PROCEDURE [dbo].[ispGenDiscrete_PPLabel] (
      @cLoadKey  NVARCHAR(10),
      @cUserID   NVARCHAR(18) = '' 
   )
AS 
BEGIN 
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @t_Labels TABLE (
      Divider      char (35) NULL ,
      Indicator    char (10) NULL ,
      UserID       char (18) NULL ,
      NoOfCopy     int  NULL ,
      LoadKey      char (10) NULL ,
      OrderKey     char (10) NULL ,
      NoOfOrderLbl int  NULL ,
      ParentSku    char (20) NULL ,
      UPCCode      char (20) NULL ,
      Style        char (20) NULL ,
      Color        char (30) NULL ,
      [Size]       char (30) NULL ,
      Ratio        char (30) NULL ,
      TotQty       int  NULL ,
      CartonNo     int  IDENTITY (1, 1) NOT NULL 
)

   DECLARE @t_LabelToGen TABLE (
      OrderKey    NVARCHAR(10),
      LabelType   NVARCHAR(1),
      UPC         NVARCHAR(20),
      LabelQty    int
      )
      
   DECLARE @cOrderKey     NVARCHAR(10), 
           @cStyle        NVARCHAR(20), 
           @cLOC          NVARCHAR(10), 
           @nQty          int, 
           @nBOMQty       int, 
           @cParentSKU    NVARCHAR(18), 
           @cUserDefine03 NVARCHAR(18), 
           @cPickSlipNo   NVARCHAR(10), 
           @bDebug        int,
           @cStorerKey    NVARCHAR(15),
           @nTotBOMQty    int, 
           @nBuddleQty    int, 
           @cPreOrderKey  NVARCHAR(10),
           @nPallet       int,
           @nCaseCnt      int,
           @nOtherUnit1   int,
           @nInnerPack    int,
           @cColor        NVARCHAR(10), 
           @cSize         NVARCHAR(5), 
           @cPreColor     NVARCHAR(10), 
           @cPreSize      NVARCHAR(5), 
           @cLabelSize    NVARCHAR(30), 
           @cLabelColor   NVARCHAR(30),
           @cLabelRatio   NVARCHAR(30), 
           @nTotQty       int, 
           @nIndex        int, 
           @cPalletUOM    NVARCHAR(5),
           @cCaseUOM      NVARCHAR(5),
           @cInnerUOM     NVARCHAR(5),
           @cShipperUOM   NVARCHAR(5),
           @nTopLevel     int,
           @nPackLevel    int,
           @nLabelQty     int,
           @cUPC          NVARCHAR(20), 
           @nUOMQty       int  

   SET @bDebug = 0  

   IF @cUserID = 'debug' 
      SET @bDebug = 1

   INSERT INTO @t_Labels (Divider, Indicator, UserID, LoadKey, OrderKey, NoOfCopy, 
  UPCCOde, Style, Color, Size, TotQty, ParentSku, Ratio)
   VALUES ('***********************************','START', @cUserID, @cLoadKey, '', 0, 
     '', '', '', '', 0, '', '')


   DECLARE C_AllocatedLines CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT PickHeader.PickHeaderKey, 
          OrderDetail.StorerKey,   
          OrderDetail.OrderKey, 
          SKU.Style,
          PickDetail.LOC,  
          SUM(PickDetail.Qty) AS Qty, 
          LotAttribute.Lottable03, 
          OrderDetail.UserDefine03
   FROM OrderDetail WITH (NOLOCK) 
   LEFT OUTER JOIN PickHeader WITH (NOLOCK) ON PickHeader.ExternOrderKey = OrderDetail.LoadKey AND 
                               PickHeader.OrderKey = OrderDetail.OrderKey 
   JOIN PickDetail WITH (NOLOCK) ON PickDetail.OrderKey = OrderDetail.OrderKey AND 
                               PickDetail.OrderLineNumber = OrderDetail.OrderLineNumber 
   JOIN LotAttribute WITH (NOLOCK) ON LotAttribute.LOT = PickDetail.LOT 
   JOIN SKU WITH (NOLOCK) ON SKU.StorerKey = PickDetail.StorerKey AND SKU.SKU = PickDetail.SKU 
   WHERE OrderDetail.loadkey = @cLoadKey  
   AND  (OrderDetail.UserDefine03 IS NOT NULL AND OrderDetail.UserDefine03 <> '')   
   GROUP BY PickHeader.PickHeaderKey, OrderDetail.StorerKey, OrderDetail.OrderKey, 
          SKU.Style,   PickDetail.LOC,  
          LotAttribute.Lottable03,  OrderDetail.UserDefine03
   ORDER BY PickHeader.PickHeaderKey, OrderDetail.StorerKey, OrderDetail.OrderKey, LotAttribute.Lottable03  
   
   OPEN C_AllocatedLines

   FETCH NEXT FROM C_AllocatedLines INTO 
         @cPickSlipNo, @cStorerKey, @cOrderKey, @cStyle, @cLOC, @nQty, @cParentSKU, @cUserDefine03

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF @bDebug =1 
      BEGIN 
         SELECT @cPickSlipNo '@cPickSlipNo', @cOrderKey '@cOrderKey', @cStyle '@cStyle', 
                @cLOC '@cLOC', @nQty '@nQty', @cParentSKU '@cParentSKU', @cUserDefine03 '@cUserDefine03'
      END
      -- Get How Many PrePack Qty Base in Ratio
      SELECT @nTotBOMQty = SUM(BOM.Qty) 
      FROM   BillOfMaterial BOM WITH (NOLOCK) 
      WHERE  BOM.StorerKey = @cStorerKey 
      AND    BOM.SKU = @cParentSKU 

      IF @cPreOrderKey <> @cOrderKey 
      BEGIN 
         SET @cPreOrderKey = @cOrderKey

         INSERT INTO @t_Labels (Divider, Indicator, UserID, NoOfCopy, LoadKey, OrderKey,
                                UPCCOde, Style, Color, Size, TotQty, ParentSKU, Ratio)
         VALUES ('***********************************','ORDSTART',@cUserID, 0, @cLoadKey, @cOrderKey, 
                 '', '', '', '', 0, '', '')
      END
      
      -- Determine what Label Type?
      SELECT @nBuddleQty = FLOOR(@nQty / @nTotBOMQty)

      SELECT @nPallet     = PACK.Pallet, 
             @cPalletUOM  = PACK.PACKUOM1, 
             @nCaseCnt    = PACK.Casecnt,
             @cCaseUOM    = PACK.PackUOM2,
             @nOtherUnit1 = PACK.Otherunit1, 
             @cShipperUOM = PACK.PackUOM8,  
             @nInnerPack  = PACK.InnerPack, 
             @cInnerUOM   = PACK.PackUOM2  
      FROM  SKU WITH (NOLOCK)
      JOIN  PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
      WHERE SKU.StorerKey = @cStorerKey
      AND   SKU.Sku = @cParentSKU

      IF @nPallet IS NOT NULL AND @nPallet > 0 
         SET @nTopLevel = 5 -- Pallet 
      ELSE IF @nOtherUnit1 IS NOT NULL AND @nOtherUnit1 > 0
         SET @nTopLevel = 4 -- Shiper 
      ELSE IF @nCaseCnt IS NOT NULL AND @nCaseCnt > 0
         SET @nTopLevel = 3 -- Master 
      ELSE IF @nInnerPack IS NOT NULL AND @nInnerPack > 0
         SET @nTopLevel = 2 -- Inner 
      ELSE 
         SET @nTopLevel = 1 -- Bunder 
      
      -- 
      IF @bDebug = 1
      BEGIN
         SELECT @nTopLevel '@nTopLevel'
      END 

      SET @nPackLevel = @nTopLevel 
      
      WHILE @nPackLevel >= 1 
      BEGIN
         SET @nLabelQty = 
                  CASE @nPackLevel 
                     WHEN 5 THEN FLOOR(@nQty / ( @nPallet * @nTotBOMQty) )
                     WHEN 4 THEN FLOOR(@nQty / ( @nOtherUnit1 * @nTotBOMQty) )
                     WHEN 3 THEN FLOOR(@nQty / ( @nCaseCnt * @nTotBOMQty) )
                     WHEN 2 THEN FLOOR(@nQty / ( @nInnerPack * @nTotBOMQty) )
                     ELSE ( @nQty / @nTotBOMQty )
                  END 
                  
         SET @nQty = 
                  CASE @nPackLevel 
                     WHEN 5 THEN (@nQty % (@nPallet * @nTotBOMQty) )
                     WHEN 4 THEN (@nQty % (@nOtherUnit1 * @nTotBOMQty) )
                     WHEN 3 THEN (@nQty % (@nCaseCnt * @nTotBOMQty) )
                     WHEN 2 THEN (@nQty % (@nInnerPack * @nTotBOMQty) )
                     ELSE ( @nQty % @nTotBOMQty ) 
                  END 
         
         SET @nUOMQty = 
             CASE @nPackLevel 
               WHEN 5 THEN @nPallet
               WHEN 4 THEN @nOtherUnit1
               WHEN 3 THEN @nCaseCnt
               WHEN 2 THEN @nInnerPack
               ELSE 1 
            END 

         IF @bDebug = 1
         BEGIN
            SELECT @nPackLevel '@nPackLevel', @nQty '@nQty', @nUOMQty '@nUOMQty', @nLabelQty '@nLabelQty', 
                   @nTotBOMQty '@nTotBOMQty'
         END
            
         IF (@nPackLevel <> @nTopLevel OR @nTopLevel = 1) AND @nLabelQty > 0 
         BEGIN 
            IF @nPackLevel > 1   
            BEGIN 
               SET @cUPC = ''

               SELECT @cUPC = ISNULL(UPC, '')
               FROM   UPC WITH (NOLOCK) 
               WHERE  StorerKey = @cStorerKey 
               AND    SKU = @cParentSKU 
               AND    UOM = CASE @nPackLevel 
                                 WHEN 2 THEN @cInnerUOM 
                                 WHEN 3 THEN @cCaseUOM
                                 WHEN 4 THEN @cShipperUOM
                                 WHEN 5 THEN @cPalletUOM
                            END

------------- Print Master Label 
               -- Cursor Loop Start
               SET @cLabelColor = ''
               SET @cLabelSize  = ''
               SET @cLabelRatio = ''
               SET @cPreColor   = ''
               SET @cPreSize    = ''

            	DECLARE C_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            	SELECT DISTINCT SKU.Color, SKU.Size, BOM.Qty 
               FROM   BillOfMaterial BOM WITH (NOLOCK) 
               JOIN   SKU WITH (NOLOCK) ON (BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSku = SKU.SKU)
               WHERE  BOM.StorerKey = @cStorerKey 
               AND    BOM.SKU = @cParentSKU
               ORDER BY SKU.Color

            	OPEN C_BOM
            	FETCH NEXT FROM C_BOM INTO @cColor, @cSize, @nBOMQty 

               IF @bDebug = 1
               BEGIN 
                  PRINT 'Start Cursor...'
               END 
            
            	WHILE (@@FETCH_STATUS <> -1)
            	BEGIN
                  IF @bDebug = 1
                  BEGIN 
                     SELECT @cStyle '@cStyle', @cColor '@cColor', @cSize '@cSize', @nBOMQty '@nBOMQty', @nUOMQty '@nUOMQty'
                  END 
            
                  IF @cPreColor <> @cColor
                  BEGIN
                     SET @cPreColor = @cColor
                     IF LEN(ISNULL(@cLabelColor, '')) = 0 
                        SET @cLabelColor = @cColor
                     ELSE
                        SET @cLabelColor = dbo.fnc_RTrim(@cLabelColor) + '-' + ISNULL(dbo.fnc_RTrim(@cColor),'')
                  END 
            
                  IF @cPreSize <> @cSize
                  BEGIN
                     SET @cPreSize = @cSize
                     IF LEN(ISNULL(@cLabelSize, '')) = 0 
                        SET @cLabelSize = @cSize
                     ELSE
                        SET @cLabelSize = dbo.fnc_RTrim(@cLabelSize) + '-' + ISNULL(dbo.fnc_RTrim(@cSize),'')
                  END 
            
-- Comment By Vicky on 03-Oct-2007 (Start) 
--                   SET @nTotQty = @nTotQty + (@nBOMQty * @nUOMQty)
-- Comment By Vicky on 03-Oct-2007 (End) 

            		FETCH NEXT FROM C_BOM INTO @cColor, @cSize, @nBOMQty 
            	END -- END WHILE (@@FETCH_STATUS <> -1)
            	CLOSE C_BOM
            	DEALLOCATE C_BOM		
               -- Cursor Loop End

               SET @nIndex = 1
            
               -- Insert Detail Label data
               WHILE @nIndex <= @nLabelQty
               BEGIN
                  IF @bDebug = 1
                  BEGIN 
                     SELECT '@nIndex/@nLabelQty: ', @nIndex, '/', @nLabelQty
                  END 

                  INSERT INTO @t_Labels (
                        Divider, Indicator, UserID, NoOfCopy, LoadKey, OrderKey, NoOfOrderLbl, ParentSku,   
                        UPCCode, Style,     Color,  Size,     Ratio,   TotQty)
                  VALUES ('','DATAM', @cUserID, 0, @cLoadKey, @cOrderKey, 0, @cParentSKU, 
                          @cUPC, @cStyle, @cLabelColor, @cLabelSize, @cLabelRatio, @nUOMQty)--(@nUOMQty * @nTotBOMQty)) -- Modified By Vicky on 03-Oct-2007
            
                  SET @nIndex = @nIndex + 1 
               END
            END -- @nPackLevel > 1
------------- Bundle Label                           
            ELSE
            BEGIN
               SET @cLabelColor = ''
               SET @cLabelSize  = ''
               SET @cLabelRatio = ''
               SET @cPreColor   = ''
               SET @cPreSize    = ''

            	DECLARE C_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            	SELECT SKU.Color, SKU.Size, BOM.Qty, @cUserID  
               FROM   BillOfMaterial BOM WITH (NOLOCK) 
               JOIN   SKU WITH (NOLOCK) ON (BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSku = SKU.SKU)
               WHERE  BOM.StorerKey = @cStorerKey 
               AND    BOM.SKU = @cParentSKU
               --ORDER BY SKU.Color, SKU.Size, BOM.Qty 
               ORDER BY SKU.Color, SKU.BUSR8, BOM.Qty -- Vicky01
            
            	OPEN C_BOM
            	FETCH NEXT FROM C_BOM INTO @cColor, @cSize, @nBOMQty, @cUserID 
            
               IF @bDebug = 1
               BEGIN 
                  PRINT 'Start Cursor...'
               END 
            
            	WHILE (@@FETCH_STATUS <> -1)
            	BEGIN
                  IF @bDebug = 1
                  BEGIN 
                     SELECT @cStyle '@cStyle', @cColor '@cColor', @cSize '@cSize', @nBOMQty '@nBOMQty', @nUOMQty '@nUOMQty'
                  END 
            
                  IF @cPreColor <> @cColor
                  BEGIN
                     SET @cPreColor = @cColor
                     IF LEN(ISNULL(@cLabelColor, '')) = 0 
                        SET @cLabelColor = @cColor
                     ELSE
                        SET @cLabelColor = dbo.fnc_RTrim(@cLabelColor) + '-' + ISNULL(dbo.fnc_RTrim(@cColor),'')
                  END 
            
                  IF @cPreSize <> @cSize
                  BEGIN
                     SET @cPreSize = @cSize
                     IF LEN(ISNULL(@cLabelSize, '')) = 0 
                        SET @cLabelSize = @cSize
                     ELSE
                        SET @cLabelSize = dbo.fnc_RTrim(@cLabelSize) + '-' + ISNULL(dbo.fnc_RTrim(@cSize),'')
                  END 
            
                  IF LEN(ISNULL(@cLabelRatio, '')) = 0 
                     SET @cLabelRatio = dbo.fnc_RTrim(CAST(@nBOMQty AS NVARCHAR(5)))
                  ELSE
                     SET @cLabelRatio = dbo.fnc_RTrim(@cLabelRatio) + '-' + dbo.fnc_RTrim(CAST(@nBOMQty AS NVARCHAR(5)))     
            
                  SET @nTotQty = @nTotQty + @nBOMQty 
            
            		FETCH NEXT FROM C_BOM INTO @cColor, @cSize, @nBOMQty, @cUserID 
            	END -- END WHILE (@@FETCH_STATUS <> -1)
            	CLOSE C_BOM
            	DEALLOCATE C_BOM		
               -- Cursor Loop End
            
               SET @nIndex = 1 
            
               -- Insert Detail Label data
               WHILE @nIndex <= @nLabelQty
    BEGIN
              IF @bDebug = 1
                  BEGIN 
                     SELECT '@nIndex/@nLabelQty: ', @nIndex, '/', @nLabelQty
                  END 
            
                  INSERT INTO @t_Labels (
                        Divider, Indicator, UserID, NoOfCopy, LoadKey, OrderKey, NoOfOrderLbl, ParentSku,   
                        UPCCode, Style,     Color,  Size,     Ratio,   TotQty)
                  VALUES ('','DATA', @cUserID, 0, @cLoadKey, @cOrderKey, 0, @cParentSKU, 
                          @cUPC, @cStyle, @cLabelColor, @cLabelSize, @cLabelRatio, (@nUOMQty * @nTotBOMQty))
            
                  SET @nIndex = @nIndex + 1 
               END               
            END -- Print Bundle 
         END -- @nPackLevel <>  @nTopLevel
         
         SET @nPackLevel = @nPackLevel - 1         
      END
      
      FETCH NEXT FROM C_AllocatedLines INTO 
            @cPickSlipNo, @cStorerKey, @cOrderKey, @cStyle, @cLOC, @nQty, @cParentSKU, @cUserDefine03

   END -- while cursor C_AllocatedLines
   CLOSE C_AllocatedLines
   DEALLOCATE C_AllocatedLines 

   -- Set Total 

--    INSERT INTO @t_Labels (Divider, Indicator, UserID, LoadKey, OrderKey, NoOfCopy, 
--                           UPCCOde, Style, Color, Size, TotQty, ParentSku, Ratio)
--    VALUES ('***********************************','END',@cUserID, @cLoadKey, '', 0, 
--            '', '', '', '', 0, '', '')

   IF (SELECT COUNT(*) FROM @t_Labels WHERE Indicator IN ('DATA', 'DATAM')) > 0 
   BEGIN 
      -- UPDATE Total Labels 
      UPDATE @t_Labels
         SET NoOfOrderLbl = ( SELECT COUNT(*) FROM @t_Labels WHERE Indicator IN ('DATA', 'DATAM') )
      WHERE Indicator IN ('START', 'END') 
   
      -- Update total labels per Order# 
      UPDATE @t_Labels
        SET NoOfOrderLbl = SUMM.LabelCount
      FROM @t_Labels Labels
      JOIN (SELECT OrderKey, COUNT(*) As LabelCount 
            FROM @t_Labels WHERE Indicator IN ('DATA', 'DATAM')
            GROUP BY OrderKey) AS SUMM 
         ON SUMM.OrderKey = Labels.OrderKey 
      WHERE Indicator = 'ORDSTART'
   END
   ELSE
   BEGIN
      -- No Labels Generated, remove the Start & End Label 
      DELETE @t_Labels 
   END 
   
  SELECT Labels.Divider,   
         Labels.Indicator,   
         Labels.UserID,   
         Labels.NoOfCopy,   
         Labels.LoadKey,   
         Labels.OrderKey,   
         Labels.NoOfOrderLbl,   
         UPPER(Labels.ParentSku), -- Vicky01
         UPPER(Labels.UPCCode),   -- Vicky01  
         Labels.Style,   
         Labels.Color,   
         Labels.Size,   
         Labels.Ratio,   
         Labels.TotQty,   
         Labels.CartonNo  
    FROM @t_Labels Labels 
END -- Procedure






GO