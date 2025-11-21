SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_PrintPrePackLabel_Bundle                       */
/* Creation Date: 03-Sep-2007                                           */
/* Copyright: IDS                                                       */
/* Written by: Shong                                                    */
/*                                                                      */
/* Purpose: To print Pre-Pack Label for US Operation.                   */
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
/* 21-Sep-2007  Vicky     Add in Username                               */
/* 27-Sep-2007  YokeBeen  SOS#87269 - (YokeBeen01)                      */ 
/*                        - Added Start & End Labels Generation.        */
/* 28-Sep-2007  Vicky     Do not insert End label, have to parse in     */
/*                        UserID because RDT spooler printed with the   */
/*                        administrator login                           */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintPrePackLabel_Bundle] (
       @cStorerKey   NVARCHAR(15), 
       @cParentSKU NVARCHAR(20), 
       @cLevel       NVARCHAR(1)  = 'P',
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
           ParentSku      NVARCHAR(20),
           Style          NVARCHAR(20),
           Color          NVARCHAR(30),
           [Size]         NVARCHAR(30),
           Ratio          NVARCHAR(30), 
           TotQty         int, 
           CartonNo       int IDENTITY(1,1))

   SET @cUPC = ''

   SET @nTotQty = 0

   IF @b_debug = 1
   BEGIN
   	SELECT SKU.Style, SKU.Color, SKU.Size, BOM.Qty, 
             @cUPC '@cUPC', 
             @nUOMQty '@nUOMQty' 
      FROM   BillOfMaterial BOM WITH (NOLOCK) 
      JOIN   SKU WITH (NOLOCK) ON (BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSku = SKU.SKU)
      WHERE  BOM.StorerKey = @cStorerKey 
      AND    BOM.SKU = @cParentSKU
      ORDER BY SKU.Style, SKU.Color, BOM.Sequence
   END

   -- Cursor Loop Start
	DECLARE C_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
	SELECT SKU.Style, SKU.Color, SKU.Size, BOM.Qty--, sUser_sName()  
   FROM   BillOfMaterial BOM WITH (NOLOCK) 
   JOIN   SKU WITH (NOLOCK) ON (BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSku = SKU.SKU)
   WHERE  BOM.StorerKey = @cStorerKey 
   AND    BOM.SKU = @cParentSKU
   ORDER BY SKU.Style, SKU.Color, BOM.Sequence

	OPEN C_BOM
	FETCH NEXT FROM C_BOM INTO @cStyle, @cColor, @cSize, @nQty--, @cUserID 

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

      IF LEN(ISNULL(@cLabelRatio, '')) = 0 
         SET @cLabelRatio = dbo.fnc_RTrim(CAST(@nQty AS NVARCHAR(5)))
      ELSE
         SET @cLabelRatio = dbo.fnc_RTrim(@cLabelRatio) + '-' + dbo.fnc_RTrim(CAST(@nQty AS NVARCHAR(5)))     

      SET @nTotQty = @nTotQty + @nQty 

		FETCH NEXT FROM C_BOM INTO @cStyle, @cColor, @cSize, @nQty--, @cUserID 
	END -- END WHILE (@@FETCH_STATUS <> -1)
	CLOSE C_BOM
	DEALLOCATE C_BOM		
   -- Cursor Loop End

   SET @nIndex = 1 

   -- (YokeBeen01) - Start 
   -- Insert Start Label data
   INSERT INTO @t_Result (Divider, Indicator, UserID, NoOfCopy, 
                          ParentSKU, Style, Color, Size, Ratio, TotQty)
   VALUES ('***********************************','START',@cUserID, @nNoOfCopy, 
           '', '', '', '', '', 0)

   -- Insert Detail Label data
   WHILE @nIndex <= @nNoOfCopy
   BEGIN
      IF @b_debug = 1
      BEGIN 
         SELECT '@nIndex/@nNoOfCopy: ', @nIndex, '/', @nNoOfCopy
      END 

      INSERT INTO @t_Result (Divider, Indicator, UserID, NoOfCopy, 
                             ParentSKU, Style, Color, Size, Ratio, TotQty)
      VALUES ('','DATA',@cUserID, @nNoOfCopy, 
              @cParentSKU, @cStyle, @cLabelColor, @cLabelSize, @cLabelRatio, @nTotQty)

      SET @nIndex = @nIndex + 1 
   END

   -- Insert End Label data
--    INSERT INTO @t_Result (Divider, Indicator, UserID, NoOfCopy, 
--                           ParentSKU, Style, Color, Size, Ratio, TotQty)
--    VALUES ('***********************************','END',@cUserID, @nNoOfCopy, 
--            '', '', '', '', '', 0)
   -- (YokeBeen01) - End 

Quit:
   SELECT * FROM @t_Result 
   ORDER BY CartonNo 
END




GO