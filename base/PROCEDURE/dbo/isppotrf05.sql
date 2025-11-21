SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPOTRF05                                            */
/* Creation Date: 15-MAR-2021                                              */
/* Copyright: IDS                                                          */
/* Written by: Wan                                                         */
/*                                                                         */
/* Purpose: WMS-16397 - [CN]ANF_Exceed_Transfer_CR                         */                               
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 15-Mar-2021  Wan     1.0   Created.                                     */
/* 27-AUG-2021  Wan01   1.1   Fixed lot for Kittype= 'T', To be empty      */
/***************************************************************************/  
CREATE PROC [dbo].[ispPOTRF05]  
(     @c_Transferkey  NVARCHAR(10)   
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
  ,   @c_TransferLineNumber   NVARCHAR(5) = ''   
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

   DECLARE @c_IMLStatus          NVARCHAR(10) = ''
         , @c_ToLoc_WCS          NVARCHAR(10) = ''
         , @c_Type               NVARCHAR(12) = ''
         , @c_CustomerRefNo      NVARCHAR(10) = ''
         , @c_ToFacility         NVARCHAR(5)  = ''
         , @c_FromStorerkey      NVARCHAR(15) = ''
         , @c_ToStorerkey        NVARCHAR(15) = ''
         , @c_ToSku              NVARCHAR(15) = ''
         , @c_ToLot              NVARCHAR(10) = ''
         , @c_ToLoc              NVARCHAR(10) = ''
         , @c_ToID               NVARCHAR(18) = ''
         , @c_ToPackkey          NVARCHAR(10) = ''
         , @c_ToUOM              NVARCHAR(10) = ''
         , @c_ToLottable01       NVARCHAR(18) = ''
         , @c_ToLottable02       NVARCHAR(18) = ''
         , @c_ToLottable03       NVARCHAR(18) = ''
         , @dt_ToLottable04      DATETIME
         , @dt_ToLottable05      DATETIME
         , @c_ToLottable06       NVARCHAR(30) = ''
         , @c_ToLottable07       NVARCHAR(30) = ''
         , @c_ToLottable08       NVARCHAR(30) = ''
         , @c_ToLottable09       NVARCHAR(30) = ''
         , @c_ToLottable10       NVARCHAR(30) = ''       
         , @c_ToLottable11       NVARCHAR(30) = ''
         , @c_ToLottable12       NVARCHAR(30) = ''
         , @dt_ToLottable13      DATETIME
         , @dt_ToLottable14      DATETIME
         , @dt_ToLottable15      DATETIME   
         
         , @n_ToQty              INT          = 0
         , @c_ToChannel          NVARCHAR(20) = ''
         
         , @n_KitLineNumber      INT          = 0
         , @n_KitLineNumberTo    INT          = 0
         , @c_KitKey             NVARCHAR(10) = ''
         , @c_KitLineNumber      NVARCHAR(5)  = ''
         , @c_KitLineNumberTo    NVARCHAR(5)  = ''
         , @c_ComponentSku       NVARCHAR(20) = ''
         , @c_Packkey            NVARCHAR(10) = ''
         , @c_UOM                NVARCHAR(10) = ''
         , @c_KitLoc             NVARCHAR(10) = ''
         , @n_KitQty             INT          = 0

         , @c_ModuleName         NVARCHAR(30) = ''
         , @c_AlertMessage       NVARCHAR(255)= ''
         
         , @CUR_TRFDET           CURSOR
         , @CUR_BOM              CURSOR

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCount = @@TRANCOUNT  
     
   -- Finalize By Header
   IF @c_TransferLineNumber <> ''
   BEGIN
      GOTO QUIT_SP
   END
     
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
   
   SET @c_CustomerRefNo = ''
   SET @c_Type          = ''
   SELECT @c_ToFacility    = ToFacility
         ,@c_FromStorerkey = FromStorerkey
         ,@c_ToStorerkey   = ToStorerkey
         ,@c_Type          = ISNULL(RTRIM([Type]),'')
         ,@c_CustomerRefNo = ISNULL(RTRIM(CustomerRefNo),'')
   FROM [TRANSFER] WITH (NOLOCK)
   WHERE Transferkey = @c_TransferKey

   SET @c_ToSku = ''
   SELECT TOP 1 @c_ToSku = TFD.ToSku
   FROM TRANSFERDETAIL TFD WITH (NOLOCK)
   JOIN SKU            SKU WITH (NOLOCK) ON (TFD.ToStorerkey = SKU.Storerkey)
                                         AND(TFD.ToSku = SKU.Sku)
   WHERE Transferkey =  @c_TransferKey
   AND   ( FromQty > 0 AND ToQty > 0 )
   AND   SKU.PrePackIndicator IS NOT NULL AND SKU.PrePackIndicator = 'Y'
   ORDER BY TFD.TransferLineNumber
        
   IF @c_ToSku = ''       
   BEGIN 
      GOTO QUIT_SP
   END  
      
   BEGIN TRAN
   
   SET @c_KitKey = ''
   SELECT TOP 1 @c_KitKey = k.KitKey FROM KIT AS k WITH (NOLOCK) WHERE k.ExternKitKey = @c_Transferkey
   
   IF @c_KitKey = ''
   BEGIN
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
         SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Getting KitKey Fail. (ispPOTRF05)' 
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
         ,  Remarks              
         )
      VALUES 
         (  @c_KitKey
         ,  @c_ToStorerkey
         ,  @c_ToStorerkey
         ,  @c_Type
         ,  @c_CustomerRefNo
         ,  'PREPACK'
         ,  @c_TransferKey
         ,  @c_ToFacility
         ,  @c_ToSku             
         )
   
      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err=82010   
         SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Insert Into KIT Fail. (ispPOTRF05)'
         GOTO QUIT_SP
      END
   END

   SELECT @c_ToLoc_WCS = ISNULL(CL.Short,'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'WCSROUTE'
   AND CL.Code = 'Y'

   SET @n_KitLineNumber = 0
   SET @c_KitLineNumber = '00000'
   
   SELECT TOP 1 @n_KitLineNumber = CONVERT (INT, kd.KITLineNumber)
   FROM KITDETAIL AS kd WITH (NOLOCK)
   WHERE kd.KITKey = @c_KitKey
   ORDER BY Kd.KITLineNumber DESC

   SET @CUR_TRFDET = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT TransferLineNumber = TFD.TransferLineNumber
         ,ToStorerkey    = TFD.ToStorerkey
         ,ToSku          = TFD.ToSku
         ,ToLot          = TFD.ToLot
         ,ToLoc         = TFD.ToLoc
         ,ToID           = TFD.ToID
         ,ToPackkey      = SKU.Packkey
         ,ToUOM          = PCK.PackUOM3
         ,ToLottable01   = ISNULL(RTRIM(TFD.ToLottable01),'')
         ,ToLottable02   = ISNULL(RTRIM(TFD.ToLottable02),'')
         ,ToLottable02   = ISNULL(RTRIM(TFD.ToLottable03),'')
         ,ToLottable04   = TFD.ToLottable04
         ,ToLottable05   = TFD.ToLottable05
         ,ToLottable06   = ISNULL(RTRIM(TFD.ToLottable06),'')
         ,ToLottable07   = ISNULL(RTRIM(TFD.ToLottable07),'')
         ,ToLottable08   = ISNULL(RTRIM(TFD.ToLottable08),'')
         ,ToLottable09   = ISNULL(RTRIM(TFD.ToLottable09),'')
         ,ToLottable10   = ISNULL(RTRIM(TFD.ToLottable10),'')                  
         ,ToLottable11   = ISNULL(RTRIM(TFD.ToLottable11),'')
         ,ToLottable12   = ISNULL(RTRIM(TFD.ToLottable12),'')
         ,ToLottable13   = ISNULL(RTRIM(TFD.ToLottable13),'')
         ,ToLottable14   = TFD.ToLottable14
         ,ToLottable15   = TFD.ToLottable15         
         ,ToQty          = TFD.ToQty 
         ,ToChannel      = TFD.ToChannel
   FROM TRANSFERDETAIL TFD WITH (NOLOCK)
   JOIN SKU            SKU WITH (NOLOCK) ON (TFD.ToStorerkey = SKU.Storerkey)
                                         AND(TFD.ToSku = SKU.Sku)
   JOIN PACK           PCK WITH (NOLOCK) ON (SKU.Packkey = PCK.Packkey)
   WHERE TFD.Transferkey = @c_TransferKey
   AND   TFD.ToQty > 0
   AND   TFD.[Status] = '9'   
   AND   SKU.PrePackIndicator IS NOT NULL AND SKU.PrePackIndicator = 'Y' 
   
   OPEN @CUR_TRFDET

   FETCH NEXT FROM @CUR_TRFDET INTO @c_TransferLineNumber  
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
                                 ,  @dt_ToLottable04    
                                 ,  @dt_ToLottable05 
                                 ,  @c_ToLottable06    
                                 ,  @c_ToLottable07    
                                 ,  @c_ToLottable08    
                                 ,  @c_ToLottable09    
                                 ,  @c_ToLottable10              
                                 ,  @c_ToLottable11    
                                 ,  @c_ToLottable12    
                                 ,  @dt_ToLottable13    
                                 ,  @dt_ToLottable14    
                                 ,  @dt_ToLottable15             
                                 ,  @n_ToQty  
                                 ,  @c_ToChannel
   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @n_KitLineNumber = @n_KitLineNumber + 1
      SET @c_KitLineNumber = RIGHT('00000' + CONVERT(VARCHAR(5),@n_KitLineNumber),5)

      SELECT TOP 1 @c_ToLOT = LOT 
      FROM dbo.ITRN WITH (NOLOCK)
      WHERE StorerKey = @c_ToStorerKey 
      AND Sku   = @c_ToSku
      AND ToLoc = @c_ToLoc
      AND ToId  = @c_ToID
      AND SourceKey = @c_Transferkey + @c_TransferLineNumber
      AND TranType = 'DP'
      AND SourceType IN ('ntrTransferDetailAdd', 'ntrTransferDetailUpdate')

      IF @c_ToLoc_WCS <> ''
      BEGIN  
         SET @c_ToLoc = @c_ToLoc_WCS
      END
      
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
         ,  Lottable06    
         ,  Lottable07    
         ,  Lottable08    
         ,  Lottable09    
         ,  Lottable10              
         ,  Lottable11    
         ,  Lottable12    
         ,  Lottable13    
         ,  Lottable14    
         ,  Lottable15 
         ,  ExternKitKey
         ,  ExternLineNo
         ,  Channel
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
         ,  @c_ToLoc
         ,  @c_ToID
         ,  @n_ToQty
         ,  @n_ToQty
         ,  @c_ToLottable01    
         ,  @c_ToLottable02    
         ,  @c_ToLottable03    
         ,  @dt_ToLottable04    
         ,  @dt_ToLottable05 
         ,  @c_ToLottable06    
         ,  @c_ToLottable07    
         ,  @c_ToLottable08    
         ,  @c_ToLottable09    
         ,  @c_ToLottable10              
         ,  @c_ToLottable11    
         ,  @c_ToLottable12    
         ,  @dt_ToLottable13    
         ,  @dt_ToLottable14    
         ,  @dt_ToLottable15 
         ,  @c_TransferKey
         ,  @c_TransferLineNumber
         ,  @c_ToChannel
         )

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err=82015  
         SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Insert Into KITDETAIL Fail. (ispPOTRF05)'
         GOTO QUIT_SP
      END

      SET @CUR_BOM = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT ComponentSku 
            ,Qty
      FROM   BILLOFMATERIAL WITH (NOLOCK)
      WHERE  Storerkey = @c_ToStorerkey 
      AND    Sku       = @c_ToSku
      ORDER BY Sequence

      OPEN @CUR_BOM

      FETCH NEXT FROM @CUR_BOM INTO @c_ComponentSku
                                 ,  @n_KitQty

      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @n_KitQty = @n_KitQty * @n_ToQty
         SET @n_KitLineNumberTo = @n_KitLineNumberTo + 1
         SET @c_KitLineNumberTo = RIGHT('00000' + CONVERT(VARCHAR(5),@n_KitLineNumberTo),5)

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
            ,  Lottable06    
            ,  Lottable07    
            ,  Lottable08    
            ,  Lottable09    
            ,  Lottable10              
            ,  Lottable11    
            ,  Lottable12    
            ,  Lottable13    
            ,  Lottable14    
            ,  Lottable15               
            ,  ExternKitKey
            ,  ExternLineNo
            ,  Channel
            )
         VALUES 
            (  @c_KitKey
            ,  @c_KITLineNumberTo
            ,  'T'
            ,  @c_ToStorerkey
            ,  @c_ComponentSku
            ,  @c_Packkey
            ,  @c_UOM
            ,  ''                         --(Wan01)
            ,  @c_ToLoc
            ,  @c_ToID
            ,  @n_KitQty
            ,  @n_KitQty
            ,  @c_ToLottable01    
            ,  @c_ToLottable02    
            ,  @c_ToLottable03    
            ,  @dt_ToLottable04    
            ,  @dt_ToLottable05 
            ,  @c_ToLottable06    
            ,  @c_ToLottable07    
            ,  @c_ToLottable08    
            ,  @c_ToLottable09    
            ,  @c_ToLottable10              
            ,  @c_ToLottable11    
            ,  @c_ToLottable12    
            ,  @dt_ToLottable13    
            ,  @dt_ToLottable14    
            ,  @dt_ToLottable15             
            ,  @c_TransferKey
            ,  @c_TransferLineNumber
            ,  @c_ToChannel
            )

            SET @n_err = @@ERROR
            IF @n_err <> 0
            BEGIN
               SET @n_Continue = 3
               SET @n_err=82020  
               SET @c_ErrMsg='NSQL'+CONVERT(VARCHAR(5),@n_err)+': Insert Into KITDETAIL Fail. (ispPOTRF05)'
               GOTO QUIT_SP
            END

         FETCH NEXT FROM @CUR_BOM INTO  @c_ComponentSku
                                    ,  @n_KitQty
      END
      CLOSE @CUR_BOM
      DEALLOCATE @CUR_BOM

      FETCH NEXT FROM @CUR_TRFDET INTO @c_TransferLineNumber  
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
                                    ,  @dt_ToLottable04    
                                    ,  @dt_ToLottable05 
                                    ,  @c_ToLottable06    
                                    ,  @c_ToLottable07    
                                    ,  @c_ToLottable08    
                                    ,  @c_ToLottable09    
                                    ,  @c_ToLottable10              
                                    ,  @c_ToLottable11    
                                    ,  @c_ToLottable12    
                                    ,  @dt_ToLottable13    
                                    ,  @dt_ToLottable14    
                                    ,  @dt_ToLottable15                                     
                                    ,  @n_ToQty
                                    ,  @c_ToChannel 
   END
   CLOSE @CUR_TRFDET
   DEALLOCATE @CUR_TRFDET


   SET @c_ModuleName = 'ispPOTRF05'
       
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
      Execute nsp_logerror @n_err, @c_errmsg, 'ispPOTRF05'
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