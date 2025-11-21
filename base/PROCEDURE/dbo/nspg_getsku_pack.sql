SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/************************************************************************/  
/* Stored Procedure: nspg_GETSKU_PACK                                   */  
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
/* 24/10/2014   NJOW01   1.0  320446-Add option '2' to storerconfig     */  
/*                            PackGetSkuByAltWithOrder to alert multi   */  
/*                            sku found from barcode                    */  
/* 23/06/2016  CSCHONG   1.1 370698-Add option'3'to storerconfig        */  
/*                            PackGetSkuByAltWithOrder to return multi  */  
/*                            sku found error from barcode (CS01)       */  
/* 21/03/2017  CSCHONG   1.2  Return UPPERCASE SKU (CS02)               */  
/* 05/04/2019  CSCHONG   1.3  WMS-8559 check active sku (CS03)          */  
/* 25/04/2019  SHONG     1.4  Performance Tuning                        */
/* 06/06/2019  TLTING01  1.5  Performance Tuning - OPTIMIZE             */
/* 13/02/2020  WLChooi   1.6  WMS-11775 - New Storerconfig              */
/*                            PackingNotAllowScanSKU to prevent user    */
/*                            scan SKU instead of UPC (WL01)            */
/* 03/09/2020  NJOW02    1.7  WMS-15009 CN Natural Beauty get sku from  */
/*                            Serial number                             */
/* 22/03/2023  NJOW03    1.8  WMS-21989 CN-Yonex get sku from SN->UPC   */
/* 15/05/2023  JHTAN01   1.9  JSM-141591 TW-Got SKU Selection screen if */    
/*                            found same sku in different orderline     */
/************************************************************************/                 
CREATE   PROC    [dbo].[nspg_GETSKU_PACK]  
               @c_PickSlipNo  NVARCHAR(10)  
,              @c_StorerKey   NVARCHAR(15)      OUTPUT   
,              @c_SKU         NVARCHAR(60)      OUTPUT  --NJOW03 chg to 60
,              @b_Success     INT               OUTPUT  
,              @n_Err         INT               OUTPUT  
,              @c_ErrMsg      NVARCHAR(250)     OUTPUT  
  
AS  
  
BEGIN
   SET NOCOUNT ON   
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_Continue                     INT
          ,@c_Orderkey                     NVARCHAR(10)
          ,@c_LoadKey                      NVARCHAR(10)
          ,@c_PackGetSkuByAltWithOrder     NVARCHAR(10)
          ,@n_SKUCnt                       INT
          ,@c_Source                       NVARCHAR(20)
          ,@c_SKUStatus                    NVARCHAR(20)	--CS03
          ,@n_Ctn                          INT --CS03 
          ,@c_FoundSKU                     NVARCHAR(20) = ''
          ,@c_FoundSKUStatus               NVARCHAR(20) = '' 
          ,@c_GetSkuBySerialNo             NVARCHAR(30) --NJOW02
          ,@c_GetSkuFromSN_UPC             NVARCHAR(30)=''   --NJOW03
   
   SELECT @n_Continue = 1
         ,@b_Success     = 1
         ,@n_Err         = 0
         ,@c_ErrMsg      = ''
   
   SELECT @n_SKUCnt = 0
         ,@c_Source = ''  
   
   SET @c_SKUStatus = 'ACTIVE' --CS03  
   SET @n_Ctn = 1 --CS03  
   
   SET @c_Orderkey = ''
   SET @c_LoadKey = ''
   
   SELECT @c_Orderkey = ISNULL(Orderkey,''), 
          @c_LoadKey = ISNULL(ExternOrderkey,'')
   FROM   PICKHEADER WITH (NOLOCK)
   WHERE  PickHeaderkey = @c_PickSlipNo  
   
   IF ISNULL(@c_Orderkey ,'')=''
   BEGIN        
      IF ISNULL(@c_StorerKey ,'')=''
      BEGIN
          SELECT TOP 1 @c_Storerkey = Storerkey
          FROM   ORDERS WITH (NOLOCK)
          WHERE  Loadkey = @c_LoadKey
      END
   END
   ELSE
   BEGIN
      IF ISNULL(@c_StorerKey ,'')=''
      BEGIN
          SELECT @c_Storerkey = Storerkey
          FROM   ORDERS WITH (NOLOCK)
          WHERE  Orderkey = @c_Orderkey
      END
   END  
   
   DECLARE @t_SKU TABLE (SKU NVARCHAR(20), SKUStatus NVARCHAR(20), Source NVARCHAR(20), SeqNo INT)
   
   EXEC nspGetRight 
        NULL	-- facility
       ,@c_StorerKey	-- StorerKey
       ,NULL	-- Sku
       ,'PackGetSkuByAltWithOrder'	-- Configkey
       ,@b_Success OUTPUT
       ,@c_PackGetSkuByAltWithOrder OUTPUT
       ,@n_Err OUTPUT
       ,@c_ErrMsg OUTPUT
   
   --NJOW02
   EXEC nspGetRight 
        @c_Facility  = NULL
       ,@c_StorerKey = @c_StorerKey
       ,@c_sku       = NULL                   
       ,@c_ConfigKey = 'GetSkuBySerialNo'
       ,@b_Success   = @b_success   OUTPUT             
       ,@c_authority = @c_GetSkuBySerialNo OUTPUT
       ,@n_err       = @n_err       OUTPUT             
       ,@c_errmsg    = @c_errmsg    OUTPUT             
    
   SELECT @c_GetSkuFromSN_UPC = dbo.fnc_GetRight('', @c_Storerkey, '', 'GetSkuFromSN_UPC')  --NJOW01
                   
   IF @c_PackGetSkuByAltWithOrder IN ('1' ,'2' ,'3') AND (ISNULL(@c_Orderkey ,'') <> '' OR ISNULL(@c_LoadKey ,'')<>'') --(CS01)
   BEGIN
      IF ISNULL(@c_Orderkey ,'') <> ''
      BEGIN
   	   SET @c_FoundSKU = ''
   	   SET @c_FoundSKUStatus = ''
         SET @c_Source = ''
      
         SELECT @c_FoundSKU = Sku, 
                @c_FoundSKUStatus = 'ACTIVE'
         FROM  ORDERDETAIL OD WITH (NOLOCK)
         WHERE OD.Sku = @c_SKU
           AND OD.Orderkey = @c_Orderkey
   	   IF ISNULL(@c_FoundSKU, '') = @c_SKU
   	   BEGIN
   		   SET @c_Source = 'SKU' 
   		   SET @c_SKUStatus = @c_FoundSKUStatus
   		   GOTO QUIT 
   	   END
   	   ELSE 
   	   BEGIN
   		   SET @c_Source = 'ALTSKU'      
   		
   		   INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
   		   SELECT SKU.Sku, SKU.SkuStatus, @c_Source, 1 
            FROM ORDERDETAIL OD (NOLOCK)
            JOIN SKU WITH (NOLOCK) ON  OD.Storerkey = SKU.Storerkey
                                   AND OD.Sku = SKU.Sku 
            WHERE SKU.StorerKey = @c_StorerKey 
            AND   SKU.AltSku = @c_SKU
            AND   OD.Orderkey = @c_Orderkey
         
            IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE')
            BEGIN
   		      SET @c_Source = 'RETAILSKU'      

   		      INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
   		      SELECT SKU.Sku, SKU.SkuStatus, @c_Source, 2 
               FROM ORDERDETAIL OD (NOLOCK)
               JOIN SKU WITH (NOLOCK) ON  OD.Storerkey = SKU.Storerkey
                                      AND OD.Sku = SKU.Sku 
               WHERE SKU.StorerKey = @c_StorerKey 
               AND   SKU.RETAILSKU = @c_SKU
               AND   OD.Orderkey = @c_Orderkey
            
               IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE')
               BEGIN
   		         SET @c_Source = 'MANUFACTURERSKU'      

   		         INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
   		         SELECT SKU.Sku, SKU.SkuStatus, @c_Source, 3 
                  FROM ORDERDETAIL OD (NOLOCK)
                  JOIN SKU WITH (NOLOCK) ON  OD.Storerkey = SKU.Storerkey
                                         AND OD.Sku = SKU.Sku 
                  WHERE SKU.StorerKey = @c_StorerKey 
                  AND   SKU.ManufacturerSku = @c_SKU
                  AND   OD.Orderkey = @c_Orderkey
                  		
                  IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE')
                  BEGIN
               	   SET @c_Source = 'UPCSKU'

   		            INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
                     SELECT s.Sku, 
                     CASE WHEN s.SkuStatus = 'ACTIVE' THEN s.SkuStatus ELSE 'INACTIVE' END, 
                     @c_Source, 4 
                     FROM  ORDERDETAIL OD (NOLOCK)
                     JOIN UPC (NOLOCK) ON  OD.Storerkey = UPC.Storerkey AND OD.Sku = UPC.Sku
                     JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = UPC.StorerKey AND s.Sku = UPC.SKU
                     WHERE OD.Orderkey = @c_Orderkey
                     AND UPC.StorerKey = @c_StorerKey 
                     AND UPC.UPC = @c_SKU                    
                                     	
                  END -- UPCSKU  
               END -- Manufacturer Sku             	
            END  -- Retail SKU                       		
   	   END -- If not found by SKU, AtlSKU 
      END -- IF ISNULL(@c_Orderkey ,'') <> ''
      ELSE
      IF ISNULL(@c_LoadKey ,'') <> ''
      BEGIN
   	   SET @c_FoundSKU = ''
   	   SET @c_FoundSKUStatus = ''
         SET @c_Source = ''
      
         SELECT @c_FoundSKU = Sku, 
                @c_FoundSKUStatus = 'ACTIVE'
         FROM  ORDERDETAIL OD WITH (NOLOCK)
         JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = OD.OrderKey
         WHERE OD.Sku = @c_SKU
           AND lpd.LoadKey = @c_Loadkey
   	   IF ISNULL(@c_FoundSKU, '') = @c_SKU
   	   BEGIN
   		   SET @c_Source = 'SKU' 
   		   SET @c_SKUStatus = @c_FoundSKUStatus
   		   GOTO QUIT 
   	   END
   	   ELSE 
   	   BEGIN
   		   SET @c_Source = 'ALTSKU'      
   		
   		   INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
   		   SELECT SKU.Sku, SKU.SkuStatus, @c_Source, 1 
            FROM ORDERDETAIL OD (NOLOCK)
            JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = OD.OrderKey
            JOIN SKU WITH (NOLOCK) ON  OD.Storerkey = SKU.Storerkey
                                   AND OD.Sku = SKU.Sku 
            WHERE SKU.StorerKey = @c_StorerKey 
            AND   SKU.AltSku = @c_SKU
            AND   LPD.LoadKey = @c_Loadkey
         
            IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE')
            BEGIN
   		      SET @c_Source = 'RETAILSKU'      

   		      INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
   		      SELECT SKU.Sku, SKU.SkuStatus, @c_Source, 2 
               FROM ORDERDETAIL OD (NOLOCK) 
               JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = OD.OrderKey
               JOIN SKU WITH (NOLOCK) ON  OD.Storerkey = SKU.Storerkey
                                      AND OD.Sku = SKU.Sku 
               WHERE SKU.StorerKey = @c_StorerKey 
               AND   SKU.RETAILSKU = @c_SKU
               AND   LPD.LoadKey = @c_Loadkey
            
               IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE')
               BEGIN
   		         SET @c_Source = 'MANUFACTURERSKU'      

   		         INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
   		         SELECT SKU.Sku, SKU.SkuStatus, @c_Source, 3 
                  FROM ORDERDETAIL OD (NOLOCK)
                  JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = OD.OrderKey
                  JOIN SKU WITH (NOLOCK) ON  OD.Storerkey = SKU.Storerkey
                                         AND OD.Sku = SKU.Sku 
                  WHERE SKU.StorerKey = @c_StorerKey 
                  AND   SKU.ManufacturerSku = @c_SKU
                  AND   LPD.LoadKey = @c_Loadkey
                  		
                  IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE')
                  BEGIN
               	   SET @c_Source = 'UPCSKU'

   		            INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
                     SELECT s.Sku, 
                           CASE WHEN s.SkuStatus = 'ACTIVE' THEN s.SkuStatus ELSE 'INACTIVE' END, 
                           @c_Source, 4 
                     FROM  ORDERDETAIL OD (NOLOCK) 
                     JOIN LoadPlanDetail AS lpd WITH(NOLOCK) ON lpd.OrderKey = OD.OrderKey 
                     JOIN UPC (NOLOCK) ON  OD.Storerkey = UPC.Storerkey AND OD.Sku = UPC.Sku
                     JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = UPC.StorerKey AND s.Sku = UPC.SKU
                     WHERE LPD.LoadKey = @c_Loadkey
                     AND UPC.StorerKey = @c_StorerKey 
                     AND UPC.UPC = @c_SKU           
                                     	
                  END -- UPCSKU  
               END -- Manufacturer Sku             	
            END  -- Retail SKU                       		
   	   END -- If not found by SKU, AtlSKU 
      END -- IF ISNULL(@c_LoadKey ,'') <> ''           
   END
   ELSE
   BEGIN
   	SET @c_FoundSKU = ''
   	SET @c_FoundSKUStatus = ''
      SET @c_Source = ''
      
      SELECT @c_FoundSKU = Sku, 
             @c_FoundSKUStatus = SkuStatus 
      FROM  SKU (NOLOCK)
      WHERE Sku = @c_SKU
      AND StorerKey = @c_StorerKey      	
   	IF ISNULL(@c_FoundSKU, '') = @c_SKU
   	BEGIN
   		SET @c_Source = 'SKU' 
   		SET @c_SKUStatus = @c_FoundSKUStatus
   	END
   	ELSE 
   	BEGIN
   		SET @c_Source = 'ALTSKU'      
   		
   		INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
         SELECT Sku, SkuStatus, @c_Source, 1 
         FROM   SKU WITH (NOLOCK)
         WHERE AltSku = @c_SKU
         AND StorerKey = @c_StorerKey            
         ORDER BY SkuStatus option (OPTIMIZE FOR UNKNOWN)   --TLTING01
         
         IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE' )
         BEGIN
   		   SET @c_Source = 'RETAILSKU'      
   		
   		   INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
            SELECT Sku, SkuStatus, @c_Source, 2
            FROM   SKU WITH (NOLOCK)
            WHERE RETAILSKU = @c_SKU
            AND StorerKey = @c_StorerKey            
            ORDER BY SkuStatus  option (OPTIMIZE FOR UNKNOWN)   --TLTING01
            
            IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE' )
            BEGIN
   		      SET @c_Source = 'MANUFACTURERSKU'      
   		
   		      INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
               SELECT Sku, SkuStatus, @c_Source, 3 
               FROM   SKU WITH (NOLOCK)
               WHERE ManufacturerSku = @c_SKU
               AND StorerKey = @c_StorerKey            
               ORDER BY SkuStatus  option (OPTIMIZE FOR UNKNOWN)   --TLTING01

               IF NOT EXISTS(SELECT 1 FROM @t_SKU WHERE SKUStatus = 'ACTIVE'  )
               BEGIN
               	SET @c_Source = 'UPCSKU'
               	
   		         INSERT INTO @t_SKU (SKU, SKUStatus, Source, SeqNo)
                  SELECT s.Sku, 
                         CASE WHEN s.SkuStatus = 'ACTIVE' THEN s.SkuStatus ELSE 'INACTIVE' END, 
                         @c_Source, 4 
                  FROM  UPC WITH (NOLOCK)
                  JOIN SKU AS s WITH(NOLOCK) ON s.StorerKey = UPC.StorerKey AND s.Sku = UPC.SKU
                  WHERE UPC.UPC = @c_SKU
                  AND UPC.StorerKey = @c_StorerKey            
                  ORDER BY s.SkuStatus                   	
               END -- UPCSKU  
            END -- Manufacturer Sku             	
         END  -- Retail SKU                       		
   	END -- If not found by SKU, AtlSKU 
   END -- by SKU 

   SELECT @c_FoundSKU = '',
          @c_FoundSKUStatus = ''
                                        
   SELECT @c_FoundSKU = SKU,
          @c_FoundSKUStatus = SKUStatus
   FROM @t_SKU AS ts 
   WHERE ts.SKUStatus = 'ACTIVE'
               
   IF @@ROWCOUNT = 0 OR ISNULL(@c_FoundSKU, '') = '' 
   BEGIN
      SELECT @c_FoundSKU = SKU,
             @c_FoundSKUStatus = SKUStatus
      FROM @t_SKU AS ts 
      WHERE ts.SKUStatus = 'INACTIVE'         
      ORDER BY ts.SeqNo          	
   END                        
   
   --NJOW02
   IF (@c_GetSkuBySerialNo = '1' OR @c_GetSkuFromSN_UPC = '1') AND ISNULL(@c_FoundSKU,'') = ''  --NJOW03
   BEGIN
      SET @c_Source = 'SERSKU'              
      
      --NJOW03
      IF @c_GetSkuFromSN_UPC = '1'
      BEGIN
   	     SELECT @c_FoundSKU = SKU.Sku,
   	            @c_FoundSKUStatus = SKU.SKUStatus
   	     FROM SERIALNO SR (NOLOCK)
   	     JOIN UPC (NOLOCK) ON SR.Userdefine02 = UPC.Upc AND SR.Storerkey = UPC.Storerkey
   	     JOIN SKU (NOLOCK) ON UPC.Storerkey = SKU.Storerkey AND UPC.Sku = SKU.Sku
   	     WHERE SR.Storerkey = @c_Storerkey
   	     AND SR.SerialNo = @c_Sku      	 
      END      
      
      IF ISNULL(@c_FoundSKU,'') = ''  --NJOW03
      BEGIN
   	     SELECT @c_FoundSKU = SKU.Sku,
   	            @c_FoundSKUStatus = SKU.SKUStatus
   	     FROM SERIALNO SR (NOLOCK)
   	     JOIN SKU (NOLOCK) ON SR.Storerkey = SKU.Storerkey AND SR.Sku = SKU.Sku
   	     WHERE SR.Storerkey = @c_Storerkey
   	     AND SR.SerialNo = @c_Sku      	              
   	  END
   END
   
   IF ISNULL(@c_FoundSKU,'') <> ''
   BEGIN
      SET @c_SKU = @c_FoundSKU
      SET @c_SKUStatus = @c_FoundSKUStatus
   END    
                         
   QUIT:  
   
   SELECT @c_SKU = UPPER(@c_SKU) --(CS02)
   
   --WL01 START
   IF @c_Source NOT IN ('UPCSKU')
   BEGIN
      DECLARE @c_NotAllowScanSKU NVARCHAR(10)
   
      EXEC nspGetRight NULL	-- facility
          ,@c_StorerKey	-- StorerKey
          ,NULL	-- Sku
          ,'PackingNotAllowScanSKU'	-- Configkey
          ,@b_Success OUTPUT
          ,@c_NotAllowScanSKU OUTPUT
          ,@n_Err OUTPUT
          ,@c_ErrMsg OUTPUT
   
      IF @c_NotAllowScanSKU = '1'
      BEGIN
         SELECT @n_Continue = 3  
         SELECT @n_Err = 40000
         SELECT @c_ErrMsg = 'Not Allow to Scan SKU due to Storerconfig: PackingNotAllowScanSKU is setup. ' +
                            'Please Key-in UPC Instead (nspg_GETSKU_PACK). '    	  	
      END
   END
   --WL01 END
   
   IF @c_PackGetSkuByAltWithOrder='2' 
   BEGIN
   	  IF (SELECT COUNT(DISTINCT Sku) FROM @t_SKU) > 1   --IF (SELECT COUNT(1) FROM @t_SKU) > 1  --JHTAN01  
   	  BEGIN
          SELECT @n_Continue = 3  
          SELECT @n_Err = 30000  
          SELECT @c_ErrMsg = 'Multiple Sku Found From '+RTRIM(ISNULL(@c_Source ,''))+
                 '. Please Key-in Sku (nspg_GETSKU_PACK)'    	  	
   	  END
   END 
   
   --CS01 start  
   
   IF @c_PackGetSkuByAltWithOrder='3'  
   BEGIN
   	  IF (SELECT COUNT(DISTINCT Sku) FROM @t_SKU) > 1   --IF (SELECT COUNT(1) FROM @t_SKU) > 1  --JHTAN01  
   	  BEGIN
          SELECT @n_Continue = 3  
          SELECT @n_Err = 60001  
          SELECT @c_ErrMsg = 'There are multiple Sku with same '+RTRIM(ISNULL(@c_Source ,''))+'. (nspg_GETSKU_PACK)'
       END 
   END 
   --CS01 END  
   
   --Cs03 Start  
   --IF UPPER(@c_SKUStatus)<>'ACTIVE'
   --BEGIN
   --    IF @c_Source='ALTSKU'
   --    BEGIN
   --        SELECT TOP 1 @c_SKU = Sku
   --        FROM  @t_SKU  
   --        WHERE Source = 'RETAILSKU'
   --        ORDER BY SeqNo
           
   --        SELECT @c_Source = 'RETAILSKU'
   --    END
   --END  
   
   IF @n_Continue=3
   BEGIN
       SELECT @b_Success = 0
   END
END 

GO