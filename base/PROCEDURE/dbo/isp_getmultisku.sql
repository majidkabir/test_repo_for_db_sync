SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_GetMultiSku                                    */
/* Creation Date:                                                       */
/* Copyright: LF                                                        */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: 289513-Get sku from packing module                          */
/*                                                                      */
/* Called By:                                                           */
/*                                                                      */
/* Version: 1.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 27-Jan-2016  NJOW01   1.0  358206 - Add storerconfig                 */
/*                            PackAltSkuAutoAssignMultiSku              */
/* 23/06/2016  CSCHONG   1.1 370698-Add option'3'to storerconfig        */
/*                            PackGetSkuByAltWithOrder to return multi  */
/*                            sku found error from barcode (CS01)       */
/************************************************************************/              

CREATE PROC    [dbo].[isp_GetMultiSku]
               @c_Pickslipno  NVARCHAR(10)
,              @c_StorerKey   NVARCHAR(15)      OUTPUT 
,              @c_sku         NVARCHAR(20)      OUTPUT
AS

BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_continue int,
           @c_Orderkey NVARCHAR(10),
           @c_Loadkey NVARCHAR(10),
           @c_PackGetSkuByAltWithOrder NVARCHAR(10),
           @c_PackAltSkuAutoAssignMultiSku NVARCHAR(10), --NJOW01
           @c_Facility NVARCHAR(5), --NJOW01
           @c_source NVARCHAR(20),
           @b_Success  INT,           
           @n_Err      INT,           
           @c_ErrMsg   NVARCHAR(250)            
           
   SELECT @n_continue = 1
   SELECT @c_Source = ''
   
   CREATE TABLE #TMP_SKU (Storerkey NVARCHAR(15), Sku NVARCHAR(20))
   
   SELECT @c_Orderkey = Orderkey
   FROM PICKHEADER(NOLOCK)
   WHERE PickHeaderkey = @c_Pickslipno
   
   IF ISNULL(@c_Orderkey,'') = ''
   BEGIN
   	  SELECT @c_Loadkey = ExternOrderkey
      FROM PICKHEADER(NOLOCK)
      WHERE PickHeaderkey = @c_Pickslipno

      IF ISNULL(@c_StorerKey,'') = ''
      BEGIN
      	 SELECT TOP 1 @c_Storerkey = Storerkey,
      	              @c_Facility = Facility --NJOW01
      	 FROM ORDERS (NOLOCK)
      	 WHERE Loadkey = @c_Loadkey
      END
   END
   ELSE
   BEGIN
      IF ISNULL(@c_StorerKey,'') = ''
      BEGIN
      	 SELECT @c_Storerkey = Storerkey,
 	              @c_Facility = Facility --NJOW01
      	 FROM ORDERS (NOLOCK)
      	 WHERE Orderkey = @c_Orderkey
      END
   END

   EXEC nspGetRight @c_Facility, -- facility      
      @c_StorerKey,  -- StorerKey      
      NULL, -- Sku      
      'PackGetSkuByAltWithOrder', -- Configkey      
      @b_success     output,      
      @c_PackGetSkuByAltWithOrder output,       
      @n_err         output,      
      @c_errmsg      output      

   EXEC nspGetRight @c_Facility, -- facility      
      @c_StorerKey,  -- StorerKey      
      NULL, -- Sku      
      'PackAltSkuAutoAssignMultiSku', -- Configkey      
      @b_success     output,      
      @c_PackAltSkuAutoAssignMultiSku output,       
      @n_err         output,      
      @c_errmsg      output      
         
   IF (@c_PackGetSkuByAltWithOrder IN ('1','2','3') OR @c_PackAltSkuAutoAssignMultiSku = '1') --NJOW01        --(CS01)
      AND (ISNULL(@c_Orderkey,'') <> '' OR ISNULL(@c_loadkey,'') <> '') 
   BEGIN
   	  IF ISNULL(@c_Orderkey,'') <> ''
   	  BEGIN
         IF EXISTS (SELECT OD.* FROM ORDERDETAIL OD (NOLOCK)  
                    WHERE OD.Sku = @c_sku 
                    AND OD.Orderkey = @c_Orderkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku) VALUES (@c_Storerkey, @c_Sku)
            SELECT @c_Source = 'SKU'         	  
            GOTO QUIT
         END

         IF EXISTS (SELECT SKU.* FROM ORDERDETAIL OD (NOLOCK) JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
                    WHERE SKU.AltSku = @c_sku and SKU.StorerKey = @c_StorerKey
                    AND OD.Orderkey = @c_Orderkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT SKU.Storerkey, SKU.Sku FROM ORDERDETAIL OD (NOLOCK) JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
            WHERE SKU.AltSku = @c_sku and SKU.StorerKey = @c_StorerKey
            AND OD.Orderkey = @c_Orderkey
            SELECT @c_Source = 'ALTSKU'
            GOTO QUIT
         END
         
         IF EXISTS (SELECT SKU.* FROM ORDERDETAIL OD (NOLOCK) JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
                    WHERE SKU.RetailSku = @c_sku and SKU.StorerKey = @c_StorerKey
                    AND OD.Orderkey = @c_Orderkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT SKU.Storerkey, SKU.Sku FROM ORDERDETAIL OD (NOLOCK) JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
            WHERE SKU.RetailSku = @c_sku and SKU.StorerKey = @c_StorerKey
            AND OD.Orderkey = @c_Orderkey
            SELECT @c_Source = 'RETAILSKU'           
            GOTO QUIT
         END
         
         IF EXISTS (SELECT SKU.* FROM ORDERDETAIL OD (NOLOCK) JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
                    WHERE SKU.ManufacturerSku = @c_sku and SKU.StorerKey = @c_StorerKey
                    AND OD.Orderkey = @c_Orderkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT SKU.Storerkey, SKU.Sku FROM ORDERDETAIL OD (NOLOCK) JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
            WHERE SKU.ManufacturerSku = @c_sku and SKU.StorerKey = @c_StorerKey
            AND OD.Orderkey = @c_Orderkey
            SELECT @c_Source = 'MANUFACTURERSKU'
            GOTO QUIT
         END
                 
         IF EXISTS (SELECT UPC.* FROM ORDERDETAIL OD (NOLOCK) JOIN UPC (NOLOCK) ON OD.Storerkey = UPC.Storerkey AND OD.Sku = UPC.Sku
                        WHERE UPC.UPC = @c_sku and UPC.StorerKey = @c_StorerKey AND OD.Orderkey = @c_Orderkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT UPC.Storerkey, UPC.Sku FROM ORDERDETAIL OD (NOLOCK) JOIN UPC (NOLOCK) ON OD.Storerkey = UPC.Storerkey AND OD.Sku = UPC.Sku
            WHERE UPC.UPC = @c_sku and UPC.StorerKey = @c_StorerKey
            AND OD.Orderkey = @c_Orderkey
            SELECT @c_Source = 'UPCSKU'
         END
      END
      ELSE
      BEGIN
      	 IF EXISTS (SELECT OD.* FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
            WHERE OD.Sku = @c_sku
            AND O.Loadkey = @c_Loadkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku) VALUES (@c_Storerkey, @c_Sku)
            SELECT @c_Source = 'SKU'         	  
            GOTO QUIT
         END

         IF EXISTS (SELECT SKU.* FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                    JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
                    WHERE SKU.AltSku = @c_sku and SKU.StorerKey = @c_StorerKey
                    AND O.Loadkey = @c_Loadkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT SKU.Storerkey, SKU.Sku FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
            JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
            WHERE SKU.AltSku = @c_sku and SKU.StorerKey = @c_StorerKey
            AND O.Loadkey = @c_Loadkey
            SELECT @c_Source = 'ALTSKU'            
            GOTO QUIT
         END
         
         IF EXISTS (SELECT SKU.* FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                    JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
                    WHERE SKU.RetailSku = @c_sku and SKU.StorerKey = @c_StorerKey
                    AND O.Loadkey = @c_Loadkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT SKU.Storerkey, SKU.Sku FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
            JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
            WHERE SKU.RetailSku = @c_sku and SKU.StorerKey = @c_StorerKey
            AND O.Loadkey = @c_Loadkey
            SELECT @c_Source = 'RETAILSKU'            
            GOTO QUIT
         END
         
         IF EXISTS (SELECT SKU.* FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
                    JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
                    WHERE SKU.ManufacturerSku = @c_sku and SKU.StorerKey = @c_StorerKey
                    AND O.Loadkey = @c_Loadkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT SKU.Storerkey, SKU.Sku FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
            JOIN SKU (NOLOCK) ON OD.Storerkey = SKU.Storerkey AND OD.Sku = SKU.Sku  
            WHERE SKU.ManufacturerSku = @c_sku and SKU.StorerKey = @c_StorerKey
            AND O.Loadkey = @c_Loadkey
            SELECT @c_Source = 'MANUFACTURERSKU'            
            GOTO QUIT
         END
                 
         IF EXISTS (SELECT UPC.* FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey JOIN
                        UPC (NOLOCK) ON OD.Storerkey = UPC.Storerkey AND OD.Sku = UPC.Sku 
                        WHERE UPC.UPC = @c_sku and UPC.StorerKey = @c_StorerKey AND O.Loadkey = @c_Loadkey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT UPC.Storerkey, UPC.Sku FROM ORDERS O (NOLOCK) JOIN ORDERDETAIL OD (NOLOCK) ON O.Orderkey = OD.Orderkey
            JOIN UPC (NOLOCK) ON OD.Storerkey = UPC.Storerkey AND OD.Sku = UPC.Sku
            WHERE UPC.UPC = @c_sku and UPC.StorerKey = @c_StorerKey
            AND O.Loadkey = @c_Loadkey
            SELECT @c_Source = 'UPCSKU'
         END
      END      
   END
   ELSE
   BEGIN
   	 --Normal
      IF NOT EXISTS (SELECT * FROM SKU (NOLOCK) WHERE Sku = @c_sku and StorerKey = @c_StorerKey)
      BEGIN
         IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE AltSku = @c_sku and StorerKey = @c_StorerKey)
         BEGIN
         	  INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT Storerkey, Sku FROM SKU (NOLOCK) WHERE AltSku = @c_sku and StorerKey = @c_StorerKey
            SELECT @c_Source = 'ALTSKU'
            GOTO QUIT
         END
         
         IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey)
         BEGIN
            INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT Storerkey, Sku FROM SKU (NOLOCK) WHERE RetailSku = @c_sku and StorerKey = @c_StorerKey
            SELECT @c_Source = 'RETAILSKU'
            GOTO QUIT
         END
         
         IF EXISTS (SELECT * FROM SKU (NOLOCK) WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey)
         BEGIN
            INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT Storerkey, Sku FROM SKU (NOLOCK) WHERE ManufacturerSku = @c_sku and StorerKey = @c_StorerKey
            SELECT @c_Source = 'MANUFACTURERSKU'
            GOTO QUIT
         END
                 
         IF EXISTS (SELECT * FROM UPC (NOLOCK) WHERE UPC = @c_sku and StorerKey = @c_StorerKey)
         BEGIN
            INSERT INTO #TMP_SKU (Storerkey, Sku)
            SELECT Storerkey, Sku FROM UPC (NOLOCK) WHERE UPC = @c_sku and StorerKey = @c_StorerKey
            SELECT @c_Source = 'UPCSKU'
         END
      END
      ELSE
      BEGIN
       	 INSERT INTO #TMP_SKU (Storerkey, Sku) VALUES (@c_Storerkey, @c_Sku)
         SELECT @c_Source = 'SKU'
      END
   END
         
   QUIT:

   SELECT * FROM #TMP_SKU ORDER BY SKU
   
END

GO