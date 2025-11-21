SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
/*************************************************************************/    
/* Stored Procedure: isp_ASNSwapPO                                       */    
/* Creation Date: 29-Oct-2014                                            */    
/* Copyright: LFL                                                        */    
/* Written by: Barnett Lim                                               */    
/*                                                                       */    
/* Purpose: Swap PO                                                      */    
/*                                                                       */    
/* Called By:PB RCM                                                      */    
/*                                                                       */    
/* PVCS Version: 1.0                                                     */    
/*                                                                       */    
/* Version: 7                                                            */    
/*                                                                       */    
/* Data Modifications:                                                   */    
/*                                                                       */    
/* Updates:                                                              */    
/* Date         Author   Ver  Purposes                                   */    
/* 29-Oct-2014  Barnett  1.0  Initial Development                        */    
/* 27-Nov-2014  TKLIM    1.0  Set @b_Success status to reply correctly   */  
/* 27-Nov-2014  TKLIM    1.0  Add BeforeReceivedQty incase not finalize  */ 
/* 12-JAN-2014  Barnett  1.0  Remove Grouping syntax                     */
/*************************************************************************/    
    
CREATE PROC [dbo].[isp_ASNSwapPO]  
      @c_ReceiptKey  NVARCHAR(10), -- ASN  
      @c_NewPOKey    NVARCHAR(18),  
      @b_Success     INT OUTPUT,   
      @n_err         INT OUTPUT,   
      @c_ErrMsg      NVARCHAR(250) OUTPUT   
AS    
BEGIN    
        
   DECLARE  @c_StorerKey      NVARCHAR(15),   
            @c_SKU            NVARCHAR(20),  
            @c_OldPOKey       NVARCHAR(18),   
            @n_continue       INT,  
            @n_QtyReceived    INT,  
            @n_QtyOrdered     INT,  
            @n_StartTranCnt   INT
          
     
   SET @b_Success = 1   --TK01
   SET @n_continue = 1  
   SET @n_StartTranCnt = @@TRANCOUNT  
     
   IF ISNULL(RTRIM(@c_ReceiptKey), '') = ''  
   BEGIN  
      SET @n_continue = 3  
      SET @n_Err = 68001             
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Invalid Receipt No (isp_ASNSwapPO)'  
      GOTO QUIT_SP  
   END  
         
   --IF (SELECT Count(Sku)'SkuCnt' FROM PODETAIL PD WITH (NOLOCK) WHERE PD.POKEY = @c_NewPOKey ) <>   
   --   (SELECT Count(Sku)'SkuCnt' FROM RECEIPTDETAIL WITH (NOLOCK) WHERE RECEIPTKEY = @c_ReceiptKey HAVING SUM(QtyReceived + BeforeReceivedQty)>0)  --TK01
   
   IF (SELECT Count(Sku)'SkuCnt' FROM PODETAIL PD WITH (NOLOCK) WHERE PD.POKEY = @c_NewPOKey ) <>   -- Barnett 1.1
      (SELECT Count(Sku)'SkuCnt' FROM RECEIPTDETAIL WITH (NOLOCK) WHERE RECEIPTKEY = @c_ReceiptKey AND (QtyReceived > 0 OR BeforeReceivedQty > 0))  --TK01  -- Barnett 1.1
   BEGIN   
      SET @n_continue = 3  
      SET @n_Err = 68002   
      SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': PO SKU Count not tally with ASN with QtyReceived SKU Count . (isp_ASNSwapPO)'     --TK01
      GOTO QUIT_SP  
   END  
   
   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN

      DECLARE C_List CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
        
      SELECT StorerKey, SKU, POKey, SUM(QtyReceived)        --TK01
      FROM RECEIPTDETAIL WITH (NOLOCK)   
      WHERE RECEIPTKEY = @c_ReceiptKey 
      GROUP BY StorerKey, SKU, POKey  
      HAVING SUM(QtyReceived) > 0      --TK01

    OPEN C_List    
      FETCH NEXT FROM C_List INTO @c_StorerKey, @c_SKU, @c_OldPOKey, @n_QtyReceived   --TK01

      WHILE (@@FETCH_STATUS<>-1)    
      BEGIN  
        
         IF NOT EXISTS( SELECT 1  
                        FROM PODETAIL WITH (NOLOCK)   
                        WHERE POKEY = @c_NewPOKey  
                        AND StorerKey = @c_StorerKey     --TK01
                        AND SKU = @c_SKU  
                        GROUP BY SKU  
                        HAVING SUM(QtyOrdered)>0 AND SUM(QtyOrdered) = @n_QtyReceived   
                       )  

         BEGIN  
             
            SET @n_continue = 3  
            SET @n_Err =  68003   
            SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': PO QtyOrdered and ASN QtyReceived Not Matched.(isp_ASNSwapPO)'     --TK01
            GOTO QUIT_SP  
         END  

      FETCH NEXT FROM C_List INTO @c_StorerKey, @c_SKU, @c_OldPOKey, @n_QtyReceived  --TK01
              
      END -- WHILE 1=1    
      CLOSE C_List   
      DEALLOCATE C_List  
           
   END 

   IF @n_continue = 1 OR @n_continue = 2  
   BEGIN  

      -------------------  
      BEGIN TRANSACTION  
      -------------------     
        
      --First Delete the ASN record which are Zero Received Qty  
      DELETE RECEIPTDETAIL  
      WHERE  RECEIPTKEY = @c_ReceiptKey AND QtyReceived = 0 AND BeforeReceivedQty = 0     --TK01

      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68004   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Delete ASN Zero Received Qty Record  (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END   

      --Update Old PO Header Status to Open
      UPDATE PO
      SET STATUS = 0
      WHERE POKEY = @c_OldPOKey

      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68005   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update Old PO Status  (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END   

      --Update New PO Header Status to Open
      UPDATE PO
      SET STATUS = 9
      WHERE POKEY = @c_NewPOKey


      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68006   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update New PO Status  (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END   


      -- Update Old PO and Set the Quantity Received to ZERO  
      UPDATE PODETAIL WITH (ROWLOCK)  
      SET QtyReceived = 0  
      WHERE POKEY = @c_OldPOKey 
      AND QtyReceived <> 0    --TK01

      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68007   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update PO Detail Record to Zero (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END   


      -- Update New PO and Set the Quantity Received to QtyOrder  
      UPDATE PODETAIL WITH (ROWLOCK)  
      SET QtyReceived = QtyOrdered  
      WHERE POKEY = @c_NewPOKey 

      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68008   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update PO Detail (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END   


        
      -- Swap ASN POKey to New POKey  
      UPDATE ASN WITH (ROWLOCK)
      SET ASN.POKey = @c_NewPOKey
         ,ASN.CarrierKey = PO.SellerName
         ,ASN.CarrierAddress1 = PO.SellerAddress1
         ,ASN.CarrierAddress2 = PO.SellerAddress2
         ,ASN.userdefine01 = PO.userdefine01
         ,ASN.userdefine02 = PO.userdefine02
         ,ASN.userdefine03 = PO.userdefine03
         ,ASN.userdefine04 = PO.userdefine04
         ,ASN.userdefine05 = PO.userdefine05
         ,ASN.userdefine06 = PO.userdefine06
         ,ASN.userdefine07 = PO.userdefine07
         ,ASN.userdefine08 = PO.userdefine08
         ,ASN.userdefine09 = PO.userdefine09
         ,ASN.userdefine10 = PO.userdefine10
         ,ASN.RecType = CASE 
                           WHEN ISNULL(PO.POTYPE,'')<>'' THEN CL.Short
                           ELSE ASN.RecType
                        END
      FROM RECEIPT ASN WITH (ROWLOCK) 
      JOIN PO PO (NOLOCK) ON PO.POKEY = @c_NewPOKey
      LEFT OUTER JOIN CODELKUP CL (NOLOCK) ON CL.ListName = 'PO2ASNTYPE' and CL.CODE = PO.POTYPE
      WHERE ASN.ReceiptKey = @c_ReceiptKey
              
      
      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68009   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update ASN  (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END  
      
      
      UPDATE RD
      SET RD.pokey = PD.pokey
          ,RD.TrafficCop = NULL
      FROM RECEIPTDETAIL RD
      JOIN RECEIPT ASN (NOLOCK) ON ASN.RECEIPTKEY = RD.RECEIPTKEY
      JOIN PODETAIL PD (NOLOCK) ON PD.POKEY = ASN.POKEY AND PD.SKU = RD.SKU
      WHERE  RD.RECEIPTKEY = @c_ReceiptKey 
      
      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68010   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update ASN Detail.POKey (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END  



      UPDATE RD
      SET --RD.storerkey     = PD.storerkey
         --,RD.sku           = PD.sku
         --,RD.packkey       = PD.packkey
         --,RD.altsku        = PD.altsku
         --,RD.uom           = PD.uom
         RD.polinenumber  = PD.polinenumber
         --,RD.lottable01    = PD.lottable01
         --,RD.lottable02    = PD.lottable02
         --,RD.lottable03    = PD.lottable03
         --,RD.lottable04    = PD.lottable04
         --,RD.lottable05    = PD.lottable04
         --,RD.userdefine01  = PD.userdefine01
         --,RD.userdefine02  = PD.userdefine02
         --,RD.userdefine03  = PD.userdefine03
         --,RD.userdefine04  = PD.userdefine04
         --,RD.userdefine05  = PD.userdefine05
         --,RD.userdefine06  = PD.userdefine06
         --,RD.userdefine07  = PD.userdefine07
         --,RD.userdefine08  = PD.userdefine08
         --,RD.userdefine09  = PD.userdefine09
         --,RD.userdefine10  = PD.userdefine10
         ,RD.externpokey   = PD.externpokey
         ,RD.ExternLineNo  = PD.ExternLineNo
         ,RD.QtyExpected   = PD.QtyOrdered
      FROM RECEIPTDETAIL RD
      JOIN RECEIPT ASN (NOLOCK) ON ASN.RECEIPTKEY = RD.RECEIPTKEY
      JOIN PODETAIL PD (NOLOCK) ON PD.POKEY = ASN.POKEY AND PD.SKU = RD.SKU
      WHERE  RD.RECEIPTKEY =  @c_ReceiptKey 
   
      IF @@Error <> 0  
      BEGIN  
         SET @n_continue = 3  
         SET @n_Err =  68011   
         SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update ASN Detail (isp_ASNSwapPO)'  
         GOTO QUIT_SP  
      END  

/*
      SELECT @c_ToLoc =  SValue FROM StorerConfig WITH (NOLOCK) WHERE ConfigKey = 'DefaultRcptLoc' AND StorerKey = @c_StorerKey
      
      IF ISNULL(@c_ToLoc, '') <>''
      BEGIN
            
            --Update ToLoc for each SKU
         UPDATE RECEIPTDETAIL 
         SET ToLoc = @ToLoc
         WHERE  RECEIPTKEY = @c_ReceiptKey

 
      END
      ELSE
      BEGIN

            SELECT @c_ToLoc =  SValue FROM storerConfig WHERE  ConfigKey = 'DefaultLoc' AND StorerKey = @c_StorerKey
            IF ISNULL(@c_ToLoc) <> ''
            BEGIN

               UPDATE RD
               SET RD.ToLoc = SKU.ReceiptLoc
               FROM SKU SKU
               JOIN RECEIPTDETAIL RD (NOLOCK) on RD.SKU = SKU.SKU and RD.ReceiptKey =  @c_ReceiptKey AND RD.StorerKey = SKU.StorerKey
               WHERE StorerKey = @c_StorerKey

               IF @@Error <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err =  68008   
     SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ': Failed to Update Receipt Loc  (isp_ASNSwapPO)'  
                  GOTO QUIT_SP  
               END  

            END
            ELSE
            BEGIN
            
               IF @@Error <> 0  
               BEGIN  
                  SET @n_continue = 3  
                  SET @n_Err =  68009   
                  SET @c_ErrMsg = 'NSQL'+CONVERT(CHAR(5), @n_err) + ':Please setup StorerConfig.DefaultLoc (isp_ASNSwapPO)'  
                  GOTO QUIT_SP  
               END  

            END
      END*/
      --Need to update all the fields just like when Populate from PO
     
   END

   QUIT_SP:  
     
   IF CURSOR_STATUS('LOCAL' , 'C_List') in (0 , 1)  
   BEGIN  
      CLOSE C_List  
      DEALLOCATE C_List  
   END        

   IF @n_continue = 3    
   BEGIN   

      IF @@TRANCOUNT > @n_StartTranCnt    
      ROLLBACK TRANSACTION    
 
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_ASNSwapPO'    
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012    

      SET @b_Success = 0   --TK01
   END    

   -------------------  
   COMMIT TRANSACTION  
   ------------------  
  
END



  

GO