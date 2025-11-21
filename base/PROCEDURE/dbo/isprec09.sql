SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispREC09                                           */
/* Creation Date: 20-Jun-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-22772 - CN IKEA Finalize and close ASN validation and   */
/*          create inventoryQC                                          */
/*                                                                      */
/* Called By: isp_ReceiptTrigger_Wrapper from Orders Trigger            */
/*            Storerconfig: ReceiptTrigger_SP                           */
/*                                                                      */
/* GitLab Version: 1.0                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 20-Jun-2023  NJOW     1.0  DevOps Combine Script                     */
/* 09-Sep-2023  NJOW01   1.1  Fix - remove update to lottable02         */
/* 21-Sep-2023  NJOW02   1.2  Change default value from IQC4 to IQC5    */
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispREC09]
   @c_Action    NVARCHAR(10)
 , @c_Storerkey NVARCHAR(15)
 , @b_Success   INT           OUTPUT
 , @n_Err       INT           OUTPUT
 , @c_ErrMsg    NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue          INT
         , @n_StartTCnt         INT
         , @c_Receiptkey        NVARCHAR(10)
         , @c_ReceiptLineNumber NVARCHAR(5)       
         , @c_ToID              NVARCHAR(18)
         , @c_ToLoc             NVARCHAR(10)
         , @c_FinalLoc          NVARCHAR(10)
         , @c_Lot               NVARCHAR(10)
         , @c_Sku               NVARCHAR(20)
         , @c_Packkey           NVARCHAR(10)
         , @c_UOM               NVARCHAR(10)
         , @c_Facility          NVARCHAR(5)
         , @c_Reason            NVARCHAR(10)                  
         , @c_UserDefine05      NVARCHAR(20)
         , @c_QCKey             NVARCHAR(10)
         , @c_QCLineNo          NVARCHAR(5)               
         , @n_QCLineNo          INT
         , @n_DamageQty         INT
         , @n_BeforeReceivedQty INT
         
   SELECT @n_Continue = 1
        , @n_StartTCnt = @@TRANCOUNT
        , @n_Err = 0
        , @c_ErrMsg = ''
        , @b_Success = 1

   IF @c_Action NOT IN ( 'INSERT', 'UPDATE' )
      GOTO QUIT_SP

   IF OBJECT_ID('tempdb..#INSERTED') IS NULL
   BEGIN
      GOTO QUIT_SP
   END
      
   IF @c_Action = 'UPDATE'
   BEGIN
   	  IF @@TRANCOUNT = 0
   	     BEGIN TRAN
   	 
   	  --Finalize ASN
   	  IF @n_continue IN(1,2)
   	  BEGIN
   	  	 SELECT TOP 1 @c_Receiptkey = RD.Receiptkey,
   	  	              @c_ReceiptLineNumber = RD.ReceiptLineNumber,
   	  	              @c_Sku = RD.Sku
         FROM #INSERTED I         
         JOIN #DELETED D (NOLOCK) ON I.Receiptkey = D.Receiptkey
         JOIN RECEIPTDETAIL RD (NOLOCK) ON I.Receiptkey = RD.Receiptkey
         WHERE I.Storerkey = @c_Storerkey
         AND I.DocType = 'R'
         AND I.Status = '9' 
         AND D.Status <> '9'
         AND RD.SubReasonCode = 'Y'
         AND RD.QtyExpected < RD.QtyReceived + CASE WHEN ISNUMERIC(RD.UserDefine05) = 0 OR ISNULL(RD.UserDefine05,'') = '' THEN 0 ELSE CAST(RD.UserDefine05 AS INT) END
         ORDER BY I.Receiptkey, RD.ReceiptLineNumber

         IF @@ROWCOUNT > 0
         BEGIN
            SET @n_continue = 3    
            SET @n_err = 61700 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
            SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Please check Sku: ' +  RTRIM(@c_Sku) + ' on Receipt#: ' + RTRIM(@c_ReceiptKey) + ' Line#: ' + RTRIM(@c_ReceiptLineNumber) + '. Damage Qty+Received Qty > Expected Qty. (ispREC09)'   
         	  GOTO QUIT_SP
         END
   	  	    	  	 
         DECLARE CUR_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT I.Receiptkey
            FROM #INSERTED I         
            JOIN #DELETED D (NOLOCK) ON I.Receiptkey = D.Receiptkey
            WHERE I.Storerkey = @c_Storerkey
            AND I.DocType = 'R'
            AND I.Status = '9' 
            AND D.Status <> '9'
         
         OPEN CUR_REC
         
         FETCH NEXT FROM CUR_REC INTO @c_Receiptkey
         
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
         BEGIN
         	 DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         	    SELECT RD.ReceiptLineNumber, RD.ToID, RD.BeforeReceivedQty      	    
         	    FROM RECEIPTDETAIL RD (NOLOCK)
         	    WHERE RD.Receiptkey = @c_Receiptkey
         
            OPEN CUR_RECDET
            
            FETCH NEXT FROM CUR_RECDET INTO @c_ReceiptLineNumber, @c_ToID, @n_BeforeReceivedQty
            
            WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
            BEGIN
            	  
            	  IF ISNULL(@c_ToID,'') = '' AND @n_BeforeReceivedQty > 0
            	  BEGIN
                  SET @n_continue = 3    
                  SET @n_err = 61700 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                  SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Receipt Detail ToID cannot be blank Line#: ' + @c_ReceiptLineNumber +' (ispREC09)'   
            	  END
            	  
            	  UPDATE RECEIPTDETAIL WITH (ROWLOCK)
            	  SET UserDefine01 = ToID,
            	      --Lottable02 = ToID,  --NJOW01
            	      Trafficcop = NULL 
            	  WHERE Receiptkey = @c_Receiptkey
            	  AND ReceiptLineNumber = @c_ReceiptLineNumber    
         
               SET @n_Err = @@ERROR              
               
               IF  @n_Err <> 0
               BEGIN
                  SET @n_continue = 3    
                  SET @n_err = 61710 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                  SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Update RECEIPTDETAIL Table failed. (ispREC09)'   
               END         	  
            	
               FETCH NEXT FROM CUR_RECDET INTO @c_ReceiptLineNumber, @c_ToID, @n_BeforeReceivedQty            	
            END
            CLOSE CUR_RECDET
            DEALLOCATE CUR_RECDET
         	       	       	       	 
            FETCH NEXT FROM CUR_REC INTO @c_Receiptkey
         END
         CLOSE CUR_REC
         DEALLOCATE CUR_REC         
      END
      
      --Close ASN     
      IF @n_continue IN(1,2)
      BEGIN          	
         DECLARE CUR_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT I.Receiptkey, I.Facility, ISNULL(CL.Code,'IQC5')  --NJOW02
            FROM #INSERTED I
            JOIN #DELETED D (NOLOCK) ON I.Receiptkey = D.Receiptkey
            JOIN RECEIPTDETAIL RD (NOLOCK) ON I.Receiptkey = RD.Receiptkey
            LEFT JOIN CODELKUP CL (NOLOCK) ON I.Facility = CL.Short AND I.RECType = CL.Code2 AND CL.ListName = 'IKEAQCCODE'
            WHERE I.Storerkey = @c_Storerkey
            AND I.DocType = 'R'
            AND I.ASNStatus = '9' 
            AND D.ASNStatus <> '9'
            AND I.Status = '9'
            AND ISNULL(RD.UserDefine05,'') <> '' 
            AND RD.SubReasonCode <> 'Y'
            GROUP BY I.Receiptkey, I.Facility, ISNULL(CL.Code,'IQC5')  --NJOW02
         
         OPEN CUR_REC
         
         FETCH NEXT FROM CUR_REC INTO @c_Receiptkey, @c_Facility, @c_Reason
         
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
         BEGIN
         	 SET @c_QCKey = ''
         	 SET @n_QCLineNo = 0 
         	 SET @c_QCLineNo = ''
         	 SET @c_FinalLoc = ''
         	 
      	   SELECT @c_FinalLoc = Code
      	   FROM CODELKUP (NOLOCK)
      	   WHERE Storerkey = @c_Storerkey
      	   AND Short = @c_Facility
      	   AND ListName = 'IKEAQCFAC'      	      	
         	          	 
         	 DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         	    SELECT RD.ReceiptLineNumber, RD.Sku, RD.ToLoc, RD.ToID, RD.Userdefine05, SKU.Packkey, PACK.PackUOM3, ISNULL(ITRN.Lot,'')
         	    FROM RECEIPTDETAIL RD (NOLOCK)
         	    JOIN SKU (NOLOCK) ON RD.Storerkey = SKU.Storerkey AND RD.Sku = SKU.Sku
         	    JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey
         	    LEFT JOIN ITRN (NOLOCK) ON RD.storerkey = ITRN.Storerkey AND RD.Sku = ITRN.Sku AND ITRN.TranType = 'DP' 
         	                            AND ITRN.SourceKey = RD.Receiptkey+RD.ReceiptLineNumber AND LEFT(ITRN.SourceType,16) = 'ntrReceiptDetail'
         	    WHERE RD.Receiptkey = @c_Receiptkey
         	    AND ISNULL(RD.UserDefine05,'') <> ''       	
         	    AND RD.SubReasonCode <> 'Y'       	       
         
            OPEN CUR_RECDET
            
            FETCH NEXT FROM CUR_RECDET INTO @c_ReceiptLineNumber, @c_Sku, @c_ToLoc, @c_ToID, @c_UserDefine05, @c_Packkey, @c_UOM, @c_Lot
            
            WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
            BEGIN         	  
            	  IF ISNUMERIC(@c_UserDefine05) <> 1
            	  BEGIN
                  SET @n_continue = 3    
                  SET @n_err = 61720 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                  SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Invalid damage qty at Line# ' + @c_ReceiptLineNumber +' (ispREC09)'   
            	  END
            	  ELSE IF CAST(@c_UserDefine05 AS INT) = 0
            	  BEGIN
            	     GOTO NEXT_RECDET
            	  END         	           	  
            	  
            	  IF @n_continue IN(1,2)
            	  BEGIN
            	  	 SET @n_DamageQty = CAST(@c_UserDefine05 AS INT)
            	  	 
            	  	 IF @c_QCKey = ''
            	  	 BEGIN
                     EXEC dbo.nspg_GetKey                
                          @KeyName = 'INVQC'    
                         ,@fieldlength = 10    
                         ,@keystring = @c_QCKey OUTPUT    
                         ,@b_Success = @b_success OUTPUT    
                         ,@n_err = @n_err OUTPUT    
                         ,@c_errmsg = @c_errmsg OUTPUT
                         ,@b_resultset = 0    
                         ,@n_batch     = 1                           	  	 	
            	  	 	
            	  	    INSERT INTO INVENTORYQC (QC_Key, StorerKey, Reason, TradeReturnKey, Refno, from_facility, to_facility, 
            	  	                             UserDefine01, UserDefine02, UserDefine03, UserDefine04, UserDefine05, UserDefine06,
                                              UserDefine07, UserDefine08, UserDefine09, UserDefine10, Notes, FinalizeFlag)
                                      VALUES (@c_QCKey, @c_Storerkey, @c_Reason, @c_Receiptkey, '', @c_Facility, @c_Facility,
                                              '', '', '', '', '', '',
                                              '', '', '', '', 'Damage(Inbound)', 'N')
                                                                                     
                     SET @n_Err = @@ERROR
                     
                     IF  @n_Err <> 0
                     BEGIN
                        SET @n_continue = 3    
                        SET @n_err = 61730 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                        SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Insert INVENTORYQC Table failed. (ispREC09)'   
                     END  
                  END     
                  
                  SET @n_QCLineNo = @n_QCLineNo + 1
                  SET @c_QCLineNo = RIGHT('00000' + RTRIM(LTRIM(CAST(@n_QCLineNo AS NVARCHAR))), 5)
                                    

                  INSERT INTO INVENTORYQCDETAIL (QC_Key, QCLineNo, StorerKey, SKU, PackKey, UOM, OriginalQty, Qty, FromLoc, FromLot,
                                                 FromID, ToQty, ToID, ToLoc, Reason, Status, UserDefine01, UserDefine02, UserDefine03,
                                                 UserDefine04, UserDefine05, UserDefine06, UserDefine07, UserDefine08, UserDefine09,
                                                 UserDefine10, FinalizeFlag, Channel, Channel_ID)
                                         VALUES (@c_QCKey, @c_QCLineNo, @c_Storerkey, @c_SKu, @c_PackKey, @c_UOM, @n_DamageQty, @n_DamageQty, @c_ToLoc, @c_Lot,
                                                 @c_ToID, @n_DamageQty, '', @c_FinalLoc, @c_Reason, '0', '', '', '',
                                                 '', '', '', '', '', '',
                                                 '', 'N', '', 0)     
                                                          
                  SET @n_Err = @@ERROR
                  
                  IF  @n_Err <> 0
                  BEGIN
                     SET @n_continue = 3    
                     SET @n_err = 61740 -- Should Be Set To The SQL Errmessage but I don't know how to do so. 
                     SET @c_errmsg = 'NSQL'+ CONVERT(NVARCHAR(5), @n_err) +': Insert INVENTORYQCDETAIL Table failed. (ispREC09)'   
                  END                 
               END   
               
               NEXT_RECDET:
            	
               FETCH NEXT FROM CUR_RECDET INTO @c_ReceiptLineNumber, @c_Sku, @c_ToLoc, @c_ToID, @c_UserDefine05, @c_Packkey, @c_UOM, @c_Lot    	
            END
            CLOSE CUR_RECDET
            DEALLOCATE CUR_RECDET
         	       	       	       	 
            FETCH NEXT FROM CUR_REC INTO @c_Receiptkey, @c_Facility, @c_Reason
         END
         CLOSE CUR_REC
         DEALLOCATE CUR_REC          
      END           	         
   END
            
   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_REC') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_REC
      DEALLOCATE CUR_REC
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_RECDET') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET
   END

   IF @n_Continue = 3 -- Error Occured - Process AND Return
   BEGIN
      SELECT @b_Success = 0
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'ispREC09'
      --RAISERROR (@c_Errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO