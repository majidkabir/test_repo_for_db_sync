SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/  
/* Store Procedure: isp_UCC_Carton_Label_52_rdt_1                                 */  
/* Creation Date: 15-Nov-2016                                                 */  
/* Copyright: IDS                                                             */  
/* Written by: CSCHONG                                                        */  
/*                                                                            */  
/* Purpose:  WMS-445 - BrownShoe Carton Content Label                         */  
/*                                                                            */  
/* Called By: Powerbuilder                                                    */  
/*                                                                            */  
/* PVCS Version: 1.1                                                          */  
/*                                                                            */  
/* Version: 5.4                                                               */  
/*                                                                            */  
/* Data Modifications:                                                        */  
/*                                                                            */  
/* Updates:                                                                   */  
/* Date         Author    Ver.  Purposes                                      */
/* 22-Dec-2016  CSCHONG   1.0   WMS-445 modify size sorting (CS01)            */
/* 22-Mar-2019  TLTING01  1.1   Bug fix                                       */
/******************************************************************************/  
  
CREATE PROC [dbo].[isp_UCC_Carton_Label_52_RDT_1] (
         @c_PickSlipNo     NVARCHAR(10)
      ,  @c_CartonNo       NVARCHAR(10)
      ,  @c_Mode           NVARCHAR(1))

AS  
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET ANSI_NULLS OFF
SET QUOTED_IDENTIFIER OFF
SET CONCAT_NULL_YIELDS_NULL OFF  
  
BEGIN
	DECLARE @c_ExecSQLStmt        NVARCHAR(MAX),
	        @c_ExecArguments      NVARCHAR(MAX),
	        @c_Presize            NVARCHAR(10),
	        @n_CartonNo           INT,
	        @c_Name               NVARCHAR(10),
	        @c_PreName            NVARCHAR(10),
	        @n_Err                INT, 
	        @c_ErrMsg             NVARCHAR(250),  
	        @b_Success            INT,
	        @n_CntM               INT,
	        @n_MaxCnt             INT,
	        @c_Sname              NVARCHAR(10),
	        @c_PreSname           NVARCHAR(10),
	        @c_susr1              NVARCHAR(18)  
	        
	DECLARE  @c_Getpickslipno NVARCHAR(10)
	        ,@n_Getcartonno  INT
	        ,@n_Size         FLOAT
	        ,@n_CurentRow    INT
	        ,@c_getsize   NVARCHAR(10)
	        ,@c_size      NVARCHAR(10)
	        ,@c_size1     NVARCHAR(10)
	        ,@c_size2     NVARCHAR(10)
	        ,@c_size3     NVARCHAR(10)
	        ,@c_size4     NVARCHAR(10)
	        ,@c_size5     NVARCHAR(10)
	        ,@c_size6     NVARCHAR(10)
	        ,@c_size7     NVARCHAR(10)
	        ,@c_size8     NVARCHAR(10)
	        ,@c_size9     NVARCHAR(10)
	        ,@c_size10     NVARCHAR(10)
	        ,@c_size11     NVARCHAR(10)
	        ,@c_size12     NVARCHAR(10)
	        ,@c_size13     NVARCHAR(10)
	        ,@n_rowid      INT        
	        
	        
 DECLARE @c_measurement NVARCHAR(10),
         @c_MPickslipno NVARCHAR(20),
         @n_Mcartonno INT,
         @n_getsize INT,
         @c_Msize NVARCHAR(10),
         @n_getqty INT
          
   DECLARE   @c_getsize1     NVARCHAR(10) 
	         ,@c_getsize2     NVARCHAR(10) 
	         ,@c_getsize3     NVARCHAR(10) 
	         ,@c_getsize4     NVARCHAR(10) 
	         ,@c_getsize5     NVARCHAR(10) 
	         ,@c_getsize6     NVARCHAR(10) 
	         ,@c_getsize7     NVARCHAR(10) 
	         ,@c_getsize8     NVARCHAR(10) 
	         ,@c_getsize9     NVARCHAR(10) 
	         ,@c_getsize10    NVARCHAR(10)
	         ,@c_getsize11    NVARCHAR(10)
	         ,@c_getsize12    NVARCHAR(10)
	         ,@c_getsize13    NVARCHAR(10)	  
	         
	         
  CREATE TABLE #TEMPSKU (
  	                RowID       [INT] IDENTITY(1,1) NOT NULL, 
                   PickSlipNo         NVARCHAR(10),
                   CartonNo           INT,
                   SKU                NVARCHAR(20) NULL,
                   Class              NVARCHAR(20) NULL,
                   SIZE               NVARCHAR(10) NULL,
                   SUSR1              NVARCHAR(18) NULL,--)  
       BUSR5              NVARCHAR(30) NULL)
                 --  SUSR2              NVARCHAR(18) NULL) 		
  	         
  CREATE TABLE #TEMPSKUM (
  	                RowID       [INT] IDENTITY(1,1) NOT NULL, 
                   PickSlipNo         NVARCHAR(10),
                   CartonNo           INT,
                   measurement        NVARCHAR(5) NULL,
                   SUSR2              NVARCHAR(18) NULL) 	                 
          

  CREATE TABLE #TEMPSIZE (RowID       [INT] IDENTITY(1,1) NOT NULL, 
                   PickSlipNo         NVARCHAR(10),
                   CartonNo           INT,
                   SNAME              NVARCHAR(10),
                   --SSIZE              FLOAT NULL,
                   SSIZE              NVARCHAR(10) NULL,
                   SUSR1              NVARCHAR(18) NULL) 	   
  
  CREATE TABLE #TempSKUSize50
  ( ID                 [INT] IDENTITY(1,1) NOT NULL, 
    PickSlipNo         NVARCHAR(10),
    CartonNo           INT,
    SName              NVARCHAR(10) NULL,
  	 SIZE1              NVARCHAR(10) NULL,
    SIZE2              NVARCHAR(10) NULL,
    SIZE3              NVARCHAR(10) NULL,
    SIZE4              NVARCHAR(10) NULL,
    SIZE5              NVARCHAR(10) NULL,
    SIZE6              NVARCHAR(10) NULL,
    SIZE7              NVARCHAR(10) NULL,
    SIZE8              NVARCHAR(10) NULL,
    SIZE9              NVARCHAR(10) NULL,
    SIZE10             NVARCHAR(10) NULL,
    SIZE11             NVARCHAR(10) NULL,
    SIZE12             NVARCHAR(10) NULL,
    SIZE13             NVARCHAR(10) NULL,
    STYPE               NVARCHAR(15) NULL
  )
  
    CREATE TABLE #TEMPSizeResult 
  ( ID                 [INT] IDENTITY(1,1) NOT NULL, 
    SName              NVARCHAR(10),
  	 SIZE1              NVARCHAR(10) NULL,
    SIZE2              NVARCHAR(10) NULL,
    SIZE3              NVARCHAR(10) NULL,
    SIZE4              NVARCHAR(10) NULL,
    SIZE5              NVARCHAR(10) NULL,
    SIZE6              NVARCHAR(10) NULL,
    SIZE7              NVARCHAR(10) NULL,
    SIZE8              NVARCHAR(10) NULL,
    SIZE9              NVARCHAR(10) NULL,
    SIZE10             NVARCHAR(10) NULL,
    SIZE11             NVARCHAR(10) NULL,
    SIZE12             NVARCHAR(10) NULL,
    SIZE13             NVARCHAR(10) NULL,
    STYPE               NVARCHAR(15) NULL
  )
  
  CREATE TABLE #TempGetSize50
	(  RowID              [INT] IDENTITY(1,1) NOT NULL, 
	   PickSlipNo         NVARCHAR(10),
      CartonNo           INT,
		S_Size             NVARCHAR(10) NULL,
	   S_Name             NVARCHAR(10) NULL)
	
		
	  SET @n_CurentRow = 1
	  SET @c_size1 = ''
	  SET @c_size2 = ''
	  SET @c_size3 = ''
	  SET @c_size4 = ''
	  SET @c_size5 = ''
	  SET @c_size6 = ''
	  SET @c_size7 = ''
	  SET @c_size8 = ''
	  SET @c_size9 = ''
	  SET @c_size10 = ''
	  SET @c_size11 = ''
	  SET @c_size12 = ''
	  SET @c_size13 = ''	
	  SET @n_MaxCnt = 5
	
	
	  IF @c_Mode = 'M'
	  BEGIN
	  	
	  	INSERT INTO #TEMPSKU
	  	(	PickSlipNo,
	  		CartonNo,
	  		SKU,
	  		Class,
	  		[SIZE],
	  		SUSR1,
	  		BUSR5
	  	)
	  		SELECT DISTINCT  PACKHEADER.PickSlipNo,
		                    PACKDETAIL.cartonno,
		                    PACKDETAIL.SKU,
		                    sKU.CLASS,
		                    SKU.Size,
		                    SKU.SUSR1,
		                    SKU.BUSR5
		   FROM PACKHEADER  WITH (NOLOCK)  
			JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
			JOIN SKU         WITH (NOLOCK) ON (PACKDETAIL.Storerkey  = SKU.Storerkey)     
														AND(PACKDETAIL.Sku        = SKU.Sku)
         WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
			AND   PACKDETAIL.cartonno     = @c_CartonNo
	  		ORDER BY SKU.SUSR1	
	  		
	  		
	  INSERT INTO #TEMPSKUM (PickSlipNo,
	  								 CartonNo,
	  								 measurement, 
	  								 SUSR2)		 	
	  								 
     SELECT DISTINCT TOP 5 PACKHEADER.PickSlipNo,PACKDETAIL.CartonNo,ISNULL(SKU.measurement,''),
                           SKU.SUSR2 
	  	 FROM PACKHEADER  WITH (NOLOCK)  
			JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
			JOIN SKU         WITH (NOLOCK) ON (PACKDETAIL.Storerkey  = SKU.Storerkey)     
														AND(PACKDETAIL.Sku        = SKU.Sku)
			WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
			AND   PACKDETAIL.cartonno     = @c_CartonNo
   ORDER BY SKU.SUSR2	  								 												
	  	
	  END
	  ELSE
	  BEGIN
	  	
	  	
	  	INSERT INTO #TEMPSKU
	  	(	PickSlipNo,
	  		CartonNo,
	  		SKU,
	  		Class,
	  		[SIZE],
	  		SUSR1
	  	)
	  	 SELECT DISTINCT    PACKHEADER.PickSlipNo,
		                    PACKDETAIL.cartonno,
		                    bom.componentSKU,
		                    sKU.CLASS,
		                    SKU.Size,
		                    SKU.SUSR1
            FROM PACKHEADER  WITH (NOLOCK)  
				JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)   
				JOIN BillOfMaterial AS bom WITH (NOLOCK) ON bom.SKU = PACKDETAIL.SKU  
															AND bom.StorerKey = PACKDETAIL.StorerKey
				 JOIN SKU SKU WITH (NOLOCK) ON SKU.sku=bom.ComponentSku AND sKU.StorerKey=bom.Storerkey	
				WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
				AND   PACKDETAIL.cartonno     = @c_CartonNo
	  	 ORDER BY SKU.SUSR1
	  	 
	  	  INSERT INTO #TEMPSKUM (PickSlipNo,
	  								 CartonNo,
	  								 measurement, 
	  								 SUSR2)			 	 	
	  								 
		  SELECT DISTINCT TOP 5 PACKHEADER.PickSlipNo,PACKDETAIL.CartonNo,ISNULL(SKU.measurement,''),
										SKU.SUSR2 
		  FROM PACKHEADER  WITH (NOLOCK)  
		  JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
		  JOIN BillOfMaterial AS bom WITH (NOLOCK) ON bom.SKU = PACKDETAIL.SKU  
																AND bom.StorerKey = PACKDETAIL.StorerKey
		  JOIN SKU SKU WITH (NOLOCK) ON SKU.sku=bom.ComponentSku AND sKU.StorerKey=bom.Storerkey
		  WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
		  AND   PACKDETAIL.cartonno     = @c_CartonNo
		  ORDER BY SKU.SUSR2	 
	  	 
	  END
	  
	  
	  
	  IF @c_Mode = 'M'
	  BEGIN
	  	   --Get SKU Size
	  	   
	  	   INSERT INTO #TEMPSIZE (PickSlipNo,CartonNo,sname,SSize,SUSR1)
         SELECT DISTINCT TS.PickSlipNo
		                         ,TS.cartonno,
		                          --CONVERT(Float,ISNULL(RTRIM(SKU.Size),'')	) 
		                          codelkup.long,
		                          --CONVERT(Float,ISNULL(RTRIM(CODELKUP.UDF02),''))
		                          ISNULL(RTRIM(CODELKUP.UDF02),'N/A'),TS.SUSR1 
         FROM #TEMPSKU TS
			LEFT JOIN CODELKUP (nolock) ON LISTNAME='BWSSIZECON' and UDF01=TS.size and UDF03=TS.CLASS
			AND   
            (CASE  
             WHEN ISNULL(TS.BUSR5,'')='Vionic' THEN TS.BUSR5  
             WHEN ISNULL(TS.BUSR5,'')<> 'Vionic' THEN ''  
             END   
            ) = ISNULL(code2,'')
			WHERE TS.PickSlipNo = @c_PickSlipNo
			AND   TS.cartonno     = @c_CartonNo
		   --ORDER BY CODELKUP.long,CONVERT(Float,ISNULL(RTRIM(CODELKUP.UDF02),'')) --CONVERT(Float,ISNULL(RTRIM(SKU.Size),'')	) 
         ORDER BY codelkup.long,TS.SUSR1  
	  		  	 
	    DECLARE C_SizeName CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT DISTINCT Pickslipno,cartonno,sname
			FROM #TEMPSIZE TSZ
			WHERE pickslipno = @c_PickSlipNo
			AND CartonNo = @c_CartonNo
			ORDER BY sname
			
		  OPEN C_SizeName 
		  FETCH NEXT FROM C_SizeName INTO @c_getpickslipno,@n_Getcartonno,@c_Sname
  
	     WHILE (@@FETCH_STATUS <> -1) 
		  BEGIN 	 
		  	   -- SET @n_CurentRow = 1
		   --  SET @c_size1 = ''
			  --SET @c_size2 = ''
			  --SET @c_size3 = ''
			  --SET @c_size4 = ''
			  --SET @c_size5 = ''
			  --SET @c_size6 = ''
			  --SET @c_size7 = ''
			  --SET @c_size8 = ''
			  --SET @c_size9 = ''
			  --SET @c_size10 = ''
			  --SET @c_size11 = ''
			  --SET @c_size12 = ''
			  --SET @c_size13 = ''
	    	  	   
	  	   DECLARE  C_Lebelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT SSize
			FROM #TEMPSIZE TSZ
			WHERE pickslipno = @c_PickSlipNo
			AND CartonNo = @c_CartonNo
			AND SNAME = @c_Sname
			ORDER BY TSZ.SUSR1
  
  
		  OPEN C_Lebelno 
		  FETCH NEXT FROM C_Lebelno INTO @c_getsize
  
		  WHILE (@@FETCH_STATUS <> -1) 
		  BEGIN 
		  	
		  	   IF @n_CurentRow = 1 
  				BEGIN
  					SET @c_size1= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 2
  				BEGIN
  					SET @c_size2= @c_getsize --CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 3
  				BEGIN
  					SET @c_size3= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 4
  				BEGIN
  					SET @c_size4= @c_getsize --CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 5
  				BEGIN
  					SET @c_size5= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 6
  				BEGIN
  					SET @c_size6= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 7
  				BEGIN
  					SET @c_size7= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 8
  				BEGIN
  					SET @c_size8= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 9
  				BEGIN
  					SET @c_size9= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 10
  				BEGIN
  					SET @c_size10= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 11
  				BEGIN
  					SET @c_size11= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END
  				ELSE IF @n_CurentRow = 12
  				BEGIN
  					SET @c_size12= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END
  				ELSE IF @n_CurentRow = 13
  				BEGIN
  					SET @c_size13= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END
 	      
 	      SET @n_CurentRow = @n_CurentRow + 1 
  	
		  FETCH NEXT FROM C_Lebelno INTO @c_getsize   
		  END   
 
		  CLOSE C_Lebelno  
		  DEALLOCATE C_Lebelno  
  
	  INSERT INTO #TempSKUSize50
					  (PickSlipNo         , 
						CartonNo           , 
						SName              ,
						SIZE1              , 
						SIZE2              , 
						SIZE3              , 
						SIZE4              , 
						SIZE5              , 
						SIZE6              , 
						SIZE7              , 
						SIZE8              , 
						SIZE9              , 
						SIZE10             , 
						SIZE11             , 
						SIZE12             , 
						SIZE13             ,
					   STYPE                )  
         VALUES(@c_Getpickslipno,@n_Getcartonno,@c_sname,@c_size1,@c_size2,@c_size3,@c_size4,@c_size5,
                @c_size6,@c_size7,@c_size8,@c_size9,@c_size10,@c_size11,@c_size12,@c_size13,'Size')
                
         
           SET @n_CurentRow = 1
			  SET @c_size1 = ''
			  SET @c_size2 = ''
			  SET @c_size3 = ''
			  SET @c_size4 = ''
			  SET @c_size5 = ''
			  SET @c_size6 = ''
			  SET @c_size7 = ''
			  SET @c_size8 = ''
			  SET @c_size9 = ''
			  SET @c_size10 = ''
			  SET @c_size11 = ''
			  SET @c_size12 = ''
			  SET @c_size13 = ''	       
                
         
		  FETCH NEXT FROM C_SizeName INTO @c_getpickslipno,@n_Getcartonno,@c_Sname 
		  END   
 
		  CLOSE C_SizeName  
		  DEALLOCATE C_SizeName  
              
           
      /*    INSERT INTO #TEMPSizeResult
					  (Sname              ,
						SIZE1              , 
						SIZE2              , 
						SIZE3              , 
						SIZE4              , 
						SIZE5              , 
						SIZE6              , 
						SIZE7              , 
						SIZE8              , 
						SIZE9              , 
						SIZE10             , 
						SIZE11             , 
						SIZE12             , 
						SIZE13             ,
					   STYPE  )  
              
          SELECT DISTINCT long AS SNAME ,T50.size1 AS Size1,T50.size2 AS Size2,T50.size3 AS Size3,
		                   T50.SIZE4 AS Size4,T50.SIZE5 AS Size5,T50.SIZE6 AS Size6,
		                   T50.SIZE7 AS Size7,T50.SIZE8 AS Size8,T50.SIZE9 AS Size9,
		                   T50.SIZE10 AS Size10,T50.SIZE11 AS Size11,T50.SIZE12 AS Size12,T50.SIZE13 AS Size13,'Size'             
			FROM PACKHEADER  WITH (NOLOCK)  
			JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
			JOIN SKU         WITH (NOLOCK) ON (PACKDETAIL.Storerkey = SKU.Storerkey)     
														AND(PACKDETAIL.Sku        = SKU.Sku)
			LEFT JOIN CODELKUP (nolock) ON LISTNAME='BWSSIZECON' and UDF01=SKU.size and UDF03=SKU.CLASS
			JOIN #TempSKUSize50 T50 WITH (NOLOCK) ON T50.PickSlipNo=PACKDETAIL.PickSlipNo AND T50.CartonNo=PACKDETAIL.CartonNo
			WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
			AND   PACKDETAIL.cartonno     = @c_CartonNo
		   ORDER BY long	 */
		   
	 --Get Measument start
	 
	 DECLARE  C_SKU_M CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   --    SELECT DISTINCT TOP 5 SKU.measurement,PACKHEADER.PickSlipNo,PACKDETAIL.CartonNo
	  --	 FROM PACKHEADER  WITH (NOLOCK)  
			--JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
			--JOIN SKU         WITH (NOLOCK) ON (PACKDETAIL.Storerkey  = SKU.Storerkey)     
			--											AND(PACKDETAIL.Sku        = SKU.Sku)
			--LEFT JOIN CODELKUP (nolock) ON LISTNAME='BWSSIZECON' and UDF01=SKU.size and UDF03=SKU.CLASS
			--WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
			--AND   PACKDETAIL.cartonno     = @c_CartonNo
   --ORDER BY SKU.measurement
   SELECT TSM.measurement,TSM.PickSlipNo,TSM.CartonNo
	  	 FROM #TEMPSKUM  TSM WITH (NOLOCK)  
			WHERE TSM.PickSlipNo = @c_PickSlipNo
			AND   TSM.cartonno     = @c_CartonNo
   ORDER BY TSM.RowID
   
  OPEN C_SKU_M 
  FETCH NEXT FROM C_SKU_M INTO @c_measurement,@c_MPickslipno,@n_Mcartonno
  
  WHILE (@@FETCH_STATUS <> -1) 
  BEGIN 
   
     
	          SET @c_getsize1 = '' 
				 SET @c_getsize2 = '' 
				 SET @c_getsize3 = '' 
				 SET @c_getsize4 = '' 
				 SET @c_getsize5 = '' 
				 SET @c_getsize6 = '' 
				 SET @c_getsize7 = '' 
				 SET @c_getsize8 = '' 
				 SET @c_getsize9 = '' 
				 SET @c_getsize10 = ''
				 SET @c_getsize11 = ''
				 SET @c_getsize12 = ''
				 SET @c_getsize13 = ''
				 
	SELECT   @c_getsize1    = Size1 
			  ,@c_getsize2    = Size2 
			  ,@c_getsize3    = Size3 
			  ,@c_getsize4    = Size4 
			  ,@c_getsize5    = Size5 
			  ,@c_getsize6    = Size6 
			  ,@c_getsize7    = Size7 
			  ,@c_getsize8    = Size8 
			  ,@c_getsize9    = Size9 
			  ,@c_getsize10   = Size10
			  ,@c_getsize11   = Size11
			  ,@c_getsize12   = Size12
			  ,@c_getsize13   = Size13
		FROM #TempSKUSize50 AS t
		WHERE t.PickSlipNo=@c_MPickslipno
		AND t.CartonNo = @n_Mcartonno
		AND t.STYPE='SIZE'
	  
	  
	  --SELECT * FROM  #TempSKUSize50
	  --WHERE STYPE='SIZE'
	  
	  --SELECT DISTINCT TS.SIZE,SUM(PD.qty),TS.SUSR1
	  --FROM PACKDETAIL  PD WITH (NOLOCK)
	  --JOIN #TEMPSKU TS ON TS.PickSlipNo = PD.PickSlipNo AND TS.CartonNo = PD.CartonNo AND TS.SKU = PD.SKU
	  --JOIN SKU S WITH(NOLOCK) ON S.SKU=TS.SKU AND S.StorerKey = PD.StorerKey
	  --WHERE TS.PickSlipNo = @c_MPickslipno
	  --AND   TS.cartonno     = @n_Mcartonno
	  --AND S.Measurement = @c_measurement
	  --GROUP BY TS.SIZE,TS.SUSR1
	  --ORDER BY TS.SUSR1
   
      DECLARE  C_SKU_MSize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  --    SELECT DISTINCT ISNULL(RTRIM(SKU.Size),'')
  --    ,SUM(PACKDETAIL.qty)
	 -- 	FROM PACKHEADER  WITH (NOLOCK)  
		--	JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)
		--	JOIN SKU         WITH (NOLOCK) ON (PACKDETAIL.Storerkey  = SKU.Storerkey)     
		--												AND(PACKDETAIL.Sku        = SKU.Sku)
		----	LEFT JOIN CODELKUP (nolock) ON LISTNAME='BWSSIZECON' and UDF01=SKU.size and UDF03=SKU.CLASS
		--	WHERE PACKHEADER.PickSlipNo = @c_MPickslipno
		--	AND   PACKDETAIL.cartonno     = @n_Mcartonno
		--	AND SKU.Measurement = @c_measurement
  --       GROUP BY ISNULL(RTRIM(SKU.Size),'')
  --       ORDER BY ISNULL(RTRIM(SKU.Size),'')
  
	  SELECT DISTINCT TS.SIZE,SUM(PD.qty),TS.SUSR1
	  FROM PACKDETAIL  PD WITH (NOLOCK)
	  JOIN #TEMPSKU TS ON TS.PickSlipNo = PD.PickSlipNo AND TS.CartonNo = PD.CartonNo AND TS.SKU = PD.SKU
	  JOIN SKU S WITH(NOLOCK) ON S.SKU=TS.SKU AND S.StorerKey = PD.StorerKey
	  WHERE TS.PickSlipNo = @c_MPickslipno
	  AND   TS.cartonno     = @n_Mcartonno
	  AND S.Measurement = @c_measurement
	  GROUP BY TS.SIZE,TS.SUSR1
	  ORDER BY TS.SUSR1
  
   
   
	  OPEN C_SKU_MSize 
	  FETCH NEXT FROM C_SKU_MSize INTO @c_Msize,@n_getqty ,@c_susr1  
  
	  WHILE (@@FETCH_STATUS <> -1) 
	  BEGIN 
  	
	  IF NOT EXISTS (SELECT 1 FROM #TempSKUSize50 WHERE SName=@c_measurement)
	  BEGIN
  		 INSERT INTO #TempSKUSize50 (PickSlipNo,CartonNo,sname,size1,size2,size3,size4,size5,size6,size7,
  											  size8,size9,size10,size11,size12,size13,STYPE)
  		 VALUES (@c_MPickslipno,@n_Mcartonno,@c_measurement,'','','','','','','','','','','','','','Measurement')  	 
	  END
   
     IF ISNULL(@c_Msize,'') <> ''
     BEGIN
     
	  IF @c_Msize = @c_getsize1
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size1 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize2
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size2 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize3
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size3 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize4
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size4 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize5
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size5 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize6
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size6 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize7
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size7 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize8
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size8 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize9
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size9 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize10
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size10 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize11
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size11 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize12
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size12 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize13
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size13 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
	END
	ELSE
	BEGIN
     
  		UPDATE #TempSKUSize50
  		SET Size1 = convert(NVARCHAR(10),@n_getqty)
  		WHERE sname= @c_measurement

	END	
 
 
	  FETCH NEXT FROM C_SKU_MSize INTO @c_Msize,@n_getqty,@c_susr1  
	  END  
  
	  CLOSE C_SKU_MSize  
	  DEALLOCATE C_SKU_MSize
			
	  FETCH NEXT FROM C_SKU_M INTO @c_measurement,@c_MPickslipno,@n_Mcartonno
	  END   
 
	  CLOSE C_SKU_M  
	  DEALLOCATE C_SKU_M  
	 	        
	 --Get Measument End		
	  END
	  ELSE
	  BEGIN
	  	
	  	   INSERT INTO #TEMPSIZE (PickSlipNo,CartonNo,sname,SSize,SUSR1)
         SELECT DISTINCT TS.PickSlipNo
		                         ,TS.cartonno,
		                          --CONVERT(Float,ISNULL(RTRIM(SKU.Size),'')	) 
		                          codelkup.long,
		                          CONVERT(Float,ISNULL(RTRIM(CODELKUP.UDF02),'')),TS.SUSR1 
         FROM #TEMPSKU TS
			LEFT JOIN CODELKUP (nolock) ON LISTNAME='BWSSIZECON' and UDF01=TS.size and UDF03=TS.CLASS
			AND   
            (CASE  
             WHEN ISNULL(TS.BUSR5,'')='Vionic' THEN TS.BUSR5  
             WHEN ISNULL(TS.BUSR5,'')<> 'Vionic' THEN ''  
             END   
            ) = ISNULL(code2,'')
			WHERE TS.PickSlipNo = @c_PickSlipNo
			AND   TS.cartonno     = @c_CartonNo
		   --ORDER BY CODELKUP.long,CONVERT(Float,ISNULL(RTRIM(CODELKUP.UDF02),'')) --CONVERT(Float,ISNULL(RTRIM(SKU.Size),'')	) 
         ORDER BY codelkup.long,TS.SUSR1
	  		
	  		DECLARE C_SizeName CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT DISTINCT Pickslipno,cartonno,sname
			FROM #TEMPSIZE TSZ
			WHERE pickslipno = @c_PickSlipNo
			AND CartonNo = @c_CartonNo
			ORDER BY sname
			
		  OPEN C_SizeName 
		  FETCH NEXT FROM C_SizeName INTO @c_getpickslipno,@n_Getcartonno,@c_Sname
  
	     WHILE (@@FETCH_STATUS <> -1) 
		  BEGIN 
		  	
		  	  SET @c_size1 = ''
			  SET @c_size2 = ''
			  SET @c_size3 = ''
			  SET @c_size4 = ''
			  SET @c_size5 = ''
			  SET @c_size6 = ''
			  SET @c_size7 = ''
			  SET @c_size8 = ''
			  SET @c_size9 = ''
			  SET @c_size10 = ''
			  SET @c_size11 = ''
			  SET @c_size12 = ''
			  SET @c_size13 = ''
	  		  	   
	  	   DECLARE  C_Lebelno CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
			SELECT SSize
			FROM #TEMPSIZE TSZ
			WHERE pickslipno = @c_PickSlipNo
			AND CartonNo = @c_CartonNo
			AND SNAME = @c_Sname
			ORDER BY TSZ.SUSR1
			
			
			  SET @n_CurentRow = 1
			  SET @c_size1 = ''
			  SET @c_size2 = ''
			  SET @c_size3 = ''
			  SET @c_size4 = ''
			  SET @c_size5 = ''
			  SET @c_size6 = ''
			  SET @c_size7 = ''
			  SET @c_size8 = ''
			  SET @c_size9 = ''
			  SET @c_size10 = ''
			  SET @c_size11 = ''
			  SET @c_size12 = ''
			  SET @c_size13 = ''
  
		  OPEN C_Lebelno 
		  FETCH NEXT FROM C_Lebelno INTO @c_getsize
  
		  WHILE (@@FETCH_STATUS <> -1) 
		  BEGIN 
  	
  				IF @n_CurentRow = 1 
  				BEGIN
  					SET @c_size1= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 2
  				BEGIN
  					SET @c_size2= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 3
  				BEGIN
  					SET @c_size3= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 4
  				BEGIN
  					SET @c_size4= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 5
  				BEGIN
  					SET @c_size5= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 6
  				BEGIN
  					SET @c_size6= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 7
  				BEGIN
  					SET @c_size7= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 8
  				BEGIN
  					SET @c_size8= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 9
  				BEGIN
  					SET @c_size9= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 10
  				BEGIN
  					SET @c_size10= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END 
  				ELSE IF @n_CurentRow = 11
  				BEGIN
  					SET @c_size11= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END
  				ELSE IF @n_CurentRow = 12
  				BEGIN
  					SET @c_size12= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END
  				ELSE IF @n_CurentRow = 13
  				BEGIN
  					SET @c_size13= @c_getsize--CONVERT(NVARCHAR(10),@n_Size)
  				END
  	
          SET @n_CurentRow = @n_CurentRow + 1
  	
		  FETCH NEXT FROM C_Lebelno INTO @c_getsize   
		  END   
 
		  CLOSE C_Lebelno  
		  DEALLOCATE C_Lebelno  
  
  
	  INSERT INTO #TempSKUSize50
					  (PickSlipNo         , 
						CartonNo           , 
						Sname              ,
						SIZE1              , 
						SIZE2              , 
						SIZE3              , 
						SIZE4              , 
						SIZE5              , 
						SIZE6              , 
						SIZE7              , 
						SIZE8              , 
						SIZE9              , 
						SIZE10             , 
						SIZE11             , 
						SIZE12             , 
						SIZE13             ,
					   STYPE)  
         VALUES(@c_Getpickslipno,@n_Getcartonno,@c_sname,@c_size1,@c_size2,@c_size3,@c_size4,@c_size5,
                @c_size6,@c_size7,@c_size8,@c_size9,@c_size10,@c_size11,@c_size12,@c_size13,'Size')          
            
         /*  INSERT INTO #TEMPSizeResult
					  (Sname              ,
						SIZE1              , 
						SIZE2              , 
						SIZE3              , 
						SIZE4              , 
						SIZE5              , 
						SIZE6              , 
						SIZE7              , 
						SIZE8              , 
						SIZE9              , 
						SIZE10             , 
						SIZE11             , 
						SIZE12             , 
						SIZE13             ,
						STYPE )      
              
          SELECT DISTINCT long AS SNAME ,T50.size1 AS Size1,T50.size2 AS Size2,T50.size3 AS Size3,
		                   T50.SIZE4 AS Size4,T50.SIZE5 AS Size5,T50.SIZE6 AS Size6,
		                   T50.SIZE7 AS Size7,T50.SIZE8 AS Size8,T50.SIZE9 AS Size9,
		                   T50.SIZE10 AS Size10,T50.SIZE11 AS Size11,T50.SIZE12 AS Size12,T50.SIZE13 AS Size13,'Size'
		  -- INTO #TEMPSizeResult                
			FROM PACKHEADER  WITH (NOLOCK)  
			JOIN PACKDETAIL  WITH (NOLOCK) ON (PACKHEADER.PickSlipNo = PACKDETAIL.PickSlipNo)   
			JOIN BillOfMaterial AS bom WITH (NOLOCK) ON bom.SKU = PACKDETAIL.SKU  
			                                 AND bom.StorerKey = PACKDETAIL.StorerKey
		    JOIN SKU S WITH (NOLOCK) ON S.sku=bom.ComponentSku AND s.StorerKey=bom.Storerkey	
		    LEFT JOIN CODELKUP (nolock) ON LISTNAME='BWSSIZECON' and UDF01=S.size and UDF03=S.CLASS
			JOIN #TempSKUSize50 T50 WITH (NOLOCK) ON T50.PickSlipNo=PACKDETAIL.PickSlipNo AND T50.CartonNo=PACKDETAIL.CartonNo
			WHERE PACKHEADER.PickSlipNo = @c_PickSlipNo
			AND   PACKDETAIL.cartonno     = @c_CartonNo
		   ORDER BY long	  */
		   
		  FETCH NEXT FROM C_SizeName INTO @c_getpickslipno,@n_Getcartonno,@c_Sname 
		  END   
 
		  CLOSE C_SizeName  
		  DEALLOCATE C_SizeName    
		  --Get Measument start
		  
		  
	 
	 DECLARE  C_SKU_M CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TSM.measurement,TSM.PickSlipNo,TSM.CartonNo
	  	 FROM #TEMPSKUM  TSM WITH (NOLOCK)  
			WHERE TSM.PickSlipNo = @c_PickSlipNo
			AND   TSM.cartonno     = @c_CartonNo
   ORDER BY TSM.RowID
   
  OPEN C_SKU_M 
  FETCH NEXT FROM C_SKU_M INTO @c_measurement,@c_MPickslipno,@n_Mcartonno
  
  WHILE (@@FETCH_STATUS <> -1) 
  BEGIN 
  	
  	          SET @c_getsize1 = '' 
				 SET @c_getsize2 = '' 
				 SET @c_getsize3 = '' 
				 SET @c_getsize4 = '' 
				 SET @c_getsize5 = '' 
				 SET @c_getsize6 = '' 
				 SET @c_getsize7 = '' 
				 SET @c_getsize8 = '' 
				 SET @c_getsize9 = '' 
				 SET @c_getsize10 = ''
				 SET @c_getsize11 = ''
				 SET @c_getsize12 = ''
				 SET @c_getsize13 = ''
				 
	SELECT   @c_getsize1    = Size1 
			  ,@c_getsize2    = Size2 
			  ,@c_getsize3    = Size3 
			  ,@c_getsize4    = Size4 
			  ,@c_getsize5    = Size5 
			  ,@c_getsize6    = Size6 
			  ,@c_getsize7    = Size7 
			  ,@c_getsize8    = Size8 
			  ,@c_getsize9    = Size9 
			  ,@c_getsize10   = Size10
			  ,@c_getsize11   = Size11
			  ,@c_getsize12   = Size12
			  ,@c_getsize13   = Size13
	FROM #TempSKUSize50 AS t
	WHERE t.PickSlipNo=@c_MPickslipno
	AND t.CartonNo = @n_Mcartonno
	AND t.STYPE='SIZE'
	
   
      DECLARE  C_SKU_MSize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
       SELECT DISTINCT TS.SIZE,SUM(bom.qty),TS.SUSR1
		FROM PACKDETAIL  PD WITH (NOLOCK)
		JOIN BillOfMaterial AS bom WITH (NOLOCK) ON bom.SKU = PD.SKU  
												AND bom.StorerKey = PD.StorerKey
		JOIN #TEMPSKU TS ON TS.PickSlipNo = PD.PickSlipNo AND TS.CartonNo = PD.CartonNo AND TS.SKU = bom.componentSKU										
		JOIN SKU S WITH(NOLOCK) ON S.SKU=TS.SKU AND S.StorerKey = PD.StorerKey
		WHERE TS.PickSlipNo = @c_MPickslipno
		AND   TS.cartonno     = @n_Mcartonno
		AND S.Measurement = @c_measurement
		GROUP BY TS.SIZE,TS.SUSR1
		ORDER BY TS.SUSR1
   
   
	  OPEN C_SKU_MSize 
	  FETCH NEXT FROM C_SKU_MSize INTO @c_Msize,@n_getqty,@c_susr1  
  
	  WHILE (@@FETCH_STATUS <> -1) 
	  BEGIN 
  	
	  IF NOT EXISTS (SELECT 1 FROM #TempSKUSize50 WHERE SName=@c_measurement)
	  BEGIN
  		 INSERT INTO #TempSKUSize50 (PickSlipNo,CartonNo,sname,size1,size2,size3,size4,size5,size6,size7,
  											  size8,size9,size10,size11,size12,size13,STYPE)
  		 VALUES (@c_MPickslipno,@n_Mcartonno,@c_measurement,'','','','','','','','','','','','','','Measurement')  	 
	  END
   IF ISNULL(@c_Msize,'') <> ''
   BEGIN
	  IF @c_Msize = @c_getsize1
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size1 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize2
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size2 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
  
	  IF @c_Msize = @c_getsize3
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size3 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize4
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size4 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize5
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size5 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize6
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size6 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize7
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size7 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize8
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size8 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize9
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size9 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize10
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size10 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize11
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size11 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize12
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size12 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
  
	  IF @c_Msize = @c_getsize13
	  BEGIN
  		  UPDATE #TempSKUSize50
  		  SET Size13 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
	  END
   END
   ELSE
   BEGIN
   	  UPDATE #TempSKUSize50
  		  SET Size1 = convert(NVARCHAR(10),@n_getqty)
  		  WHERE sname= @c_measurement
   END  
 
  FETCH NEXT FROM C_SKU_MSize INTO @c_Msize,@n_getqty,@c_susr1 
  END  
  
  CLOSE C_SKU_MSize  
  DEALLOCATE C_SKU_MSize
			
  FETCH NEXT FROM C_SKU_M INTO @c_measurement,@c_MPickslipno,@n_Mcartonno
  END   
 
  CLOSE C_SKU_M  
  DEALLOCATE C_SKU_M  
	 	        
	 --Get Measument End	 
		                          
	  END	
	  
	  
	  SELECT @n_CntM = COUNT (1)
	  FROM #TempSKUSize50 
	  WHERE Stype='Measurement'
	  
	  WHILE @n_CntM< @n_MaxCnt
	  BEGIN
	  	
	  	 INSERT INTO #TempSKUSize50 (PickSlipNo,CartonNo,sname,size1,size2,size3,size4,size5,size6,size7,
  	                             size8,size9,size10,size11,size12,size13,STYPE)
  	    VALUES ('','','','','','','','','','','','','','','','','Measurement')  	 
  	 
  	   SET @n_CntM = @n_CntM + 1
	  	
	  END
	 
  SELECT id,sname,SIZE1,SIZE2,SIZE3,SIZE4,SIZE5,SIZE6,SIZE7,SIZE8,SIZE9,
         SIZE10,SIZE11,SIZE12,SIZE13,STYPE
    FROM #TempSKUSize50 
  --ORDER BY s_size
  --ORDER BY SType DESC,S_Name,S_Size
  
   DROP TABLE #TEMPSKU
  
   DROP TABLE #TEMPSKUM
	
	DROP TABLE #TempSKUSize50
	
	DROP TABLE #TEMPSizeResult
	--DROP TABLE #TempSKUMea50
END

GO