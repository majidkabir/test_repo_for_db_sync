SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: ispPRPPLPO03                                            */
/* Creation Date: 11-Jun-2021                                           */
/* Copyright: LF Logistics                                              */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-17224 - RG Adidas Populate PO update UCC and Send Email */
/*          for sku missing pick loc                                    */
/*        :                                                             */
/* Called By:  isp_PrePopulatePO_Wrapper (PrePopulatePOSP)              */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 06-OCT-2021  NJOW      1.0 DEVOPS combine script                     */
/* 20-OCT-2021  NJOW01    1.1 WMS-17224 Fix stamp Userdefined06 to      */
/*                            Userdefined09                             */
/* 31-OCT-2021  NJOW02    1.2 WMS-17224 Back List skip stamp QC flag    */
/* 18-NOV-2021  NJOW02    1.2 DEVOPS combine script                     */
/* 26-SEP-2023  NJOW03    1.3 WMS-23734 add config for PH to stamp ucc  */
/*                            userdefined06 by max qty and count        */
/************************************************************************/
CREATE   PROC [dbo].[ispPRPPLPO03]
           @c_Receiptkey      NVARCHAR(10)
         , @c_POKeys          NVARCHAR(MAX)
         , @c_POLineNumbers   NVARCHAR(MAX) = ''
         , @b_Success         INT OUTPUT    
         , @n_Err             INT OUTPUT
         , @c_Errmsg          NVARCHAR(255) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_StartTCnt           INT
          ,@n_Continue            INT
          ,@c_POKey               NVARCHAR(10)
          ,@c_Storerkey           NVARCHAR(15)
          ,@c_Sku                 NVARCHAR(20)
          ,@c_ExternPokey         NVARCHAR(20)
          ,@c_Userdefine01_UCC    NVARCHAR(30)
          ,@c_Userdefine08        NVARCHAR(10)
          ,@c_Userdefine08Curr    NVARCHAR(10)
          ,@c_UccFound            NVARCHAR(5)
          ,@n_MaxUccNo            INT             
          ,@n_UCCCount            INT
          ,@n_NoofUCCStamp        INT
          ,@c_UCCNo               NVARCHAR(20)
          ,@n_debug               INT  
          ,@c_authority           NVARCHAR(30)
          ,@c_Option1             NVARCHAR(50)
          ,@c_option2             NVARCHAR(50)
          ,@c_option3             NVARCHAR(50)
          ,@c_option4             NVARCHAR(50)
          ,@c_option5             NVARCHAR(4000)
          ,@c_PercentageofArticle NVARCHAR(10) = ''
          ,@n_PercentageofArticle NUMERIC(12,2) = 0.00
          ,@n_NoofArticleToQC     INT = 0
          ,@n_NoofArtical_HV      INT = 0
          ,@c_Style               NVARCHAR(20)
          ,@c_BlackListSkipQCFlag NVARCHAR(10) = 'N' --NJOW02
          ,@c_UCCStampByQty       NVARCHAR(5) = 'N'  --NJOW03
          ,@n_MaxUccQty           INT --NJOW03     
          ,@n_UCCQtySum           INT --NJOW03       
          ,@n_NoofUCCQtyStamp     INT --NJOW03
          ,@n_UCCQty              INT --NJOW03
                    
   DECLARE @c_Body                NVARCHAR(MAX),         
           @c_Subject             NVARCHAR(255),          
           @c_Date                NVARCHAR(20),           
           @c_SendEmail           NVARCHAR(1),
           @c_Recipients          NVARCHAR(2000) 
           
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @n_debug = 0
   
   IF @n_continue IN(1,2)
   BEGIN
   	  --NJOW01
   	  IF CHARINDEX('|',@c_POKeys) > 0
   	     SELECT @c_POKeys = REPLACE(@c_POKeys,'|',',')    

   	  IF CHARINDEX('|',@c_POLineNumbers) > 0
   	     SELECT @c_POLineNumbers = REPLACE(@c_POLineNumbers,'|',',')       	  
   	  
      CREATE TABLE #PREPPL_PO
         (  SeqNo          INT
         ,  POKey          NVARCHAR(10)   NOT NULL DEFAULT ('')
         ,  POLineNumber   NVARCHAR(5)    NOT NULL DEFAULT ('')
         )
      
      INSERT INTO #PREPPL_PO
         (  SeqNo
         ,  POKey 
         )     
      SELECT SeqNo
         ,   ColValue
      FROM dbo.fnc_DelimSplit (',', @c_POKeys)
         
      IF @c_POLineNumbers <> ''
      BEGIN
         UPDATE #PREPPL_PO
         SET POLineNumber = ColValue
         FROM dbo.fnc_DelimSplit (',', @c_POLineNumbers) T
         WHERE #PREPPL_PO.SeqNo = T.SeqNo
      END
      
      --NJOW02
      SELECT POD.* 
      INTO #TMP_PODETAIL
      FROM PO (NOLOCK) 
      JOIN PODETAIL POD (NOLOCK) ON PO.Pokey = POD.Pokey
      LEFT JOIN RECEIPTDETAIL RD (NOLOCK) ON POD.Storerkey = RD.Storerkey AND POD.Sku = RD.Sku AND POD.Pokey = RD.Pokey AND POD.POLineNumber = RD.POLineNumber
      WHERE PO.Pokey IN(SELECT POKey FROM #PREPPL_PO)
      AND RD.Receiptkey IS NULL
   END
   
   IF @n_continue IN(1,2)
   BEGIN
      DECLARE CUR_PO CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PO.POKey, POD.ExternPokey, PO.Storerkey, POD.Sku, POD.Userdefine01,
                CASE WHEN SKU.Susr2 = '1' THEN 'HV' 
                     WHEN ISNULL(LTRIM(S.Susr1),'') = '1' THEN 'BL'
                     ELSE '' END
         FROM PO (NOLOCK)
         JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.POkey = POD.POKey
         LEFT JOIN STORER S (NOLOCK) ON PO.SellerName = S.Storerkey AND S.Type = '5'
         JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
         WHERE PO.POKey IN(SELECT POKey FROM #PREPPL_PO)
         AND (SKU.SUSR2 = '1' OR ISNULL(LTRIM(S.Susr1),'') = '1')
                   
      OPEN CUR_PO  
      
      FETCH NEXT FROM CUR_PO INTO @c_Pokey, @c_ExternPOKey, @c_Storerkey, @c_Sku, @c_Userdefine01_UCC, @c_Userdefine08
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	  --IF EXISTS(SELECT 1 FROM UCC (NOLOCK) 
      	  --          WHERE ExternKey = @c_ExternPOKey 
      	  --          AND UCCNo = @c_Userdefine01_UCC 
      	  --          AND Storerkey = @c_Storerkey)      	  
      	  --          AND Sku = @c_Sku)
      	  
      	  SET @c_UccFound = '0' 
      	  SET @c_Userdefine08Curr = ''
      	  SELECT @c_Userdefine08Curr = ISNULL(MAX(Userdefined08),''),
      	         @c_UccFound = '1' 
          FROM UCC (NOLOCK)       	         
      	  WHERE ExternKey = @c_ExternPOKey 
      	  AND UCCNo = @c_Userdefine01_UCC 
      	  AND Storerkey = @c_Storerkey    
      	  
      	  IF @c_Userdefine08Curr = 'HV'
      	     SET @c_Userdefine08 = 'HV'
      	  ELSE IF @c_Userdefine08Curr = 'BL' AND @c_Userdefine08 = ''
      	     SET @c_Userdefine08 = 'BL'
      	  
      	  IF @c_UccFound = '1'          
      	  BEGIN
      	     UPDATE UCC WITH (ROWLOCK)
      	     SET Userdefined08 = @c_Userdefine08, 
      	         TrafficCop = NULL
      	     WHERE ExternKey = @c_ExternPOKey 
      	     AND UCCNo = @c_Userdefine01_UCC 
      	     AND Storerkey = @c_Storerkey
      	     --AND Sku = @c_Sku
      	     
            SELECT @n_err = @@ERROR                                                                                                                                                        
            IF @n_err <> 0                                                                                                                                                                 
            BEGIN                                                                                                                                                                          
               SELECT @n_continue = 3                                                                                                                                                      
               SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83000  -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                     
               SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispPRPPLPO03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '            
            END                                                                                                                                                                               	     
      	  END             	  
         	  
         FETCH NEXT FROM CUR_PO INTO @c_Pokey, @c_ExternPOKey, @c_Storerkey, @c_Sku, @c_Userdefine01_UCC, @c_Userdefine08
      END
      CLOSE CUR_PO
      DEALLOCATE CUR_PO             	
   END

   IF @n_continue IN(1,2)
   BEGIN
      SELECT TOP 1 @c_Storerkey = Storerkey
      FROM PO (NOLOCK)
      WHERE POKey IN(SELECT POKey FROM #PREPPL_PO)
      
      Execute nspGetRight                                
         @c_Facility  = '',                     
         @c_StorerKey = @c_StorerKey,                    
         @c_sku       = '',                          
         @c_ConfigKey = 'PrePopulatePOSP',    
         @b_Success   = @b_success   OUTPUT,             
         @c_authority = @c_authority OUTPUT,             
         @n_err       = @n_err       OUTPUT,             
         @c_errmsg    = @c_errmsg    OUTPUT,             
         @c_Option1   = @c_option1 OUTPUT,               
         @c_Option2   = @c_option2 OUTPUT,               
         @c_Option3   = @c_option3 OUTPUT,               
         @c_Option4   = @c_option4 OUTPUT,               
         @c_Option5   = @c_option5 OUTPUT               

      SELECT @c_PercentageofArticle = dbo.fnc_GetParamValueFromString('@c_PercentageofArticle', @c_option5, @c_PercentageofArticle)
      SELECT @c_BlackListSkipQCFlag = dbo.fnc_GetParamValueFromString('@c_BlackListSkipQCFlag', @c_option5, @c_BlackListSkipQCFlag) --NJOW02
      SELECT @c_UCCStampByQty = dbo.fnc_GetParamValueFromString('@c_UCCStampByQty', @c_option5, @c_UCCStampByQty) --NJOW03

      IF ISNUMERIC(@c_PercentageofArticle) = 1 
      BEGIN
      	 SELECT @n_PercentageofArticle = CONVERT(NUMERIC(12,2), @c_PercentageofArticle) / 100.00

      	 SELECT @n_NoofArticleToQC = CEILING(@n_PercentageofArticle * COUNT(DISTINCT SKU.Style))
      	 FROM PO (NOLOCK)
      	 JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.Pokey = POD.Pokey
      	 JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
      	 LEFT JOIN STORER S (NOLOCK) ON PO.SellerName = S.Storerkey AND S.Type = '5' AND S.Susr1 = '1' AND @c_BlackListSkipQCFlag = 'Y'  --NJOW02
      	 WHERE PO.Pokey IN(SELECT POKey FROM #PREPPL_PO) 
      	 AND S.Storerkey IS NULL --NJOW02
      	       	       	 
      	 SELECT @n_NoofArtical_HV = COUNT(DISTINCT SKU.Style)
      	 FROM PO (NOLOCK)
      	 JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.Pokey = POD.Pokey
      	 JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
      	 JOIN UCC (NOLOCK) ON UCC.Externkey = POD.ExternPokey AND UCC.UccNo = POD.Userdefine01 AND UCC.Storerkey = PO.Storerkey AND UCC.Userdefined08 = 'HV'
      	 LEFT JOIN STORER S (NOLOCK) ON PO.SellerName = S.Storerkey AND S.Type = '5' AND S.Susr1 = '1' AND @c_BlackListSkipQCFlag = 'Y'  --NJOW02
      	 WHERE PO.Pokey IN(SELECT POKey FROM #PREPPL_PO)
      	 AND S.Storerkey IS NULL --NJOW02
      	 
      	 SELECT @n_NoofArticleToQC = @n_NoofArticleToQC - @n_NoofArtical_HV 
      	 
      	 IF @n_NoofArticleToQC > 0
      	 BEGIN
      	    DECLARE CUR_ARTICLE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      	       SELECT SKU.Style
      	       FROM PO (NOLOCK)
      	       JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.Pokey = POD.Pokey
      	       JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
      	       JOIN UCC (NOLOCK) ON UCC.Externkey = POD.ExternPokey AND UCC.UccNo = POD.Userdefine01 AND UCC.Storerkey = PO.Storerkey AND UCC.Sku = POD.Sku AND UCC.Userdefined08 <> 'HV' 
          	   LEFT JOIN STORER S (NOLOCK) ON PO.SellerName = S.Storerkey AND S.Type = '5' AND S.Susr1 = '1' AND @c_BlackListSkipQCFlag = 'Y'  --NJOW02
      	       WHERE PO.Pokey IN(SELECT POKey FROM #PREPPL_PO)
      	       AND ISNULL(SKU.SUSR2,'') <> '1'
            	 AND S.Storerkey IS NULL --NJOW02
      	       GROUP BY SKU.Style
      	       ORDER BY SUM(POD.QtyOrdered), SKU.Style 

            OPEN CUR_ARTICLE  
      
            FETCH NEXT FROM CUR_ARTICLE INTO @c_Style
            
            WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_NoofArticleToQC > 0
            BEGIN
               DECLARE CUR_UCC_QC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
                  SELECT UCC.UccNo          
          	      FROM PO (NOLOCK)                     
      	          JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.Pokey = POD.Pokey
      	          JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
      	          JOIN UCC (NOLOCK) ON UCC.Externkey = POD.ExternPokey AND UCC.UccNo = POD.Userdefine01 AND UCC.Storerkey = PO.Storerkey AND UCC.Userdefined08 <> 'HV' 
              	  LEFT JOIN STORER S (NOLOCK) ON PO.SellerName = S.Storerkey AND S.Type = '5' AND S.Susr1 = '1' AND @c_BlackListSkipQCFlag = 'Y'  --NJOW02
      	          WHERE PO.Pokey IN(SELECT POKey FROM #PREPPL_PO)
      	          AND ISNULL(SKU.SUSR2,'') <> '1'
      	          AND SKU.Style = @c_Style
               	  AND S.Storerkey IS NULL --NJOW02
                          
               OPEN CUR_UCC_QC
               
               FETCH NEXT FROM CUR_UCC_QC INTO @c_UCCNo                        
                          
               WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
               BEGIN
      	          UPDATE UCC WITH (ROWLOCK)
      	          SET Userdefined09 = '1',   --NJOW01
      	              TrafficCop = NULL
      	          WHERE UCCNo = @c_UCCNo
      	          AND Storerkey = @c_Storerkey
      	          --AND Sku = @c_Sku
      	          
                  SELECT @n_err = @@ERROR                                                                                                                                                        
                  IF @n_err <> 0                                                                                                                                                                 
                  BEGIN                                                                                                                                                                          
                     SELECT @n_continue = 3                                                                                                                                                      
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83010  -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                     
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispPRPPLPO03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '            
                  END                                                                                                                                                                               	                    	
                  
                  FETCH NEXT FROM CUR_UCC_QC INTO @c_UCCNo             	
               END
               CLOSE CUR_UCC_QC
               DEALLOCATE CUR_UCC_QC                                      	  
            	
            	 SET @n_NoofArticleToQC = @n_NoofArticleToQC - 1
            	  
               FETCH NEXT FROM CUR_ARTICLE INTO @c_Style
            END
            CLOSE CUR_ARTICLE
            DEALLOCATE CUR_ARTICLE                  	          	       
      	 END      	 
      END           
   END   
   
   IF @n_continue IN(1,2) AND @c_UCCStampByQty <> 'Y'  --NJOW03
   BEGIN   	
   	   DECLARE CUR_POSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PO.Storerkey, POD.Sku, ISNULL(MXU.MaxUccNo,0)      
         FROM PO (NOLOCK)
         JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.POkey = POD.POKey
         JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
         JOIN V_STORERCONFIG2 SC (NOLOCK) ON PO.Storerkey = SC.Storerkey AND SC.Configkey = 'INSERTUCC' AND SC.Svalue = '1'          
         OUTER APPLY (SELECT TOP 1 CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END AS MaxUccNo 
                      FROM CODELKUP CL (NOLOCK) WHERE CL.Storerkey = SKU.Storerkey AND CL.Code = SKU.Skugroup AND CL.ListName = 'MAXUCCNO') MXU              
         WHERE PO.POKey IN(SELECT POKey FROM #PREPPL_PO)
         AND (SKU.Length = 0 OR SKU.Width = 0 OR SKU.Height = 0)
         AND ISNULL(MXU.MaxUccNo,0) > 0
         GROUP BY PO.Storerkey, POD.Sku, MXU.MaxUccNo
                   
      OPEN CUR_POSKU  
      
      FETCH NEXT FROM CUR_POSKU INTO @c_Storerkey, @c_Sku, @n_MaxUccNo

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	  SET @n_UCCCount = 0   
      	  SELECT @n_UCCCount = COUNT(1)
          FROM UCC (NOLOCK)
          WHERE Storerkey = @c_Storerkey          
          AND Sku = @c_Sku
          AND UserDefined06 = '1'
          AND [Status] IN ('0','1')
          
          IF @n_debug = 1
          BEGIN
             PRINT '@c_Sku:' + RTRIM(@c_Sku) + ' @n_MaxUccNo:' + RTRIM(CAST(@n_MaxUccNo AS NVARCHAR)) + ' @n_UCCCount:' + RTRIM(CAST(@n_UCCCount AS NVARCHAR))      
          END
         
          IF @n_UCCCount < @n_MaxUCCNo
          BEGIN
             SET @n_NoofUCCStamp = @n_MaxUCCNo - @n_UCCCount 

             IF @n_debug = 1
             BEGIN
                PRINT '@n_NoofUCCStamp:' + RTRIM(CAST(@n_NoofUCCStamp AS NVARCHAR)) 
             END
             
             DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT UCCNo
               FROM UCC (NOLOCK) 
               OUTER APPLY (SELECT TOP 1 POD.Userdefine01 FROM PO (NOLOCK)
                            JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.POkey = POD.POKey
                            WHERE PO.POKey IN(SELECT POKey FROM #PREPPL_PO)
                            AND POD.Userdefine01 = UCC.UccNo
                            AND POD.Storerkey = UCC.Storerkey
                            ) AS POUCC
               WHERE UCC.Status IN('0','1')
               AND UCC.UserDefined06 <> '1'
               AND UCC.Storerkey = @c_Storerkey
               AND UCC.Sku = @c_Sku
               GROUP BY UCC.UCCNo, POUCC.Userdefine01, UCC.Userdefined07
               ORDER BY CASE WHEN POUCC.Userdefine01 IS NOT NULL THEN 1 ELSE 2 END, 
                        CASE WHEN UCC.Userdefined07 = '1' THEN 1 ELSE 2 END,
                        UCC.UCCNo
                        
             OPEN CUR_UCC
             
             FETCH NEXT FROM CUR_UCC INTO @c_UCCNo                        
                        
             WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_NoofUCCStamp > 0
             BEGIN
      	        UPDATE UCC WITH (ROWLOCK)
      	        SET Userdefined06 = '1', 
      	            TrafficCop = NULL
      	        WHERE UCCNo = @c_UCCNo
      	        AND Storerkey = @c_Storerkey
      	        --AND Sku = @c_Sku
      	        
                SELECT @n_err = @@ERROR                                                                                                                                                        
                IF @n_err <> 0                                                                                                                                                                 
                BEGIN                                                                                                                                                                          
                   SELECT @n_continue = 3                                                                                                                                                      
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                     
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispPRPPLPO03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '            
                END                                                                                                                                                                               	     
             	
                SET @n_NoofUCCStamp = @n_NoofUCCStamp -  1
                
                FETCH NEXT FROM CUR_UCC INTO @c_UCCNo             	
             END
             CLOSE CUR_UCC
             DEALLOCATE CUR_UCC                                                               
          END
          
          FETCH NEXT FROM CUR_POSKU INTO @c_Storerkey, @c_Sku, @n_MaxUccNo                                                                	       	       	     
      END	  
      CLOSE CUR_POSKU
      DEALLOCATE CUR_POSKU                          	   
   END

   --NJOW03 S
   IF @n_continue IN(1,2) AND @c_UCCStampByQty = 'Y'  
   BEGIN   	
   	   DECLARE CUR_POSKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT PO.Storerkey, POD.Sku, ISNULL(MXU.MaxUccNo,0), ISNULL(MXU.MaxUccQty,0)
         FROM PO (NOLOCK)
         JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.POkey = POD.POKey
         JOIN SKU (NOLOCK) ON POD.Storerkey = SKU.Storerkey AND POD.Sku = SKU.Sku
         JOIN V_STORERCONFIG2 SC (NOLOCK) ON PO.Storerkey = SC.Storerkey AND SC.Configkey = 'INSERTUCC' AND SC.Svalue = '1'          
         OUTER APPLY (SELECT TOP 1 CASE WHEN ISNUMERIC(CL.Short) = 1 THEN CAST(CL.Short AS INT) ELSE 0 END AS MaxUccNo,
                                   CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS INT) ELSE 0 END AS MaxUccQty
                      FROM CODELKUP CL (NOLOCK) WHERE CL.Storerkey = SKU.Storerkey AND CL.Code = SKU.Skugroup AND CL.ListName = 'MAXUCCNO') MXU              
         WHERE PO.POKey IN(SELECT POKey FROM #PREPPL_PO)
         AND (SKU.Length = 0 OR SKU.Width = 0 OR SKU.Height = 0)
         AND ISNULL(MXU.MaxUccNo,0) > 0
         GROUP BY PO.Storerkey, POD.Sku, ISNULL(MXU.MaxUccNo,0), ISNULL(MXU.MaxUccQty,0)
                   
      OPEN CUR_POSKU  
      
      FETCH NEXT FROM CUR_POSKU INTO @c_Storerkey, @c_Sku, @n_MaxUccNo, @n_MaxUccQty

      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)
      BEGIN
      	  SET @n_UCCCount = 0
      	  SET @n_UCCQtySum = 0   
      	  
      	  /*
      	  SELECT @n_UCCCount = COUNT(1),
      	         @n_UCCQtySum = SUM(Qty)
          FROM UCC (NOLOCK)
          WHERE Storerkey = @c_Storerkey          
          AND Sku = @c_Sku
          AND UserDefined06 = '1'
          AND [Status] IN ('0','1')
          */
          
          IF @n_MaxUccQty = 0
             SET @n_MaxUccQty = 9999999
          
          IF @n_debug = 1
          BEGIN
             PRINT '@c_Sku:' + RTRIM(@c_Sku) + ' @n_MaxUccNo:' + RTRIM(CAST(@n_MaxUccNo AS NVARCHAR)) + ' @n_UCCCount:' + RTRIM(CAST(@n_UCCCount AS NVARCHAR)) + ' @n_MaxUccQty:' + RTRIM(CAST(@n_MaxUccQty AS NVARCHAR)) 
          END
         
          IF @n_UCCCount < @n_MaxUCCNo
             AND @n_UCCQtySum < @n_MaxUccQty
          BEGIN
             SET @n_NoofUCCStamp = @n_MaxUCCNo - @n_UCCCount 
             SET @n_NoofUCCQtyStamp = @n_MaxUccQty - @n_UCCQtySum 
             
             IF @n_debug = 1
             BEGIN
                PRINT '@n_NoofUCCStamp:' + RTRIM(CAST(@n_NoofUCCStamp AS NVARCHAR))  + ' @n_NoofUCCQtyStamp:' + RTRIM(CAST(@n_NoofUCCQtyStamp AS NVARCHAR)) 
             END
             
             DECLARE CUR_UCC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
               SELECT UCCNo, SUM(Qty)
               FROM UCC (NOLOCK) 
               OUTER APPLY (SELECT TOP 1 POD.Userdefine01 FROM PO (NOLOCK)
                            JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.POkey = POD.POKey
                            WHERE PO.POKey IN(SELECT POKey FROM #PREPPL_PO)
                            AND POD.Userdefine01 = UCC.UccNo
                            AND POD.Storerkey = UCC.Storerkey
                            ) AS POUCC
               WHERE UCC.Status IN('0','1')
               AND UCC.UserDefined06 <> '1'
               AND UCC.Storerkey = @c_Storerkey
               AND UCC.Sku = @c_Sku
               AND POUCC.Userdefine01 IS NOT NULL
               GROUP BY UCC.UCCNo, POUCC.Userdefine01, UCC.Userdefined07
               ORDER BY --CASE WHEN POUCC.Userdefine01 IS NOT NULL THEN 1 ELSE 2 END,                         
                        2,
                        CASE WHEN UCC.Userdefined07 = '1' THEN 1 ELSE 2 END,
                        UCC.UCCNo
                        
             OPEN CUR_UCC
             
             FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty                        
                        
             WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) AND @n_NoofUCCStamp > 0 AND @n_NoofUCCQtyStamp > 0
             BEGIN
             	  IF @n_UCCQty > @n_NoofUCCQtyStamp
             	     BREAK
             	
      	        UPDATE UCC WITH (ROWLOCK)
      	        SET Userdefined06 = '1', 
      	            TrafficCop = NULL
      	        WHERE UCCNo = @c_UCCNo
      	        AND Storerkey = @c_Storerkey
      	        --AND Sku = @c_Sku
      	        
                SELECT @n_err = @@ERROR                                                                                                                                                        
                IF @n_err <> 0                                                                                                                                                                 
                BEGIN                                                                                                                                                                          
                   SELECT @n_continue = 3                                                                                                                                                      
                   SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 83020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.                                     
                   SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Table Failed. (ispPRPPLPO03)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '            
                END                                                                                                                                                                               	     
             	
                SET @n_NoofUCCStamp = @n_NoofUCCStamp -  1
                SET @n_NoofUCCQtyStamp = @n_NoofUCCQtyStamp - @n_UCCQty
                
                FETCH NEXT FROM CUR_UCC INTO @c_UCCNo, @n_UCCQty             	
             END
             CLOSE CUR_UCC
             DEALLOCATE CUR_UCC                                                               
          END
          
          FETCH NEXT FROM CUR_POSKU INTO @c_Storerkey, @c_Sku, @n_MaxUccNo, @n_MaxUccQty                                                                	       	       	     
      END	  
      CLOSE CUR_POSKU
      DEALLOCATE CUR_POSKU                          	   
   END
   --NJOW03 E
               
   IF  @n_continue IN(1,2)
   BEGIN   	                                                            
   	  SET @c_SendEmail ='N'
      SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)  
      SET @c_Subject = '[Adidas] Email alert found in PO that doesn''t have a Home Location - ' + @c_Date + ' PO: ' + RTRIM(@c_POKeys)  
      
      SET @c_Body = '<style type="text/css">       
               p.a1  {  font-family: Arial; font-size: 12px;  }      
               table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}      
               table, td, th {padding:3px; font-size: 12px; }
               td { vertical-align: top}
               </style>'
  
      SET @c_Body = @c_Body + '<b>Please setup home location for sku below.</b>'  
      SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'   
      SET @c_Body = @c_Body + '<tr bgcolor=silver><th>Storerkey</th><th>Sku</th></tr>'  
      
      DECLARE CUR_SKU CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PO.Storerkey, POD.Sku
         FROM PO (NOLOCK)
         JOIN #TMP_PODETAIL POD (NOLOCK) ON PO.POkey = POD.POKey
         LEFT JOIN SKUXLOC SL (NOLOCK) ON POD.Storerkey = SL.Storerkey AND POD.Sku = SL.Sku AND SL.LocationType IN('PICK','CASE')         
         WHERE PO.POKey IN(SELECT POKey FROM #PREPPL_PO)
         AND SL.Loc IS NULL
         ORDER BY PO.Storerkey, POD.Sku
        
      OPEN CUR_SKU              
        
      FETCH NEXT FROM CUR_SKU INTO @c_Storerkey, @c_Sku

      SELECT TOP 1 @c_Recipients = Notes
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'EMAILALERT'
      AND Storerkey = @c_Storerkey
      AND Code = 'ispPRPPLPO03'
      
      IF ISNULL(@c_Recipients,'') = ''
         SET @c_Recipients = 'KunakornNumduang@LFLogistics.com'
        
      WHILE @@FETCH_STATUS <> -1       
      BEGIN           
         SET @c_SendEmail = 'Y'
           
         SET @c_Body = @c_Body + '<tr><td>' + RTRIM(@c_Storerkey) + '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Sku) + '</td>'  
         SET @c_Body = @c_Body + '</tr>'  
                                            
         FETCH NEXT FROM CUR_SKU INTO @c_Storerkey, @c_Sku
      END  
      CLOSE CUR_SKU              
      DEALLOCATE CUR_SKU           
        
      SET @c_Body = @c_Body + '</table>'  
      
      IF @c_SendEmail = 'Y'
      BEGIN           
         EXEC msdb.dbo.sp_send_dbmail   
               @recipients      = @c_Recipients,  
               @copy_recipients = NULL,  
               @subject         = @c_Subject,  
               @body            = @c_Body,  
               @body_format     = 'HTML' ;  
                 
         SET @n_Err = @@ERROR  
         
         IF @n_Err <> 0  
         BEGIN           
            SELECT @n_continue = 3
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 83010
   	        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Executing sp_send_dbmail alert Failed! (ispPRPPLPO03)' + ' ( '
                           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
         END  
      END         	
   END                  
  
QUIT_SP:
  
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRPPLPO03'
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO