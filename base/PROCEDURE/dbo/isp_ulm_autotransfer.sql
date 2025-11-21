SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: isp_ULM_AutoTransfer                                  */
/* Creation Date: 01-APR-2022                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-19383 - MY Unilever - Auto create transfer to transfer     */
/*          RMA or DMG inventory                                           */
/*                                                                         */
/* Called By: SQL Backend Job run daily                                    */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 7.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 01-May-2022  NJOW01  1.0   DEVOPS Combine Script                        */
/***************************************************************************/
CREATE PROC [dbo].[isp_ULM_AutoTransfer]
       @c_TransferType NVARCHAR(10)=''  --RMA or DMG
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success             INT,
           @n_Err                 INT,
           @c_ErrMsg              NVARCHAR(255),
           @n_Continue            INT,
           @n_StartTranCount      INT

   DECLARE @c_Storerkey           NVARCHAR(15),
           @c_Sku                 NVARCHAR(20),
           @c_Transferkey         NVARCHAR(10),
           @c_Lot                 NVARCHAR(10),
           @c_FromLoc             NVARCHAR(10),
           @c_ToLoc               NVARCHAR(10),
           @c_ID                  NVARCHAR(18),
           @c_Facility            NVARCHAR(5),
           @n_Qty                 INT,
           @c_Type                NVARCHAR(10),
           @c_Remark              NVARCHAR(200)='',
           @n_RowID               INT,
           @c_Status              NVARCHAR(10)

   DECLARE @c_TransferLineNumber NVARCHAR(5),
           @c_FromStorerkey      NVARCHAR(15),
           @c_FromSku            NVARCHAR(20),
           @c_FromDescr          NVARCHAR(60),
           @c_FromLot            NVARCHAR(10),
           @c_FromID             NVARCHAR(18),
           @n_FromQty            INT,
           @c_ToStorerkey        NVARCHAR(15),
           @c_ToSku              NVARCHAR(20),
           @c_ToDescr            NVARCHAR(60),
           @c_ToLot              NVARCHAR(10),
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
           @n_FromQtyInCase      DECIMAL(20,2),   
           @c_FromQtyInCase      NVARCHAR(20)     
           
   DECLARE @c_Body                NVARCHAR(MAX),
           @c_Subject             NVARCHAR(255),
           @c_Date                NVARCHAR(20),
           @c_SendEmail           NVARCHAR(1),
           @c_Recipients          NVARCHAR(2000)           

   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT
   
   SET @c_Storerkey = 'UNILEVER'

   --IF @@TRANCOUNT = 0
   --   BEGIN TRAN

   CREATE TABLE #TMP_TRF (Rowid INT IDENTITY(1,1), 
                          Type NVARCHAR(10),
                          Facility NVARCHAR(5),
                          FromLoc NVARCHAR(10),
                          ToLoc NVARCHAR(10),
                          Transferkey NVARCHAR(10),
                          Status NVARCHAR(10)
                          )
   IF @c_TransferType = 'RMA'        
   BEGIN
   	  INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('RMA','BR','10RMABR-V','10RMABR','','0')   	  
	    INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('RMA','BRL','10RMABRL-V','10RMABRL','','0')   	     	  
   END                   
   ELSE IF @c_TransferType = 'DMG'  
   BEGIN
   	  INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('DMG','BR','BRDMG','BRDMG-V','','0')   	  
	    INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('DMG','BRL','BRLDMG','BRLDMG-V','','0')   	     	  
   END
   ELSE
   BEGIN
   	  INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('RMA','BR','10RMABR-V','10RMABR','','0')   	  
	    INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('RMA','BRL','10RMABRL-V','10RMABRL','','0')   	     	  
   	  INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('DMG','BR','BRDMG','BRDMG-V','','0')   	  
	    INSERT INTO #TMP_TRF (Type, Facility, FromLoc, ToLoc, Transferkey, Status) VALUES('DMG','BRL','BRLDMG','BRLDMG-V','','0')   	     	  
   END

   IF @n_continue IN(1,2)   
   BEGIN
      DECLARE CUR_TRF CURSOR LOCAL FAST_FORWARD READ_ONLY FOR      
          SELECT RowID, Type, Facility, FromLoc, ToLoc
          FROM #TMP_TRF
          ORDER BY RowId

      OPEN CUR_TRF

      FETCH NEXT FROM CUR_TRF INTO @n_RowId, @c_Type, @c_Facility, @c_FromLoc, @c_ToLoc

      WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
      BEGIN          
      	 SET @c_Transferkey = ''
      	 SET @c_Status = '0'
      	 
      	 DECLARE CUR_INV CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
      	    SELECT LLI.Sku, LLI.Lot, LLI.Id, 
      	           LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked AS Qty
            FROM LOTXLOCXID LLI (NOLOCK)
     	      JOIN ID (NOLOCK) ON LLI.Id = ID.Id
     	      JOIN LOC (NOLOCK) ON LLI.Loc = LOC.Loc
     	      JOIN LOT (NOLOCK) ON LLI.Lot = LOT.Lot
     	      JOIN LOTATTRIBUTE LA (NOLOCK) ON LOT.Lot = LA.Lot
     	      WHERE ID.Status = 'OK'
     	      AND LOC.LocationFlag = 'HOLD'
     	      AND LOC.Status = 'OK'
     	      AND LOT.Status = 'OK'
     	      AND LLI.Storerkey = @c_Storerkey
    	      AND LA.Lottable03 = 'UR'
    	      AND LOC.HostWHCode = 'M001'
    	      AND LOC.Loc = @c_FromLoc
    	      AND LOC.Facility = @c_Facility
     	      AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0
     	      ORDER BY LA.Lottable05, LOC.LogicalLocation, LOC.Loc      	 

         OPEN CUR_INV

         FETCH NEXT FROM CUR_INV INTO @c_Sku, @c_Lot, @c_Id, @n_Qty

         WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
         BEGIN                	
            SET @b_Success = 0
      	    EXEC ispCreateTransfer
      	       @c_Transferkey = @c_Transferkey OUTPUT,
      	       @c_FromFacility = @c_Facility,
      	       @c_FromLot = @c_Lot,
               @c_FromLoc = @c_FromLoc,
               @c_FromID = @c_ID,
               @n_FromQty = @n_Qty,
               @c_ToLoc = @c_ToLoc,
      	       @c_CopyLottable = 'Y',
      	       @c_Finalize = 'N',
      	       @c_Type = 'ULM-SLT',
      	       @c_ReasonCode = 'U311',
      	       @c_Remarks = @c_Remark,
      	       @b_Success = @b_Success OUTPUT,
      	       @n_Err = @n_Err OUTPUT,
      	       @c_ErrMsg = @c_ErrMsg OUTPUT

   	        IF  @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
   	           SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (isp_ULM_AutoTransfer)'
            END
         	        	      
            FETCH NEXT FROM CUR_INV INTO @c_Sku, @c_Lot, @c_Id, @n_Qty
         END
         CLOSE CUR_INV
         DEALLOCATE CUR_INV
         
         --finalize current transfer
         IF @n_continue IN(1,2) AND ISNULL(@c_Transferkey,'') <> ''
         BEGIN
            EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
         
            IF @b_Success <> 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63200
               SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (isp_ULM_AutoTransfer)' + ' ( '
                                      + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               SET @c_Status = 'E'                       
            END            
            ELSE
               SET @c_Status = '9'
         END   
         
         UPDATE #TMP_TRF
         SET Transferkey = @c_Transferkey,
             Status = @c_Status                 
         WHERE RowId = @n_RowID                              
                     	 
         FETCH NEXT FROM CUR_TRF INTO @n_RowId, @c_Type, @c_Facility, @c_FromLoc, @c_ToLoc
      END
      CLOSE CUR_TRF
      DEALLOCATE CUR_TRF          
   END
   
   IF @n_continue IN(1,2)
   BEGIN
      SELECT TOP 1 @c_Recipients = Notes
      FROM CODELKUP (NOLOCK)
      WHERE Listname = 'EMAILALERT'
      AND Storerkey = @c_Storerkey
      AND Code = 'isp_ULM_AutoTransfer'
      
      IF ISNULL(@c_Recipients,'') = '' 
         SET @c_Recipients = 'LFLMYInventory@lflogistics.com'      
            	
   	  DECLARE CUR_Email CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT Transferkey, Type, Facility
         FROM #TMP_TRF
         WHERE Status = '9'
         ORDER BY RowId

      OPEN CUR_Email

      FETCH NEXT FROM CUR_Email INTO @c_Transferkey, @c_Type, @c_Facility

      WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
      BEGIN
   	     SET @c_SendEmail ='N'
         SET @c_Date = CONVERT(NVARCHAR(10), GETDATE(), 103)
         
         SET @c_Subject = 'UNILEVER ' + RTRIM(@c_Type) + ' Transfer for ' + RTRIM(@c_Facility) + ' - ' + @c_Date         
         
         SET @c_Body = '<style type="text/css">
                  p.a1  {  font-family: Arial; font-size: 12px;  }
                  table {  font-family: Arial; margin-left: 0em; border-collapse:collapse;}
                  table, td, th {padding:3px; font-size: 12px; }
                  td { vertical-align: top}
                  </style>'

         SET @c_Body = @c_Body + '<p>Dear All, </p>'

         SET @c_Body = @c_Body + '<p>Please be informed of Transfer ' + RTRIM(@c_Type) + ' Stocks at facility ' + RTRIM(@c_Facility) + '</p>'

         SET @c_Body = @c_Body + '<table border="1" cellspacing="0" cellpadding="5">'
         SET @c_Body = @c_Body + '<tr bgcolor=silver><th>Transferkey</th><th>TransferLineNumber</th><th>FromStorerkey</th><th>FromSku</th><th>FromDescr</th><th>FromLoc</th>'
         SET @c_Body = @c_Body + '<th>FromLot</th><th>FromId</th><th>FromQty (PC)</th><th>FromQty (CS)</th><th>FromLottable01</th><th>FromLottable02</th><th>FromLottable04</th>'   
         SET @c_Body = @c_Body + '<th>FromLottable05</th><th>ToLoc</th></tr>'

         
         DECLARE CUR_TRANSFER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT TRD.Transferkey, TRD.TransferLineNumber, TRD.FromStorerkey, TRD.FromSku, SKU.Descr, TRD.FromLoc, TRD.FromLot, TRD.FromID, TRD.FromQty,
                   CASE WHEN ISNULL(PACK.Casecnt,0) = 0 THEN 0 ELSE CAST((TRD.FromQty / PACK.Casecnt) AS DECIMAL(20,2)) END AS FromQtyInCase,   
                   TRD.Lottable01, TRD.Lottable02, '', TRD.Lottable04, TRD.Lottable05, TRD.ToStorerkey, TRD.ToSku, SKU.Descr, TRD.ToLoc, TRD.ToLot,   
                   TRD.ToID, TRD.ToQty, TRD.ToLottable01, TRD.ToLottable02, TRD.ToLottable03, TRD.ToLottable04, TRD.ToLottable05
            FROM TRANSFER TR (NOLOCK)
            JOIN TRANSFERDETAIL TRD (NOLOCK) ON TR.Transferkey = TRD.Transferkey
            JOIN SKU (NOLOCK) ON TRD.FromStorerkey = SKU.Storerkey AND TRD.FromSku = SKU.Sku
            JOIN PACK (NOLOCK) ON PACK.Packkey = SKU.Packkey   
            WHERE TR.Transferkey = @c_Transferkey
            ORDER BY TRD.TransferLineNumber

         OPEN CUR_TRANSFER

         FETCH NEXT FROM CUR_TRANSFER INTO @c_Transferkey, @c_TransferLineNumber, @c_FromStorerkey, @c_FromSku, @c_FromDescr, @c_FromLoc, @c_FromLot, @c_FromID, @n_FromQty,
                                           @n_FromQtyInCase,  
                                           @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_ToStorerkey, @c_ToSku, @c_ToDescr, @c_ToLoc,
                                           @c_ToLot, @c_ToID, @n_ToQty, @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @dt_ToLottable04, @dt_ToLottable05

         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
         BEGIN
            IF @n_FromQtyInCase % 1 = 0
               SET @c_FromQtyInCase = CAST(@n_FromQtyInCase AS INT)
            ELSE
               SET @c_FromQtyInCase = @n_FromQtyInCase

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
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_FromQtyInCase)+ '</td>'   
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable01)+ '</td>'
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_Lottable02)+ '</td>'
            SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_Lottable04, 103))+ '</td>'
            SET @c_Body = @c_Body + '<td>' + RTRIM(CONVERT(NVARCHAR(10), @dt_Lottable05, 103))+ '</td>'
            SET @c_Body = @c_Body + '<td>' + RTRIM(@c_ToLoc)+ '</td>'
            SET @c_Body = @c_Body + '</tr>'

            FETCH NEXT FROM CUR_TRANSFER INTO @c_Transferkey, @c_TransferLineNumber, @c_FromStorerkey, @c_FromSku, @c_FromDescr, @c_FromLoc, @c_FromLot, @c_FromID, @n_FromQty,
                                              @n_FromQtyInCase,   
                                              @c_Lottable01, @c_Lottable02, @c_Lottable03, @dt_Lottable04, @dt_Lottable05, @c_ToStorerkey, @c_ToSku, @c_ToDescr, @c_ToLoc,
                                              @c_ToLot, @c_ToID, @n_ToQty, @c_ToLottable01, @c_ToLottable02, @c_ToLottable03, @dt_ToLottable04, @dt_ToLottable05
         END
         CLOSE CUR_TRANSFER
         DEALLOCATE CUR_TRANSFER

         SET @c_Body = @c_Body + '</table>'

         IF @c_SendEmail = 'Y'
         BEGIN
         	  print @c_Recipients
         	  print @c_Subject
         	  print @c_Body 
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
                  
         FETCH NEXT FROM CUR_Email INTO @c_Transferkey, @c_Type, @c_Facility
      END
      CLOSE CUR_Email
      DEALLOCATE CUR_Email
   END

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_ULM_AutoTransfer'
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