SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ShelfLifeExpiredAlert                             */
/* Creation Date: 28-APR-2017                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-1734 - SG Prestige shelf life expired alert by email and   */
/*                     Auto create transfer lot's lottable03 to expiring   */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 08/06/2017   NJOW01  1.0   WMS-1734 Get shelflife from sku              */
/* 23/06/2017   MT01    1.1   IN00385458 Removed '@c_' in where clause     */
/* 27/10/2017   AikLiang1.2   Add Busr6 GIVENCHY FRAGRANCE                 */
/* 14/09/2018   NJOW02  1.3   WMS-6312 add expiry checking for FIFO Sku    */ 
/* 10/07/2020   CSCHONG 1.4   WMS-14049 revised field logic (CS01)         */
/***************************************************************************/  
CREATE PROC [dbo].[isp_ShelfLifeExpiredAlert]    
(
   @c_Facility  NVARCHAR(5) = 'BULIM',
   --@n_ShelfLife INT = 179,
   @c_Recipients NVARCHAR(2000) = 'LFLSGPPrestigeUsers@lftltd.net' --email address delimited by ;
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
           @c_Busr6Value01       NVARCHAR(30),
           @c_Busr6Value02       NVARCHAR(30),
           @c_Busr6Value03       NVARCHAR(30),  --AL01
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
           @c_StockStatus        NVARCHAR(10)
    
   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT
   
   SET @c_Storerkey = 'PRESTIGE'
   SET @c_SkuGroup = 'STOCK'
   SET @c_Busr6Value01 = 'GIVENCHY SKINCARE'
   SET @c_Busr6Value02 = 'GIVENCHY COSMETICS'
   SET @c_Busr6Value03 = 'GIVENCHY FRAGRANCE'  --AL01

   SET @c_Lottable03 = 'EXPIRING'
   SET @c_Type = 'XA'
   SET @c_ReasonCode = '01'
   SET @c_CustomerRefNo = 'PPD_' + RIGHT(RTRIM(CONVERT(NVARCHAR,GETDATE(),112)),4)
   SET @c_CopyLottable = 'Y'
   SET @c_Finalize = 'N'
   SET @c_Transferkey = ''   
         
   BEGIN TRAN
   	   	
   	--Create transfer for expired inventory
   IF @n_continue IN(1,2)
   BEGIN
      SELECT LLI.Lot,         
             /*CASE WHEN DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife -(CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END), LA.Lottable05)) <= 0 THEN  --NJOW02
                  'EXPIRED'
                  WHEN DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife -(CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END), LA.Lottable05)) <= 179 THEN
                  'EXPIRING' 
             END AS StockStatus*/    
             --CS01 START
             /*CASE WHEN DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable05)) <= 0 THEN  --NJOW02
                  'EXPIRED'
                  WHEN DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable05)) <= 179 THEN
                  'EXPIRING' 
             END AS StockStatus*/
             CASE WHEN LA.Lottable03 IN ('OK','OK-RTN','EXPIRING','IBEXPR') AND DATEDIFF(dd, GETDATE(), LA.Lottable04) <= 1 THEN  
                  'EXPIRED'
                  WHEN LA.Lottable03 IN ('OK','OK-RTN')  AND DATEDIFF(dd, GETDATE(), LA.Lottable04) > 1
                       AND (CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END) - DATEDIFF(dd, GETDATE(), LA.Lottable04) >=1 THEN
                  'EXPIRING' 
             END AS StockStatus     
            --CS01 END     
      INTO #TMP_EXPLOT
      FROM LOTXLOCXID LLI (NOLOCK)
      JOIN SKU (NOLOCK)ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku      
      JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      WHERE LLI.Storerkey = @c_Storerkey
      --AND DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable05)) <= 179   --NJOW02                         --CS01
      AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
      AND (LOC.Facility = @c_Facility OR ISNULL(@c_Facility,'') = '')      
      --AND SKU.Strategykey = 'PPDSTD'  --NJOW02                                                                           --CS01
      --AND (LA.Lottable03 = 'OK' --NOT IN('EXPIRED','EXPIRING')                                                           --CS01  
      --     OR (LA.Lottable03 = 'EXPIRING' AND DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable05)) <= 0)) --CS01  
      GROUP BY LLI.Lot,
               --CS01 START
               --CASE WHEN DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable05)) <= 0 THEN  --NJOW02
               --     'EXPIRED'
               --     WHEN DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable05)) <= 179 THEN
               --     'EXPIRING'                                     
               --END
              CASE WHEN LA.Lottable03 IN ('OK','OK-RTN','EXPIRING','IBEXPR') AND DATEDIFF(dd, GETDATE(), LA.Lottable04) <= 1 THEN  
                  'EXPIRED'
                  WHEN LA.Lottable03 IN ('OK','OK-RTN')  AND DATEDIFF(dd, GETDATE(), LA.Lottable04) > 1
                       AND (CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END) - DATEDIFF(dd, GETDATE(), LA.Lottable04) >=1 THEN
                  'EXPIRING' 
             END       
             --CS01 END
      --UNION ALL  --CS01 remove union       
      --SELECT LLI.Lot, 
      --        --CS01 START
      --       --CASE WHEN LA.Lottable03 = 'EXPIRING' OR DATEDIFF(DAY, GETDATE(), LA.Lottable04) <= 0 THEN 
      --       --    'EXPIRED' ELSE 'EXPIRING' END AS StockStatus
      --        CASE WHEN LA.Lottable03 IN ('OK','OK-RTN','EXPIRING') AND DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable04)) <= 1 THEN  
      --            'EXPIRED'
      --            WHEN LA.Lottable03 IN ('OK','OK-RTN')  AND DATEDIFF(dd, GETDATE(), LA.Lottable04) > 1
      --                 AND (CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END) - DATEDIFF(dd, GETDATE(), LA.Lottable04) >=1 THEN
      --            'EXPIRING' 
      --       END AS StockStatus 
      --       --CS01 END
      --FROM LOTXLOCXID LLI (NOLOCK)
      --JOIN SKU (NOLOCK)ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku      
      --JOIN LOTATTRIBUTE LA (NOLOCK) ON LLI.Lot = LA.Lot
      --JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
      --WHERE LLI.Storerkey = @c_Storerkey
      ----AND SKU.SkuGroup = @c_SkuGroup                                     --CS01
      --AND SKU.Busr6 IN(@c_Busr6Value01, @c_Busr6Value02, @c_Busr6Value03)  --AL01
      ----AND DATEDIFF(Day, GETDATE(), LA.Lottable04) <= @n_Shelflife
      --AND DATEDIFF(Day, GETDATE(), LA.Lottable04) <= CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END
      --AND (LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked) > 0
      --AND (LOC.Facility = @c_Facility OR ISNULL(@c_Facility,'') = '')      
      ----AND SKU.Strategykey <> 'PPDFEFO'  --NJOW02                                                 --CS01
      ----AND (LA.Lottable03 = 'OK' --NOT IN('EXPIRED','EXPIRING')                                   --CS01
      ----     OR (LA.Lottable03 = 'EXPIRING' AND DATEDIFF(DAY, GETDATE(), LA.Lottable04) <= 0))     --CS01
      --GROUP BY LLI.Lot,
      --         --CS01 START
      --         --CASE WHEN LA.Lottable03 = 'EXPIRING' OR DATEDIFF(DAY, GETDATE(), LA.Lottable04) <= 0 THEN 
      --         --  'EXPIRED' ELSE 'EXPIRING' END
      --         CASE WHEN LA.Lottable03 IN ('OK','OK-RTN','EXPIRING') AND DATEDIFF(dd, GETDATE(), DATEADD(DAY, SKU.ShelfLife, LA.Lottable04)) <= 1 THEN  
      --            'EXPIRED'
      --            WHEN LA.Lottable03 IN ('OK','OK-RTN')  AND DATEDIFF(dd, GETDATE(), LA.Lottable04) > 1
      --                 AND (CASE WHEN ISNUMERIC(SKU.Susr2) = 1 THEN CAST(SKU.Susr2 AS INT) ELSE 0 END) - DATEDIFF(dd, GETDATE(), LA.Lottable04) >=1 THEN
      --            'EXPIRING'  
      --       END 
               --CS01 END
      
      DECLARE CUR_EXPLOT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Lot, StockStatus
         FROM #TMP_EXPLOT
         WHERE ISNULL(StockStatus,'') <> ''                 --CS01
         ORDER BY StockStatus, Lot
         
      OPEN CUR_EXPLOT  
      
      FETCH NEXT FROM CUR_EXPLOT INTO @c_Lot, @c_StockStatus
      
      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN        	      	 
      	 
      	 SET @c_Lottable03 = @c_StockStatus
      	       	     	
      	 SET @b_Success = 0
      	 EXEC ispCreateTransfer
      	    @c_Transferkey = @c_Transferkey OUTPUT,
      	    @c_FromFacility = @c_Facility,
      	    @c_FromLot = @c_Lot,
      	    @c_ToLottable03 = @c_Lottable03,
      	    @c_CopyLottable = @c_CopyLottable,
      	    @c_Finalize = @c_Finalize,
      	    @c_Type = @c_Type,
      	    @c_ReasonCode = @c_ReasonCode,
      	    @c_CustomerRefNo = @c_CustomerRefNo,      	    
      	    @b_Success = @b_Success OUTPUT,
      	    @n_Err = @n_Err OUTPUT,
      	    @c_ErrMsg = @c_ErrMsg OUTPUT

   	     IF  @b_Success <> 1
         BEGIN
            SELECT @n_continue = 3
   	        SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (isp_ShelfLifeExpiredAlert)'
         END
               	          	          	
         FETCH NEXT FROM CUR_EXPLOT INTO @c_Lot, @c_StockStatus
      END
      CLOSE CUR_EXPLOT
      DEALLOCATE CUR_EXPLOT       
   END
   
      --finalize transfer
   IF ISNULL(@c_Transferkey,'') <> '' AND @n_continue IN(1,2)
   BEGIN
      EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
      
      IF @b_Success <> 1
      BEGIN
         SELECT @n_continue = 3
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63200
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ShelfLifeExpiredAlert)' + ' ( '
                                + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
      END
   END   

   --Send alert by email
   IF ISNULL(@c_Transferkey,'') <> '' AND @n_continue IN(1,2)
   BEGIN   	                                                            
   	  SET @c_SendEmail ='N'
      SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)  
      SET @c_Subject = 'Prestige Inventory Expired Alert - ' + @c_Date  
      
      SET @c_Body = '<style type="text/css">       
               p.a1  {  font-family: Arial; font-size: 12px;  }      
               table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}      
               table, td, th {padding:3px; font-size: 12px; }
               td { vertical-align: top}
               </style>'
  
      SET @c_Body = @c_Body + '<b>The following are the shelf life expiring inventory:</b>'  
      SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'   
      SET @c_Body = @c_Body + '<tr bgcolor=silver><th>Transferkey</th><th>TransferLineNumber</th><th>FromStorerkey</th><th>FromSku</th><th>FromDescr</th><th>FromLoc</th>'  
      SET @c_Body = @c_Body + '<th>FromLot</th><th>FromId</th><th>FromQty</th><th>FromLottable01</th><th>FromLottable02</th><th>FromLottable03</th><th>FromLottable04</th>'  
      SET @c_Body = @c_Body + '<th>FromLottable05</th><th>ToStorerkey</th><th>ToSku</th><th>ToDescr</th><th>ToLoc</th><th>ToLot</th><th>ToId</th><th>ToQty</th>'  
      SET @c_Body = @c_Body + '<th>ToLottable01</th><th>ToLottable02</th><th>ToLottable03</th><th>ToLottable04</th><th>ToLottable05</th></tr>'  
      
      DECLARE CUR_TRANSFER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
         SELECT TRD.Transferkey, TRD.TransferLineNumber, TRD.FromStorerkey, TRD.FromSku, SKU.Descr, TRD.FromLoc, TRD.FromLot, TRD.FromID, TRD.FromQty,
                TRD.Lottable01, TRD.Lottable02, TRD.Lottable03, TRD.Lottable04, TRD.Lottable05, TRD.ToStorerkey, TRD.ToSku, SKU.Descr, TRD.ToLoc, TRD.ToLot,
                TRD.ToID, TRD.ToQty, TRD.ToLottable01, TRD.ToLottable02, TRD.ToLottable03, TRD.ToLottable04, TRD.ToLottable05          
         FROM TRANSFER TR (NOLOCK)
         JOIN TRANSFERDETAIL TRD (NOLOCK) ON TR.Transferkey = TRD.Transferkey        
         JOIN SKU (NOLOCK) ON TRD.FromStorerkey = SKU.Storerkey AND TRD.FromSku = SKU.Sku
         WHERE TR.Transferkey = @c_Transferkey
         ORDER BY TRD.TransferLineNumber
        
      OPEN CUR_TRANSFER              
        
      FETCH NEXT FROM CUR_TRANSFER INTO @c_Transferkey, @c_TransferLineNumber, @c_FromStorerkey, @c_FromSku, @c_FromDescr, @c_FromLoc, @c_FromLot, @c_FromID, @n_FromQty,
                                        @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_ToStorerkey, @c_ToSku, @c_ToDescr, @c_ToLoc,  
                                        @c_ToLot, @c_ToID, @n_ToQty, @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @dt_ToLottable04, @dt_ToLottable05
        
      WHILE @@FETCH_STATUS <> -1       
      BEGIN  
         
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
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable01)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable02)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable03)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_Lottable04, 103))+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_Lottable05, 103))+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToStorerkey)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToSku)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToDescr)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLoc)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLot)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToID)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(CAST(@n_ToQty AS NVARCHAR))+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLottable01)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLottable02)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLottable03)+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_ToLottable04, 103))+ '</td>'  
         SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_ToLottable05, 103))+ '</td>'  
         SET @c_Body = @c_Body + '</tr>'  
                                            
         FETCH NEXT FROM CUR_TRANSFER INTO @c_Transferkey, @c_TransferLineNumber, @c_FromStorerkey, @c_FromSku, @c_FromDescr, @c_FromLoc, @c_FromLot, @c_FromID, @n_FromQty,
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
   	        SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Executing sp_send_dbmail alert for Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ShelfLifeExpiredAlert)' + ' ( '
                           + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                           
            UPDATE TRANSFER WITH (ROWLOCK)
            SET Remarks = 'EMAIL FAILED',
                TrafficCop = NULL
            WHERE Transferkey = @c_Transferkey	     --MT01

            SET @n_Err = @@ERROR  
            IF @n_Err <> 0  
            BEGIN           
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63220
   	           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TRANSFER for Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ShelfLifeExpiredAlert)' + ' ( '
                              + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END                             
         END  
         ELSE
         BEGIN
            UPDATE TRANSFER WITH (ROWLOCK)
            SET Remarks = 'EMAIL SENT',
                TrafficCop = NULL
            WHERE Transferkey = @c_Transferkey	      --MT01

            SET @n_Err = @@ERROR  
            IF @n_Err <> 0  
            BEGIN           
                 SELECT @n_continue = 3
                 SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63230
   	           SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TRANSFER for Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ShelfLifeExpiredAlert)' + ' ( '
                              + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
            END  
         END
      END         	
   END
            
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ShelfLifeExpiredAlert'
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