SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC18                                            */
/* Creation Date: 17-MAY-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-17011- [CN] LACOSTE_PreFinalizeReceiptSP                    */                               
/*        : Before finalize ASN                                            */
/*                                                                         */
/* Called By:                                                              */
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
/* 20-Dec-2021  CSCHONG 1.1   Devops Scripts Combine                       */
/* 20-Dec-2021  CSCHONG 1.2   WMS-18522 - revised logic (CS01)             */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC18]  
(     @c_Receiptkey  NVARCHAR(10)  
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''      
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTranCount     INT         
         , @c_ToID               NVARCHAR(18)
         , @c_Storerkey          NVARCHAR(15)
         , @c_ReceiptGroup       NVARCHAR(20)
         , @c_RecType            NVARCHAR(10) = N''
         , @c_UserDefine03       NVARCHAR(30) = N''
         , @c_Style              NVARCHAR(20) = N''
         , @c_Color              NVARCHAR(10) = N''
         , @c_RDUserDefine02     NVARCHAR(30) = N''    --CS01
         , @n_Count              INT                   --CS01
		   , @n_RALineNo           NVARCHAR(30) = N''    --CS01
   
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   
   IF @n_Continue IN(1,2)
   BEGIN        

      SELECT @c_ReceiptGroup = ReceiptGroup,
             @c_UserDefine03 = UserDefine03,
             @c_RecType = RECType,
             @c_Storerkey = StorerKey  
      FROM  RECEIPT (NOLOCK) WHERE ReceiptKey = @c_ReceiptKey;
      
   IF @c_ReceiptGroup = ''
   BEGIN
      DECLARE CUR_RECDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
          SELECT  rd.ReceiptLineNumber,
                  s.Style,
                  s.Color,
                  rd.UserDefine02                --CS01
         FROM   RECEIPTDETAIL rd (NOLOCK)
         JOIN   SKU s (NOLOCK) ON s.StorerKey = rd.StorerKey
                               AND s.Sku      = rd.Sku
   WHERE ReceiptKey = @c_ReceiptKey
   ORDER BY  rd.ReceiptLineNumber
      
      OPEN CUR_RECDET  
      
      FETCH NEXT FROM CUR_RECDET INTO @c_ReceiptLineNumber, @c_Style, @c_Color,@c_RDUserDefine02    --CS01
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)          
      BEGIN
           --CS01 START
           SET @n_Count = 0
		     SET @n_RALineNo = ''

		  SELECT TOP 1 @n_Count = 1,@n_RALineNo = rd.UserDefine02  --Got is exists and RA file's same style and color's lineno
        FROM  RECEIPT r (NOLOCK)  
        JOIN  RECEIPTDETAIL rd (NOLOCK) ON rd.ReceiptKey = r.ReceiptKey  
        JOIN SKU s (NOLOCK) ON s.StorerKey = rd.StorerKey AND s.Sku = rd.Sku WHERE r.StorerKey = @c_Storerkey  
                           AND r.UserDefine03   = @c_UserDefine03  
                           AND rd.QtyExpected   > 0  
                           AND s.Style          = @c_Style  
                           AND s.Color          = @c_Color
		  ORDER BY rd.UserDefine02 DESC     

          --CS01 END

          IF @c_RecType = 'ASN'
          BEGIN        --CS01 START
   
      --     AND NOT EXISTS (    SELECT      1
      --                         FROM  RECEIPT r (NOLOCK)
      --                         JOIN  RECEIPTDETAIL rd (NOLOCK) ON rd.ReceiptKey = r.ReceiptKey
      --                         JOIN SKU s (NOLOCK) ON s.StorerKey = rd.StorerKey AND s.Sku = rd.Sku
      --                         WHERE r.StorerKey = @c_Storerkey
      --                         AND r.UserDefine03   = @c_UserDefine03
      --                         AND rd.QtyExpected   > 0
      --                         AND s.Style          = @c_Style
      --                         AND s.Color          = @c_Color)
      --BEGIN
      --    UPDATE RECEIPTDETAIL WITH (ROWLOCK)
      --    SET UserDefine03 = 'NONASN', TrafficCop = NULL 
      --    WHERE ReceiptKey = @c_ReceiptKey AND ReceiptLineNumber = @c_ReceiptLineNumber
      --END;
      --ELSE
      --BEGIN
      -- UPDATE RECEIPTDETAIL WITH (ROWLOCK)
      -- SET UserDefine03 = @c_RecType, TrafficCop = NULL 
      -- WHERE ReceiptKey = @c_ReceiptKey AND ReceiptLineNumber = @c_ReceiptLineNumber
      --END
            
      --   SET @n_err = @@ERROR  
         
      --   IF @n_err <> 0   
      --   BEGIN  
      --      SET @n_continue = 3  
      --      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      --      SET @n_err = 82020    
      --      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC18)' 
      --                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      --   END  


            IF (ISNULL(@n_Count,0) = 0)  
            BEGIN  --Style and Color not in RA file 
                  UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
                  SET UserDefine03 = 'NONASN', TrafficCop = NULL   
                  WHERE ReceiptKey = @c_ReceiptKey AND ReceiptLineNumber = @c_ReceiptLineNumber  
             END
	          ELSE 
	          BEGIN
	              IF EXISTS (SELECT      1  
                           FROM  RECEIPT r (NOLOCK)  
                           JOIN  RECEIPTDETAIL rd (NOLOCK) ON rd.ReceiptKey = r.ReceiptKey  
                           JOIN SKU s (NOLOCK) ON s.StorerKey = rd.StorerKey AND s.Sku = rd.Sku                                 
                           WHERE r.StorerKey = @c_Storerkey  
                                 AND r.ReceiptKey   = @c_ReceiptKey  
                                 AND rd.QtyExpected   > 0  
                                 AND s.Style          = @c_Style  
                                 AND s.Color          = @c_Color)  
	               BEGIN  --Style and Color in RA and also in this ASN[SSCC], whatever size
                      UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
                      SET UserDefine03 = 'ASN', TrafficCop = NULL   
                      WHERE ReceiptKey = @c_ReceiptKey AND ReceiptLineNumber = @c_ReceiptLineNumber  
		            END
		            ELSE
                  BEGIN  --Style and Color in RA but not in this ASN[SSCC]
		                UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
                      SET UserDefine03 = 'LOOSE', TrafficCop = NULL   
                      WHERE ReceiptKey = @c_ReceiptKey AND ReceiptLineNumber = @c_ReceiptLineNumber  
		            END
             END
	       END
          ELSE  
          BEGIN  ---For RA
	          UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
              SET UserDefine03 = @c_RecType, TrafficCop = NULL   
              WHERE ReceiptKey = @c_ReceiptKey AND ReceiptLineNumber = @c_ReceiptLineNumber  
          END
		  
		  IF ISNULL(@c_RDUserDefine02,'')=''   --update if lineno is empty, if RA also no lineno, also will update to empty
		  BEGIN
		      UPDATE RECEIPTDETAIL WITH (ROWLOCK)  
              SET UserDefine02 = @n_RALineNo, TrafficCop = NULL   
              WHERE ReceiptKey = @c_ReceiptKey AND ReceiptLineNumber = @c_ReceiptLineNumber  
          END
              
         SET @n_err = @@ERROR    
           
         IF @n_err <> 0     
         BEGIN    
            SET @n_continue = 3    
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)    
            SET @n_err = 82020      
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC18)'   
                         + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '    
         END  --CS01 END 
         
      FETCH NEXT FROM CUR_RECDET INTO @c_ReceiptLineNumber, @c_Style, @c_Color,@c_RDUserDefine02           --CS01
      END            
      CLOSE CUR_RECDET
      DEALLOCATE CUR_RECDET 

   END                                   
 END
    
   QUIT_SP:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCount
         BEGIN
            COMMIT TRAN
         END
      END

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC18'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
   END
END

GO