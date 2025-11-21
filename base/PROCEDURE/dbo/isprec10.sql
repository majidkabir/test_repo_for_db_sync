SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: ispREC10                                           */
/* Creation Date: 12-DEC-2023                                           */
/* Copyright: MAERSK                                                    */
/* Written by:                                                          */
/*                                                                      */
/* Purpose: WMS-24401 - ZAF DEFY close ASN auto create transfer for     */
/*          DAMAGE stock                                                */
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
/* 12-DEC-2023  NJOW     1.0  DevOps Combine Script                     */
/* 21-JUN-2024  SSA01    1.1  Updated to handle return items            */
/*                            as part of UWP-20525                      */
/* 24-JUN-2024  SSA02    1.2  Added missing variable while executing    */
/*                            update transfer detail query              */
/* 25-JUN-2024  SSA03    1.3  Syntax error fix                          */
/* 26-JUN-2024  SSA04    1.4  Updated transfer detail update dynamic    */
/*                            query                                     */
/* 27-JUN-2024  SSA05    1.5  Updated to address cursor fix             */
/************************************************************************/
CREATE   PROCEDURE [dbo].[ispREC10]
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

   DECLARE @n_Continue           INT
         , @n_StartTCnt          INT
         , @c_Receiptkey         NVARCHAR(10)
         , @c_Facility           NVARCHAR(5)
         , @c_Sku                NVARCHAR(20)
         , @c_Lot                NVARCHAR(10)
         , @n_QtyReceived        INT
         , @c_UOM                NVARCHAR(10)
         , @c_Loc                NVARCHAR(10)
         , @c_ID                 NVARCHAR(18)
         , @c_ExternReceiptkey   NVARCHAR(50)
         , @c_PALoc              NVARCHAR(10)
         , @c_Transferkey        NVARCHAR(10)
         , @c_TransferLineNumber NVARCHAR(5)
         , @c_Itrnkey            NVARCHAR(10)
         , @c_CfgRecTriggerOpt5  NVARCHAR(100)                   --(SSA01)
         , @c_ASNAutoTRFType     NVARCHAR(100)                   --(SSA01)
         , @c_Type               NVARCHAR(20)                    --(SSA01)
         , @c_Condition          NVARCHAR(MAX)                   --(SSA01)
         , @c_SQL                NVARCHAR(MAX)                   --(SSA01)

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
      
   IF @c_Action IN('UPDATE')
   BEGIN
   	  IF @@TRANCOUNT = 0
   	     BEGIN TRAN
   	 ----(SSA01) start ----

         DECLARE CUR_REC CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT I.Receiptkey,I.Rectype, I.Facility, I.Storerkey
            FROM #INSERTED I
            JOIN #DELETED D (NOLOCK) ON I.Receiptkey = D.Receiptkey
            JOIN RECEIPTDETAIL RD (NOLOCK) ON I.Receiptkey = RD.Receiptkey
            WHERE I.Storerkey = @c_Storerkey
            AND I.ASNStatus = '9'
            AND D.ASNStatus <> '9'
            AND RD.FinalizeFlag = 'Y'
            AND RD.QtyReceived > 0
            ORDER BY I.Receiptkey

         OPEN CUR_REC
         
         FETCH NEXT FROM CUR_REC INTO @c_Receiptkey, @c_Type, @c_Facility, @c_Storerkey
         
         WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
         BEGIN         	  
         	  SET @c_Transferkey = ''
            ----(SSA01) start ----

            SELECT @c_CfgRecTriggerOpt5  = fsgr.ConfigOption5
              FROM dbo.fnc_SelectGetRight(@c_Facility, @c_Storerkey, '', 'ReceiptTrigger_SP') AS fsgr

               SET @c_ASNAutoTRFType = 'NORMAL';
               SELECT @c_ASNAutoTRFType = dbo.fnc_GetParamValueFromString('@c_ASNAutoTRFType', @c_CfgRecTriggerOpt5, @c_ASNAutoTRFType)

               IF(CHARINDEX(@c_Type, LTRIM(@c_ASNAutoTRFType)) <= 0)
               BEGIN
                  GOTO NEXT_ASN
               END

               SET @c_Condition = ''
               IF(@c_Type = 'NORMAL')
               BEGIN
                  SET @c_Condition = ' AND RD.Lottable02 = ''DAMAGE'''
               END

            SELECT @c_SQL = 'DECLARE CUR_TRF CURSOR FAST_FORWARD READ_ONLY FOR'
               +' SELECT R.Facility,R.Storerkey, RD.Sku, I.Lot, SUM(RD.QtyReceived) AS Qty,'
               +' RD.UOM, RD.ToLoc, RD.ToID, R.ExternReceiptkey, I.Itrnkey'
               +' FROM RECEIPT R (NOLOCK)'
               +' JOIN RECEIPTDETAIL RD (NOLOCK) ON R.Receiptkey = RD.Receiptkey'
               +' JOIN ITRN I (NOLOCK) ON RD.Storerkey = I.Storerkey AND RD.Sku = I.Sku AND I.TranType = ''DP'''
               +' AND I.SourceKey = R.Receiptkey + RD.ReceiptLineNumber AND LEFT(I.SourceType,10) = ''ntrReceipt'''
               +' WHERE R.Receiptkey = @c_Receiptkey'+ @c_Condition
               +' AND RD.FinalizeFlag = ''Y'''
               +' AND RD.QtyReceived > 0'
               +' GROUP BY R.Facility, R.Storerkey, RD.Sku, I.Lot, RD.UOM, RD.ToLoc, RD.ToID, R.ExternReceiptkey, I.Itrnkey'

            EXEC sp_executesql @c_SQL
            , N'@c_Receiptkey     NVARCHAR(15)'
            , @c_Receiptkey

            SET @c_SQL = ''
            ----(SSA01) end----
            OPEN CUR_TRF
            
            FETCH NEXT FROM CUR_TRF INTO @c_Facility, @c_Storerkey, @c_Sku, @c_Lot, @n_QtyReceived, @c_UOM, @c_Loc, @c_ID, @c_ExternReceiptkey, @c_Itrnkey
            
            WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
            BEGIN      	                       	        	   
            	 SET @c_PALoc = ''
            	 
            	 SELECT TOP 1 @c_PALoc = MV.ToLoc
            	 FROM ITRN DP (NOLOCK)
            	 JOIN ITRN MV (NOLOCK) ON DP.Lot = MV.Lot AND DP.Storerkey = MV.Storerkey AND DP.Sku = MV.Sku AND DP.Qty = MV.Qty
            	                       AND MV.TranType = 'MV' AND DP.ToLoc = MV.FromLoc AND DP.ToID = MV.FromID --AND MV.SourceType = 'rdt_PutawayByID_Confirm'
            	 WHERE DP.Itrnkey = @c_ItrnKey
            	             	             	 
            	 SELECT TOP 1 @c_PALoc = LLI.Loc
            	 FROM LOTXLOCXID LLI (NOLOCK)
            	 WHERE LLI.Lot = @c_Lot
            	 AND LLI.Id = @c_ID
            	 AND LLI.Qty > 0 
            	 ORDER BY CASE WHEN LLI.Loc = @c_PALoc THEN 1 ELSE 2 END,
            	          CASE WHEN LLI.Loc = @c_Loc THEN 1 ELSE 2 END
            	 
            	 IF @c_PALoc <> ''
            	    SET @c_Loc = @c_PALoc
            	           	
            	 SET @b_Success = 0
            	 EXEC ispCreateTransfer
            	    @c_Transferkey = @c_Transferkey OUTPUT,
            	    @c_FromFacility = @c_Facility,
            	    @c_FromLot = @c_Lot,
                  @c_FromLoc = @c_Loc,
                  @c_FromID  = @c_ID,
            	    @n_FromQty = @n_QtyReceived,
            	    @c_ToLottable01 = '',
            	    @c_ToLottable02 = '',
            	    @c_ToLottable03 = '',
            	    @dt_ToLottable04 = NULL,
            	    @dt_ToLottable05 = NULL,
            	    @c_ToLottable06 = '',
            	    @c_ToLottable07 = '',
            	    @c_ToLottable08 = '',
            	    @c_ToLottable09 = '',
            	    @c_ToLottable10 = '',
            	    @c_ToLottable11 = '',
            	    @c_ToLottable12 = '',
            	    @dt_ToLottable13 = NULL,
            	    @dt_ToLottable14 = NULL,
            	    @dt_ToLottable15 = NULL,
            	    @c_CopyLottable = 'Y',
            	    @c_Finalize = 'N',
            	    @c_Type = 'AD',
            	    @c_ReasonCode = 'SSC',
            	    @c_CustomerRefNo = '',
            	    @b_Success = @b_Success OUTPUT,
            	    @n_Err = @n_Err OUTPUT,
            	    @c_ErrMsg = @c_ErrMsg OUTPUT
            
   	           IF  @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
   	              SELECT @c_errmsg = RTRIM(@c_Errmsg) +  ' (ispREC10)'
               END
            
               FETCH NEXT FROM CUR_TRF INTO @c_Facility, @c_Storerkey, @c_Sku, @c_Lot, @n_QtyReceived, @c_UOM, @c_Loc, @c_ID, @c_ExternReceiptkey, @c_Itrnkey
            END
   	        CLOSE CUR_TRF
   	        DEALLOCATE CUR_TRF
        
            IF ISNULL(@c_Transferkey,'') <> '' AND @n_continue IN(1,2)
            BEGIN   
            	 --This is a dummy transfer records for interface triggering purpose and will not perform the real transfer after close, hence no ITRN records will be generated.

            	 --Trigger interface            	             	                       	 
            	 IF EXISTS(SELECT 1
            	           FROM ITFTriggerConfig ITC (NOLOCK) 
            	           WHERE ITC.Storerkey = @c_Storerkey
            	           AND ITC.Svalue = '1'
            	           AND ITC.SourceTable = 'RECEIPT'
            	           AND ITC.UpdatedColumns = 'ASNStatus'
            	           --AND ITC.TableName = 'RCPTLOG'
            	           AND ITC.RecordStatus = '9')
            	 BEGIN            	            	    
            	    EXECUTE dbo.isp_ITF_ntrReceipt
                     @c_TriggerName    = 'ntrReceiptHeaderUpdate'
                    ,@c_SourceTable    = 'RECEIPT'  
                    ,@c_ReceiptKey     = @c_ReceiptKey  
                    ,@c_ColumnsUpdated = 'ASNStatus'        
                    ,@b_Success        = @b_Success   OUTPUT  
                    ,@n_err            = @n_err       OUTPUT  
                    ,@c_errmsg         = @c_errmsg    OUTPUT  
                  
                  /*
                  IF @b_Success <> 1
                  BEGIN
                     SELECT @n_continue = 3
                  END
                  */
            	 END            	 
                        	    	                                       
            	 --Update custom data to transfer                                    
            	 UPDATE TRANSFER WITH (ROWLOCK)
            	 SET Userdefine01 = @c_ExternReceiptkey,
            	     Userdefine02 = @c_Receiptkey,
            	     Trafficcop = NULL
            	     --OpenQty = 0
            	 WHERE Transferkey = @c_Transferkey 
            	             
            	 --Custom field update and close the transer
            	 DECLARE CUR_TRFDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            	    SELECT TRF.TransferLineNumber
            	    FROM TRANSFERDETAIL TRF (NOLOCK)
            	    WHERE TRF.Transferkey = @c_Transferkey
            	    ORDER BY TRF.TransferLineNumber

               OPEN CUR_TRFDET
               
               FETCH NEXT FROM CUR_TRFDET INTO @c_TransferLineNumber
               
               WHILE @@FETCH_STATUS <> -1  AND @n_continue IN(1,2)
               BEGIN
                  ----(SSA01) start---

                  SELECT @c_SQL = 'UPDATE TRANSFERDETAIL WITH (ROWLOCK)'
                            +' SET Lottable01 = ''A'''
                            +',Lottable02 = IIF(@c_Type = ''NORMAL'',''GOOD'',''RETURN'')'
                            +',Status = ''9'''
                            +',Userdefine01 = CASE WHEN RDET.ReceiptLineNumber IS NOT NULL THEN RDET.ReceiptLineNumber ELSE Userdefine01 END'      --(SSA03)
                            +' FROM TRANSFERDETAIL'
                            +' OUTER APPLY (SELECT TOP 1 RD.ReceiptLineNumber'
                            +' FROM RECEIPTDETAIL RD (NOLOCK)'
                            +' WHERE RD.Receiptkey = '+ @c_Receiptkey               --(SSA04)
                            +' AND RD.Sku = TRANSFERDETAIL.FromSku'
                            +' AND RD.ToID = TRANSFERDETAIL.FromID'
                            + @c_Condition
                            +' ORDER BY RD.ReceiptLineNumber) RDET'
                            +' WHERE TRANSFERDETAIL.Transferkey = '+@c_Transferkey                  --(SSA04)
                            +' AND TRANSFERDETAIL.TransferLineNumber = '+@c_TransferLineNumber      --(SSA04)

                EXEC sp_executesql @c_SQL
                , N'@c_Type            NVARCHAR(20)'                       --(SSA02)
                , @c_Type                                                  --(SSA02)

                SET @c_SQL = ''

                  ----(SSA01) end---
                  SET @n_err = @@ERROR
                  
                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3
                     SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63100
                     SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update TRANSFERDETAIL of Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (ispREC10)' + ' ( '
                                            + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
                  END
   
                  FETCH NEXT FROM CUR_TRFDET INTO @c_TransferLineNumber
               END   
               CLOSE CUR_TRFDET
               DEALLOCATE CUR_TRFDET
            END
               /*
               EXEC ispFinalizeTransfer @c_Transferkey, @b_Success OUTPUT, @n_err OUTPUT, @c_errmsg OUTPUT
            
               IF @b_Success <> 1
               BEGIN
                  SELECT @n_continue = 3
                  SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63110
                  SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Finalize Transfer# ' + RTRIM(@c_Transferkey) + ' Failed! (ispREC10)' + ' ( '
                                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '
               END
               */
            NEXT_ASN:
            FETCH NEXT FROM CUR_REC INTO @c_Receiptkey, @c_type, @c_Facility, @c_Storerkey
         END   
         CLOSE CUR_REC
         DEALLOCATE CUR_REC
   END
            
   QUIT_SP:

   IF CURSOR_STATUS('LOCAL', 'CUR_REC') IN ( 0, 1 )
   BEGIN
      CLOSE CUR_REC
      DEALLOCATE CUR_REC
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
      EXECUTE dbo.nsp_logerror @n_Err, @c_ErrMsg, 'ispREC10'
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