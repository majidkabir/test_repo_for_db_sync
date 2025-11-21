SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store procedure: WMS                                                 */
/* Copyright      : LFLogistics                                         */
/*                                                                      */
/* Purpose: Dynamic lottable                                            */
/*                                                                      */
/* Date        Rev   Author      Purposes                               */
/* 2020-04-06  1.1   Wan02       LFWM-2053 - UAT - MY  Putaway All in   */
/*                               Receipt not working                    */
/* 2021-02-09  1.2   mingle01    Add Big Outer Begin try/Catch          */
/*                               Execute Login if @c_UserName<>SUSER_SNAME()*/
/************************************************************************/
CREATE PROCEDURE [WM].[lsp_ReceiptPutaway_Wrapper]
      @c_ReceiptKey NVARCHAR(10)
    , @c_ReceiptLineNumber NVARCHAR(5)=''   
    , @b_Success INT=1 OUTPUT
    , @n_Err INT=0 OUTPUT
    , @c_ErrMsg NVARCHAR(250)='' OUTPUT
    , @n_WarningNo INT = 0       OUTPUT
    , @c_ProceedWithWarning CHAR(1) = 'N' 
    , @c_UserName NVARCHAR(128)=''
    , @n_ErrGroupKey INT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON
    SET QUOTED_IDENTIFIER OFF
    SET ANSI_NULLS OFF
    SET CONCAT_NULL_YIELDS_NULL OFF

    DECLARE @n_StartTCnt   INT   = @@TRANCOUNT
        
    SET @n_Err = 0 
    --(mingle01) - START   
    IF SUSER_SNAME() <> @c_UserName
    BEGIN
       EXEC [WM].[lsp_SetUser] 
             @c_UserName = @c_UserName  OUTPUT
          ,  @n_Err      = @n_Err       OUTPUT
          ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
       IF @n_Err <> 0 
       BEGIN
          GOTO EXIT_SP
       END
    
       EXECUTE AS LOGIN = @c_UserName
    END
    --(mingle01) - END
   
    --(mingle01) - START
    BEGIN TRY        

       DECLARE
            @n_ItrnSysId     int,
            @c_LOT           NVARCHAR(10),
            @c_ToLoc         NVARCHAR(10),
            @c_ToID          NVARCHAR(18),
            @c_Status        NVARCHAR(10),
            @c_Lottable01    NVARCHAR(18),
            @c_Lottable02    NVARCHAR(18),
            @c_Lottable03    NVARCHAR(18),
            @d_Lottable04    datetime,
            @d_Lottable05    datetime,
            @c_lottable06    NVARCHAR(30),
            @c_lottable07    NVARCHAR(30),
            @c_lottable08    NVARCHAR(30),
            @c_lottable09    NVARCHAR(30),
            @c_lottable10    NVARCHAR(30),
            @c_lottable11    NVARCHAR(30),
            @c_lottable12    NVARCHAR(30),
            @d_lottable13    datetime,
            @d_lottable14    datetime,
            @d_lottable15    datetime,
            @n_LLI_Qty       int,
            @n_innerpack     int,
            @n_Qty           int,
            @n_pallet        int,
            @f_cube          float,
            @f_grosswgt      float,
            @f_netwgt        float,
            @f_otherunit1    float,
            @f_otherunit2    float,
            @c_PackKey       NVARCHAR(10),
            @c_UOM           NVARCHAR(10) ,
            @c_SourceKey     NVARCHAR(15),
            @c_SourceType    NVARCHAR(30),
            @d_EffectiveDate datetime,
            @c_itrnkey       NVARCHAR(10) ,
            @c_FinalizeFlag  NVARCHAR(1),
            @n_QtyExpected   INT, 
            @c_ReceiptGroup  NVARCHAR(20),
            @c_OriginalReceiptLineNumber NVARCHAR(5)
    
      DECLARE @c_Lottable01Label    NVARCHAR(20),
            @c_Lottable02Label     NVARCHAR(20),
            @c_Lottable03Label     NVARCHAR(20),
            @c_Lottable04Label     NVARCHAR(20),
            @c_Lottable05Label     NVARCHAR(20),
            @c_Lottable06Label     NVARCHAR(20),
            @c_Lottable07Label     NVARCHAR(20),
            @c_Lottable08Label     NVARCHAR(20),
            @c_Lottable09Label     NVARCHAR(20),
            @c_Lottable10Label     NVARCHAR(20),
            @c_Lottable11Label     NVARCHAR(20),
            @c_Lottable12Label     NVARCHAR(20),
            @c_Lottable13Label     NVARCHAR(20),
            @c_Lottable14Label     NVARCHAR(20),
            @c_Lottable15Label     NVARCHAR(20),
            @c_RecType             NVARCHAR(10),
            @c_ExternLineNo        NVARCHAR(20),
            @n_TotQtyReceived      int,
            @c_CopyPackKey         NVARCHAR(1),        
            @c_authority_02        NVARCHAR(1),
            @n_IncomingShelfLife   Bigint,        
            @n_TolerancePerc       Bigint,        
           
            @c_DefaultReturnPickFace NVARCHAR(1) = '0',
            @c_authority_RetReason NVARCHAR(1),    
            @c_DocType             NVARCHAR(1)    


      DECLARE @c_PODLottable01      NVARCHAR(18)
            , @c_RECLottable01      NVARCHAR(18)
            , @c_PODLottable02      NVARCHAR(18)
            , @c_RECLottable02      NVARCHAR(18)
            , @c_PODLottable03      NVARCHAR(18)
            , @c_RECLottable03      NVARCHAR(18)
            , @d_PODLottable04      DateTime
            , @d_RECLottable04      DateTime
            , @d_PODLottable05      DateTime
            , @d_RECLottable05      DateTime
            , @c_TransmitlogKey     NVARCHAR(10)
            , @c_LOTCHGLOG          CHAR(1)       
            , @c_PutawayLoc         NVARCHAR(10)     
            , @c_SuggestedLoc       NVARCHAR(10)     
            , @c_DelToID            NVARCHAR(10)     
            , @c_SerialNoCapture    NVARCHAR(1)
            , @c_TableName          NVARCHAR(50)

      DECLARE    @c_Option1         NVARCHAR(30)  
               , @c_Option2         NVARCHAR(30)  
               , @c_Option3         NVARCHAR(30)  
               , @c_Option4         NVARCHAR(30)  
               , @c_Option5         NVARCHAR(2000) 
               , @c_authority_OverRcp  NVARCHAR(1)
               , @n_cnt        int
               , @c_SQL             NVARCHAR(2000) 


      declare @n_err2                 int,
               @n_Continue             int,                                   
               @c_StorerKey            NVARCHAR(15),
               @c_SKU                  NVARCHAR(20),
               @c_Facility             NVARCHAR(5),
               @c_bypasstolerance      NVARCHAR(1),
               @c_DefaultLottable_Returns   NVARCHAR(1), 
               @c_ASNUniqueLottableValue    NVARCHAR(1) 
            
      DECLARE @c_PUTAWAY_IDSTH   NVARCHAR(30) = ''    --(Wan01)
            , @c_PUTAWAY_RDTSP   NVARCHAR(30) = ''    --(Wan01) 
            , @c_PASP            NVARCHAR(50) = ''    --(Wan01)
            , @c_PickAndDropLoc  NVARCHAR(10) = ''    --(Wan01)  
            , @c_FitCasesInAisle NVARCHAR(1)  = ''    --(Wan01)        
            , @c_Param1          NVARCHAR(20) = ''    --(Wan01) 
            , @c_Param2          NVARCHAR(20) = ''    --(Wan01) 
            , @c_Param3          NVARCHAR(20) = ''    --(Wan01) 
            , @c_Param4          NVARCHAR(20) = ''    --(Wan01) 
            , @c_Param5          NVARCHAR(20) = ''    --(Wan01) 
      
      SET @n_Continue   = 1
      SET @c_TableName = 'ReceiptDetail'
      SET @c_SourceType = 'WSPUTAWAY'
      SET @n_ErrGroupKey = 0
      SET @c_OriginalReceiptLineNumber = @c_ReceiptLineNumber

      -- Validation before finalize
      DECLARE @c_ASNStatus NVARCHAR(10)

       
      IF @c_ReceiptLineNumber <> ''
      BEGIN
          SELECT @c_ASNStatus = r.ASNStatus, 
                 @c_StorerKey = r.StorerKey, 
                 @c_Facility  = r.Facility,
                 @c_RecType   = r.RECType, 
                 @c_DocType   = r.DOCTYPE 
          FROM RECEIPT AS r WITH(NOLOCK)
          JOIN ReceiptDetail RD WITH (NOLOCK) ON RD.ReceiptKey = r.ReceiptKey and RD.ReceiptLineNumber = @c_ReceiptLineNumber
          WHERE r.ReceiptKey = @c_ReceiptKey     
          IF @@ROWCOUNT = 0 
          BEGIN
            SET @n_continue = 3  
            SET @n_Err = 554151
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                  ': No Record Found! Invalid Receipt Key or Line Number. (lsp_ReceiptPutaway_Wrapper)'                 
            GOTO EXIT_SP            
          END
      END
      ELSE
      BEGIN
         SELECT @c_ASNStatus = r.ASNStatus, 
                @c_StorerKey = r.StorerKey, 
                @c_Facility  = r.Facility,
                @c_RecType   =r.RECType, 
                @c_DocType   = r.DOCTYPE      
         FROM RECEIPT AS r WITH(NOLOCK)
         WHERE r.ReceiptKey = @c_ReceiptKey
         IF @@ROWCOUNT=0
         BEGIN
            SET @n_continue = 3  
            SET @n_Err = 554152 
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
                  ': No Record Found! Invalid Receipt Key. (lsp_ReceiptPutaway_Wrapper)'                 
            GOTO EXIT_SP         
         END          
      END
     
      BEGIN TRY    
         SET @c_DefaultReturnPickFace = '0'
         EXEC nspGetRight
         @c_Facility = @c_Facility,
         @c_StorerKey = @c_StorerKey,
         @c_SKU = '',
         @c_ConfigKey = 'DefaultReturnPickFace',
         @b_Success = @b_Success OUTPUT,
         @c_authority = @c_DefaultReturnPickFace OUTPUT,
         @n_err = @n_err OUTPUT,
         @c_errmsg = @c_errmsg OUTPUT 
      END TRY
      BEGIN CATCH
         SET @n_continue = 3  
         SET @n_Err = 554153
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': Error Executing nspGetRight - DefaultReturnPickFace. (lsp_ReceiptPutaway_Wrapper)'                 
         GOTO EXIT_SP  
      END CATCH  

      BEGIN TRY
         SET @c_PUTAWAY_IDSTH = '0'
         EXEC nspGetRight
         @c_Facility = '',
         @c_StorerKey = @c_StorerKey,
         @c_SKU = '',
         @c_ConfigKey = 'PUTAWAY_IDSTH',
         @b_Success = @b_Success OUTPUT,
         @c_authority = @c_PUTAWAY_IDSTH OUTPUT,
         @n_err = @n_err OUTPUT,
         @c_errmsg = @c_errmsg OUTPUT 
      END TRY
      BEGIN CATCH
         SET @n_continue = 3  
         SET @n_Err = 554154
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': Error Executing nspGetRight - PUTAWAY_IDSTH. (lsp_ReceiptPutaway_Wrapper)'                 
         GOTO EXIT_SP  
      END CATCH   

      BEGIN TRY
         SET @c_PUTAWAY_RDTSP = '0'
         EXEC nspGetRight
         @c_Facility = '',
         @c_StorerKey = @c_StorerKey,
         @c_SKU = '',
         @c_ConfigKey = 'PUTAWAY_RDTSP',
         @b_Success = @b_Success OUTPUT,
         @c_authority = @c_PUTAWAY_RDTSP OUTPUT,
         @n_err = @n_err OUTPUT,
         @c_errmsg = @c_errmsg OUTPUT 
      END TRY
      BEGIN CATCH
         SET @n_continue = 3  
         SET @n_Err = 554155
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + 
               ': Error Executing nspGetRight - PUTAWAY_RDTSP. (lsp_ReceiptPutaway_Wrapper)'                 
         GOTO EXIT_SP  
      END CATCH    

       --Data Validation
      DECLARE C_RECEIPTLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT RD.ReceiptKey,
               RD.ReceiptLineNumber,
               RD.StorerKey,
               RD.SKU,
               ISNULL(RTRIM(RD.PutawayLoc),''),
               ISNULL(RTRIM(RD.ToLoc),''),  
               ISNULL(RD.ToLot,''),
               ISNULL(RD.ToId, ''),
               RD.QtyReceived  
         FROM ReceiptDetail RD WITH (NOLOCK)       
         JOIN RECEIPT R WITH (NOLOCK) ON (R.ReceiptKey = RD.ReceiptKey) 
         WHERE (RD.QtyReceived > 0) 
         AND RD.ReceiptKey = @c_ReceiptKey 
         AND RD.ReceiptLineNumber = CASE WHEN ISNULL(RTRIM(@c_ReceiptLineNumber), '') = '' THEN RD.ReceiptLineNumber ELSE @c_ReceiptLineNumber END
         AND RD.QtyReceived > 0  
         ORDER BY RD.ReceiptKey ,RD.ReceiptLineNumber

      OPEN C_RECEIPTLINE

      FETCH NEXT FROM C_RECEIPTLINE INTO
          @c_ReceiptKey              ,@c_ReceiptLineNumber       ,@c_StorerKey
         ,@c_SKU                     ,@c_PutawayLoc              ,@c_ToLoc
         ,@c_LOT                     ,@c_ToID                    ,@n_Qty 

      WHILE (@@FETCH_STATUS <> -1) 
      BEGIN
         --SELECT @c_ReceiptKey              ,@c_ReceiptLineNumber       ,@c_StorerKey
         --,@c_SKU
         SET @n_Continue = 1      
         SET @c_SourceKey = RTRIM(@c_ReceiptKey) + @c_ReceiptLineNumber
         SET @c_SuggestedLoc = ''
         
         IF (@c_RecType = 'RGR' OR @c_RecType = 'RET') AND @c_DefaultReturnPickFace = '1' --(Wan02)
         BEGIN
            IF @c_PutawayLoc <> '' AND @c_PutawayLoc NOT IN ('UNKNOWN','SEE_SUPV') AND 
               NOT EXISTS(SELECT 1 
                          FROM ITRN (NOLOCK) 
                          WHERE SourceType = 'WSPUTAWAY'
                          AND   SourceKey  = @c_SourceKey 
                          AND   TranType   = 'MV')
            BEGIN
               SET @c_SuggestedLoc = @c_PutawayLoc 
               GOTO EXEC_PUTAWAY 
            END
         END -- IF @c_RecType = 'RGR' OR @c_RecType = 'RET'
         ELSE IF @c_PutawayLoc = ''
         BEGIN
            GOTO EXEC_PUTAWAY  
         END

         FETCH_NEXT:
         FETCH NEXT FROM C_RECEIPTLINE INTO
             @c_ReceiptKey              ,@c_ReceiptLineNumber       ,@c_StorerKey
            ,@c_SKU                     ,@c_PutawayLoc              ,@c_ToLoc
            ,@c_LOT                     ,@c_ToID                    ,@n_Qty 
      END
      CLOSE C_RECEIPTLINE
      DEALLOCATE C_RECEIPTLINE
       
      GOTO EXIT_SP
      
      EXEC_PUTAWAY:
      IF EXISTS(SELECT 1 FROM LOC WITH (NOLOCK) WHERE LOC = @c_ToLoc AND LocationFlag IN ('DAMAGE'))
      BEGIN
         GOTO FETCH_NEXT   
      END
          
      IF @c_LOT = ''
      BEGIN
         SELECT TOP 1
            @c_LOT = ITRN.LOT 
         FROM   ITRN (NOLOCK)
         WHERE  ITRN.SourceKey = @c_SourceKey
         AND    ITRN.TOLOC = @c_ToLoc
         AND    ITRN.TranType = 'DP'
         AND    ITRN.SourceType Like 'ntrReceiptDetail%'
         AND    ITRN.ToId = @c_ToID 
         ORDER BY ItrnKey DESC  
      END

      IF @c_LOT = ''
         GOTO FETCH_NEXT 
          
      IF @c_SuggestedLoc = ''  
      BEGIN    
         SELECT @c_UOM = P.PackUOM3, 
                @c_PackKey = P.PackKey  
         FROM SKU AS S WITH (NOLOCK) 
         JOIN PACK AS P WITH (NOLOCK) ON p.PackKey = s.PackKey 
         WHERE s.StorerKey = @c_StorerKey 
         AND s.Sku = @c_SKU
         
         BEGIN TRY
            --(Wan01) - START
            IF @c_PUTAWAY_RDTSP = '1'
            BEGIN
               SET @c_PASP = 'nspRDTPASTD'
               EXEC nspRDTPASTD
                  @c_userid      = @c_UserName
               ,  @c_StorerKey   = @c_StorerKey
               ,  @c_LOT         = @c_LOT
               ,  @c_SKU         = @c_SKU
               ,  @c_ID          = @c_ToID
               ,  @c_FromLoc     = @c_ToLoc
               ,  @n_Qty         = @n_Qty
               ,  @c_UOM         = @c_UOM
               ,  @c_PackKey     = @c_PackKey
               ,  @n_PutawayCapacity= 0
               ,  @c_Final_ToLoc    = @c_SuggestedLoc OUTPUT
               ,  @c_PickAndDropLoc = @c_PickAndDropLoc  OUTPUT
               ,  @c_FitCasesInAisle= @c_FitCasesInAisle OUTPUT
               ,  @c_Param1         = @c_Param1 OUTPUT
               ,  @c_Param2         = @c_Param2 OUTPUT
               ,  @c_Param3         = @c_Param3 OUTPUT
               ,  @c_Param4         = @c_Param4 OUTPUT
               ,  @c_Param5         = @c_Param5 OUTPUT
            END
            ELSE IF @c_PUTAWAY_IDSTH = '1'
            BEGIN
               SET @c_PASP = 'nspASNPAStdTH'
               EXEC nspASNPAStdTH
                  @c_userid   = @c_UserName
               ,  @c_StorerKey= @c_StorerKey
               ,  @c_LOT      = @c_LOT
               ,  @c_SKU      = @c_SKU
               ,  @c_ID       = @c_ToID
               ,  @c_FromLoc  = @c_ToLoc
               ,  @n_Qty      = @n_Qty
               ,  @c_UOM      = @c_UOM
               ,  @c_PackKey  = @c_PackKey
               ,  @n_PutawayCapacity = 0
               ,  @c_Final_ToLoc = @c_SuggestedLoc OUTPUT
            END
            ELSE
            BEGIN
               SET @c_PASP = 'nspASNPASTD'
               EXEC nspASNPASTD
                  @c_userid   = @c_UserName
               ,  @c_StorerKey= @c_StorerKey
               ,  @c_LOT      = @c_LOT
               ,  @c_SKU      = @c_SKU
               ,  @c_ID       = @c_ToID
               ,  @c_FromLoc  = @c_ToLoc
               ,  @n_Qty      = @n_Qty
               ,  @c_UOM      = @c_UOM
               ,  @c_PackKey  = @c_PackKey
               ,  @n_PutawayCapacity = 0
               ,  @c_Final_ToLoc     = @c_SuggestedLoc OUTPUT
            END
            --(Wan01) - END        
         END TRY 
         BEGIN CATCH
            SET @n_Continue = 3
            SET @n_err = 554156
            SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing PA SP:' + @c_PASP
                           + '. (lsp_ReceiptPutaway_Wrapper)'
                           + ' |' + @c_PASP

            EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_ReceiptKey,
               @c_Refkey2     = @c_ReceiptLineNumber,
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err OUTPUT,
               @c_errmsg      = @c_errmsg OUTPUT   
         END CATCH
        
         IF @n_Continue = 3               --(Wan02)
         BEGIN  
            GOTO FETCH_NEXT
         END

         IF @c_SuggestedLoc = 'UNKNOWN' OR @c_SuggestedLoc = 'SEE_SUPV' OR @c_SuggestedLoc = ''
         BEGIN
            SET @n_Continue = 3               
            SET @n_err=554157  
            SET @c_ErrMsg = 'Unknown Location, Please check with supervisor.'      
                     
            EXEC [WM].[lsp_WriteError_List] 
               @i_iErrGroupKey = @n_ErrGroupKey output,
               @c_TableName   = @c_TableName,
               @c_SourceType  = @c_SourceType,
               @c_Refkey1     = @c_ReceiptKey,
               @c_Refkey2     = @c_ReceiptLineNumber,
               @c_Refkey3     = '',
               @n_err2        = @n_err,
               @c_errmsg2     = @c_errmsg,
               @b_Success     = @b_Success OUTPUT,
               @n_err         = @n_err OUTPUT,
               @c_errmsg      = @c_errmsg OUTPUT         
         END         
         ELSE
         BEGIN
            -- Do Move
            SET @n_LLI_Qty = 0 
            
            SELECT @n_LLI_Qty = lli.Qty - lli.QtyAllocated - lli.QtyPicked  
            FROM LOTxLOCxID AS lli WITH(NOLOCK)
            WHERE lli.Lot = @c_LOT
            AND   lli.Loc = @c_ToLOC
            AND   lli.ID  = @c_ToID
            
            IF @n_LLI_Qty < @n_Qty 
               SET @n_Qty = @n_LLI_Qty

            --SELECT @c_LOT '@c_LOT', @c_ToLOC '@c_ToLOC', @c_ToID '@c_ToID', @n_Qty '@n_Qty', @n_LLI_Qty '@n_LLI_Qty', @c_SuggestedLoc '@c_SuggestedLoc'
                     
            IF @n_Qty > 0 AND @c_SuggestedLoc <> @c_ToLoc AND @c_SuggestedLoc <> ''
            BEGIN
               SET @n_err = 0
               BEGIN TRY
                  EXEC dbo.nspItrnAddMove
                      @n_itrnsysid     = NULL ,
                      @c_storerkey     = @c_StorerKey,
                      @c_sku           = @c_Sku,
                      @c_lot           = @c_Lot,
                      @c_fromid        = @c_ToID,
                      @c_fromloc       = @c_ToLoc ,
                      @c_toloc         = @c_SuggestedLoc,
                      @c_toid          = @c_ToID,
                      @c_status        = '',
                      @c_lottable01    = '', 
                      @c_lottable02    = '', 
                      @c_lottable03    = '', 
                      @d_lottable04    = NULL, 
                      @d_lottable05    = NULL, 
                      @c_lottable06    = '',
                      @c_lottable07    = '',
                      @c_lottable08    = '',
                      @c_lottable09    = '',
                      @c_lottable10    = '',
                      @c_lottable11    = '',
                      @c_lottable12    = '',
                      @d_lottable13    = NULL,
                      @d_lottable14    = NULL,
                      @d_lottable15    = NULL,
                      @n_casecnt       = 0 ,
                      @n_innerpack     = 0 ,
                      @n_qty           = @n_Qty ,
                      @n_pallet        = 0 ,
                      @f_cube          = 0 ,
                      @f_grosswgt      = 0 ,
                      @f_netwgt        = 0 ,
                      @f_otherunit1    = 0 ,
                      @f_otherunit2    = 0 ,
                      @c_sourcetype    = @c_SourceType,
                      @c_sourcekey     = @c_SourceKey,
                      @c_packkey       = @c_Packkey,
                      @c_uom           = @c_UOM,
                      @b_uomcalc       = 1 ,
                      @d_effectivedate = NULL,
                      @c_itrnkey       = @c_itrnkey OUTPUT,
                      @b_success       = @b_success OUTPUT,
                      @n_err           = @n_err OUTPUT,
                      @c_errmsg        = @c_errmsg OUTPUT,
                      @c_MoveRefKey    = ''           
               END TRY
               BEGIN CATCH
                 SET @n_Continue = 3
                 SET @n_err = 554158
                 SET @c_ErrMsg = ERROR_MESSAGE()
                 SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing nspItrnAddMove. (lsp_ReceiptPutaway_Wrapper)'
                                + '( ' + @c_errmsg + ' )'
                             
               EXEC [WM].[lsp_WriteError_List] 
                  @i_iErrGroupKey = @n_ErrGroupKey output,
                  @c_TableName   = @c_TableName,
                  @c_SourceType  = @c_SourceType,
                  @c_Refkey1     = @c_ReceiptKey,
                  @c_Refkey2     = @c_ReceiptLineNumber,
                  @c_Refkey3     = '',
                  @n_err2        = @n_err,
                  @c_errmsg2     = @c_errmsg,
                  @b_Success     = @b_Success OUTPUT,
                  @n_err         = @n_err OUTPUT,
                  @c_errmsg      = @c_errmsg OUTPUT                
               END CATCH  

               IF @b_success = 1 AND @n_err = 0
               BEGIN
                  BEGIN TRY
                     UPDATE RECEIPTDETAIL 
                     SET PutawayLoc = @c_SuggestedLoc
                        ,EditWho = @c_UserName
                        ,EditDate= GETDATE()
                     WHERE ReceiptKey = @c_ReceiptKey
                     AND ReceiptLineNumber = @c_ReceiptLineNumber
                  END TRY
                  BEGIN CATCH
                     SET @n_Continue = 3
                     SET @n_err = 554159
                     SET @c_ErrMsg = ERROR_MESSAGE()
                     SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Update RECEIPTDETAIL Table fail. (lsp_ReceiptPutaway_Wrapper)'
                                    + '( ' + @c_errmsg + ' )'
                  END CATCH
               END
            END      
         END          
      END
      GOTO FETCH_NEXT
   
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
   EXIT_SP:       

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_ReceiptPutaway_Wrapper'
      SET @n_WarningNo = 0
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END


   REVERT  
END -- End Procedure

GO