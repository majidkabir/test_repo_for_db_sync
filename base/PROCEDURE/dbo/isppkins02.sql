SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: ispPKINS02                                          */
/* Copyright      : LF                                                  */
/*                                                                      */
/* Purpose: WMS-4405 - SG NikeSG- get header pack instruction           */
/*                                                                      */
/* Called from: isp_PackGetInstruction_Wrapper                          */
/*              storerconfig: PackGetInstruction_SP                     */
/*                                                                      */
/* Exceed version: 7.0                                                  */
/*                                                                      */
/* Modifications log:                                                   */
/*                                                                      */
/* Date        Rev  Author     Purposes                                 */
/* 01-Jul-2021 1.0  NJOW01     WMS-17290 Sku pack instruction for single*/
/*                             order pack                               */
/* 19-Sep-2022 1.1  NJOW02     WMS-20807 prompt alert for DG product    */
/* 19-Sep-2022 1.1  NJOW02     DEVOPS Combine Script                    */
/* 05-Jan-2023 1.2  NJOW03     WMS-21380 Suggest carton type for ecom   */
/* 26-Apr-2023 1.3  NJOW04     WMS-22448 Change multi logic of >= 3     */
/* 29-Jun-2023 1.4  NJOW05     WMS-22945 add sku alert for 1BOXRemoveUCC*/
/************************************************************************/

CREATE   PROCEDURE [dbo].[ispPKINS02]
   @c_Pickslipno       NVARCHAR(10),
   @c_Storerkey        NVARCHAR(15),
   @c_Sku              NVARCHAR(50),  --if call from pack header sku no value(header instruction), if from packdetail sku have value(item instruction)
   @c_PackInstruction  NVARCHAR(500) OUTPUT,  --NJOW01
   @b_Success          INT      OUTPUT,
   @n_ErrNo            INT      OUTPUT, 
   @c_ErrMsg           NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON 
   SET QUOTED_IDENTIFIER OFF 
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @c_countryname    NVARCHAR(50),
           @c_ProductModel   NVARCHAR(30),
           @c_OrderGroup     NVARCHAR(20)
   
   --NJOW03        
   DECLARE @c_Orderkey           NVARCHAR(10), 
           @n_SumOrdQty          INT = 0,       
           @c_Division           NVARCHAR(30),
           @c_Gender             NVARCHAR(30),
           @c_Size               NVARCHAR(10),
           @c_CartonType         NVARCHAR(10) = '',
           @c_CartonGroup        NVARCHAR(10) = ''
                                 
   SELECT @b_Success = 1, @n_ErrNo = 0, @c_ErrMsg = '', @c_PackInstruction = ''
        
   IF ISNULL(@c_Sku,'') = ''  --only get header instruction
   BEGIN   	
   	  SELECT @c_countryname = CASE WHEN ISNULL(CL.Long,'') <> '' THEN CL.Long ELSE O.c_isocntrycode END
   	  FROM PICKHEADER PH (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   	  LEFT JOIN CODELKUP CL (NOLOCK) ON  O.c_isocntrycode = CL.Code AND CL.Listname = 'ISOCOUNTRY'
   	  WHERE PH.Pickheaderkey = @c_Pickslipno   	  
   	  
   	  IF ISNULL(@c_countryname,'') <> ''
   	     SET @c_PackInstruction = 'Country: ' + @c_countryname
   	     
   	  --NJOW03 S
   	  SELECT @c_OrderGroup = O.OrderGroup,
   	         @c_Orderkey = O.Orderkey,
   	         @c_CartonGroup = STORER.CartonGroup,
   	         @n_SumOrdQty = SUM(OD.OpenQty)
   	  FROM PICKHEADER PH (NOLOCK)
   	  JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   	  JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
   	  JOIN STORER (NOLOCK) ON O.Storerkey = STORER.Storerkey
   	  WHERE PH.Pickheaderkey = @c_Pickslipno   
   	  GROUP BY O.OrderGroup,
   	           O.Orderkey,
   	           STORER.CartonGroup
   	     	     	  
   	  IF @c_OrderGroup IN('SINGLE','MULTI')  --ECOM Order
   	  BEGIN
   	     SELECT SKU.Busr7 AS Division,  --10=Apparel(AP) 20=Footwear(FW) 30=Equipment(EQ)
   	            SUBSTRING(SKU.Sku, 10, LEN(SKU.Sku)-9) AS Size,
   	            ISNULL(CL.Short,'') AS Gender, --MENS, WOMEN, KIDS
   	            SUM(OD.OpenQty) AS Qty
   	     INTO #TMP_SKUREF
   	     FROM ORDERDETAIL OD (NOLOCK)
   	     JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
   	     LEFT JOIN CODELKUP CL (NOLOCK) ON CL.Storerkey = SKU.Storerkey AND CL.Listname = 'NGENDERAGE' AND CL.Code = SKU.Busr4
   	     WHERE OD.Orderkey = @c_Orderkey
   	     GROUP BY SKU.Busr7,                             
                  SUBSTRING(SKU.Sku, 10, LEN(SKU.Sku)-9),   
                  ISNULL(CL.Short,'')
   	  	
   	  	 IF @n_SumOrdQty = 1
   	  	 BEGIN
   	  	 	  IF EXISTS(SELECT 1 FROM #TMP_SKUREF WHERE Division = '20') --FW
   	  	 	  BEGIN
   	  	 	     SELECT TOP 1 @c_CartonType = CL.UDF01
   	  	 	     FROM #TMP_SKUREF SR 
   	  	 	     JOIN CODELKUP CL (NOLOCK) ON CL.Code = SR.Division AND CL.Short = SR.Size AND CL.Long = SR.Gender AND CL.ListName = 'NPACKAGING' AND CL.Storerkey = @c_Storerkey
   	  	 	  END
   	  	 	  ELSE --AP or EQ
   	  	 	     SET @c_CartonType = 'APME305'   	  	 	    	  	 	  
   	  	 END
   	  	 
   	  	 IF @n_SumOrdQty = 2
   	  	 BEGIN
   	  	 	  IF EXISTS(SELECT 1 FROM #TMP_SKUREF WHERE Division = '20' HAVING SUM(Qty) = 2) -- 2FW
   	  	 	  BEGIN
   	  	 	     SELECT TOP 1 @c_CartonType = CL.UDF02
   	  	 	     FROM #TMP_SKUREF SR 
   	  	 	     JOIN CODELKUP CL (NOLOCK) ON CL.Code = SR.Division AND CL.Short = SR.Size AND CL.Long = SR.Gender AND CL.ListName = 'NPACKAGING' AND CL.Storerkey = @c_Storerkey   	  
   	  	 	     JOIN CARTONIZATION CZ (NOLOCK) ON CZ.CartonizationGroup = @c_CartonGroup AND CZ.CartonType = CL.UDF02
   	  	 	     ORDER BY (CZ.CartonLength * CZ.CartonWidth * CZ.CartonHeight) DESC
   	  	    END

   	  	 	  IF EXISTS(SELECT 1 FROM #TMP_SKUREF WHERE Division = '20' HAVING SUM(Qty) = 1) -- 1FW+1AP or 1FW+1EQ
   	  	 	  BEGIN
   	  	 	     SELECT TOP 1 @c_CartonType = CL.UDF03
   	  	 	     FROM #TMP_SKUREF SR 
   	  	 	     JOIN CODELKUP CL (NOLOCK) ON CL.Code = SR.Division AND CL.Short = SR.Size AND CL.Long = SR.Gender AND CL.ListName = 'NPACKAGING' AND CL.Storerkey = @c_Storerkey
   	  	 	     WHERE SR.Division = '20' --Get from FW
   	  	    END
   	  	    
   	  	    IF NOT EXISTS(SELECT 1 FROM #TMP_SKUREF WHERE Division = '20') --1AP+1EQ or 1AP+1AP or 1EQ+1EQ
   	  	       SET @c_CartonType = 'APME305'    	  	        
   	  	 END
   	  	 
   	  	 IF @n_SumOrdQty >= 3
   	  	 BEGIN
   	  	    IF EXISTS(SELECT 1 FROM #TMP_SKUREF HAVING SUM(CASE WHEN Division IN('10','30') THEN 1 ELSE 0 END) = 0
   	  	                AND SUM(CASE WHEN Division IN('20') THEN 1 ELSE 0 END) > 0)  --FW only
   	  	    BEGIN
   	  	       SET @c_CartonType = 'OTHERS' --NJOW04
   	  	    END            

   	  	 	  IF EXISTS(SELECT 1 FROM #TMP_SKUREF WHERE Division = '20' HAVING SUM(Qty) = 2) -- 2FW + APP/EQ 
   	  	 	  BEGIN
   	  	 	     SELECT TOP 1 @c_CartonType = CL.UDF04 --NJOW04
   	  	 	     FROM #TMP_SKUREF SR 
   	  	 	     JOIN CODELKUP CL (NOLOCK) ON CL.Code = SR.Division AND CL.Short = SR.Size AND CL.Long = SR.Gender AND CL.ListName = 'NPACKAGING' AND CL.Storerkey = @c_Storerkey   	  
   	  	 	     JOIN CARTONIZATION CZ (NOLOCK) ON CZ.CartonizationGroup = @c_CartonGroup AND CZ.CartonType = CL.UDF04
   	  	 	     WHERE SR.Division = '20'  --Get from FW
   	  	 	     ORDER BY (CZ.CartonLength * CZ.CartonWidth * CZ.CartonHeight) DESC
   	  	    END   	  	       	  	      	  	    
   	  	    
  	  	 	  IF EXISTS(SELECT 1 FROM #TMP_SKUREF WHERE Division = '20' HAVING SUM(Qty) = 1) -- 1FW + APP/EQ 
   	  	 	  BEGIN
   	  	 	     SELECT TOP 1 @c_CartonType = CL.UDF03
   	  	 	     FROM #TMP_SKUREF SR 
   	  	 	     JOIN CODELKUP CL (NOLOCK) ON CL.Code = SR.Division AND CL.Short = SR.Size AND CL.Long = SR.Gender AND CL.ListName = 'NPACKAGING' AND CL.Storerkey = @c_Storerkey
   	  	 	     WHERE SR.Division = '20' --Get from FW
   	  	 	  END
   	  	 	  
            IF NOT EXISTS(SELECT 1 FROM #TMP_SKUREF WHERE Division = '20') --AP+EQ or AP+AP or EQ+EQ
   	  	       SET @c_CartonType = 'APME380'    	  	           	  	 	  
   	  	 END   	  	 
   	  	 
   	     IF ISNULL(@c_CartonType,'') <> ''
   	     BEGIN
   	        SET @c_PackInstruction = RTRIM(@c_PackInstruction) + IIF(ISNULL(@c_PackInstruction,'') <> '', '   ', '') + 'Carton Type: ' + @c_CartonType
   	     END   	  	 
   	  END   	     	  
   	  --NJOW03 E
   END
   
   --NJOW01
   IF ISNULL(@c_Sku,'') <> ''  --only get detail instruction for single order pack
   BEGIN   	                                    
   	  --NJOW02 S                              
   	  SELECT TOP 1 @c_OrderGroup = O.OrderGroup,
   	               @c_ProductModel = SKU.ProductModel
   	  FROM PICKHEADER PH (NOLOCK)
      JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
      JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
      JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
      WHERE PH.Pickheaderkey = @c_Pickslipno
      AND OD.Sku = @c_Sku
                      
      IF @c_OrderGroup = 'SINGLE' AND @c_ProductModel = '1BOX'
      BEGIN
         SET @c_PackInstruction = '1 BOX SKU. No Shipping Box Required!' 
      END          
      ELSE IF @c_OrderGroup IN('SINGLE','MULTI') AND @c_ProductModel = 'DG'
      BEGIN
         SET @c_PackInstruction = 'Paste DG Label' 
      END         
      ELSE IF @c_OrderGroup = 'SINGLE' AND @c_ProductModel = '1BOXRemoveUCC'  --NJOW05
      BEGIN 
      	 SET @c_PackInstruction = '1 BOX SKU. Remove UCC' 
      END
      --NJOW02 E

      /*
   	  IF EXISTS(SELECT 1
                FROM PICKHEADER PH (NOLOCK)
                JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
                JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku
                WHERE PH.Pickheaderkey = @c_Pickslipno
                AND OD.Sku = @c_Sku
                AND SKU.ProductModel = '1BOX'
                AND O.OrderGroup = 'SINGLE'         
                )
      BEGIN
         SET @c_PackInstruction = '1 BOX SKU. No Shipping Box Required!'
      END    
      */ 
   END
END -- End Procedure


GO