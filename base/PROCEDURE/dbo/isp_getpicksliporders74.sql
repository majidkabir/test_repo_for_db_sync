SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/
/* Store Procedure: isp_GetPickSlipOrders74                              */
/* Creation Date: 04-AUG-2017                                            */
/* Copyright: IDS                                                        */
/* Written by: CSCHONG                                                   */
/*                                                                       */
/* Purpose: WMS-2438 - CNWMS-ELLEDecor_PickingSlip_CR                    */
/*                                                                       */
/* Called By: r_dw_print_pickorder74                                     */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver.  Purposes                                   */
/* 18-SEP-2017  CSCHONG 1.1   WMS-2973 - revise report logic (CS01)      */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/*************************************************************************/

CREATE PROC [dbo].[isp_GetPickSlipOrders74] (@c_loadkey   NVARCHAR(10)
                                          ,@c_type   NVARCHAR(5) 
                                          ,@n_recgrp INT = ''
                                          ,@c_sku    NVARCHAR(20) = '')     --CS01         
AS            
BEGIN                        
   SET ANSI_WARNINGS OFF            
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF   
  
   DECLARE @c_MCompany        NVARCHAR(45)  
         , @c_Externorderkey  NVARCHAR(50)    --tlting_ext
         , @c_C_Addresses     NVARCHAR(200)   
         , @c_Userdef03       NVARCHAR(20)  
         , @c_salesman        NVARCHAR(30)  
         , @c_phone1          NVARCHAR(18)
         , @c_contact1        NVARCHAR(30)  
  
         , @n_TTLPQty         INT   
         , @c_shippername     NVARCHAR(45)  
         , @c_GetSku          NVARCHAR(20)  
         , @n_skuqty          INT
         , @c_OrdKey          NVARCHAR(10) 
         , @n_NoOfLine        INT  
         , @c_getOrdKey       NVARCHAR(10)
         , @n_pageno          INT
         , @c_PreSku          NVARCHAR(20)
         , @b_success         INT
         , @n_err             INT
         , @c_errmsg          NVARCHAR(255)
         , @n_Batch           INT
         , @c_pickheaderkey   NVARCHAR(10)
         , @n_continue        INT
         , @n_StartTCnt       INT
         , @c_Storerkey       NVARCHAR(15)                --CS01
         , @c_sbusr5          NVARCHAR(20)                --CS01
         , @n_CSKUQty         INT                         --CS01
         , @n_CthCSKU         INT                         --CS01
         , @n_qty             INT                         --CS01
         , @n_reccnt          INT                         --CS01
			, @n_getrecgrp       INT                         --CS01
			, @c_CSku            NVARCHAR(20)                --CS01
			, @n_TTLPage         INT                         --CS01
			, @n_NoOfCopy        INT                         --CS01
			
		 SET @n_NoOfLine   = 6
		 SET @c_getOrdKey  = ''              
		 SET @n_PageNo     = 0       
		 SET @n_TTLPQty    = 1  
		 SET @c_PreSku     = ''
		 SET @n_Batch      = 0
		 SET @c_pickheaderkey = ''
		 SET @n_NoOfCopy = 1                                --CS01
		 
		 
		SET @n_Continue      = 1
		SET @n_StartTCnt     = @@TRANCOUNT
		SET @b_success       = 1
		SET @n_err           = 0
		SET @c_errmsg        = ''
		SET @c_sbusr5        = ''           --CS01  
		SET @n_CthCSKU       = 1            --CS01  
		SET @n_reccnt        = 1            --CS01
		 
		 
	WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END
  
  
 CREATE TABLE #TEMP_PICK74 
         ( c_Contact1      NVARCHAR(30) NULL 
         , C_Addresses     NVARCHAR(200) NULL
         , c_Phone1        NVARCHAR(18) NULL
         , c_Phone2        NVARCHAR(18) NULL
         , c_Company       NVARCHAR(45) NULL 
         , m_Company       NVARCHAR(45) NULL 
         , PickLOC         NVARCHAR(10)  NULL
         , SKUSize         NVARCHAR(10) NULL   
         , ORDUdef03       NVARCHAR(20) NULL 
         , PASKU           NVARCHAR(20)  NULL
         , Pqty            INT               
         , OrderKey        NVARCHAR(10)  NULL          
         , Loadkey         NVARCHAR(10)  NULL        
         , Shipperkey      NVARCHAR(30)  NULL        
         , ODQtyPick       INT  
         , RecGrp          INT
         , PageNo          INT 
         , TTLPQty         INT
         , PickSlipNo      NVARCHAR(10) NULL
         , Storerkey       NVARCHAR(15) NULL           --CS01
         , SBUSR5          NVARCHAR(20) NULL           --CS01
         , CSKU            NVARCHAR(20) NULL           --CS01
         )  
         
         /*CS01 start*/
         CREATE TABLE #TEMP_PICK74CSKU (
           PickSlipNo      NVARCHAR(10) NULL
         , Storerkey       NVARCHAR(15) NULL 
         , PASKU           NVARCHAR(20) NULL 	
         , PACSKU          NVARCHAR(20) NULL
         , COMSKU_SIZE     NVARCHAR(10) NULL
         , Qty             INT   
         , recgrp          INT 
         , Loadkey         NVARCHAR(10)  NULL       
         )
         
         
         /*CS01 End*/
         
     
  
   INSERT INTO #TEMP_PICK74 (
                             c_Contact1      
									 , C_Addresses     
									 , c_Phone1        
									 , c_Phone2       
									 , C_Company       
									 , m_Company   
									 , PickLOC         
									 , SKUSize         
									 , ORDUdef03       
									 , PASKU           
									 , Pqty            
									 , OrderKey        
									 , Loadkey         
									 , Shipperkey        
									 , ODQtyPick     
									 , RecGrp
									 , PageNo
                            , TTLPQty 
                            , PickSlipNo     
                            , Storerkey                      --CS01
                            , SBUSR5                         --CS01
                            ,  CSKU                          --CS01
                           )             
   SELECT DISTINCT ISNULL(OH.c_Contact1,''),(OH.C_state+OH.C_City+OH.C_address1+OH.C_address2 + OH.C_address3 + OH.C_address4),
                   ISNULL(OH.C_Phone1,''),
                   ISNULL(OH.C_Phone2,''),
                   ISNULL(OH.C_Company,''),
                   ISNULL(OH.M_Company,''),PD.LOC,s.size,
                   ISNULL(OH.Userdefine03,''),
                   ORDDET.sku,SUM(PD.qty) AS qty,OH.OrderKey,
                   OH.Loadkey,OH.shipperkey,ORDDET.openqty,
                   (Row_Number() OVER (PARTITION BY OH.Orderkey ORDER BY ORDDET.SKU Asc)-1)/@n_NoOfLine,0,0
                   ,Pickslipno  = ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '') 
                   , Storerkey = OH.StorerKey                              --CS01
                   ,SBUSR5 = ''                                            --CS01
                   ,CSKU   = ''                                              --CS01
   FROM LOADPLANDETAIL WITH (NOLOCK)
   JOIN ORDERS     OH    WITH (NOLOCK) ON (OH.Orderkey = LOADPLANDETAIL.Orderkey)
   JOIN ORDERDETAIL ORDDET WITH (NOLOCK) ON ORDDET.Orderkey = OH.Orderkey
   JOIN PICKDETAIL PD WITH (NOLOCK) ON PD.Orderkey = OH.Orderkey 
                            AND PD.orderlinenumber = ORDDET.orderlinenumber
   JOIN SKU S WITH (NOLOCK) ON S.SKU = ORDDET.SKU AND S.Storerkey=ORDDET.Storerkey
   LEFT OUTER JOIN PICKHEADER   WITH (NOLOCK) ON (LOADPLANDETAIL.Loadkey = PICKHEADER.ExternOrderkey)
                                              AND(LOADPLANDETAIL.Orderkey= PICKHEADER.Orderkey)
                                              AND(PICKHEADER.Zone = '3')
   --JOIN STORER STO WITH (NOLOCK) ON OH.shipperkey = STO.Storerkey  
   --LEFT JOIN FACILITY F WITH (NOLOCK) ON f.Facility=oh.Facility                       
  WHERE LOADPLANDETAIL.LoadKey = @c_LoadKey
     AND PD.Status >= '0'
   GROUP BY ISNULL(OH.c_Contact1,''),(OH.C_state+OH.C_City+OH.C_address1+OH.C_address2 + OH.C_address3 + OH.C_address4),
                   ISNULL(OH.C_Phone1,''),
                   ISNULL(OH.C_Phone2,''),
                   ISNULL(OH.C_Company,''),
                   ISNULL(OH.M_Company,''),PD.LOC,s.size,
                   ISNULL(OH.Userdefine03,''),
                   ORDDET.sku,OH.OrderKey,
                   OH.Loadkey,OH.shipperkey,ORDDET.openqty,ISNULL(RTRIM(PICKHEADER.PickHeaderKey), '') 
                   ,OH.StorerKey             
   ORDER By OH.OrderKey,ORDDET.sku
   
   
      SET @n_TTLPQty = 1
   	
   	--SELECT @n_TTLPQty = SUM(pqty)
   	--FROM #TEMP_PICK74
   	--WHERE orderkey = @c_getOrdKey
   	
   SELECT @n_Batch = Count(DISTINCT OrderKey)
   FROM #TEMP_PICK74
   WHERE (PickSlipNo IS NULL OR RTRIM(PickSlipNo) = '')

   IF @@ERROR <> 0
   BEGIN
      GOTO FAILURE
   END
   ELSE IF @n_Batch > 0
   BEGIN
      BEGIN TRAN 
      EXECUTE nspg_GetKey 'PICKSLIP'
            , 9
            , @c_Pickheaderkey   OUTPUT
            , @b_success         OUTPUT
            , @n_err             OUTPUT
            , @c_errmsg          OUTPUT
            , 0
            , @n_Batch

      SELECT @n_err = @@ERROR 
      IF @n_err = 0
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      BEGIN TRAN -- SOS#280077
      INSERT INTO PICKHEADER (PickHeaderKey, OrderKey, ExternOrderKey, PickType, Zone, TrafficCop)
      SELECT 'P' + RIGHT ( '000000000' +
                           LTRIM(RTRIM( STR( CAST(@c_pickheaderkey AS INT) +
                           ( SELECT COUNT(DISTINCT orderkey)
                           FROM #TEMP_PICK74 as Rank
                           WHERE Rank.OrderKey < #TEMP_PICK74.OrderKey
                           AND ISNULL(RTRIM(Rank.PickSlipNo),'') = '' ) -- SOS#280077
                           ) -- str
                          ))--LTRIM & RTRIM
                        , 9)
               , OrderKey
               , LoadKey
               , '0'
               , '3'
               , ''
      FROM #TEMP_PICK74
      WHERE ISNULL(RTRIM(PickSlipNo),'') = ''
      GROUP BY LoadKey, OrderKey

      SELECT @n_err = @@ERROR -- SOS#280077
      IF @n_err = 0
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN
         END
      END

      UPDATE #TEMP_PICK74
      SET   PickSlipNo = PICKHEADER.PickHeaderKey
      FROM  PICKHEADER (NOLOCK)
      WHERE PICKHEADER.ExternOrderKey = #TEMP_PICK74.LoadKey
      AND   PICKHEADER.OrderKey = #TEMP_PICK74.OrderKey
      AND   PICKHEADER.Zone = '3'
      AND   (#TEMP_PICK74.PickSlipNo IS NULL OR RTRIM(#TEMP_PICK74.PickSlipNo) = '')
   END
  -- GOTO SUCCESS
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PA34.Orderkey,PA34.PASKU,PA34.Storerkey ,PA34.Pqty                    --CS01   
   FROM   #TEMP_PICK74 PA34  
   WHERE loadkey = @c_LoadKey 
   GROUP BY PA34.OrderKey,PA34.PASKU,PA34.Storerkey,PA34.Pqty
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_Ordkey,@c_GetSku,@c_Storerkey,@n_qty               --CS01    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN  
   	
   	SET @n_skuqty = 1
   	SET @n_NoOfCopy = @n_qty
   	
   	SELECT @n_skuqty = SUM(pqty)
   	FROM #TEMP_PICK74
   	WHERE orderkey = @c_Ordkey
   	AND PASKU = @c_GetSku
   	
   	/*CS01 Start*/
   	SET @n_reccnt       = @n_skuqty
   	SET @c_sbusr5        = ''           --CS01  
   	
   	SELECT @c_sbusr5 = ISNULL(S.BUSR5,'')
   	FROM SKU S WITH (NOLOCK)
   	WHERE S.StorerKey = @c_Storerkey
   	AND S.Sku = @c_GetSku
   	
   	IF @c_sbusr5 = 'CP'
   	BEGIN
   		INSERT INTO #TEMP_PICK74CSKU (PickSlipNo, Storerkey, PASKU,PACSKU,COMSKU_SIZE,Qty,recgrp,Loadkey)
   		SELECT tp.PickSlipNo,tp.Storerkey,tp.PASKU,bom.ComponentSku,s.Size,SUM(bom.Qty),
   		 (Row_Number() OVER (PARTITION BY tp.PASKU ORDER BY bom.ComponentSku Asc)-1)/1,
   		tp.Loadkey
   		FROM #TEMP_PICK74 AS tp WITH (NOLOCK)
   		JOIN BillOfMaterial BOM WITH (NOLOCK) ON BOM.Sku = tp.paSku AND BOM.Storerkey = tp.Storerkey
   		JOIN sku s WITH (NOLOCK) ON s.StorerKey = tp.Storerkey AND s.sku = tp.PASKU
   		WHERE tp.PASKU = @c_GetSku
   		GROUP BY tp.PickSlipNo,tp.Storerkey,tp.PASKU,bom.ComponentSku,s.Size,tp.Loadkey
   		
   		
   	END
   	
   	
   	SET  @n_CSKUQty =0
   	
   	SELECT  @n_CSKUQty =SUM(qty)
   	       ,@n_CthCSKU = COUNT(1)
   	FROM #TEMP_PICK74CSKU
   	WHERE PASKU = @c_GetSku
   	
   	SELECT @c_CSku = PACSKU
   	FROM #TEMP_PICK74CSKU
   	WHERE PASKU = @c_GetSku
   	
   --	SELECT @n_CSKUQty '@n_CSKUQty',@n_skuqty '@n_skuqty'
  
   	IF @c_sbusr5 = 'CP' and @n_CSKUQty > 0
   	BEGIN
   		SET @n_skuqty = @n_skuqty + @n_CSKUQty
   	END
   	ELSE IF @n_qty > 1
   	BEGIN
   		SET @n_CSKUQty = 1
   	END	
   
    	/*CS01 End*/
   	
   	SET @n_pageno = @n_pageno + 1
   	
      UPDATE #TEMP_PICK74
      SET PageNo = @n_pageno
         ,TTLPQty = @n_skuqty --+ @n_CSKUQty
         ,SBUSR5 = @c_sbusr5                       --CS01
         ,CSKU = @c_CSku                           --CS01
         ,pqty = CASE WHEN @n_qty>1 THEN @n_CSKUQty ELSE pqty END
      WHERE orderkey=@c_Ordkey
      AND PASKU=@c_GetSku  
      
      WHILE @n_NoOfCopy > 1
      BEGIN
      	
      	INSERT INTO #TEMP_PICK74(c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	            OrderKey, Loadkey, Shipperkey, ODQtyPick, RecGrp, PageNo,
      	            TTLPQty, PickSlipNo, Storerkey, SBUSR5)
      	SELECT TOP 1 c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	            OrderKey, Loadkey, Shipperkey, ODQtyPick, (RecGrp+1), PageNo,
      	            0, PickSlipNo, Storerkey, SBUSR5
      	FROM #TEMP_PICK74
      	WHERE PASKU=@c_GetSku AND ISNULL(SBUSR5,'') <> 'CP'
      	ORDER BY pageno DESC
      	
      	SET @n_NoOfCopy = @n_NoOfCopy - 1
      	
      END
      
      WHILE @n_CthCSKU > 1 AND @c_sbusr5 = 'CP'
      BEGIN
      	INSERT INTO #TEMP_PICK74(c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	            OrderKey, Loadkey, Shipperkey, ODQtyPick, RecGrp, PageNo,
      	            TTLPQty, PickSlipNo, Storerkey, SBUSR5)
      	SELECT TOP 1 c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	            OrderKey, Loadkey, Shipperkey, ODQtyPick, (RecGrp+1), PageNo,
      	            0, PickSlipNo, Storerkey, SBUSR5
      	FROM #TEMP_PICK74
      	WHERE PASKU=@c_GetSku
      	ORDER BY pageno desc
      	
      	--IF @n_reccnt > 1
      	--BEGIN
      	--	INSERT INTO #TEMP_PICK74(c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	--            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	--            OrderKey, Loadkey, Shipperkey, ODQtyPick, RecGrp, PageNo,
      	--            TTLPQty, PickSlipNo, Storerkey, SBUSR5)
      	--   SELECT TOP 1 c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	--            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	--            OrderKey, Loadkey, Shipperkey, ODQtyPick, (RecGrp+1), PageNo,
      	--            0, PickSlipNo, Storerkey, SBUSR5
      	--FROM #TEMP_PICK74
      	--WHERE PASKU=@c_GetSku
      	--ORDER BY pageno desc
      	--END
      		
      		
      	SET @n_reccnt = @n_reccnt - 1	
      	SET @n_CthCSKU= @n_CthCSKU - 1	
      	
      	
      END     
   	
   FETCH NEXT FROM CUR_RESULT INTO @c_Ordkey,@c_GetSku ,@c_Storerkey ,@n_qty               --CS01    
   END  
   
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT
    
   DECLARE CUR_CPLoop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PA34.Orderkey,PA34.PASKU,PA34.Storerkey,PA34.RecGrp,PA34.Pqty                     --CS01   
   FROM   #TEMP_PICK74 PA34  
   WHERE loadkey = @c_LoadKey 
   AND PA34.SBUSR5 = 'CP'
   GROUP BY PA34.OrderKey,PA34.PASKU,PA34.Storerkey,PA34.RecGrp,PA34.Pqty
  
   OPEN CUR_CPLoop   
     
   FETCH NEXT FROM CUR_CPLoop INTO @c_Ordkey,@c_GetSku,@c_Storerkey,@n_getrecgrp,@n_reccnt               --CS01    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   
   	
   	WHILE @n_reccnt > 1
   	BEGIN
   		INSERT INTO #TEMP_PICK74(c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	            OrderKey, Loadkey, Shipperkey, ODQtyPick, RecGrp, PageNo,
      	            TTLPQty, PickSlipNo, Storerkey, SBUSR5)
      	SELECT TOP 1 c_Contact1, C_Addresses, c_Phone1, c_Phone2,
      	            c_Company, m_Company, PickLOC, SKUSize, ORDUdef03, PASKU, Pqty,
      	            OrderKey, Loadkey, Shipperkey, ODQtyPick, @n_getrecgrp, PageNo,
      	            0, PickSlipNo, Storerkey, SBUSR5
      	FROM #TEMP_PICK74
      	WHERE PASKU=@c_GetSku
   		
   		SET @n_reccnt = @n_reccnt -1
   	END   
   	
   FETCH NEXT FROM CUR_CPLoop INTO @c_Ordkey,@c_GetSku ,@c_Storerkey,@n_getrecgrp,@n_reccnt                --CS01    
   END 
   
   CLOSE CUR_CPLoop
   DEALLOCATE CUR_CPLoop
   	
   	SET @n_TTLPage = 1
   	SELECT @n_TTLPage = COUNT(1)
   	FROM #TEMP_PICK74 AS tp
   	WHERE Loadkey = @c_loadkey
   	
   	UPDATE #TEMP_PICK74
   	SET PageNo = @n_TTLPage
      WHERE Loadkey = @c_loadkey
   
       IF @c_type = 'H1' GOTO TYPE_H1
       --IF @c_type = 'D_SKU' GOTO TYPE_D_SKU
       IF @c_type = 'D_CSK' GOTO TYPE_D_CSKU
   
   --GOTO SUCCESS
   
   FAILURE:
   DELETE FROM #TEMP_PICK74
  
  --SUCCESS:                       --CS01 start
  TYPE_H1:
                   SELECT   c_Contact1      
									 , C_Addresses     
									 , c_Phone1        
									 , c_Phone2       
									 , C_Company       
									 , m_Company   
									 , PickLOC         
									 , SKUSize         
									 , ORDUdef03       
									 , PASKU           
									 , Pqty            
									 , OrderKey        
									 , Loadkey         
									 , Shipperkey        
									 , ODQtyPick     
									 , RecGrp  
									 , PageNo
									 , TTLPQty   
									 , pickslipno  
									 , Storerkey            --CS01
									 , SBUSR5               --CS01
   FROM #TEMP_PICK74 
   WHERE Loadkey = @c_loadkey
   ORDER BY Orderkey,PASKU,PageNo,RecGrp 
   
   GOTO QUIT
   
   -- TYPE_D_SKU:
   --                SELECT     PickLOC         
			--						 , SKUSize         
			--						 , ORDUdef03       
			--						 , PASKU           
			--						 , Pqty            
			--						 , OrderKey        
			--						 , Loadkey                 
			--						 , ODQtyPick     
			--						 , RecGrp  
			--						 , PageNo
			--						 , TTLPQty   
			--						 , pickslipno  
			--						 , Storerkey            
			--						 , SBUSR5               
   --FROM #TEMP_PICK74 
   --WHERE Loadkey = @c_loadkey
   ----AND SBUSR5<>'CP'
   --ORDER BY Orderkey,PASKU,PageNo  
   
   GOTO QUIT
   
   TYPE_D_CSKU:
  
                   SELECT    COMSKU_SIZE
                           , PASKU
                           , Qty
                           , Loadkey
                           , recgrp
                           , PickSlipNo
                           , Storerkey  
                           , PACSKU     
   FROM #TEMP_PICK74CSKU 
   WHERE Loadkey = @c_loadkey
   AND PASKU = @c_sku
   AND recgrp = @n_recgrp
   ORDER BY PACSKU,recgrp 
   
   GOTO QUIT
   
   /*CS01 END*/
   QUIT:
   DROP TABLE #TEMP_PICK74
   DROP TABLE #TEMP_PICK74CSKU            --CS01
             
END



GO