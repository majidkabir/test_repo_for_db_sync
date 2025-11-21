SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Stored Procedure: ispTRCHK01                                         */  
/* Creation Date: 06-FEB-2015                                           */  
/* Copyright: LF                                                        */  
/* Written by:                                                          */  
/*                                                                      */  
/* Purpose: 331748-CN-H&M-InterfaceLog CR for Transfer Update           */  
/*                                                                      */  
/* Called By: Finalize Transfer                                         */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author  Ver  Purposes                                   */  
/* 02-Feb-2015  YTWan   1.1   SOS#315474 - Project Merlion - Exceed GTM */  
/*                            Kiosk Module (Wan01)                      */  
/************************************************************************/  
  
CREATE PROCEDURE [dbo].[ispTRCHK01]  
   @c_TransferKey      NVARCHAR(10),  
   @b_Success          INT = 1  OUTPUT,  
   @n_Err              INT = 0  OUTPUT,  
   @c_Errmsg           NVARCHAR(250) = '' OUTPUT  
,  @c_TransferLineNumber NVARCHAR(5) = '' --(Wan01)   
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
     
   DECLARE @n_StartTranCount INT,  
           @n_Continue INT  
   
   DECLARE @c_Storerkey NVARCHAR(15),  
--           @c_TransferLineNumber NVARCHAR(5), --(Wan01)  
           @c_TransferLineNoFound NVARCHAR(5),  
           @c_SKU NVARCHAR(20),  
           @n_FromQty INT,  
           @c_Lot NVARCHAR(10),  
           @c_Interfacekey NVARCHAR(10),  
           @n_Qty INT,  
           @n_UpdatedQty INT  
     
   SELECT @b_Success = 1, @n_Err = 0, @c_Errmsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT    
     
   SET @c_TransferLineNoFound = ''  
     
   SELECT TOP 1 @c_TransferLineNoFound = TD.TransferLineNumber            
   FROM TRANSFER T (NOLOCK)  
   JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey  
   LEFT JOIN INTERFACELOG I (NOLOCK) ON TD.fromStorerkey = I.Storerkey AND TD.FromSku = I.Sku AND TD.FromLot = I.TranCode    
                                     AND I.Status = 0 AND I.Qty > 0  
   WHERE TD.Lottable03 = 'RET'  
   AND TD.ToLottable03 <> 'RET'  
   AND T.Transferkey = @c_Transferkey  
   AND T.Status <> '9'  
   AND TD.FromQty - CASE WHEN ISNUMERIC(TD.Userdefine01) = 0 THEN 0  
                    ELSE CAST(TD.Userdefine01 AS INT) END > 0  
   GROUP BY TD.TransferLineNumber, TD.Userdefine01, TD.FromQty  
   HAVING TD.FromQty - CASE WHEN ISNUMERIC(TD.Userdefine01) = 0 THEN 0  
                    ELSE CAST(TD.Userdefine01 AS INT) END > SUM(ISNULL(I.Qty,0))  
   ORDER BY TD.TransferLineNumber  
     
   IF ISNULL(@c_TransferLineNoFound,'') <> ''  
   BEGIN    
      SET @n_continue = 3    
      SET @n_err = 68004    
      SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))     
              + ': Transfer Line:' + RTRIM(@c_TransferLineNoFound) + ' Insufficient Qty found in Intrfacelog. (ispTRCHK01) '     
              + '( sqlsvr message=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
      GOTO EXIT_SP    
   END    
  
   DECLARE TRF_CUR CURSOR FAST_FORWARD READ_ONLY FOR  
      SELECT TD.FromStorerkey, TD.TransferLineNumber,   
            TD.FromSku,   
     TD.FromQty - CASE WHEN ISNUMERIC(TD.Userdefine01) = 0 THEN 0  
                      ELSE CAST(TD.Userdefine01 AS INT) END AS FromQty,  
            TD.FromLot  
      FROM TRANSFER T (NOLOCK)  
      JOIN TRANSFERDETAIL TD (NOLOCK) ON T.Transferkey = TD.Transferkey  
      WHERE TD.Lottable03 = 'RET'  
      AND TD.ToLottable03 <> 'RET'  
      AND T.Transferkey = @c_Transferkey  
      AND T.Status <> '9'  
      AND TD.FromQty - CASE WHEN ISNUMERIC(TD.Userdefine01) = 0 THEN 0  
                      ELSE CAST(TD.Userdefine01 AS INT) END > 0  
      ORDER BY TD.TransferLineNumber  
  
   OPEN TRF_CUR  
  
    FETCH NEXT FROM TRF_CUR INTO @c_Storerkey, @c_TransferLineNumber, @c_Sku, @n_FromQty, @c_Lot  
  
    WHILE @@FETCH_STATUS <> -1  
    BEGIN  
        
        SET @n_UpdatedQty = 0  
        WHILE @n_FromQty > 0  
        BEGIN          
          SET @c_Interfacekey = ''  
          SET @n_Qty = 0  
            
          SELECT TOP 1 @c_Interfacekey = Interfacekey,   
                        @n_Qty = Qty           
          FROM INTERFACELOG(NOLOCK)  
          WHERE Storerkey = @c_Storerkey  
          AND Sku = @c_Sku  
          AND Trancode = @c_Lot   
          AND Status = '0'  
          AND Qty > 0  
          AND TableName = 'HMRTN'  
          ORDER BY Interfacekey  
            
          IF ISNULL(@c_Interfacekey,'') <> ''  
          BEGIN              
              IF @n_Qty <= @n_FromQty  
              BEGIN  
                 SELECT @n_FromQty = @n_FromQty - @n_Qty              
              END  
              ELSE  
              BEGIN  
                 SELECT @n_Qty = @n_FromQty  
                 SELECT @n_FromQty = 0              
              END  
                            
              SELECT @n_UpdatedQty = @n_UpdatedQty + @n_Qty  
                
              UPDATE INTERFACELOG WITH (ROWLOCK)  
              SET Qty = QTY - @n_Qty,   
                  Userdefine03  = @c_Transferkey,  
                  Userdefine04 = @c_TransferLineNumber,  
                  Status = '9'  
              WHERE Interfacekey = @c_Interfacekey              
                
              SELECT @n_err = @@ERROR  
            IF @n_err <> 0  
            BEGIN    
               SET @n_continue = 3    
               SET @n_err = 68005    
               SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))     
                       + ': Update Intrfacelog Failed. (ispTRCHK01) '     
                       + '( sqlsvr message=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
               GOTO EXIT_SP    
            END    
          END  
          ELSE  
          BEGIN  
              BREAK  
          END                            
        END  
          
        UPDATE TRANSFERDETAIL WITH (ROWLOCK)  
     SET Userdefine01 = CASE WHEN ISNUMERIC(Userdefine01) = 0 THEN  
                             CAST(@n_UpdatedQty AS NVARCHAR)  
                        ELSE CAST(CAST(Userdefine01 AS INT) +  @n_UpdatedQty AS NVARCHAR) END  
      WHERE Transferkey = @c_Transferkey  
      AND TransferLineNumber = @c_TransferLineNumber                            
  
      SELECT @n_err = @@ERROR  
      IF @n_err <> 0  
      BEGIN    
         SET @n_continue = 3    
         SET @n_err = 68006    
         SET @c_errmsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_err,0))     
                 + ': Update Transferdetail Failed. (ispTRCHK01) '     
                 + '( sqlsvr message=' + ISNULL(LTRIM(RTRIM(@c_errmsg)),'') + ' ) '    
         GOTO EXIT_SP    
      END    
  
       FETCH NEXT FROM TRF_CUR INTO @c_Storerkey, @c_TransferLineNumber, @c_Sku, @n_FromQty, @c_Lot  
        
   END  
   CLOSE TRF_CUR  
   DEALLOCATE TRF_CUR  
     
   EXIT_SP:    
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispTRCHK01'  
      --RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
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