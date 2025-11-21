SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO


/***************************************************************************/        
/* Stored Procedure: ispTransferAllocation04                               */        
/* Creation Date: 2021-03-12                                               */        
/* Copyright: IDS                                                          */        
/* Written by: Wan                                                         */        
/*                                                                         */        
/* Purpose: WMS-16397 - [CN]ANF_Exceed_Transfer_CR                         */        
/*        : Transfer Channel Only. LotxLocxID No change- Transfer allocate */      
/* Called By: Job Scheduler / ue_transferallocation                        */        
/*                                                                         */        
/* PVCS Version: 1.1                                                       */        
/*                                                                         */        
/* Version: 5.4                                                            */        
/*                                                                         */        
/* Data Modifications:                                                     */        
/*                                                                         */        
/* Updates:                                                                */        
/* Date        Author   Ver   Purposes                                     */        
/* 2021-03-12  Wan      1.0   Created.                                     */      
/* 2021-08-27  Wan01    1.1   Fixed. Transfer Channel Only. LotxLocxID No  */      
/*                            changed.                                     */    
/* 26-Nov-2021 PakYuen 1.2   JSM-35430  change the logic to update  (py01) */      
/***************************************************************************/        
        
CREATE PROC [dbo].[ispTransferAllocation04](        
   @c_FromStorerkey  NVARCHAR(10) = ''                
,  @c_TransferKey    NVARCHAR(10) = ''                
,  @b_Success        INT          = 1   OUTPUT        
,  @n_Err            INT          = 0   OUTPUT        
,  @c_ErrMsg         NVARCHAR(250)= ''  OUTPUT        
,  @c_Code           NVARCHAR(30) = ''                
,  @c_Facility       NVARCHAR(5)  = ''                
)        
AS        
BEGIN        
   SET NOCOUNT ON        
   SET QUOTED_IDENTIFIER OFF        
   SET ANSI_NULLS OFF        
   SET CONCAT_NULL_YIELDS_NULL OFF        
        
   DECLARE @b_Debug                    INT   = 0      
         , @n_Cnt                      INT   = 0      
         , @n_Continue                 INT   = 1      
         , @n_StartTCount              INT   = @@TRANCOUNT      
                                             
   DECLARE @c_Transmitlogkey           NVARCHAR(10)   = ''         
         , @c_ReAllocTrfkey            NVARCHAR(10)   = ''      
         , @c_Status_TFH               NVARCHAR(10)   = ''      
         , @c_Status_TFD               NVARCHAR(10)   = ''      
         , @c_Status_Orig_TFH          NVARCHAR(10)   = ''      
         , @c_TransferType             NVARCHAR(10)   = ''      
         , @c_Transmitflag             NVARCHAR(10)   = ''      
         , @c_TransmitBatch            NVARCHAR(10)   = ''      
         , @c_TransferLineNumber       NVARCHAR(5)    = ''      
         , @c_NewTransferLineNo        NVARCHAR(5)    = ''      
        
         , @c_FromFacility             NVARCHAR(5)    = ''      
         , @c_FromSku                  NVARCHAR(15)   = ''      
         , @c_FromLot                  NVARCHAR(10)   = ''      
         , @c_FromLoc                  NVARCHAR(10)   = ''      
         , @c_FromID                   NVARCHAR(18)   = ''      
         , @c_FromPackkey              NVARCHAR(10)   = ''      
         , @c_FromUOM                  NVARCHAR(10)   = ''      
         , @c_ToPackkey                NVARCHAR(10)   = ''      
         , @c_ToUOM                    NVARCHAR(10)   = ''      
         , @c_ToFacility               NVARCHAR(15)   = ''      
         , @c_ToStorerkey              NVARCHAR(15)   = ''      
         , @c_ToSku                    NVARCHAR(20)   = ''      
         , @c_ToID                     NVARCHAR(18)   = ''      
         , @c_ToLoc                    NVARCHAR(10)   = ''      
         , @c_FromLottable01           NVARCHAR(18)   = ''      
         , @c_FromLottable02           NVARCHAR(18)   = ''      
         , @c_FromLottable03           NVARCHAR(18)   = ''      
         , @dt_FromLottable04          DATETIME        
         , @dt_FromLottable05          DATETIME        
         , @c_FromLottable06           NVARCHAR(30)   = ''               
         , @c_FromLottable07           NVARCHAR(30)   = ''               
         , @c_FromLottable08           NVARCHAR(30)   = ''               
         , @c_FromLottable09           NVARCHAR(30)   = ''               
         , @c_FromLottable10           NVARCHAR(30)   = ''               
         , @c_FromLottable11           NVARCHAR(30)   = ''               
         , @c_FromLottable12           NVARCHAR(30)   = ''               
         , @dt_FromLottable13          DATETIME                      
         , @dt_FromLottable14          DATETIME                      
         , @dt_FromLottable15          DATETIME       
         , @c_ToLottable02             NVARCHAR(18)   = ''      
         , @c_ToLottable03             NVARCHAR(18)   = ''                       
         , @c_Lottable01               NVARCHAR(18)   = ''      
         , @c_Lottable02               NVARCHAR(18)   = ''      
         , @c_Lottable03               NVARCHAR(18)   = ''      
         , @dt_Lottable04              DATETIME             
         , @dt_Lottable05              DATETIME             
         , @c_Lottable06               NVARCHAR(30)   = ''             
         , @c_Lottable07               NVARCHAR(30)   = ''             
         , @c_Lottable08               NVARCHAR(30)   = ''             
         , @c_Lottable09               NVARCHAR(30)   = ''             
         , @c_Lottable10               NVARCHAR(30)   = ''             
         , @c_Lottable11               NVARCHAR(30)   = ''             
         , @c_Lottable12               NVARCHAR(30)   = ''             
         , @dt_Lottable13              DATETIME                   
         , @dt_Lottable14              DATETIME                   
         , @dt_Lottable15              DATETIME                   
         , @c_UCCNo                    NVARCHAR(20)   = ''      
         , @c_FromChannel              NVARCHAR(20)   = ''      
         , @c_ToChannel                NVARCHAR(20)   = ''      
               
         , @c_LocationCategory         NVARCHAR(10)   = ''      
         , @c_LocationType             NVARCHAR(10)   = ''      
         , @c_Status_UCC               NVARCHAR(10)   = '0'      
               
         , @n_UCC_RowRef               BIGINT         = 0      
         , @n_FromQty                  INT            = 0      
         , @n_ToQty                    INT            = 0      
         , @n_QtyRemaining             INT            = 0      
         , @n_QtyAvail                 INT            = 0      
         , @n_QtyToTake                INT            = 0      
         , @n_QtyToMove                INT            = 0      
         , @n_UCCQty                   INT            = 0      
         , @n_OpenQty                  INT            = 0      
         , @b_RPFTask                  BIT            = 0      
                 
         , @c_PrepackIndicator         NVARCHAR(30)   = ''      
                                                     
         , @c_UserID                   NVARCHAR(128)  = ''      
         , @dt_today                   DATETIME       = ''      
                
         , @c_PABookID                 NVARCHAR(18)   = ''        
         , @c_FinalToLoc_DPP           NVARCHAR(10)   = ''                       
         , @c_TaskDetailKey            NVARCHAR(10)   = ''      
         , @c_Areakey                  NVARCHAR(10)   = ''      
         , @c_MoveToLoc                NVARCHAR(10)   = ''      
         , @c_FinalToLoc               NVARCHAR(10)   = ''      
         , @c_LogicalLoc               NVARCHAR(10)   = ''      
         , @c_LogicalMoveToLoc         NVARCHAR(10)   = ''      
         , @c_SourceKey                NVARCHAR(30)   = ''      
                                                         
         , @c_PostFinalizeTransferSP   NVARCHAR(10)   = ''      
         , @c_AutoFinalizeShortTrf     NVARCHAR(10)   = ''      
         , @c_AlertMessage             NVARCHAR(255)  = ''      
        
         , @cRecipients                NVARCHAR(MAX)  = ''      
         , @cBody                      NVARCHAR(MAX)  = ''      
         , @cSubject                   NVARCHAR(255)  = ''      
      
         , @n_PABookingKey             INT            = 0            
         , @dt_TimeOut                 DATETIME           
         , @b_DummyLLI                 INT            = 0            
      
         , @c_TransferAlloc_SP         NVARCHAR(30)   = ''        
         , @c_SQL                      NVARCHAR(2000) = ''        
         , @c_SQLParms                 NVARCHAR(2000) = ''       
               
         , @CUR_ANFTRAN                CURSOR      
         , @CUR_TFRDET                 CURSOR       
               
   DECLARE @t_TL3 TABLE (  Transmitlogkey NVARCHAR(10) NOT NULL PRIMARY KEY      
                        ,  Key1           NVARCHAR(10) NOT NULL      
                        ,  Key3           NVARCHAR(20) NOT NULL      
                        )      
   --CR v6.0      
   DECLARE @tLA TABLE      
         (  RowRef            INT            IDENTITY(1,1) PRIMARY KEY      
         ,  Lot               NVARCHAR(10)   NOT NULL DEFAULT('')            
         ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')      
         ,  Sku               NVARCHAR(20)   NOT NULL DEFAULT('')      
         ,  Lottable01        NVARCHAR(18)   NOT NULL DEFAULT('')      
         ,  Lottable02        NVARCHAR(18)   NOT NULL DEFAULT('')      
         ,  Lottable03        NVARCHAR(18)   NOT NULL DEFAULT('')      
         ,  Lottable04        DATETIME       NULL      
         ,  Lottable05        DATETIME       NULL       
         ,  Lottable06        NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  Lottable07        NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  Lottable08        NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  Lottable09        NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  Lottable10        NVARCHAR(30)   NOT NULL DEFAULT('')                   
         ,  Lottable11        NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  Lottable12        NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  Lottable13        DATETIME       NULL       
         ,  Lottable14        DATETIME       NULL       
         ,  Lottable15        DATETIME       NULL        
         ,  MatchLottable01   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable02   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable03   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable04   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable05   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable06   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable07   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable08   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable09   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable10   INT            NOT NULL DEFAULT(0)                     
         ,  MatchLottable11   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable12   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable13   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable14   INT            NOT NULL DEFAULT(0)      
         ,  MatchLottable15   INT            NOT NULL DEFAULT(0)            
         )      
               
   IF ISNULL(OBJECT_ID('tempdb..#Error'),'') <> ''        
   BEGIN        
      DROP TABLE #Error        
   END        
   CREATE TABLE #Error ( ErrMsg NVARCHAR(250) NULL )        
            
   SET @c_UserID = SUSER_NAME()        
   SET @dt_today = GETDATE()        
        
   WHILE @@TRANCOUNT > 0        
   BEGIN        
      COMMIT TRAN        
   END        
        
   SET @c_ReAllocTrfkey = @c_Transferkey        
        
   SET @c_Transferkey = ''        
   IF @c_ReAllocTrfkey = ''        
   BEGIN      
      IF @c_Facility = ''       
      BEGIN        
         INSERT INTO @t_TL3 ( Transmitlogkey, Key1, Key3 )      
         SELECT TL3.Transmitlogkey      
               ,TL3.Key1       
               ,TL3.Key3      
         FROM TRANSMITLOG3 TL3 WITH (NOLOCK)      
         WHERE TL3.TABLENAME = 'ANFTranAdd'        
         AND TL3.Key3 = @c_FromStorerkey       
         AND TL3.Transmitflag  <= '5'       
      END       
      ELSE      
      BEGIN      
         INSERT INTO @t_TL3 ( Transmitlogkey, Key1, Key3 )      
         SELECT TL3.Transmitlogkey      
               ,TL3.Key1       
               ,TL3.Key3      
         FROM TRANSMITLOG3 TL3 WITH (NOLOCK)      
         WHERE TL3.TABLENAME = 'ANFTranAdd'        
         AND TL3.Key3 = @c_FromStorerkey       
         AND TL3.Transmitflag  <= '5'        
         AND EXISTS (SELECT 1 FROM [TRANSFER] AS t WITH (NOLOCK) WHERE TL3.Key1 = t.TransferKey AND t.Facility = @c_Facility)      
      END      
   END      
   ELSE      
   BEGIN      
      --SET @c_ErrMsg = 'Transfer Re-allocated'       
            
      SELECT @c_FromStorerkey = TF.FromStorerkey      
            ,@c_Status_TFH    = TF.[Status]      
            ,@c_FromFacility  = TF.Facility        
      FROM [TRANSFER] TF WITH (NOLOCK)        
      WHERE TF.Transferkey = @c_ReAllocTrfkey       
            
      IF @c_FromFacility <> @c_Facility AND @c_Facility <> ''       
      BEGIN      
         SET @n_continue = 3            
         SET @n_err    = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.            
         SET @c_errmsg = 'Pass In Facility <> Transfer From Facility. (ispTransferAllocation04)'        
         GOTO QUIT_SP      
      END      
      
      IF @c_Status_TFH NOT IN ('0', '3')       
      BEGIN        
         SET @n_continue = 3            
         SET @n_err    = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.            
         SET @c_errmsg = 'Transfer is not allowed to re-allocate. (ispTransferAllocation04)'        
         GOTO QUIT_SP                   
      END      
            
      INSERT INTO @t_TL3 ( Transmitlogkey, Key1, Key3 )      
      SELECT TL3.Transmitlogkey      
            ,TL3.Key1       
            ,TL3.Key3      
      FROM TRANSMITLOG3 TL3 WITH (NOLOCK)      
      WHERE TL3.TABLENAME = 'ANFTranAdd'       
      AND TL3.Key1 = @c_ReAllocTrfkey       
      AND TL3.Key3 = @c_FromStorerkey       
      AND TL3.Transmitflag  <= '9'          
   END        
           
   SET @c_AutoFinalizeShortTrf = '0'        
   SELECT @c_AutoFinalizeShortTrf = ISNULL(RTRIM(SValue),'')        
   FROM STORERCONFIG WITH (NOLOCK)        
   WHERE Storerkey = @c_FromStorerkey        
   AND Configkey = 'AutoFinalizeShortTrf'        
         
   SET @CUR_ANFTRAN = CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR        
   SELECT Transmitlogkey= TL3.Transmitlogkey        
        , Transferkey   = TL3.Key1        
        , TransferType  = TF.[Type]        
        , Facility      = TF.Facility       
        , ToFacility    = TF.ToFacility       
        , Status_Orig_TFH = TF.[Status]      
   FROM @t_TL3 TL3         
   JOIN [TRANSFER] TF WITH (NOLOCK) ON (TL3.Key1 = TF.TransferKey)        
                                    AND(TL3.Key3 = TF.FromStorerkey)        
   WHERE TF.[Status] < '9'         
   ORDER BY TL3.Transmitlogkey        
        
   OPEN @CUR_ANFTRAN        
        
   FETCH NEXT FROM @CUR_ANFTRAN INTO @c_Transmitlogkey        
                                    ,@c_Transferkey        
                                    ,@c_TransferType        
                                    ,@c_FromFacility      
                                    ,@c_ToFacility       
                                    ,@c_Status_Orig_TFH       
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1                   
      SET @b_Success= 1        
      SET @n_Err    = 0        
      SET @c_ErrMsg = ''        
        
      --CR v5.0 - START      
      --IF @c_TransferType NOT Like '%DTC%'        
      --BEGIN        
      --   SET @c_Transmitflag = 'IGNOR'        
      --   SET @c_TransmitBatch= '0'       
      --   GOTO NEXT_TRF        
      --END      
      --CR v5.0 - END        
            
      BEGIN TRAN        
      UPDATE TL3       
      SET Trafficcop = NULL        
         ,Transmitflag = '1'                    
         ,EditDate = GETDATE()      
         ,EditWho = SUSER_SNAME()      
      FROM TRANSMITLOG3 TL3          
      WHERE TL3.Transmitlogkey = @c_Transmitlogkey        
        
      SET @n_err = @@ERROR          
        
      IF @n_err <> 0             
      BEGIN          
         SET @n_continue = 3            
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
         SET @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.            
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSMITLOG3 Failed. (ispTransferAllocation04)'         
                      + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '          
         GOTO NEXT_TRF          
      END        
        
      SET @c_Status_TFD = '3'        
      SET @c_Transmitflag   = '9'        
      SET @c_TransmitBatch  = '4'        
      
      SET @b_RPFTask = 0      
      IF EXISTS ( SELECT 1 FROM CODELKUP (NOLOCK)        
                  WHERE Code = @c_FromFacility        
                  AND Listname = 'ANFFAC'         
                  AND UDF05 = 'Y'      
                  )       
      BEGIN       
         SET @b_RPFTask = 1      
      END      
            
      SET @CUR_TFRDET = CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR        
      SELECT TransferLineNumber = TD.TransferLineNumber        
           , FromSku    = TD.FromSku        
           , FromQty    = TD.FromQty        
           , FromLottable01 = ISNULL(RTRIM(TD.Lottable01),'')                 --CR v6.0      
           , FromLottable02 = ISNULL(RTRIM(TD.Lottable02),'')                 --CR v6.0      
           , FromLottable03 = ISNULL(RTRIM(TD.Lottable03),'')                 --CR v6.0      
           , FromLottable04 = ISNULL(RTRIM(TD.Lottable04),'1900-01-01')       --CR v6.0      
           , FromLottable05 = ISNULL(RTRIM(TD.Lottable05),'1900-01-01')       --CR v6.0      
           , FromLottable06 = ISNULL(RTRIM(TD.Lottable06),'')                 --CR v6.0                                        
           , Fromlottable07 = ISNULL(RTRIM(TD.Lottable07),'')                 --CR v6.0      
           , FromLottable08 = ISNULL(RTRIM(TD.Lottable08),'')                 --CR v6.0      
           , FromLottable09 = ISNULL(RTRIM(TD.Lottable09),'')                 --CR v6.0      
           , FromLottable10 = ISNULL(RTRIM(TD.Lottable10),'')                 --CR v6.0      
           , FromLottable11 = ISNULL(RTRIM(TD.Lottable11),'')                 --CR v6.0      
           , FromLottable12 = ISNULL(RTRIM(TD.Lottable12),'')                 --CR v6.0      
           , FromLottable13 = ISNULL(RTRIM(TD.Lottable13),'1900-01-01')       --CR v6.0      
           , FromLottable14 = ISNULL(RTRIM(TD.Lottable14),'1900-01-01')       --CR v6.0      
           , FromLottable15 = ISNULL(RTRIM(TD.Lottable15),'1900-01-01')       --CR v6.0      
           , ToStorereky = TD.ToStorerkey        
           , ToSku       = TD.ToSku       
           , ToLottable02   = ISNULL(RTRIM(TD.ToLottable02),'')                 
           , ToLottable03   = ISNULL(RTRIM(TD.ToLottable03),'')       
           , FromChannel = ISNULL(RTRIM(TD.FromChannel),'')        
           , TOChannel = ISNULL(RTRIM(TD.ToChannel),'')               
      FROM TRANSFERDETAIL TD  WITH (NOLOCK)        
      JOIN SKU            SKU WITH (NOLOCK) ON (TD.ToStorerkey = SKU.Storerkey) AND (TD.ToSku = SKU.Sku)        
      WHERE TD.Transferkey = @c_Transferkey        
      AND   TD.[Status] = '0'               
      AND   TD.FromLot  = ''                
      AND   TD.FromQty  > 0                 
        
      OPEN @CUR_TFRDET        
        
      FETCH NEXT FROM @CUR_TFRDET INTO @c_TransferLineNumber        
         ,  @c_FromSku        
                                    ,  @n_FromQty        
                                    ,  @c_FromLottable01      
                                    ,  @c_FromLottable02      
                                    ,  @c_FromLottable03      
                                    ,  @dt_FromLottable04         
                                    ,  @dt_FromLottable05       
                                    ,  @c_FromLottable06                                                        
                                    ,  @c_Fromlottable07      
                                    ,  @c_FromLottable08       
                                    ,  @c_FromLottable09       
                                    ,  @c_FromLottable10       
                                    ,  @c_FromLottable11      
                                    ,  @c_FromLottable12      
               ,  @dt_FromLottable13      
                                    ,  @dt_FromLottable14         
                                    ,  @dt_FromLottable15      
                                    ,  @c_ToStorerkey        
                                    ,  @c_ToSku        
                                    ,  @c_ToLottable02       
                                    ,  @c_ToLottable03                                           
                                    ,  @c_FromChannel      
                                    ,  @c_ToChannel       
        
      WHILE @@FETCH_STATUS <> -1        
      BEGIN      
         SET @n_QtyRemaining = @n_FromQty        
         SET @c_Status_TFD = '9'        
        
         SELECT @c_FromPackkey = PACK.Packkey        
               ,@c_FromUOM     = PACK.PackUOM3        
         FROM SKU  WITH (NOLOCK)        
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)        
         WHERE SKU.Storerkey = @c_FromStorerkey        
         AND   SKU.Sku       = @c_FromSku        
        
         SELECT @c_ToPackkey = PACK.Packkey        
               ,@c_ToUOM     = PACK.PackUOM3        
               ,@c_PrepackIndicator = ISNULL(RTRIM(SKU.PrepackIndicator),'')        
         FROM SKU WITH (NOLOCK)        
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)        
         WHERE SKU.Storerkey = @c_ToStorerkey        
         AND   SKU.Sku       = @c_ToSku       
        
         -- CR v6.0             
         DELETE FROM @tLA;      
               
         INSERT INTO @tLA       
            ( Lot, Storerkey, Sku      
            , Lottable01, Lottable02, Lottable03, Lottable04, Lottable05      
            , Lottable06, Lottable07, Lottable08, Lottable09, Lottable10                        
            , Lottable11, Lottable12, Lottable13, Lottable14, Lottable15      
            , MatchLottable01, MatchLottable02, MatchLottable03, MatchLottable04, MatchLottable05      
            , MatchLottable06, MatchLottable07, MatchLottable08, MatchLottable09, MatchLottable10                        
            , MatchLottable11, MatchLottable12, MatchLottable13, MatchLottable14, MatchLottable15               
            )      
         SELECT LATRB.Lot, LATRB.Storerkey, LATRB.Sku      
         , Lottable01 = CASE WHEN @c_FromLottable01  = '' THEN LATRB.Lottable01 ELSE @c_FromLottable01   END      
         , Lottable02 = CASE WHEN @c_FromLottable02  = '' THEN LATRB.Lottable02 ELSE @c_FromLottable02   END      
         , Lottable03 = CASE WHEN @c_FromLottable03  = '' THEN LATRB.Lottable03 ELSE @c_FromLottable03   END      
         , Lottable04 = CASE WHEN @dt_FromLottable04 = '' THEN LATRB.Lottable04 ELSE @dt_FromLottable04  END      
         , Lottable05 = CASE WHEN @dt_FromLottable05 = '' THEN LATRB.Lottable05 ELSE @dt_FromLottable05  END      
         , Lottable06 = CASE WHEN @c_FromLottable06  = '' THEN LATRB.Lottable06 ELSE @c_FromLottable06   END      
         , Lottable07 = CASE WHEN @c_FromLottable07  = '' THEN LATRB.Lottable07 ELSE @c_FromLottable07   END      
         , Lottable08 = CASE WHEN @c_FromLottable08  = '' THEN LATRB.Lottable08 ELSE @c_FromLottable08   END      
         , Lottable09 = CASE WHEN @c_FromLottable09  = '' THEN LATRB.Lottable09 ELSE @c_FromLottable09   END      
         , Lottable10 = CASE WHEN @c_FromLottable10  = '' THEN LATRB.Lottable10 ELSE @c_FromLottable10   END              
         , Lottable11 = CASE WHEN @c_FromLottable11  = '' THEN LATRB.Lottable11 ELSE @c_FromLottable11   END      
         , Lottable12 = CASE WHEN @c_FromLottable12  = '' THEN LATRB.Lottable12 ELSE @c_FromLottable12   END      
         , Lottable13 = CASE WHEN @dt_FromLottable13 = '' THEN LATRB.Lottable13 ELSE @dt_FromLottable13  END      
         , Lottable14 = CASE WHEN @dt_FromLottable14 = '' THEN LATRB.Lottable14 ELSE @dt_FromLottable14  END      
         , Lottable15 = CASE WHEN @dt_FromLottable15 = '' THEN LATRB.Lottable15 ELSE @dt_FromLottable15  END      
         , MatchLottable01 = CASE WHEN @c_FromLottable01 = '' THEN 1       
                                    WHEN LATRB.Lottable01  = @c_FromLottable01 THEN 1      
                                    ELSE 0      
END      
         , MatchLottable02 = CASE WHEN @c_FromLottable02 = '' THEN 1       
                                    WHEN LATRB.Lottable02  = @c_FromLottable02 THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable03 = CASE WHEN @c_FromLottable03 = '' THEN 1       
                                    WHEN LATRB.Lottable03  = @c_FromLottable03 THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable04 = CASE WHEN @dt_FromLottable04 = '1900-01-01' THEN 1       
                                    WHEN LATRB.Lottable04   = @dt_FromLottable04 THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable05 = CASE WHEN @dt_FromLottable05 = '1900-01-01' THEN 1       
                                    WHEN LATRB.Lottable05   = @dt_FromLottable05 THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable06 = CASE WHEN @c_FromLottable06  = '' THEN 1       
                                    WHEN LATRB.Lottable06   = @c_FromLottable06  THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable07 = CASE WHEN @c_FromLottable07  = '' THEN 1       
                                    WHEN LATRB.Lottable07   = @c_FromLottable07  THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable08 = CASE WHEN @c_FromLottable08  = '' THEN 1       
                                    WHEN LATRB.Lottable08   = @c_FromLottable08  THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable09 = CASE WHEN @c_FromLottable09  = '' THEN 1       
                                    WHEN LATRB.Lottable09   = @c_FromLottable09  THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable10 = CASE WHEN @c_FromLottable10  = '' THEN 1       
                                    WHEN LATRB.Lottable10   = @c_FromLottable10 THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable11 = CASE WHEN @c_FromLottable11  = '' THEN 1       
                                    WHEN LATRB.Lottable11   = @c_FromLottable11  THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable12 = CASE WHEN @c_FromLottable12  = '' THEN 1       
                                    WHEN LATRB.Lottable12   = @c_FromLottable12  THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable13 = CASE WHEN @dt_FromLottable13 = '1900-01-01' THEN 1       
                                    WHEN LATRB.Lottable13   = @dt_FromLottable13  THEN 1      
                                    ELSE 0      
                    END      
         , MatchLottable14 = CASE WHEN @dt_FromLottable14 = '1900-01-01' THEN 1       
                                    WHEN LATRB.Lottable14   = @dt_FromLottable14  THEN 1      
                                    ELSE 0      
                                    END      
         , MatchLottable15 = CASE WHEN @dt_FromLottable15 = '1900-01-01' THEN 1       
                                    WHEN LATRB.Lottable15   = @dt_FromLottable15  THEN 1      
                                    ELSE 0      
                                    END              
         FROM LOTATTRIBUTE LATRB WITH (NOLOCK)      
         WHERE LATRB.StorerKey = @c_FromStorerkey      
         AND   LATRB.Sku = @c_FromSku       
      
         WHILE @n_FromQty > 0        
         BEGIN        
            SET @n_QtyToTake = 0        
            SET @n_QtyAvail= 0       
            SET @n_UCCQty  = 0       
            SET @n_UCC_RowRef = 0      
            SET @c_FromLot = ''        
            SET @c_FromLoc = ''        
            SET @c_ToLoc = ''        
            SET @c_LogicalLoc  = ''        
            SET @c_UCCNo      = ''       
            SET @c_Status_UCC  = '1'      
            SET @c_Lottable01 = ''        
            SET @c_Lottable02 = ''                    
            SET @c_Lottable03 = ''        
            SET @dt_Lottable04 = NULL        
            SET @dt_Lottable05 = NULL        
            SET @c_Lottable06 = ''        
            SET @c_Lottable07 = ''        
            SET @c_Lottable08 = ''        
            SET @c_Lottable09 = ''        
            SET @c_Lottable10 = ''        
            SET @c_Lottable11 = ''        
            SET @c_Lottable12 = ''        
            SET @dt_Lottable13 = NULL        
            SET @dt_Lottable14 = NULL        
            SET @dt_Lottable15 = NULL        
                  
            --(Wan01) 2021-09-02 Only Transfer Channel, No Transfer Inventory, Inventory Unchanged      
            --(Wan01) Allocate UCC, task , movement no longer valid for CN, that was HK ANF logic      
            --(Wan01) Remove unnecessary logic      
            SELECT TOP 1        
                @c_FromLot = LLI.Lot        
               ,@c_FromLoc = LLI.Loc        
               ,@c_FromID  = LLI.ID        
               --(Wan01) - START      
               --,@n_QtyAvail   = CASE WHEN UCC.UCCNo IS NOT NULL       
               --                        THEN UCC.Qty       
               --                        WHEN CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold >= LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  --Wan01, GetAvailable Channel      
               --                        THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked      
               --                        ELSE CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold      
               --                        END        
               --,@c_UCCNo      = ISNULL(UCC.UCCNo,'')      
               --,@n_UCCQty     = ISNULL(UCC.Qty,0)      
               --,@c_Status_UCC = UCC.[Status]      
               --,@n_UCC_RowRef = UCC.UCC_RowRef      
               ,@n_QtyAvail= CASE WHEN CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold >= LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked  --Wan01, GetAvailable Channel      
                                  THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked      
                                  ELSE CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold      
                                  END        
               ,@c_UCCNo      = ''      
               ,@n_UCCQty     = 0      
               ,@c_Status_UCC = ''      
               ,@n_UCC_RowRef = 0      
               --(Wan01)-END      
               ,@c_Lottable01 = ISNULL(RTRIM(LA.Lottable01),'')        
               ,@c_Lottable02 = ISNULL(RTRIM(LA.Lottable02),'')       
               ,@c_Lottable03 = ISNULL(RTRIM(LA.Lottable03),'')        
               ,@dt_Lottable04= LA.Lottable04        
               ,@dt_Lottable05= LA.Lottable05        
               ,@c_Lottable06 = ISNULL(RTRIM(LA.Lottable06),'')        
               ,@c_Lottable07 = ISNULL(RTRIM(LA.Lottable07),'')        
      ,@c_Lottable08 = ISNULL(RTRIM(LA.Lottable08),'')        
               ,@c_Lottable09 = ISNULL(RTRIM(LA.Lottable09),'')        
               ,@c_Lottable10 = ISNULL(RTRIM(LA.Lottable10),'')        
               ,@c_Lottable11 = ISNULL(RTRIM(LA.Lottable11),'')        
               ,@c_Lottable12 = ISNULL(RTRIM(LA.Lottable12),'')        
               ,@dt_Lottable13= LA.Lottable13        
               ,@dt_Lottable14= LA.Lottable14        
               ,@dt_Lottable15= LA.Lottable15        
               ,@c_LogicalLoc = ISNULL(RTRIM(LOC.LogicalLocation),'')       
               ,@c_LocationCategory = LOC.LocationCategory      
               ,@c_LocationType = LOC.LocationType      
            FROM @tLA LA       
            JOIN LOT          LOT WITH (NOLOCK) ON (LA.Lot = LOT.Lot)      
            JOIN LOTxLOCxID   LLI WITH (NOLOCK) ON (LOT.Lot = LLI.Lot)        
            JOIN LOC          LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)        
            JOIN ID           ID  WITH (NOLOCK) ON (LLI.ID  = ID.ID)        
            JOIN CHANNELINV   CINV WITH (NOLOCK)ON (CINV.Facility = LOC.Facility)      
                                                AND(CINV.Storerkey= LOT.Storerkey)      
                                                AND(CINV.Sku= LOT.Sku)      
                                                AND(CINV.Channel= @c_FromChannel)      
                                                AND(CINV.C_Attribute01 = LA.Lottable03)      
                                                AND CINV.C_Attribute01 <> ''      
            --LEFT JOIN UCC     UCC WITH (NOLOCK) ON (LLI.Lot = UCC.Lot)         --(Wan01)      
            --                     AND(LLI.Loc = UCC.Loc)                        --(Wan01)      
            --                     AND(LLI.ID  = UCC.ID)                         --(Wan01)      
            --                     AND(UCC.[Status]= '1')                        --(Wan01)      
            --                     AND UCC.Qty > 0                               --(Wan01)      
            WHERE LOC.Facility  = @c_FromFacility        
            AND   LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated > 0        
            AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked > 0        
            AND   CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold > 0      
            --AND   CINV.Qty - CINV.QtyAllocated - CINV.QtyOnHold >= ISNULL(UCC.Qty,0)   -- if Channel Qty invqty, CHannel & inv qty are tally --Wan01            
            AND   LOT.[Status] = 'OK'        
            AND   LOC.[Status] = 'OK'        
            AND   LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )        
            AND   ID.[Status]  = 'OK'       
            AND   LA.MatchLottable01 + LA.MatchLottable02 + LA.MatchLottable03 + LA.MatchLottable04 + LA.MatchLottable05 +      
                  LA.MatchLottable06 + LA.MatchLottable07 + LA.MatchLottable08 + LA.MatchLottable09 + LA.MatchLottable10 +      
                  LA.MatchLottable11 + LA.MatchLottable12 + LA.MatchLottable13 + LA.MatchLottable14 + LA.MatchLottable15 = 15       
            --(Wan01) - START            
            --AND   NOT EXISTS (SELECT 1 FROM dbo.UCC AS u WITH (NOLOCK) WHERE u.UCC_RowRef = UCC.UCC_RowRef AND u.Qty > @n_QtyRemaining)  --(Wan01) not to alloc partial ucc      
            --AND   NOT EXISTS (SELECT 1 FROM dbo.TRANSFERDETAIL AS t WITH (NOLOCK) WHERE t.TransferKey = @c_TransferKey AND t.UserDefine01 = ucc.UCCNo)      -- 2021-05-27 Fixed        
            --AND   NOT EXISTS (SELECT 1 FROM dbo.TRANSFERDETAIL AS t2 WITH (NOLOCK)     -- 2021-07-08 CR 8.0      
            --               WHERE t2.TransferKey = @c_TransferKey       
            --               AND   t2.fromlot = LLI.lot      
            --               AND   t2.FromLoc = LLI.loc      
            --               AND   t2.FromId  = lli.Id      
            --               AND   t2.[Status] = '9'      
            --               AND   t2.UserDefine01 = ''       
            --               AND   t2.UserDefine01 = t2.UserDefine02      
            --               GROUP BY t2.fromlot       
            --                     , t2.FromLoc      
            --                     , t2.FromId       
            --               HAVING SUM(t2.FromQty) <= LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked      
            --                           )                                               -- 2021-07-08 CR 8.0        
            --(Wan01) - END      
            ORDER BY CASE WHEN @c_FromFacility =  @c_ToFacility AND LOC.LocationType = 'DYNPPICK' THEN 10        
                          WHEN @c_FromFacility =  @c_ToFacility AND LOC.LocationType <>'DYNPPICK' THEN 20       
                          WHEN @c_FromFacility <> @c_ToFacility AND LOC.LocationType = 'DYNPPICK' THEN 20         --(Wan01) Fixed order by BULK      
                          WHEN @c_FromFacility <> @c_ToFacility AND LOC.LocationType <>'DYNPPICK' THEN 10         --(Wan01) Fixed order by BULK      
                          END        
                  ,  LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked      
            --(Wan01) - START            
            --      ,  CASE WHEN LOC.LocationType = 'DYNPPICK' THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked      
            --              ELSE UCC.Qty END       
            --(Wan01) - END       
      
            IF @c_FromLot = ''        
            BEGIN        
               GOTO NEXT_TRFDET        
            END        
        
      IF @n_QtyRemaining >= @n_QtyAvail        
            BEGIN        
               SET @n_QtyToTake = @n_QtyAvail        
            END        
            ELSE        
            BEGIN        
               SET @n_QtyToTake = @n_QtyRemaining        
            END        
      
            IF @n_QtyToTake <= 0       
            BEGIN       
               GOTO NEXT_LLI      
            END       
      
            --IF @b_RPFTask = 1 AND @c_LocationCategory <> 'SELECTIVE'      
            --BEGIN      
            --   SET @b_RPFTask = 0      
            --END        
                  
            SET @c_Status_TFD = '0'        
      
            SET @c_Status_TFD = CASE WHEN @c_UCCNo = '' THEN '9' ELSE '3' END        
            -------------------------------------      
            -- Get Transfer to ToLoc - START      
            -------------------------------------      
            IF @b_RPFTask = 0      
            BEGIN      
               SET @c_ToLoc = @c_FromLoc           -- Same Facility      
               IF @c_FromFacility <> @c_ToFacility      
               BEGIN      
                  SET @c_ToLoc = ''      
                  SELECT @c_ToLoc = CL.Code      
                  FROM CODELKUP CL WITH (NOLOCK)      
                  WHERE CL.ListName = 'MASTSLFLOC'      
                  AND CL.Code2    = @c_ToFacility      
                  AND CL.Storerkey= @c_FromStorerkey      
                  AND CL.Short    = @c_LocationType       
               END      
               SET @c_Status_TFD = '9'       
            END      
            -------------------------------------      
            -- Get Transfer to ToLoc - END      
            -------------------------------------                   
      
            SET @n_QtyRemaining = @n_QtyRemaining - @n_QtyToTake        
            SET @n_QtyToMove   = CASE WHEN @c_UCCNo = '' THEN @n_QtyToTake ELSE @n_UCCQty END        
            SET @c_Toid = @c_Fromid        
                          
            -------------------------------------      
            -- Find Move To Loc - Start      
            -------------------------------------       
            IF @b_RPFTask = 1       
            BEGIN      
               -- Find MoveToLoc (START)        
               SET @c_MoveToLoc = ''        
               SET @c_FinalToLoc= ''        
                          
               SELECT @c_MoveToLoc = ISNULL(RTRIM(Short),'')        
               FROM CODELKUP WITH (NOLOCK)        
               WHERE ListName = 'WCSROUTE'        
               AND   Code = @c_PrepackIndicator        
        
               SET @c_FinalToLoc = @c_MoveToLoc       
                     
               IF @c_PrepackIndicator <> 'Y' AND @c_UCCNo = ''          
               BEGIN        
                  SET @c_MoveToLoc = ''        
               END       
               ELSE       
               IF @c_PrepackIndicator <> 'Y' AND @c_UCCNo <> ''      
               BEGIN        
                  IF(@n_UCCQty = @n_QtyToMove) --If Transfer qty = Taskdetail.qty = UCC.Qty - This logic only apply to CN        
                  BEGIN        
                     IF EXISTS (SELECT 1 FROM LOC (NOLOCK) WHERE LOC = 'TRBKST')        
                     BEGIN        
                        SET @c_FinalToLoc = 'TRBKST'          
                     END        
                     ELSE        
                     BEGIN        
                        SET @n_Continue = 3        
                        SET @n_Err = 81040        
                        SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Location : TRBKST Not Found in LOC Table (ispTransferAllocation04)'        
                                     + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                        GOTO NEXT_TRF        
                     END         
                  END          
                        
                  IF @c_FinalToLoc = ''         
                  BEGIN          
                     IF EXISTS(SELECT 1 FROM CODELKUP (NOLOCK) WHERE Listname = 'ANFPUTZONE')        
                     BEGIN                            
                        SELECT TOP 1 @c_FinalToLoc = LOC.Loc        
                        FROM LOTXLOCXID LLI (NOLOCK)          
                        JOIN SKU (NOLOCK) ON LLI.Storerkey = SKU.Storerkey AND LLI.Sku = SKU.Sku        
    JOIN CODELKUP CL (NOLOCK) ON SKU.Putawayzone = CL.Short        
                        JOIN LOC (NOLOCK) ON  CL.Long = LOC.Putawayzone AND LLI.Loc = LOC.Loc        
                        WHERE LLI.Storerkey = @c_FromStorerkey        
                        AND LLI.Sku = @c_FromSku        
                        AND CL.Listname = 'ANFPUTZONE'        
                        AND LOC.LocationType = 'DYNPPICK'        
                        AND LOC.Facility = @c_fromFacility        
                        GROUP BY CL.Code, LOC.LogicalLocation, LOC.Loc        
                        HAVING SUM((LLI.Qty + LLI.PendingMoveIN + LLI.QtyExpected) - LLI.QtyPicked) > 0        
                        ORDER BY CL.Code, LOC.LogicalLocation DESC, LOC.Loc DESC        
                          
                        IF ISNULL(@c_FinalToLoc,'') = ''        
                        BEGIN        
                           SELECT TOP 1 @c_FinalToLoc = LOC.Loc        
                           FROM SKU (NOLOCK)         
                           JOIN CODELKUP CL (NOLOCK) ON SKU.Putawayzone = CL.Short        
                           JOIN LOC (NOLOCK) ON  CL.Long = LOC.Putawayzone         
                           LEFT JOIN LOTXLOCXID LLI (NOLOCK) ON LOC.Loc = LLI.Loc          
                           WHERE SKU.Storerkey = @c_FromStorerkey        
                           AND SKU.Sku = @c_FromSku        
                           AND CL.Listname = 'ANFPUTZONE'        
                           AND LOC.LocationType = 'DYNPPICK'        
                           AND LOC.Facility = @c_fromFacility        
                           GROUP BY CL.Code, LOC.LogicalLocation, LOC.Loc        
                           HAVING SUM((ISNULL(LLI.Qty,0) + ISNULL(LLI.PendingMoveIN,0) + ISNULL(LLI.QtyExpected,0)) - ISNULL(LLI.QtyPicked,0)) = 0        
                           ORDER BY CL.Code, LOC.LogicalLocation, LOC.Loc        
                        END           
                     END       
                     ELSE      
                     BEGIN                                           
                        EXEC @n_Err = [dbo].[nspRDTPASTD]        
                                      @c_userid          = @c_UserID        
                                    , @c_Storerkey       = @c_FromStorerkey        
                                    , @c_lot             = @c_FromLot        
                                    , @c_sku             = @c_FromSku        
                                    , @c_id              = @c_FromID        
               , @c_fromloc         = @c_FromLoc        
                                    , @n_qty             = @n_QtyToMove        
                                    , @c_uom             = '' -- not used        
                                    , @c_packkey         = '' -- optional, if pass-in SKU        
                                    , @n_putawaycapacity = 0        
                                    , @c_final_toloc     = @c_FinalToLoc OUTPUT        
                             
                        IF @n_Err <> 0        
                        BEGIN        
                           SET @n_Continue = 3        
                           SET @n_Err = 81050        
                           SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Putaway Strategy nspRDTPASTD (ispTransferAllocation04)'        
                           GOTO NEXT_TRF        
                        END        
                     END                             
                  END      
                        
                  -- Error if failed to find DPP location for Bulk allocation (Chee01)        
                  IF @c_FinalToLoc = ''        
                  BEGIN        
                     SET @n_Continue = 3        
                     SET @n_Err = 81060       
                     SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to find DPP location for Bulk allocation. (ispTransferAllocation04)'        
                     GOTO NEXT_TRF        
                  END        
        
                  SET @c_MoveToLoc = @c_FinalToLoc        
       
                  SET @dt_TimeOut = GETDATE()        
                        
                                 
                  SET @c_PABookID = RIGHT( RTRIM( @c_UCCNo), 18)           
                   
                  --Copy from getting taskdetail.toid        
                  SELECT @c_PABookID = CASE WHEN LocationType ='DYNPPICK' AND @c_UCCNO <> ''        
                                       THEN '' ELSE @c_FromID END       
                        , @c_FinalToLoc_DPP = LocationType      
                  FROM LOC  WITH (NOLOCK)        
                  WHERE Loc = @c_FinalToLoc        
                  AND LocationType = 'DYNPPICK'       
                           
                  IF @c_FinalToLoc_DPP = 'DYNPPICK'      
                  BEGIN                            
                     IF NOT EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK)        
        WHERE LOT = @c_FromLot        
                                    AND   LOC = @c_FromLoc        
                                    AND   ID = @c_PABookID )        
                     BEGIN --Add dummy lotxlocxid with id = '', will delete later        
                        INSERT INTO LotxLocxID (LOT, LOC, ID, SKU, STORERKEY, Qty, QtyAllocated, QtyExpected, QtyPicked, QtyPickInProcess, QtyReplen, PendingMoveIN, ArchiveQty)        
                        SELECT TOP 1 LOT, LOC, @c_PABookID, SKU, STORERKEY, Qty, QtyAllocated, QtyExpected, QtyPicked, QtyPickInProcess, QtyReplen, PendingMoveIN, ArchiveQty        
                        FROM LOTXLOCXID (NOLOCK)        
                        WHERE LOT = @c_FromLot        
                        AND LOC = @c_FromLoc        
                        AND ID =  @c_FromID        
                        AND STORERKEY = @c_FromStorerkey        
                        AND SKU = @c_FromSku        
                        SET @b_DummyLLI = 1         
                     END        
        
                     EXEC  rdt.rdt_Putaway_PendingMoveIn        
                                              @cUserName     = @c_UserID        
                                             ,@cType         = 'LOCK'        
                                             ,@cFromLOT      = @c_FromLot       
                                             ,@cFromLoc      = @c_FromLoc        
                                             ,@cFromID       = @c_PABookID        
                                             ,@cSuggestedLOC = @c_FinalToLoc        
 ,@cStorerKey    = @c_FromStorerkey        
                                             ,@cSKU          = @c_FromSku       
                                             ,@nErrNo        = @n_Err     OUTPUT        
                                             ,@cErrMsg       = @c_ErrMsg  OUTPUT        
                                             ,@nPutawayQTY   = @n_QtyToMove        
                                             ,@cUCCNo        = @c_UCCNo        
                                             ,@cToID         = @c_PABookID        
                                             ,@nPABookingKey = @n_PABookingKey OUTPUT       
                                                         
                     IF @n_Err <> 0        
                     BEGIN        
                        SET @n_Continue = 3        
                        SET @n_Err = 81070        
                        SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing rdt_Putaway_PendingMoveIn (ispTransferAllocation04)'        
                                       + ' for transferkey: ' + @c_Transferkey        
                                       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
        
                        GOTO NEXT_TRF        
                     END        
        
                     --IF EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK)        
                     --               WHERE LOT = @c_FromLot        
                     --               AND LOC = @c_FromLoc        
                     --               AND ID = @c_PABookID )        
                     --BEGIN        
                     --   IF @b_DummyLLI = 1        
                     --   BEGIN        
                     --      UPDATE LotxLocxID WITH (ROWLOCK)        
                     --      SET Qty = 0,        
                     --            QtyAllocated = 0,        
                     --            QtyPicked = 0,        
                     --            TrafficCop = NULL,        
                     --            EditDate = GETDATE(),        
                     --            EditWho = Suser_Sname()        
                     --      WHERE LOT = @c_FromLot        
                     --      AND LOC = @c_FromLoc        
                     --      AND ID =  @c_PABookID        
                     --      AND STORERKEY = @c_FromStorerkey        
                     -- AND SKU = @c_FromSku        
        
                     --      DELETE FROM LOTXLOCXID        
                     --      WHERE LOT = @c_FromLot        
                     --      AND LOC = @c_FromLoc        
                     --      AND ID =  @c_PABookID        
                     --      AND STORERKEY = @c_FromStorerkey        
                     --      AND SKU = @c_FromSku        
                     --   END        
                     --END        
                  END                       
               END        
            END      
            -------------------------------------------------------------      
            -- Move UCC Inventory from BULK to HOLD ID 'HOLD_001' (START)      
            -------------------------------------------------------------       
            IF @c_UCCNo <> '' AND @c_Status_TFD < '9'      
            BEGIN       
               SET @b_Success = 1        
               EXEC dbo.nspItrnAddMove        
                     @n_ItrnSysId      = NULL        
                  ,  @c_StorerKey      = @c_FromStorerkey        
                  ,  @c_Sku            = @c_FromSku        
                  ,  @c_Lot            = @c_FromLot        
                  ,  @c_FromLoc        = @c_FromLoc        
                  ,  @c_FromID         = @c_FromID        
                  ,  @c_ToLoc          = @c_FromLoc        
                  ,  @c_ToID           = 'HOLD_001'        
                  ,  @c_Status         = 'HOLD'        
                  ,  @c_lottable01     = ''        
                  ,  @c_lottable02     = ''        
                  ,  @c_lottable03     = ''        
                  ,  @d_lottable04     = ''        
                  ,  @d_lottable05     = ''        
                  ,  @c_lottable06     = ''               
                  ,  @c_lottable07     = ''               
                  ,  @c_lottable08     = ''               
                  ,  @c_lottable09     = ''               
                  ,  @c_lottable10     = ''               
                  ,  @c_lottable11     = ''               
                  ,  @c_lottable12     = ''               
                  ,  @d_lottable13     = ''               
                  ,  @d_lottable14     = ''               
                  ,  @d_lottable15     = ''               
                  ,  @n_casecnt        = 0.00        
                  ,  @n_innerpack      = 0.00        
                  ,  @n_qty            = @n_QtyToMove      
                  ,  @n_pallet         = 0.00        
                  ,  @f_cube           = 0.00        
                  ,  @f_grosswgt       = 0.00        
                  ,  @f_netwgt         = 0.00        
                  ,  @f_otherunit1     = 0.00        
                  ,  @f_otherunit2     = 0.00        
                  ,  @c_SourceKey      = @c_Transferkey        
                  ,  @c_SourceType     = 'ispTransferAllocation04'        
                  ,  @c_PackKey        = @c_FromPackkey        
                  ,  @c_UOM            = @c_FromUOM        
                  ,  @b_UOMCalc        = 0        
                  ,  @d_EffectiveDate  = @dt_today        
                  ,  @c_itrnkey        = ''        
                  ,  @b_Success        = @b_Success      OUTPUT        
                  ,  @n_err            = @n_err          OUTPUT        
                  ,  @c_errmsg         = @c_errmsg       OUTPUT        
        
               IF NOT @b_Success = 1        
               BEGIN        
                  SET @n_Continue = 3        
                  SET @n_Err = 81080        
                  SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing Move To HOLD ID - nspItrnAddMove (ispTransferAllocation04)'        
                                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                  GOTO NEXT_TRF        
               END       
               SET @c_FromID = 'HOLD_001'        
               SET @c_toid = ''            
                   
               IF @n_UCC_RowRef > 0       
               BEGIN      
                  UPDATE UCC       
                  SET ID = @c_FromID       
                     ,[Status] = @c_Status_UCC       
                  WHERE UCC_RowRef = @n_UCC_RowRef       
        
                  SET @n_err = @@ERROR        
        
                  IF @n_err <> 0        
                  BEGIN        
                     SET @n_continue = 3        
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                     SET @n_err = 81090  -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update UCC Failed. (ispTransferAllocation04)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                     GOTO NEXT_TRF        
                  END        
               END            
            END      
            -------------------------------------------------------------      
            -- Move UCC Inventory from BULK to HOLD ID 'HOLD_001' (END)      
            -- Or Update UCC. Status = '3'       
            -------------------------------------------------------------       
                  
            ----------------------------------------------------------      
            -- Split New Transfer Line OR Update Transfer Line - START      
            ----------------------------------------------------------      
            -- CR v6.0  - tolottable(01-15) same as fromlottable(01-15)      
            IF @n_QtyRemaining <= 0        
            BEGIN        
               UPDATE TRANSFERDETAIL       
               SET FromLot    = @c_FromLot        
                  ,FromLoc    = @c_FromLoc        
                  ,FromID     = @c_FromID        
    ,FromQty    = @n_QtyToTake           
                  ,Lottable01 = @c_Lottable01        
                  ,Lottable02 = @c_Lottable02       
                  ,Lottable03 = @c_Lottable03                         
                  ,Lottable04 = @dt_Lottable04       
                  ,Lottable05 = @dt_Lottable05       
                  ,Lottable06 = @c_Lottable06        
                  ,Lottable07 = @c_Lottable07          
                  ,Lottable08 = @c_Lottable08        
                  ,Lottable09 = @c_Lottable09        
                  ,Lottable10 = @c_Lottable10        
                  ,Lottable11 = @c_Lottable11        
                  ,Lottable12 = @c_Lottable12        
                  ,Lottable13 = @dt_Lottable13       
                  ,Lottable14 = @dt_Lottable14       
                  ,Lottable15 = @dt_Lottable15       
                  ,ToLoc      = @c_ToLoc        
                  ,ToID       = @c_FromID        
                  ,ToQty      = @n_QtyToTake         
                  ,ToLottable01 = @c_Lottable01       
                  ,ToLottable02 = @c_Lottable02                         
                  ,ToLottable03 = @c_Lottable03                           
                  ,ToLottable04 = @dt_Lottable04        
                  ,ToLottable05 = @dt_Lottable05        
                  ,ToLottable06 = @c_Lottable06          
                  ,ToLottable07 = @c_Lottable07             
                  ,ToLottable08 = @c_Lottable08          
                  ,ToLottable09 = @c_Lottable09          
                  ,ToLottable10 = @c_Lottable10          
                  ,ToLottable11 = @c_Lottable11          
                  ,ToLottable12 = @c_Lottable12          
                  ,ToLottable13 = @dt_Lottable13         
                  ,ToLottable14 = @dt_Lottable14         
                  ,ToLottable15 = @dt_Lottable15         
                  ,UserDefine01 = @c_UCCNo      
                  ,UserDefine02 = @c_UCCNo      
                  ,FromChannel  =  @c_FromChannel      
                  ,TOChannel    =  @c_ToChannel           
               WHERE Transferkey = @c_Transferkey        
               AND TransferLineNumber = @c_TransferLineNumber        
        
               SET @n_err = @@ERROR        
        
               IF @n_err <> 0        
               BEGIN        
                  SET @n_continue = 3        
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                  SET @n_err = 81100   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFERDETAIL Failed. (ispTransferAllocation04)'        
                                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                  GOTO NEXT_TRF        
               END        
        
               SET @c_NewTransferLineNo = @c_TransferLineNumber        
            END        
            ELSE        
            BEGIN        
               SELECT @c_NewTransferLineNo = RIGHT('00000' + CONVERT(VARCHAR(5), MAX(CONVERT(INT, TransferLineNumber)) + 1),5)        
               FROM TRANSFERDETAIL WITH (NOLOCK)        
               WHERE Transferkey = @c_Transferkey        
        
               INSERT INTO TRANSFERDETAIL        
                  (  TransferKey        
                  ,  TransferLineNumber        
                  ,  FromStorerkey        
                  ,  FromSku        
                  ,  FromLot        
                  ,  FromLoc        
                  ,  FromID        
                  ,  FromPackkey        
                  ,  FromUOM        
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
                  , Lottable12              
                  ,  Lottable13              
                  ,  Lottable14              
                  ,  Lottable15              
                  ,  FromQty        
                  ,  ToStorerkey        
                  ,  ToSku        
                  ,  ToLoc        
                  ,  ToID        
                  ,  ToPackkey        
                  ,  ToUOM        
                  ,  ToLottable01        
                  ,  ToLottable02        
                  ,  ToLottable03        
                  ,  ToLottable04        
                  ,  ToLottable05        
                  ,  ToLottable06                   
                  ,  ToLottable07                   
                  ,  ToLottable08                   
                  ,  ToLottable09                   
                  ,  ToLottable10                   
                  ,  ToLottable11                   
                  ,  ToLottable12                   
                  ,  ToLottable13                   
                  ,  ToLottable14                   
                  ,  ToLottable15                   
                  ,  ToQty        
                  ,  [Status]        
                  ,  UserDefine01      
                  ,  UserDefine02                  
                  ,  FromChannel       
                  ,  ToChannel      
                  )        
               VALUES        
                  (  @c_TransferKey        
                  ,  @c_NewTransferLineNo        
                  ,  @c_FromStorerkey        
                  ,  @c_FromSku        
                  ,  @c_FromLot        
                  ,  @c_FromLoc        
                  ,  @c_FromID        
                  ,  @c_FromPackkey        
                  ,  @c_FromUOM        
                  ,  @c_Lottable01        
                  ,  @c_Lottable02        
                  ,  @c_Lottable03        
                  ,  @dt_Lottable04        
                  ,  @dt_Lottable05        
                  ,  @c_Lottable06               
                  ,  @c_Lottable07               
                  ,  @c_Lottable08               
                  ,  @c_Lottable09               
                  ,  @c_Lottable10               
                  ,  @c_Lottable11            
                  ,  @c_Lottable12               
  ,  @dt_Lottable13              
                  ,  @dt_Lottable14              
                  ,  @dt_Lottable15              
                  ,  @n_QtyToTake         
                  ,  @c_ToStorerkey        
                  ,  @c_ToSku        
                  ,  @c_ToLoc        
                  ,  @c_FromID        
                  ,  @c_ToPackkey        
                  ,  @c_ToUOM        
                  ,  @c_Lottable01        
                  ,  @c_Lottable02        
                  ,  @c_Lottable03        
                  ,  @dt_Lottable04        
                  ,  @dt_Lottable05        
                  ,  @c_Lottable06                    
                  ,  @c_Lottable07                    
                  ,  @c_Lottable08                    
                  ,  @c_Lottable09                    
                  ,  @c_Lottable10                    
                  ,  @c_Lottable11                    
                  ,  @c_Lottable12                    
                  ,  @dt_Lottable13                   
                  ,  @dt_Lottable14                   
                  ,  @dt_Lottable15        
                  ,  @n_QtyToTake         
                  ,  '0' --CASE WHEN @c_Status_TFD < '9' THEN @c_Status_TFD ELSE '0' END        
                  ,  @c_UCCNo      
                  ,  @c_UCCNo      
                  ,  @c_FromChannel       
                  ,  @c_ToChannel        
                  )        
               SET @n_err = @@ERROR        
        
               IF @n_err <> 0        
               BEGIN        
                  SET @n_continue = 3        
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                  SET @n_err = 81110   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT TRANSFERDETAIL Failed. (ispTransferAllocation04)'        
                                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                  GOTO NEXT_TRF        
               END        
            END        
                  
            ----------------------------------------------------------      
            -- Split New Transfer Line OR Update Transfer Line - START      
            ----------------------------------------------------------      
            --------------------------------------------------      
            -- Finalize Transfer Line is Status = '9' - START      
            --------------------------------------------------      
       
            IF @c_Status_TFD = '9'       
            BEGIN      
               EXEC dbo.ispFinalizeTransfer       
                       @c_TransferKey = @c_TransferKey        
                     , @b_Success     = @b_Success     OUTPUT        
                     , @n_Err         = @n_err         OUTPUT        
                     , @c_ErrMsg      = @c_errmsg      OUTPUT        
                     , @c_TransferLineNumber = @c_NewTransferLineNo      
        
               IF @n_err <> 0        
               BEGIN        
                  SET @n_Continue= 3        
                  SET @n_err  = 81120        
                  SET @c_errmsg = 'Execute ispFinalizeTransfer Failed. (ispTransferAllocation04)'        
                                 + '(' + @c_errmsg + ')'        
                  GOTO NEXT_TRF        
               END               
            END      
            --------------------------------------------------      
            -- Finalize Transfer Line is Status = '9' - END      
   --------------------------------------------------      
        
            SET @c_Sourcekey = @c_Transferkey + @c_NewTransferLineNo        
        
            --Create Move Task for        
            --1) BULK to VAS, 2) DPP to VAS, 3) BULK to DPP (CN) 4) BULK to STAGING (HK)        
            IF @b_RPFTask = 1 AND @c_MoveToLoc <> ''        
            BEGIN        
               IF @c_PrepackIndicator = 'Y' AND @c_Status_TFD = '9' -- DPP to VAS        
               BEGIN        
                  SELECT @c_FromLot = Lot        
                  FROM ITRN WITH (NOLOCK)        
                  WHERE Sourcetype IN ('ntrTransferDetailAdd', 'ntrTransferDetailUpdate')        
                  AND SourceKey = @c_TransferKey + @c_NewTransferLineNo        
                  AND Trantype = 'DP'        
               END        
                 
               SET @b_success = 1        
               EXECUTE   nspg_getkey        
                     'TaskDetailKey'        
                        , 10        
                        , @c_TaskdetailKey OUTPUT        
                        , @b_success       OUTPUT        
                        , @n_err           OUTPUT        
                        , @c_errmsg        OUTPUT        
        
               IF NOT @b_success = 1        
               BEGIN        
                  SET @n_continue = 3        
                  SET @n_err = 81130   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispTransferAllocation04)'        
                                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                  GOTO NEXT_TRF        
               END        
        
               IF @b_success = 1        
               BEGIN        
                  SET @c_LogicalMoveToLoc = ''        
                  SET @c_Areakey = ''        
        
                  SELECT @c_LogicalMoveToLoc = ISNULL(RTRIM(LOC.LogicalLocation),'')        
                        ,@c_ToID             = CASE WHEN LocationType ='DYNPPICK' AND @c_UCCNO <> ''        
                                                    THEN '' ELSE @c_FromID END        
                  FROM LOC  WITH (NOLOCK)        
                  WHERE Loc = @c_MoveToLoc        
        
                  SELECT TOP 1       
                           @c_Areakey  = ISNULL(AD.AreaKey,'')        
                  FROM LOC  WITH (NOLOCK)        
                  LEFT JOIN AREADETAIL AD WITH (NOLOCK) ON (LOC.Putawayzone = AD.Putawayzone)        
                  WHERE Loc = @c_FromLoc        
        
                  INSERT INTO TASKDETAIL        
                     (        
                        TaskDetailKey        
                     ,  TaskType        
                     ,  Storerkey        
                     ,  Sku        
                     ,  UOM        
                     ,  UOMQty        
                     ,  Qty        
                     ,  SystemQty        
                     ,  Lot        
                     ,  FromLoc        
                     ,  FromID        
                     ,  ToLoc        
                     ,  ToID        
                     ,  CaseID        
                     ,  PickMethod        
                     ,  SourceType        
                     ,  SourceKey        
                     ,  [Priority]        
                     ,  SourcePriority        
                     ,  [Status]        
                     ,  Areakey        
                     ,  LogicalFromLoc        
                     ,  LogicalToLoc        
                     ,  Message01        
                     ,  Message02        
                     )        
                  VALUES        
                     (        
                        @c_Taskdetailkey        
                     ,  'RPF'                --Tasktype        
                     ,  @c_FromStorerkey        
              ,  @c_FromSku        
                     ,  @c_FromUOM           --UOM,        
                     ,  @n_QtyToMove        
                     ,  @n_QtyToMove        
                     ,  0                    --systemqty         
                     ,  @c_FromLot        
                     ,  @c_Fromloc        
                     ,  @c_FromID            -- from id        
                     ,  @c_MoveToLoc        
                     ,  @c_ToID              -- to id        
                     ,  @c_UCCNo        
                     ,  'PP'        
                     ,  'ispTransferAllocation04' --Sourcetype        
                     ,  @c_Sourcekey        
                     ,  '5'                  -- Priority        
                     ,  '9'                  -- Sourcepriority        
                     ,  'S'                  -- 11-AUG-2014 CR        
                     ,  @c_Areakey        
                     ,  @c_LogicalLoc        --Logical from loc        
                     ,  @c_LogicalMoveToLoc  --Logical to loc        
                     ,  'TRANSFER'        
                     ,  @c_FinalToLoc        
                     )        
        
                  SET @n_err = @@ERROR        
        
                  IF @n_err <> 0        
                  BEGIN        
                     SET @n_continue = 3        
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                     SET @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispTransferAllocation04)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                     GOTO NEXT_TRF        
                  END        
        
                  IF @n_PABookingKey > 0      
                  BEGIN      
                     UPDATE RFPutaway         
                     SET Taskdetailkey = @c_Taskdetailkey        
                     WHERE RowRef = @n_PABookingKey        
                     AND PABookingKey = @n_PABookingKey        
        
                     SET @n_err = @@ERROR        
        
                     IF @n_Err <> 0        
                     BEGIN        
                        SET @n_Continue = 3        
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                        SET @n_Err = 81150       
                        SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Updating RFPutaway Table (ispTransferAllocation04)'        
                                       + ' for transferkey: ' + @c_Transferkey        
                                       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                        GOTO NEXT_TRF        
                     END       
                  END             
               END        
            END        
        
            SET @n_FromQty = @n_FromQty - @n_QtyToTake       
            NEXT_LLI:       
         END        
        
         NEXT_TRFDET:        
         IF @n_QtyRemaining > 0        
         BEGIN        
            SET @c_Status_TFD = '0'          
            IF @c_AutoFinalizeShortTrf = '1'       
            BEGIN      
               SET @n_FromQty = 0      
               SET @c_Status_TFD = '9'    --- Auto Finalize Short inventory        
            END      
               
            UPDATE TRANSFERDETAIL        
            SET FromQty  = @n_FromQty        
               ,ToQty    = @n_FromQty      
               ,[Status] = @c_Status_TFD          
               ,EditWho  = @c_UserID        
               ,EditDate = @dt_Today        
               ,Trafficcop = NULL        
            WHERE Transferkey = @c_Transferkey        
            AND TransferLineNumber = @c_TransferLineNumber        
            AND (FromLot = '' OR FromLot IS NULL)        
        
            SET @n_err = @@ERROR        
        
            IF @n_err <> 0        
            BEGIN        
               SET @n_continue = 3        
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
               SET @n_err = 81160   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFERDETAIL Failed. (ispTransferAllocation04)'        
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
               GOTO NEXT_TRF        
            END        
         END        
               
         FETCH NEXT FROM @CUR_TFRDET INTO @c_TransferLineNumber        
                                       ,  @c_FromSku        
                                       ,  @n_FromQty        
                                       ,  @c_FromLottable01      
                                       ,  @c_FromLottable02      
                                       ,  @c_FromLottable03      
                                       ,  @dt_FromLottable04         
                                       ,  @dt_FromLottable05       
                                       ,  @c_FromLottable06                                                        
                                       ,  @c_Fromlottable07      
                                       ,  @c_FromLottable08       
                                       ,  @c_FromLottable09       
                                       ,  @c_FromLottable10       
                                       ,  @c_FromLottable11      
                                       ,  @c_FromLottable12      
                                       ,  @dt_FromLottable13      
                                       ,  @dt_FromLottable14         
                                       ,  @dt_FromLottable15      
                                       ,  @c_ToStorerkey        
                                       ,  @c_ToSku        
                                       ,  @c_ToLottable02      
                                       ,  @c_ToLottable03       
                                       ,  @c_FromChannel      
                                       ,  @c_ToChannel          
      END        
      CLOSE @CUR_TFRDET        
      DEALLOCATE @CUR_TFRDET        
        
      IF @c_Transmitflag <> 'IGNOR'        
      BEGIN        
         SET @n_OpenQty = 0        
         SET @c_Status_TFH = '0'      
         SELECT @c_Status_TFH = CASE WHEN MIN([Status]) = '9' THEN '9' ELSE '3' END      
               ,@n_OpenQty = ISNULL(SUM(CASE WHEN [Status] = '9' THEN 0 ELSE FromQty END),0)        
         FROM TRANSFERDETAIL WITH (NOLOCK)        
         WHERE TransferKey = @c_Transferkey      
         GROUP BY TransferKey       
      
         IF @c_Status_TFH = '9'        
         BEGIN       
            SET @b_Success = 0        
            SET @n_err     = 0        
            SET @c_errmsg  = ''        
            SET @c_PostFinalizeTransferSP = ''        
        
            EXEC nspGetRight        
                    @c_Facility  = @c_FromFacility        
                  , @c_StorerKey = @c_FromStorerKey        
                  , @c_sku       = NULL        
                  , @c_ConfigKey = 'PostFinalizeTranferSP'        
                  , @b_Success   = @b_Success                  OUTPUT        
                  , @c_authority = @c_PostFinalizeTransferSP   OUTPUT        
                  , @n_err       = @n_err                      OUTPUT        
                  , @c_errmsg    = @c_errmsg                   OUTPUT        
        
            IF EXISTS (SELECT 1 FROM sys.objects o WHERE NAME = @c_PostFinalizeTransferSP AND TYPE = 'P')        
            BEGIN        
               SET @b_Success = 0        
               EXECUTE dbo.ispPostFinalizeTransferWrapper        
                       @c_TransferKey             = @c_TransferKey        
                     , @c_PostFinalizeTransferSP  = @c_PostFinalizeTransferSP        
                     , @b_Success = @b_Success     OUTPUT        
                     , @n_Err     = @n_err         OUTPUT        
                     , @c_ErrMsg  = @c_errmsg      OUTPUT        
                     , @b_debug   = 0        
        
               IF @n_err <> 0        
               BEGIN        
                  SET @n_Continue= 3        
                  SET @n_err  = 81170        
                  SET @c_errmsg = 'Execute ispPostFinalizeTransferWrapper Failed. (ispTransferAllocation02)'        
                                 + '(' + @c_errmsg + ')'        
                  GOTO NEXT_TRF        
               END        
            END       
      
            IF @n_OpenQty = 0      
            BEGIN      
               SELECT @c_Status_TFH = @c_Status_Orig_TFH      
            END       
         END         
              
        
    --py01    
         DECLARE @c_Status_Current NVARCHAR(10) = ''    
               , @n_Open_Current INT = 0    
    
         SELECT @c_Status_Current =  t.[Status]     
            , @n_Open_Current =  t.[openqty]     
         FROM dbo.TRANSFER AS t  WITH (NOLOCK)    
         WHERE t.TransferKey = @c_TransferKey     
              
         IF @c_Status_Current NOT IN ('9') AND @n_Open_Current <> 0     
         BEGIN    
            SET @c_SQL = 'UPDATE [TRANSFER]'      
                       +' SET [Status] = @c_Status_TFH'       
                       +    ',OpenQty  = @n_OpenQty'        
                       +    ',EditWho  = @c_UserID '       
                       +    ',EditDate = GETDATE() '       
                       + CASE WHEN @c_Status_Current NOT IN ('9') AND @n_OpenQty = 0    
                              THEN ''     
                              WHEN @c_Status_Current NOT IN ('9') AND @c_Status_TFH = '9'     
                              THEN ''    
                              ELSE ',Trafficcop = NULL' END      
                       +' WHERE Transferkey = @c_Transferkey'       
                          
            SET @c_SQLParms= ' @c_Status_TFH  NVARCHAR(10)'       
                           + ',@n_OpenQty     INT'        
                           + ',@c_UserID      NVARCHAR(128)'       
                           + ',@c_Transferkey NVARCHAR(10)'       
        
            EXEC sp_ExecuteSQL @c_SQL      
                              ,@c_SQLParms      
                              ,@c_Status_TFH      
                              ,@n_OpenQty      
                              ,@c_UserID      
                              ,@c_Transferkey      
    
      
      
      
        
     
         SET @n_err = @@ERROR        
        
         IF @n_err <> 0        
         BEGIN        
            SET @n_continue = 3        
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
            SET @n_err = 81180   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFER Failed. (ispTransferAllocation02)'        
                           + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
            GOTO NEXT_TRF        
         END        
  END    
      
         IF @n_QtyRemaining > 0        
         BEGIN        
            SET @c_AlertMessage = 'There are requried qty not allocated. TransferKey : ' + @c_TransferKey        
        
            EXEC nspLogAlert        
                  @c_modulename       = 'ispTransferAllocation04'        
                , @c_AlertMessage     = @c_AlertMessage        
                , @n_Severity         = '5'        
                , @b_success          = @b_success    OUTPUT        
                , @n_err              = @n_Err        OUTPUT        
                , @c_errmsg           = @c_ErrMsg     OUTPUT        
                , @c_Activity         = 'Finalize Transfer'        
                , @c_Storerkey        = @c_FromStorerkey        
                , @c_SKU              = ''        
                , @c_UOM           = ''        
                , @c_UOMQty           = ''        
                , @c_Qty              = 0        
                , @c_Lot              = ''        
                , @c_Loc              = ''        
                , @c_ID               = ''        
                , @c_TaskDetailKey    = ''        
                , @c_UCCNo            = ''        
         END        
      END        
        
      NEXT_TRF:        
        
      IF @n_continue = 3  -- Error Occured        
      BEGIN        
         SET @b_success = 0        
      
         IF @@TRANCOUNT >= 1                                       
         BEGIN        
            ROLLBACK TRAN        
         END        
        
         SET @c_AlertMessage = 'There are Error on Transfer allocation. TransferKey : ' + @c_TransferKey +        
                               ' - ' + @c_ErrMsg -- (Chee01)        
         BEGIN TRAN        
        
      
      
         INSERT INTO #Error (ErrMsg) VALUES (@c_AlertMessage)        
        
         EXEC nspLogAlert        
               @c_modulename       = 'ispTransferAllocation04'        
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
          
         WHILE @@TRANCOUNT > 0      
         BEGIN      
            COMMIT TRAN      
         END       
         SET @c_Transmitflag = '5'       
      END        
        
      SET @b_success = 1        
        
      IF @@TRANCOUNT = 0      
      BEGIN      
         BEGIN TRAN        
      END        
      
      UPDATE TRANSMITLOG3        
      SET Transmitflag = @c_Transmitflag        
         ,TransmitBatch= @c_TransmitBatch      
         ,EditDate = GETDATE()      
         ,EditWho = SUSER_SNAME()      
         ,TrafficCop = NULL            
      WHERE Transmitlogkey = @c_Transmitlogkey        
        
      SET @n_err = @@ERROR        
        
      IF @n_err <> 0        
      BEGIN        
         SET @n_continue = 3        
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
         SET @n_err = 81190   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSMITLOG3 Failed. (ispTransferAllocation04)'        
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '       
         IF @@TRANCOUNT > 0      
         BEGIN                      
            ROLLBACK TRAN        
         END      
      END        
      
      WHILE @@TRANCOUNT > 0      
      BEGIN      
         COMMIT TRAN      
      END          
        
      FETCH NEXT FROM @CUR_ANFTRAN INTO @c_Transmitlogkey        
                                       ,@c_Transferkey        
                                       ,@c_TransferType        
                                       ,@c_FromFacility       
                                       ,@c_ToFacility       
                                       ,@c_Status_Orig_TFH         
   END        
   CLOSE @CUR_ANFTRAN        
   DEALLOCATE @CUR_ANFTRAN        
        
   QUIT_SP:        
        
   WHILE @@TRANCOUNT > 0         
   BEGIN        
      COMMIT TRAN        
   END       
         
   -- Send Email Alert if got error (Chee01)        
   IF EXISTS(SELECT 1 FROM #Error)        
   BEGIN        
      SELECT @cRecipients = CASE WHEN ISNULL(UDF01,'') <> '' THEN RTRIM(UDF01) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF02,'') <> '' THEN RTRIM(UDF02) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF03,'') <> '' THEN RTRIM(UDF03) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF04,'') <> '' THEN RTRIM(UDF04) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF05,'') <> '' THEN RTRIM(UDF05) + ';' ELSE '' END        
      FROM CODELKUP WITH (NOLOCK)        
      WHERE ListName = 'EmailAlert'        
      AND   Code = 'ispTransferAllocation04'        
      AND StorerKey = @c_FromStorerkey        
        
      IF ISNULL(@cRecipients, '') <> ''        
      BEGIN        
         SET @cSubject = 'ANF Transfer Allocation Alert - ' + REPLACE(CONVERT(NVARCHAR(19), GETDATE(), 126),'T',' ')        
         SET @cBody = '<table border="1" cellspacing="0" cellpadding="5">' +        
             '<tr bgcolor=silver><th>Error</th></tr>' + CHAR(13) +        
             CAST ( ( SELECT td = ISNULL(ErrMsg,'')        
                      FROM #Error        
                 FOR XML PATH('tr'), TYPE        
             ) AS NVARCHAR(MAX) ) + '</table>' ;        
        
        EXEC msdb.dbo.sp_send_dbmail        
            @recipients      = @cRecipients,        
            @copy_recipients = NULL,        
            @subject         = @cSubject,        
            @body            = @cBody,        
            @body_format     = 'HTML' ;        
        
         IF @@ERROR <> 0        
         BEGIN        
            SET @n_Continue = 3       
            SET @n_err = 81200      
            SET @c_Errmsg = 'Error executing sp_send_dbmail. (ispTransferAllocation04)'        
                          + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'        
         END        
      END -- IF ISNULL(@cRecipients, '') <> ''        
   END -- IF EXISTS(SELECT 1 FROM #Error)        
        
   IF @c_ReAllocTrfkey <> ''        
   BEGIN        
      SET @b_success =  1       
      IF @n_Continue = 1       
      BEGIN      
         SET @c_ErrMsg = 'Transfer Re-allocated'        
      END       
      ELSE      
      BEGIN      
         SET @b_success =  0      
         --SET @c_ErrMsg = ' Transfer Re-allocated With Error. ' + @c_ErrMsg      
      END      
   END         
           
   WHILE @@TRANCOUNT < @n_StartTCount        
   BEGIN        
      BEGIN TRAN        
   END        
        
   RETURN        
END 

GO