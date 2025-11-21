SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PrintPrePackLabel_Master02                     */
/* Creation Date: 03-Jun-2010                                           */
/* Copyright: IDS                                                       */
/* Written by: ChewKP                                                   */
/*                                                                      */
/* Purpose: To print Master Label of Pre-Pack for UK Operation.         */
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
/* 26-07-2010   ChewKP    Add in BillOfMaterial.ComponentSKU (ChewKP01) */
/* 29-06-2011   James     SOS219645 - Add SKU.Size (james01)            */
/* 05-07-2011   James     SOS220090 - Add SKU Descr & Size into header  */
/*                                    section (james02)                 */
/* 12-MAY-2012  YTWan     SOS#244023-RDTBOMLabel - Company Logo change. */
/*                        (Wan01)                                       */
/* 22-MAY-2012  YTWan     SOS#244023-RDTBOMLabel - Print Gender on label*/
/*                        (Wan02)                                       */
/************************************************************************/
CREATE PROC [dbo].[isp_PrintPrePackLabel_Master02] (
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
           @nIndex        int,
           @cDescr        NVARCHAR(60),
           @cBOMSKU       NVARCHAR(20),
			  @cCaseID		  NVARCHAR(8),
			  @cCaseIDPreFix NVARCHAR(1),
			  @nNoOfCopyLBL  int,
			  @nIndex2		  int,
			  @c_packkey     NVARCHAR(10),
			  @n_CaseCnt     int,
			  @n_TotalBOMQTY int,
			  @nCaseQty      int,
			  @nLabelCount   int,
			  @nTotalLabel	  int,
			  @cComponentSKU NVARCHAR(20) -- (ChewKP01)
         , @c_Gender      NVARCHAR(30)  --(Wan02)
		  
           
           
--           @cUserID       NVARCHAR(18) -- (YokeBeen01)

   DECLARE @t_Result Table (
           UserID         NVARCHAR(18), 
           NoOfCopy       NVARCHAR(5), 
           BOMSKU         NVARCHAR(20),
           SKUDescr       NVARCHAR(60),
           TotQty         NVARCHAR(5), 
           LBLDate        NVARCHAR(10),
			  CaseID			  NVARCHAR(9),
			  DataType       NVARCHAR(10),
			  TotalLabel     NVARCHAR(5),
			  ComponentSKU   NVARCHAR(20), -- (ChewKP01)
           SKUSize        NVARCHAR(5)  -- (james01)  
         , Storerkey      NVARCHAR(15)  --(Wan01) 
         , Gender         NVARCHAR(30)  --(Wan02)
           )

   SET @cUPC = ''
	SET @cCaseIDPreFix = '9'
	SET @nLabelCount = 0
   SET @nTotalLabel = 0

   SET @c_Gender    = ''               --(Wan02)

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

	   
--	SELECT @n_TotalBOMQTY = SUM(QTY) ,@c_CompoenentSKU = ComponentSKU  FROM dbo.BILLOFMATERIAL (NOLOCK) -- (ChewKP01)
--	WHERE SKU = @c_BOMSKU
--	AND STORERKEY = @cStorerKey
--	GROUP BY ComponentSKU
		   

	
   SELECT DISTINCT 
      @cBOMSKU = BOM.SKU ,
      @n_TotalBOMQTY = BOM.Qty, 
      @cDescr = SKU.Descr, 
      @cComponentSKU = BOM.ComponentSKU,     -- (ChewKP01)
      @cSize = SKU.Size                      -- (james01)
      --(Wan02) - START
     ,@c_Gender = CASE WHEN ISNULL(RTRIM(SKU.busr5),'') IN ( '', 'W', 'Z') THEN 'WOMEN'
                       WHEN ISNULL(RTRIM(SKU.busr5),'') =  ( 'M' ) THEN 'MEN'
                  END
      --(Wan02) - END
      FROM   BillOfMaterial BOM WITH (NOLOCK) 
      JOIN   SKU WITH (NOLOCK) ON (BOM.StorerKey = SKU.StorerKey AND BOM.ComponentSku = SKU.SKU)
      WHERE  BOM.StorerKey = @cStorerKey 
      AND    BOM.SKU = @cParentSKU
      ORDER BY BOM.SKU
   
      
   
   SELECT  @c_packkey = Packkey FROM UPC (NOLOCK)
   WHERE SKU = @cParentSKU

   SELECT @n_CaseCnt = CaseCnt FROM dbo.PACK (NOLOCK)
	WHERE PACKKEY = @c_packkey
		
   SET @nCaseQty = 0
	      
--	SET @nCaseQty = (@n_TotalBOMQTY * @n_CaseCnt)
   SET @nCaseQty = (@n_TotalBOMQTY * 1)
	
   SET @nIndex = 1
   
   SET @nNoOfCopyLBL = rdt.RDTGetConfig( 0, 'PrintMultiBOMLabel', @cStorerKey)

   -- Insert Header Label Data 
   INSERT INTO @t_Result (UserID, DataType, SKUDescr, SKUSize, Storerkey, Gender)--(Wan01 & Wan02)
            VALUES (@cUserID,'HEADER', @cDescr, SUBSTRING(RTRIM(@cSize), 1, 4)   -- (james02)
                  , @cStorerKey                                                  --(Wan01)
                  , @c_Gender                                                    --(Wan02)
                  )
	
   -- Insert Detail Label data
   WHILE @nIndex <= @nNoOfCopy 
   BEGIN
      IF @b_debug = 1
      BEGIN 
         SELECT '@nIndex/@nNoOfCopy: ', @nIndex, '/', @nNoOfCopy
      END 
      
      EXECUTE dbo.nspg_getkey       
                     'CaseID'      
                     , 7      
                     , @cCaseID OUTPUT      
                     , @b_success OUTPUT      
                     , @n_err OUTPUT      
                     , @c_errmsg OUTPUT      

	   SET @cCaseID = @cCaseIDPreFix + ISNULL(RTrim(@cCaseID),'')
      

			SET @nIndex2 = 1 

         WHILE  @nIndex2 <= @nNoOfCopyLBL 
         BEGIN

            INSERT INTO @t_Result (UserID, NoOfCopy, BOMSKU, SKUDescr, TotQty, LBLDate, CaseID, DataType, ComponentSKU, SKUSize -- (ChewKP01)
                        , Storerkey, Gender                                                                                     -- (Wan01 & Wan02)
                        )
            VALUES ( 
                     @cUserID,
                     CAST(@nNoOfCopy AS NVARCHAR(5)), 
                     @cBOMSKU, 
                     @cDescr, 
                     CAST(@nCaseQty AS NVARCHAR(5)), 
                     Convert( NVARCHAR(10), getdate(),103) , 
                     @cCaseID, 'DETAIL' , 
                     @cComponentSKU, 
                     SUBSTRING(RTRIM(@cSize), 1, 4)   --FBR request to have always be a maximum of 4 characters (james01)
                   , @cStorerKey                                                                                              --(Wan01)
                   , @c_Gender                                                                                                --(Wan02)
                  ) 
		
				SET @nIndex2 = @nIndex2 + 1 
				
				SET @nLabelCount = @nLabelCount + 1
         END
      
		
		
      SET @nIndex = @nIndex + 1 
   END
   

Quit:
   SET @nTotalLabel = @nLabelCount 
   
   UPDATE @t_Result 
   SET TotalLabel = CAST(@nTotalLabel AS NVARCHAR(5))
   WHERE DataType = 'HEADER'
   
   
   SELECT * FROM @t_Result Order By DataType Desc
	--Select 'UserID' , '1' , '65491003' , 'SC SHADOW PINTUCK   90WHITE' , '10' , '16/07/2010' , '90001857' ,'DETAIL'  , ''      
	--Select 'ckpname' , '1' , '65491003' , 'SC SHADOW PINTUCK   90WHITE' , '10' , '16/07/2010' , '90001857' ,'HEADER'  , '4' , '65491099'   
   
END

GO