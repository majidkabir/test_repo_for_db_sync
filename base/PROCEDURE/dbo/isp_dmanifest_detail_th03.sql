SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/************************************************************************/  
/* Stored Procedure: isp_dmanifest_detail_th03                          */  
/* Creation Date: 27-Oct-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-15572 - TH-Elanco CR Delivery Manifest for CPF          */  
/*                                                                      */  
/*                                                                      */  
/* Called By: report dw = r_dw_dmanifest_detail_th03                    */  
/*                                                                      */  
/* GitLab Version: 1.0                                                  */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
CREATE PROC [dbo].[isp_dmanifest_detail_th03] (  
   @c_MBOLKey NVARCHAR(10)  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET ANSI_DEFAULTS OFF  
  
   DECLARE @c_QRDelimiter     NVARCHAR(10) = '(!)'
         , @c_Externorderkey  NVARCHAR(50) = ''
         , @c_Descr           NVARCHAR(50) = ''
         , @c_Lottable02      NVARCHAR(MAX) = ''
         , @c_Lottable03      NVARCHAR(MAX) = ''
         , @c_Lottable04      NVARCHAR(MAX) = ''
         , @c_Q2              NVARCHAR(50) = ''
         , @c_Q4              NVARCHAR(50) = ''
         , @c_Q9              NVARCHAR(50) = ''
         , @c_FinalQR         NVARCHAR(MAX) = ''
         , @c_Data            NVARCHAR(MAX) = ''
         , @c_ShippedQty      NVARCHAR(50) = ''
         , @c_Storerkey       NVARCHAR(15) = ''
         , @n_CountRec        INT = 0
         , @n_RowID           INT = 1
         , @c_GetExtOrdKey    NVARCHAR(50)
         
   CREATE TABLE #TMP_QR (
   	ExternOrderkey   NVARCHAR(50) NULL,
   	Q2               NVARCHAR(50) NULL,
   	DESCR            NVARCHAR(50) NULL,
   	Q4               NVARCHAR(50) NULL,
   	Lottable02       NVARCHAR(50) NULL,
   	Lottable03       NVARCHAR(50) NULL,
   	Lottable04       NVARCHAR(10) NULL,
   	ShippedQty       NVARCHAR(5)  NULL,
   	Q9               NVARCHAR(50) NULL,
   	FinalQR          NVARCHAR(4000) NULL )
   
   CREATE TABLE #TMP_LOTTABLE_TEMP (
   	ExternOrderkey   NVARCHAR(50)  NULL,
   	Q2               NVARCHAR(50)  NULL,
   	DESCR            NVARCHAR(50)  NULL,
   	Q4               NVARCHAR(50)  NULL,
   	QRData           NVARCHAR(MAX) NULL,
   	Q9               NVARCHAR(50)  NULL )
   	
   CREATE TABLE #TMP_LOTTABLE_TEMP1 (
   	RowID            INT NOT NULL IDENTITY(1,1),
   	ExternOrderkey   NVARCHAR(50)  NULL,
   	Q2               NVARCHAR(50)  NULL,
   	DESCR            NVARCHAR(50)  NULL,
   	Q4               NVARCHAR(50)  NULL,
   	QRData           NVARCHAR(MAX) NULL,
   	Q9               NVARCHAR(50)  NULL )
   	
   CREATE TABLE #TMP_CLKUP (
   	Code      NVARCHAR(50) NULL,
   	Long      NVARCHAR(50) NULL)
   
   CREATE TABLE #TMP_Final (
   	ExternOrderkey      NVARCHAR(50) NULL,
   	QRCount1            INT NULL,
   	QRData1             NVARCHAR(MAX) NULL,
   	QRCount2            INT NULL,
   	QRData2             NVARCHAR(MAX) NULL,
   	QRCount3            INT NULL,
   	QRData3             NVARCHAR(MAX) NULL
   )
   	
   SELECT @c_Storerkey = Storerkey
   FROM ORDERS (NOLOCK)
   WHERE MBOLKey = @c_MBOLKey
   
   INSERT INTO #TMP_CLKUP (Code, Long)	
   SELECT DISTINCT ISNULL(CL.Code,'')
                 , ISNULL(CL.Long,'')
   FROM CODELKUP CL (NOLOCK)
   WHERE CL.Storerkey = @c_Storerkey
   AND CL.LISTNAME = 'ELCREP'
   AND CL.Code IN ('R0','R1','R1-1','Q2','Q4','Q9')
   	
   INSERT INTO #TMP_QR (ExternOrderkey, Q2, DESCR, Q4,             
   	                  Lottable02, Lottable03, Lottable04,   
   	                  ShippedQty, Q9, FinalQR)     
   SELECT OH.Externorderkey
        , (SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'Q2') AS Q2
        , LEFT(LTRIM(RTRIM(ISNULL(S.DESCR,''))),50)
        , (SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'Q4') AS Q4
        , LTRIM(RTRIM(ISNULL(LA.Lottable02,'')))
        , LTRIM(RTRIM(ISNULL(LA.Lottable03,'')))
        , CONVERT(NVARCHAR(10),ISNULL(LA.Lottable04,'19000101'), 112)
        --, RIGHT('00000'+ CAST(SUM(OD.ShippedQty) AS NVARCHAR(5)), 5)
        , RIGHT('00000'+ CAST(SUM(PD.Qty) AS NVARCHAR(5)), 5)
        , (SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'Q9') AS Q9
        , ''
   FROM ORDERS OH (NOLOCK)
   JOIN PICKDETAIL PD (NOLOCK) ON OH.OrderKey = PD.OrderKey
   JOIN SKU S (NOLOCK) ON S.SKU = PD.SKU AND S.StorerKey = OH.StorerKey
   JOIN LOTATTRIBUTE LA (NOLOCK) ON LA.LOT = PD.LOT
   --JOIN ORDERDETAIL OD (NOLOCK) ON OD.OrderKey = PD.OrderKey AND OD.OrderLineNumber = PD.OrderLineNumber AND OD.SKU = PD.SKU
   --WHERE OH.OrderKey = '0020208470'
   WHERE OH.MBOLKey = @c_MBOLKey   --'0005523517'
   GROUP BY OH.Externorderkey
          , LEFT(LTRIM(RTRIM(ISNULL(S.DESCR,''))),50)
          , LTRIM(RTRIM(ISNULL(LA.Lottable02,'')))
          , LTRIM(RTRIM(ISNULL(LA.Lottable03,'')))
          , CONVERT(NVARCHAR(10),ISNULL(LA.Lottable04,'19000101'), 112)
   
   DECLARE cur_Loop CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT ExternOrderkey, Q2, DESCR, Q4,
          Lottable02,  
          Lottable03,  
          Lottable04,
          ShippedQty,
          Q9
   FROM #TMP_QR AS tq
   
   OPEN cur_Loop
   	
   FETCH NEXT FROM cur_Loop INTO @c_Externorderkey, @c_Q2, @c_Descr, @c_Q4, 
                                 @c_Lottable02, @c_Lottable03, @c_Lottable04, 
                                 @c_ShippedQty, @c_Q9
   	
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	IF LEN(LTRIM(RTRIM(ISNULL(@c_Lottable03,'')))) = 8 AND ISDATE(@c_Lottable03) = 1
      BEGIN
         SELECT @c_Lottable03 = RIGHT('00' + CAST(DATEPART(DD, CAST(@c_Lottable03 AS DATETIME)) AS NVARCHAR(2)), 2) + '.' + 
                                RIGHT('00' + CAST(DATEPART(MM, CAST(@c_Lottable03 AS DATETIME)) AS NVARCHAR(2)), 2) + '.' + 
                                CAST(DATEPART(YYYY, CAST(@c_Lottable03 AS DATETIME)) AS NVARCHAR(4))
      END
      
      IF LEN(LTRIM(RTRIM(ISNULL(@c_Lottable03,'')))) = 10
      BEGIN
         IF ISDATE(SUBSTRING(@c_Lottable03,7,4) + SUBSTRING(@c_Lottable03,4,2) + SUBSTRING(@c_Lottable03,1,2)) = 1
         BEGIN
            SET @c_Lottable03 = SUBSTRING(@c_Lottable03,7,4) + SUBSTRING(@c_Lottable03,4,2) + SUBSTRING(@c_Lottable03,1,2)
            SELECT @c_Lottable03 = RIGHT('00' + CAST(DATEPART(DD, CAST(@c_Lottable03 AS DATETIME)) AS NVARCHAR(2)), 2) + '.' + 
                                   RIGHT('00' + CAST(DATEPART(MM, CAST(@c_Lottable03 AS DATETIME)) AS NVARCHAR(2)), 2) + '.' + 
                                   CAST(DATEPART(YYYY, CAST(@c_Lottable03 AS DATETIME)) AS NVARCHAR(4))
         END
      END
      
      IF ISDATE(@c_Lottable04) = 1
      BEGIN
         SELECT @c_Lottable04 = RIGHT('00' + CAST(DATEPART(DD, CAST(@c_Lottable04 AS DATETIME)) AS NVARCHAR(2)), 2) + '.' + 
                                RIGHT('00' + CAST(DATEPART(MM, CAST(@c_Lottable04 AS DATETIME)) AS NVARCHAR(2)), 2) + '.' + 
                                CAST(DATEPART(YYYY, CAST(@c_Lottable04 AS DATETIME)) AS NVARCHAR(4))
      END
         
   	INSERT INTO #TMP_LOTTABLE_TEMP
   	SELECT @c_Externorderkey,  @c_Q2, @c_Descr, @c_Q4, 
   	       @c_Lottable02 + ',' + @c_Lottable03 + ',' + @c_Lottable04 + ',' + @c_ShippedQty,
   	       @c_Q9
   
      FETCH NEXT FROM cur_Loop INTO @c_Externorderkey, @c_Q2, @c_Descr, @c_Q4, 
                                    @c_Lottable02, @c_Lottable03, @c_Lottable04,
                                    @c_ShippedQty, @c_Q9
   END
   	
   --SELECT * FROM #TMP_LOTTABLE_TEMP
   
   DECLARE cur_QR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT ExternOrderkey, Q2, DESCR, Q4,
          STUFF((SELECT RTRIM(t1.QRData) + '|' FROM #TMP_LOTTABLE_TEMP t1  
                 WHERE t1.ExternOrderkey = tl.ExternOrderkey AND t1.DESCR = tl.DESCR
                 ORDER BY t1.QRData FOR XML PATH('')),1,0,'' ),
          Q9
   FROM #TMP_LOTTABLE_TEMP AS tl
   
   OPEN cur_QR
   	
   FETCH NEXT FROM cur_QR INTO @c_Externorderkey, @c_Q2, @c_Descr, @c_Q4, 
                               @c_Data, @c_Q9
   	
   WHILE @@FETCH_STATUS <> -1
   BEGIN
   	SET @c_Data = SUBSTRING(@c_Data, 1, LEN(@c_Data) - 1)
   	SET @c_FinalQR = ISNULL(@c_Externorderkey,'') + @c_QRDelimiter +
   	                 ISNULL(@c_Q2,'')    + @c_QRDelimiter +
   	                 ISNULL(@c_Descr,'') + @c_QRDelimiter +
   	                 ISNULL(@c_Q4,'')    + @c_QRDelimiter + 
   	                 ISNULL(@c_Data,'')  + @c_QRDelimiter + ISNULL(@c_Q9,'')
   
      UPDATE #TMP_LOTTABLE_TEMP
      SET QRData = @c_FinalQR
      WHERE ExternOrderkey = @c_Externorderkey AND DESCR = @c_Descr
      
      FETCH NEXT FROM cur_QR INTO @c_Externorderkey, @c_Q2, @c_Descr, @c_Q4, 
                                  @c_Data, @c_Q9
   END
   
   --SELECT DISTINCT (SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'R0') AS R0
   --              , (SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'R1') AS R1
   --              , (SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'R1-1') AS R1_1
   --              , ExternOrderkey
   --              , SUBSTRING(QRData,1,4000) AS QRData1
   --              , SUBSTRING(QRData,4001,4000) AS QRData2
   --              , SUBSTRING(QRData,8001,4000) AS QRData3
   --FROM #TMP_LOTTABLE_TEMP
   --ORDER BY ExternOrderkey

   --SELECT * FROM #TMP_LOTTABLE_TEMP1
   
   DECLARE cur_LoopExt CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT Externorderkey
   FROM #TMP_LOTTABLE_TEMP AS tlt
   ORDER BY Externorderkey
   
   OPEN cur_LoopExt
   
   FETCH NEXT FROM cur_LoopExt INTO @c_GetExtOrdKey
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      INSERT INTO #TMP_LOTTABLE_TEMP1 (ExternOrderkey, Q2, DESCR, Q4, QRData, Q9)
      SELECT DISTINCT ExternOrderkey
                    , Q2            
                    , DESCR         
                    , Q4            
                    , QRData        
                    , Q9            
      FROM #TMP_LOTTABLE_TEMP
      WHERE ExternOrderkey = @c_GetExtOrdKey
   
   	SELECT @n_CountRec = COUNT(1)
      FROM #TMP_LOTTABLE_TEMP1
   	WHERE ExternOrderkey = @c_GetExtOrdKey
   	
   	WHILE (@n_CountRec > 0)
      BEGIN
   	   INSERT INTO #TMP_Final
   	   SELECT @c_GetExtOrdKey
   	        , @n_RowID
   	        , (SELECT QRData FROM #TMP_LOTTABLE_TEMP1 WHERE ExternOrderkey = @c_GetExtOrdKey AND RowID = @n_RowID)
   	        , @n_RowID + 1
   	        , (SELECT QRData FROM #TMP_LOTTABLE_TEMP1 WHERE ExternOrderkey = @c_GetExtOrdKey AND RowID = @n_RowID + 1)
   	        , @n_RowID + 2
   	        , (SELECT QRData FROM #TMP_LOTTABLE_TEMP1 WHERE ExternOrderkey = @c_GetExtOrdKey AND RowID = @n_RowID + 2)
   	   
   	   SET @n_RowID = @n_RowID + 3
   	   
   	   SET @n_CountRec = @n_CountRec - 3
      END
      
   	TRUNCATE TABLE #TMP_LOTTABLE_TEMP1
   	SET @n_RowID = 1
   	
   	FETCH NEXT FROM cur_LoopExt INTO @c_GetExtOrdKey
   END
   
   SELECT DISTINCT ISNULL((SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'R0'),'') AS R0
                 , ISNULL((SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'R1'),'') AS R1
                 , ISNULL((SELECT TOP 1 Long FROM #TMP_CLKUP (NOLOCK) WHERE Code = 'R1-1'),'') AS R1_1
                 , ExternOrderkey
                 , QRCount1
                 , CAST(SUBSTRING(QRData1,1,4000) AS NVARCHAR(4000))    AS QRData1_1
                 , CAST(SUBSTRING(QRData1,4001,4000) AS NVARCHAR(4000)) AS QRData1_2
                 , CAST(SUBSTRING(QRData1,8001,4000) AS NVARCHAR(4000)) AS QRData1_3
                 , QRCount2
                 , CAST(SUBSTRING(QRData2,1,4000) AS NVARCHAR(4000))    AS QRData2_1
                 , CAST(SUBSTRING(QRData2,4001,4000) AS NVARCHAR(4000)) AS QRData2_2
                 , CAST(SUBSTRING(QRData2,8001,4000) AS NVARCHAR(4000)) AS QRData2_3
                 , QRCount3
                 , CAST(SUBSTRING(QRData3,1,4000)  AS NVARCHAR(4000))   AS QRData3_1
                 , CAST(SUBSTRING(QRData3,4001,4000) AS NVARCHAR(4000)) AS QRData3_2
                 , CAST(SUBSTRING(QRData3,8001,4000) AS NVARCHAR(4000)) AS QRData3_3
   FROM #TMP_Final
   ORDER BY ExternOrderkey
   
   IF OBJECT_ID('tempdb..#TMP_CLKUP') IS NOT NULL
      DROP TABLE #TMP_CLKUP
      
   IF OBJECT_ID('tempdb..#TMP_QR') IS NOT NULL
      DROP TABLE #TMP_QR
      
   IF OBJECT_ID('tempdb..#TMP_LOTTABLE_TEMP') IS NOT NULL
      DROP TABLE #TMP_LOTTABLE_TEMP
      
   IF OBJECT_ID('tempdb..#TMP_LOTTABLE_TEMP1') IS NOT NULL
      DROP TABLE #TMP_LOTTABLE_TEMP1
      
   IF OBJECT_ID('tempdb..#TMP_Final') IS NOT NULL
      DROP TABLE #TMP_Final
   
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   
   IF CURSOR_STATUS('LOCAL', 'cur_LoopExt') IN (0 , 1)
   BEGIN
      CLOSE cur_LoopExt
      DEALLOCATE cur_LoopExt   
   END
   
   IF CURSOR_STATUS('LOCAL', 'cur_QR') IN (0 , 1)
   BEGIN
      CLOSE cur_QR
      DEALLOCATE cur_QR   
   END
END

GO