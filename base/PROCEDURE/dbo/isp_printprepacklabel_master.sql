SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/
/* Stored Procedure: isp_PrintPrePackLabel_Master                       */
/* Creation Date: 03-Sep-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: To print Master Label of Pre-Pack for US Operation.         */
/*                                                                      */
/* Called By: PB - BillOfMaterial & ASN/XDock/Trade Return Modules      */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Purposes                                      */
/* 18-Sep-2007  Vicky     Add Pallet Level                              */
/* 27-Sep-2007  YokeBeen  SOS#87269 - (YokeBeen01)                      */ 
/*                        - Added Start & End Labels Generation.        */
/* 28-Sep-2007  Vicky     Do not insert End label, have to parse in     */
/*                        UserID because RDT spooler printed with the   */
/*                        administrator login                           */
/* 03-Oct-2007  Vicky     SOS#88066 - Prepack Label master qty should be*/
/*                        shown as prepack instead of pieces            */
/* 31-Mar-2009  Larry01   SOS#133035 - Get 10 Chars from Left, 1 SKU    */
/*                        2 UPC in UOM CS, get the shorter one          */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintPrePackLabel_Master] (
       @cStorerKey   NVARCHAR(15), 
       @cParentSKU NVARCHAR(20), 
       @cLevel       NVARCHAR(1)  = 'I',
       @nNoOfCopy    int = 1,
       @cUserID      NVARCHAR(18) -- Vicky 
)
AS
BEGIN
	 SET NOCOUNT ON
	 SET QUOTED_IDENTIFIER OFF	
   SET CONCAT_NULL_YIELDS_NULL OFF
   

   DECLARE @n_continue    int,
           @c_errmsg      NVARCHAR(255),
           @b_success     int,
           @n_err         int, 
           @b_debug       int
   SET @b_debug = 0

   DECLARE @cUPC          NVARCHAR(20), 
           @nUOMQty       float,
           @cStyle        NVARCHAR(20), 
           @cColor        NVARCHAR(10), 
           @cSize         NVARCHAR(5), 
           @nQty          int,
           @cPreStyle     NVARCHAR(20), 
           @cPreColor     NVARCHAR(10), 
           @cPreSize      NVARCHAR(5), 
           @cLabelSize    NVARCHAR(30), 
           @cLabelColor   NVARCHAR(30),
           @cLabelRatio   NVARCHAR(30), 
           @nTotQty       int, 
           @nIndex        int 
--           @cUserID       NVARCHAR(18) -- (YokeBeen01)

   DECLARE @t_Result Table (
           -- (YokeBeen01) - Start 
           Divider        NVARCHAR(35), 
           Indicator      NVARCHAR(10), 
           UserID         NVARCHAR(18), 
           NoOfCopy       int, 
           -- (YokeBeen01) - End 
           UPCCOde        NVARCHAR(20),
           Style          NVARCHAR(20),
           Color          NVARCHAR(30),
           [Size]         NVARCHAR(30),
           TotQty         int, 
           CartonNo       int IDENTITY(1,1))

   SET @cUPC = ''

   IF @cLevel = 'I' -- Inner Level
   BEGIN
      SELECT @cUPC = UPC, 
             @nUOMQty = PACK.InnerPack
--             @cUserID = sUser_sName()  -- (YokeBeen01)
      FROM   UPC WITH (NOLOCK) 
      JOIN   PACK WITH (NOLOCK) ON PACK.PackKey = UPC.PackKey AND PACK.PackUOM2 = UPC.UOM  
      WHERE  StorerKey = @cStorerKey 
      AND    SKU = @cParentSKU 
   END
   ELSE IF @cLevel = 'C' -- Carton Level
   BEGIN
      SELECT TOP 1 @cUPC = UPC, --Larry01
             @nUOMQty = PACK.CaseCnt
--             @cUserID = sUser_sName()  -- (YokeBeen01)
      FROM   UPC WITH (NOLOCK) 
      JOIN   PACK WITH (NOLOCK) ON PACK.PackKey = UPC.PackKey AND PACK.PackUOM1 = UPC.UOM  
      WHERE  StorerKey = @cStorerKey 
      AND    SKU = @cParentSKU 
      ORDER BY LEN(UPC) ASC  --Larry01
   END
   ELSE IF @cLevel = 'S' -- Shipper Level
   BEGIN
      SELECT @cUPC = UPC, 
             @nUOMQty = PACK.OtherUnit1
--             @cUserID = sUser_sName()  -- (YokeBeen01)
      FROM   UPC WITH (NOLOCK) 
      JOIN   PACK WITH (NOLOCK) ON PACK.PackKey = UPC.PackKey AND PACK.PackUOM8 = UPC.UOM  
      WHERE  StorerKey = @cStorerKey 
      AND    SKU = @cParentSKU 
   END
   -- Added By Vicky on 18-Sept-2007 (Start)
   ELSE IF @cLevel = 'T' -- Pallet Level
   BEGIN
      SELECT @cUPC = UPC, 
             @nUOMQty = PACK.Pallet 
--             @cUserID = sUser_sName()  -- (YokeBeen01)
      FROM   UPC WITH (NOLOCK) 
      JOIN   PACK WITH (NOLOCK) ON PACK.PackKey = UPC.PackKey AND PACK.PackUOM4 = UPC.UOM  
      WHERE  StorerKey = @cStorerKey 
      AND    SKU = @cParentSKU 
   END
   -- Added By Vicky on 18-Sept-2007 (End)

   IF ISNULL(dbo.fnc_RTrim(@cUPC), '') = ''
      GOTO Quit
   
   SET @nTotQty = 0

   IF @b_debug = 1
   BEGIN
   	SELECT DISTINCT SKU.Style, SKU.Color, SKU.Size, BOM.Qty, @cUPC '@cUPC',  @nUOMQty '@nUOMQty'
      FROM   BillOfMaterial BOM WITH (NOLOCK) 
      JOIN   SKU WITH (NOLOCK) ON (BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSku = SKU.SKU)
      WHERE  BOM.StorerKey = @cStorerKey 
      AND    BOM.SKU = @cParentSKU
      ORDER BY SKU.Style, SKU.Color, SKU.Size
   END

   -- Cursor Loop Start
	DECLARE C_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT DISTINCT SKU.Style, SKU.Color, SKU.Size, BOM.Qty 
   FROM   BillOfMaterial BOM WITH (NOLOCK) 
   JOIN   SKU WITH (NOLOCK) ON (BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSku = SKU.SKU)
   WHERE  BOM.StorerKey = @cStorerKey 
   AND    BOM.SKU = @cParentSKU

   ORDER BY SKU.Style, SKU.Color

	OPEN C_BOM
	FETCH NEXT FROM C_BOM INTO @cStyle, @cColor, @cSize, @nQty 

   IF @b_debug = 1
   BEGIN 
      PRINT 'Start Cursor...'
   END 

	WHILE (@@FETCH_STATUS <> -1)
	BEGIN
      IF @b_debug = 1
      BEGIN 
         SELECT 'Style/Color/Size/Qty/UserID.. ', @cStyle, @cColor, @cSize, @nQty, @cUserID
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
--       SET @nTotQty = @nTotQty + (@nQty * @nUOMQty)
-- Comment By Vicky on 03-Oct-2007 (End)

		FETCH NEXT FROM C_BOM INTO @cStyle, @cColor, @cSize, @nQty 
	END -- END WHILE (@@FETCH_STATUS <> -1)
	CLOSE C_BOM
	DEALLOCATE C_BOM		
   -- Cursor Loop End

   SET @nIndex = 1

   -- (YokeBeen01) - Start 
   -- Insert Start Label data
   INSERT INTO @t_Result (Divider, Indicator, UserID, NoOfCopy, 
                          UPCCOde, Style, Color, Size, TotQty)
   VALUES ('***********************************','START',@cUserID, @nNoOfCopy, 
           '', '', '', '', 0)

   -- Insert Detail Label data
   WHILE @nIndex <= @nNoOfCopy
   BEGIN
      IF @b_debug = 1
      BEGIN 
         SELECT '@nIndex/@nNoOfCopy: ', @nIndex, '/', @nNoOfCopy
      END 

      INSERT INTO @t_Result (Divider, Indicator, UserID, NoOfCopy, 
                          UPCCOde, Style, Color, Size, TotQty)
      VALUES ('','DATA',@cUserID, @nNoOfCopy, 
              @cUPC, @cStyle, @cLabelColor, @cLabelSize, @nUOMQty)--@nTotQty) -- Modified By Vicky on 02-Oct-2007

      SET @nIndex = @nIndex + 1 
   END
   
   -- Insert End Label data
--    INSERT INTO @t_Result (Divider, Indicator, UserID, NoOfCopy, 
--                           UPCCOde, Style, Color, Size, TotQty)
--    VALUES ('***********************************','END',@cUserID, @nNoOfCopy, 
--            '', '', '', '', 0)
   -- (YokeBeen01) - End 

Quit:
   SELECT * FROM @t_Result 
   ORDER BY CartonNo 
END




GO