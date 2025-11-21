SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_NikeGetVASCode                                 */
/* Creation Date: 24-Jan-2018                                           */
/* Copyright: LFL                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: Getting promotion code from OMS database                    */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* PVCS Version: 7                                                      */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Rev   Purposes                                  */
/************************************************************************/
CREATE PROCEDURE [dbo].[isp_NikeGetVASCode] ( 
	 @c_OrderKey   NVARCHAR(10) 
  , @c_VASCode    VARCHAR(200) OUTPUT 
  , @b_Success    BIT = 1 OUTPUT 
  , @n_ErrNo      INT = 0 OUTPUT 
  , @c_ErrMsg     NVARCHAR(250) = ''  OUTPUT 
  , @b_Debug      BIT = 0    
) 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS ON 
   SET ANSI_WARNINGS ON 
   SET QUOTED_IDENTIFIER ON  
   SET ANSI_PADDING ON 
   

   DECLARE	
      @c_City       NVARCHAR(20) = ''
    , @c_OrderValue NVARCHAR(18) = ''
    , @d_OrderDate  DATETIME
    , @c_OrderType  NVARCHAR(10) = ''
    , @c_StorerKey  NVARCHAR(15) = ''
    , @n_OpenQty    INT = 0 
    , @n_DT_OpenQty INT = 0 
    , @n_DT_Amount  MONEY = 0 
    , @n_ProdCatgr  NVARCHAR(20) 
    , @c_ShopCode   NVARCHAR(20) = ''
 
   DECLARE 
   	@c_SQLExec      NVARCHAR(2000)
    , @c_OMSDBName    NVARCHAR(20) = ''
    
   DECLARE @t_PromoOrd AS PromoOrders;
   DECLARE @t_PromoOrdDet AS PromoOrderDetail;
   
   SET @b_Success = 1
   
   --INSERT INTO NSQLCONFIG(ConfigKey, NSQLValue, NSQLDefault, NSQLDescrip)
   --VALUES ('OMSDBName', 'CNOMS', '', 'OMS Database')
   
   SELECT @c_OMSDBName = NSQLValue 
   FROM nsqlConfig WITH (NOLOCK) 
   WHERE ConfigKey = 'OMSDBName'   

   SELECT  @c_OrderType = o.[Type] 
         , @c_City = o.C_City
         , @c_OrderValue = o.UserDefine05 
         , @d_OrderDate = o.OrderDate
         , @c_StorerKey = o.StorerKey 
         , @n_OpenQty   = o.OpenQty 
         , @c_ShopCode  = o.OrderGroup
   FROM ORDERS AS o WITH(NOLOCK)
   WHERE o.OrderKey = @c_OrderKey

   INSERT INTO @t_PromoOrd VALUES (@c_OrderKey, @c_StorerKey, @d_OrderDate, @c_OrderValue, @n_OpenQty, @c_City, @c_ShopCode)

   DECLARE @c_OrderLineNumber nvarchar(5), @c_Sku nvarchar(20), @c_OpenQty int

   DECLARE C_ORDERDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT OD.OrderLineNumber
         , OD.Sku
         , OD.OpenQty
         , ISNULL(SKU.SUSR4,'') AS ProductCategory
         , OD.OpenQty * ISNULL(OD.UnitPrice,0) 
   FROM ORDERDETAIL AS OD WITH (NOLOCK)
   JOIN SKU AS SKU WITH(NOLOCK) ON SKU.Sku = OD.Sku AND SKU.StorerKey = OD.StorerKey 
   WHERE OD.OrderKey = @c_OrderKey

   OPEN C_ORDERDETAIL

   FETCH FROM C_ORDERDETAIL INTO @c_OrderLineNumber, @c_Sku, @n_DT_OpenQty, @n_ProdCatgr, @n_DT_Amount
                                                           
   WHILE @@FETCH_STATUS = 0
   BEGIN
      INSERT INTO @t_PromoOrdDet VALUES(@c_OrderKey,@c_OrderLineNumber,@c_StorerKey, @c_Sku, @n_DT_OpenQty, @n_DT_Amount, @n_ProdCatgr)

	   FETCH FROM C_ORDERDETAIL INTO @c_OrderLineNumber, @c_Sku, @n_DT_OpenQty, @n_ProdCatgr, @n_DT_Amount
   END
   CLOSE C_ORDERDETAIL
   DEALLOCATE C_ORDERDETAIL

   DECLARE    @x_PromoOrd    XML 
            , @x_PromoOrdDet XML 

   SET  @x_PromoOrd = (SELECT * FROM @t_PromoOrd AS PromoOrd 
                       FOR XML AUTO, BINARY BASE64, ELEMENTS )
   SET  @x_PromoOrdDet = (SELECT * FROM @t_PromoOrdDet AS PromoOrdDet 
                       FOR XML AUTO, BINARY BASE64, ELEMENTS )    
   --SELECT * FROM @t_PromoOrd
   --SELECT * FROM @t_PromoOrdDet

   IF @b_Debug = 1
   BEGIN
   	SELECT  @x_PromoOrdDet
   	
      --SELECT O.c.value('OrderKey[1]', 'nvarchar(20)') AS OrderKey, 
      --          O.c.value('OrderLine[1]', 'nvarchar(5)') AS OrderLine,
      --          O.c.value('Storerkey[1]', 'nvarchar(15)') AS Storerkey,          
      --          O.c.value('SKU[1]', 'nvarchar(20)') AS SKU,
      --          O.c.value('Qty[1]', 'int') AS Qty,  
      --          O.c.value('LineAmt[1]', 'money') AS Amount,
      --          O.c.value('ProductCategory[1]', 'nvarchar(20)') AS ProdCat 
      --   FROM @x_PromoOrdDet.nodes('//PromoOrdDet') AS O(c)   	
   END


   SET @c_SQLExec = 
   N'EXEC ' + RTRIM(@c_OMSDBName) + '.OMS.osp_GetPromotionVASCode 
 	   @x_PromoOrd = @x_PromoOrd
    , @x_PromoOrdDet = @x_PromoOrdDet 
    , @c_VASCode = @c_VASCode OUTPUT
    , @b_Debug = @b_Debug ' 
   
   BEGIN TRY
      EXEC sp_ExecuteSql @c_SQLExec, 
       N'@x_PromoOrd AS XML,  @x_PromoOrdDet AS XML, @c_VASCode NVARCHAR(100) OUTPUT, @b_Debug BIT'
       , @x_PromoOrd, @x_PromoOrdDet, @c_VASCode OUTPUT, @b_Debug    	
   END TRY
   BEGIN CATCH
   		SELECT
   			@n_ErrNo  =  ERROR_NUMBER(),
   			@c_ErrMsg =  ERROR_MESSAGE()
         
         SET @c_VASCode = ''
   END CATCH 
   
	
END

GO