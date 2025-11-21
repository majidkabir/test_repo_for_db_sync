SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPOTFR01                                            */
/* Creation Date: 11-APR-2014                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#304838 - ANF - Allocation strategy for Transfer            */                               
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
/* 02-Feb-2015  YTWan   1.1   SOS#315474 - Project Merlion - Exceed GTM    */
/*                            Kiosk Module (Wan01)                         */
/***************************************************************************/  
CREATE PROC [dbo].[ispPOTFR01]  
(     @c_Transferkey  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
  ,   @c_TransferLineNumber   NVARCHAR(5) = ''  --(Wan01)   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @b_Debug              INT
         , @n_Cnt                INT
         , @n_Continue           INT 
         , @n_StartTCount        INT 

   DECLARE @c_IMLStatus          NVARCHAR(10)
--         , @c_TransferLineNumber NVARCHAR(5)  --(Wan01) 

         , @c_Type               NVARCHAR(12)
         , @c_CustomerRefNo      NVARCHAR(10)
         , @c_ToFacility         NVARCHAR(5)
         , @c_FromStorerkey      NVARCHAR(15)
         , @c_ToStorerkey        NVARCHAR(15)
         , @c_ToSku              NVARCHAR(15)
         , @c_ToLot              NVARCHAR(10)
         , @c_ToLoc              NVARCHAR(10)
         , @c_ToID               NVARCHAR(18)
         , @c_ToPackkey          NVARCHAR(10)
         , @c_ToUOM              NVARCHAR(10)
         , @c_ToLottable01       NVARCHAR(18)
         , @c_ToLottable02       NVARCHAR(18)
         , @c_ToLottable03       NVARCHAR(18)
         , @c_ToLottable04       DATETIME
         , @c_ToLottable05       DATETIME
         , @n_ToQty              INT
         
         , @n_KitLineNumber      INT
         , @c_KitKey             NVARCHAR(10)
         , @c_KitLineNumber      NVARCHAR(5)
         , @c_ComponentSku       NVARCHAR(20)
         , @c_Packkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_KitLoc             NVARCHAR(10)
         , @n_KitQty             INT   

         , @c_ModuleName         NVARCHAR(30)
         , @c_AlertMessage       NVARCHAR(255)

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCount = @@TRANCOUNT  
     
   SET @n_Cnt = 0
   SELECT @c_IMLStatus = TransmitFlag
        , @n_Cnt       = 1
   FROM TRANSMITLOG3 TL3 WITH (NOLOCK)
   WHERE TABLENAME = 'ANFTranAdd'
   AND Key1 = @c_TransferKey

   IF @n_Cnt = 0
   BEGIN 
      GOTO QUIT_SP
   END

   IF @c_IMLStatus = 'IGNOR' OR -- NOT DTC transfer type
      @c_IMLStatus = '0'        -- NOT Process Yet
   BEGIN
      GOTO QUIT_SP
   END

   -- FromSku = TOSku
   IF NOT EXISTS( SELECT 1
                  FROM TRANSFERDETAIL WITH (NOLOCK) 
                  WHERE Transferkey = @c_TransferKey
                  GROUP BY Transferkey 
                  HAVING COUNT(DISTINCT ToStorerkey + ToSku) = 1)

   BEGIN 
      GOTO QUIT_SP
   END

   SET @c_CustomerRefNo = ''
   SET @c_Type          = ''
   SELECT @c_ToFacility    = Facility
         ,@c_FromStorerkey = FromStorerkey
         ,@c_ToStorerkey   = ToStorerkey
         ,@c_Type          = ISNULL(RTRIM([Type]),'')
         ,@c_CustomerRefNo = ISNULL(RTRIM(CustomerRefNo),'')
   FROM TRANSFER WITH (NOLOCK)
   WHERE Transferkey = @c_TransferKey

   -- 14-AUG-2013
   SET @c_ToSku = ''
   SELECT TOP 1 @c_ToSku = TFD.FromSku
   FROM TRANSFERDETAIL TFD WITH (NOLOCK)
   JOIN SKU            SKU WITH (NOLOCK) ON (TFD.ToStorerkey = SKU.Storerkey)
                                       AND(TFD.ToSku = SKU.Sku)
   WHERE Transferkey =  @c_TransferKey
   AND   ( FromQty > 0 AND ToQty > 0 )
   AND   SKU.PrePackIndicator IS NOT NULL AND SKU.PrePackIndicator = 'Y'
        
   IF @c_ToSku = ''       
   BEGIN 
      GOTO QUIT_SP
   END  
      
   BEGIN TRAN
   EXECUTE nspg_GetKey  
      'KITTING'   
     , 10   
     , @c_KitKey     OUTPUT   
     , @b_Success    OUTPUT   
     , @n_Err        OUTPUT   
     , @c_ErrMsg     OUTPUT  

   IF @b_Success = 0 
   BEGIN  
      SET @n_Continue = 3 
      SET @n_err=82005  
      SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Getting KitKey Fail. (ispPOTFR01)' 
      GOTO QUIT_SP  
   END  

   INSERT INTO KIT 
      (  KitKey
      ,  Storerkey
      ,  ToStorerkey
      ,  Type
      ,  CustomerRefNo 
      ,  ReasonCode
      ,  ExternKitKey
      ,  Facility
      ,  Remarks              --14-AUG-2014
      )
   VALUES 
      (  @c_KitKey
      ,  @c_FromStorerkey
      ,  @c_ToStorerkey
      ,  @c_Type
      ,  @c_CustomerRefNo
      ,  'PREPACK'
      ,  @c_TransferKey
      ,  @c_ToFacility
      ,  @c_ToSku             --14-AUG-2014
      )

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err=82010   
      SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Insert Into KIT Fail. (ispPOTFR01)'
      GOTO QUIT_SP
   END

   SET @n_KitLineNumber = 0
   SET @c_KitLineNumber = '00000'

   DECLARE CUR_TRFDET CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TransferLineNumber = TFD.TransferLineNumber
         ,ToStorerkey    = TFD.FromStorerkey
         ,ToSku          = TFD.FromSku
         ,ToLot          = TFD.ToLot
         ,ToLoc          = TFD.ToLoc
         ,ToID           = TFD.ToID
         ,ToPackkey      = SKU.Packkey
         ,ToUOM          = PCK.PackUOM3
         ,ToLottable01   = ISNULL(RTRIM(TFD.ToLottable01),'')
         ,ToLottable02   = ISNULL(RTRIM(TFD.ToLottable02),'')
         ,ToLottable02   = ISNULL(RTRIM(TFD.ToLottable03),'')
         ,ToLottable04   = TFD.ToLottable04
         ,ToLottable05   = TFD.ToLottable05
         ,ToQty          = TFD.ToQty 
   FROM TRANSFERDETAIL TFD WITH (NOLOCK)
   JOIN SKU            SKU WITH (NOLOCK) ON (TFD.ToStorerkey = SKU.Storerkey)
                                         AND(TFD.ToSku = SKU.Sku)
   JOIN PACK           PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)
   WHERE TFD.Transferkey = @c_TransferKey
   AND   TFD.FromQty > 0
   AND   SKU.PrePackIndicator IS NOT NULL AND SKU.PrePackIndicator = 'Y' 

   OPEN CUR_TRFDET

   FETCH NEXT FROM CUR_TRFDET INTO  @c_TransferLineNumber  
                                 ,  @c_ToStorerkey     
                                 ,  @c_ToSku           
                                 ,  @c_ToLot  
                                 ,  @c_ToLoc         
                                 ,  @c_ToID            
                                 ,  @c_ToPackkey         
                                 ,  @c_ToUOM         
                                 ,  @c_ToLottable01    
                                 ,  @c_ToLottable02    
                                 ,  @c_ToLottable03    
                                 ,  @c_ToLottable04    
                                 ,  @c_ToLottable05    
                                 ,  @n_ToQty  
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_KitLineNumber = @n_KitLineNumber + 1
      SET @c_KitLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5),@n_KitLineNumber),5)

      SELECT TOP 1 @c_ToLOT = LOT 
      FROM ITRN WITH (NOLOCK)
      WHERE StorerKey = @c_ToStorerKey 
      AND Sku   = @c_ToSku
      AND ToLoc = @c_ToLoc
      AND ToId  = @c_ToID
      AND SourceKey = @c_Transferkey + @c_TransferLineNumber
      AND TranType = 'DP'
      AND SourceType IN ('ntrTransferDetailAdd', 'ntrTransferDetailUpdate')

      SET @c_KitLoc = ''
      SELECT @c_KitLoc = ISNULL(RTRIM(Short),'')
      FROM CODELKUP WITH (NOLOCK)
      WHERE ListName = 'WCSROUTE'
      AND   Code = 'Y'

      INSERT INTO KITDETAIL 
         (  KitKey
         ,  KITLineNumber
         ,  Type
         ,  Storerkey
         ,  Sku
         ,  Packkey
         ,  UOM
         ,  Lot
         ,  Loc
         ,  ID
         ,  ExpectedQty
         ,  Qty
         ,  Lottable01
         ,  Lottable02
         ,  Lottable03
         ,  Lottable04
         ,  Lottable05
         ,  ExternKitKey
         ,  ExternLineNo
         )
      VALUES 
         (  @c_KitKey
         ,  @c_KITLineNumber
         ,  'F'
         ,  @c_ToStorerkey
         ,  @c_ToSku
         ,  @c_ToPackkey
         ,  @c_ToUOM
         ,  @c_ToLot
         ,  @c_KitLoc
         ,  @c_ToID
         ,  @n_ToQty
         ,  @n_ToQty
         ,  @c_ToLottable01
         ,  @c_ToLottable02
         ,  @c_ToLottable03
         ,  @c_ToLottable04
         ,  @c_ToLottable05
         ,  @c_TransferKey
         ,  @c_TransferLineNumber
         )

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err=82015  
         SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Insert Into KITDETAIL Fail. (ispPOTFR01)'
         GOTO QUIT_SP
      END

      DECLARE CUR_BOM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ComponentSku 
            ,Qty
      FROM   BILLOFMATERIAL WITH (NOLOCK)
      WHERE  Storerkey = @c_ToStorerkey 
      AND    Sku       = @c_ToSku
      ORDER BY Sequence

      OPEN CUR_BOM

      FETCH NEXT FROM CUR_BOM INTO  @c_ComponentSku
                                 ,  @n_KitQty


      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_KitQty = @n_KitQty * @n_ToQty
         SET @n_KitLineNumber = @n_KitLineNumber + 1
         SET @c_KitLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5),@n_KitLineNumber),5)

         SET @c_Packkey = ''
         SET @c_UOM     = ''

         SELECT @c_Packkey = PACK.Packkey
               ,@c_UOM     = PACK.PackUOM3
         FROM SKU  WITH (NOLOCK)
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)
         WHERE SKU.Storerkey = @c_ToStorerkey
         AND   SKU.Sku       = @c_ComponentSku

         INSERT INTO KITDETAIL 
            (  KitKey
            ,  KITLineNumber
            ,  Type
            ,  Storerkey
            ,  Sku
            ,  Packkey
            ,  UOM
            ,  Lot
            ,  Loc
            ,  ID
            ,  ExpectedQty
            ,  Qty
            ,  Lottable01
            ,  Lottable02
            ,  Lottable03
            ,  Lottable04
            ,  Lottable05
            ,  ExternKitKey
            ,  ExternLineNo
            )
         VALUES 
            (  @c_KitKey
            ,  @c_KITLineNumber
            ,  'T'
            ,  @c_ToStorerkey
            ,  @c_ComponentSku
            ,  @c_Packkey
            ,  @c_UOM
            ,  ''
            ,  @c_KitLoc
            ,  @c_ToID
            ,  @n_KitQty
            ,  @n_KitQty
            ,  @c_ToLottable01
            ,  @c_ToLottable02
            ,  @c_ToLottable03
            ,  @c_ToLottable04
            ,  @c_ToLottable05
            ,  @c_TransferKey
            ,  @c_TransferLineNumber
            )

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err=82020  
               SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Insert Into KITDETAIL Fail. (ispPOTFR01)'
               GOTO QUIT_SP
            END

         FETCH NEXT FROM CUR_BOM INTO  @c_ComponentSku
                                    ,  @n_KitQty
      END
      CLOSE CUR_BOM
      DEALLOCATE CUR_BOM

      FETCH NEXT FROM CUR_TRFDET INTO  @c_TransferLineNumber  
                                    ,  @c_ToStorerkey     
                                    ,  @c_ToSku           
                                    ,  @c_ToLot  
                                    ,  @c_ToLoc            
                                    ,  @c_ToID            
                                    ,  @c_ToPackkey         
                                    ,  @c_ToUOM         
                                    ,  @c_ToLottable01    
                                    ,  @c_ToLottable02    
                                    ,  @c_ToLottable03    
                                    ,  @c_ToLottable04    
                                    ,  @c_ToLottable05    
                                    ,  @n_ToQty  
   END
   CLOSE CUR_TRFDET
   DEALLOCATE CUR_TRFDET

   SET @c_ModuleName = 'ispPOTFR01'
       
   SET @c_AlertMessage = 'Kitting Created when finalize tranfer. TransferKey : ' + @c_TransferKey

   EXEC nspLogAlert
         @c_modulename       = @c_ModuleName
       , @c_AlertMessage     = @c_AlertMessage
       , @n_Severity         = '5'
       , @b_success          = @b_success    OUTPUT
       , @n_err              = @n_Err        OUTPUT
       , @c_errmsg           = @c_ErrMsg     OUTPUT
       , @c_Activity         = 'Finalize Transfer'
       , @c_Storerkey        = @c_FromStorerkey
       , @c_SKU              = ''
       , @c_UOM              = ''
       , @c_UOMQty           = ''
       , @c_Qty              = 0
       , @c_Lot              = ''
       , @c_Loc              = ''
       , @c_ID               = ''
       , @c_TaskDetailKey    = ''
       , @c_UCCNo            = ''

   QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_BOM') in (0 , 1)
   BEGIN
      CLOSE CUR_BOM
      DEALLOCATE CUR_BOM
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_TRFDET') in (0 , 1)
   BEGIN
      CLOSE CUR_TRFDET
      DEALLOCATE CUR_TRFDET
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCount
         BEGIN
            COMMIT TRAN
         END
      END
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOTFR01'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCount
      BEGIN
         COMMIT TRAN
      END 

      RETURN
   END 
END

GO