SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/  
/* Stored Procedure: ispASNFZ02                                            */  
/* Creation Date: 27-JUN-2014                                              */  
/* Copyright: IDS                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: SOS#314477-Stamp Receiptdetail.Userefine02 to UCC.Userdefined02*/  
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
/* 10-Nov-2020  TLTING01 1.1  performance tune                             */   
/* 04-Feb-2021  WLChooi  1.2  WMS-16315 - Add Receiptdetail.Channel into   */
/*                            Codelkup if not exists for CN (WL01)         */
/***************************************************************************/  
  
CREATE PROC [dbo].[ispASNFZ02]  
(     @c_Receiptkey  NVARCHAR(10)  
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT  
  ,   @c_ReceiptLineNumber NVARCHAR(5)=''  
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue INT,  
           @n_StartTranCount INT,  
           @n_LineNo INT
   
   --WL01 S        
   DECLARE @c_Country     NVARCHAR(10),
           @c_Channel     NVARCHAR(20),
           @c_Storerkey   NVARCHAR(15),              
           @c_Listname    NVARCHAR(20)  = 'Channel',  
           @c_Description NVARCHAR(250) = 'consignee info'
         
   SELECT @c_Country = N.NSQLValue
   FROM NSQLCONFIG N (NOLOCK)
   WHERE N.ConfigKey = 'Country'
   --WL01 E
           
  
   SELECT @b_Success=1, @n_Err=0, @c_ErrMsg='', @n_Continue = 1, @n_StartTranCount=@@TRANCOUNT  
  
   SELECT DISTINCT ISNULL(UCC.UCCNo, UCCPO.UCCNo) AS UCCNO,  
          CASE WHEN ISNULL(UCC.UCCNo,'') <> '' THEN 'ASN' ELSE 'PO' END AS SourceType,  
          CASE WHEN ISNULL(UCC.UCCNo,'') <> '' THEN RECEIPTDETAIL.ReceiptKey+RECEIPTDETAIL.ReceiptLineNumber ELSE  
               PODETAIL.POKey + PODETAIL.PoLinenUmber END AS Sourcekey,  
          RECEIPTDETAIL.Storerkey,  
          RECEIPTDETAIL.Sku,  
          RECEIPTDETAIL.Userdefine02  
   INTO #TMP_UCC  
   FROM RECEIPT WITH (NOLOCK)  
   JOIN RECEIPTDETAIL WITH (NOLOCK) ON ( RECEIPT.ReceiptKey = RECEIPTDETAIL.ReceiptKey )  
   LEFT JOIN UCC      WITH (NOLOCK) ON -- TLTING01 ( RECEIPTDETAIL.ReceiptKey = SUBSTRING(UCC.SourceKey,1,10) AND UCC.Sourcetype = 'ASN' )  
                                    ( UCC.SourceKey = RECEIPTDETAIL.ReceiptKey + RECEIPTDETAIL.ReceiptLineNumber  AND UCC.Sourcetype = 'ASN' )  
                                                                  
   LEFT JOIN PODETAIL WITH (NOLOCK) ON ( RECEIPTDETAIL.POKEy = PODETAIL.POKey )  
                                    AND( RECEIPTDETAIL.ExternLineNo = PODETAIL.PoLinenUmber)  
   LEFT JOIN UCC  UCCPO WITH (NOLOCK) ON ( PODETAIL.ExternPOKEy = UCCPO.ExternKey )  
                                    AND( UCCPO.Sourcekey = PODETAIL.POKey + PODETAIL.PoLinenUmber)  
                                    AND( UCCPO.Sourcetype = 'PO')  
   WHERE RECEIPT.Receiptkey = @c_Receiptkey  
   AND RECEIPTDETAIL.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RECEIPTDETAIL.ReceiptLineNumber END  
  
   UPDATE UCC WITH (ROWLOCK)  
   SET UCC.Userdefined02 = T.Userdefine02  
   FROM UCC  
   JOIN #TMP_UCC T ON UCC.UCCNo = T.UCCNo AND UCC.Sourcetype = T.SourceType AND UCC.SourceKey = T.Sourcekey  
                      AND UCC.Storerkey = T.Storerkey AND UCC.Sku = T.Sku  
   AND ISNULL(T.UCCNo,'') <> ''  
  
   SELECT @n_err = @@ERROR  
   IF  @n_err <> 0  
   BEGIN  
      SELECT @n_continue = 3  
      SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63504  
      SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update UCC Failed! (ispASNFZ02)' + ' ( '  
                             + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      GOTO QUIT_SP  
   END  
   
   --WL01 S
   IF @n_continue IN (1,2) AND @c_Country = 'CN'
   BEGIN
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT RD.Channel, RD.StorerKey
         FROM RECEIPTDETAIL RD (NOLOCK)
         LEFT JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'Channel' AND CL.Code = RD.Channel AND CL.StorerKey = RD.StorerKey
         WHERE RD.ReceiptKey = @c_Receiptkey  
         AND RD.ReceiptLineNumber = CASE WHEN ISNULL(@c_ReceiptLineNumber,'') <> '' THEN @c_ReceiptLineNumber ELSE RD.ReceiptLineNumber END  
         AND RD.Channel IS NOT NULL AND RD.Channel <> ''
         AND CL.Code IS NULL
         
      OPEN CUR_LOOP
      	
      FETCH NEXT FROM CUR_LOOP INTO @c_Channel, @c_Storerkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	INSERT INTO CODELKUP (LISTNAME, Code, [Description], Storerkey)
      	SELECT @c_Listname, @c_Channel, @c_Description, @c_Storerkey
      	
      	SELECT @n_err = @@ERROR  
      	
         IF @n_err <> 0  
         BEGIN  
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63505  
            SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Insert CODELKUP Failed! (ispASNFZ02)' + ' ( '  
                                   + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
            GOTO QUIT_SP  
         END  
      	
         FETCH NEXT FROM CUR_LOOP INTO @c_Channel, @c_Storerkey
      END
   END
   --WL01 E
  
QUIT_SP:  
   --WL01 S
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END
   --WL01 E
   
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispASNFZ02'  
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