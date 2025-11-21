SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RecvCheckList01_rpt                             */
/* Creation Date: 2018-03-26                                             */
/* Copyright: IDS                                                        */
/* Written by:                                                           */
/*                                                                       */
/* Purpose: WMS-4270 - KR - Receiving Checking Lists Report              */
/*                                                                       */
/* Called By: r_receipt_checklist01_rpt                                  */
/*                                                                       */
/* PVCS Version: 1.1                                                     */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date         Author  Ver   Purposes                                   */
/* 13-JUL-2018  CSCHONG 1.1   WMS-5453 - revised sorting logic (CS01)    */
/*************************************************************************/
CREATE PROC [dbo].[isp_RecvCheckList01_rpt]
         (  @c_storerkey           NVARCHAR(20),
            @c_receiptkey_start    NVARCHAR(10),
            @c_receiptkey_end      NVARCHAR(10)         
         )
                 
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   DECLARE @n_NoOfLine  INT
          ,@c_getUDF01  NVARCHAR(30)
          ,@c_PrvUDF01  NVARCHAR(30)
          ,@n_CtnUDF01  INT
          ,@n_ctnsct    INT
          ,@n_Ctnsmct   INT
   
   
   SET @n_CtnUDF01 = 1
   SET @c_PrvUDF01 = ''
   
   CREATE TABLE #TEMPRCVCHK01LIST (
   Storerkey     NVARCHAR(20),
   RecLineNo     NVARCHAR(5),
   RDUDF03       NVARCHAR(30),
   SSM           NVARCHAR(5),
   SKU           NVARCHAR(20),
   SDESCR        NVARCHAR(200),
   qtyexp        INT,
   reckey        NVARCHAR(20),  
   signatory     NVARCHAR(20),  
   CNTSCTN       INT,
   CNTSMCTN      INT,
   SQty          INT,
   SMQty         INT,
   RecWHSREF     NVARCHAR(18),
   RDUDF01       NVARCHAR(30),
   OrderNo       NVARCHAR(10)
   )
   
     CREATE TABLE #TEMPCHKUNQ (
       
       RDUDF01       NVARCHAR(30),
       SKU           NVARCHAR(20),
     	 Storerkey     NVARCHAR(20),
     	 reckey        NVARCHAR(20),
       RecLineNo     NVARCHAR(5),
      )
   
  -- SET @n_NoOfLine = 40
  
 DECLARE  @c_Reckey          NVARCHAR(20),
		  @c_reclineno         NVARCHAR(20),
		  @c_getstorerkey      NVARCHAR(20),
		  @n_CntCnts           INT,
		  @n_cntcntsm          INT,
		  @n_sqty              INT,
		  @n_Smqty             INT,
		  @c_SSM               NVARCHAR(10),
		  @n_qtyExp            INT
   
   IF ISNULL(@c_storerkey,'') = ''
   BEGIN 
		SELECT TOP 1 @c_storerkey = REC.Storerkey
		FROM RECEIPT REC (NOLOCK)
		WHERE Receiptkey = @c_receiptkey_start
   END  
   
   
   INSERT INTO #TEMPRCVCHK01LIST
   (  Storerkey,
   	RecLineNo,
		RDUDF03,
		SSM,
		SKU,
		SDESCR,
		qtyexp,
		reckey,  
		signatory,  
		CNTSCTN,
		CNTSMCTN,
		SQty,
		SMQty,
		RecWHSREF,
		RDUDF01,
		OrderNo
   )
   
    SELECT REC.storerkey,rd.ReceiptLineNumber,rd.userdefine03,'',
         rd.sku,s.descr,rd.QtyExpected,REC.receiptkey,ISNULL(REC.Signatory,''),
         0,0,0,0,ISNULL(rec.WarehouseReference,''),rd.userdefine01
       ,SUBSTRING(rd.lottable02,7,6) AS orderno
	FROM RECEIPT REC WITH (NOLOCK)
	JOIN RECEIPTDETAIL RD WITH (NOLOCK) ON RD.receiptkey = REC.receiptkey
	JOIN sku s WITH (NOLOCK) ON s.StorerKey=rd.StorerKey AND s.sku=rd.Sku
	WHERE REC.StorerKey = @c_storerkey
	AND rec.receiptkey BETWEEN @c_receiptkey_start AND @c_receiptkey_end
	AND RD.POKey <> ''
          
    SET @n_ctnsct = 0
	 SET @n_cntcntsm = 0      
          
    DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT t.storerkey,t.reckey,t.RecLineNo   
   FROM #TEMPRCVCHK01LIST AS t
   WHERE t.reckey BETWEEN @c_receiptkey_start AND @c_receiptkey_end
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_getstorerkey,@c_Reckey,@c_reclineno    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN        
   	
   	SET @c_SSM = '' 
   	SET @n_qtyExp = 0 
		
		--SELECT * FROM #TEMPCHKUNQ
		SET @c_getUDF01 = ''
		
		SELECT @c_getUDF01 = userdefine01
		FROM RECEIPTDETAIL (NOLOCK)
		 WHERE STORERKEY = @c_getstorerkey
       and receiptkey = @c_Reckey
       AND ReceiptLineNumber = @c_reclineno
		
		
		 SELECT @n_CtnUDF01 = COUNT(1) from  receiptdetail
		 WHERE STORERKEY = @c_getstorerkey
		 and receiptkey = @c_Reckey
		 AND userdefine01=@c_getUDF01
		 GROUP BY userdefine01 
		
		
		SET @c_ssm = ''
	 
	 
		
		--IF EXISTS (SELECT 1 FROM #TEMPCHKUNQ WHERE storerkey = @c_getstorerkey AND reckey=@c_Reckey AND RecLineNo=@c_reclineno)	 
		IF @n_CtnUDF01 = 1 --AND @n_ctnsmct > 1
		BEGIN 
			SET @c_ssm = 'S'
			IF @c_PrvUDF01 <> @c_getUDF01
			BEGIN
			  SET @n_ctnsct = @n_ctnsct + 1
			END  
		END			 
		ELSE
		BEGIN
			SET @c_ssm = 'SM'
			IF @c_PrvUDF01 <> @c_getUDF01
			BEGIN
			  SET @n_cntcntsm = @n_cntcntsm + 1
			END 
		END	
  
  
    SELECT @n_qtyExp = Qtyexpected
    FROM RECEIPTDETAIL WITH (NOLOCK)
    WHERE receiptkey = @c_Reckey
    AND ReceiptLineNumber = @c_reclineno

   UPDATE #TEMPRCVCHK01LIST
   SET
   	SSM = @c_SSM
   	,SQty = CASE WHEN @c_SSM = 'S' THEN @n_qtyExp ELSE 0 END
   	,SMQty = CASE WHEN @c_SSM = 'SM' THEN @n_qtyExp ELSE 0 END
   WHERE reckey = @c_Reckey	
   AND RecLineNo = @c_reclineno
   AND storerkey = @c_getstorerkey 	
   
   SET @c_PrvUDF01 = @c_getUDF01
   
   FETCH NEXT FROM CUR_RESULT INTO  @c_getstorerkey,@c_Reckey,@c_reclineno    
   END   
   
 --  select * FROM #TEMPRCVCHK01LIST
  
   SET @n_sqty = 1
   SET @n_Smqty = 1
   
   
   UPDATE #TEMPRCVCHK01LIST
   SET
   	CNTSCTN = CASE WHEN ssm='S' THEN ISNULL(@n_ctnsct,0) ELSE 0 END,
   	CNTSMCTN = CASE WHEN ssm='SM' THEN ISNULL(@n_cntcntsm,0) ELSE 0 END
  -- 	SQty = CASE WHEN ssm='S' THEN ISNULL(@n_sqty,0) ELSE 0 END,
   --	SMQty = CASE WHEN ssm='SM' THEN  ISNULL(@n_smqty,0) ELSE 0 END
   WHERE reckey = @c_Reckey	
   AND storerkey =@c_storerkey
   
   SELECT  Storerkey,
   	RecLineNo,
		RDUDF03,
		SSM,
		(SUBSTRING (Sku, 1, 7 ) + '-' + SUBSTRING ( Sku, 8, 3 )  + '-' +SUBSTRING (Sku, 11, 3 ))as SKU,
		SDESCR,
		qtyexp,
		reckey,  
		signatory,  
		CNTSCTN,
		CNTSMCTN,
		SQty,
		SMQty,
		RecWHSREF,
		RDUDF01,
		OrderNo
   FROM #TEMPRCVCHK01LIST AS t
   ORDER BY orderno,(SUBSTRING (Sku, 1, 7 ) + '-' + SUBSTRING ( Sku, 8, 3 )  + '-' +SUBSTRING (Sku, 11, 3 ))--t.recLineNo  --CS01
   
    QUIT_SP:
    
END


GO