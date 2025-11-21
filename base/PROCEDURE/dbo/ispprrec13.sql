SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/    
/* Stored Procedure: ispPRREC13                                            */    
/* Creation Date: 10-JUL-2019                                              */    
/* Copyright: LFL                                                          */    
/* Written by:  CSCHONG                                                    */    
/*                                                                         */    
/* Purpose:WMS-9520 - TH-DSG customize RM partial receiving checking       */  
/*                    Tolerance by PO                                      */    
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
/***************************************************************************/      
CREATE PROC [dbo].[ispPRREC13]      
(     @c_Receiptkey         NVARCHAR(10)      
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''          
  ,   @b_Success            INT           OUTPUT    
  ,   @n_Err                INT           OUTPUT    
  ,   @c_ErrMsg             NVARCHAR(255) OUTPUT    
  ,   @b_Debug              INT   = 0     
)      
AS      
BEGIN      
   SET NOCOUNT ON  
   SET ANSI_NULLS ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
   SET ANSI_WARNINGS ON  
      
      
   DECLARE   
           @n_Cnt                INT    
         , @n_Continue           INT     
         , @n_StartTranCount     INT     
  
         , @c_Lottable02         NVARCHAR(18) = ''  
         , @c_SKU                NVARCHAR(20) = ''  
         , @c_Storerkey          NVARCHAR(15) = ''  
         , @c_DataMartServerDB   NVARCHAR(120)  
         , @c_ExternRecKey       NVARCHAR(20)  
         , @c_SUSR5              NVARCHAR(30)   
         , @c_RECPOKEY           NVARCHAR(20)  
         , @n_DMRecQty           INT  
         , @n_TTLDMRecQty        INT  
         , @n_RecQty             INT  
         , @n_TTLRecQty          INT  
         , @n_POORDQTY           INT  
         , @n_QtyOrd             INT  
         , @n_DMQtyOrd           INT  
         , @n_TTLPOORDQTY        INT  
         , @n_AllowPOORDQTY      INT  
         , @n_DMPOORDQTY         INT  
         , @n_OverQTY            INT  
         , @c_Facility           NVARCHAR(10)  
         , @n_B4RecQty           INT  
         , @n_POQTYRCV           INT  
         , @n_PODMQTYRCV         INT  
  
DECLARE    @sqlinsert          NVARCHAR(MAX)  
         , @sqlselect          NVARCHAR(MAX)  
         , @sqlfrom            NVARCHAR(MAX)  
         , @sqlwhere           NVARCHAR(MAX)   
         , @c_Sql              NVARCHAR(MAX)  
   
  
  
   SET @b_Success= 1     
   SET @n_Err    = 0      
   SET @c_ErrMsg = ''    
  -- SET @b_Debug = 0  
   SET @n_Continue = 1      
  
  
   SET @n_DMRecQty       = 1  
   SET @n_TTLDMRecQty    = 0  
   SET @n_RecQty         = 1  
   SET @n_TTLRecQty      = 0  
   SET @n_POORDQTY       = 1  
   SET @n_QtyOrd         = 0  
   SET @n_TTLPOORDQTY    = 0  
   SET @n_DMPOORDQTY     = 0  
   SET @n_OverQTY        = 0  
   SET @n_AllowPOORDQTY  = 1  
   SET @n_PODMQTYRCV     = 0  
   SET @n_POQTYRCV       = 0  
  
   SET @n_StartTranCount = @@TRANCOUNT      
  
  
   SELECT @c_DataMartServerDB = ISNULL(NSQLDescrip,'')   
   FROM NSQLCONFIG (NOLOCK)       
   WHERE ConfigKey='DataMartServerDBName'    
  
    IF ISNULL(@c_DataMartServerDB,'') = ''  
    SET @c_DataMartServerDB = 'DATAMART'  
       
  
    IF RIGHT(RTRIM(@c_DataMartServerDB),1) <> '.'   
    BEGIN  
      SET @c_DataMartServerDB = RTRIM(@c_DataMartServerDB) + '.'    
    END   
  
   SET @c_RECPOKEY = ''  
  
   SELECT @c_RECPOKEY = REC.pokey  
   FROM RECEIPT REC WITH (NOLOCK)  
   WHERE REC.ReceiptKey = @c_Receiptkey  
  
   DECLARE CUR_RD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT RD.ReceiptLineNumber, RD.SKU, RD.Storerkey,  
          RH.ExternReceiptKey,RD.Beforereceivedqty,RH.facility  
   FROM RECEIPTDETAIL RD (NOLOCK) --WL01  
   JOIN RECEIPT RH (NOLOCK) ON RH.RECEIPTKEY = RD.RECEIPTKEY AND RH.STORERKEY = RD.STORERKEY  
   WHERE RD.RECEIPTKEY = @c_Receiptkey   
   AND   RD.ReceiptLineNumber = CASE WHEN ISNULL(RTRIM(@c_ReceiptLineNumber),'') = '' THEN RD.ReceiptLineNumber ELSE @c_ReceiptLineNumber END    
  -- AND RH.Status='9'  
  
   OPEN CUR_RD    
    
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @c_SKU, @c_Storerkey , @c_ExternRecKey,@n_RecQty,@c_Facility  
                             
   WHILE @@FETCH_STATUS <> -1     
   BEGIN  
  
   IF @c_Facility <> '18100'  
   BEGIN  
     GOTO QUIT_SP  
   END  
  
  
      SET @c_SUSR5 = '0'  
      SET @n_DMRecQty       = 0  
      SET @n_POORDQTY = 0  
      SET @n_QtyOrd = 0  
      SET @n_TTLRecQty = 0  
      SET @n_DMQtyord = 0  
      SET @n_B4RecQty = 0  
      --SET @c_TTLDMRecQty    = 0  
     
      SELECT @c_SUSR5 = S.SUSR5  
      FROM SKU S WITH (NOLOCK)  
      WHERE S.SKU = @c_SKU AND S.Storerkey = @c_Storerkey   
  
      IF ISNUMERIC(@c_SUSR5) <> 1 OR @c_SUSR5 = '0'  
      BEGIN  
        SET @c_SUSR5 = '1'  
      END  
  
   --SELECT @n_POORDQTY = PODET.QtyOrdered  
   --FROM PODETAIL PODET WITH (NOLOCK)  
   --WHERE PODET.ExternPOKey = @c_RECPOKEY  
  
   SELECT @n_B4RecQty = SUM(RD.Beforereceivedqty)  
   FROM RECEIPTDETAIL RD WITH (NOLOCK)  
   WHERE RD.Receiptkey = @c_Receiptkey --in (select receiptkey FROM RECEIPT R WITH (NOLOCK) where R.pokey =@c_RECPOKEY and r.storerkey = @c_Storerkey)    
   AND RD.SKU = @c_SKU AND RD.Storerkey =@c_Storerkey  
  
  
  -- SET @n_QtyOrd = (@n_POORDQTY*CAST(@c_SUSR5 as int)/100)  
  
  
    SET @sqlselect =  N'SELECT @n_DMPOORDQTY = sum(PODET.QtyOrdered), @n_PODMQTYRCV = sum(PODET.qtyreceived)'  
    SET @sqlfrom =  N' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.PODETAIL PODET WITH (NOLOCK) '   
                   + ' WHERE PODET.ExternPOKey = @c_RECPOKEY  '  
                   + ' AND PODET.SKU=@c_SKU AND PODET.Storerkey = @c_Storerkey  '  
  
    
     SET @c_sql = @sqlselect + CHAR(13) + @sqlfrom --+ CHAR(13) + @sqlwhere    
       
   EXEC sp_executesql @c_sql,                                   
                    N' @c_ExternRecKey NVARCHAR(20),@c_SKU NVARCHAR(20),@c_storerKey NVARCHAR(20),@c_RECPOKEY NVARCHAR(30),@n_DMPOORDQTY INT OUTPUT,@n_PODMQTYRCV INT OUTPUT',   
                     @c_ExternRecKey,@c_SKU,@c_storerKey,@c_RECPOKEY,@n_DMPOORDQTY OUTPUT,@n_PODMQTYRCV OUTPUT   
        IF ISNULL(@n_DMPOORDQTY,'') = ''  
        BEGIN  
          SET @n_DMPOORDQTY = 0  
        END  
  
        IF ISNULL(@n_PODMQTYRCV,'') = ''  
        BEGIN  
          SET @n_PODMQTYRCV = 0  
        END  
     
        --SET @n_DMQtyord = (@n_DMPOORDQTY*CAST(@c_SUSR5 as int)/100)  
  
        IF @b_Debug = '1'  
        BEGIN  
           SELECT 'PO DM'  
           SELECT @c_sql  
           SELECT @n_POORDQTY '@n_POORDQTY' ,@c_SUSR5 '@c_SUSR5', @n_DMPOORDQTY '@n_DMPOORDQTY',@n_DMQtyord '@n_DMQtyord'  
                 ,@n_QtyOrd '@n_QtyOrd',@n_B4RecQty '@n_B4RecQty',@n_PODMQTYRCV '@n_PODMQTYRCV'  
        END  
         
  
  -- SET @sqlselect =  N'SELECT @n_DMRecQty = sum(rd.Beforereceivedqty)'  
  --    SET @sqlfrom =  N' FROM ' + RTRIM(@c_DataMartServerDB) + 'ods.RECEIPTDETAIL RD WITH (NOLOCK) '   
  --                 --+ ' WHERE RD.Receiptkey = @c_Receiptkey  '  
  --       + ' WHERE RD.RECEIPTKEY IN (select receiptkey FROM RECEIPT R WITH (NOLOCK) '  
  --    + '                         where R.pokey =@c_RECPOKEY and r.storerkey = @c_Storerkey) '  
  --             + ' AND RD.SKU=@c_SKU AND RD.Storerkey =@c_Storerkey  '  
  
    
  --SET @c_sql = @sqlselect + CHAR(13) + @sqlfrom --+ CHAR(13) + @sqlwhere    
  -- --print @c_sql       
  -- EXEC sp_executesql @c_sql,                                   
  --                  N' @c_RECPOKEY NVARCHAR(20),@c_SKU NVARCHAR(20),@c_storerKey NVARCHAR(20),@n_DMRecQty INT OUTPUT',   
  --                   @c_RECPOKEY,@c_SKU,@c_storerKey,@n_DMRecQty OUTPUT   
      
  
  ----      SET @n_TTLDMRecQty = @n_TTLDMRecQty +  @n_DMRecQty  
  
  --      IF ISNULL(@n_DMRecQty,'') = ''  
  --BEGIN  
  --  SET @n_DMRecQty = 0  
  --END  
  
         IF @b_Debug = '1'  
         BEGIN  
            SELECT 'Receipt DM',@c_ExternRecKey 'c_ExternRecKey',@c_SKU '@c_SKU',@c_storerKey '@c_storerKey'  
            SELECT @c_sql  
            SELECT @n_RecQty '@n_RecQty',@n_DMRecQty '@n_DMRecQty'  
         END  
  
    
  
   SET @n_TTLRecQty = @n_B4RecQty --+ @n_DMRecQty  
   SET @n_AllowPOORDQTY = (@n_DMPOORDQTY*CAST(@c_SUSR5 as int))/100  
   SET @n_TTLPOORDQTY =  (@n_DMPOORDQTY + @n_AllowPOORDQTY) - @n_PODMQTYRCV --@n_QtyOrd + @n_DMQtyord  
   SET @n_OverQTY = @n_TTLRecQty - @n_TTLPOORDQTY  
  
   IF @b_Debug = '1'  
   BEGIN  
     SELECT (@n_POORDQTY + @n_DMPOORDQTY) 'PODQTY',CAST(@c_SUSR5 as int) 'susr5'  
     SELECT @n_TTLRecQty '@n_TTLRecQty',@n_TTLPOORDQTY '@n_TTLPOORDQTY',@n_OverQTY '@n_OverQTY'  
   END  
  
        IF @n_TTLRecQty > @n_TTLPOORDQTY    
        BEGIN      
         SET @n_continue = 3     
         SET @n_err = 82005   
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)      
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': SKU : '+ @c_SKU + ' OVER receiving qty ' + CONVERT(NVARCHAR(10),@n_OverQTY) +   
                     ', Total Received Qty ' + CONVERT(NVARCHAR(10),@n_TTLPOORDQTY) + ' (ispPRREC13)'       
         GOTO QUIT_SP    
       END   
      
   SET @c_SUSR5 = '0'  
   SET @n_DMRecQty       = 0  
   SET @n_POORDQTY = 0  
   SET @n_QtyOrd = 0  
   SET @n_TTLRecQty = 0  
   SET @n_DMQtyord = 0  
   SET @n_B4RecQty = 0    
      
   FETCH NEXT FROM CUR_RD INTO @c_ReceiptLineNumber, @c_SKU, @c_Storerkey , @c_ExternRecKey,@n_RecQty , @c_facility  
   END    
   CLOSE CUR_RD    
   DEALLOCATE CUR_RD    
  
    
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
    
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'ispPRREC13'    
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