SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_ReceiptSummary12                                        */
/* Creation Date: 01-Aug-2017                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose:WMS- WMS-2412-[TW-LCT] Return Summary Report                 */
/*          :                                                           */
/* Called By: r_dw_receipt_summary12                                    */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 2-2-2018     LZG       1.0  Added LocationFlag = 'NONE' (ZG01)       */ 
/************************************************************************/
CREATE PROC [dbo].[isp_ReceiptSummary12]
            @c_ReceiptKey  NVARCHAR(10)
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @c_reckey          NVARCHAR(20)
         , @c_extrecetkey     NVARCHAR(20)
         , @c_sku             NVARCHAR(20)
         , @c_sloc            NVARCHAR(20)
         , @c_loc             NVARCHAR(20)
         , @n_qty             NVARCHAR(20)
         , @c_HOSTWHCODE      NVARCHAR(20)
         , @c_RLHOSTWHCODE    NVARCHAR(20)
         , @n_Cntsloc         INT
         , @n_sqty            INT
         , @c_Getloc          NVARCHAR(20)
         , @c_Facility        NVARCHAR(5)


   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1

	 CREATE TABLE #TMP_RECSUMM12
   (  ExtRecKey           NVARCHAR(20)  NULL
   ,  Carrierkey          NVARCHAR(15)  NULL
   ,  Receiptkey          NVARCHAR(20)  NULL
   ,  CarrierName         NVARCHAR(30)  NULL
   ,  PlaceOfLoading      NVARCHAR(18)  NULL
   ,  Storerkey           NVARCHAR(20)  NULL
   ,  SKU                 NVARCHAR(20)  NULL  
   ,  Descr               NVARCHAR(120)  NULL
   ,  QtyExpected         INT  NULL
   ,  QtyReceived         INT  NULL
   ,  SLoc                NVARCHAR(20)  NULL
   ,  RecAddDate          DATETIME 
   ,  RecNotes            NVARCHAR(120)  NULL 
   )
   
    CREATE TABLE #TMP_RECLOC12
   (  Storerkey           NVARCHAR(20)  NULL 
   ,  Receiptkey          NVARCHAR(20)  NULL  
   ,  ExtRecKey           NVARCHAR(20)  NULL
   ,  Qty                 INT  NULL
   ,  SKU                 NVARCHAR(20)  NULL  
   ,  Loc                 NVARCHAR(20)  NULL
   ,  Match               INT  NULL
   )
   
   
   INSERT INTO #TMP_RECLOC12 (Storerkey, Receiptkey, ExtRecKey, Qty, SKU, Loc,
               Match)
  SELECT Rec.storerkey,Rec.ReceiptKey,Rec.ExternReceiptKey,lli.Qty,rd.sku,rd.toloc,
  --CASE WHEN l.Lottable01 = rd.Lottable01 AND rd.Lottable01 = l.HOSTWHCODE THEN 1 ELSE 0 END AS 'match'
  CASE WHEN rd.toloc = l.HOSTWHCODE THEN 1 ELSE 0 END AS 'match'
  FROM RECEIPT REC (NOLOCK) 
  JOIN RECEIPTDETAIL AS RD WITH (NOLOCK) ON RD.ReceiptKey=REC.ReceiptKey 
  JOIN lotxlocxid lli (NOLOCK) on lli.sku=RD.sku AND lli.storerkey = RD.StorerKey
  JOIN loc l WITH (NOLOCK) ON l.loc=lli.loc
  LEFT JOIN LOTATTRIBUTE AS lott WITH (NOLOCK) ON lott.lot=lli.lot 
  WHERE REC.ReceiptKey = @c_ReceiptKey
  AND l.LocationFlag='NONE'
  GROUP BY  Rec.storerkey,Rec.ReceiptKey,Rec.ExternReceiptKey,lli.Qty,rd.sku,rd.toloc
  ,CASE WHEN rd.toloc = l.HOSTWHCODE THEN 1 ELSE 0 END
  ORDER BY rd.sku,lli.Qty ,rd.toloc         
  
   INSERT INTO #TMP_RECSUMM12 (ExtRecKey, Carrierkey, Receiptkey, CarrierName,
               PlaceOfLoading, Storerkey, SKU, Descr, QtyExpected, QtyReceived,
               SLoc,RecAddDate,RecNotes)
   SELECT ExtRecKey         = RECEIPT.Externreceiptkey
         ,Carrierkey        = ISNULL(RTRIM(RECEIPT.Carrierkey),'')
         --,Brand             = #TMP_BRAND.Brand 
         ,RECEIPT.Receiptkey
         ,CarrierName       = ISNULL(RTRIM(RECEIPT.CarrierName),'')
         ,PlaceOfLoading      = ISNULL(RTRIM(RECEIPT.PlaceOfLoading),'')
         ,RECEIPTDETAIL.Storerkey          
         ,RECEIPTDETAIL.Sku
         ,Descr        = ISNULL(RTRIM(SKU.Descr),'')
         ,QtyExpected  = ISNULL(SUM(RECEIPTDETAIL.QtyExpected),0)
         ,QtyReceived  = (ISNULL(SUM(RECEIPTDETAIL.QtyReceived),0) + ISNULL(SUM(RECEIPTDETAIL.BeforeReceivedQty),0))  --(CS01)
         ,Loc       = ''
         , RecAddDate = RECEIPT.AddDate
         , RecNotes = ISNULL(RECEIPT.notes,'')
   FROM RECEIPT WITH (NOLOCK)
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON (RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey)
   JOIN STORER        WITH (NOLOCK) ON (RECEIPT.Storerkey = STORER.Storerkey)
   JOIN SKU           WITH (NOLOCK) ON (RECEIPTDETAIL.Storerkey = SKU.Storerkey)
                                    AND(RECEIPTDETAIL.Sku = SKU.Sku)
   --JOIN #TMP_BRAND                  ON (ISNULL(RTRIM(RECEIPTDETAIL.ExternPOKey),'') = #TMP_BRAND.ExternPOKey )
   WHERE RECEIPT.ReceiptKey = @c_ReceiptKey
   GROUP BY RECEIPT.Externreceiptkey
         ,  ISNULL(RTRIM(RECEIPT.Carrierkey),'')
         ,  RECEIPT.Receiptkey
         ,  ISNULL(RTRIM(RECEIPT.CarrierName),'')
         ,  ISNULL(RTRIM(RECEIPT.PlaceOfLoading),'')
         ,  RECEIPT.AddDate
         ,  RECEIPTDETAIL.Storerkey
         ,  RECEIPTDETAIL.Sku
         ,  ISNULL(RTRIM(SKU.Descr),'')
         ,  ISNULL(RECEIPT.notes,'')
        
   
   DECLARE CUR_RESULT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT receiptkey  ,ExtRecKey,SKU 
   FROM   #TMP_RECSUMM12   
   WHERE receiptkey =  @c_ReceiptKey
  
   OPEN CUR_RESULT   
     
   FETCH NEXT FROM CUR_RESULT INTO @c_reckey,@c_extrecetkey,@c_sku    
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN 
   	
   	
   	SET @c_loc = ''
   	SET @c_sloc = ''
   	SET @c_HOSTWHCODE = ''
   	SET @n_cntsloc = 0
   	SET @n_sqty = 0
   	SET @c_Getloc = ''
   	SET @c_RLHOSTWHCODE = ''
   	SET @c_Facility = ''
   	
   	SELECT @c_loc = TRL12.Loc
   	FROM #TMP_RECLOC12 TRL12
   	WHERE TRL12.Receiptkey = @c_reckey
   	AND TRL12.ExtRecKey = @c_extrecetkey
   	AND TRL12.SKU = @c_sku
   	--AND TRL12.Match=1
   	
   	SELECT @c_Facility = Facility
   	FROM RECEIPT WITH (NOLOCK)
   	WHERE receiptkey = @c_reckey
   
   	
   	SELECT @c_RLHOSTWHCODE = HOSTWHCODE
   	FROM LOC WITH (NOLOCK)
   	WHERE loc=@c_loc
   	
   	SELECT @n_cntsloc = COUNT(1)
   	FROM SKUXloc WITH (NOLOCK)
   	WHERE sku=@c_sku
   	
   	IF @n_cntsloc = 1
   	BEGIN
   	
   		SELECT @c_Getloc = lli.LOC
   		FROM SKUXloc lli WITH (NOLOCK)
   		WHERE sku=@c_sku
   	
   		SELECT @c_HOSTWHCODE = HOSTWHCODE
   		FROM LOC WITH (NOLOCK)
   		WHERE loc=@c_Getloc
   		
   	END
   	ELSE 
   	BEGIN	
   		SELECT TOP 1 @c_Getloc = lli.LOC
                     ,@n_sqty  = lli.Qty
         FROM skuxloc lli WITH (NOLOCK)
         WHERE sku=@c_sku
         and loc in (select loc
                       from loc
                       where facility=@c_Facility
                       AND LocationFlag = 'NONE'               -- ZG01
                       and hostwhcode=@c_RLHOSTWHCODE)
         ORDER BY lli.Qty

   		
   		SELECT @c_HOSTWHCODE = HOSTWHCODE
   		FROM LOC WITH (NOLOCK)
   		WHERE loc=@c_Getloc
   		
   	END	
   	
   	/*IF @@ROWCOUNT = 1
   	BEGIN
   		SET @c_sloc = @c_loc
   	END
   	ELSE IF @@ROWCOUNT > 1
   	BEGIN
   		
   		SELECT TOP 1 @c_loc = TRL12.Loc
   	   FROM #TMP_RECLOC12 TRL12
   	   WHERE TRL12.Receiptkey = @c_reckey
   	   AND TRL12.ExtRecKey = @c_extrecetkey
   	   AND TRL12.SKU = @c_sku
   	   --AND TRL12.Match=1
   		ORDER BY TRL12.Qty, TRL12.Loc
   		
   	END*/
   	IF @c_RLHOSTWHCODE = @c_HOSTWHCODE
   	BEGIN
   		SET @c_sloc = @c_Getloc
   	END
   	ELSE
   	BEGIN
   		SET @c_sloc = ''
   	END	
   
   
   UPDATE #TMP_RECSUMM12
   SET	SLoc = @c_sloc
   WHERE receiptkey = @c_reckey
   AND ExtRecKey = @c_extrecetkey
   AND SKU = @c_sku
  
   FETCH NEXT FROM CUR_RESULT INTO  @c_reckey,@c_extrecetkey,@c_sku  
   END
   
   CLOSE CUR_RESULT
   DEALLOCATE CUR_RESULT
   
   
   SELECT * FROM #TMP_RECSUMM12
   ORDER BY Receiptkey, SKU, SLoc
   
   DROP TABLE #TMP_RECSUMM12
   DROP TABLE #TMP_RECLOC12
      
QUIT_SP:
END -- procedure

GO