SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ULM_TransferExpiry                                */
/* Creation Date: 03-Mar-2021                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-16423 - MYS ULM Auto Transfer Near Expiry                  */
/*                                                                         */
/* Called By: SQL Job                                                      */
/*                                                                         */
/* GitLab Version: 2.2                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 3/8/2021     ian     1.0   bug fixed fromloc                            */   
/* 20/9/2021    ian     2.0   bug fixed fromid                             */   
/* 28-Dec-2021  WLChooi 2.1   DevOps Combine Script                        */
/* 28-Dec-2021  WLChooi 2.1   WMS-18614 & WMS-18615 - Add new column (WL01)*/
/* 28-Jul-2022  WLChooi 2.2   WMS-20350 - Hold FromLoc after transfer(WL02)*/
/***************************************************************************/  
CREATE PROC [dbo].[isp_ULM_TransferExpiry]    
(
   @c_Facility      NVARCHAR(255)  = '',
   @c_StockStatus   NVARCHAR(20)   = 'EXPIRED',
   @c_Recipients    NVARCHAR(2000) = 'LFLMYInventory@lflogistics.com' --email address delimited by ;
)
AS  
BEGIN  	
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Success            INT,
           @n_Err                INT,
           @c_ErrMsg             NVARCHAR(255),
           @n_Continue           INT,
           @n_StartTranCount     INT
   
   DECLARE @c_Storerkey          NVARCHAR(15),
           @c_SkuGroup           NVARCHAR(10),
           @c_CopyLottable       NVARCHAR(1), 
           @c_Finalize           NVARCHAR(1),
           @c_Type               NVARCHAR(12),
           @c_ReasonCode         NVARCHAR(10),
           @c_CustomerRefNo      NVARCHAR(20),
           @c_Transferkey        NVARCHAR(10),
           @c_Lot                NVARCHAR(10)

   DECLARE @c_Body         NVARCHAR(MAX),          
           @c_Subject      NVARCHAR(255),          
           @c_Date         NVARCHAR(20),           
           @c_SendEmail    NVARCHAR(1)
   
   DECLARE @c_TransferLineNumber NVARCHAR(5),
           @c_FromStorerkey      NVARCHAR(15),
           @c_FromSku            NVARCHAR(20),
           @c_FromDescr          NVARCHAR(60),
           @c_FromLot            NVARCHAR(10),
           @c_FromLoc            NVARCHAR(10),
           @c_FromID             NVARCHAR(18),
           @n_FromQty            INT,               
           @c_ToStorerkey        NVARCHAR(15),
           @c_ToSku              NVARCHAR(20),
           @c_ToDescr            NVARCHAR(60),
           @c_ToLot              NVARCHAR(10),
           @c_ToLoc              NVARCHAR(10),
           @c_ToID               NVARCHAR(18),
           @n_ToQty              INT, 
           @c_Lottable01         NVARCHAR(18),
           @c_Lottable02         NVARCHAR(18),
           @c_Lottable03         NVARCHAR(18),
           @dt_Lottable04        DATETIME,
           @dt_Lottable05        DATETIME,
           @c_ToLottable01       NVARCHAR(18),
           @c_ToLottable02       NVARCHAR(18),
           @c_ToLottable03       NVARCHAR(18),
           @dt_ToLottable04      DATETIME, 
           @dt_ToLottable05      DATETIME,
           @c_GetFacility        NVARCHAR(5) = '',
           @c_PrevFacility       NVARCHAR(5) = '',
           @n_FromQtyInCase      DECIMAL(20,2),   --WL01
           @c_FromQtyInCase      NVARCHAR(20)     --WL01
    
   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT
   
   SET @c_Storerkey = 'UNILEVER'
   SET @c_Type = 'ULM-SLT'
   SET @c_ReasonCode = 'U311'
   SET @c_CustomerRefNo = RTRIM(CONVERT(NVARCHAR(8),GETDATE(),112)) + LEFT(REPLACE(LTRIM(RTRIM(CONVERT(NVARCHAR(8),GETDATE(),108))),':',''), 4)
   SET @c_CopyLottable = 'Y'
   SET @c_Finalize = 'N'
   SET @c_Transferkey = ''
         
   CREATE TABLE #TMP_Facility (
      Facility   NVARCHAR(5) NULL
   )

   CREATE TABLE #TMP_Transfer (
      TransferKey   NVARCHAR(10) NULL
   )

   INSERT INTO #TMP_Facility (Facility)
   SELECT DISTINCT ColValue 
   FROM dbo.fnc_delimsplit (',',@c_Facility)

   IF NOT EXISTS (SELECT 1 FROM #TMP_Facility)
   BEGIN
      INSERT INTO #TMP_Facility (Facility)
      SELECT ''   --ALL Facility
   END

   BEGIN TRAN
   	   	
   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Facility
      FROM #TMP_Facility

   OPEN CUR_LOOP

   FETCH NEXT FROM CUR_LOOP INTO @c_GetFacility

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN (1,2)
   BEGIN
      --Create transfer for expired inventory
      IF @n_continue IN(1,2)
      BEGIN
         IF OBJECT_ID('tempdb..#TMP_EXPLOT') IS NOT NULL
            DROP TABLE #TMP_EXPLOT

         SELECT LLI.Lot,         
                CASE WHEN LOC.HostWhCode IN ('M001') AND DATEDIFF(dd, GETDATE(), LA.Lottable04) <= (CASE WHEN ISNUMERIC(SKU.Susr4) = 1 THEN CAST(SKU.Susr4 AS INT) ELSE 0 END) + 2 THEN  
                     'EXPIRING'
                     WHEN LOC.HostWhCode IN ('M005') AND DATEDIFF(dd, GETDATE(), LA.Lottable04) <= 0 THEN
                     'EXPIRED' 
                END AS StockStatus,
                CASE WHEN @c_StockStatus = 'EXPIRING'  THEN CASE WHEN LOC.Facility = 'BR' THEN 'BRNEP' WHEN LOC.Facility = 'BRL' THEN 'BRLNEP' ELSE '' END
                     WHEN @c_StockStatus = 'EXPIRED'   THEN CASE WHEN LOC.Facility = 'BR' THEN 'BREXP' WHEN LOC.Facility = 'BRL' THEN 'BRLEXP' ELSE '' END 
                     ELSE '' END AS ToLoc,  
                loc.loc as fromloc, --ian  1.0
                lli.id as fromid, --ian  2.0  
                LOC.Facility
         INTO #TMP_EXPLOT
         FROM LOTXLOCXID LLI (NOLOCK)
         JOIN SKU (NOLOCK)ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku      
         JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
         JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
         JOIN SKUxLOC SL (NOLOCK) ON SL.LOC = LLI.LOC AND SL.StorerKey = LLI.StorerKey AND SL.SKU = LLI.SKU
         WHERE LLI.Storerkey = @c_Storerkey
         AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
         AND LA.Lottable03 IN ('UR')
         AND LOC.HOSTWHCODE IN ('M001','M005')
         AND (LOC.Facility = @c_GetFacility OR ISNULL(@c_GetFacility,'') = '')      
         GROUP BY LLI.Lot,
                  CASE WHEN LOC.HostWhCode IN ('M001') AND DATEDIFF(dd, GETDATE(), LA.Lottable04) <= (CASE WHEN ISNUMERIC(SKU.Susr4) = 1 THEN CAST(SKU.Susr4 AS INT) ELSE 0 END) + 2 THEN  
                       'EXPIRING'
                       WHEN LOC.HostWhCode IN ('M005') AND DATEDIFF(dd, GETDATE(), LA.Lottable04) <= 0 THEN
                       'EXPIRED' 
                   END,
                   CASE WHEN @c_StockStatus = 'EXPIRING'  THEN CASE WHEN LOC.Facility = 'BR' THEN 'BRNEP' WHEN LOC.Facility = 'BRL' THEN 'BRLNEP' ELSE '' END
                        WHEN @c_StockStatus = 'EXPIRED'   THEN CASE WHEN LOC.Facility = 'BR' THEN 'BREXP' WHEN LOC.Facility = 'BRL' THEN 'BRLEXP' ELSE '' END 
                        ELSE '' END,
                   loc.loc, --ian  1.0
                   lli.id,
                   LOC.Facility

         DECLARE CUR_EXPLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT Lot, StockStatus, ToLoc, fromloc, Facility , fromid --ian  1.0  --ian  2.0   
            FROM #TMP_EXPLOT      
            WHERE ISNULL(StockStatus,'') = @c_StockStatus      
            ORDER BY Facility,StockStatus, Lot, ToLoc , fromid, fromloc   --ian  1.0  --ian  2.0
            
         OPEN CUR_EXPLOT  
         
         FETCH NEXT FROM CUR_EXPLOT INTO @c_Lot, @c_StockStatus, @c_ToLoc,@c_FromLoc, @c_Facility , @c_FromID --ian  1.0 --ian  2.0   
         
         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
         BEGIN        	      	      	
            SET @b_Success = 0
            
            IF ISNULL(@c_PrevFacility,'') = ''
               SET @c_PrevFacility = @c_Facility

            IF @c_PrevFacility <> @c_Facility
               SET @c_Transferkey = ''

            EXEC ispCreateTransfer
                @c_Transferkey   = @c_Transferkey    OUTPUT,
                @c_FromFacility  = @c_Facility,
                @c_FromLot       = @c_Lot,
                @c_ToLoc         = @c_ToLoc,
                @c_FromLoc       = @c_FromLoc,      --ian  1.0
                @c_FromID        = @c_FromID,        --ian  2.0
                @c_CopyLottable  = @c_CopyLottable,
                @c_Finalize      = @c_Finalize,
                @c_Type          = @c_Type,
                @c_ReasonCode    = @c_ReasonCode,
                @c_CustomerRefNo = @c_CustomerRefNo,      	    
                @b_Success       = @b_Success        OUTPUT,
                @n_Err           = @n_Err            OUTPUT,
                @c_ErrMsg        = @c_ErrMsg         OUTPUT
      
            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (isp_ULM_TransferExpiry)'
            END

            INSERT INTO #TMP_Transfer (Transferkey)
            SELECT @c_Transferkey

            SET @c_PrevFacility = @c_Facility
                  	          	          	
            FETCH NEXT FROM CUR_EXPLOT INTO @c_Lot, @c_StockStatus, @c_ToLoc,@c_FromLoc, @c_Facility , @c_FromID --ian  1.0  --ian  2.0  
         END
         CLOSE CUR_EXPLOT
         DEALLOCATE CUR_EXPLOT       
      END

      DECLARE CUR_TRANSFERKEY CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT TransferKey
         FROM #TMP_Transfer
      
      OPEN CUR_TRANSFERKEY  
   
      FETCH NEXT FROM CUR_TRANSFERKEY INTO @c_Transferkey
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN   
         ----finalize transfer
         IF ISNULL(@c_Transferkey,'') <> '' AND @n_continue IN(1,2)
         BEGIN
            EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
            
            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63200
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ULM_TransferExpiry)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END
         END   
         
         --Send alert by email
         IF ISNULL(@c_Transferkey,'') <> '' AND @n_continue IN(1,2)
         BEGIN   	                                                            
            SET @c_SendEmail ='N'
            SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)  
         
            SELECT @c_Facility = Facility
            FROM TRANSFER (NOLOCK)
            WHERE TransferKey = @c_Transferkey
         
            IF @c_StockStatus = 'EXPIRED'
            BEGIN
               SET @c_Subject = 'UNILEVER Inventory Expired Alert for ' 
                              + CASE WHEN @c_Facility = 'BR' THEN 'BREXP' WHEN @c_Facility = 'BRL' THEN 'BRLEXP' ELSE '' END 
                              + ' - ' + @c_Date 
            END 
            ELSE IF @c_StockStatus = 'EXPIRING'
            BEGIN 
               SET @c_Subject = 'UNILEVER Inventory Near Expiry Alert for '
                              + CASE WHEN @c_Facility = 'BR' THEN 'BRNEP' WHEN @c_Facility = 'BRL' THEN 'BRLNEP' ELSE '' END 
                              + ' - ' + @c_Date  
            END
         
            --SET @c_Subject = 'UNILEVER Inventory Expired Alert - ' + @c_Date  
            
            SET @c_Body = '<style type="text/css">       
                     p.a1  {  font-family: Arial; font-size: 12px;  }      
                     table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}      
                     table, td, th {padding:3px; font-size: 12px; }
                     td { vertical-align: top}
                     </style>'
         
            SET @c_Body = @c_Body + '<p>Dear All, </p>'  
            
            IF @c_StockStatus = 'EXPIRED'
               SET @c_Body = @c_Body + '<p>Please be informed of Transfer Expired Stocks.</p>'  
            ELSE IF @c_StockStatus = 'EXPIRING'
               SET @c_Body = @c_Body + '<p>Please be informed of Transfer Near Expiry Stocks.</p>'  
               
            SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'   
            SET @c_Body = @c_Body + '<tr bgcolor=silver><th>Transferkey</th><th>TransferLineNumber</th><th>FromStorerkey</th><th>FromSku</th><th>FromDescr</th><th>FromLoc</th>'  
            --SET @c_Body = @c_Body + '<th>FromLot</th><th>FromId</th><th>FromQty</th><th>FromLottable01</th><th>FromLottable02</th><th>FromLottable03</th><th>FromLottable04</th>'   --WL01  
            SET @c_Body = @c_Body + '<th>FromLot</th><th>FromId</th><th>FromQty (PC)</th><th>FromQty (CS)</th><th>FromLottable01</th><th>FromLottable02</th><th>FromLottable04</th>'   --WL01 
            SET @c_Body = @c_Body + '<th>FromLottable05</th><th>ToLoc</th></tr>'
            
            DECLARE CUR_TRANSFER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
               SELECT TRD.Transferkey, TRD.TransferLineNumber, TRD.FromStorerkey, TRD.FromSku, SKU.Descr, TRD.FromLoc, TRD.FromLot, TRD.FromID, TRD.FromQty,
                      --TRD.Lottable01, TRD.Lottable02, TRD.Lottable03, TRD.Lottable04, TRD.Lottable05, TRD.ToStorerkey, TRD.ToSku, SKU.Descr, TRD.ToLoc, TRD.ToLot,   --WL01
                      CASE WHEN ISNULL(PACK.Casecnt,0) = 0 THEN 0 ELSE CAST((TRD.FromQty / PACK.Casecnt) AS DECIMAL(20,2)) END AS FromQtyInCase,   --WL01
                      TRD.Lottable01, TRD.Lottable02, '', TRD.Lottable04, TRD.Lottable05, TRD.ToStorerkey, TRD.ToSku, SKU.Descr, TRD.ToLoc, TRD.ToLot,   --WL01
                      TRD.ToID, TRD.ToQty, TRD.ToLottable01, TRD.ToLottable02, TRD.ToLottable03, TRD.ToLottable04, TRD.ToLottable05          
               FROM TRANSFER TR (NOLOCK)
               JOIN TRANSFERDETAIL TRD (NOLOCK) ON TR.Transferkey = TRD.Transferkey        
               JOIN SKU (NOLOCK) ON TRD.FromStorerkey = SKU.Storerkey AND TRD.FromSku = SKU.Sku
               JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey   --WL01
               WHERE TR.Transferkey = @c_Transferkey
               ORDER BY TRD.TransferLineNumber
              
            OPEN CUR_TRANSFER              
              
            FETCH NEXT FROM CUR_TRANSFER INTO @c_Transferkey, @c_TransferLineNumber, @c_FromStorerkey, @c_FromSku, @c_FromDescr, @c_FromLoc, @c_FromLot, @c_FromID, @n_FromQty,
                                              @n_FromQtyInCase,   --WL01
                                              @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_ToStorerkey, @c_ToSku, @c_ToDescr, @c_ToLoc,  
                                              @c_ToLot, @c_ToID, @n_ToQty, @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @dt_ToLottable04, @dt_ToLottable05
              
            WHILE @@FETCH_STATUS <> -1       
            BEGIN  
               --WL01 S
               IF @n_FromQtyInCase % 1 = 0
                  SET @c_FromQtyInCase = CAST(@n_FromQtyInCase AS INT)
               ELSE
                  SET @c_FromQtyInCase = @n_FromQtyInCase
               --WL01 E

               SET @c_SendEmail = 'Y'
                 
               SET @c_Body = @c_Body + '<tr><td>' + RTRIM(@c_Transferkey) + '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_TransferLineNumber) + '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromStorerkey) + '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromSku)+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromDescr)+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromLoc)+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromLot)+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromID)+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(CAST(@n_FromQty AS NVARCHAR))+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromQtyInCase)+ '</td>'   --WL01 
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable01)+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable02)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable03)+ '</td>'   --WL01  
               SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_Lottable04, 103))+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_Lottable05, 103))+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToStorerkey)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToSku)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToDescr)+ '</td>'  
               SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLoc)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLot)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToID)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(CAST(@n_ToQty AS NVARCHAR))+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLottable01)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLottable02)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLottable03)+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_ToLottable04, 103))+ '</td>'  
               --SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_ToLottable05, 103))+ '</td>'  
               SET @c_Body = @c_Body + '</tr>'  

               --WL02 S
               IF EXISTS (SELECT 1
                          FROM LOC (NOLOCK)
                          WHERE LOC = @c_FromLoc
                          AND LocationType = 'OTHER' 
                          AND LocationFlag <> 'HOLD')
               BEGIN
                  IF EXISTS (SELECT 1
                             FROM LOTxLOCxID LLI (NOLOCK)
                             WHERE LOC = @c_FromLoc
                             HAVING SUM(LLI.QTY - LLI.QTYALLOCATED - LLI.QTYPICKED - LLI.QtyReplen) = 0)
                  BEGIN 
                     UPDATE dbo.LOC
                     SET LocationFlag = 'HOLD'
                     WHERE Loc = @c_FromLoc

                     SET @n_Err = @@ERROR 
                     
                     IF @n_Err <> 0  
                     BEGIN           
                        SELECT @n_continue = 3
                        SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63209
                        SELECT @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Hold ' + TRIM(@c_FromLoc) + ' Failed for Transfer# ' + RTRIM(@c_Transferkey) + ' (isp_ULM_TransferExpiry)' + ' ( '
                                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                     END
                  END
               END
               --WL02 E
                                                  
               FETCH NEXT FROM CUR_TRANSFER INTO @c_Transferkey, @c_TransferLineNumber, @c_FromStorerkey, @c_FromSku, @c_FromDescr, @c_FromLoc, @c_FromLot, @c_FromID, @n_FromQty,
                                                 @n_FromQtyInCase,   --WL01
                                                 @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_ToStorerkey, @c_ToSku, @c_ToDescr, @c_ToLoc,  
                                                 @c_ToLot, @c_ToID, @n_ToQty, @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @dt_ToLottable04, @dt_ToLottable05           
            END  
            CLOSE CUR_TRANSFER              
            DEALLOCATE CUR_TRANSFER           
            
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
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63210
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Executing sp_send_dbmail alert for Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ULM_TransferExpiry)' + ' ( '
                                 + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                                 
                  UPDATE TRANSFER WITH (ROWLOCK)
                  SET Remarks = 'EMAIL FAILED',
                      TrafficCop = NULL
                  WHERE Transferkey = @c_Transferkey
         
                  SET @n_Err = @@ERROR  
                  IF @n_Err <> 0  
                  BEGIN           
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63220
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TRANSFER for Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ULM_TransferExpiry)' + ' ( '
                                    + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END                             
               END  
               ELSE
               BEGIN
                  UPDATE TRANSFER WITH (ROWLOCK)
                  SET Remarks = 'EMAIL SENT',
                      TrafficCop = NULL
                  WHERE Transferkey = @c_Transferkey
         
                  SET @n_Err = @@ERROR  
                  IF @n_Err <> 0  
                  BEGIN           
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63230
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TRANSFER for Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ULM_TransferExpiry)' + ' ( '
                                     + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END  
               END
            END      	
         END
         FETCH NEXT FROM CUR_TRANSFERKEY INTO @c_Transferkey
      END
      CLOSE CUR_TRANSFERKEY
      DEALLOCATE CUR_TRANSFERKEY

      FETCH NEXT FROM CUR_LOOP INTO @c_GetFacility
   END   --End Facility Loop
   CLOSE CUR_LOOP
   DEALLOCATE CUR_LOOP
            
   QUIT_SP:

   IF OBJECT_ID('tempdb..#TMP_Transfer') IS NOT NULL
      DROP TABLE #TMP_Transfer

   IF OBJECT_ID('tempdb..#TMP_Facility') IS NOT NULL
      DROP TABLE #TMP_Facility

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ULM_TransferExpiry'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012          
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN
   END 
END

GO