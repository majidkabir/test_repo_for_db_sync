SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/***************************************************************************/        
/* Stored Procedure: ispTransferAllocation02                               */        
/* Creation Date: 22-FEB-2021                                              */        
/* Copyright: IDS                                                          */        
/* Written by: Wan                                                         */        
/*                                                                         */        
/* Purpose: WMS-16094 - [CN] ANFQHW_WMS_TransferAllocation                 */        
/*        : Assumption: fromsku = tosku                                    */       
/*        : Duplicate and Modify from ispTransferAllocation                */      
/*                                                                         */        
/* Called By: Job Scheduler / RCM Menu                                     */        
/*                                                                         */        
/* PVCS Version: 1.0                                                       */        
/*                                                                         */        
/* Version: 5.4                                                            */        
/*                                                                         */        
/* Data Modifications:                                                     */        
/*                                                                         */        
/* Updates:                                                                */        
/* Date         Author  Ver   Purposes                                     */        
/* 22-FEB-2021  Wan     1.0   Created                                      */    
/* 26-Nov-2021 PakYuen  1.1   JSM-35430  change the logic to update  (py01)*/        
/***************************************************************************/        
CREATE PROC [dbo].[ispTransferAllocation02](        
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
        
   DECLARE @b_Debug              INT = 0       
         , @n_Cnt                INT = 0       
         , @n_Continue           INT = 1       
         , @n_StartTCount        INT = @@TRANCOUNT       
      
         , @b_ReAllocateTRF      BIT = 0      
      
         , @b_MoveToHoldID       BIT = 0      
         , @b_GetFinalToLoc      BIT = 0      
         , @b_CreateTask         BIT = 0      
               
         , @n_UCC_RowRef         BIGINT = 0      
               
         , @c_SQL                NVARCHAR(1000) = ''      
         , @c_SQLParms           NVARCHAR(1000) = ''                
               
   DECLARE @c_Transmitlogkey     NVARCHAR(10)   = ''      
         , @c_ReAllocTrfkey      NVARCHAR(10)   = ''       
         , @c_TransferType       NVARCHAR(10)   = ''      
         , @c_Status             NVARCHAR(10)   = ''      
         , @c_TransferStatus_D   NVARCHAR(10)   = ''      
         , @c_TransferStatus_H   NVARCHAR(10)   = ''      
         , @c_Transmitflag       NVARCHAR(10)   = ''      
         , @c_TransmitBatch      NVARCHAR(10)   = ''       
         , @c_Trafficcop         NVARCHAR(10)   = ''      
         , @c_TRFType            NVARCHAR(30)   = ''      
         , @c_TRFFromLoc         NVARCHAR(30)   = ''      
      
         , @c_TransferLineNumber NVARCHAR(5)    = ''      
         , @c_NewTransferLineNo  NVARCHAR(5)    = ''      
      
         , @c_TransOrder         NVARCHAR(10)   = ''      
         , @c_ToFacLoc_NonBulk   NVARCHAR(10)   = ''     --v1.5      
         , @c_ToFacLoc_BULK      NVARCHAR(10)   = ''     --v1.5      
         , @c_LocationCategory   NVARCHAR(10)   = ''      
         , @c_ToLocationCategory NVARCHAR(10)   = ''       
         , @c_Putawayzone_Sku    NVARCHAR(10)   = ''      
                  
         , @n_QtyAvail_LLI       INT            = 0      
         , @n_Qty                INT            = 0       
         , @n_QtyUCC             INT            = 0       
         , @n_QtyChannel         INT            = 0      
         , @n_QtyUCCINID         INT            = 0        
         , @n_Qty_TRFAllocated   INT            = 0       
                                                        
         , @c_FromFacility       NVARCHAR(5)    = ''      
         , @c_FromSku            NVARCHAR(15)   = ''      
         , @c_FromLot            NVARCHAR(10)   = ''      
         , @c_FromLoc            NVARCHAR(10)   = ''      
         , @c_FromID             NVARCHAR(18)   = ''      
         , @c_FromPackkey        NVARCHAR(10)   = ''      
         , @c_FromUOM            NVARCHAR(10)   = ''      
         , @c_FromChannel        NVARCHAR(20)   = ''      
             
         , @c_ToFacility         NVARCHAR(5)    = ''      
         , @c_ToPackkey          NVARCHAR(10)   = ''      
         , @c_ToUOM              NVARCHAR(10)   = ''      
         , @c_ToStorerkey        NVARCHAR(15)   = ''      
         , @c_ToSku              NVARCHAR(20)   = ''      
         , @c_ToLot              NVARCHAR(10)   = ''      
         , @c_ToLoc              NVARCHAR(10)   = ''      
         , @c_ToID               NVARCHAR(18)   = ''      
         , @c_FromLottable01     NVARCHAR(18)   = ''      
         , @c_FromLottable02     NVARCHAR(18)   = ''      
         , @c_FromLottable03     NVARCHAR(18)   = ''      
         , @dt_FromLottable04    DATETIME        
         , @dt_FromLottable05    DATETIME        
         , @c_FromLottable06     NVARCHAR(30)   = ''               
         , @c_FromLottable07     NVARCHAR(30)   = ''               
         , @c_FromLottable08     NVARCHAR(30)   = ''               
         , @c_FromLottable09     NVARCHAR(30)   = ''               
         , @c_FromLottable10     NVARCHAR(30)   = ''               
         , @c_FromLottable11     NVARCHAR(30)   = ''               
         , @c_FromLottable12     NVARCHAR(30)   = ''               
         , @dt_FromLottable13    DATETIME                      
         , @dt_FromLottable14    DATETIME                      
         , @dt_FromLottable15    DATETIME                
         , @c_Lottable01         NVARCHAR(18)   = ''      
         , @c_Lottable02         NVARCHAR(18)   = ''      
         , @c_Lottable03         NVARCHAR(18)   = ''      
         , @dt_Lottable04        DATETIME        
         , @dt_Lottable05        DATETIME        
         , @c_Lottable06         NVARCHAR(30)   = ''               
         , @c_Lottable07         NVARCHAR(30)   = ''               
         , @c_Lottable08         NVARCHAR(30)   = ''               
         , @c_Lottable09         NVARCHAR(30)   = ''               
         , @c_Lottable10         NVARCHAR(30)   = ''               
         , @c_Lottable11         NVARCHAR(30)   = ''               
         , @c_Lottable12         NVARCHAR(30)   = ''               
         , @dt_Lottable13        DATETIME                      
         , @dt_Lottable14        DATETIME                      
         , @dt_Lottable15        DATETIME          
         , @c_UCCNo              NVARCHAR(20)   = ''      
         , @c_ToUCCNo            NVARCHAR(20)   = ''      
         , @c_ToChannel          NVARCHAR(20)   = ''       
         , @n_FromChannel_ID     BIGINT         = 0      
         , @n_ToChannelID        BIGINT         = 0         
        
         , @n_FromQty            INT            = 0      
         , @n_ToQty              INT            = 0      
         , @n_QtyRemaining       INT            = 0      
         , @n_QtyToTake     INT            = 0      
         , @n_QtyToMove          INT            = 0      
         , @n_OpenQty            INT            = 0      
        
         , @c_PrepackIndicator   NVARCHAR(30)   = ''      
        
         , @c_UserID             NVARCHAR(128)  = ''      
         , @dt_today             DATETIME        
               
         --2021-04-02 - Add Get ChannelID by Attribute - START      
         , @n_Attribute_Cnt      INT            = 0      
         , @c_C_AttributeLbl     NVARCHAR(50)   = ''       
         , @c_C_AttributeLbl01   NVARCHAR(50)   = ''       
         , @c_C_AttributeLbl02   NVARCHAR(50)   = ''       
         , @c_C_AttributeLbl03   NVARCHAR(50)   = ''       
         , @c_C_AttributeLbl04   NVARCHAR(50)   = ''       
         , @c_C_AttributeLbl05   NVARCHAR(50)   = ''       
                 
         , @c_C_AttributeLbl_Value   NVARCHAR(30)   = ''       
         , @c_C_AttributeLbl01_Value   NVARCHAR(30)   = ''       
         , @c_C_AttributeLbl02_Value   NVARCHAR(30)   = ''       
         , @c_C_AttributeLbl03_Value   NVARCHAR(30)   = ''       
         , @c_C_AttributeLbl04_Value   NVARCHAR(30)   = ''       
         , @c_C_AttributeLbl05_Value   NVARCHAR(30)   = ''      
         --2021-04-02 - Add Get ChannelID by Attribute - END      
        
         , @c_TaskDetailKey      NVARCHAR(10)   = ''      
         , @c_UOM                NVARCHAR(10)   = ''  --2021-05-10 Fixed      
         , @c_Areakey            NVARCHAR(10)   = ''      
         , @c_MoveToLoc          NVARCHAR(10)   = ''      
         , @c_FinalToLoc         NVARCHAR(10)   = ''      
         , @c_LogicalLoc         NVARCHAR(10)   = ''      
         , @c_LogicalToLoc       NVARCHAR(10)   = ''      
         , @c_SourceKey          NVARCHAR(30)   = ''      
        
         , @c_PostFinalizeTransferSP   NVARCHAR(10) = ''       
         , @c_AutoFinalizeShortTrf     NVARCHAR(10) = ''       
         , @c_AlertMessage             NVARCHAR(255)= ''        
         , @c_ErrMsg2                  NVARCHAR(255)= ''        
        
         , @cRecipients             NVARCHAR(MAX)   = ''       
         , @cBody                   NVARCHAR(MAX)   = ''      
         , @cSubject                NVARCHAR(255)   = ''      
         , @n_PABookingKey          INT             = 0         
         , @dt_TimeOut              DATETIME        
               
         , @c_TRFAllocHoldChannel   NVARCHAR(30)    = '0'      
      
   DECLARE @CUR_ANFTRAN             CURSOR      
         , @CUR_TFRDET              CURSOR        
         , @CUR_LLI                 CURSOR        
         , @CUR_PM                  CURSOR      
        
   DECLARE @tTRF  TABLE      
         (  TransferKey       NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY      
         ,  Facility          NVARCHAR(5)    NOT NULL DEFAULT('')       
         ,  FromStorerkey     NVARCHAR(15)   NOT NULL DEFAULT('')      
         ,  ToFacility        NVARCHAR(5)    NOT NULL DEFAULT('')      
         ,  TRFType           NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  TRFFromLoc        NVARCHAR(30)   NOT NULL DEFAULT('')      
         )      
      
   DECLARE @tTL3  TABLE      
         (  Transmitlogkey    NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY      
         ,  TransferKey       NVARCHAR(10)   NOT NULL DEFAULT('')      
         )      
      
   DECLARE @tPutZone  TABLE      
         (  RowRef            INT            IDENTITY(1,1) PRIMARY KEY      
         ,  ListName          NVARCHAR(10)   NOT NULL DEFAULT('')      
         ,  Code              NVARCHAR(30)   NOT NULL DEFAULT('')      
         ,  Short             NVARCHAR(10)   NOT NULL DEFAULT('')      
         ,  Long              NVARCHAR(250)  NOT NULL DEFAULT('')      
         ,  Storerkey         NVARCHAR(15)   NOT NULL DEFAULT('')      
         ,  Code2             NVARCHAR(30)   NOT NULL DEFAULT('')      
         )      
               
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
      
   SET @c_UserID = SUSER_SNAME()        
   SET @dt_today = GETDATE()        
                  
   IF ISNULL(OBJECT_ID('tempdb..#Error'),'') <> ''        
   BEGIN        
      DROP TABLE #Error        
   END        
   CREATE TABLE #Error ( ErrMsg NVARCHAR(250) NULL )        
           
   IF @c_TransferKey <> ''      
   BEGIN      
      SET @b_ReAllocateTRF = 1      
      
      INSERT INTO @tTRF (TransferKey, Facility, FromStorerkey, ToFacility, TRFType, TRFFromLoc)      
      SELECT TF.TransferKey       
            ,TF.Facility      
            ,TF.FromStorerKey      
            ,TF.ToFacility      
            ,TRFType    = ISNULL(CL.Code,'IGNOR')      
            ,TRFFromLoc = ISNULL(CL2.Code,'IGNOR')      
      FROM [TRANSFER] TF WITH (NOLOCK)       
      JOIN TRANSFERDETAIL TFD WITH (NOLOCK) ON TFD.TransferKey = TF.Transferkey      
      LEFT JOIN CODELKUP CL WITH (NOLOCK)  ON  cl.LISTNAME = 'TranType'      
                                             AND cl.Code = TF.[Type]      
                                             AND cl.Storerkey = TF.FromStorerKey      
                                             AND cl.UDF01 = '1'      
      LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'ANFFAC'      
                                             AND CL2.Code     = TF.Facility      
                                             AND CL2.Storerkey= TF.FromStorerkey      
                                             AND CL2.UDF01    = TFD.FromLoc       
      WHERE TF.TransferKey = @c_TransferKey      
      AND   TF.[Status] < '9'       
      AND   TFD.FromLot = ''      
      AND   TFD.[Status]='0'      
      AND   TFD.FromQty > 0                 
      AND   TFD.FromLoc <> ''      
      GROUP BY TF.TransferKey       
            ,  TF.Facility      
            ,  TF.FromStorerKey      
            ,  TF.ToFacility      
            ,  ISNULL(CL.Code,'IGNOR')      
            ,  ISNULL(CL2.Code,'IGNOR')           
      
      INSERT INTO @tTL3 ( Transmitlogkey, Transferkey)      
      SELECT TL3.Transmitlogkey      
            ,TL3.Key1      
      FROM @tTRF t      
      JOIN [TRANSFER] TF WITH (NOLOCK)    ON t.TransferKey = TF.TransferKey      
      JOIN TRANSMITLOG3 TL3 WITH (NOLOCK) ON  TL3.Key1 = TF.TransferKey          
           AND TL3.Key3 = TF.FromStorerkey      
      WHERE TL3.TABLENAME = 'ANFTranAdd'        
      AND TL3.Transmitflag  <= '9'        
      AND TF.[Status] < '9'      
            
      SELECT TOP 1 @c_FromStorerkey = t.FromStorerkey      
            , @c_FromFacility = t.Facility      
      FROM @tTRF t      
   END      
   ELSE      
   BEGIN      
      IF @c_Facility = ''      
      BEGIN      
         INSERT INTO @tTRF (TransferKey, Facility, FromStorerkey, ToFacility, TRFType, TRFFromLoc )      
         SELECT DISTINCT      
                TF.Transferkey      
               ,TF.Facility      
               ,TF.FromStorerkey      
               ,TF.ToFacility      
               ,TRFType    = ISNULL(CL.Code,'IGNOR')      
               ,TRFFromLoc = ISNULL(CL2.Code,'IGNOR')      
         FROM [TRANSFER] TF WITH (NOLOCK)       
         JOIN TRANSFERDETAIL TFD WITH (NOLOCK) ON TFD.TransferKey = TF.Transferkey      
         LEFT JOIN CODELKUP CL WITH (NOLOCK)  ON  cl.LISTNAME = 'TranType'      
                                              AND cl.Code = TF.[Type]      
                                              AND cl.Storerkey = TF.FromStorerKey      
                                              AND cl.UDF01 = '1'      
         LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'ANFFAC'      
                                              AND CL2.Code     = TF.Facility      
                                              AND CL2.Storerkey= TF.FromStorerkey      
                                              AND CL2.UDF01    = TFD.FromLoc       
         WHERE TF.[Status] < '9'       
         AND   TFD.FromLot = ''      
         AND   TFD.[Status]='0'      
         AND   TFD.FromQty > 0                 
         AND   TFD.FromLoc <> ''        
         GROUP BY TF.TransferKey       
            ,  TF.Facility      
            ,  TF.FromStorerKey      
            ,  TF.ToFacility      
            ,  ISNULL(CL.Code,'IGNOR')      
            ,  ISNULL(CL2.Code,'IGNOR')             
      END      
      ELSE      
      BEGIN      
         INSERT INTO @tTRF (TransferKey, Facility, FromStorerkey, ToFacility, TRFType, TRFFromLoc)      
         SELECT DISTINCT      
                TF.Transferkey      
               ,TF.Facility      
               ,TF.FromStorerkey      
               ,TF.ToFacility      
               ,TRFType    = ISNULL(CL.Code,'IGNOR')      
               ,TRFFromLoc = ISNULL(CL2.Code,'IGNOR')      
         FROM [TRANSFER] TF WITH (NOLOCK)       
         JOIN TRANSFERDETAIL TFD WITH (NOLOCK) ON TFD.TransferKey = TF.Transferkey      
         LEFT JOIN CODELKUP CL WITH (NOLOCK)  ON  cl.LISTNAME = 'TrantType'      
                                              AND cl.Code = TF.[Type]      
                                              AND cl.Storerkey = TF.FromStorerKey      
                                              AND cl.UDF01 = '1'      
         LEFT JOIN CODELKUP CL2 WITH (NOLOCK) ON CL2.LISTNAME = 'ANFFAC'      
                                              AND CL2.Code     = TF.Facility      
                                              AND CL2.Storerkey= TF.FromStorerkey      
                                              AND CL2.UDF01    = TFD.FromLoc       
         WHERE TF.[Status] < '9'       
         AND   TF.Facility = @c_Facility      
         AND   TFD.FromLot = ''      
         AND   TFD.[Status]='0'      
         AND   TFD.FromQty > 0             
         AND   TFD.FromLoc <> ''       
         GROUP BY TF.TransferKey       
            ,  TF.Facility      
            ,  TF.FromStorerKey      
            ,  TF.ToFacility      
            ,  ISNULL(CL.Code,'IGNOR')      
            ,  ISNULL(CL2.Code,'IGNOR')         
                  
      END      
            
      INSERT INTO @tTL3 ( Transmitlogkey, Transferkey)      
      SELECT TL3.Transmitlogkey      
            ,TL3.Key1      
      FROM @tTRF t      
      JOIN [TRANSFER] TF WITH (NOLOCK) ON t.TransferKey = TF.TransferKey      
      JOIN TRANSMITLOG3 TL3  WITH (NOLOCK) ON  TL3.Key1 = TF.TransferKey          
                                           AND TL3.Key3 = TF.FromStorerkey      
      WHERE TL3.TABLENAME = 'ANFTranAdd'        
      AND TL3.Transmitflag < '9'        
      AND TF.[Status] < '9'      
   END      
      
   WHILE @@TRANCOUNT > 0        
   BEGIN        
      COMMIT TRAN        
   END        
      
   IF @b_ReAllocateTRF = 1      
   BEGIN        
      IF NOT EXISTS ( SELECT 1 FROM @tTRF t )        
      BEGIN        
         SET @n_continue = 3            
         SET @n_err    = 81010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.            
         SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Transfer(s) is not allowed to re-allocate. (ispTransferAllocation02)'        
         GOTO QUIT_SP                   
      END        
   END        
           
   SET @c_AutoFinalizeShortTrf = '0'        
   SELECT @c_AutoFinalizeShortTrf = ISNULL(RTRIM(SValue),'')        
   FROM STORERCONFIG WITH (NOLOCK)        
   WHERE Storerkey = @c_FromStorerkey        
   AND Configkey = 'AutoFinalizeShortTrf'       
         
INSERT INTO @tPutZone (ListName, Code, Short, Long, Storerkey, Code2)      
   SELECT cl.ListName      
         ,cl.Code      
         ,Short = ISNULL(cl.Short,'')      
         ,Long  = ISNULL(cl.Long,'')      
         ,cl.Storerkey      
         ,cl.Code2      
   FROM CODELKUP cl WITH (NOLOCK)      
   WHERE cl.ListName = 'ANFPUTZONE'       
      
   IF NOT EXISTS ( SELECT 1 FROM @tPutZone t )        
   BEGIN        
      SET @n_continue = 3            
      SET @n_err    = 81020   -- Should Be Set To The SQL Errmessage but I don't know how to do so.            
      SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PUTZone Does not setup in Codelkup. (ispTransferAllocation02)'        
      GOTO QUIT_SP                   
   END        
         
   SELECT @c_C_AttributeLbl01 = cac.C_AttributeLabel01        
         ,@c_C_AttributeLbl02 = cac.C_AttributeLabel02        
         ,@c_C_AttributeLbl03 = cac.C_AttributeLabel03        
         ,@c_C_AttributeLbl04 = cac.C_AttributeLabel04        
         ,@c_C_AttributeLbl05 = cac.C_AttributeLabel05        
   FROM   ChannelAttributeConfig AS cac WITH(NOLOCK)        
   WHERE  cac.StorerKey = @c_FromStorerkey       
        
   SET @CUR_ANFTRAN = CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR        
   SELECT Transmitlogkey= TL3.Transmitlogkey        
        , Transferkey   = TF.Transferkey        
        , TransferType  = TF.[Type]        
        , Facility      = TF.Facility       
        , FromStorerkey = TF.FromStorerkey       
        , TransmitFlag  = TL3.TransmitFlag      
        , ToFacility    = TF.ToFacility       
        , [Status]      = TF.[Status]      
        , TRFType       = t1.TRFType      
        , TRFFromLoc    = t1.TRFFromLoc      
   FROM @tTRF        t1      
   JOIN @tTL3        t2                ON  t2.TransferKey = t1.TransferKey       
   JOIN [TRANSFER]   TF  WITH (NOLOCK) ON  t1.TransferKey = TF.TransferKey      
   JOIN TRANSMITLOG3 TL3 WITH (NOLOCK) ON  TL3.Transmitlogkey = t2.Transmitlogkey        
                                       AND TL3.TABLENAME = 'ANFTranAdd'      
                                       AND TL3.Key1 = TF.TransferKey      
                                       AND TL3.Key3 = TF.FromStorerkey       
   WHERE TF.[Status] < '9'       
   ORDER BY TL3.Transmitlogkey        
        
   OPEN @CUR_ANFTRAN        
        
   FETCH NEXT FROM @CUR_ANFTRAN INTO   @c_Transmitlogkey        
                                    ,  @c_Transferkey        
                                    ,  @c_TransferType        
                                    ,  @c_FromFacility      
                                    ,  @c_FromStorerkey      
                                    ,  @c_Transmitflag       
                                    ,  @c_ToFacility       
                                    ,  @c_Status       
                                    ,  @c_TRFType      
                                    ,  @c_TRFFromLoc       
        
   WHILE @@FETCH_STATUS <> -1        
   BEGIN        
      SET @n_Continue = 1                    
      SET @b_Success= 1        
      SET @n_Err    = 0        
      SET @c_ErrMsg = ''      
            
      SET @c_TRFAllocHoldChannel = '0'      
      SELECT @c_TRFAllocHoldChannel = SC.Authority      
      FROM fnc_SelectGetRight (@c_FromFacility, @c_FromStorerkey, '', 'TRFAllocHoldChannel') SC       
      
      BEGIN TRAN        
      
      IF @c_TRFType = 'IGNOR' OR @c_TRFFromLoc = 'IGNOR'      
      BEGIN      
         SET @c_TransmitFlag = 'IGNOR'      
         SET @c_TransmitBatch= '0'         
         GOTO NEXT_TRF       
      END      
      
      --PROCESS NEXT IF CALL FROM Scheduler      
      IF @c_Transmitflag = '9' AND @b_ReAllocateTRF = 0      
      BEGIN       
         GOTO NEXT_REC      
      END      
      
      IF @c_Transmitflag = '9' AND @b_ReAllocateTRF = 1       
      BEGIN      
         UPDATE TRANSMITLOG3      
         SET   transmitflag  = '1'      
            ,  transmitbatch = '0'      
            ,  EditDate = GETDATE()      
            ,  EditWho = SUSER_SNAME()      
            ,  TrafficCop = NULL      
         WHERE transmitlogkey = @c_Transmitlogkey      
               
         SET @n_Err = @@ERROR      
              
         IF @n_err <> 0             
         BEGIN          
            SET @n_continue = 3            
            SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)          
            SET @n_err = 81030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.            
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSMITLOG3 Failed. (ispTransferAllocation02)'         
                         + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '          
            GOTO QUIT_SP      
         END      
      END      
            
      SET @c_TransOrder = 'RETAIL'      
            
      IF @c_TransferType Like '%DTC%'       
      BEGIN      
         SET @c_TransOrder = 'ECOM'      
      END      
      
      SET @c_Transmitflag   = '9'         
      SET @c_TransmitBatch  = '4'      
            
      IF @c_TransOrder = 'RETAIL' AND @c_FromFacility <> @c_ToFacility      
      BEGIN      
         SET @c_ToFacLoc_BULK = ''      
         SET @c_ToFacLoc_NonBulk = ''      
         SELECT @c_ToFacLoc_BULK  = ISNULL(tfc.UserDefine19,'')      
               ,@c_ToFacLoc_NonBulk  = ISNULL(tfc.UserDefine20,'')      
         FROM FACILITY tfc WITH (NOLOCK)      
         WHERE Facility = @c_ToFacility      
      
         IF @c_ToFacLoc_BULK = '' OR @c_ToFacLoc_NonBulk = ''      
         BEGIN      
            SET @n_continue = 3            
            SET @n_err    = 81040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.            
            SET @c_errmsg = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Default To Facility''s Loc not found. (ispTransferAllocation02)'        
            GOTO QUIT_SP       
         END      
      END      
        
      SET @CUR_TFRDET = CURSOR LOCAL FORWARD_ONLY STATIC READ_ONLY FOR        
      SELECT TransferLineNumber = TD.TransferLineNumber        
           , FromSku    = TD.FromSku        
           , FromQty    = TD.FromQty        
           , FromLottable01 = ISNULL(RTRIM(TD.Lottable01),'')       
           , FromLottable02 = ISNULL(RTRIM(TD.Lottable02),'')       
        , FromLottable03 = ISNULL(RTRIM(TD.Lottable03),'')       
           , FromLottable04 = ISNULL(RTRIM(TD.Lottable04),'1900-01-01')          
           , FromLottable05 = ISNULL(RTRIM(TD.Lottable05),'1900-01-01')        
           , FromLottable06 = ISNULL(RTRIM(TD.Lottable06),'')                                                         
           , Fromlottable07 = ISNULL(RTRIM(TD.Lottable07),'')      
           , FromLottable08 = ISNULL(RTRIM(TD.Lottable08),'')        
           , FromLottable09 = ISNULL(RTRIM(TD.Lottable09),'')        
           , FromLottable10 = ISNULL(RTRIM(TD.Lottable10),'')        
           , FromLottable11 = ISNULL(RTRIM(TD.Lottable11),'')       
           , FromLottable12 = ISNULL(RTRIM(TD.Lottable12),'')       
           , FromLottable13 = ISNULL(RTRIM(TD.Lottable13),'1900-01-01')       
           , FromLottable14 = ISNULL(RTRIM(TD.Lottable14),'1900-01-01')          
           , FromLottable15 = ISNULL(RTRIM(TD.Lottable15),'1900-01-01')                                                           
           , ToStorereky = TD.ToStorerkey        
           , ToSku     = TD.ToSku        
           , TD.FromChannel        
           , TD.ToChannel               
      FROM TRANSFERDETAIL TD  WITH (NOLOCK)        
      JOIN SKU            SKU WITH (NOLOCK) ON (TD.ToStorerkey = SKU.Storerkey) AND (TD.ToSku = SKU.Sku)       
      JOIN CODELKUP    AS c   WITH (NOLOCK) ON  c.LISTNAME = 'ANFFAC'      
                                            AND c.Code = @c_FromFacility      
                                            AND c.Storerkey = @c_FromStorerkey      
      WHERE TD.Transferkey = @c_Transferkey        
      AND   TD.[Status] = '0'               
      AND   TD.FromLot  = ''                  
      AND   TD.FromQty  > 0        
      AND   TD.FromLoc = c.UDF01       
      AND   TD.FromLoc <> ''              
        
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
                                    ,  @c_FromChannel       
                                    ,  @c_ToChannel              
        
      WHILE @@FETCH_STATUS <> -1        
      BEGIN       
         SET @n_QtyRemaining = @n_FromQty        
        
         SELECT @c_FromPackkey = PACK.Packkey        
               ,@c_FromUOM     = PACK.PackUOM3       
               ,@c_Putawayzone_Sku =  ISNULL(SKU.Putawayzone,'')      
         FROM SKU  WITH (NOLOCK)        
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)        
         WHERE SKU.Storerkey = @c_FromStorerkey        
         AND   SKU.Sku       = @c_FromSku        
        
         SELECT @c_ToPackkey = PACK.Packkey        
               ,@c_ToUOM     = PACK.PackUOM3        
               ,@c_PrepackIndicator = ISNULL(RTRIM(SKU.PrepackIndicator),'N')        
         FROM SKU WITH (NOLOCK)        
         JOIN PACK WITH (NOLOCK) ON (SKU.Packkey = PACK.Packkey)        
         WHERE SKU.Storerkey = @c_ToStorerkey        
         AND   SKU.Sku       = @c_ToSku       
               
         --------------------------------------------      
         -- Allocate Stock - Strategy      
         -- Allocate from 1) AVG OR DPP 2) Bulk      
         --------------------------------------------      
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
          
         -- Accumulate Sum  for UCCNo for Lot, Loc, id must be < Lotxlocxid.qty- lotxlocxid - qtyallocated - qtypicked - qtyreplen      
      
         SET @CUR_LLI = CURSOR FAST_FORWARD READ_ONLY FOR      
         SELECT LLI.Lot        
               ,LLI.Loc        
               ,LLI.ID        
               ,LogicalLoc = ISNULL(LOC.LogicalLocation,'')      
               ,LocationCategory = ISNULL(LOC.LocationCategory,'')         
               ,LA.Lottable01      
               ,LA.Lottable02       
               ,LA.Lottable03       
               ,LA.Lottable04      
               ,LA.Lottable05      
               ,LA.Lottable06       
               ,LA.Lottable07       
               ,LA.Lottable08       
               ,LA.Lottable09       
               ,LA.Lottable10       
               ,LA.Lottable11       
               ,LA.Lottable12       
               ,LA.Lottable13       
               ,LA.Lottable14       
               ,LA.Lottable15      
         FROM @tLA LA       
         JOIN LOT WITH (NOLOCK) ON LA.Lot = LOT.Lot      
         JOIN LOTxLOCxID   LLI WITH (NOLOCK) ON (LOT.Lot = LLI.Lot)        
         JOIN LOC          LOC WITH (NOLOCK) ON (LLI.Loc = LOC.LOC)        
         JOIN ID           ID  WITH (NOLOCK) ON (LLI.ID  = ID.ID)        
         WHERE LOC.Facility  = @c_FromFacility        
         AND   LOT.Qty - LOT.QtyAllocated - LOT.QtyPicked - LOT.QtyPreAllocated > 0        
         AND   LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - QtyReplen > 0        
         AND   LOT.Status = 'OK'        
         AND   LOC.Status = 'OK'        
         AND   LOC.LocationFlag NOT IN ( 'HOLD', 'DAMAGE' )        
         AND   ID.Status  = 'OK'       
         AND   LA.MatchLottable01 + LA.MatchLottable02 + LA.MatchLottable03 + LA.MatchLottable04 + LA.MatchLottable05 +      
               LA.MatchLottable06 + LA.MatchLottable07 + LA.MatchLottable08 + LA.MatchLottable09 + LA.MatchLottable10 +      
               LA.MatchLottable11 + LA.MatchLottable12 + LA.MatchLottable13 + LA.MatchLottable14 + LA.MatchLottable15 = 15      
         ORDER BY CASE WHEN LOC.LocationType = 'PICK' AND LOC.LocationCategory = 'AVG' THEN 10      
                       WHEN LOC.LocationType = 'DYNPPICK' AND LOC.LocationCategory = 'DPP' THEN 20        
                       WHEN LOC.LocationType = 'CASE' AND LOC.LocationCategory = 'BULK' THEN 30      
                       WHEN LOC.LocationType NOT IN ('DYNPPICK','PICK','CASE')  AND LOC.LocationCategory = 'BULK' THEN 40       
                       END        
               ,  CASE WHEN LOC.LocationCategory IN ( 'AVG', 'DPP' ) THEN LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen ELSE 0 END      
               ,  LLI.Loc      
               ,  LLI.ID               
               ,  LLI.Lot      
                  
         OPEN @CUR_LLI        
         FETCH NEXT FROM @CUR_LLI INTO @c_FromLot        
                                    ,  @c_FromLoc        
                                    ,  @c_FromID      
                                    ,  @c_LogicalLoc      
                                    ,  @c_LocationCategory      
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
                  
         WHILE  @@FETCH_STATUS <> -1 AND @n_FromQty > 0        
         BEGIN        
            SET @n_QtyAvail_LLI=0        
            SELECT @n_QtyAvail_LLI = LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen      
            FROM LOTxLOCxID LLI (NOLOCK)      
            WHERE LLI.Lot = @c_FromLot      
            AND LLI.Loc = @c_FromLoc      
            AND LLI.ID = @c_FromID      
            AND LLI.Qty - LLI.QtyAllocated - LLI.QtyPicked - LLI.QtyReplen > 0       
      
            IF @n_QtyAvail_LLI = 0      
            BEGIN      
               GOTO NEXT_LLI      
            END      
      
            WHILE @n_FromQty > 0 AND @n_QtyAvail_LLI > 0       
            BEGIN      
               SET @n_QtyToTake = 0        
      
               SET @c_UCCNo       = ''        
               SET @n_FromChannel_ID = 0      
               SET @n_PABookingKey= 0       
      
               IF @c_LocationCategory = 'BULK'      
               BEGIN      
                  SELECT TOP 1       
                        @c_UCCNo = u.UCCNo      
                     ,  @n_QtyUCC= u.Qty       
                     ,  @n_UCC_RowRef = u.UCC_RowRef            
                  FROM UCC u WITH (NOLOCK)      
                  WHERE u.Storerkey = @c_FromStorerkey      
                  AND u.Lot = @c_FromLot      
                  AND u.Loc = @c_FromLoc      
                  AND u.ID = @c_FromID      
                  AND u.Qty > 0      
                  AND u.Qty <= @n_QtyAvail_LLI      
                  AND u.[Status] = '1'      
      
                  IF @c_UCCNo = ''      
                  BEGIN      
                     GOTO NEXT_LLI      
                  END      
               END      
                  
               -- 2021-04-02 Get Channel ID By All Channel Attribute       
               IF @c_FromChannel <> ''      
               BEGIN      
                  SET @n_Attribute_Cnt = 1      
                  WHILE @n_Attribute_Cnt <= 5      
                  BEGIN      
                     IF @n_Attribute_Cnt = 1 SET @c_C_AttributeLbl = @c_C_AttributeLbl01      
                     IF @n_Attribute_Cnt = 2 SET @c_C_AttributeLbl = @c_C_AttributeLbl02      
                     IF @n_Attribute_Cnt = 3 SET @c_C_AttributeLbl = @c_C_AttributeLbl03      
                     IF @n_Attribute_Cnt = 4 SET @c_C_AttributeLbl = @c_C_AttributeLbl04      
                     IF @n_Attribute_Cnt = 5 SET @c_C_AttributeLbl = @c_C_AttributeLbl05        
            
                     SET @c_C_AttributeLbl_value = CASE WHEN @c_C_AttributeLbl = 'Lottable01' THEN @c_Lottable01        
                                 WHEN @c_C_AttributeLbl = 'Lottable02' THEN @c_Lottable02        
                                                        WHEN @c_C_AttributeLbl = 'Lottable03' THEN @c_Lottable03        
                                                        WHEN @c_C_AttributeLbl = 'Lottable04' THEN CONVERT(NVARCHAR(30), @dt_Lottable04, 112)      
                                                        WHEN @c_C_AttributeLbl = 'Lottable05' THEN CONVERT(NVARCHAR(30), @dt_Lottable05, 112)      
                                                        WHEN @c_C_AttributeLbl = 'Lottable06' THEN @c_Lottable06                                                 
                                                        WHEN @c_C_AttributeLbl = 'Lottable07' THEN @c_Lottable07         
                                                        WHEN @c_C_AttributeLbl = 'Lottable08' THEN @c_Lottable08                                                          
                                                        WHEN @c_C_AttributeLbl = 'Lottable09' THEN @c_Lottable09                                                 
                                                        WHEN @c_C_AttributeLbl = 'Lottable10' THEN @c_Lottable10        
                                                        WHEN @c_C_AttributeLbl = 'Lottable11' THEN @c_Lottable11        
                                                        WHEN @c_C_AttributeLbl = 'Lottable12' THEN @c_Lottable12        
                                                        WHEN @c_C_AttributeLbl = 'Lottable13' THEN CONVERT(NVARCHAR(30), @dt_Lottable13, 112)      
                                                        WHEN @c_C_AttributeLbl = 'Lottable14' THEN CONVERT(NVARCHAR(30), @dt_Lottable14, 112)      
                     WHEN @c_C_AttributeLbl = 'Lottable15' THEN CONVERT(NVARCHAR(30), @dt_Lottable15, 112)       
                                                        ELSE ''      
                                                        END        
                     IF @n_Attribute_Cnt = 1 SET @c_C_AttributeLbl01_Value = @c_C_AttributeLbl_Value      
                     IF @n_Attribute_Cnt = 2 SET @c_C_AttributeLbl02_Value = @c_C_AttributeLbl_Value      
                     IF @n_Attribute_Cnt = 3 SET @c_C_AttributeLbl03_Value = @c_C_AttributeLbl_Value      
IF @n_Attribute_Cnt = 4 SET @c_C_AttributeLbl04_Value = @c_C_AttributeLbl_Value      
                     IF @n_Attribute_Cnt = 5 SET @c_C_AttributeLbl05_Value = @c_C_AttributeLbl_Value          
            
                     SET @n_Attribute_Cnt = @n_Attribute_Cnt + 1                                                                                                                                                              
                  END      
      
                  SELECT TOP 1      
                        @n_FromChannel_ID =  chni.Channel_ID        
                     ,  @n_QtyChannel = chni.Qty - chni.QtyAllocated - chni.QtyOnHold      
                  FROM CHANNELINV chni WITH (NOLOCK)      
                  WHERE chni.Facility = @c_FromFacility      
                  AND chni.Storerkey = @c_FromStorerkey      
                  AND chni.Sku = @c_FromSku      
                  AND chni.Channel = @c_FromChannel      
                  --AND chni.C_Attribute01 = @c_Lottable07      
                  AND chni.C_Attribute01 = @c_C_AttributeLbl01_Value      
                  AND chni.C_Attribute02 = @c_C_AttributeLbl02_Value      
                  AND chni.C_Attribute03 = @c_C_AttributeLbl03_Value      
                  AND chni.C_Attribute04 = @c_C_AttributeLbl04_Value      
                  AND chni.C_Attribute05 = @c_C_AttributeLbl05_Value          
                  AND chni.Qty - chni.QtyAllocated - chni.QtyOnHold > 0      
      
                  IF @n_FromChannel_ID = 0      
                  BEGIN      
                     GOTO NEXT_LLI       
                  END      
               END       
                     
               IF @c_UCCNo = ''      
               BEGIN      
    SET @n_Qty = CASE WHEN @n_QtyChannel <= @n_QtyAvail_LLI THEN @n_QtyChannel ELSE @n_QtyAvail_LLI END      
               END      
               ELSE      
               BEGIN      
                  SET @n_Qty = CASE WHEN @n_QtyChannel < @n_QtyUCC THEN 0 ELSE @n_QtyUCC END      
               END      
      
               IF @n_Qty = 0      
               BEGIN      
                  GOTO NEXT_LLI       
               END      
      
               IF @n_QtyRemaining >= @n_Qty       
               BEGIN        
                  SET @n_QtyToTake = @n_Qty      
               END        
               ELSE        
               BEGIN        
                  SET @n_QtyToTake = @n_QtyRemaining        
               END        
      
               IF @n_QtyToTake <= 0        
               BEGIN        
                  GOTO NEXT_LLI      
               END       
      
               SET @c_ToLoc = ''      
               IF @c_TransOrder = 'RETAIL'      
               BEGIN       
                  IF @c_FromFacility = @c_ToFacility      
                  BEGIN      
                     SET @c_ToLoc = @c_FromLoc      
                  END      
                  ELSE      
                  BEGIN      
                     --v1.5      
                     SET @c_ToLoc = @c_ToFacLoc_NonBulk      
                     IF @c_LocationCategory = 'BULK'      
                     BEGIN       
                        SET @c_ToLoc = @c_ToFacLoc_Bulk      
                     END       
                  END      
               END      
               ELSE      
               BEGIN      
                  SELECT @c_ToLoc = CASE WHEN ISNULL(cl.Notes2,'') <> '' THEN ISNULL(cl.Notes2,'')      
                                         WHEN ISNULL(cl.Long,'') = 'FromLoc' THEN @c_FromLoc      
                                         ELSE ''      
                                         END       
                        ,@c_ToLocationCategory = ISNULL(cl.Long,'')      
                  FROM CODELKUP cl WITH (NOLOCK)      
                  WHERE cl.ListName = 'ANFDTCLOC'      
                  AND   cl.Storerkey= @c_FromStorerkey      
                  AND   cl.Code2 = @c_FromFacility      
                  AND   cl.Short = @c_LocationCategory      
                  AND  cl.UDF01 = @c_PrepackIndicator      
               END      
        
               ------------------------------      
               -- Find To Loc(DPP) - START      
               ------------------------------      
               IF @c_ToLoc = '' AND @c_ToLocationCategory = 'DPP'      
               BEGIN      
                  -- Find 1) Friend - Sku, Lottable01, Lottable03       
                  -- Find 2) Friend Empty Loc          
                  SELECT TOP 1 @c_ToLoc = LOC.Loc       
                  FROM @tPutZone CL       
                  JOIN LOC             WITH (NOLOCK) ON  CL.Long = LOC.Putawayzone       
                  LEFT OUTER JOIN LOTXLOCXID  LLI WITH (NOLOCK) ON  LLI.Storerkey = @c_FromStorerkey       
                                                      AND LLI.Sku = @c_FromSku       
                                                      AND LLI.Loc = LOC.Loc      
                  LEFT OUTER JOIN LOTATTRIBUTE LA WITH (NOLOCK) ON  LA.Lot = LLI.Lot      
                                                      AND LA.Lottable01 = @c_Lottable01      
                                                      AND LA.Lottable03 = @c_Lottable03      
                  WHERE CL.Listname = 'ANFPUTZONE'       
                  AND CL.Short    = @c_Putawayzone_Sku       
                  AND LOC.LocationType = 'DYNPPICK'        
                  AND LOC.Facility  = @c_FromFacility        
      
                  GROUP BY CL.Code, LOC.LogicalLocation, LOC.Loc        
                  --HAVING SUM((LLI.Qty + LLI.QtyReplen + LLI.PendingMoveIN + LLI.QtyExpected + LLI.QtyAllocated + LLI.QtyPicked) > 0        
                  ORDER BY ISNULL(SUM(LLI.Qty + LLI.QtyReplen + LLI.PendingMoveIN + LLI.QtyExpected + LLI.QtyAllocated + LLI.QtyPicked),0) DESC      
                        ,  CL.Code      
                        ,  LOC.LogicalLocation DESC      
                    ,  LOC.Loc DESC        
                       
                  -- Error if failed to find DPP location for Bulk allocation (Chee01)        
                  IF @c_ToLoc = ''        
                  BEGIN        
                     SET @n_Continue = 3        
                     SET @n_Err = 81050        
                     SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to find DPP location for Bulk allocation. (ispTransferAllocation02)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                     GOTO NEXT_TRF        
                  END        
                                
                  IF NOT EXISTS (SELECT 1 FROM LOTXLOCXID (NOLOCK)        
                                 WHERE LOT = @c_FromLot        
                                 AND   LOC = @c_FromLoc        
                                 AND   ID  = @c_ToID )        
                  BEGIN        
                     INSERT INTO LotxLocxID (LOT, LOC, ID, SKU, STORERKEY, Qty, QtyAllocated, QtyExpected, QtyPicked, QtyPickInProcess, QtyReplen, PendingMoveIN, ArchiveQty)        
                     SELECT TOP 1 LOT, LOC, @c_ToID, SKU, STORERKEY, Qty, QtyAllocated, QtyExpected, QtyPicked, QtyPickInProcess, QtyReplen, PendingMoveIN, ArchiveQty        
                     FROM LOTXLOCXID (NOLOCK)        
                     WHERE LOT = @c_FromLot        
                     AND LOC = @c_FromLoc        
                     AND ID =  @c_FromID        
                     AND STORERKEY = @c_FromStorerkey        
                     AND SKU = @c_FromSku        
                  END        
        
                  EXEC  rdt.rdt_Putaway_PendingMoveIn        
                                           @cUserName     = @c_UserID        
                                          ,@cType         = 'LOCK'        
                                          ,@cFromLoc      = @c_FromLoc        
                                          ,@cFromID       = @c_ToID        
                                          ,@cSuggestedLOC = @c_ToLoc      
                                         ,@cStorerKey    = @c_FromStorerkey        
                                          ,@nErrNo        = @n_Err     OUTPUT        
                                          ,@cErrMsg       = @c_ErrMsg  OUTPUT        
                                          ,@cSKU          = @c_FromSku        
                                          ,@nPutawayQTY   = @n_QtyToMove        
                                          ,@cUCCNo        = @c_UCCNo        
                                          ,@cFromLOT      = @c_FromLot        
                                          ,@cToID         = @c_ToID        
                                          ,@nPABookingKey = @n_PABookingKey OUTPUT       
                                                         
                  IF @n_Err <> 0        
                  BEGIN        
                     SET @n_Continue = 3        
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                     SET @n_Err = 81060        
                     SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing rdt_Putaway_PendingMoveIn (ispTransferAllocation02)'        
                                    + ' for transferkey: ' + @c_Transferkey        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
        
                     GOTO NEXT_TRF        
                  END        
               END      
               ------------------------------      
               -- Find To Loc(DPP) - END      
               ------------------------------      
                 
               IF @c_ToLoc = ''      
               BEGIN      
                  SET @n_Continue = 3        
                  SET @n_Err = 81070       
                  SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': ToLoc Not Found (ispTransferAllocation02)'        
                                 + ' for transferkey: ' + @c_Transferkey        
                  GOTO NEXT_TRF                    
               END      
                  
               SET @c_TransferStatus_D = '0'      
               IF @c_FromLoc = @c_ToLoc AND @c_FromFacility = @c_ToFacility --v1.5      
               BEGIN      
                  SET @c_TransferStatus_D = '9'  -- Finalize Line for 1) Retail Order for Same Facility, 2) ECOM Order for None Kitting DPP/AVG Loc      
               END      
               ELSE       
               BEGIN      
                  SET @c_TransferStatus_D = '3'  -- Do Not Finalize Line      
               END      
      
               SET @c_ToID = @c_FromID      
      
               SET @n_QtyRemaining = @n_QtyRemaining - @n_QtyToTake        
                  
               SET @c_ToUCCNo = ''      
               IF EXISTS ( SELECT 1 FROM LOC TL WITH (NOLOCK) WHERE TL.Loc = @c_ToLoc AND TL.LoseUCC = '0')      
               BEGIN      
                  SET @c_ToUCCNo = @c_UCCNo                       
               END        
               -----------------------------------------------      
               -- Populate Inventory to Transferdetail - START      
               -----------------------------------------------      
               IF @n_QtyRemaining <= 0        
               BEGIN        
                  UPDATE TRANSFERDETAIL WITH (ROWLOCK)        
                  SET FromLot  = @c_FromLot        
                     ,FromLoc  = @c_FromLoc        
                     ,FromID   = @c_FromID        
                     ,FromQty  = @n_QtyToTake           
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
                     ,ToID       = @c_ToID        
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
                     ,UserDefine02 = @c_ToUCCNo        
                     ,FromChannel_ID= @n_FromChannel_ID      
                     ,EditWho      = @c_UserID      
                     ,EditDate     = GETDATE()      
                  WHERE Transferkey = @c_Transferkey        
                  AND TransferLineNumber = @c_TransferLineNumber        
        
                  SET @n_err = @@ERROR        
        
                  IF @n_err <> 0        
                  BEGIN        
                     SET @n_continue = 3        
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
      SET @n_err = 81080   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFERDETAIL Failed. (ispTransferAllocation02)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                     GOTO NEXT_TRF        
                  END        
        
                  SET @c_NewTransferLineNo = @c_TransferLineNumber        
               END        
               ELSE        
               BEGIN        
                  ----------------------------------      
                  -- Populate to New Line      
                  ----------------------------------      
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
                     ,  Lottable12               
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
                     ,  UserDefine01   -- FromUCC      
                     ,  UserDefine02   -- ToUCC      
                     ,  FromCHannel_ID -- FromChannel ID      
                     ,  FromChannel    -- FromChannel       
                     ,  ToChannel      -- ToChannel      
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
                     ,  @c_ToID        
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
                     ,  '0'               -- Let ispFinalizeTransfer to finalize      
                     ,  @c_UCCNo       
                     ,  @c_ToUCCNo       
                     ,  @n_FromChannel_ID  -- FromChannel ID      
                     ,  @c_FromChannel    -- FromChannel       
                     ,  @c_ToChannel      -- ToChannel      
                     )        
                  SET @n_err = @@ERROR        
        
                  IF @n_err <> 0        
                  BEGIN        
                     SET @n_continue = 3        
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                     SET @n_err = 81090   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': INSERT TRANSFERDETAIL Failed. (ispTransferAllocation02)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                     GOTO NEXT_TRF        
                  END        
               END        
        
               --------------------------------------------------      
               -- Finalize Transfer Line is Status = '9' - START      
               --------------------------------------------------      
               IF @c_TransferStatus_D = '9'       
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
                     SET @n_err  = 81100        
                     SET @c_errmsg = 'Execute ispFinalizeTransfer Failed. (ispTransferAllocation03)'        
                                    + '(' + @c_errmsg + ')'        
                     GOTO NEXT_TRF        
                  END               
               END      
               --------------------------------------------------      
               -- Finalize Transfer Line is Status = '9' - END      
               --------------------------------------------------      
               SET @c_Sourcekey = @c_Transferkey + @c_NewTransferLineNo        
      
               ---------------------------------------      
               -- Lock Channel id: + qtyonhold - START      
               ---------------------------------------      
               IF @c_TransferStatus_D < '9' AND @c_FromChannel <> '' AND @c_TRFAllocHoldChannel = '1'        
               BEGIN      
                  EXEC isp_ChannelInvHoldWrapper        
                       @c_HoldType     = 'TRF'               
                     , @c_SourceKey    = @c_Transferkey          
                     , @c_SourceLineNo = @c_NewTransferLineNo                                       
                     , @c_Facility     = ''             
                     , @c_Storerkey    = ''             
                     , @c_Sku          = ''             
                     , @c_Channel      = ''             
                     , @c_C_Attribute01= ''             
                     , @c_C_Attribute02= ''             
                     , @c_C_Attribute03= ''             
                     , @c_C_Attribute04= ''             
                     , @c_C_Attribute05= ''             
                     , @n_Channel_ID   = 0             
                     , @c_Hold         = '1'             
                     , @c_Remarks      = ''        
                     , @c_HoldTRFType  = 'F'             
                     , @b_Success      = @b_Success   OUTPUT        
                     , @n_Err        = @n_Err       OUTPUT        
                     , @c_ErrMsg       = @c_ErrMsg    OUTPUT        
        
                  IF @b_Success = 0        
                  BEGIN        
                     SET @n_continue = 3        
                     SET @n_err = 81110        
                     SET @c_errmsg  = CONVERT(char(5),@n_err)+': Error Executing isp_ChannelInvHoldWrapper. (ispTransferAllocation02)'       
                     GOTO NEXT_TRF       
                  END        
               END      
               ---------------------------------------      
               -- Lock Channel id: + qtyonhold - END      
               ---------------------------------------      
      
               ---------------------------------------      
               -- Lock UCC: Update Status ='3' - START      
               ---------------------------------------      
               IF @c_UCCno <> ''       
               BEGIN      
                  UPDATE UCC      
                  SET [Status] = '3'      
                  WHERE UCC_RowRef = @n_UCC_RowRef      
                     
                  SET @n_err = @@ERROR        
        
                  IF @n_err <> 0        
                  BEGIN        
                     SET @n_continue = 3        
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                     SET @n_err = 81120   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE UCC Failed. (ispTransferAllocation02)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                     GOTO NEXT_TRF        
                  END        
               END      
               ---------------------------------------      
               -- Lock UCC: Update Status ='3'- END      
               ---------------------------------------      
               -----------------------------------------------      
               -- Insert Into Transferdetail - START      
               -- To Lock QtyReplen to LOTxLOCxID      
               -----------------------------------------------      
               IF @c_TransferStatus_D = '3' AND @c_FromLoc <> @c_ToLoc AND @c_TransOrder = 'ECOM'-- Not finalize      
               BEGIN      
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
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Error Executing nsp_GetKey - Taskdetailkey. (ispTransferAllocation02)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                     GOTO NEXT_TRF        
                  END        
        
                  SET @c_UOM = CASE WHEN @c_LocationCategory = 'BULK' THEN '2' ELSE '7' END     --2021-05-10 Fixed      
                  SET @c_ToID = ''      
                  SET @c_LogicalToLoc = @c_ToLoc       
                  SET @c_Areakey = ''        
       
                  SELECT TOP 1        
                           @c_Areakey  = ISNULL(AD.AreaKey,'')        
                  FROM LOC  WITH (NOLOCK)        
                  LEFT JOIN AREADETAIL AD WITH (NOLOCK) ON (LOC.Putawayzone = AD.Putawayzone)        
                  WHERE Loc = @c_FromLoc        
       
                  SELECT @c_ToLoc = PAZ.InLoc      
  FROM LOC l WITH (NOLOCK)      
                  JOIN PUTAWAYZONE PAZ WITH (NOLOCK) ON L.PutawayZone = PAZ.Putawayzone      
                  WHERE l.Loc = @c_ToLoc      
      
                  IF @c_ToLoc = ''      
                  BEGIN      
                     SET @n_continue = 3        
                     SET @n_err = 81140   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': PutawayZone''s InLoc not found. (ispTransferAllocation02)'        
                     GOTO NEXT_TRF        
                  END      
      
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
                     ,  QtyReplen      
                     )        
                  VALUES        
                     (        
                        @c_Taskdetailkey        
                     ,  'RPF'                --Tasktype        
                     ,  @c_FromStorerkey        
                     ,  @c_FromSku        
                     ,  @c_UOM               --UOM,         --2021-05-10 Fixed      
                     ,  CASE WHEN @c_UCCNo = '' THEN @n_QtyToTake ELSE @n_QtyUCC END   --2021-05-17 Fixed        
                     ,  CASE WHEN @c_UCCNo = '' THEN @n_QtyToTake ELSE @n_QtyUCC END   --2021-05-17 Fixed       
                     ,  0                    --systemqty        
                     ,  @c_FromLot        
                     ,  @c_Fromloc        
                     ,  @c_FromID            -- from id        
                     ,  @c_ToLoc        
                     ,  @c_ToID              -- to id        
                     ,  @c_UCCNo        
                     ,  'PP'        
                     ,  'ispTransferAllocation02' --Sourcetype        
               ,  @c_Sourcekey        
                     ,  '5'                  -- Priority        
                     ,  '9'                  -- Sourcepriority        
                     ,  'S'                  -- 11-AUG-2014 CR        
                     ,  @c_Areakey        
                     ,  @c_LogicalLoc        --Logical from loc        
                     ,  @c_LogicalToLoc      --Logical to loc        
                     ,  'TRANSFER'        
                     ,  @c_ToLoc        
                     ,  CASE WHEN @c_UCCNo = '' THEN @n_QtyToTake ELSE @n_QtyUCC END   --2021-05-17 Fixed      
                     )        
        
                  SET @n_err = @@ERROR        
        
                  IF @n_err <> 0        
                  BEGIN        
                     SET @n_continue = 3        
                     SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                     SET @n_err = 81150   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                     SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert TASKDETAIL Failed. (ispTransferAllocation02)'        
                                    + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
        
                     GOTO NEXT_TRF        
                  END        
        
                  IF @n_PABookingKey > 0      
                  BEGIN        
                     UPDATE RFPutaway WITH (ROWLOCK)        
                     SET Taskdetailkey = @c_Taskdetailkey        
                     WHERE RowRef = @n_PABookingKey        
                     AND PABookingKey = @n_PABookingKey        
        
                     SET @n_err = @@ERROR        
        
                     IF @n_Err <> 0        
                     BEGIN        
                        SET @n_Continue = 3        
                        SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                        SET @n_Err = 81160        
                        SET @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Updating RFPutaway Table (ispTransferAllocation02)'        
                                       + ' for transferkey: ' + @c_Transferkey        
                                       + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                        GOTO NEXT_TRF        
                     END        
                  END        
               -----------------------------------------------      
               -- Insert Into Transferdetail - END      
               -----------------------------------------------      
               END        
        
               SET @n_FromQty = @n_FromQty - @n_QtyToTake       
               SET @n_QtyAvail_LLI = @n_QtyAvail_LLI - @n_QtyToTake      
            END -- END Lotxlocxid QtyAvailable       
                --          
            NEXT_LLI:      
            FETCH NEXT FROM @CUR_LLI INTO @c_FromLot        
                                       ,  @c_FromLoc        
                                       ,  @c_FromID      
                                       ,  @c_LogicalLoc      
                  ,  @c_LocationCategory      
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
         END       
         CLOSE @CUR_LLI      
        DEALLOCATE @CUR_LLI       
        
        
         NEXT_TRFDET:        
      
         IF @n_QtyRemaining > 0       
         BEGIN       
            SET @c_TransferStatus_D = '0'          
            IF @c_AutoFinalizeShortTrf = '1'       
            BEGIN      
               SET @n_QtyRemaining = 0      
               SET @c_TransferStatus_D = '9'    --- Auto Finalize Short inventory        
            END      
               
            UPDATE TRANSFERDETAIL       
            SET FromQty  = @n_QtyRemaining        
               ,ToQty    = @n_QtyRemaining        
               ,[Status] = @c_TransferStatus_D        
               ,EditWho  = @c_UserID        
               ,EditDate = GETDATE()        
               ,Trafficcop = NULL        
            WHERE Transferkey = @c_Transferkey        
            AND TransferLineNumber = @c_TransferLineNumber        
            AND (FromLot = '' OR FromLot IS NULL)        
        
            SET @n_err = @@ERROR        
        
            IF @n_err <> 0        
            BEGIN        
          SET @n_continue = 3        
               SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
               SET @n_err = 81170   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
               SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFERDETAIL Failed. (ispTransferAllocation02)'        
                            + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
               GOTO NEXT_TRF        
            END        
         END      
                 
        FETCH NEXT FROM @CUR_TFRDET INTO  @c_TransferLineNumber        
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
                                       ,  @c_FromChannel       
                                       ,  @c_ToChannel              
                                                   
      END        
      CLOSE @CUR_TFRDET        
      DEALLOCATE @CUR_TFRDET        
      
      ---------------------------------------------------      
      -- Calculate PickMethod for TaskDetail.CaseiD <> ''      
      ---------------------------------------------------      
      SET @CUR_PM = CURSOR FAST_FORWARD READ_ONLY FOR       
      SELECT t.FromLoc      
            ,t.FromID      
            ,QtyUCCinID = SUM(t.Qty)      
      FROM TASKDETAIL t WITH (NOLOCK)       
      JOIN dbo.LOC AS l WITH (NOLOCK) ON t.FromLoc = l.Loc      
      WHERE t.TaskType = 'RPF'      
      AND t.SourceType = 'ispTransferAllocation02'      
      AND t.Sourcekey Like @c_TransferKey + '%'       
      AND t.CaseID <> ''      
      AND l.LocationType NOT IN ('DYNPPICK','PICK','CASE')        
      AND l.LocationHandling = '1'        --v1.6 CR      
      AND l.LocationCategory = 'BULK'      
      GROUP BY t.Storerkey      
             , t.FromLoc       
             , t.FromID      
      
      OPEN @CUR_PM      
      
      FETCH NEXT FROM @CUR_PM INTO  @c_FromLoc          
                                 ,  @c_FromID         
                                 ,  @n_QtyUCCinID          
       
      WHILE @@FETCH_STATUS <> -1          
      BEGIN          
         SELECT @n_Qty_TRFAllocated = ISNULL(SUM(FromQty),0)      
         FROM TRANSFERDETAIL AS t WITH (NOLOCK)      
         JOIN dbo.UCC AS u WITH (NOLOCK) ON  u.Storerkey = t.FromStorerkey      
                                         AND u.UCCNo = t.UserDefine01      
         WHERE t.TransferKey = t.TransferKey      
         AND FromLoc = @c_FromLoc      
         AND FromID = @c_FromID      
         AND t.[Status] = '0'      
         AND t.UserDefine01 <> ''      
      
         IF @n_QtyUCCinID = @n_Qty_TRFAllocated       
         BEGIN      
            IF EXISTS (      
                        SELECT 1      
                        FROM LOTxLOCxID LLI WITH (NOLOCK)      
                        WHERE LLI.Storerkey = @c_FromStorerkey      
                        AND   LLI.Loc = @c_FromLoc      
                        AND   LLI.ID  = @c_FromID      
                        GROUP BY LLI.Storerkey      
                               , LLI.Loc       
                               , LLI.ID      
                        HAVING SUM(Qty) = @n_Qty_TRFAllocated      
                        )      
            BEGIN      
               ;WITH UPDT ( TaskdetailKey, PickMethod )       
               AS (  SELECT t.TaskDetailKey, PickMethod = 'FP'       
                     FROM TASKDETAIL t WITH (NOLOCK)       
                     WHERE t.TaskType= 'RPF'      
                     AND t.SourceType = 'ispTransferAllocation02'      
                     AND t.Sourcekey Like @c_TransferKey + '%'       
                     AND t.CaseID <> ''      
                     AND t.FromLoc = @c_FromLoc      
                     AND t.FromID  = @c_FromID      
               )      
      
               UPDATE td      
               SET PickMethod = UPDT.PickMethod      
                  , EditWho = @c_UserID      
                  , EditDate= GETDATE()      
                  , Trafficcop = NULL      
               FROM UPDT      
               JOIN TASKDETAIL td ON UPDT.TaskdetailKey = td.TaskdetailKey      
      
               IF @@ERROR <> 0      
               BEGIN      
                  SET @n_continue = 3        
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
                  SET @n_err = 81180   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TASKDETAIL Failed. (ispTransferAllocation02)'        
                                 + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
                  GOTO NEXT_TRF        
               END      
            END      
         END      
      
         FETCH NEXT FROM @CUR_PM INTO  @c_FromLoc          
                                    ,  @c_FromID         
                                    ,  @n_QtyUCCinID             
      
      END      
      CLOSE @CUR_PM      
      DEALLOCATE @CUR_PM      
                        
      ---------------------------------------------------      
      -- Calculate PickMethod for TaskDetail.CaseiD <> ''      
      ---------------------------------------------------      
              
      SET @n_OpenQty = 0        
      SET @c_TransferStatus_H = '0'      
      SELECT @c_TransferStatus_H = CASE WHEN MIN([Status]) = '9' THEN '9'      
    WHEN MIN([Status]) = '0 'AND MAX([Status]) = '0' THEN '3'      
                                        ELSE '5'      
                                        END      
            ,@n_OpenQty = ISNULL(SUM(CASE WHEN [Status] = '9' THEN 0 ELSE FromQty END),0)        
      FROM TRANSFERDETAIL WITH (NOLOCK)        
      WHERE TransferKey = @c_Transferkey      
      GROUP BY TransferKey       
        
      --------------------------------------------      
      -- Create Transfer Build Kit - START      
      --------------------------------------------      
      ---Only Finalize Transfer Then only Create KIT      
      --IF @c_TransferStatus_H = '5' AND @c_PrePackIndicator = 'Y'     
      --BEGIN      
      --   EXEC ispTFRAlloc02_BuildKit        
      --       @c_Transferkey = @c_Transferkey        
      --     , @b_Success     = @b_Success OUTPUT      
      --     , @n_Err         = @n_Err     OUTPUT      
      --     , @c_ErrMsg      = @c_ErrMsg  OUTPUT         
      --     , @c_TransferLineNumber = @c_TransferLineNumber       
                 
      --   IF @b_Success = 0      
      --   BEGIN      
      --      SET @n_Continue= 3        
      --      SET @b_Success = 0        
      --      SET @n_err  = 81060        
      --      SET @c_errmsg = 'Execute ispPostFinalizeTransferWrapper Failed. (ispTransferAllocation02)'        
      --                     + '(' + @c_errmsg + ')'        
      --      GOTO NEXT_TRF      
      --   END      
      --END      
      --------------------------------------------      
      -- Create Transfer Build Kit - END      
      --------------------------------------------      
            
      SET @c_Trafficcop = ''      
      IF @c_TransferStatus_H = '9'        
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
               SET @b_Success = 0        
               SET @n_err  = 81190        
               SET @c_errmsg = 'Execute ispPostFinalizeTransferWrapper Failed. (ispTransferAllocation02)'        
                              + '(' + @c_errmsg + ')'        
               GOTO NEXT_TRF        
            END        
         END       
         SET @c_Trafficcop = NULL       
      
         IF @n_OpenQty = 0      
         BEGIN      
            SELECT @c_TransferStatus_H = @c_Status      
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
                       +' SET [Status] = @c_TransferStatus_H'       
                       +    ',OpenQty  = @n_OpenQty'        
                       +    ',EditWho  = @c_UserID '       
                       +    ',EditDate = GETDATE() '       
                       + CASE WHEN @c_Status_Current NOT IN ('9') AND @n_OpenQty = 0    
                              THEN ''     
                              WHEN @c_Status_Current NOT IN ('9') AND @c_TransferStatus_H = '9'     
                              THEN ''    
                              ELSE ',Trafficcop = NULL' END      
                       +' WHERE Transferkey = @c_Transferkey'       
                          
         SET @c_SQLParms= ' @c_TransferStatus_H  NVARCHAR(10)'       
                           + ',@n_OpenQty     INT'        
                           + ',@c_UserID      NVARCHAR(128)'       
                           + ',@c_Transferkey NVARCHAR(10)'       
        
            EXEC sp_ExecuteSQL @c_SQL      
                              ,@c_SQLParms      
                              ,@c_TransferStatus_H      
                              ,@n_OpenQty      
                              ,@c_UserID      
           ,@c_Transferkey      
        
      SET @n_err = @@ERROR        
        
      IF @n_err <> 0        
      BEGIN        
         SET @n_continue = 3        
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)        
         SET @n_err = 81200   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSFER Failed. (ispTransferAllocation02)'        
                        + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '        
         GOTO NEXT_TRF        
      END        
    END    
            
      IF @n_QtyRemaining > 0       
      BEGIN        
         SET @c_AlertMessage = 'There are required qty not allocated. TransferKey : ' + @c_TransferKey        
        
         EXEC nspLogAlert        
               @c_modulename       = 'ispTransferAllocation02'        
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
               @c_modulename       = 'ispTransferAllocation02'        
             , @c_AlertMessage     = @c_AlertMessage        
             , @n_Severity         = '5'        
             , @b_success          = @b_success    OUTPUT        
             , @n_err              = @n_Err        OUTPUT        
             , @c_errmsg           = @c_ErrMsg2    OUTPUT        
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
      ELSE        
      BEGIN        
         SET @b_success = 1        
      END        
        
      IF @@TRANCOUNT = 0      
      BEGIN      
         BEGIN TRAN        
      END      
         UPDATE TRANSMITLOG3 WITH (ROWLOCK)        
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
            SET @n_err = 81210   -- Should Be Set To The SQL Errmessage but I don't know how to do so.        
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE TRANSMITLOG3 Failed. (ispTransferAllocation02)'        
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
            
      NEXT_REC:      
      FETCH NEXT FROM @CUR_ANFTRAN INTO   @c_Transmitlogkey        
                                       ,  @c_Transferkey        
                                       ,  @c_TransferType        
                                       ,  @c_FromFacility      
                                       ,  @c_FromStorerkey      
                                       ,  @c_Transmitflag      
                                       ,  @c_ToFacility       
                                       ,  @c_Status      
                                       ,  @c_TRFType      
                                       ,  @c_TRFFromLoc                             
         
   END        
   CLOSE @CUR_ANFTRAN        
   DEALLOCATE @CUR_ANFTRAN        
      
   QUIT_SP:        
      
   WHILE @@TRANCOUNT > 0         
   BEGIN        
      COMMIT TRAN        
   END       
      
   -- Send Email Alert if got error (Chee01)        
   IF EXISTS (SELECT 1 FROM #Error)        
   BEGIN        
      SET @n_continue = 3      
      SELECT @cRecipients = CASE WHEN ISNULL(UDF01,'') <> '' THEN RTRIM(UDF01) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF02,'') <> '' THEN RTRIM(UDF02) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF03,'') <> '' THEN RTRIM(UDF03) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF04,'') <> '' THEN RTRIM(UDF04) + ';' ELSE '' END        
                          + CASE WHEN ISNULL(UDF05,'') <> '' THEN RTRIM(UDF05) + ';' ELSE '' END        
      FROM CODELKUP WITH (NOLOCK)        
      WHERE ListName = 'EmailAlert'        
      AND   Code = 'ispTransferAllocation02'        
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
            SET @n_err = 81220        
            SET @c_Errmsg = 'Error executing sp_send_dbmail. (ispTransferAllocation02)'        
                          + ' ( SQLSvr MESSAGE=' + CONVERT(NVARCHAR(5),ISNULL(@n_err,0)) + ' )'        
         END        
      END -- IF ISNULL(@cRecipients, '') <> ''        
   END -- IF EXISTS(SELECT 1 FROM #Error)        
        
IF @b_ReAllocateTRF = 1        
   BEGIN        
      SET @b_success =  1       
      IF @n_Continue = 1       
      BEGIN      
         SET @c_ErrMsg = 'Transfer Re-allocated'        
      END       
      ELSE      
      BEGIN      
         SET @b_success =  0      
      END      
   END         
          
   WHILE @@TRANCOUNT < @n_StartTCount        
   BEGIN        
      BEGIN TRAN        
   END        
        
   RETURN        
END 

GO